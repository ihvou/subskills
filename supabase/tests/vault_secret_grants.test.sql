begin;

create extension if not exists pgtap;

select plan(4);

select ok(
  to_regprocedure('public.get_vault_secret(text)') is not null,
  'get_vault_secret(text) exists'
);

select is(
  has_function_privilege('anon', 'public.get_vault_secret(text)', 'execute'),
  false,
  'anon cannot execute get_vault_secret'
);

select is(
  has_function_privilege('authenticated', 'public.get_vault_secret(text)', 'execute'),
  false,
  'authenticated cannot execute get_vault_secret'
);

select is(
  has_function_privilege('service_role', 'public.get_vault_secret(text)', 'execute'),
  true,
  'service_role can execute get_vault_secret'
);

select * from finish();
rollback;
