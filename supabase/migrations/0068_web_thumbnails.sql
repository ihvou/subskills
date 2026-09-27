-- 0068: web thumbnails rehosted on Cloudflare R2 (img.subskills.xyz).
--
-- WHY. The web used to show each video's thumbnail from where the platform keeps
-- it, and those addresses name the video: i.ytimg.com/vi/<video id>/…, and our own
-- storage keys thumbnails/tiktok/<video id>.jpg and thumbnails/instagram/reel-<code>.jpg.
-- That undid the /go links, which exist to keep video addresses off the page. It
-- also sent every visitor's browser to YouTube's image servers.
--
-- WHAT. scripts/rehost-thumbnails.mjs resizes each video's thumbnail to a 640 px
-- WebP, unmodified otherwise, and uploads it to R2 under a name made from a hash
-- of the image, which says nothing about the video. The key lands here.
--
-- WEB ONLY. The mobile app keeps reading thumbnail_url and thumbnail_storage_path,
-- exactly as before, and its get_latest_skill_thumbnails is untouched. The web
-- gets its own function below, returning only the key.

begin;

alter table public.links add column if not exists web_thumbnail_key text;

comment on column public.links.web_thumbnail_key is
  'Object key of the web thumbnail on R2, served at https://img.subskills.xyz/<key>. '
  'A 640 px WebP named by a hash of the image, so it never names the video. Written '
  'by scripts/rehost-thumbnails.mjs; null until then. Web only: the app reads '
  'thumbnail_url and thumbnail_storage_path.';

-- The latest published video per skill that has a web thumbnail: the artwork for
-- the home page's skill tiles and the previous/next links on a skill page.
-- SECURITY INVOKER, so anon reads through the same public policies as everywhere
-- else (published active relations, active links) and 0066's rule on definer
-- functions has nothing to allow.
create or replace function public.get_latest_skill_web_thumbnails(p_skill_ids uuid[])
returns table (skill_id uuid, web_thumbnail_key text)
language sql
stable
security invoker
set search_path = public
as $fn$
  select distinct on (lsr.skill_id)
    lsr.skill_id,
    l.web_thumbnail_key
  from public.link_skill_relations lsr
  join public.links l on l.id = lsr.link_id
  where lsr.skill_id = any(p_skill_ids)
    and lsr.is_active
    and lsr.published
    and l.is_active
    and l.web_thumbnail_key is not null
  order by lsr.skill_id, lsr.created_at desc;
$fn$;

revoke all on function public.get_latest_skill_web_thumbnails(uuid[]) from public;
grant execute on function public.get_latest_skill_web_thumbnails(uuid[]) to anon, authenticated, service_role;

commit;
