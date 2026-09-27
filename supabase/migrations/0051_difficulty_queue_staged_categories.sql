-- 0051: stop the difficulty queue hiding staged categories.
--
-- Third and last function carrying the `c.is_active = true` filter. The story so far:
--
--   0046  removed it from get_unscored_for_coach() so the seven categories staged
--         inactive while they fill could be reviewed at all.
--   0050  removed it from set_curator_vote(), which had kept it — so the coach was
--         handed work it was then forbidden to record. Every vote raised
--         "active link_skill_relation not found", the edge function returned 500, and
--         curation went from ~2,880 votes/day to zero.
--
-- get_untagged_for_difficulty() still has it. Today it hides exactly 0 rows, because no
-- staged-category relation has yet reached `curator_reviews >= 2` or been published, so
-- nothing satisfies the rest of the predicate. That is precisely why it is worth fixing
-- now rather than later: the moment BJJ, Climbing and Golf start publishing, this begins
-- dropping rows, and unlike the 0050 break it fails SILENTLY. No exception, no 500 — the
-- queue simply returns fewer rows and the routine reports "nothing to judge" while a
-- growing pile of staged content goes untagged. That is much harder to notice than an
-- outage, and the difficulty tag is user-visible on every card.
--
-- Same argument as 0046 and 0050: `s.is_active` is the lever for retiring content, while
-- category staging is a RENDERING decision. The categories join stays — `c.name` is in the
-- returned columns — only the is_active test goes.
--
-- Body is otherwise byte-identical to the deployed definition (0036 lineage): same
-- limit clamp, same transcript inner join (difficulty is judged FROM the transcript, so a
-- row without one is correctly unqueueable), same intermediate-only recheck predicate,
-- same ordering.
begin;

create or replace function public.get_untagged_for_difficulty(p_limit integer default 30)
returns table (
  relation_id uuid,
  source text,
  title text,
  description text,
  url text,
  duration_seconds numeric,
  skill_name text,
  category_name text,
  current_level text,
  transcript text
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
    -- INNER on purpose: the difficulty call is a judgement about the content, so a
    -- relation with no transcript is not judgeable and must not be queued. 69 rows sit
    -- in that state today; only the nightly fetching captions will clear them.
    join public.link_transcripts lt on lt.link_id = l.id
    where lsr.is_active = true
      and l.is_active = true
      and s.is_active = true
      -- 0051: `and c.is_active = true` is GONE, to match get_unscored_for_coach (0046)
      -- and set_curator_vote (0050). A staged category must be tagged before it is
      -- switched on, or it goes live with every card missing its difficulty pill.
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
  'Rows awaiting a difficulty judgement: never-tagged with >=2 curator reviews, or tagged `intermediate` and published (the old rubric over-applied that level). Requires an active relation, link and SKILL, and a transcript; deliberately does NOT require the category to be active, so staged categories are tagged before they go live (see 0046, 0050, 0051).';

revoke all on function public.get_untagged_for_difficulty(integer) from public, anon, authenticated;
grant execute on function public.get_untagged_for_difficulty(integer) to service_role;

commit;
