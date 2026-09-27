-- Discover screen N+1 fix.
--
-- getDiscoverSections() fetched the newest thumbnail with ONE request per skill
-- (fetchLatestSkillThumbnail). With ~152 active skills that is ~152 REST round-trips
-- on every cold start; measured ~0.28s each, so Discover sat on skeleton placeholders
-- for ~10s before rendering.
--
-- This returns the newest published resource's thumbnail for every requested skill in
-- a single round-trip. Mirrors the previous per-skill query exactly:
--   is_active + published relation, active link, newest by created_at.

begin;

create or replace function public.get_latest_skill_thumbnails(p_skill_ids uuid[])
returns table (
  skill_id uuid,
  thumbnail_url text,
  thumbnail_storage_path text,
  canonical_url text,
  url text
)
language sql
stable
security definer
set search_path = public
as $fn$
  select distinct on (lsr.skill_id)
    lsr.skill_id,
    l.thumbnail_url,
    l.thumbnail_storage_path,
    l.canonical_url,
    l.url
  from public.link_skill_relations lsr
  join public.links l on l.id = lsr.link_id
  where lsr.skill_id = any(p_skill_ids)
    and lsr.is_active = true
    and lsr.published = true
    and l.is_active = true
  order by lsr.skill_id, lsr.created_at desc;
$fn$;

comment on function public.get_latest_skill_thumbnails(uuid[]) is
  'Newest published resource thumbnail per skill, in one round-trip (Discover screen).';

revoke all on function public.get_latest_skill_thumbnails(uuid[]) from public;
grant execute on function public.get_latest_skill_thumbnails(uuid[]) to anon, authenticated;

-- Supports the distinct-on ordering above.
create index if not exists link_skill_relations_skill_created_published_idx
  on public.link_skill_relations (skill_id, created_at desc)
  where is_active and published;

commit;
