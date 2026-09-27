begin;

create extension if not exists pgtap;

select plan(6);

insert into auth.users (id, email, aud, role, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-4000-8000-00000000f101', 'vote-one@example.com', 'authenticated', 'authenticated', '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-4000-8000-00000000f102', 'vote-two@example.com', 'authenticated', 'authenticated', '{}'::jsonb, '{}'::jsonb, now(), now())
on conflict (id) do nothing;

insert into public.links (id, url, canonical_url, domain, title, content_type)
values (
  '00000000-0000-4000-8000-00000000b801',
  'https://example.com/vote-semantics',
  'https://example.com/vote-semantics',
  'example.com',
  'Vote semantics fixture',
  'video'
)
on conflict (canonical_url) do nothing;

insert into public.link_skill_relations (id, link_id, skill_id, is_active)
values
  ('00000000-0000-4000-8000-00000000b811', '00000000-0000-4000-8000-00000000b801', '00000000-0000-4000-8000-000000000101', true),
  ('00000000-0000-4000-8000-00000000b812', '00000000-0000-4000-8000-00000000b801', '00000000-0000-4000-8000-000000000102', true),
  ('00000000-0000-4000-8000-00000000b813', '00000000-0000-4000-8000-00000000b801', '00000000-0000-4000-8000-000000000103', true)
on conflict (link_id, skill_id) do nothing;

insert into public.user_actions (user_id, link_id, link_skill_relation_id, action_type)
values (
  '00000000-0000-4000-8000-00000000f101',
  '00000000-0000-4000-8000-00000000b801',
  '00000000-0000-4000-8000-00000000b811',
  'upvote'
);

select results_eq(
  $$select upvote_count, downvote_count, vote_score
    from public.link_skill_relations
    where id = '00000000-0000-4000-8000-00000000b811'::uuid$$,
  $$values (1, 0, 1)$$,
  'upvote increments only the voted relation'
);

select results_eq(
  $$select count(*)::integer
    from public.link_skill_relations
    where id in (
      '00000000-0000-4000-8000-00000000b812'::uuid,
      '00000000-0000-4000-8000-00000000b813'::uuid
    )
      and upvote_count = 0
      and downvote_count = 0
      and vote_score = 0$$,
  $$values (2)$$,
  'sibling relations for the same link are untouched'
);

insert into public.user_actions (user_id, link_id, link_skill_relation_id, action_type)
values (
  '00000000-0000-4000-8000-00000000f102',
  '00000000-0000-4000-8000-00000000b801',
  '00000000-0000-4000-8000-00000000b811',
  'downvote'
);

select results_eq(
  $$select upvote_count, downvote_count, vote_score
    from public.link_skill_relations
    where id = '00000000-0000-4000-8000-00000000b811'::uuid$$,
  $$values (1, 1, 0)$$,
  'downvote increments downvote_count instead of decrementing upvote_count'
);

insert into public.user_actions (user_id, link_id, link_skill_relation_id, action_type)
values (
  '00000000-0000-4000-8000-00000000f101',
  '00000000-0000-4000-8000-00000000b801',
  '00000000-0000-4000-8000-00000000b812',
  'downvote'
);

select results_eq(
  $$select upvote_count, downvote_count, vote_score
    from public.link_skill_relations
    where id = '00000000-0000-4000-8000-00000000b812'::uuid$$,
  $$values (0, 1, 0)$$,
  'fresh downvote does not make the displayed score negative'
);

delete from public.user_actions
where user_id = '00000000-0000-4000-8000-00000000f102'::uuid
  and link_skill_relation_id = '00000000-0000-4000-8000-00000000b811'::uuid
  and action_type = 'downvote';

select results_eq(
  $$select upvote_count, downvote_count, vote_score
    from public.link_skill_relations
    where id = '00000000-0000-4000-8000-00000000b811'::uuid$$,
  $$values (1, 0, 1)$$,
  'deleting a downvote only decrements downvote_count'
);

select throws_ok(
  $$insert into public.user_actions (user_id, link_id, action_type)
    values (
      '00000000-0000-4000-8000-00000000f102',
      '00000000-0000-4000-8000-00000000b801',
      'upvote'
    )$$,
  '23514',
  'Vote actions require link_skill_relation_id',
  'vote actions require relation context'
);

select * from finish();
rollback;
