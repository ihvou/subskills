begin;

create extension if not exists pgtap;

select plan(6);

insert into public.links (id, url, canonical_url, domain, title, content_type, is_active)
values
  (
    '00000000-0000-4000-8000-00000052a001',
    'https://example.com/curation-low-votes-high',
    'https://example.com/curation-low-votes-high',
    'example.com',
    'Low curation, high community score',
    'video',
    true
  ),
  (
    '00000000-0000-4000-8000-00000052a002',
    'https://example.com/curation-high-votes-low',
    'https://example.com/curation-high-votes-low',
    'example.com',
    'High curation, low community score',
    'video',
    true
  ),
  (
    '00000000-0000-4000-8000-00000052a003',
    'https://example.com/curation-single-gate',
    'https://example.com/curation-single-gate',
    'example.com',
    'Single gate low curation fixture',
    'video',
    true
  )
on conflict (canonical_url) do nothing;

insert into public.link_skill_relations (
  id,
  link_id,
  skill_id,
  is_active,
  published,
  relevance_vote,
  value_vote,
  user_score,
  combined_score
)
values
  (
    '00000000-0000-4000-8000-00000052b001',
    '00000000-0000-4000-8000-00000052a001',
    '00000000-0000-4000-8000-000000000101',
    true,
    false,
    -0.2,
    0.0,
    3.0,
    1.3
  ),
  (
    '00000000-0000-4000-8000-00000052b002',
    '00000000-0000-4000-8000-00000052a002',
    '00000000-0000-4000-8000-000000000101',
    true,
    false,
    1.0,
    0.5,
    -3.0,
    0.0
  ),
  (
    '00000000-0000-4000-8000-00000052b003',
    '00000000-0000-4000-8000-00000052a003',
    '00000000-0000-4000-8000-000000000101',
    true,
    true,
    -0.2,
    0.0,
    3.0,
    1.3
  )
on conflict (link_id, skill_id) do update
set is_active = excluded.is_active,
    published = excluded.published,
    relevance_vote = excluded.relevance_vote,
    value_vote = excluded.value_vote,
    user_score = excluded.user_score,
    combined_score = excluded.combined_score;

select is(
  (select curator_score from public.link_skill_relations where id = '00000000-0000-4000-8000-00000052b001'::uuid),
  -0.2::real,
  'low-curation fixture has curation score below the gate'
);

select is(
  (select combined_score from public.link_skill_relations where id = '00000000-0000-4000-8000-00000052b001'::uuid),
  1.3::real,
  'low-curation fixture still has enough combined score to prove votes are not the gate'
);

select is(
  (public.refresh_relation_publish_gate(2::smallint, 1.3::real, false)->>'published_count')::integer,
  1,
  'full publish gate promotes only the curation-approved relation'
);

select is(
  (select published from public.link_skill_relations where id = '00000000-0000-4000-8000-00000052b001'::uuid),
  false,
  'full publish gate does not publish low-curation content with enough community score'
);

select is(
  (select published from public.link_skill_relations where id = '00000000-0000-4000-8000-00000052b002'::uuid),
  true,
  'full publish gate can publish curation-approved content even when community votes lower combined score'
);

update public.link_skill_relations
set published = true
where id = '00000000-0000-4000-8000-00000052b003'::uuid;

select is(
  public.refresh_relation_publish_gate_one('00000000-0000-4000-8000-00000052b003'::uuid, 2::smallint, 1.3::real),
  false,
  'single-relation gate also unpublishes low-curation content despite enough combined score'
);

select * from finish();
rollback;
