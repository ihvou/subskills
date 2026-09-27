-- 0040: order the coach queue by scarcity, not by a binary visibility threshold.
--
-- 0038 floated rows whose skill sat below the 3-published visibility line. That was
-- the right shape at the time — the urgent goal was getting every skill visible, and
-- a single boolean is self-limiting. It worked: 88 skills went from zero content to
-- 248 of 249 visible in a day.
--
-- Having succeeded, it went inert. Every skill now clears the threshold, so the
-- boolean is uniformly true and the ordering collapsed back to pure created_at FIFO
-- — which means the old July backlog, and that backlog belongs to the original
-- (already thick) skills. Measured 2026-08-15: of everything published that day,
-- 205 rows went to skills with 30+ published, 47 to 15-29, 18 to 6-14, and ZERO to
-- skills under 6, while 565 rows for thin skills sat behind 2,835 rows for thicker
-- ones. Collection was doing its part throughout — the previous night put 258 rows
-- on thin skills and none on thick — so the mismatch was entirely in review order.
--
-- Replacing the boolean with the published count itself keeps the same self-limiting
-- property, just continuously: a skill at 3 gets reviewed, rises to 8, and yields to
-- skills still at 3-4. The frontier advances on its own, so nothing starves — thick
-- skills are simply served last.
--
-- Side benefit: the deprioritised rows are the low-yield ones. Content collected
-- before the query tuning, open search and the source cleanup passes at ~37%, versus
-- ~57% for newer content, so scarcity order also raises published-per-review.
--
-- Everything else — excerpt sizes, caps, filters, cost (~132 ms) — is unchanged.
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
    -- Scarcest skill first; oldest first within a skill so it stays deterministic.
    order by coalesce(sp.pub, 0) asc,
             lsr.created_at asc,
             lsr.id asc
    limit v_limit;
end;
$fn$;

comment on function public.get_unscored_for_coach(text, integer) is
  'Combined-coach queue: unvoted active relations, 5000-char transcript excerpt + 300-char description, default 30 / cap 60. Ordered by the skill''s PUBLISHED count ascending, then oldest-first — so review effort follows scarcity and does not undo the collector''s own thin-skill-first rotation.';

revoke all on function public.get_unscored_for_coach(text, integer) from public, anon, authenticated;
grant execute on function public.get_unscored_for_coach(text, integer) to service_role;

commit;
