begin;

alter table public.link_skill_relations
add column if not exists relevance_vote real,
add column if not exists value_vote real,
add column if not exists curator_score real
  generated always as (
    coalesce(relevance_vote, 0::real) + coalesce(value_vote, 0::real)
  ) stored,
add column if not exists curator_reviews smallint
  generated always as (
    ((relevance_vote is not null)::integer + (value_vote is not null)::integer)::smallint
  ) stored;

comment on column public.link_skill_relations.relevance_vote is
  'Shadow relevance coach vote in [-2, 2], maintained from curator_votes.';
comment on column public.link_skill_relations.value_vote is
  'Shadow value coach vote in [-2, 2], maintained from curator_votes.';
comment on column public.link_skill_relations.curator_score is
  'Shadow aggregate score: relevance_vote + value_vote; not used for ranking until cutover.';
comment on column public.link_skill_relations.curator_reviews is
  'Shadow review count from the two curator coach roles.';

create table if not exists public.curator_votes (
  id uuid primary key default gen_random_uuid(),
  link_skill_relation_id uuid not null
    references public.link_skill_relations(id) on delete cascade,
  coach_role text not null check (coach_role in ('relevance', 'value')),
  weight real not null check (weight >= -2 and weight <= 2),
  comment_internal text,
  comment_public text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (link_skill_relation_id, coach_role)
);

comment on table public.curator_votes is
  'Shadow two-coach scoring votes for Learning Path ranking cutover.';

create index if not exists curator_votes_relation_role_idx
on public.curator_votes (link_skill_relation_id, coach_role);

create index if not exists curator_votes_role_created_idx
on public.curator_votes (coach_role, created_at);

drop trigger if exists curator_votes_set_updated_at on public.curator_votes;
create trigger curator_votes_set_updated_at
before update on public.curator_votes
for each row execute function public.set_updated_at();

alter table public.curator_votes enable row level security;

drop policy if exists "curator votes are public" on public.curator_votes;
create policy "curator votes are public"
on public.curator_votes for select
to anon, authenticated
using (true);

revoke insert, update, delete on public.curator_votes from anon, authenticated;
grant select on public.curator_votes to anon, authenticated;

create or replace function public.refresh_curator_vote_aggregates(p_relation_id uuid)
returns void
language sql
security definer
set search_path = public
as $fn$
  update public.link_skill_relations lsr
     set relevance_vote = (
           select cv.weight
             from public.curator_votes cv
            where cv.link_skill_relation_id = p_relation_id
              and cv.coach_role = 'relevance'
            limit 1
         ),
         value_vote = (
           select cv.weight
             from public.curator_votes cv
            where cv.link_skill_relation_id = p_relation_id
              and cv.coach_role = 'value'
            limit 1
         ),
         updated_at = now()
   where lsr.id = p_relation_id;
$fn$;

revoke all on function public.refresh_curator_vote_aggregates(uuid) from public;

create or replace function public.sync_curator_vote_aggregates()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    perform public.refresh_curator_vote_aggregates(old.link_skill_relation_id);
  end if;

  if tg_op in ('INSERT', 'UPDATE')
     and (tg_op <> 'UPDATE' or new.link_skill_relation_id is distinct from old.link_skill_relation_id) then
    perform public.refresh_curator_vote_aggregates(new.link_skill_relation_id);
  end if;

  return coalesce(new, old);
end;
$fn$;

revoke all on function public.sync_curator_vote_aggregates() from public;

drop trigger if exists curator_votes_sync_aggregates on public.curator_votes;
create trigger curator_votes_sync_aggregates
after insert or update or delete on public.curator_votes
for each row execute function public.sync_curator_vote_aggregates();

create or replace function public.get_unscored_for_coach(
  p_coach_role text,
  p_limit integer default 10
) returns table (
  relation_id uuid,
  source text,
  title text,
  description text,
  url text,
  duration_seconds numeric,
  like_count integer,
  comment_count integer,
  share_count integer,
  favorite_count integer,
  creator_handle text,
  skill_name text,
  category_name text
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_limit integer;
begin
  if p_coach_role not in ('relevance', 'value') then
    raise exception 'invalid coach_role: %', p_coach_role;
  end if;

  v_limit := least(greatest(coalesce(p_limit, 10), 1), 100);

  return query
    select
      lsr.id as relation_id,
      case
        when lower(l.domain) like '%tiktok.com%' or lower(l.url) like '%tiktok.com%' then 'tiktok'
        when lower(l.domain) like '%youtube.com%'
          or lower(l.domain) like '%youtu.be%'
          or lower(l.url) like '%youtube.com%'
          or lower(l.url) like '%youtu.be%' then 'youtube'
        else 'other'
      end as source,
      l.title,
      l.description,
      l.canonical_url as url,
      l.duration_seconds,
      l.like_count,
      l.comment_count,
      l.share_count,
      l.favorite_count,
      l.creator_handle,
      s.name as skill_name,
      c.name as category_name
    from public.link_skill_relations lsr
    join public.links l on l.id = lsr.link_id
    join public.skills s on s.id = lsr.skill_id
    join public.categories c on c.id = s.category_id
    where lsr.is_active = true
      and l.is_active = true
      and s.is_active = true
      and c.is_active = true
      and not exists (
        select 1
          from public.curator_votes cv
         where cv.link_skill_relation_id = lsr.id
           and cv.coach_role = p_coach_role
      )
    order by lsr.created_at asc, lsr.id asc
    limit v_limit;
end;
$fn$;

revoke all on function public.get_unscored_for_coach(text, integer) from public;
grant execute on function public.get_unscored_for_coach(text, integer) to anon, authenticated;

create or replace function public.set_curator_vote(
  p_relation_id uuid,
  p_coach_role text,
  p_weight real,
  p_comment_internal text default null,
  p_comment_public text default null
) returns void
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if p_coach_role not in ('relevance', 'value') then
    raise exception 'invalid coach_role: %', p_coach_role;
  end if;

  if p_weight is null or p_weight < -2 or p_weight > 2 then
    raise exception 'invalid curator vote weight: %', p_weight;
  end if;

  if not exists (
    select 1
      from public.link_skill_relations lsr
      join public.links l on l.id = lsr.link_id
      join public.skills s on s.id = lsr.skill_id
      join public.categories c on c.id = s.category_id
     where lsr.id = p_relation_id
       and lsr.is_active = true
       and l.is_active = true
       and s.is_active = true
       and c.is_active = true
  ) then
    raise exception 'active link_skill_relation not found: %', p_relation_id;
  end if;

  insert into public.curator_votes (
    link_skill_relation_id,
    coach_role,
    weight,
    comment_internal,
    comment_public
  )
  values (
    p_relation_id,
    p_coach_role,
    p_weight,
    nullif(p_comment_internal, ''),
    nullif(p_comment_public, '')
  )
  on conflict (link_skill_relation_id, coach_role) do update
     set weight = excluded.weight,
         comment_internal = excluded.comment_internal,
         comment_public = excluded.comment_public,
         updated_at = now();
end;
$fn$;

revoke all on function public.set_curator_vote(uuid, text, real, text, text) from public;
grant execute on function public.set_curator_vote(uuid, text, real, text, text) to anon, authenticated;

commit;
