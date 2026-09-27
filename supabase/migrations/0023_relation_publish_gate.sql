begin;

alter table public.link_skill_relations
  add column if not exists published boolean not null default false,
  add column if not exists published_at timestamptz;

comment on column public.link_skill_relations.published is
  'Public visibility gate. A relation can stay active for coach review while unpublished.';
comment on column public.link_skill_relations.published_at is
  'Timestamp for the latest transition into the public catalog.';

create index if not exists link_skill_relations_published_skill_score_idx
on public.link_skill_relations (
  skill_id,
  curator_score desc,
  curator_reviews desc,
  created_at desc
)
where is_active and published;

create index if not exists link_skill_relations_unpublished_review_queue_idx
on public.link_skill_relations (created_at asc, id asc)
where is_active and not published;

create or replace function public.sync_relation_published_at()
returns trigger
language plpgsql
set search_path = public
as $fn$
begin
  if new.published then
    new.published_at := coalesce(new.published_at, now());
  else
    new.published_at := null;
  end if;

  return new;
end;
$fn$;

drop trigger if exists link_skill_relations_sync_published_at on public.link_skill_relations;
create trigger link_skill_relations_sync_published_at
before insert or update of published, published_at on public.link_skill_relations
for each row execute function public.sync_relation_published_at();

drop policy if exists "active link skill relations are public" on public.link_skill_relations;
drop policy if exists "published active link skill relations are public" on public.link_skill_relations;
create policy "published active link skill relations are public"
on public.link_skill_relations for select
to anon, authenticated
using (is_active = true and published = true);

create or replace function public.get_skill_resource_counts(p_skill_ids uuid[])
returns table(skill_id uuid, resource_count bigint)
language sql
stable
security definer
set search_path = public
as $fn$
  select lsr.skill_id, count(*)::bigint as resource_count
  from public.link_skill_relations lsr
  join public.links l on l.id = lsr.link_id
  where lsr.skill_id = any(p_skill_ids)
    and lsr.is_active = true
    and lsr.published = true
    and l.is_active = true
  group by lsr.skill_id;
$fn$;

grant execute on function public.get_skill_resource_counts(uuid[]) to anon, authenticated;

create table if not exists public.relation_publish_gate_runs (
  id uuid primary key default gen_random_uuid(),
  min_reviews smallint not null,
  min_score real not null,
  unpublish_unreviewed boolean not null default false,
  published_count integer not null default 0,
  unpublished_count integer not null default 0,
  metadata_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

comment on table public.relation_publish_gate_runs is
  'Audit log for scheduled relation publish-gate refreshes.';

alter table public.relation_publish_gate_runs enable row level security;
grant select on public.relation_publish_gate_runs to authenticated;

drop policy if exists "moderators can view relation publish gate runs" on public.relation_publish_gate_runs;
create policy "moderators can view relation publish gate runs"
on public.relation_publish_gate_runs for select
to authenticated
using (public.is_moderator());

create or replace function public.refresh_relation_publish_gate(
  p_min_reviews smallint default 2,
  p_min_score real default 2.0,
  p_unpublish_unreviewed boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_min_reviews smallint := greatest(coalesce(p_min_reviews, 2), 1);
  v_min_score real := coalesce(p_min_score, 2.0);
  v_published integer := 0;
  v_unpublished integer := 0;
  v_result jsonb;
begin
  with publishable as (
    select lsr.id
    from public.link_skill_relations lsr
    join public.links l on l.id = lsr.link_id
    where lsr.is_active = true
      and lsr.published = false
      and l.is_active = true
      and lsr.curator_reviews >= v_min_reviews
      and lsr.curator_score >= v_min_score
  ),
  published_rows as (
    update public.link_skill_relations lsr
       set published = true,
           published_at = coalesce(lsr.published_at, now()),
           updated_at = now()
      from publishable p
     where lsr.id = p.id
     returning lsr.id
  )
  select count(*)::integer into v_published
  from published_rows;

  with unpublishable as (
    select lsr.id
    from public.link_skill_relations lsr
    join public.links l on l.id = lsr.link_id
    where lsr.published = true
      and (
        lsr.is_active = false
        or l.is_active = false
        or (
          lsr.curator_reviews >= v_min_reviews
          and lsr.curator_score < v_min_score
        )
        or (
          p_unpublish_unreviewed = true
          and lsr.curator_reviews < v_min_reviews
        )
      )
  ),
  unpublished_rows as (
    update public.link_skill_relations lsr
       set published = false,
           published_at = null,
           updated_at = now()
      from unpublishable u
     where lsr.id = u.id
     returning lsr.id
  )
  select count(*)::integer into v_unpublished
  from unpublished_rows;

  v_result := jsonb_build_object(
    'ok', true,
    'published_count', v_published,
    'unpublished_count', v_unpublished,
    'min_reviews', v_min_reviews,
    'min_score', v_min_score,
    'unpublish_unreviewed', p_unpublish_unreviewed
  );

  insert into public.relation_publish_gate_runs (
    min_reviews,
    min_score,
    unpublish_unreviewed,
    published_count,
    unpublished_count,
    metadata_json
  )
  values (
    v_min_reviews,
    v_min_score,
    p_unpublish_unreviewed,
    v_published,
    v_unpublished,
    v_result
  );

  return v_result;
end;
$fn$;

comment on function public.refresh_relation_publish_gate(smallint, real, boolean) is
  'Publishes fully-reviewed high-scoring active relations and unpublishes inactive or fully-reviewed low-scoring relations. Legacy unreviewed rows stay visible unless p_unpublish_unreviewed is true.';

revoke all on function public.refresh_relation_publish_gate(smallint, real, boolean) from public;
grant execute on function public.refresh_relation_publish_gate(smallint, real, boolean) to service_role;

-- Safe cutover: existing active public catalog rows should remain visible when
-- web/mobile start filtering by `published`. Fully-reviewed low-score rows are
-- excluded so the scheduled gate can continue from the same rule set.
update public.link_skill_relations lsr
   set published = true,
       published_at = coalesce(lsr.published_at, now()),
       updated_at = now()
  from public.links l
 where l.id = lsr.link_id
   and lsr.is_active = true
   and l.is_active = true
   and lsr.published = false
   and (
     lsr.curator_reviews < 2
     or lsr.curator_score >= 2.0
   );

select cron.schedule(
  'relation_publish_gate_15min',
  '*/15 * * * *',
  $$select public.refresh_relation_publish_gate(2::smallint, 2.0::real, false);$$
)
where not exists (select 1 from cron.job where jobname = 'relation_publish_gate_15min');

commit;
