-- 0032: re-review mislabelled difficulty tags, without touching the edge function.
--
-- PROBLEM. The combined-coach rubric told the model "intermediate = the DEFAULT
-- tutorial" and "when unsure, use intermediate". It obeyed: published content is
-- 64.7% intermediate / 23.0% beginner / 10.4% advanced, 19 sub-skills have ZERO
-- beginner-labelled items, and 448 of 1,629 published intermediate rows have
-- intro-style titles ("How to PROPERLY Deadlift for Growth (5 Easy Steps)",
-- "How To: Deep Barbell Back Squat"). Both apps ship a Beginner filter, so a
-- beginner filtering to "Beginner" — the most natural thing a beginner does —
-- hits an empty shelf on 19 sub-skills while good beginner material sits there
-- mislabelled. See docs/taxonomy-audit-2026-08.md §6.
--
-- WHY THIS IS A MIGRATION AND NOT A PROMPT EDIT. get_untagged_for_difficulty
-- filters `skill_level is null`, so already-tagged rows are invisible to it.
-- Simply flipping that to `= 'intermediate'` loops forever: re-confirming a row
-- as intermediate leaves it matching the filter, so the same 30 rows come back
-- every hour and the cursor never advances. A progress marker is required, and
-- link_skill_relations had no column recording that difficulty was reviewed.
--
-- WHY A TRIGGER. The hosted coach-curation edge function is AHEAD of this repo:
-- it serves `difficulty_queue` and `tag` actions that are absent from
-- supabase/functions/coach-curation/index.ts, so redeploying it from source
-- would silently break difficulty tagging. Its `tag` action performs a direct
-- UPDATE (there is no set_skill_level RPC), so a `BEFORE UPDATE OF skill_level`
-- trigger catches every tag write without any function change. `UPDATE OF` fires
-- whenever the column appears in the SET list — including a write that re-confirms
-- the SAME value, which is exactly what has to advance the cursor.
begin;

alter table public.link_skill_relations
  add column if not exists skill_level_reviewed_at timestamptz;

comment on column public.link_skill_relations.skill_level_reviewed_at is
  'Set automatically whenever skill_level is written. NULL means difficulty has never been judged under the corrected rubric, which is what puts a row in the difficulty queue. Stamped by trigger, never by hand.';

create or replace function public.stamp_skill_level_reviewed()
returns trigger
language plpgsql
set search_path = public
as $fn$
begin
  -- Stamped on every write to skill_level, including one that re-confirms the
  -- existing value: "the coach looked at this row" is the fact we need, not
  -- "the value changed". Without that, confirmed-intermediate rows never leave
  -- the queue and the routine loops forever.
  new.skill_level_reviewed_at := now();
  return new;
end;
$fn$;

drop trigger if exists link_skill_relations_stamp_skill_level_reviewed on public.link_skill_relations;
create trigger link_skill_relations_stamp_skill_level_reviewed
  before update of skill_level on public.link_skill_relations
  for each row
  execute function public.stamp_skill_level_reviewed();

-- Keeps the queue scan cheap as the reviewed set grows.
create index if not exists link_skill_relations_difficulty_queue_idx
  on public.link_skill_relations (created_at, id)
  where is_active and skill_level_reviewed_at is null;

-- The queue now serves TWO populations, so the existing `difficulty_queue` edge
-- action drives both jobs with no code change:
--   1. never-tagged rows (skill_level is null) — the original backfill
--   2. published rows tagged 'intermediate' that predate the corrected rubric
-- Rows tagged beginner/advanced are NOT re-reviewed: the bias ran toward
-- intermediate, so those were deliberate calls. Unpublished rows are excluded —
-- only published content is visible to a learner, and including it would roughly
-- double the work for no user-visible gain.
--
-- Return shape gains current_level, so the routine can tell a fresh tag from a
-- re-review and phrase its judgement accordingly. Changing the shape needs a
-- DROP; safe because only service_role may execute it and the routine is paused.
drop function if exists public.get_untagged_for_difficulty(integer);

create function public.get_untagged_for_difficulty(
  p_limit integer default 20
) returns table (
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
  v_limit := least(greatest(coalesce(p_limit, 20), 1), 30);

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
  'Difficulty queue: rows whose skill_level has never been judged under the corrected rubric (skill_level_reviewed_at is null) — either never tagged, or tagged intermediate by the old "default to intermediate" rubric and published. Never-tagged rows sort first. Returns a 3500-char transcript excerpt plus current_level; default 20 / cap 30. Consumed via the coach-curation edge function.';

revoke all on function public.get_untagged_for_difficulty(integer) from public, anon, authenticated;
grant execute on function public.get_untagged_for_difficulty(integer) to service_role;

commit;
