begin;

-- M44/M69: expose one canonical public ordering key. The current formula lives in
-- combined_score (coach curation + damped community vote), and publication remains
-- gated by curator_score after 0052.
alter table public.link_skill_relations
  add column if not exists rank_key real generated always as (combined_score) stored;

comment on column public.link_skill_relations.rank_key is
  'Canonical public resource ranking key. Generated from combined_score so server caps and client display sort by the same value.';

create index if not exists link_skill_relations_skill_rank_published_idx
  on public.link_skill_relations (skill_id, rank_key desc, created_at desc, id)
  where is_active and published;

-- M69: return only the top N resources per requested skill. This keeps category
-- rails close to their rendered size instead of sending an entire category's
-- relation table over the wire and slicing it on device.
create or replace function public.get_ranked_skill_relations(
  p_skill_ids uuid[],
  p_per_skill integer default 12,
  p_sort text default 'popular',
  p_level text default 'all',
  p_source text default 'all'
)
returns setof public.link_skill_relations
language sql
stable
security definer
set search_path = public
as $fn$
  with normalized as (
    select
      coalesce(p_skill_ids, '{}'::uuid[]) as skill_ids,
      greatest(1, least(coalesce(p_per_skill, 12), 100)) as per_skill,
      case when lower(coalesce(p_sort, 'popular')) = 'newest' then 'newest' else 'popular' end as sort_key,
      case
        when lower(coalesce(p_level, 'all')) in ('all', 'beginner', 'intermediate', 'advanced', 'unlabeled')
          then lower(coalesce(p_level, 'all'))
        else 'all'
      end as level_key,
      case
        when lower(coalesce(p_source, 'all')) in ('all', 'youtube', 'tiktok', 'instagram')
          then lower(coalesce(p_source, 'all'))
        else 'all'
      end as source_key
  ),
  ranked as (
    select
      lsr.id,
      row_number() over (
        partition by lsr.skill_id
        order by
          case when n.sort_key = 'newest' then lsr.created_at end desc nulls last,
          case when n.sort_key = 'popular' then lsr.rank_key end desc nulls last,
          lsr.created_at desc,
          lsr.id asc
      ) as rn
    from normalized n
    join public.link_skill_relations lsr
      on lsr.skill_id = any(n.skill_ids)
    join public.links l
      on l.id = lsr.link_id
    where lsr.is_active = true
      and lsr.published = true
      and l.is_active = true
      and (
        n.level_key = 'all'
        or (n.level_key = 'unlabeled' and lsr.skill_level is null)
        or lsr.skill_level = n.level_key
      )
      and (
        n.source_key = 'all'
        or (
          n.source_key = 'youtube'
          and (
            coalesce(l.domain, '') ilike '%youtube%'
            or coalesce(l.domain, '') ilike '%youtu.be%'
            or coalesce(l.url, '') ilike '%youtube.com%'
            or coalesce(l.url, '') ilike '%youtu.be%'
            or coalesce(l.canonical_url, '') ilike '%youtube.com%'
            or coalesce(l.canonical_url, '') ilike '%youtu.be%'
          )
        )
        or (
          n.source_key = 'tiktok'
          and (
            coalesce(l.domain, '') ilike '%tiktok.com%'
            or coalesce(l.url, '') ilike '%tiktok.com%'
            or coalesce(l.canonical_url, '') ilike '%tiktok.com%'
            or coalesce(l.thumbnail_storage_path, '') ilike '%/tiktok/%'
          )
        )
        or (
          n.source_key = 'instagram'
          and (
            coalesce(l.domain, '') ilike '%instagram.com%'
            or coalesce(l.url, '') ilike '%instagram.com%'
            or coalesce(l.canonical_url, '') ilike '%instagram.com%'
            or coalesce(l.thumbnail_storage_path, '') ilike '%/instagram/%'
          )
        )
      )
  )
  select lsr.*
  from ranked
  join public.link_skill_relations lsr
    on lsr.id = ranked.id
  cross join normalized n
  where ranked.rn <= n.per_skill
  order by
    lsr.skill_id,
    case when n.sort_key = 'newest' then lsr.created_at end desc nulls last,
    case when n.sort_key = 'popular' then lsr.rank_key end desc nulls last,
    lsr.created_at desc,
    lsr.id asc;
$fn$;

comment on function public.get_ranked_skill_relations(uuid[], integer, text, text, text) is
  'Top-N active published link_skill_relations per skill, ordered by rank_key or newest, with optional level/source filters.';

revoke all on function public.get_ranked_skill_relations(uuid[], integer, text, text, text) from public;
grant execute on function public.get_ranked_skill_relations(uuid[], integer, text, text, text) to anon, authenticated;

-- MI24: progress rows for Library skill chips. Derived, auth-scoped, and safe
-- for anonymous identities because they still use the authenticated role.
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
    join public.link_skill_relations lsr
      on lsr.id = uw.link_skill_relation_id
    join public.links l
      on l.id = lsr.link_id
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

comment on function public.get_user_skill_progress(uuid[]) is
  'Auth-scoped watched-vs-target progress for requested skills. Target is least(3, published active resource count).';

revoke all on function public.get_user_skill_progress(uuid[]) from public;
grant execute on function public.get_user_skill_progress(uuid[]) to authenticated;

-- M56: Watch later is a queue. Once a user watches a link, keep the bookmark row
-- for history/order preservation but remove it from the saved view.
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
          join public.link_skill_relations watched_lsr
            on watched_lsr.id = watched.link_skill_relation_id
          where watched.user_id = v_user_id
            and watched_lsr.link_id = ub.link_id
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

commit;
