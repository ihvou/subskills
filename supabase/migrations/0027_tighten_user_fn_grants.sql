-- Review fix for 0025/0026: Supabase's default privileges GRANT EXECUTE on every new
-- function to `anon` and `authenticated`, and `revoke all ... from public` does NOT
-- remove those explicit role grants. 0025/0026 relied on revoke-from-public for the
-- user action functions and the single-relation gate helper, which left `anon` able to
-- call them. The user functions are still safe at runtime (they raise when auth.uid()
-- is null), but defense-in-depth says anon shouldn't reach them at all; and the gate
-- helper is internal-only. Tighten with explicit revokes (matching how 0025 already did
-- it for set_curator_vote / get_unscored_for_coach).

begin;

revoke execute on function public.set_user_vote(uuid, smallint) from anon;
revoke execute on function public.set_user_bookmark(uuid, boolean) from anon;
revoke execute on function public.set_user_watched(uuid, boolean) from anon;
revoke execute on function public.refresh_relation_publish_gate_one(uuid, smallint, real) from anon, authenticated;

commit;
