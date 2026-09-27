begin;

-- M101/MI36: saved state is now a personal link list, not a relation-only
-- bookmark. Existing rows are preserved by resolving their relation's link_id.
alter table public.user_bookmarks
  add column if not exists id uuid,
  add column if not exists link_id uuid,
  add column if not exists skill_id uuid,
  add column if not exists source_suggestion_id uuid,
  add column if not exists sort_order bigint,
  add column if not exists updated_at timestamptz not null default now();

update public.user_bookmarks
   set id = gen_random_uuid()
 where id is null;

update public.user_bookmarks ub
   set link_id = lsr.link_id,
       skill_id = coalesce(ub.skill_id, lsr.skill_id)
  from public.link_skill_relations lsr
 where ub.link_skill_relation_id = lsr.id
   and ub.link_id is null;

-- Foreign keys should make this a no-op on healthy data. If a local/dev table
-- somehow contains an orphaned legacy row, it cannot be represented by the new
-- link-keyed model.
delete from public.user_bookmarks
 where link_id is null;

with ranked as (
  select
    id,
    row_number() over (
      partition by user_id, link_id
      order by created_at desc, link_skill_relation_id nulls last, id
    ) as rn
  from public.user_bookmarks
)
delete from public.user_bookmarks ub
using ranked r
where ub.id = r.id
  and r.rn > 1;

with ordered as (
  select
    id,
    row_number() over (partition by user_id order by created_at desc, id) as rn
  from public.user_bookmarks
  where sort_order is null
)
update public.user_bookmarks ub
   set sort_order = ordered.rn * 1024
  from ordered
 where ub.id = ordered.id;

-- The old primary key is (user_id, link_skill_relation_id), and Postgres refuses
-- `drop not null` on a column that is still part of a primary key
-- (SQLSTATE 42P16). So the constraint has to go FIRST, then the column nullability
-- changes, then the new key. Do not reorder these three statements.
alter table public.user_bookmarks
  drop constraint if exists user_bookmarks_pkey;

alter table public.user_bookmarks
  alter column id set default gen_random_uuid(),
  alter column id set not null,
  alter column link_id set not null,
  alter column link_skill_relation_id drop not null,
  alter column sort_order set not null,
  alter column updated_at set default now();

alter table public.user_bookmarks
  add constraint user_bookmarks_pkey primary key (id);

alter table public.user_bookmarks
  drop constraint if exists user_bookmarks_link_id_fkey,
  add constraint user_bookmarks_link_id_fkey
    foreign key (link_id) references public.links(id) on delete cascade,
  drop constraint if exists user_bookmarks_skill_id_fkey,
  add constraint user_bookmarks_skill_id_fkey
    foreign key (skill_id) references public.skills(id) on delete set null,
  drop constraint if exists user_bookmarks_source_suggestion_id_fkey,
  add constraint user_bookmarks_source_suggestion_id_fkey
    foreign key (source_suggestion_id) references public.suggestions(id) on delete set null;

create unique index if not exists user_bookmarks_user_link_idx
on public.user_bookmarks (user_id, link_id);

create index if not exists user_bookmarks_user_sort_idx
on public.user_bookmarks (user_id, sort_order asc, created_at desc);

create index if not exists user_bookmarks_relation_idx
on public.user_bookmarks (link_skill_relation_id)
where link_skill_relation_id is not null;

drop trigger if exists user_bookmarks_set_updated_at on public.user_bookmarks;
create trigger user_bookmarks_set_updated_at
before update on public.user_bookmarks
for each row execute function public.set_updated_at();

comment on table public.user_bookmarks is
  'Private Watch later rows keyed by user_id + link_id. link_skill_relation_id is nullable so private/share-in saves can survive review state changes.';
comment on column public.user_bookmarks.sort_order is
  'User-controlled Watch later order; lower values appear first.';
comment on column public.user_bookmarks.source_suggestion_id is
  'Human suggestion that created this personal row, when the user also recommended the link publicly.';

alter table public.link_skill_relations
  add column if not exists submitted_by_user_id uuid,
  add column if not exists source_suggestion_id uuid,
  add column if not exists review_lane text not null default 'coach';

alter table public.creators
  drop constraint if exists creators_platform_check,
  add constraint creators_platform_check
    check (platform in ('youtube', 'tiktok', 'instagram'));

alter table public.link_skill_relations
  drop constraint if exists link_skill_relations_submitted_by_user_id_fkey,
  add constraint link_skill_relations_submitted_by_user_id_fkey
    foreign key (submitted_by_user_id) references auth.users(id) on delete set null,
  drop constraint if exists link_skill_relations_source_suggestion_id_fkey,
  add constraint link_skill_relations_source_suggestion_id_fkey
    foreign key (source_suggestion_id) references public.suggestions(id) on delete set null,
  drop constraint if exists link_skill_relations_review_lane_check,
  add constraint link_skill_relations_review_lane_check
    check (review_lane in ('coach', 'founder', 'agent', 'private'));

create index if not exists link_skill_relations_human_queue_idx
on public.link_skill_relations (submitted_by_user_id, created_at asc)
where is_active and not published and submitted_by_user_id is not null;

create index if not exists link_skill_relations_review_lane_idx
on public.link_skill_relations (review_lane, created_at asc)
where is_active and not published;

comment on column public.link_skill_relations.review_lane is
  'Review lane for human share-in: coach for YouTube/transcript-scored items, founder for TikTok/Instagram/manual review, private for save-only rows if ever materialized.';
comment on column public.link_skill_relations.submitted_by_user_id is
  'Auth user that submitted this relation through share-in, used to float human submissions in the coach queue.';

create or replace function public.next_user_bookmark_sort_order(p_user_id uuid)
returns bigint
language sql
stable
security definer
set search_path = public
as $fn$
  select coalesce(
    (select min(sort_order) - 1024 from public.user_bookmarks where user_id = p_user_id),
    (extract(epoch from now()) * 1000)::bigint
  );
$fn$;

revoke all on function public.next_user_bookmark_sort_order(uuid) from public;

create or replace function public.upsert_user_bookmark_for_link(
  p_user_id uuid,
  p_link_id uuid,
  p_skill_id uuid default null,
  p_relation_id uuid default null,
  p_source_suggestion_id uuid default null
) returns uuid
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_bookmark_id uuid;
  v_sort_order bigint;
begin
  if p_user_id is null then
    raise exception 'user_id is required' using errcode = '22023';
  end if;
  if p_link_id is null then
    raise exception 'link_id is required' using errcode = '22023';
  end if;

  v_sort_order := public.next_user_bookmark_sort_order(p_user_id);

  insert into public.user_bookmarks (
    user_id,
    link_id,
    skill_id,
    link_skill_relation_id,
    source_suggestion_id,
    sort_order
  )
  values (
    p_user_id,
    p_link_id,
    p_skill_id,
    p_relation_id,
    p_source_suggestion_id,
    v_sort_order
  )
  on conflict (user_id, link_id) do update set
    skill_id = coalesce(excluded.skill_id, public.user_bookmarks.skill_id),
    link_skill_relation_id = coalesce(excluded.link_skill_relation_id, public.user_bookmarks.link_skill_relation_id),
    source_suggestion_id = coalesce(excluded.source_suggestion_id, public.user_bookmarks.source_suggestion_id),
    updated_at = now()
  returning id into v_bookmark_id;

  return v_bookmark_id;
end;
$fn$;

revoke all on function public.upsert_user_bookmark_for_link(uuid, uuid, uuid, uuid, uuid) from public;
grant execute on function public.upsert_user_bookmark_for_link(uuid, uuid, uuid, uuid, uuid) to service_role;

drop function if exists public.set_user_bookmark(uuid, boolean);
create function public.set_user_bookmark(
  p_relation_id uuid,
  p_saved boolean
) returns table (
  link_skill_relation_id uuid,
  link_id uuid,
  saved boolean,
  created_at timestamptz,
  sort_order bigint
)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_user_id uuid := auth.uid();
  v_relation record;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  select
    lsr.id,
    lsr.link_id,
    lsr.skill_id
  into v_relation
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

  if v_relation.id is null then
    raise exception 'published link_skill_relation not found: %', p_relation_id using errcode = 'P0002';
  end if;

  if coalesce(p_saved, false) then
    perform public.upsert_user_bookmark_for_link(
      v_user_id,
      v_relation.link_id,
      v_relation.skill_id,
      v_relation.id,
      null
    );
  else
    delete from public.user_bookmarks ub
     where ub.user_id = v_user_id
       and ub.link_id = v_relation.link_id;
  end if;

  return query
    select
      ub.link_skill_relation_id,
      ub.link_id,
      (ub.user_id is not null),
      ub.created_at,
      ub.sort_order
    from (select 1) seed
    left join public.user_bookmarks ub
      on ub.user_id = v_user_id
     and ub.link_id = v_relation.link_id;
end;
$fn$;

revoke all on function public.set_user_bookmark(uuid, boolean) from public;
grant execute on function public.set_user_bookmark(uuid, boolean) to authenticated;

create or replace function public.set_user_link_bookmark(
  p_link_id uuid,
  p_saved boolean
) returns table (
  link_id uuid,
  saved boolean,
  created_at timestamptz,
  sort_order bigint
)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_user_id uuid := auth.uid();
  v_link_id uuid;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  select id
    into v_link_id
    from public.links
   where id = p_link_id
     and is_active = true;

  if v_link_id is null then
    raise exception 'active link not found: %', p_link_id using errcode = 'P0002';
  end if;

  if coalesce(p_saved, false) then
    perform public.upsert_user_bookmark_for_link(v_user_id, v_link_id, null, null, null);
  else
    delete from public.user_bookmarks ub
     where ub.user_id = v_user_id
       and ub.link_id = v_link_id;
  end if;

  return query
    select
      v_link_id,
      (ub.user_id is not null),
      ub.created_at,
      ub.sort_order
    from (select 1) seed
    left join public.user_bookmarks ub
      on ub.user_id = v_user_id
     and ub.link_id = v_link_id;
end;
$fn$;

revoke all on function public.set_user_link_bookmark(uuid, boolean) from public;
grant execute on function public.set_user_link_bookmark(uuid, boolean) to authenticated;

create or replace function public.reorder_user_bookmarks(p_bookmark_ids uuid[])
returns integer
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_user_id uuid := auth.uid();
  v_updated integer := 0;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  with ordered as (
    select id, ordinality::bigint * 1024 as next_order
    from unnest(coalesce(p_bookmark_ids, '{}'::uuid[])) with ordinality as input(id, ordinality)
  ),
  updated as (
    update public.user_bookmarks ub
       set sort_order = ordered.next_order,
           updated_at = now()
      from ordered
     where ub.id = ordered.id
       and ub.user_id = v_user_id
     returning ub.id
  )
  select count(*)::integer into v_updated
  from updated;

  return v_updated;
end;
$fn$;

revoke all on function public.reorder_user_bookmarks(uuid[]) from public;
grant execute on function public.reorder_user_bookmarks(uuid[]) to authenticated;

create or replace function public.library_status_for_saved_row(
  p_relation_id uuid,
  p_relation_published boolean,
  p_relation_is_active boolean,
  p_relation_curator_reviews integer,
  p_suggestion_status public.suggestion_status
) returns text
language sql
immutable
set search_path = public
as $fn$
  select case
    when p_relation_id is null and p_suggestion_status is null then 'private'
    when p_relation_published = true then 'in_catalog'
    when p_suggestion_status = 'declined' then 'not_added'
    when p_relation_id is not null
      and p_relation_is_active = true
      and coalesce(p_relation_curator_reviews, 0) >= 2 then 'not_added'
    when p_relation_id is not null
      and p_relation_is_active = false then 'not_added'
    else 'in_review'
  end;
$fn$;

revoke all on function public.library_status_for_saved_row(uuid, boolean, boolean, integer, public.suggestion_status) from public;

create or replace function public.get_user_library_resources(p_view text default 'saved')
returns table (
  library_view text,
  bookmark_id uuid,
  list_sort_order bigint,
  library_added_at timestamptz,
  watched_at timestamptz,
  catalog_status text,
  link_skill_relation_id uuid,
  relation_published boolean,
  relation_is_active boolean,
  relation_review_lane text,
  relation_curator_reviews integer,
  suggestion_id uuid,
  suggestion_status text,
  suggestion_review_lane text,
  public_note text,
  skill_level text,
  upvote_count integer,
  downvote_count integer,
  vote_score integer,
  value_score real,
  curator_score real,
  curator_reviews integer,
  user_score real,
  combined_score real,
  coach_take text,
  relation_created_at timestamptz,
  link_id uuid,
  url text,
  canonical_url text,
  domain text,
  title text,
  description text,
  thumbnail_url text,
  thumbnail_storage_path text,
  duration_seconds numeric,
  like_count integer,
  comment_count integer,
  share_count integer,
  favorite_count integer,
  creator_handle text,
  creator_url text,
  scoring_strategy text,
  content_type text,
  link_created_at timestamptz,
  contributor_profile_id uuid,
  contributor_slug text,
  contributor_display_name text,
  contributor_avatar_url text,
  contributor_accepted_count integer,
  skill_id uuid,
  skill_slug text,
  skill_name text,
  category_slug text,
  category_name text
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_user_id uuid := auth.uid();
  v_view text := lower(coalesce(nullif(p_view, ''), 'saved'));
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  if v_view not in ('saved', 'watched') then
    raise exception 'invalid library view: %', p_view using errcode = '22023';
  end if;

  if v_view = 'saved' then
    return query
      select
        'saved'::text as library_view,
        ub.id as bookmark_id,
        ub.sort_order as list_sort_order,
        ub.created_at as library_added_at,
        null::timestamptz as watched_at,
        public.library_status_for_saved_row(
          lsr.id,
          coalesce(lsr.published, false),
          coalesce(lsr.is_active, false),
          coalesce(lsr.curator_reviews, 0)::integer,
          sug.status
        ) as catalog_status,
        lsr.id as link_skill_relation_id,
        coalesce(lsr.published, false) as relation_published,
        coalesce(lsr.is_active, false) as relation_is_active,
        coalesce(lsr.review_lane, (sug.payload_json ->> 'review_lane')) as relation_review_lane,
        coalesce(lsr.curator_reviews, 0)::integer as relation_curator_reviews,
        sug.id as suggestion_id,
        sug.status::text as suggestion_status,
        sug.payload_json ->> 'review_lane' as suggestion_review_lane,
        coalesce(lsr.public_note, nullif(sug.payload_json ->> 'public_note', '')) as public_note,
        coalesce(lsr.skill_level, nullif(sug.payload_json ->> 'skill_level', '')) as skill_level,
        coalesce(lsr.upvote_count, 0)::integer as upvote_count,
        coalesce(lsr.downvote_count, 0)::integer as downvote_count,
        coalesce(lsr.vote_score, 0)::integer as vote_score,
        lsr.value_score,
        lsr.curator_score,
        lsr.curator_reviews::integer,
        lsr.user_score,
        lsr.combined_score,
        lsr.coach_take,
        lsr.created_at as relation_created_at,
        l.id as link_id,
        l.url,
        l.canonical_url,
        l.domain,
        l.title,
        l.description,
        l.thumbnail_url,
        l.thumbnail_storage_path,
        l.duration_seconds,
        l.like_count,
        l.comment_count,
        l.share_count,
        l.favorite_count,
        l.creator_handle,
        l.creator_url,
        l.scoring_strategy,
        l.content_type,
        l.created_at as link_created_at,
        cp.id as contributor_profile_id,
        cp.slug as contributor_slug,
        cp.display_name as contributor_display_name,
        cp.avatar_url as contributor_avatar_url,
        coalesce(cp.accepted_count, 0) as contributor_accepted_count,
        s.id as skill_id,
        s.slug as skill_slug,
        s.name as skill_name,
        c.slug as category_slug,
        c.name as category_name
      from public.user_bookmarks ub
      join public.links l on l.id = ub.link_id
      left join public.link_skill_relations lsr
        on lsr.id = ub.link_skill_relation_id
      left join public.suggestions sug
        on sug.id = ub.source_suggestion_id
      left join public.skills s
        on s.id = coalesce(lsr.skill_id, ub.skill_id, (sug.payload_json ->> 'target_skill_id')::uuid)
      left join public.categories c
        on c.id = s.category_id
      left join public.contributor_profiles cp
        on cp.id = l.contributor_profile_id
      where ub.user_id = v_user_id
        and l.is_active = true
      order by ub.sort_order asc, ub.created_at desc, ub.id asc;

    return;
  end if;

  return query
    select
      'watched'::text as library_view,
      null::uuid as bookmark_id,
      null::bigint as list_sort_order,
      uw.created_at as library_added_at,
      uw.watched_at,
      case when lsr.published then 'in_catalog' else 'not_added' end as catalog_status,
      lsr.id as link_skill_relation_id,
      lsr.published as relation_published,
      lsr.is_active as relation_is_active,
      lsr.review_lane as relation_review_lane,
      lsr.curator_reviews::integer as relation_curator_reviews,
      sug.id as suggestion_id,
      sug.status::text as suggestion_status,
      sug.payload_json ->> 'review_lane' as suggestion_review_lane,
      lsr.public_note,
      lsr.skill_level,
      lsr.upvote_count,
      lsr.downvote_count,
      lsr.vote_score,
      lsr.value_score,
      lsr.curator_score,
      lsr.curator_reviews::integer,
      lsr.user_score,
      lsr.combined_score,
      lsr.coach_take,
      lsr.created_at as relation_created_at,
      l.id as link_id,
      l.url,
      l.canonical_url,
      l.domain,
      l.title,
      l.description,
      l.thumbnail_url,
      l.thumbnail_storage_path,
      l.duration_seconds,
      l.like_count,
      l.comment_count,
      l.share_count,
      l.favorite_count,
      l.creator_handle,
      l.creator_url,
      l.scoring_strategy,
      l.content_type,
      l.created_at as link_created_at,
      cp.id as contributor_profile_id,
      cp.slug as contributor_slug,
      cp.display_name as contributor_display_name,
      cp.avatar_url as contributor_avatar_url,
      coalesce(cp.accepted_count, 0) as contributor_accepted_count,
      s.id as skill_id,
      s.slug as skill_slug,
      s.name as skill_name,
      c.slug as category_slug,
      c.name as category_name
    from public.user_watched uw
    join public.link_skill_relations lsr on lsr.id = uw.link_skill_relation_id
    join public.links l on l.id = lsr.link_id
    join public.skills s on s.id = lsr.skill_id
    join public.categories c on c.id = s.category_id
    left join public.suggestions sug on sug.id = lsr.source_suggestion_id
    left join public.contributor_profiles cp on cp.id = l.contributor_profile_id
    where uw.user_id = v_user_id
      and lsr.is_active = true
      and lsr.published = true
      and l.is_active = true
      and s.is_active = true
      and c.is_active = true
    order by uw.watched_at desc, uw.created_at desc;
end;
$fn$;

revoke all on function public.get_user_library_resources(text) from public;
grant execute on function public.get_user_library_resources(text) to authenticated;

create or replace function public.sync_user_bookmarks_for_published_relation()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if new.is_active = true and new.published = true then
    update public.user_bookmarks ub
       set link_skill_relation_id = new.id,
           skill_id = coalesce(ub.skill_id, new.skill_id),
           updated_at = now()
     where ub.link_id = new.link_id
       and (ub.skill_id is null or ub.skill_id = new.skill_id)
       and (ub.link_skill_relation_id is null or ub.link_skill_relation_id = new.id);
  end if;

  return new;
end;
$fn$;

drop trigger if exists link_skill_relations_sync_user_bookmarks on public.link_skill_relations;
create trigger link_skill_relations_sync_user_bookmarks
after insert or update of published, is_active, link_id, skill_id on public.link_skill_relations
for each row execute function public.sync_user_bookmarks_for_published_relation();

create or replace function public.recompute_contributor_accepted_count(p_profile_id uuid)
returns void
language sql
security definer
set search_path = public
as $fn$
  update public.contributor_profiles cp
     set accepted_count = coalesce((
       select count(distinct lsr.id)::integer
       from public.links l
       join public.link_skill_relations lsr on lsr.link_id = l.id
       where l.contributor_profile_id = cp.id
         and l.is_active = true
         and lsr.is_active = true
         and lsr.published = true
     ), 0)
   where cp.id = p_profile_id;
$fn$;

revoke all on function public.recompute_contributor_accepted_count(uuid) from public;

drop trigger if exists suggestions_sync_contributor_accepted_count on public.suggestions;

create or replace function public.sync_contributor_accepted_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_old_profile_id uuid;
  v_new_profile_id uuid;
begin
  if tg_op in ('UPDATE', 'DELETE') then
    select contributor_profile_id into v_old_profile_id
    from public.links
    where id = old.link_id;
    if v_old_profile_id is not null then
      perform public.recompute_contributor_accepted_count(v_old_profile_id);
    end if;
  end if;

  if tg_op in ('INSERT', 'UPDATE') then
    select contributor_profile_id into v_new_profile_id
    from public.links
    where id = new.link_id;
    if v_new_profile_id is not null
       and (v_old_profile_id is null or v_new_profile_id is distinct from v_old_profile_id) then
      perform public.recompute_contributor_accepted_count(v_new_profile_id);
    end if;
  end if;

  return coalesce(new, old);
end;
$fn$;

drop trigger if exists link_skill_relations_sync_contributor_accepted_count on public.link_skill_relations;
create trigger link_skill_relations_sync_contributor_accepted_count
after insert or delete or update of published, is_active, link_id on public.link_skill_relations
for each row execute function public.sync_contributor_accepted_count();

create or replace function public.sync_link_contributor_accepted_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if tg_op = 'UPDATE' then
    if old.contributor_profile_id is not null then
      perform public.recompute_contributor_accepted_count(old.contributor_profile_id);
    end if;
    if new.contributor_profile_id is not null
       and new.contributor_profile_id is distinct from old.contributor_profile_id then
      perform public.recompute_contributor_accepted_count(new.contributor_profile_id);
    end if;
  elsif tg_op = 'INSERT' then
    if new.contributor_profile_id is not null then
      perform public.recompute_contributor_accepted_count(new.contributor_profile_id);
    end if;
  end if;

  return coalesce(new, old);
end;
$fn$;

drop trigger if exists links_sync_contributor_accepted_count on public.links;
create trigger links_sync_contributor_accepted_count
after insert or update of contributor_profile_id, is_active on public.links
for each row execute function public.sync_link_contributor_accepted_count();

update public.contributor_profiles cp
   set accepted_count = coalesce((
     select count(distinct lsr.id)::integer
     from public.links l
     join public.link_skill_relations lsr on lsr.link_id = l.id
     where l.contributor_profile_id = cp.id
       and l.is_active = true
       and lsr.is_active = true
       and lsr.published = true
   ), 0);

drop function if exists public.apply_suggestion_transaction(uuid, uuid);
create function public.apply_suggestion_transaction(
  p_suggestion_id uuid,
  p_moderator_user_id uuid default null,
  p_keep_pending boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_suggestion public.suggestions%rowtype;
  v_payload jsonb;
  v_link_id uuid;
  v_relation_id uuid;
  v_target_skill_id uuid;
  v_target_category_id uuid;
  v_status public.suggestion_status;
  v_active_relation_count integer;
  v_slug text;
  v_contributor_profile_id uuid;
  v_review_lane text;
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
      'status', v_suggestion.status,
      'link_id', v_suggestion.link_id
    );
  end if;

  v_payload := v_suggestion.payload_json;
  v_review_lane := coalesce(nullif(v_payload ->> 'review_lane', ''), 'coach');
  if v_review_lane not in ('coach', 'founder', 'agent', 'private') then
    v_review_lane := 'coach';
  end if;
  v_status := case
    when p_keep_pending = true
      and v_suggestion.origin_type = 'human'
      and v_suggestion.status = 'pending' then 'pending'::public.suggestion_status
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
        thumbnail_storage_path,
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
        nullif(v_payload ->> 'thumbnail_storage_path', ''),
        nullif(v_payload ->> 'content_type', ''),
        coalesce(nullif(v_payload ->> 'language', ''), 'en'),
        case
          when nullif(v_payload ->> 'thumbnail_storage_path', '') is not null
            or nullif(v_payload ->> 'thumbnail_url', '') is not null then 'fetched'
          else 'pending'
        end,
        case
          when nullif(v_payload ->> 'thumbnail_storage_path', '') is not null
            or nullif(v_payload ->> 'thumbnail_url', '') is not null then now()
          else null
        end,
        v_contributor_profile_id,
        true
      )
      on conflict (canonical_url) do update set
        url = excluded.url,
        domain = excluded.domain,
        title = coalesce(excluded.title, public.links.title),
        description = coalesce(excluded.description, public.links.description),
        thumbnail_url = coalesce(excluded.thumbnail_url, public.links.thumbnail_url),
        thumbnail_storage_path = coalesce(excluded.thumbnail_storage_path, public.links.thumbnail_storage_path),
        content_type = coalesce(excluded.content_type, public.links.content_type),
        language = coalesce(excluded.language, public.links.language),
        preview_status = case
          when excluded.thumbnail_storage_path is not null or excluded.thumbnail_url is not null then 'fetched'
          else public.links.preview_status
        end,
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
        last_checked_at,
        submitted_by_user_id,
        source_suggestion_id,
        review_lane
      )
      values (
        v_link_id,
        v_target_skill_id,
        nullif(v_payload ->> 'public_note', ''),
        nullif(v_payload ->> 'skill_level', ''),
        true,
        now(),
        v_suggestion.submitted_by_user_id,
        v_suggestion.id,
        v_review_lane
      )
      on conflict (link_id, skill_id) do update set
        public_note = coalesce(excluded.public_note, public.link_skill_relations.public_note),
        skill_level = coalesce(excluded.skill_level, public.link_skill_relations.skill_level),
        submitted_by_user_id = coalesce(public.link_skill_relations.submitted_by_user_id, excluded.submitted_by_user_id),
        source_suggestion_id = coalesce(public.link_skill_relations.source_suggestion_id, excluded.source_suggestion_id),
        review_lane = case
          when public.link_skill_relations.review_lane = 'private' then excluded.review_lane
          else coalesce(nullif(public.link_skill_relations.review_lane, ''), excluded.review_lane)
        end,
        is_active = true,
        last_checked_at = now()
      returning id into v_relation_id;

      update public.suggestions
      set status = v_status,
          decided_at = case when v_status = 'pending' then null else now() end,
          moderator_user_id = case when v_status = 'pending' then null else p_moderator_user_id end,
          link_id = v_link_id,
          payload_json = jsonb_set(v_payload, '{review_lane}', to_jsonb(v_review_lane), true)
      where id = p_suggestion_id;

      return jsonb_build_object(
        'ok', true,
        'applied_changes', jsonb_build_array('link_upserted', 'relation_upserted'),
        'link_id', v_link_id,
        'relation_id', v_relation_id,
        'status', v_status,
        'review_lane', v_review_lane
      );

    when 'LINK_ATTACH_SKILL' then
      v_link_id := (v_payload ->> 'link_id')::uuid;
      v_target_skill_id := (v_payload ->> 'target_skill_id')::uuid;

      insert into public.link_skill_relations (
        link_id,
        skill_id,
        public_note,
        skill_level,
        is_active,
        last_checked_at,
        submitted_by_user_id,
        source_suggestion_id,
        review_lane
      )
      values (
        v_link_id,
        v_target_skill_id,
        nullif(v_payload ->> 'public_note', ''),
        nullif(v_payload ->> 'skill_level', ''),
        true,
        now(),
        v_suggestion.submitted_by_user_id,
        v_suggestion.id,
        v_review_lane
      )
      on conflict (link_id, skill_id) do update set
        public_note = coalesce(excluded.public_note, public.link_skill_relations.public_note),
        skill_level = coalesce(excluded.skill_level, public.link_skill_relations.skill_level),
        submitted_by_user_id = coalesce(public.link_skill_relations.submitted_by_user_id, excluded.submitted_by_user_id),
        source_suggestion_id = coalesce(public.link_skill_relations.source_suggestion_id, excluded.source_suggestion_id),
        is_active = true,
        last_checked_at = now()
      returning id into v_relation_id;

      update public.links
      set is_active = true,
          contributor_profile_id = coalesce(contributor_profile_id, v_contributor_profile_id)
      where id = v_link_id;
      update public.suggestions
         set status = v_status,
             decided_at = case when v_status = 'pending' then null else now() end,
             moderator_user_id = case when v_status = 'pending' then null else p_moderator_user_id end,
             link_id = v_link_id
       where id = p_suggestion_id;

      return jsonb_build_object('ok', true, 'applied_changes', jsonb_build_array('relation_attached'), 'relation_id', v_relation_id, 'link_id', v_link_id, 'status', v_status);

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
$fn$;

grant execute on function public.apply_suggestion_transaction(uuid, uuid, boolean) to service_role;

create or replace function public.get_unscored_for_coach(
  p_coach_role text,
  p_limit integer default 30
) returns table (
  relation_id uuid, source text, title text, description text, url text,
  duration_seconds numeric, like_count integer, comment_count integer,
  share_count integer, favorite_count integer, creator_handle text,
  skill_name text, category_name text, transcript text
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_limit integer;
begin
  if p_coach_role not in ('relevance', 'value') then
    raise exception 'invalid coach_role: %', p_coach_role;
  end if;

  v_limit := least(greatest(coalesce(p_limit, 30), 1), 60);

  return query
    with skill_pub as (
      select r.skill_id, count(*) filter (where r.is_active and r.published) as pub
      from public.link_skill_relations r
      group by r.skill_id
    )
    select
      lsr.id as relation_id,
      case
        when lower(l.domain) like '%tiktok.com%' or lower(l.url) like '%tiktok.com%' then 'tiktok'
        when lower(l.domain) like '%youtube.com%'
          or lower(l.domain) like '%youtu.be%'
          or lower(l.url) like '%youtube.com%'
          or lower(l.url) like '%youtu.be%' then 'youtube'
        else 'other'
      end as source,
      l.title,
      left(l.description, 300) as description,
      l.canonical_url as url,
      l.duration_seconds,
      l.like_count,
      l.comment_count,
      l.share_count,
      l.favorite_count,
      l.creator_handle,
      s.name as skill_name,
      c.name as category_name,
      left(lt.transcript_text, 5000) as transcript
    from public.link_skill_relations lsr
    join public.links l on l.id = lsr.link_id
    join public.skills s on s.id = lsr.skill_id
    join public.categories c on c.id = s.category_id
    join skill_pub sp on sp.skill_id = lsr.skill_id
    left join public.link_transcripts lt on lt.link_id = l.id
    where lsr.is_active = true
      and l.is_active = true
      and s.is_active = true
      and c.is_active = true
      and coalesce(lsr.review_lane, 'coach') = 'coach'
      and not exists (
        select 1
          from public.curator_votes cv
         where cv.link_skill_relation_id = lsr.id
           and cv.coach_role = p_coach_role
      )
    order by case when lsr.submitted_by_user_id is not null then 0 else 1 end asc,
             coalesce(sp.pub, 0) asc,
             lsr.created_at asc,
             lsr.id asc
    limit v_limit;
end;
$fn$;

comment on function public.get_unscored_for_coach(text, integer) is
  'Combined-coach queue: unvoted active coach-lane relations, 5000-char transcript excerpt + 300-char description, default 30 / cap 60. Human share-in rows float ahead of agent rows; within that, scarcity ordering still applies.';

revoke all on function public.get_unscored_for_coach(text, integer) from public, anon, authenticated;
grant execute on function public.get_unscored_for_coach(text, integer) to service_role;

commit;
