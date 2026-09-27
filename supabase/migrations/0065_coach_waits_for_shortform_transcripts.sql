-- 0065: give short-form a chance to be transcribed before the coach judges it.
--
-- Committed on 2026-09-09 as a SECOND 0058, beside 0058_app_events. Two files
-- cannot share a version: `supabase db start` stopped on a duplicate key in
-- schema_migrations, which is why CI's database job failed from then on. Hosted
-- had applied it by hand but could only record one 0058 (app_events). The body is
-- unchanged. It replaces get_unscored_for_coach wholesale, and nothing after it
-- touches that function, so running last yields the same final definition.
--
-- THE RACE. Transcripts for TikTok and Instagram are produced out of band by
-- scripts/fetch-shortform-transcripts.mjs, the same shape as the YouTube
-- gap-filler. The coach queue LEFT JOINs link_transcripts, so a reel shared at
-- 10:00 can be served to the coach at 10:05, scored on its title alone, and
-- reach a verdict before the transcript ever arrives. The transcript then lands
-- on an already-decided relation and changes nothing.
--
-- That is precisely the metadata-scoring behaviour the short-form pipeline work
-- exists to remove, so it must not be reintroduced through timing.
--
-- THE FIX, AND WHY IT IS BOUNDED. Hold back short-form relations that have no
-- transcript yet — but only for a window, not forever. Some clips genuinely
-- cannot be transcribed: a music-only demo or a song produces no usable speech
-- and the gap-filler deliberately stores nothing for it. An unbounded wait would
-- park those relations permanently, invisible to both the coach and the
-- operator. After the window they flow through and are scored on metadata,
-- exactly as a caption-less YouTube video already is.
--
-- YouTube is untouched: its transcript is attached at submit time in
-- evidence_json, so there is nothing to wait for.
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
  -- How long a short-form relation waits for its transcript before being
  -- scored on metadata instead. The gap-filler runs far more often than this;
  -- the window only has to outlast a backlog, not a single pass.
  v_shortform_grace interval := interval '24 hours';
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
        when lower(l.domain) like '%instagram.com%' or lower(l.url) like '%instagram.com%' then 'instagram'
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
      -- 0046/0050/0051: no category is_active filter, so staged categories can
      -- be reviewed before they are switched on.
      and coalesce(lsr.review_lane, 'coach') = 'coach'
      and not exists (
        select 1
          from public.curator_votes cv
         where cv.link_skill_relation_id = lsr.id
           and cv.coach_role = p_coach_role
      )
      -- 0058: a short-form link with no transcript yet waits, but only until the
      -- grace window expires.
      and (
        lt.link_id is not null
        or lsr.created_at < now() - v_shortform_grace
        or not (
          lower(l.url) like '%tiktok.com%'
          or lower(l.url) like '%instagram.com%'
          or lower(coalesce(l.domain, '')) like '%tiktok.com%'
          or lower(coalesce(l.domain, '')) like '%instagram.com%'
        )
      )
    -- Unchanged from 0057: user submissions first, then scarcest skill, then
    -- oldest. Reproduced verbatim rather than reformatted so a future diff of
    -- these two migrations shows only the transcript predicate.
    order by case when lsr.submitted_by_user_id is not null then 0 else 1 end asc,
             coalesce(sp.pub, 0) asc,
             lsr.created_at asc,
             lsr.id asc
    limit v_limit;
end;
$fn$;

comment on function public.get_unscored_for_coach(text, integer) is
  'Relations awaiting a coach vote, in the coach review lane. Scarcest skill first, user submissions ahead of collector output. Ignores category is_active so staged categories can be reviewed (0046/0050/0051). Holds back short-form links whose transcript has not arrived yet, for 24h, so they are judged on content rather than on their title (0058).';

revoke all on function public.get_unscored_for_coach(text, integer) from public, anon, authenticated;
grant execute on function public.get_unscored_for_coach(text, integer) to service_role;

commit;
