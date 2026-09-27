begin;

create extension if not exists pgtap;

select plan(3);

-- The functions 0066 locked down. Each runs with its owner's rights and trusts its
-- arguments, so reaching one with the anon key (it ships in every client) means
-- rewriting the catalogue or another user's library. See 0066 for the audit.
select is(
  (
    select coalesce(array_agg(p.proname::text order by p.proname), '{}')
    from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and p.proname in (
        'apply_suggestion_transaction', 'apply_tiktok_link_metadata',
        'enqueue_link_checker_jobs', 'enqueue_link_searcher_jobs',
        'next_user_bookmark_sort_order', 'recompute_contributor_accepted_count',
        'refresh_curator_vote_aggregates', 'refresh_relation_publish_gate',
        'refresh_relation_scores', 'set_curator_vote', 'set_relation_score',
        'set_skill_learning_order', 'upsert_user_bookmark_for_link',
        'upsert_user_watched_for_link'
      )
      and (has_function_privilege('anon', p.oid, 'execute')
        or has_function_privilege('authenticated', p.oid, 'execute'))
  ),
  '{}'::text[],
  'internal SECURITY DEFINER functions are not executable by anon or authenticated'
);

select is(
  (
    select count(*)::int
    from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and p.proname in (
        'apply_suggestion_transaction', 'refresh_relation_publish_gate',
        'set_curator_vote', 'set_relation_score', 'set_skill_learning_order'
      )
      and has_function_privilege('service_role', p.oid, 'execute')
  ),
  5,
  'service_role keeps execute on the functions the edge functions and scripts call'
);

-- The class, not just today's list. Supabase grants EXECUTE on every new function
-- to anon unless the migration revokes it, and that is how all fourteen above
-- were exposed. A new SECURITY DEFINER function callable by anon fails here until
-- it is either revoked or added below as deliberately public.
select is(
  (
    select coalesce(array_agg(p.proname::text order by p.proname), '{}')
    from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and p.prosecdef
      and p.prokind = 'f'
      and p.prorettype <> 'trigger'::regtype
      and has_function_privilege('anon', p.oid, 'execute')
      and p.proname not in (
        -- public catalogue reads made by the web server with the anon key
        'get_latest_skill_thumbnails', 'get_ranked_skill_relations',
        'get_skill_resource_counts',
        -- user functions that raise unless auth.uid() is set
        'get_user_library_resources', 'get_user_skill_progress', 'is_moderator',
        'reorder_user_bookmarks', 'set_user_bookmark', 'set_user_link_bookmark'
      )
  ),
  '{}'::text[],
  'no other SECURITY DEFINER function is callable with the anon key'
);

select * from finish();
rollback;
