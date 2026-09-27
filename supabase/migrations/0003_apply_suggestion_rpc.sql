create or replace function public.slugify(value text)
returns text
language sql
immutable
as $$
  select trim(both '-' from regexp_replace(lower(regexp_replace(value, '&', ' and ', 'g')), '[^a-z0-9]+', '-', 'g'));
$$;

create or replace function public.domain_from_url(value text)
returns text
language sql
immutable
as $$
  select regexp_replace(lower(split_part(regexp_replace(value, '^https?://', ''), '/', 1)), '^www\.', '');
$$;

create or replace function public.apply_suggestion_transaction(
  p_suggestion_id uuid,
  p_moderator_user_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_suggestion public.suggestions%rowtype;
  v_payload jsonb;
  v_link_id uuid;
  v_target_skill_id uuid;
  v_target_category_id uuid;
  v_status public.suggestion_status;
  v_active_relation_count integer;
  v_slug text;
begin
  select *
  into v_suggestion
  from public.suggestions
  where id = p_suggestion_id
  for update;

  if not found then
    raise exception 'Suggestion % not found', p_suggestion_id using errcode = 'P0002';
  end if;

  if v_suggestion.status not in ('pending', 'auto_approved') then
    return jsonb_build_object(
      'ok', true,
      'already_decided', true,
      'status', v_suggestion.status
    );
  end if;

  v_payload := v_suggestion.payload_json;
  v_status := case
    when v_suggestion.status = 'auto_approved' then 'auto_approved'::public.suggestion_status
    else 'approved'::public.suggestion_status
  end;

  case v_suggestion.type
    when 'LINK_ADD' then
      v_target_skill_id := (v_payload ->> 'target_skill_id')::uuid;

      insert into public.links (
        url,
        canonical_url,
        domain,
        title,
        description,
        thumbnail_url,
        content_type,
        language,
        preview_status,
        fetched_at,
        is_active
      )
      values (
        v_payload ->> 'url',
        v_payload ->> 'canonical_url',
        coalesce(nullif(v_payload ->> 'domain', ''), public.domain_from_url(v_payload ->> 'canonical_url')),
        nullif(v_payload ->> 'title', ''),
        nullif(v_payload ->> 'description', ''),
        nullif(v_payload ->> 'thumbnail_url', ''),
        nullif(v_payload ->> 'content_type', ''),
        coalesce(nullif(v_payload ->> 'language', ''), 'en'),
        case when nullif(v_payload ->> 'thumbnail_url', '') is null then 'pending' else 'fetched' end,
        case when nullif(v_payload ->> 'thumbnail_url', '') is null then null else now() end,
        true
      )
      on conflict (canonical_url) do update set
        url = excluded.url,
        domain = excluded.domain,
        title = coalesce(excluded.title, public.links.title),
        description = coalesce(excluded.description, public.links.description),
        thumbnail_url = coalesce(excluded.thumbnail_url, public.links.thumbnail_url),
        content_type = coalesce(excluded.content_type, public.links.content_type),
        language = coalesce(excluded.language, public.links.language),
        preview_status = excluded.preview_status,
        fetched_at = coalesce(excluded.fetched_at, public.links.fetched_at),
        is_active = true
      returning id into v_link_id;

      insert into public.link_skill_relations (
        link_id,
        skill_id,
        public_note,
        skill_level,
        is_active,
        last_checked_at
      )
      values (
        v_link_id,
        v_target_skill_id,
        nullif(v_payload ->> 'public_note', ''),
        nullif(v_payload ->> 'skill_level', ''),
        true,
        now()
      )
      on conflict (link_id, skill_id) do update set
        public_note = coalesce(excluded.public_note, public.link_skill_relations.public_note),
        skill_level = coalesce(excluded.skill_level, public.link_skill_relations.skill_level),
        is_active = true,
        last_checked_at = now();

      update public.suggestions
      set status = v_status,
          decided_at = now(),
          moderator_user_id = p_moderator_user_id,
          link_id = v_link_id
      where id = p_suggestion_id;

      return jsonb_build_object('ok', true, 'applied_changes', jsonb_build_array('link_upserted', 'relation_upserted'), 'link_id', v_link_id);

    when 'LINK_ATTACH_SKILL' then
      v_link_id := (v_payload ->> 'link_id')::uuid;
      v_target_skill_id := (v_payload ->> 'target_skill_id')::uuid;

      insert into public.link_skill_relations (
        link_id,
        skill_id,
        public_note,
        skill_level,
        is_active,
        last_checked_at
      )
      values (
        v_link_id,
        v_target_skill_id,
        nullif(v_payload ->> 'public_note', ''),
        nullif(v_payload ->> 'skill_level', ''),
        true,
        now()
      )
      on conflict (link_id, skill_id) do update set
        public_note = coalesce(excluded.public_note, public.link_skill_relations.public_note),
        skill_level = coalesce(excluded.skill_level, public.link_skill_relations.skill_level),
        is_active = true,
        last_checked_at = now();

      update public.links set is_active = true where id = v_link_id;
      update public.suggestions set status = v_status, decided_at = now(), moderator_user_id = p_moderator_user_id where id = p_suggestion_id;

      return jsonb_build_object('ok', true, 'applied_changes', jsonb_build_array('relation_attached'));

    when 'LINK_DETACH_SKILL' then
      v_link_id := (v_payload ->> 'link_id')::uuid;
      v_target_skill_id := (v_payload ->> 'target_skill_id')::uuid;

      update public.link_skill_relations
      set is_active = false,
          last_checked_at = now()
      where link_id = v_link_id
        and skill_id = v_target_skill_id;

      select count(*) into v_active_relation_count
      from public.link_skill_relations
      where link_id = v_link_id
        and is_active;

      if v_active_relation_count = 0 then
        update public.links set is_active = false where id = v_link_id;
      end if;

      update public.suggestions set status = v_status, decided_at = now(), moderator_user_id = p_moderator_user_id where id = p_suggestion_id;

      return jsonb_build_object('ok', true, 'applied_changes', jsonb_build_array('relation_detached'));

    when 'LINK_UPVOTE_SKILL' then
      v_link_id := (v_payload ->> 'link_id')::uuid;
      v_target_skill_id := (v_payload ->> 'target_skill_id')::uuid;

      update public.link_skill_relations
      set upvote_count = upvote_count + 1,
          last_checked_at = now()
      where link_id = v_link_id
        and skill_id = v_target_skill_id
        and is_active = true;

      update public.suggestions set status = v_status, decided_at = now(), moderator_user_id = p_moderator_user_id where id = p_suggestion_id;

      return jsonb_build_object('ok', true, 'applied_changes', jsonb_build_array('relation_upvoted'));

    when 'SKILL_CREATE' then
      v_target_category_id := (v_payload ->> 'category_id')::uuid;
      v_slug := public.slugify(v_payload ->> 'name');

      insert into public.skills (category_id, slug, name, description, is_active)
      values (
        v_target_category_id,
        v_slug,
        v_payload ->> 'name',
        nullif(v_payload ->> 'description', ''),
        true
      )
      on conflict (category_id, slug) do update set
        name = excluded.name,
        description = coalesce(excluded.description, public.skills.description),
        is_active = true;

      update public.suggestions set status = v_status, decided_at = now(), moderator_user_id = p_moderator_user_id where id = p_suggestion_id;

      return jsonb_build_object('ok', true, 'applied_changes', jsonb_build_array('skill_created'), 'skill_slug', v_slug);

    when 'SKILL_DELETE' then
      v_target_skill_id := (v_payload ->> 'skill_id')::uuid;

      update public.skills set is_active = false where id = v_target_skill_id;
      update public.link_skill_relations set is_active = false where skill_id = v_target_skill_id;
      update public.suggestions set status = v_status, decided_at = now(), moderator_user_id = p_moderator_user_id where id = p_suggestion_id;

      return jsonb_build_object('ok', true, 'applied_changes', jsonb_build_array('skill_deactivated'));
  end case;
end;
$$;

grant execute on function public.apply_suggestion_transaction(uuid, uuid) to service_role;
