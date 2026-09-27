begin;

-- M115: user votes should affect ranking, never publication. combined_score
-- remains the ranking/UI score; publication uses the generated curation-only
-- curator_score = relevance_vote + value_vote.
comment on column public.link_skill_relations.combined_score is
  'Ranking score: curator_score plus damped community-vote contribution. Not used as the publication gate.';

create or replace function public.refresh_relation_publish_gate(
  p_min_reviews smallint default 2,
  p_min_score real default 1.3,
  p_unpublish_unreviewed boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_min_reviews smallint := greatest(coalesce(p_min_reviews, 2), 1);
  v_min_score real := coalesce(p_min_score, 1.3);
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
    'unpublish_unreviewed', p_unpublish_unreviewed,
    'score_column', 'curator_score',
    'ranking_column', 'combined_score'
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
  'Publishes fully-reviewed active relations using curator_score only; combined_score remains the ranking score.';

revoke all on function public.refresh_relation_publish_gate(smallint, real, boolean) from public;
grant execute on function public.refresh_relation_publish_gate(smallint, real, boolean) to service_role;

create or replace function public.refresh_relation_publish_gate_one(
  p_relation_id uuid,
  p_min_reviews smallint default 2,
  p_min_score real default 1.3
)
returns boolean
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_min_reviews smallint := greatest(coalesce(p_min_reviews, 2), 1);
  v_min_score real := coalesce(p_min_score, 1.3);
  v_should_publish boolean;
  v_published boolean;
begin
  select
    (
      lsr.is_active
      and l.is_active
      and lsr.curator_reviews >= v_min_reviews
      and lsr.curator_score >= v_min_score
    ),
    lsr.published
  into v_should_publish, v_published
  from public.link_skill_relations lsr
  join public.links l on l.id = lsr.link_id
  where lsr.id = p_relation_id;

  if v_should_publish is null then
    return null;
  end if;

  if v_should_publish is distinct from v_published then
    update public.link_skill_relations lsr
       set published = v_should_publish,
           published_at = case when v_should_publish then coalesce(lsr.published_at, now()) else null end,
           updated_at = now()
     where lsr.id = p_relation_id;
  end if;

  return v_should_publish;
end;
$fn$;

comment on function public.refresh_relation_publish_gate_one(uuid, smallint, real) is
  'Publishes/unpublishes one relation using curator_score only. Cheap per-vote path; combined_score remains ranking.';

revoke all on function public.refresh_relation_publish_gate_one(uuid, smallint, real) from public;
grant execute on function public.refresh_relation_publish_gate_one(uuid, smallint, real) to service_role;

-- MI27: the local-first user_actions bridge is deprecated. Keep the table for
-- historical rows, but stop clients from reading/writing it; active state lives
-- in user_bookmarks, user_watched and user_relation_votes.
drop policy if exists "contributors read own actions" on public.user_actions;
drop policy if exists "contributors insert own actions" on public.user_actions;
drop policy if exists "contributors delete own actions" on public.user_actions;
drop policy if exists "contributors update own action timestamps" on public.user_actions;

revoke select, insert, update, delete on public.user_actions from anon, authenticated;

comment on table public.user_actions is
  'Deprecated legacy local-first action table. Client writes are disabled; use user_bookmarks, user_watched and user_relation_votes.';

commit;
