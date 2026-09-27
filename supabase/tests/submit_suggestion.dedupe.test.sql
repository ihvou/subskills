begin;

create extension if not exists pgtap;

select plan(2);

insert into public.suggestions (type, status, origin_type, payload_json, dedupe_key)
values (
  'LINK_ADD',
  'approved',
  'agent',
  '{"url":"https://example.com/dedupe","canonical_url":"https://example.com/dedupe","target_skill_id":"00000000-0000-4000-8000-000000000101"}'::jsonb,
  'submit-dedupe-key'
);

select throws_ok(
  $$insert into public.suggestions (type, status, origin_type, payload_json, dedupe_key)
    values (
      'LINK_ADD',
      'pending',
      'agent',
      '{"url":"https://example.com/dedupe","canonical_url":"https://example.com/dedupe","target_skill_id":"00000000-0000-4000-8000-000000000101"}'::jsonb,
      'submit-dedupe-key'
    )$$,
  '23505',
  'duplicate key value violates unique constraint "suggestions_active_dedupe_key_idx"',
  'active approved suggestions dedupe pending duplicates'
);

update public.suggestions
set status = 'declined'
where dedupe_key = 'submit-dedupe-key';

insert into public.suggestions (type, status, origin_type, payload_json, dedupe_key)
values (
  'LINK_ADD',
  'pending',
  'agent',
  '{"url":"https://example.com/dedupe","canonical_url":"https://example.com/dedupe","target_skill_id":"00000000-0000-4000-8000-000000000101"}'::jsonb,
  'submit-dedupe-key'
);

select results_eq(
  $$select count(*)::integer from public.suggestions where dedupe_key = 'submit-dedupe-key' and status in ('pending','approved','auto_approved')$$,
  $$values (1)$$,
  'declined suggestions release the dedupe key for a new pending suggestion'
);

select * from finish();
rollback;
