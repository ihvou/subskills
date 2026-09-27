begin;

create extension if not exists pgtap;

select plan(1);

select has_function('public', 'notify_revalidation', array[]::text[], 'revalidation trigger function exists');

select * from finish();
rollback;
