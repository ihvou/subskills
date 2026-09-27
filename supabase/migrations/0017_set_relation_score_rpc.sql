-- 0017: scoped scoring RPC so the Learning-Path scoring routine (M29) can run on
-- the PUBLIC (anon) key instead of the service-role key. security definer + a
-- narrow update (4 score columns on one active relation) means even if the key in
-- the cloud routine leaks, anon can ONLY set scores — not read/write/delete the DB.
create or replace function public.set_relation_score(
  p_relation_id uuid,
  p_relevance real,
  p_teaching_quality real,
  p_value_score real,
  p_skill_level text
) returns void
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if p_skill_level is not null
     and p_skill_level not in ('beginner','intermediate','advanced') then
    raise exception 'invalid skill_level: %', p_skill_level;
  end if;
  update public.link_skill_relations r
     set relevance        = p_relevance,
         teaching_quality = p_teaching_quality,
         value_score      = p_value_score,
         skill_level      = coalesce(p_skill_level, r.skill_level),
         updated_at       = now()
   where r.id = p_relation_id
     and r.is_active;
end;
$fn$;

revoke all on function public.set_relation_score(uuid, real, real, real, text) from public;
grant execute on function public.set_relation_score(uuid, real, real, real, text) to anon, authenticated;
