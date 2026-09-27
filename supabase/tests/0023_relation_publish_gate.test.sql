begin;

create extension if not exists pgtap;

select plan(5);

insert into public.links (id, url, canonical_url, domain, title, content_type, is_active)
values
  (
    '00000000-0000-4000-8000-00000000c901',
    'https://example.com/publish-gate-good',
    'https://example.com/publish-gate-good',
    'example.com',
    'Publish gate good',
    'video',
    true
  ),
  (
    '00000000-0000-4000-8000-00000000c902',
    'https://example.com/publish-gate-legacy',
    'https://example.com/publish-gate-legacy',
    'example.com',
    'Publish gate legacy',
    'video',
    true
  ),
  (
    '00000000-0000-4000-8000-00000000c903',
    'https://example.com/publish-gate-low',
    'https://example.com/publish-gate-low',
    'example.com',
    'Publish gate low',
    'video',
    true
  )
on conflict (canonical_url) do nothing;

insert into public.link_skill_relations (id, link_id, skill_id, is_active, published)
values
  (
    '00000000-0000-4000-8000-00000000c911',
    '00000000-0000-4000-8000-00000000c901',
    '00000000-0000-4000-8000-000000000101',
    true,
    false
  ),
  (
    '00000000-0000-4000-8000-00000000c912',
    '00000000-0000-4000-8000-00000000c902',
    '00000000-0000-4000-8000-000000000102',
    true,
    true
  ),
  (
    '00000000-0000-4000-8000-00000000c913',
    '00000000-0000-4000-8000-00000000c903',
    '00000000-0000-4000-8000-000000000103',
    true,
    true
  )
on conflict (link_id, skill_id) do update
set is_active = excluded.is_active,
    published = excluded.published;

select public.set_curator_vote('00000000-0000-4000-8000-00000000c911'::uuid, 'relevance', 1.0, null, null);
select public.set_curator_vote('00000000-0000-4000-8000-00000000c911'::uuid, 'value', 1.5, null, null);
select public.set_curator_vote('00000000-0000-4000-8000-00000000c913'::uuid, 'relevance', -1.0, null, null);
select public.set_curator_vote('00000000-0000-4000-8000-00000000c913'::uuid, 'value', 0.0, null, null);

select is(
  (public.refresh_relation_publish_gate(2::smallint, 2.0::real, false)->>'published_count')::integer,
  1,
  'publish gate promotes one fully reviewed high-score relation'
);

select is(
  (select published from public.link_skill_relations where id = '00000000-0000-4000-8000-00000000c911'::uuid),
  true,
  'high-score reviewed relation is published'
);

select is(
  (select published from public.link_skill_relations where id = '00000000-0000-4000-8000-00000000c912'::uuid),
  true,
  'legacy unreviewed published relation remains visible by default'
);

select is(
  (select published from public.link_skill_relations where id = '00000000-0000-4000-8000-00000000c913'::uuid),
  false,
  'fully reviewed low-score relation is unpublished'
);

select isnt_empty(
  $$select 1 from public.relation_publish_gate_runs where published_count >= 1 and unpublished_count >= 1$$,
  'publish gate writes an audit row'
);

select * from finish();
rollback;
