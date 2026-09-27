begin;

create extension if not exists pgtap;

select plan(7);

-- Skill 101: an older published video with a web thumbnail, a newer published one
-- without, and the newest one with a thumbnail but unpublished. Skill 102: a
-- published video with no web thumbnail. Dated 2099 so nothing in the seed is newer.
insert into public.links (id, url, canonical_url, domain, title, content_type, is_active, thumbnail_url, web_thumbnail_key)
values
  ('00000000-0000-4000-8000-00000068a001', 'https://www.youtube.com/watch?v=thumb0068aa', 'https://www.youtube.com/watch?v=thumb0068aa',
   'youtube.com', 'Older, rehosted', 'video', true, 'https://i.ytimg.com/vi/thumb0068aa/hqdefault.jpg', 'v1/older.webp'),
  ('00000000-0000-4000-8000-00000068a002', 'https://www.youtube.com/watch?v=thumb0068bb', 'https://www.youtube.com/watch?v=thumb0068bb',
   'youtube.com', 'Newer, not rehosted yet', 'video', true, 'https://i.ytimg.com/vi/thumb0068bb/hqdefault.jpg', null),
  ('00000000-0000-4000-8000-00000068a003', 'https://www.youtube.com/watch?v=thumb0068cc', 'https://www.youtube.com/watch?v=thumb0068cc',
   'youtube.com', 'Newest, unpublished', 'video', true, 'https://i.ytimg.com/vi/thumb0068cc/hqdefault.jpg', 'v1/unpublished.webp'),
  ('00000000-0000-4000-8000-00000068a004', 'https://www.youtube.com/watch?v=thumb0068dd', 'https://www.youtube.com/watch?v=thumb0068dd',
   'youtube.com', 'Other skill, not rehosted', 'video', true, 'https://i.ytimg.com/vi/thumb0068dd/hqdefault.jpg', null)
on conflict (canonical_url) do nothing;

insert into public.link_skill_relations (id, link_id, skill_id, is_active, published, created_at)
values
  ('00000000-0000-4000-8000-00000068b001', '00000000-0000-4000-8000-00000068a001', '00000000-0000-4000-8000-000000000101', true, true, '2099-01-01'),
  ('00000000-0000-4000-8000-00000068b002', '00000000-0000-4000-8000-00000068a002', '00000000-0000-4000-8000-000000000101', true, true, '2099-02-01'),
  ('00000000-0000-4000-8000-00000068b003', '00000000-0000-4000-8000-00000068a003', '00000000-0000-4000-8000-000000000101', true, false, '2099-03-01'),
  ('00000000-0000-4000-8000-00000068b004', '00000000-0000-4000-8000-00000068a004', '00000000-0000-4000-8000-000000000102', true, true, '2099-01-01')
on conflict (link_id, skill_id) do update
set is_active = excluded.is_active,
    published = excluded.published,
    created_at = excluded.created_at;

select has_column('public', 'links', 'web_thumbnail_key', 'links carries the web thumbnail key');

select is(
  (select prosecdef from pg_proc where oid = 'public.get_latest_skill_web_thumbnails(uuid[])'::regprocedure),
  false,
  'the web thumbnail function runs with the caller''s rights, not as a definer'
);

select is(
  (select web_thumbnail_key from public.get_latest_skill_web_thumbnails(
     array['00000000-0000-4000-8000-000000000101']::uuid[])),
  'v1/older.webp',
  'the latest published video that has a web thumbnail wins; newer ones without one, and unpublished ones, are skipped'
);

select is(
  (select count(*)::int from public.get_latest_skill_web_thumbnails(
     array['00000000-0000-4000-8000-000000000102']::uuid[])),
  0,
  'a skill with no rehosted thumbnail yet returns no row'
);

select is(
  (select thumbnail_url from public.get_latest_skill_thumbnails(
     array['00000000-0000-4000-8000-000000000101']::uuid[])),
  'https://i.ytimg.com/vi/thumb0068bb/hqdefault.jpg',
  'the app''s function is unchanged: still the newest published video, key or not'
);

select ok(
  has_function_privilege('anon', 'public.get_latest_skill_web_thumbnails(uuid[])', 'execute'),
  'anon can call the web thumbnail function'
);

set local role anon;

select is(
  (select web_thumbnail_key from public.get_latest_skill_web_thumbnails(
     array['00000000-0000-4000-8000-000000000101']::uuid[])),
  'v1/older.webp',
  'anon gets the same answer through the public policies'
);

reset role;

select * from finish();

rollback;
