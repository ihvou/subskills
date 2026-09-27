-- Review fix for M84 (0025): set_user_vote ran a FULL-TABLE publish-gate refresh on
-- every vote (refresh_relation_publish_gate), which scans all active relations, issues
-- two table-wide UPDATEs, and appends a relation_publish_gate_runs audit row per vote.
-- At user scale that is lock contention on link_skill_relations + audit-log bloat.
--
-- This adds a single-relation gate and re-points set_user_vote at it. The 15-min cron
-- still runs the full reconciliation; per-vote we only touch the one relation that
-- changed. combined_score is already current here (the user_relation_votes trigger
-- refreshes it before this runs), so the decision still holds: a downvote that pulls a
-- borderline relation below 1.3 unpublishes it immediately.

begin;

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
      and lsr.combined_score >= v_min_score
    ),
    lsr.published
  into v_should_publish, v_published
  from public.link_skill_relations lsr
  join public.links l on l.id = lsr.link_id
  where lsr.id = p_relation_id;

  -- Relation (or its link) not found: nothing to do.
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
  'Publishes/unpublishes a SINGLE relation by combined_score (curator_reviews >= min). Cheap per-vote path; the cron still does full reconciliation.';

revoke all on function public.refresh_relation_publish_gate_one(uuid, smallint, real) from public;
grant execute on function public.refresh_relation_publish_gate_one(uuid, smallint, real) to service_role;

-- Re-point set_user_vote at the single-relation gate (identical to 0025 except the gate call).
create or replace function public.set_user_vote(
  p_relation_id uuid,
  p_vote smallint
) returns table (
  link_skill_relation_id uuid,
  vote smallint,
  user_score real,
  combined_score real,
  published boolean
)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_user_id uuid := auth.uid();
  v_relation_id uuid;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  if p_vote is null or p_vote not in (-1, 0, 1) then
    raise exception 'invalid user vote: %', p_vote;
  end if;

  select lsr.id
    into v_relation_id
    from public.link_skill_relations lsr
    join public.links l on l.id = lsr.link_id
    join public.skills s on s.id = lsr.skill_id
    join public.categories c on c.id = s.category_id
   where lsr.id = p_relation_id
     and lsr.is_active = true
     and (
       lsr.published = true
       or exists (
         select 1
           from public.user_relation_votes existing_vote
          where existing_vote.user_id = v_user_id
            and existing_vote.link_skill_relation_id = lsr.id
       )
     )
     and l.is_active = true
     and s.is_active = true
     and c.is_active = true;

  if v_relation_id is null then
    raise exception 'published link_skill_relation not found: %', p_relation_id using errcode = 'P0002';
  end if;

  if p_vote = 0 then
    delete from public.user_relation_votes urv
     where urv.user_id = v_user_id
       and urv.link_skill_relation_id = p_relation_id;
  else
    insert into public.user_relation_votes (
      user_id,
      link_skill_relation_id,
      vote
    )
    values (v_user_id, p_relation_id, p_vote)
    on conflict (user_id, link_skill_relation_id) do update
       set vote = excluded.vote,
           updated_at = now();
  end if;

  -- Single-relation gate (was a full-table refresh in 0025). The user_relation_votes
  -- trigger has already refreshed combined_score for this relation above.
  perform public.refresh_relation_publish_gate_one(p_relation_id, 2::smallint, 1.3::real);

  return query
    select
      lsr.id,
      coalesce(urv.vote, 0)::smallint,
      lsr.user_score,
      lsr.combined_score,
      lsr.published
    from public.link_skill_relations lsr
    left join public.user_relation_votes urv
      on urv.link_skill_relation_id = lsr.id
     and urv.user_id = v_user_id
    where lsr.id = p_relation_id;
end;
$fn$;

revoke all on function public.set_user_vote(uuid, smallint) from public;
grant execute on function public.set_user_vote(uuid, smallint) to authenticated;

commit;
