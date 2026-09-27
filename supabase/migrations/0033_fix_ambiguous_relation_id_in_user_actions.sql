-- Fix: every user-action RPC failed at runtime with
--   ERROR: column reference "link_skill_relation_id" is ambiguous
--
-- 0025 declared these functions as RETURNS TABLE (link_skill_relation_id uuid, ...).
-- That OUT parameter is an in-scope PL/pgSQL variable, so the INSERT's conflict target
-- `on conflict (user_id, link_skill_relation_id)` could not be resolved and every
-- insert raised. Net effect in production: saving a resource, marking it watched, and
-- voting ALL failed (on web and mobile — they share these RPCs). Only the delete
-- branches worked, because those qualify the column with a table alias.
--
-- Caught by driving the real app on-device: tapping Save showed "Save failed:
-- column reference link_skill_relation_id is ambiguous".
--
-- Fix without changing any signature or returned shape: target the primary key by
-- CONSTRAINT NAME, so the column never has to be resolved.

begin;

CREATE OR REPLACE FUNCTION public.set_user_bookmark(p_relation_id uuid, p_saved boolean)
 RETURNS TABLE(link_skill_relation_id uuid, saved boolean, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user_id uuid := auth.uid();
  v_relation_id uuid;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  select lsr.id
    into v_relation_id
    from public.link_skill_relations lsr
    join public.links l on l.id = lsr.link_id
    join public.skills s on s.id = lsr.skill_id
    join public.categories c on c.id = s.category_id
   where lsr.id = p_relation_id
     and lsr.is_active = true
     and lsr.published = true
     and l.is_active = true
     and s.is_active = true
     and c.is_active = true;

  if v_relation_id is null then
    raise exception 'published link_skill_relation not found: %', p_relation_id using errcode = 'P0002';
  end if;

  if coalesce(p_saved, false) then
    insert into public.user_bookmarks (user_id, link_skill_relation_id)
    values (v_user_id, p_relation_id)
    on conflict on constraint user_bookmarks_pkey do nothing;
  else
    delete from public.user_bookmarks ub
     where ub.user_id = v_user_id
       and ub.link_skill_relation_id = p_relation_id;
  end if;

  return query
    select
      p_relation_id,
      (ub.user_id is not null),
      ub.created_at
    from (select 1) seed
    left join public.user_bookmarks ub
      on ub.user_id = v_user_id
     and ub.link_skill_relation_id = p_relation_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.set_user_watched(p_relation_id uuid, p_watched boolean)
 RETURNS TABLE(link_skill_relation_id uuid, watched boolean, watched_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user_id uuid := auth.uid();
  v_relation_id uuid;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  select lsr.id
    into v_relation_id
    from public.link_skill_relations lsr
    join public.links l on l.id = lsr.link_id
    join public.skills s on s.id = lsr.skill_id
    join public.categories c on c.id = s.category_id
   where lsr.id = p_relation_id
     and lsr.is_active = true
     and lsr.published = true
     and l.is_active = true
     and s.is_active = true
     and c.is_active = true;

  if v_relation_id is null then
    raise exception 'published link_skill_relation not found: %', p_relation_id using errcode = 'P0002';
  end if;

  if coalesce(p_watched, false) then
    insert into public.user_watched (user_id, link_skill_relation_id, watched_at)
    values (v_user_id, p_relation_id, now())
    on conflict on constraint user_watched_pkey do update
       set watched_at = coalesce(public.user_watched.watched_at, excluded.watched_at),
           updated_at = now();
  else
    delete from public.user_watched uw
     where uw.user_id = v_user_id
       and uw.link_skill_relation_id = p_relation_id;
  end if;

  return query
    select
      p_relation_id,
      (uw.user_id is not null),
      uw.watched_at
    from (select 1) seed
    left join public.user_watched uw
      on uw.user_id = v_user_id
     and uw.link_skill_relation_id = p_relation_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.set_user_vote(p_relation_id uuid, p_vote smallint)
 RETURNS TABLE(link_skill_relation_id uuid, vote smallint, user_score real, combined_score real, published boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user_id uuid := auth.uid();
  v_relation_id uuid;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  if p_vote is null or p_vote not in (-1, 0, 1) then
    raise exception 'invalid user vote: %', p_vote;
  end if;

  select lsr.id
    into v_relation_id
    from public.link_skill_relations lsr
    join public.links l on l.id = lsr.link_id
    join public.skills s on s.id = lsr.skill_id
    join public.categories c on c.id = s.category_id
   where lsr.id = p_relation_id
     and lsr.is_active = true
     and (
       lsr.published = true
       or exists (
         select 1
           from public.user_relation_votes existing_vote
          where existing_vote.user_id = v_user_id
            and existing_vote.link_skill_relation_id = lsr.id
       )
     )
     and l.is_active = true
     and s.is_active = true
     and c.is_active = true;

  if v_relation_id is null then
    raise exception 'published link_skill_relation not found: %', p_relation_id using errcode = 'P0002';
  end if;

  if p_vote = 0 then
    delete from public.user_relation_votes urv
     where urv.user_id = v_user_id
       and urv.link_skill_relation_id = p_relation_id;
  else
    insert into public.user_relation_votes (
      user_id,
      link_skill_relation_id,
      vote
    )
    values (v_user_id, p_relation_id, p_vote)
    on conflict on constraint user_relation_votes_pkey do update
       set vote = excluded.vote,
           updated_at = now();
  end if;

  -- Single-relation gate (was a full-table refresh in 0025). The user_relation_votes
  -- trigger has already refreshed combined_score for this relation above.
  perform public.refresh_relation_publish_gate_one(p_relation_id, 2::smallint, 1.3::real);

  return query
    select
      lsr.id,
      coalesce(urv.vote, 0)::smallint,
      lsr.user_score,
      lsr.combined_score,
      lsr.published
    from public.link_skill_relations lsr
    left join public.user_relation_votes urv
      on urv.link_skill_relation_id = lsr.id
     and urv.user_id = v_user_id
    where lsr.id = p_relation_id;
end;
$function$;

commit;
