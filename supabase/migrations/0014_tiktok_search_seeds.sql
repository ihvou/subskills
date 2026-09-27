begin;

insert into public.trusted_sources (
  source_type,
  identifier,
  display_name,
  category_id,
  origin_type,
  discovered_at,
  discovery_score,
  discovery_evidence_json,
  last_validated_at
)
select
  'tiktok_search',
  v.query,
  v.display_name,
  c.id,
  'agent',
  now(),
  12,
  jsonb_build_object(
    'source', 'manual_seed',
    'target_skill_slug', v.skill_slug,
    'collector', 'tiktok_browser_engagement_authority'
  ),
  now()
from (values
  ('badminton', 'forehand-smash', 'badminton forehand smash', 'TikTok: badminton forehand smash'),
  ('padel', 'volley', 'padel volley', 'TikTok: padel volley'),
  ('surfing', 'pop-up', 'surfing pop up', 'TikTok: surfing pop up'),
  ('yoga', 'crow-pose', 'yoga crow pose', 'TikTok: yoga crow pose')
) as v(category_slug, skill_slug, query, display_name)
join public.categories c on c.slug = v.category_slug
join public.skills s on s.category_id = c.id and s.slug = v.skill_slug
on conflict (source_type, identifier) do update set
  display_name = excluded.display_name,
  category_id = excluded.category_id,
  origin_type = coalesce(public.trusted_sources.origin_type, excluded.origin_type),
  discovery_score = greatest(coalesce(public.trusted_sources.discovery_score, 0), excluded.discovery_score),
  discovery_evidence_json = coalesce(public.trusted_sources.discovery_evidence_json, '{}'::jsonb)
    || excluded.discovery_evidence_json,
  last_validated_at = excluded.last_validated_at;

commit;
