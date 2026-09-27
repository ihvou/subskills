begin;

create extension if not exists pgtap;

select plan(3);

insert into public.moderators (email, is_active)
values ('rls-moderator@example.com', true)
on conflict (email) do update set is_active = true;

insert into public.suggestions (type, status, origin_type, payload_json, dedupe_key)
values (
  'LINK_ADD',
  'pending',
  'agent',
  '{"url":"https://example.com/rls","canonical_url":"https://example.com/rls","target_skill_id":"00000000-0000-4000-8000-000000000101"}'::jsonb,
  'rls-real-test'
);

set local role anon;
select is_empty(
  $$select id from public.suggestions where dedupe_key = 'rls-real-test'$$,
  'anon cannot see suggestions'
);

reset role;
set local role authenticated;
set local request.jwt.claims = '{"email":"rls-user@example.com","user_metadata":{}}';
select is_empty(
  $$select id from public.suggestions where dedupe_key = 'rls-real-test'$$,
  'non-moderator authenticated users cannot see suggestions'
);

reset role;
set local role authenticated;
set local request.jwt.claims = '{"email":"rls-moderator@example.com","user_metadata":{}}';
select results_eq(
  $$select dedupe_key from public.suggestions where dedupe_key = 'rls-real-test'$$,
  $$values ('rls-real-test'::text)$$,
  'moderators can see suggestions'
);

select * from finish();
rollback;
