begin;

-- Keep the candid internal coach reasoning OUT of the public API. The "curator
-- votes are public" RLS policy still exposes rows, so without column grants anon
-- can read comment_internal via PostgREST. Restrict anon + authenticated to the
-- structural columns + comment_public only; comment_internal stays readable to
-- service-role (admin/moderation) which bypasses these grants. The security-
-- definer RPCs (get_unscored_for_coach / set_curator_vote / refresh aggregates)
-- run as owner, so they are unaffected.
revoke select on public.curator_votes from anon, authenticated;
grant select (
  id,
  link_skill_relation_id,
  coach_role,
  weight,
  comment_public,
  created_at,
  updated_at
) on public.curator_votes to anon, authenticated;

-- Redundant index: the UNIQUE (link_skill_relation_id, coach_role) constraint
-- already provides an index on exactly these columns.
drop index if exists public.curator_votes_relation_role_idx;

commit;
