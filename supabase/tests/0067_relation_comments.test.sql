begin;

create extension if not exists pgtap;

select plan(14);

insert into public.links (id, url, canonical_url, domain, title, content_type, is_active)
values (
  '00000000-0000-4000-8000-00000067a001',
  'https://www.youtube.com/watch?v=comment0067',
  'https://www.youtube.com/watch?v=comment0067',
  'youtube.com',
  'Comments fixture',
  'video',
  true
)
on conflict (canonical_url) do nothing;

insert into public.link_skill_relations (id, link_id, skill_id, is_active, published)
values (
  '00000000-0000-4000-8000-00000067b001',
  '00000000-0000-4000-8000-00000067a001',
  '00000000-0000-4000-8000-000000000101',
  true,
  true
)
on conflict (link_id, skill_id) do update
set is_active = true,
    published = true;

insert into public.curator_votes (link_skill_relation_id, coach_role, weight, comment_internal, comment_public)
values ('00000000-0000-4000-8000-00000067b001', 'relevance', 1.5, 'Covers the grip and the elbow.', 'On point for this shot.');

select is(
  (select body from public.relation_comments
    where link_skill_relation_id = '00000000-0000-4000-8000-00000067b001'
      and internal_user_id = '00000000-0000-4000-8000-000000000204'),
  'Covers the grip and the elbow.',
  'a relevance vote creates the Moderator comment from its internal comment'
);

select is(
  (select body from public.relation_comments
    where link_skill_relation_id = '00000000-0000-4000-8000-00000067b001'
      and internal_user_id = '00000000-0000-4000-8000-000000000205'),
  'On point for this shot.',
  'with no value vote yet, the Reviewer falls back to the relevance take'
);

insert into public.curator_votes (link_skill_relation_id, coach_role, weight, comment_internal, comment_public)
values ('00000000-0000-4000-8000-00000067b001', 'value', 1.6, 'Clear and correct.', 'Great teaching, start here.');

select is(
  (select body from public.relation_comments
    where link_skill_relation_id = '00000000-0000-4000-8000-00000067b001'
      and internal_user_id = '00000000-0000-4000-8000-000000000205'),
  'Great teaching, start here.',
  'the value take replaces the fallback as the Reviewer comment'
);

create temporary table before_rescore on commit drop as
select id, created_at
from public.relation_comments
where link_skill_relation_id = '00000000-0000-4000-8000-00000067b001'
  and internal_user_id = '00000000-0000-4000-8000-000000000204';

update public.curator_votes
set comment_internal = 'Covers the grip, the elbow and the finish.'
where link_skill_relation_id = '00000000-0000-4000-8000-00000067b001'
  and coach_role = 'relevance';

select is(
  (select count(*)::integer from public.relation_comments
    where link_skill_relation_id = '00000000-0000-4000-8000-00000067b001'),
  2,
  'a re-score keeps one comment per author'
);

select ok(
  (select c.body = 'Covers the grip, the elbow and the finish.' and c.id = b.id and c.created_at = b.created_at
     from public.relation_comments c
     join before_rescore b on b.id = c.id),
  'a re-score edits the Moderator comment in place, keeping its id and date'
);

select is(
  has_function_privilege('anon', 'public.refresh_relation_comments(uuid)', 'execute'),
  false,
  'anon cannot run the comment refresh'
);

set local role anon;

select is(
  (select count(*)::integer from public.relation_comments
    where link_skill_relation_id = '00000000-0000-4000-8000-00000067b001'),
  2,
  'anon reads the comments on a published relation'
);

select is(
  (select display_name from public.internal_users where id = '00000000-0000-4000-8000-000000000204'),
  'Moderator',
  'anon reads the author name'
);

select throws_ok(
  $$select is_agent_actor from public.internal_users limit 1$$,
  '42501',
  null,
  'anon cannot read internal bookkeeping on authors'
);

select throws_ok(
  $$insert into public.relation_comments (link_skill_relation_id, internal_user_id, body)
    values ('00000000-0000-4000-8000-00000067b001', '00000000-0000-4000-8000-000000000204', 'spam')$$,
  '42501',
  null,
  'anon cannot post a comment'
);

reset role;

update public.relation_comments
set is_hidden = true
where link_skill_relation_id = '00000000-0000-4000-8000-00000067b001'
  and internal_user_id = '00000000-0000-4000-8000-000000000205';

set local role anon;

select is(
  (select count(*)::integer from public.relation_comments
    where link_skill_relation_id = '00000000-0000-4000-8000-00000067b001'),
  1,
  'a hidden comment is not public'
);

reset role;

update public.link_skill_relations
set published = false
where id = '00000000-0000-4000-8000-00000067b001';

set local role anon;

select is(
  (select count(*)::integer from public.relation_comments
    where link_skill_relation_id = '00000000-0000-4000-8000-00000067b001'),
  0,
  'comments on an unpublished relation are not public'
);

reset role;

select lives_ok(
  $$delete from public.link_skill_relations where id = '00000000-0000-4000-8000-00000067b001'$$,
  'deleting a relation with votes and comments succeeds'
);

select is(
  (select count(*)::integer from public.relation_comments
    where link_skill_relation_id = '00000000-0000-4000-8000-00000067b001'),
  0,
  'its comments go with it'
);

select * from finish();
rollback;
