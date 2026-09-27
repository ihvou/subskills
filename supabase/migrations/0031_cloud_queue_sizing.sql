-- 0031: re-size the coach + difficulty queues for CLOUD Routines.
--
-- 0029/0030 shrank both queues to tiny batches (coach cap 8, difficulty cap 25)
-- with short transcript excerpts SOLELY to dodge the LOCAL scheduled-task failure
-- mode: a large curl response made the runner save it to a file and improvise a
-- parser (python heredoc / jq), which tripped Claude Code's permission
-- "expansion obfuscation" guard and HUNG the unattended run.
--
-- We are moving these routines to Claude Code CLOUD Routines (they run on Anthropic
-- infrastructure, not this Mac). Cloud routines run fully autonomously with NO
-- permission prompts, so that whole stall mode cannot happen — the inline-read size
-- constraint no longer applies. The remaining limit is just throughput: at 8 coach
-- rows/run hourly (=192/day) the coach can't keep up with the ~317-525/day inflow.
--
-- So raise the caps (coach 8->30, difficulty 25->30) and enlarge the transcript
-- excerpts modestly (coach 3000->5000, difficulty 2000->3500) for better scoring,
-- while keeping batches bounded so per-run token cost stays sane. The cloud routine
-- requests an explicit limit per run; the cap is the safety ceiling.
begin;

-- ---- combined-coach queue ----------------------------------------------------
create or replace function public.get_unscored_for_coach(
  p_coach_role text,
  p_limit integer default 20
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
  'Combined-coach queue (cloud sizing): unvoted active relations with a 5000-char transcript excerpt + 300-char description, default 20 / cap 30. Sized for autonomous CLOUD Routines (no inline-read constraint); throughput keeps up with daily inflow. Transcript exposed only via this security-definer RPC.';

revoke all on function public.get_unscored_for_coach(text, integer) from public, anon, authenticated;
grant execute on function public.get_unscored_for_coach(text, integer) to service_role;

-- ---- difficulty-backfill queue -----------------------------------------------
create or replace function public.get_untagged_for_difficulty(
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
      and lsr.skill_level is null
      and lsr.curator_reviews >= 2
    order by lsr.created_at asc, lsr.id asc
    limit v_limit;
end;
$fn$;

comment on function public.get_untagged_for_difficulty(integer) is
  'Backfill queue (cloud sizing): active, coach-reviewed (curator_reviews>=2) relations lacking skill_level, with a 3500-char transcript excerpt, default 20 / cap 30. Sized for autonomous CLOUD Routines. Via the coach-curation edge function.';

revoke all on function public.get_untagged_for_difficulty(integer) from public, anon, authenticated;
grant execute on function public.get_untagged_for_difficulty(integer) to service_role;

commit;
