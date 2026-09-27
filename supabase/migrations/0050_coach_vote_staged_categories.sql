-- 0050: let the coach STORE votes for staged categories, not just receive them.
--
-- THE BREAK. Migration 0046 removed the `c.is_active` filter from
-- get_unscored_for_coach() so the coach could review the seven categories that sit
-- inactive while they fill. It did not make the matching change to
-- set_curator_vote() (0018), which still requires `c.is_active = true` and raises
-- `active link_skill_relation not found` otherwise. So the coach was handed work it
-- was then forbidden to record: every vote call threw, the edge function returned
-- 500, and the routine reported "Storage failure - scores were NOT saved."
--
-- WHY IT WAS TOTAL, NOT PARTIAL. get_unscored_for_coach orders by
-- `coalesce(sp.pub, 0) asc` (0040: scarcest skill first). A staged category has zero
-- published rows by definition, so its relations sort to the FRONT of every batch.
-- The coach therefore drew nothing but unvotable rows. Curation went from ~2,880
-- votes/day (08-13..08-18) to 108 on 08-19 to 0 on 08-20, with 519 relations backed
-- up behind it, 469 of them in staged categories.
--
-- THE FIX. Drop `c.is_active` here too. 0046 already made the argument and it holds
-- on this side of the pipe: `s.is_active` is the correct lever for retiring content,
-- and category staging is a RENDERING decision, not a curation one. Keeping the
-- filter in either function re-creates the same deadlock -- collect, never review,
-- never publish, so the category can never be switched on.
--
-- The publish gate is unaffected: it tests curator_reviews and combined_score, and
-- the site never renders an inactive category. Staged content becomes reviewed and
-- publishable, and stays invisible until someone flips the category on -- which is
-- the entire point of staging it.
begin;

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
     where lsr.id = p_relation_id
       and lsr.is_active = true
       and l.is_active = true
       and s.is_active = true
    -- 0050: the categories join and its `c.is_active = true` test are GONE, to match
    -- get_unscored_for_coach() after 0046. A staged category must be reviewable or
    -- it can never earn its way to being switched on. s.is_active still applies.
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

comment on function public.set_curator_vote(uuid, text, real, text, text) is
  'Records one coach vote. Requires the relation, link and SKILL to be active; deliberately does NOT require the category to be active, so staged categories can be curated before they are switched on (see 0046 and 0050).';

revoke all on function public.set_curator_vote(uuid, text, real, text, text) from public;
grant execute on function public.set_curator_vote(uuid, text, real, text, text) to anon, authenticated;

commit;
