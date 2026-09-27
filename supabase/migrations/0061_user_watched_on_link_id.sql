begin;

-- M158: Watched state is a property of a link, not of a catalogue relation.
--
-- user_watched was keyed on (user_id, link_skill_relation_id) with the relation
-- NOT NULL. A link saved privately — the share-in flow with the catalogue
-- toggle off — has no relation, so there was no row that could represent
-- "I watched this", and the app had to refuse the action with an alert. This
-- moves the table onto link_id, exactly as 0053 did for user_bookmarks.
--
-- Backfill is clean on production data: 23 rows, 0 orphaned relations.

alter table public.user_watched
  add column if not exists id uuid,
  add column if not exists link_id uuid,
  add column if not exists skill_id uuid,
  add column if not exists source_suggestion_id uuid;

update public.user_watched
   set id = gen_random_uuid()
 where id is null;

update public.user_watched uw
   set link_id = lsr.link_id,
       skill_id = coalesce(uw.skill_id, lsr.skill_id)
  from public.link_skill_relations lsr
 where uw.link_skill_relation_id = lsr.id
   and uw.link_id is null;

-- Foreign keys should make this a no-op on healthy data. An orphaned legacy row
-- cannot be represented by the new link-keyed model.
delete from public.user_watched
 where link_id is null;

-- Two relations on the same link collapse to one watched row. Keep the earliest
-- watch, since that is when the user actually saw the video.
with ranked as (
  select
    id,
    row_number() over (
      partition by user_id, link_id
      order by watched_at asc, link_skill_relation_id nulls last, id
    ) as rn
  from public.user_watched
)
delete from public.user_watched uw
using ranked r
where uw.id = r.id
  and r.rn > 1;

-- The old primary key is (user_id, link_skill_relation_id), and Postgres refuses
-- `drop not null` on a column that is still part of a primary key
-- (SQLSTATE 42P16). So the constraint has to go FIRST, then the column nullability
-- changes, then the new key. Do not reorder these three statements.
alter table public.user_watched
  drop constraint if exists user_watched_pkey;

alter table public.user_watched
  alter column id set default gen_random_uuid(),
  alter column id set not null,
  alter column link_id set not null,
  alter column link_skill_relation_id drop not null;

alter table public.user_watched
  add constraint user_watched_pkey primary key (id);

alter table public.user_watched
  drop constraint if exists user_watched_link_id_fkey,
  add constraint user_watched_link_id_fkey
    foreign key (link_id) references public.links(id) on delete cascade,
  drop constraint if exists user_watched_skill_id_fkey,
  add constraint user_watched_skill_id_fkey
    foreign key (skill_id) references public.skills(id) on delete set null,
  drop constraint if exists user_watched_source_suggestion_id_fkey,
  add constraint user_watched_source_suggestion_id_fkey
    foreign key (source_suggestion_id) references public.suggestions(id) on delete set null;

-- The relation FK was ON DELETE CASCADE, from when the relation *was* the key.
-- Now that the row stands on its own, dropping a relation must not take the
-- user's history with it — the row degrades to a private watch instead.
-- user_bookmarks has the same problem for the same reason; fix both.
alter table public.user_watched
  drop constraint if exists user_watched_link_skill_relation_id_fkey,
  add constraint user_watched_link_skill_relation_id_fkey
    foreign key (link_skill_relation_id) references public.link_skill_relations(id) on delete set null;

alter table public.user_bookmarks
  drop constraint if exists user_bookmarks_link_skill_relation_id_fkey,
  add constraint user_bookmarks_link_skill_relation_id_fkey
    foreign key (link_skill_relation_id) references public.link_skill_relations(id) on delete set null;

create unique index if not exists user_watched_user_link_idx
on public.user_watched (user_id, link_id);

create index if not exists user_watched_relation_idx
on public.user_watched (link_skill_relation_id)
where link_skill_relation_id is not null;

comment on table public.user_watched is
  'Private Watched rows keyed by user_id + link_id. link_skill_relation_id is nullable so private/share-in saves can be marked watched and survive review state changes.';

-- ---------------------------------------------------------------------------
-- Writers
-- ---------------------------------------------------------------------------

-- Mirrors upsert_user_bookmark_for_link. Attributes are filled in on first
-- write and only ever upgraded, never blanked by a later, thinner call.
create or replace function public.upsert_user_watched_for_link(
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
  v_watched_id uuid;
begin
  if p_user_id is null then
    raise exception 'user_id is required' using errcode = '22023';
  end if;
  if p_link_id is null then
    raise exception 'link_id is required' using errcode = '22023';
  end if;

  insert into public.user_watched (
    user_id,
    link_id,
    skill_id,
    link_skill_relation_id,
    source_suggestion_id,
    watched_at
  )
  values (
    p_user_id,
    p_link_id,
    p_skill_id,
    p_relation_id,
    p_source_suggestion_id,
    now()
  )
  on conflict (user_id, link_id) do update set
    -- Keep the original timestamp: re-marking something already watched must
    -- not move it to the top of the list.
    watched_at = coalesce(public.user_watched.watched_at, excluded.watched_at),
    skill_id = coalesce(excluded.skill_id, public.user_watched.skill_id),
    link_skill_relation_id =
      coalesce(excluded.link_skill_relation_id, public.user_watched.link_skill_relation_id),
    source_suggestion_id =
      coalesce(excluded.source_suggestion_id, public.user_watched.source_suggestion_id),
    updated_at = now()
  returning id into v_watched_id;

  return v_watched_id;
end;
$fn$;

revoke all on function public.upsert_user_watched_for_link(uuid, uuid, uuid, uuid, uuid) from public;
grant execute on function public.upsert_user_watched_for_link(uuid, uuid, uuid, uuid, uuid) to authenticated;

-- Unchanged signature and unchanged validation: TestFlight builds 12-14 and the
-- web app both call this with a published relation id and must keep working.
-- Only the storage underneath moved.
create or replace function public.set_user_watched(p_relation_id uuid, p_watched boolean)
returns table (
  link_skill_relation_id uuid,
  watched boolean,
  watched_at timestamptz
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

  if coalesce(p_watched, false) then
    perform public.upsert_user_watched_for_link(
      v_user_id,
      v_relation.link_id,
      v_relation.skill_id,
      v_relation.id,
      null
    );
  else
    delete from public.user_watched uw
     where uw.user_id = v_user_id
       and uw.link_id = v_relation.link_id;
  end if;

  return query
    select
      p_relation_id,
      (uw.user_id is not null),
      uw.watched_at
    from (select 1) seed
    left join public.user_watched uw
      on uw.user_id = v_user_id
     and uw.link_id = v_relation.link_id;
end;
$fn$;

revoke all on function public.set_user_watched(uuid, boolean) from public;
revoke execute on function public.set_user_watched(uuid, boolean) from anon;
grant execute on function public.set_user_watched(uuid, boolean) to authenticated;

-- The link-keyed entry point, for rows that have no catalogue relation. Mirrors
-- set_user_link_bookmark. Skill and relation are inherited from the user's own
-- saved row when there is one, so marking a share-in watched does not lose the
-- sport and skill the user picked in the share sheet.
create or replace function public.set_user_link_watched(p_link_id uuid, p_watched boolean)
returns table (
  link_id uuid,
  watched boolean,
  watched_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_user_id uuid := auth.uid();
  v_link_id uuid;
  v_bookmark record;
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

  if coalesce(p_watched, false) then
    select ub.skill_id, ub.link_skill_relation_id, ub.source_suggestion_id
      into v_bookmark
      from public.user_bookmarks ub
     where ub.user_id = v_user_id
       and ub.link_id = v_link_id;

    perform public.upsert_user_watched_for_link(
      v_user_id,
      v_link_id,
      v_bookmark.skill_id,
      v_bookmark.link_skill_relation_id,
      v_bookmark.source_suggestion_id
    );
  else
    delete from public.user_watched uw
     where uw.user_id = v_user_id
       and uw.link_id = v_link_id;
  end if;

  return query
    select
      v_link_id,
      (uw.user_id is not null),
      uw.watched_at
    from (select 1) seed
    left join public.user_watched uw
      on uw.user_id = v_user_id
     and uw.link_id = v_link_id;
end;
$fn$;

revoke all on function public.set_user_link_watched(uuid, boolean) from public;
revoke execute on function public.set_user_link_watched(uuid, boolean) from anon;
grant execute on function public.set_user_link_watched(uuid, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- Readers
-- ---------------------------------------------------------------------------

-- Both branches now resolve identically: the link is the spine, and the
-- relation, suggestion, skill and category are optional decoration. Before
-- this, the watched branch inner-joined the relation and would simply drop a
-- private watch from the list.
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
        and not exists (
          select 1
          from public.user_watched watched
          where watched.user_id = v_user_id
            and watched.link_id = ub.link_id
        )
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
    from public.user_watched uw
    join public.links l on l.id = uw.link_id
    left join public.link_skill_relations lsr
      on lsr.id = uw.link_skill_relation_id
    left join public.suggestions sug
      on sug.id = uw.source_suggestion_id
    left join public.skills s
      on s.id = coalesce(lsr.skill_id, uw.skill_id, (sug.payload_json ->> 'target_skill_id')::uuid)
    left join public.categories c
      on c.id = s.category_id
    left join public.contributor_profiles cp
      on cp.id = l.contributor_profile_id
    where uw.user_id = v_user_id
      and l.is_active = true
    order by uw.watched_at desc, uw.created_at desc, uw.id asc;
end;
$fn$;

revoke all on function public.get_user_library_resources(text) from public;
grant execute on function public.get_user_library_resources(text) to anon, authenticated;

-- Progress stays a measure of the *catalogue*: how much of what is published for
-- this skill the user has watched. A private watch has nothing to be a fraction
-- of, so it does not count — otherwise watched_count could exceed total_count
-- and a skill would complete without a single catalogue video.
--
-- Counting through link_id rather than the relation the user happened to tap is
-- also more accurate: watching one video credits every published relation that
-- video has, so a video filed under two skills advances both.
create or replace function public.get_user_skill_progress(p_skill_ids uuid[])
returns table (
  skill_id uuid,
  total_count integer,
  watched_count integer,
  target integer,
  completed boolean
)
language sql
stable
security definer
set search_path = public
as $fn$
  with requested as (
    select distinct id as skill_id
    from unnest(coalesce(p_skill_ids, '{}'::uuid[])) as input(id)
    where auth.uid() is not null
  ),
  totals as (
    select
      lsr.skill_id,
      count(*)::integer as total_count
    from public.link_skill_relations lsr
    join requested r on r.skill_id = lsr.skill_id
    join public.links l on l.id = lsr.link_id
    where lsr.is_active = true
      and lsr.published = true
      and l.is_active = true
    group by lsr.skill_id
  ),
  watched as (
    select
      lsr.skill_id,
      count(distinct lsr.id)::integer as watched_count
    from public.user_watched uw
    join public.links l
      on l.id = uw.link_id
    join public.link_skill_relations lsr
      on lsr.link_id = uw.link_id
    join requested r
      on r.skill_id = lsr.skill_id
    where uw.user_id = auth.uid()
      and lsr.is_active = true
      and lsr.published = true
      and l.is_active = true
    group by lsr.skill_id
  )
  select
    r.skill_id,
    coalesce(t.total_count, 0)::integer as total_count,
    coalesce(w.watched_count, 0)::integer as watched_count,
    least(3, coalesce(t.total_count, 0))::integer as target,
    (
      coalesce(t.total_count, 0) > 0
      and coalesce(w.watched_count, 0) >= least(3, coalesce(t.total_count, 0))
    ) as completed
  from requested r
  left join totals t on t.skill_id = r.skill_id
  left join watched w on w.skill_id = r.skill_id
  order by r.skill_id;
$fn$;

revoke all on function public.get_user_skill_progress(uuid[]) from public;
grant execute on function public.get_user_skill_progress(uuid[]) to anon, authenticated;

commit;
