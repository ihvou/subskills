begin;

create extension if not exists pgtap;

select plan(1);

insert into public.suggestions (type, status, origin_type, payload_json, dedupe_key)
values
  (
    'LINK_UPVOTE_SKILL',
    'approved',
    'agent',
    '{"link_id":"00000000-0000-4000-8000-000000000301","target_skill_id":"00000000-0000-4000-8000-000000000101"}',
    'duplicate-key'
  );

select throws_ok(
  $$insert into public.suggestions (type, status, origin_type, payload_json, dedupe_key)
    values (
      'LINK_UPVOTE_SKILL',
      'pending',
      'agent',
      '{"link_id":"00000000-0000-4000-8000-000000000301","target_skill_id":"00000000-0000-4000-8000-000000000101"}',
      'duplicate-key'
    )$$,
  '23505',
  'duplicate key value violates unique constraint "suggestions_active_dedupe_key_idx"',
  'active suggestion dedupe key is unique across approved and pending'
);

select * from finish();
rollback;
