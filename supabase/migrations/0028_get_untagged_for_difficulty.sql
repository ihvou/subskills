-- 0028: backfill queue for difficulty tags.
--
-- skill_level (beginner|intermediate|advanced) used to be set by the Ollama
-- scorer at collection time. When Ollama was unwired (commit 9bcb888) collection
-- began submitting candidates unscored, and the coaches judge relevance/value but
-- never assign difficulty — so ~71% of active relations are now untagged. This
-- RPC feeds a "difficulty-backfill" routine that re-tags relations the coaches
-- have ALREADY reviewed (curator_reviews >= 2) but that still lack a skill_level.
--
-- Requires a transcript (inner join): difficulty is judged from content, so rows
-- without a transcript (e.g. TikTok) are intentionally out of scope here.
-- Mirrors get_unscored_for_coach's row shape so the routine reads it the same way.
begin;

create or replace function public.get_untagged_for_difficulty(
  p_limit integer default 25
) returns table (
  relation_id uuid,
  source text,
  title text,
  description text,
  url text,
  duration_seconds numeric,
  skill_name text,
  category_name text,
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
  v_limit := least(greatest(coalesce(p_limit, 25), 1), 100);

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
      lt.transcript_text as transcript
    from public.link_skill_relations lsr
    join public.links l on l.id = lsr.link_id
    join public.skills s on s.id = lsr.skill_id
    join public.categories c on c.id = s.category_id
    join public.link_transcripts lt on lt.link_id = l.id
    where lsr.is_active = true
      and l.is_active = true
      and s.is_active = true
      and c.is_active = true
      and lsr.skill_level is null
      and lsr.curator_reviews >= 2
    order by lsr.created_at asc, lsr.id asc
    limit v_limit;
end;
$fn$;

comment on function public.get_untagged_for_difficulty(integer) is
  'Backfill queue: active, coach-reviewed (curator_reviews>=2) relations that still lack a skill_level and have a transcript. Read via the coach-curation edge function by the difficulty-backfill routine.';

revoke all on function public.get_untagged_for_difficulty(integer) from public, anon, authenticated;
grant execute on function public.get_untagged_for_difficulty(integer) to service_role;

commit;
