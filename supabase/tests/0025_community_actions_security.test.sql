begin;

create extension if not exists pgtap;

select plan(10);

select is(
  has_function_privilege('anon', 'public.set_curator_vote(uuid,text,real,text,text)', 'execute'),
  false,
  'anon cannot execute set_curator_vote'
);

select is(
  has_function_privilege('authenticated', 'public.set_curator_vote(uuid,text,real,text,text)', 'execute'),
  false,
  'authenticated cannot execute set_curator_vote'
);

select is(
  has_function_privilege('service_role', 'public.set_curator_vote(uuid,text,real,text,text)', 'execute'),
  true,
  'service_role can execute set_curator_vote'
);

select is(
  has_function_privilege('anon', 'public.get_unscored_for_coach(text,integer)', 'execute'),
  false,
  'anon cannot execute get_unscored_for_coach'
);

select is(
  has_function_privilege('authenticated', 'public.get_unscored_for_coach(text,integer)', 'execute'),
  false,
  'authenticated cannot execute get_unscored_for_coach'
);

select is(
  has_function_privilege('authenticated', 'public.set_user_vote(uuid,smallint)', 'execute'),
  true,
  'authenticated users can execute set_user_vote'
);

insert into auth.users (id, email, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values (
  '00000000-0000-4000-8000-00000000d501',
  'community-voter@example.com',
  'authenticated',
  'authenticated',
  '{}'::jsonb,
  '{}'::jsonb,
  now(),
  now()
)
on conflict (id) do nothing;

insert into public.links (id, url, canonical_url, domain, title, content_type, is_active)
values (
  '00000000-0000-4000-8000-00000000d511',
  'https://example.com/community-vote',
  'https://example.com/community-vote',
  'example.com',
  'Community vote fixture',
  'video',
  true
)
on conflict (canonical_url) do nothing;

insert into public.link_skill_relations (id, link_id, skill_id, is_active, published, relevance_vote, value_vote)
values (
  '00000000-0000-4000-8000-00000000d521',
  '00000000-0000-4000-8000-00000000d511',
  '00000000-0000-4000-8000-000000000101',
  true,
  true,
  1.0,
  0.5
)
on conflict (link_id, skill_id) do update
set is_active = excluded.is_active,
    published = excluded.published,
    relevance_vote = excluded.relevance_vote,
    value_vote = excluded.value_vote;

select is(
  has_table_privilege('authenticated', 'public.user_actions', 'insert'),
  false,
  'authenticated users cannot write deprecated user_actions'
);

reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-00000000d501","email":"community-voter@example.com","user_metadata":{}}';

select results_eq(
  $$select vote, user_score, combined_score from public.set_user_vote('00000000-0000-4000-8000-00000000d521'::uuid, 1::smallint)$$,
  $$values (1::smallint, 1::real, 2.0::real)$$,
  'set_user_vote records one authenticated vote and returns the combined score'
);

reset role;

select results_eq(
  $$select upvote_count, downvote_count, vote_score, user_score, combined_score
      from public.link_skill_relations
     where id = '00000000-0000-4000-8000-00000000d521'::uuid$$,
  $$values (1, 0, 1, 1::real, 2.0::real)$$,
  'relation counters and combined_score are synchronized from user_relation_votes'
);

select results_eq(
  $$select user_id, link_skill_relation_id, vote
      from public.user_relation_votes
     where user_id = '00000000-0000-4000-8000-00000000d501'::uuid$$,
  $$values ('00000000-0000-4000-8000-00000000d501'::uuid, '00000000-0000-4000-8000-00000000d521'::uuid, 1::smallint)$$,
  'user_relation_votes stores one private relation vote'
);

select * from finish();
rollback;
