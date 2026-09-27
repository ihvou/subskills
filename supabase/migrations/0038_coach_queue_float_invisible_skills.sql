-- 0038: float content for not-yet-visible skills to the front of the coach queue.
--
-- THE MISMATCH. The two halves of the pipeline disagreed about priority:
--   * collection rotates skills by PUBLISHED count ascending, so the thinnest and
--     newest skills are collected first (migration-era change in run-collection.mjs)
--   * the coach queue ordered strictly `lsr.created_at asc` — oldest first, with no
--     regard for which skill the row belongs to
-- So collection carefully prioritised a starved skill and the coach then buried its
-- output behind weeks of backlog. Measured 2026-08-13: the coach was reviewing
-- content created 18-22 July while 4,129 rows sat ahead of the content collected for
-- the 97 new sub-skills, i.e. 3.5-5 days before it would even be looked at. 100
-- skills were under 3 published with 593 rows waiting behind that same backlog.
--
-- THE CHANGE. One boolean added ahead of the existing FIFO key: rows belonging to a
-- skill that is not yet VISIBLE sort first, and everything else keeps its existing
-- oldest-first order.
--
-- Deliberately a single boolean rather than full scarcity ranking:
--   * it targets exactly the problem — getting a skill over the visibility line
--   * it is self-limiting. Once a skill reaches the threshold it rejoins normal FIFO,
--     so no skill can monopolise the queue and nothing starves permanently.
--   * within each group the order is still created_at, so it stays deterministic.
--
-- The threshold mirrors getPublishMinResources() in apps/web/lib/data.ts (default 3,
-- overridable via COLLECT_PUBLISH_MIN_RESOURCES). If that default ever changes, change
-- v_visible_threshold to match — otherwise the queue would optimise for a line the UI
-- no longer draws.
--
-- Cost: the per-skill aggregate is one grouped pass, measured at ~132 ms for the
-- hourly LIMIT 50 call against production. Everything else — excerpt sizes, caps,
-- filters — is unchanged from 0036.
begin;

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
  v_visible_threshold constant integer := 3;
begin
  if p_coach_role not in ('relevance', 'value') then
    raise exception 'invalid coach_role: %', p_coach_role;
  end if;

  v_limit := least(greatest(coalesce(p_limit, 30), 1), 60);

  return query
    with skill_pub as (
      select r.skill_id, count(*) filter (where r.is_active and r.published) as pub
      from public.link_skill_relations r
      group by r.skill_id
    )
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
    join skill_pub sp on sp.skill_id = lsr.skill_id
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
    -- false (skill not yet visible) sorts before true, so starved skills lead.
    order by (coalesce(sp.pub, 0) >= v_visible_threshold) asc,
             lsr.created_at asc,
             lsr.id asc
    limit v_limit;
end;
$fn$;

comment on function public.get_unscored_for_coach(text, integer) is
  'Combined-coach queue: unvoted active relations, 5000-char transcript excerpt + 300-char description, default 30 / cap 60. Rows for skills below the 3-published visibility threshold sort FIRST, then oldest-first within each group — so collection prioritising starved skills is not undone by a strict FIFO review order. Threshold mirrors getPublishMinResources().';

revoke all on function public.get_unscored_for_coach(text, integer) from public, anon, authenticated;
grant execute on function public.get_unscored_for_coach(text, integer) to service_role;

commit;
