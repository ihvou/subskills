-- 0066: take the internal SECURITY DEFINER functions away from the public API key.
--
-- THE HOLE. Supabase's default privileges grant EXECUTE on every new function in
-- `public` to anon and authenticated, and PostgREST serves each one at
-- /rest/v1/rpc/<name>. 0027 named this in June and tightened the functions of the
-- day, but every migration since that created or re-created a function without an
-- explicit revoke republished it. The anon key ships inside the web bundle and
-- both apps, and these functions run with their owner's rights and never check
-- who is calling. Audited on hosted 2026-09-20, fourteen were callable by anyone:
--
--   refresh_relation_publish_gate   one request could unpublish the catalogue, or
--                                   publish every rejected relation
--   apply_suggestion_transaction    approve any pending suggestion, naming any
--                                   moderator id
--   set_curator_vote                locked to service_role by 0025, re-opened by
--                                   0050, which re-granted it to anon/authenticated
--                                   while re-creating it for staged categories
--   set_relation_score, set_skill_learning_order, apply_tiktok_link_metadata
--                                   rewrite scores, learning paths, link metadata
--   upsert_user_bookmark_for_link, upsert_user_watched_for_link
--                                   write into any user's library (p_user_id is
--                                   trusted as given)
--   enqueue_*_jobs, refresh_*, recompute_*, next_user_bookmark_sort_order
--                                   internal plumbing
--
-- WHO STILL CALLS THEM, AND WHY NOTHING BREAKS. Only service_role:
--   - the apply-suggestion, coach-curation and skill-summary edge functions all
--     use getServiceClient();
--   - the scripts that call set_skill_learning_order and
--     apply_suggestion_transaction use the service key.
-- Every function that calls one of these internally (set_user_bookmark,
-- set_user_link_watched, the sync_* triggers, ...) is itself SECURITY DEFINER
-- owned by postgres, so the inner call is checked against postgres, not the
-- user. No policy or view references them. The web and mobile clients call
-- eleven RPCs and none is on this list, so the builds already in testers' hands
-- keep working.
--
-- LEFT OPEN ON PURPOSE: get_latest_skill_thumbnails, get_ranked_skill_relations and
-- get_skill_resource_counts are public catalogue reads the web server makes with
-- the anon key. Trigger functions cannot be called directly.
-- tests/0066_internal_functions_locked.test.sql fails CI if a later migration
-- re-opens any of these, or adds a new anon-callable SECURITY DEFINER function
-- without a decision to allow it.

begin;

revoke all on function public.apply_suggestion_transaction(uuid, uuid, boolean) from public;
revoke execute on function public.apply_suggestion_transaction(uuid, uuid, boolean) from anon, authenticated;
grant execute on function public.apply_suggestion_transaction(uuid, uuid, boolean) to service_role;

revoke all on function public.apply_tiktok_link_metadata(uuid, text, text, text, text, text, integer, integer, integer, boolean, numeric, numeric, integer, integer, integer, integer, text, text, text, text) from public;
revoke execute on function public.apply_tiktok_link_metadata(uuid, text, text, text, text, text, integer, integer, integer, boolean, numeric, numeric, integer, integer, integer, integer, text, text, text, text) from anon, authenticated;
grant execute on function public.apply_tiktok_link_metadata(uuid, text, text, text, text, text, integer, integer, integer, boolean, numeric, numeric, integer, integer, integer, integer, text, text, text, text) to service_role;

revoke all on function public.enqueue_link_checker_jobs() from public;
revoke execute on function public.enqueue_link_checker_jobs() from anon, authenticated;
grant execute on function public.enqueue_link_checker_jobs() to service_role;

revoke all on function public.enqueue_link_searcher_jobs() from public;
revoke execute on function public.enqueue_link_searcher_jobs() from anon, authenticated;
grant execute on function public.enqueue_link_searcher_jobs() to service_role;

revoke all on function public.next_user_bookmark_sort_order(uuid) from public;
revoke execute on function public.next_user_bookmark_sort_order(uuid) from anon, authenticated;
grant execute on function public.next_user_bookmark_sort_order(uuid) to service_role;

revoke all on function public.recompute_contributor_accepted_count(uuid) from public;
revoke execute on function public.recompute_contributor_accepted_count(uuid) from anon, authenticated;
grant execute on function public.recompute_contributor_accepted_count(uuid) to service_role;

revoke all on function public.refresh_curator_vote_aggregates(uuid) from public;
revoke execute on function public.refresh_curator_vote_aggregates(uuid) from anon, authenticated;
grant execute on function public.refresh_curator_vote_aggregates(uuid) to service_role;

revoke all on function public.refresh_relation_publish_gate(smallint, real, boolean) from public;
revoke execute on function public.refresh_relation_publish_gate(smallint, real, boolean) from anon, authenticated;
grant execute on function public.refresh_relation_publish_gate(smallint, real, boolean) to service_role;

revoke all on function public.refresh_relation_scores(uuid) from public;
revoke execute on function public.refresh_relation_scores(uuid) from anon, authenticated;
grant execute on function public.refresh_relation_scores(uuid) to service_role;

revoke all on function public.set_curator_vote(uuid, text, real, text, text) from public;
revoke execute on function public.set_curator_vote(uuid, text, real, text, text) from anon, authenticated;
grant execute on function public.set_curator_vote(uuid, text, real, text, text) to service_role;

revoke all on function public.set_relation_score(uuid, real, real, real, text) from public;
revoke execute on function public.set_relation_score(uuid, real, real, real, text) from anon, authenticated;
grant execute on function public.set_relation_score(uuid, real, real, real, text) to service_role;

revoke all on function public.set_skill_learning_order(text, jsonb) from public;
revoke execute on function public.set_skill_learning_order(text, jsonb) from anon, authenticated;
grant execute on function public.set_skill_learning_order(text, jsonb) to service_role;

revoke all on function public.upsert_user_bookmark_for_link(uuid, uuid, uuid, uuid, uuid) from public;
revoke execute on function public.upsert_user_bookmark_for_link(uuid, uuid, uuid, uuid, uuid) from anon, authenticated;
grant execute on function public.upsert_user_bookmark_for_link(uuid, uuid, uuid, uuid, uuid) to service_role;

revoke all on function public.upsert_user_watched_for_link(uuid, uuid, uuid, uuid, uuid) from public;
revoke execute on function public.upsert_user_watched_for_link(uuid, uuid, uuid, uuid, uuid) from anon, authenticated;
grant execute on function public.upsert_user_watched_for_link(uuid, uuid, uuid, uuid, uuid) to service_role;

commit;
