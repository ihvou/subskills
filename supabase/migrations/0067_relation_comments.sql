-- 0067: comments on a video in a sub-skill, starting with the coach's two.
--
-- WHAT THIS IS. Every published video carries two coach votes. Until now the page
-- showed one line of them as "Coach's take" (link_skill_relations.coach_take).
-- From here they are comments by two internal authors:
--   Moderator — what the video covers: the relevance coach's comment_internal.
--   Reviewer  — the verdict: the value coach's comment_public, falling back to the
--               relevance coach's, which is the same pick coach_take has always made.
-- The web card shows the two newest and a popup shows them in full. Nobody else can
-- post yet (M170); user_id and is_hidden exist for that and are unused for now.
--
-- ONE COMMENT PER AUTHOR PER RELATION. A re-score edits the comment in place: body
-- and updated_at change, id and created_at do not. So the count and the order on the
-- card stay put instead of growing with every coach run.
--
-- ORDER. created_at is the source vote's created_at, so "newest first" follows the
-- coach's own sequence. It writes the relevance vote and then the value vote, which
-- puts the Reviewer above the Moderator on 99.97% of relations (35,683 of 35,693,
-- measured on hosted 2026-09-24).
--
-- KEPT IN SYNC BY A TRIGGER on curator_votes, beside curator_votes_sync_aggregates,
-- so the coach routine and the coach-curation edge function need no code change.
-- The backfill at the end runs the same function once for every relation with votes.
--
-- coach_take is left exactly as it is: the mobile app still selects it.

begin;

insert into public.internal_users (id, display_name, is_agent_actor)
values
  ('00000000-0000-4000-8000-000000000204', 'Moderator', true),
  ('00000000-0000-4000-8000-000000000205', 'Reviewer', true)
on conflict (id) do update
set display_name = excluded.display_name,
    is_active = true;

-- Comment authors are now shown on public pages, so the public can read their names
-- and nothing else. The table was readable in full through its "internal users are
-- public" policy; the remaining columns are internal bookkeeping.
revoke select on public.internal_users from anon, authenticated;
grant select (id, display_name, is_active) on public.internal_users to anon, authenticated;

create table if not exists public.relation_comments (
  id uuid primary key default gen_random_uuid(),
  link_skill_relation_id uuid not null
    references public.link_skill_relations(id) on delete cascade,
  internal_user_id uuid references public.internal_users(id),
  user_id uuid references auth.users(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 4000),
  is_hidden boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint relation_comments_one_author check (num_nonnulls(internal_user_id, user_id) = 1)
);

create unique index if not exists relation_comments_one_per_internal_author
  on public.relation_comments (link_skill_relation_id, internal_user_id)
  where internal_user_id is not null;

create index if not exists relation_comments_by_relation_newest
  on public.relation_comments (link_skill_relation_id, created_at desc);

drop trigger if exists relation_comments_set_updated_at on public.relation_comments;
create trigger relation_comments_set_updated_at
before update on public.relation_comments
for each row execute function public.set_updated_at();

alter table public.relation_comments enable row level security;

drop policy if exists "comments on published relations are public" on public.relation_comments;
create policy "comments on published relations are public"
on public.relation_comments
for select
to anon, authenticated
using (
  not is_hidden
  and exists (
    select 1
    from public.link_skill_relations r
    where r.id = relation_comments.link_skill_relation_id
      and r.is_active
      and r.published
  )
);

revoke all on public.relation_comments from anon, authenticated;
grant select on public.relation_comments to anon, authenticated;
grant all on public.relation_comments to service_role;

create or replace function public.refresh_relation_comments(p_relation_id uuid)
returns void
language plpgsql
set search_path = public
as $fn$
declare
  v_moderator constant uuid := '00000000-0000-4000-8000-000000000204';
  v_reviewer constant uuid := '00000000-0000-4000-8000-000000000205';
  v_body text;
  v_at timestamptz;
begin
  -- A relation being deleted cascades to its votes, and each vote delete fires the
  -- sync trigger. The relation is already gone by then, and inserting a comment for
  -- it would fail the foreign key and abort the delete.
  if not exists (select 1 from public.link_skill_relations where id = p_relation_id) then
    return;
  end if;

  select btrim(cv.comment_internal), cv.created_at
    into v_body, v_at
    from public.curator_votes cv
   where cv.link_skill_relation_id = p_relation_id
     and cv.coach_role = 'relevance'
     and nullif(btrim(cv.comment_internal), '') is not null
   order by cv.updated_at desc
   limit 1;

  if v_body is null then
    delete from public.relation_comments
     where link_skill_relation_id = p_relation_id
       and internal_user_id = v_moderator;
  else
    insert into public.relation_comments (link_skill_relation_id, internal_user_id, body, created_at)
    values (p_relation_id, v_moderator, v_body, v_at)
    on conflict (link_skill_relation_id, internal_user_id) where internal_user_id is not null
    do update set body = excluded.body
     where relation_comments.body is distinct from excluded.body;
  end if;

  select btrim(cv.comment_public), cv.created_at
    into v_body, v_at
    from public.curator_votes cv
   where cv.link_skill_relation_id = p_relation_id
     and nullif(btrim(cv.comment_public), '') is not null
   order by case cv.coach_role when 'value' then 0 else 1 end, cv.updated_at desc
   limit 1;

  if v_body is null then
    delete from public.relation_comments
     where link_skill_relation_id = p_relation_id
       and internal_user_id = v_reviewer;
  else
    insert into public.relation_comments (link_skill_relation_id, internal_user_id, body, created_at)
    values (p_relation_id, v_reviewer, v_body, v_at)
    on conflict (link_skill_relation_id, internal_user_id) where internal_user_id is not null
    do update set body = excluded.body
     where relation_comments.body is distinct from excluded.body;
  end if;
end;
$fn$;

revoke all on function public.refresh_relation_comments(uuid) from public, anon, authenticated;
grant execute on function public.refresh_relation_comments(uuid) to service_role;

create or replace function public.sync_relation_comments_from_votes()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    perform public.refresh_relation_comments(old.link_skill_relation_id);
  end if;

  if tg_op in ('INSERT', 'UPDATE')
     and (tg_op <> 'UPDATE' or new.link_skill_relation_id is distinct from old.link_skill_relation_id) then
    perform public.refresh_relation_comments(new.link_skill_relation_id);
  end if;

  return coalesce(new, old);
end;
$fn$;

revoke all on function public.sync_relation_comments_from_votes() from public, anon, authenticated;

drop trigger if exists curator_votes_sync_comments on public.curator_votes;
create trigger curator_votes_sync_comments
after insert or update or delete on public.curator_votes
for each row execute function public.sync_relation_comments_from_votes();

do $backfill$
declare
  v_relation uuid;
begin
  for v_relation in select distinct link_skill_relation_id from public.curator_votes loop
    perform public.refresh_relation_comments(v_relation);
  end loop;
end;
$backfill$;

commit;
