begin;

-- Supabase security advisor: rls_disabled_in_public (critical), reported for
-- 13 Sep 2026.
--
-- public.coach_rescore_2026_09_snapshot was created by hand during the M160
-- rescore — not by a migration — to keep the coach votes and rationales from
-- before the re-vote. A table made that way has RLS off, and Supabase's default
-- privileges grant anon and authenticated ALL on every new table in public. So
-- the public anon key, which ships inside the web and mobile apps, could read,
-- change and delete all 3,744 rows through PostgREST. pg_stat_statements (kept
-- since 2026-06-07) shows no anon or authenticated query against it before the
-- report was investigated.
--
-- Every table the migrations create already enables RLS, so the gap is tables
-- created any other way: psql sessions, snapshots, CREATE TABLE AS. Two parts:
--
--   1. Close the hole that exists: any public table without RLS gets RLS on and
--      loses its anon/authenticated grants. postgres and service_role bypass
--      RLS, so the collector, scripts and edge functions are unaffected.
--   2. Make RLS the default: an event trigger turns RLS on for every table
--      created in public from now on, however it is created. A table meant to
--      be client-readable still needs a policy — which is already how every
--      migration here works — so nothing following the house pattern changes.
--
-- Event triggers are database-level objects, so a public-schema dump does not
-- carry this one: re-apply this migration after restoring into a fresh project
-- (docs/db-backup-restore.md).

-- 1. Tables that exist today --------------------------------------------------
do $$
declare
  t regclass;
begin
  for t in
    select c.oid::regclass
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('r', 'p')
      and not c.relrowsecurity
  loop
    execute format('alter table %s enable row level security', t);
    execute format('revoke all on table %s from anon, authenticated', t);
    raise notice 'RLS enabled, anon/authenticated revoked: %', t;
  end loop;
end;
$$;

-- 2. Tables created from now on ------------------------------------------------
create or replace function public.enable_rls_on_new_public_tables()
returns event_trigger
language plpgsql
set search_path = pg_catalog
as $fn$
declare
  cmd record;
begin
  for cmd in
    select object_identity
    from pg_event_trigger_ddl_commands()
    where object_type = 'table'
      and schema_name = 'public'
  loop
    execute format('alter table %s enable row level security', cmd.object_identity);
  end loop;
end;
$fn$;

comment on function public.enable_rls_on_new_public_tables() is
  'Event trigger (0062): turns RLS on for every table created in public, so a hand-made table is never exposed to the anon key by default.';

-- An event-trigger function cannot be called directly, but default privileges
-- still hand anon/authenticated EXECUTE on every new public function.
revoke all on function public.enable_rls_on_new_public_tables() from public, anon, authenticated;

drop event trigger if exists enable_rls_on_new_public_tables;
create event trigger enable_rls_on_new_public_tables
  on ddl_command_end
  when tag in ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
  execute function public.enable_rls_on_new_public_tables();

commit;
