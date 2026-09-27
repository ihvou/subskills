-- 0030: shrink the combined-coach queue so it reads INLINE (no improvised parsing).
--
-- The combined-coach pulled 25 FULL transcripts per run — a response large enough
-- that the runner saves it to a file, pushing the model to improvise a parser
-- (python heredocs) that trips the permission "expansion obfuscation" guard and
-- HANGS the run. Observed 2026-06-24→25: the coach stalled ~16h on exactly this
-- (last vote 06-24 21:16, no runs since, while the difficulty-backfill ran fine).
--
-- Same fix as the difficulty queue (0029): return a transcript EXCERPT (3000 chars
-- — bigger than the 2000 difficulty excerpt, since the coach needs more for the
-- value/teaching-quality judgment) + a truncated description, and cap the batch
-- small (8) so 8 rows fit in the curl output (~28 KB). Throughput is kept up by
-- running the routine every 15 min instead of hourly. Only the combined-coach
-- consumes this RPC (the separate relevance/value coaches are disabled).
begin;

create or replace function public.get_unscored_for_coach(
  p_coach_role text,
  p_limit integer default 8
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

  v_limit := least(greatest(coalesce(p_limit, 8), 1), 8);

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
      left(lt.transcript_text, 3000) as transcript
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
  'Combined-coach queue (excerpt edition): unvoted active relations with a 3000-char transcript EXCERPT + 300-char description and a small cap (<=8) so the combined-coach reads the response inline, no parsing. Transcript exposed only via this security-definer RPC.';

revoke all on function public.get_unscored_for_coach(text, integer) from public, anon, authenticated;
grant execute on function public.get_unscored_for_coach(text, integer) to service_role;

commit;
