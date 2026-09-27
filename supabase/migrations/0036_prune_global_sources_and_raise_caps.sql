-- 0033: remove the windsurfing "global" sources, purge the junk they produced,
--       and raise the coach/difficulty queue caps for cloud Routines.
--
-- (1) THE BUG. loadChannels() in scripts/run-collection.mjs selects sources with
--     `(category_id is null or category_id = $1)`, so a channel with no category
--     is searched for EVERY skill in EVERY category. The six such rows are all
--     WINDSURFING channels — leftovers from a category that does not exist in the
--     catalogue (there are 13 categories and none of them is windsurfing).
--
--     Cost: Padel searched 8 channels of which only 2 were padel; Badminton 9 of
--     which 3 were badminton. A large share of nightly search time went to
--     windsurfing channels looking for badminton footwork.
--
--     They also produced 187 relations such as "Windsurfing at Home - Wave Ride
--     Simulation" attached to Badminton "Serve (low)" and Gym (women) "Lat
--     pulldown". The coach correctly rejected every one (0 of 187 published) —
--     but 145 are still sitting unreviewed, i.e. ~5 coach batches of guaranteed
--     rejections. Deactivated here rather than deleted, so it is reversible.
--
-- (2) CAPS. 0031 sized the queues for cloud Routines at 30. The coach backlog is
--     now 5,842 (the routine was down 14 Jul - 11 Aug while collection kept
--     running), which is ~8 days at 30/hour. Raising the ceiling to 60 lets the
--     routine request larger batches; the prompt should move up gradually and
--     watch that runs still complete, since each row costs three curl calls.
begin;

-- ---- (1a) retire the windsurfing sources -------------------------------------
update public.trusted_sources
   set is_active = false
 where source_type = 'youtube_channel'
   and category_id is null;

-- ---- (1b) retire the junk they already produced ------------------------------
-- Scoped to relations that are still UNREVIEWED: reviewed ones were already
-- rejected and are harmless, and leaving them keeps the audit trail intact.
update public.link_skill_relations lsr
   set is_active = false
  from public.links l
 where l.id = lsr.link_id
   and lsr.is_active
   and not lsr.published
   and (l.title ilike '%windsurf%' or l.title ilike '%wingfoil%' or l.title ilike '%wing foil%')
   and not exists (
     select 1 from public.curator_votes cv
      where cv.link_skill_relation_id = lsr.id
        and cv.coach_role = 'relevance'
   );

-- ---- (2a) coach queue: cap 30 -> 60 ------------------------------------------
create or replace function public.get_unscored_for_coach(
  p_coach_role text,
  p_limit integer default 30
) returns table (
  relation_id uuid, source text, title text, description text, url text,
  duration_seconds numeric, like_count integer, comment_count integer,
  share_count integer, favorite_count integer, creator_handle text,
  skill_name text, category_name text, transcript text
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

  v_limit := least(greatest(coalesce(p_limit, 30), 1), 60);

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
      left(l.description, 300) as description,
      l.canonical_url as url,
      l.duration_seconds,
      l.like_count,
      l.comment_count,
      l.share_count,
      l.favorite_count,
      l.creator_handle,
      s.name as skill_name,
      c.name as category_name,
      left(lt.transcript_text, 5000) as transcript
    from public.link_skill_relations lsr
    join public.links l on l.id = lsr.link_id
    join public.skills s on s.id = lsr.skill_id
    join public.categories c on c.id = s.category_id
    left join public.link_transcripts lt on lt.link_id = l.id
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

comment on function public.get_unscored_for_coach(text, integer) is
  'Combined-coach queue: unvoted active relations with a 5000-char transcript excerpt + 300-char description, default 30 / cap 60. Sized for autonomous cloud Routines; raised from 30 to drain the backlog left by the 14 Jul - 11 Aug coach outage.';

revoke all on function public.get_unscored_for_coach(text, integer) from public, anon, authenticated;
grant execute on function public.get_unscored_for_coach(text, integer) to service_role;

-- ---- (2b) difficulty queue: cap 30 -> 60 -------------------------------------
-- Same body as 0032; only the cap and default change. Difficulty is cheaper than
-- the coach (one curl per row, shorter excerpt), so it tolerates larger batches.
create or replace function public.get_untagged_for_difficulty(
  p_limit integer default 30
) returns table (
  relation_id uuid, source text, title text, description text, url text,
  duration_seconds numeric, skill_name text, category_name text,
  current_level text, transcript text
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_limit integer;
begin
  v_limit := least(greatest(coalesce(p_limit, 30), 1), 60);

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
      s.name as skill_name,
      c.name as category_name,
      lsr.skill_level as current_level,
      left(lt.transcript_text, 3500) as transcript
    from public.link_skill_relations lsr
    join public.links l on l.id = lsr.link_id
    join public.skills s on s.id = lsr.skill_id
    join public.categories c on c.id = s.category_id
    join public.link_transcripts lt on lt.link_id = l.id
    where lsr.is_active = true
      and l.is_active = true
      and s.is_active = true
      and c.is_active = true
      and lsr.skill_level_reviewed_at is null
      and (
        (lsr.skill_level is null and lsr.curator_reviews >= 2)
        or (lsr.skill_level = 'intermediate' and lsr.published = true)
      )
    order by (lsr.skill_level is not null), lsr.created_at asc, lsr.id asc
    limit v_limit;
end;
$fn$;

comment on function public.get_untagged_for_difficulty(integer) is
  'Difficulty queue: rows whose skill_level has never been judged under the corrected rubric. Never-tagged rows sort first. 3500-char transcript excerpt + current_level; default 30 / cap 60.';

revoke all on function public.get_untagged_for_difficulty(integer) from public, anon, authenticated;
grant execute on function public.get_untagged_for_difficulty(integer) to service_role;

commit;
