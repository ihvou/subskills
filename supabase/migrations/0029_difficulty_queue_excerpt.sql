-- 0029: shrink the difficulty-backfill queue so the routine reads it INLINE.
--
-- 0028's queue returned the FULL transcript for up to 25 rows — a response large
-- enough that the runner saves it to a file, which pushed the difficulty-backfill
-- routine to improvise ad-hoc parsing (python heredocs, grep). Those commands trip
-- the permission allow-list (and the "expansion obfuscation" heuristic) and prompt
-- on every run. Difficulty (beginner/intermediate/advanced) only needs the OPENING
-- of the transcript, so return a 2000-char excerpt and a smaller default/cap; the
-- whole response then fits in the curl output and needs no parsing at all.
begin;

create or replace function public.get_untagged_for_difficulty(
  p_limit integer default 10
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
  v_limit := least(greatest(coalesce(p_limit, 10), 1), 25);

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
      left(lt.transcript_text, 2000) as transcript
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
  'Backfill queue (excerpt edition): active, coach-reviewed (curator_reviews>=2) relations lacking skill_level, with a 2000-char transcript EXCERPT and a small default/cap so the difficulty-backfill routine reads the response inline (no parsing). Via the coach-curation edge function.';

revoke all on function public.get_untagged_for_difficulty(integer) from public, anon, authenticated;
grant execute on function public.get_untagged_for_difficulty(integer) to service_role;

commit;
