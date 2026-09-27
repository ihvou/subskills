create table if not exists public.contributor_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  display_name text not null,
  slug text not null unique,
  bio text,
  avatar_url text,
  accepted_count integer not null default 0 check (accepted_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.links
add column if not exists contributor_profile_id uuid references public.contributor_profiles(id);

alter table public.links
drop constraint if exists links_contributor_profile_id_fkey;

alter table public.links
add constraint links_contributor_profile_id_fkey
foreign key (contributor_profile_id) references public.contributor_profiles(id);

alter table public.suggestions
add column if not exists submitted_by_user_id uuid references auth.users(id) on delete set null;

create table if not exists public.suggest_rate_limits (
  ip text primary key,
  window_start timestamptz not null default now(),
  count integer not null default 0 check (count >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_actions (
  user_id uuid not null references auth.users(id) on delete cascade,
  link_id uuid not null references public.links(id) on delete cascade,
  action_type text not null check (action_type in ('saved','completed','upvote','downvote')),
  created_at timestamptz not null default now(),
  primary key (user_id, link_id, action_type)
);

create index if not exists links_contributor_profile_idx
on public.links (contributor_profile_id)
where contributor_profile_id is not null;

create index if not exists suggestions_submitted_by_user_idx
on public.suggestions (submitted_by_user_id, created_at desc)
where submitted_by_user_id is not null;

create index if not exists suggestions_link_add_canonical_created_idx
on public.suggestions ((payload_json ->> 'canonical_url'), created_at desc)
where type = 'LINK_ADD';

create index if not exists user_actions_user_created_idx
on public.user_actions (user_id, created_at desc);

create trigger contributor_profiles_set_updated_at
before update on public.contributor_profiles
for each row execute function public.set_updated_at();

alter table public.contributor_profiles enable row level security;
alter table public.suggest_rate_limits enable row level security;
alter table public.user_actions enable row level security;

drop policy if exists "contributor profiles are public" on public.contributor_profiles;
create policy "contributor profiles are public"
on public.contributor_profiles for select
to anon, authenticated
using (true);

drop policy if exists "contributors manage own profile" on public.contributor_profiles;
create policy "contributors manage own profile"
on public.contributor_profiles for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "contributors insert own profile" on public.contributor_profiles;
create policy "contributors insert own profile"
on public.contributor_profiles for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "contributors read own actions" on public.user_actions;
create policy "contributors read own actions"
on public.user_actions for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "contributors insert own actions" on public.user_actions;
create policy "contributors insert own actions"
on public.user_actions for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "contributors delete own actions" on public.user_actions;
create policy "contributors delete own actions"
on public.user_actions for delete
to authenticated
using (user_id = auth.uid());

grant select on public.contributor_profiles to anon, authenticated;
grant insert, update on public.contributor_profiles to authenticated;
grant select, insert, delete on public.user_actions to authenticated;
grant all on public.suggest_rate_limits to service_role;

create or replace function public.create_contributor_profile_for_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_display_name text;
  v_avatar_url text;
  v_base_slug text;
  v_slug text;
  v_suffix integer := 0;
begin
  if exists (select 1 from public.contributor_profiles where user_id = new.id) then
    return new;
  end if;

  v_display_name := nullif(trim(coalesce(
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'name',
    split_part(new.email, '@', 1),
    'Contributor'
  )), '');
  v_avatar_url := nullif(new.raw_user_meta_data ->> 'avatar_url', '');
  v_base_slug := nullif(public.slugify(v_display_name), '');

  if v_base_slug is null then
    v_base_slug := 'contributor-' || left(replace(new.id::text, '-', ''), 8);
  end if;

  v_slug := v_base_slug;

  loop
    begin
      insert into public.contributor_profiles (user_id, display_name, slug, avatar_url)
      values (new.id, v_display_name, v_slug, v_avatar_url);
      return new;
    exception when unique_violation then
      v_suffix := v_suffix + 1;
      v_slug := v_base_slug || '-' || v_suffix::text;
    end;
  end loop;
end;
$$;

drop trigger if exists on_auth_user_create_contributor_profile on auth.users;
create trigger on_auth_user_create_contributor_profile
after insert on auth.users
for each row execute function public.create_contributor_profile_for_user();

with user_display_names as (
  select
    users.id,
    coalesce(
      nullif(trim(users.raw_user_meta_data ->> 'full_name'), ''),
      nullif(trim(users.raw_user_meta_data ->> 'name'), ''),
      nullif(trim(split_part(users.email, '@', 1)), ''),
      'Contributor'
    ) as display_name,
    nullif(users.raw_user_meta_data ->> 'avatar_url', '') as avatar_url
  from auth.users as users
),
prepared_slugs as (
  select
    id,
    display_name,
    avatar_url,
    coalesce(
      nullif(public.slugify(display_name), ''),
      'contributor-' || left(replace(id::text, '-', ''), 8)
    ) as base_slug
  from user_display_names
),
numbered_slugs as (
  select
    *,
    row_number() over (partition by base_slug order by id) as slug_number
  from prepared_slugs
)
insert into public.contributor_profiles (user_id, display_name, slug, avatar_url)
select
  id,
  display_name,
  case when slug_number = 1 then base_slug else base_slug || '-' || slug_number::text end,
  avatar_url
from numbered_slugs
on conflict do nothing;

create or replace function public.sync_contributor_accepted_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old_accepted boolean;
  v_new_accepted boolean;
begin
  v_old_accepted := case
    when tg_op = 'UPDATE' then old.status in ('approved', 'auto_approved')
    else false
  end;
  v_new_accepted := new.status in ('approved', 'auto_approved');

  if new.submitted_by_user_id is null then
    return new;
  end if;

  if not v_old_accepted and v_new_accepted then
    update public.contributor_profiles
    set accepted_count = accepted_count + 1
    where user_id = new.submitted_by_user_id;
  elsif v_old_accepted and not v_new_accepted then
    update public.contributor_profiles
    set accepted_count = greatest(accepted_count - 1, 0)
    where user_id = new.submitted_by_user_id;
  end if;

  return new;
end;
$$;

drop trigger if exists suggestions_sync_contributor_accepted_count on public.suggestions;
create trigger suggestions_sync_contributor_accepted_count
after insert or update of status, submitted_by_user_id on public.suggestions
for each row execute function public.sync_contributor_accepted_count();

create or replace function public.sync_user_action_vote_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if new.action_type = 'upvote' then
      update public.link_skill_relations
      set upvote_count = upvote_count + 1
      where link_id = new.link_id and is_active = true;
    elsif new.action_type = 'downvote' then
      update public.link_skill_relations
      set upvote_count = upvote_count - 1
      where link_id = new.link_id and is_active = true;
    end if;
    return new;
  end if;

  if tg_op = 'DELETE' then
    if old.action_type = 'upvote' then
      update public.link_skill_relations
      set upvote_count = greatest(upvote_count - 1, 0)
      where link_id = old.link_id and is_active = true;
    elsif old.action_type = 'downvote' then
      update public.link_skill_relations
      set upvote_count = upvote_count + 1
      where link_id = old.link_id and is_active = true;
    end if;
    return old;
  end if;

  return null;
end;
$$;

drop trigger if exists user_actions_sync_vote_count on public.user_actions;
create trigger user_actions_sync_vote_count
after insert or delete on public.user_actions
for each row execute function public.sync_user_action_vote_count();

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
  v_contributor_profile_id uuid;
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

  select id
  into v_contributor_profile_id
  from public.contributor_profiles
  where user_id = v_suggestion.submitted_by_user_id;

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
        contributor_profile_id,
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
        v_contributor_profile_id,
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
        contributor_profile_id = coalesce(public.links.contributor_profile_id, excluded.contributor_profile_id),
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

      update public.links
      set is_active = true,
          contributor_profile_id = coalesce(contributor_profile_id, v_contributor_profile_id)
      where id = v_link_id;
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
