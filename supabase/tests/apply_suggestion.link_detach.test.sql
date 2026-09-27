begin;

create extension if not exists pgtap;

select plan(4);

insert into public.links (id, url, canonical_url, domain, title, content_type, is_active)
values (
  '00000000-0000-4000-8000-00000000d101',
  'https://example.com/stale-resource',
  'https://example.com/stale-resource',
  'example.com',
  'Stale resource',
  'article',
  true
);

insert into public.link_skill_relations (link_id, skill_id, public_note, skill_level, is_active)
values (
  '00000000-0000-4000-8000-00000000d101',
  '00000000-0000-4000-8000-000000000101',
  'Previously relevant.',
  'beginner',
  true
);

insert into public.suggestions (id, type, status, origin_type, skill_id, link_id, payload_json, dedupe_key, confidence)
values (
  '00000000-0000-4000-8000-00000000d201',
  'LINK_DETACH_SKILL',
  'pending',
  'agent',
  '00000000-0000-4000-8000-000000000101',
  '00000000-0000-4000-8000-00000000d101',
  jsonb_build_object(
    'link_id', '00000000-0000-4000-8000-00000000d101',
    'target_skill_id', '00000000-0000-4000-8000-000000000101',
    'reason', 'Re-check no longer supports this skill.'
  ),
  'test-link-detach',
  0.800
);

select is(
  (public.apply_suggestion_transaction('00000000-0000-4000-8000-00000000d201'::uuid, null)->>'ok')::boolean,
  true,
  'LINK_DETACH_SKILL apply returns ok'
);

select results_eq(
  $$select is_active
    from public.link_skill_relations
    where link_id = '00000000-0000-4000-8000-00000000d101'::uuid
      and skill_id = '00000000-0000-4000-8000-000000000101'::uuid$$,
  $$values (false)$$,
  'LINK_DETACH_SKILL deactivates the relation'
);

select results_eq(
  $$select is_active from public.links where id = '00000000-0000-4000-8000-00000000d101'::uuid$$,
  $$values (false)$$,
  'LINK_DETACH_SKILL deactivates orphaned links'
);

select results_eq(
  $$select status::text from public.suggestions where id = '00000000-0000-4000-8000-00000000d201'::uuid$$,
  $$values ('approved'::text)$$,
  'LINK_DETACH_SKILL marks the suggestion approved'
);

select * from finish();
rollback;
