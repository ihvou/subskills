begin;

create extension if not exists pgtap;

select plan(6);

insert into public.suggestions (id, type, status, origin_type, category_id, skill_id, payload_json, dedupe_key, confidence)
values (
  '00000000-0000-4000-8000-00000000a101',
  'LINK_ADD',
  'pending',
  'agent',
  '00000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000101',
  jsonb_build_object(
    'url', 'https://example.com/badminton-clear-article',
    'canonical_url', 'https://example.com/badminton-clear-article',
    'domain', 'example.com',
    'title', 'Forehand clear technique',
    'description', 'A focused article about forehand clear mechanics.',
    'content_type', 'article',
    'language', 'en',
    'target_skill_id', '00000000-0000-4000-8000-000000000101',
    'public_note', 'Clear mechanics for overhead forehand clears.',
    'skill_level', 'beginner'
  ),
  'test-link-add-article',
  0.900
);

select is(
  (public.apply_suggestion_transaction('00000000-0000-4000-8000-00000000a101'::uuid, null)->>'ok')::boolean,
  true,
  'LINK_ADD apply returns ok'
);

select results_eq(
  $$select canonical_url from public.links where canonical_url = 'https://example.com/badminton-clear-article'$$,
  $$values ('https://example.com/badminton-clear-article'::text)$$,
  'LINK_ADD upserts the link'
);

select results_eq(
  $$select lsr.is_active
    from public.link_skill_relations lsr
    join public.links l on l.id = lsr.link_id
    where l.canonical_url = 'https://example.com/badminton-clear-article'
      and lsr.skill_id = '00000000-0000-4000-8000-000000000101'::uuid$$,
  $$values (true)$$,
  'LINK_ADD creates an active skill relation'
);

select results_eq(
  $$select lsr.published
    from public.link_skill_relations lsr
    join public.links l on l.id = lsr.link_id
    where l.canonical_url = 'https://example.com/badminton-clear-article'
      and lsr.skill_id = '00000000-0000-4000-8000-000000000101'::uuid$$,
  $$values (false)$$,
  'LINK_ADD keeps new skill relations unpublished'
);

select results_eq(
  $$select status::text from public.suggestions where id = '00000000-0000-4000-8000-00000000a101'::uuid$$,
  $$values ('approved'::text)$$,
  'LINK_ADD marks the suggestion approved'
);

select results_eq(
  $$select link_id is not null from public.suggestions where id = '00000000-0000-4000-8000-00000000a101'::uuid$$,
  $$values (true)$$,
  'LINK_ADD stores the applied link id on the suggestion'
);

select * from finish();
rollback;
