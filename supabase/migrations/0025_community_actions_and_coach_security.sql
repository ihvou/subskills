begin;

alter table public.link_skill_relations
  add column if not exists user_score real not null default 0,
  add column if not exists combined_score real not null default 0,
  add column if not exists coach_take text;

comment on column public.link_skill_relations.user_score is
  'Authenticated community vote aggregate: +1 per upvote, -1 per downvote.';
comment on column public.link_skill_relations.combined_score is
  'Ranking and publish score: curator_score + user_score.';
comment on column public.link_skill_relations.coach_take is
  'Latest public coach comment suitable for user-facing cards.';

create index if not exists link_skill_relations_published_combined_score_idx
on public.link_skill_relations (
  skill_id,
  combined_score desc,
  curator_reviews desc,
  created_at desc
)
where is_active and published;

create table if not exists public.user_relation_votes (
  user_id uuid not null references auth.users(id) on delete cascade,
  link_skill_relation_id uuid not null references public.link_skill_relations(id) on delete cascade,
  vote smallint not null check (vote in (-1, 1)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, link_skill_relation_id)
);

comment on table public.user_relation_votes is
  'Private authenticated vote state for one user per resource relation.';

create table if not exists public.user_bookmarks (
  user_id uuid not null references auth.users(id) on delete cascade,
  link_skill_relation_id uuid not null references public.link_skill_relations(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, link_skill_relation_id)
);

comment on table public.user_bookmarks is
  'Private authenticated saved-resource state.';

create table if not exists public.user_watched (
  user_id uuid not null references auth.users(id) on delete cascade,
  link_skill_relation_id uuid not null references public.link_skill_relations(id) on delete cascade,
  watched_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, link_skill_relation_id)
);

comment on table public.user_watched is
  'Private authenticated watched/completed-resource state.';

create index if not exists user_relation_votes_relation_idx
on public.user_relation_votes (link_skill_relation_id);

create index if not exists user_bookmarks_user_created_idx
on public.user_bookmarks (user_id, created_at desc);

create index if not exists user_watched_user_watched_idx
on public.user_watched (user_id, watched_at desc);

drop trigger if exists user_relation_votes_set_updated_at on public.user_relation_votes;
create trigger user_relation_votes_set_updated_at
before update on public.user_relation_votes
for each row execute function public.set_updated_at();

drop trigger if exists user_watched_set_updated_at on public.user_watched;
create trigger user_watched_set_updated_at
before update on public.user_watched
for each row execute function public.set_updated_at();

alter table public.user_relation_votes enable row level security;
alter table public.user_bookmarks enable row level security;
alter table public.user_watched enable row level security;

drop policy if exists "users read own relation votes" on public.user_relation_votes;
create policy "users read own relation votes"
on public.user_relation_votes for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "users read own bookmarks" on public.user_bookmarks;
create policy "users read own bookmarks"
on public.user_bookmarks for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "users read own watched" on public.user_watched;
create policy "users read own watched"
on public.user_watched for select
to authenticated
using (user_id = auth.uid());

grant select on public.user_relation_votes to authenticated;
grant select on public.user_bookmarks to authenticated;
grant select on public.user_watched to authenticated;
grant all on public.user_relation_votes to service_role;
grant all on public.user_bookmarks to service_role;
grant all on public.user_watched to service_role;

revoke all on function public.get_unscored_for_coach(text, integer) from public;
revoke execute on function public.get_unscored_for_coach(text, integer) from anon, authenticated;
grant execute on function public.get_unscored_for_coach(text, integer) to service_role;

revoke all on function public.set_curator_vote(uuid, text, real, text, text) from public;
revoke execute on function public.set_curator_vote(uuid, text, real, text, text) from anon, authenticated;
grant execute on function public.set_curator_vote(uuid, text, real, text, text) to service_role;

create or replace function public.refresh_relation_scores(p_relation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_upvotes integer := 0;
  v_downvotes integer := 0;
  v_user_score real := 0;
  v_coach_take text;
begin
  select
    count(*) filter (where urv.vote = 1)::integer,
    count(*) filter (where urv.vote = -1)::integer,
    coalesce(sum(urv.vote), 0)::real
  into v_upvotes, v_downvotes, v_user_score
  from public.user_relation_votes urv
  where urv.link_skill_relation_id = p_relation_id;

  select nullif(trim(cv.comment_public), '')
    into v_coach_take
    from public.curator_votes cv
   where cv.link_skill_relation_id = p_relation_id
     and nullif(trim(cv.comment_public), '') is not null
   order by
     case cv.coach_role when 'value' then 0 else 1 end,
     cv.updated_at desc
   limit 1;

  update public.link_skill_relations lsr
     set upvote_count = v_upvotes,
         downvote_count = v_downvotes,
         user_score = v_user_score,
         combined_score = (
           coalesce(lsr.relevance_vote, 0::real)
           + coalesce(lsr.value_vote, 0::real)
           + v_user_score
         ),
         coach_take = v_coach_take,
         updated_at = now()
   where lsr.id = p_relation_id;
end;
$fn$;

revoke all on function public.refresh_relation_scores(uuid) from public;

create or replace function public.sync_curator_vote_aggregates()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    perform public.refresh_curator_vote_aggregates(old.link_skill_relation_id);
    perform public.refresh_relation_scores(old.link_skill_relation_id);
  end if;

  if tg_op in ('INSERT', 'UPDATE')
     and (tg_op <> 'UPDATE' or new.link_skill_relation_id is distinct from old.link_skill_relation_id) then
    perform public.refresh_curator_vote_aggregates(new.link_skill_relation_id);
    perform public.refresh_relation_scores(new.link_skill_relation_id);
  end if;

  return coalesce(new, old);
end;
$fn$;

revoke all on function public.sync_curator_vote_aggregates() from public;

create or replace function public.sync_user_relation_vote_aggregates()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    perform public.refresh_relation_scores(old.link_skill_relation_id);
  end if;

  if tg_op in ('INSERT', 'UPDATE')
     and (tg_op <> 'UPDATE' or new.link_skill_relation_id is distinct from old.link_skill_relation_id) then
    perform public.refresh_relation_scores(new.link_skill_relation_id);
  end if;

  return coalesce(new, old);
end;
$fn$;

revoke all on function public.sync_user_relation_vote_aggregates() from public;

drop trigger if exists user_relation_votes_sync_aggregates on public.user_relation_votes;
create trigger user_relation_votes_sync_aggregates
after insert or update or delete on public.user_relation_votes
for each row execute function public.sync_user_relation_vote_aggregates();

create or replace function public.validate_user_action_context()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.action_type in ('saved', 'completed') then
    new.link_skill_relation_id := null;
    return new;
  end if;

  if new.action_type in ('upvote', 'downvote') and auth.uid() is not null then
    raise exception 'Vote actions must use set_user_vote' using errcode = '42501';
  end if;

  if new.link_skill_relation_id is null then
    raise exception 'Vote actions require link_skill_relation_id' using errcode = '23514';
  end if;

  if not exists (
    select 1
    from public.link_skill_relations
    where id = new.link_skill_relation_id
      and link_id = new.link_id
  ) then
    raise exception 'Vote action relation must belong to link_id' using errcode = '23514';
  end if;

  return new;
end;
$$;

revoke all on function public.validate_user_action_context() from public;

create or replace function public.sync_user_action_vote_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_next_vote smallint;
begin
  if tg_op = 'INSERT' then
    if new.action_type in ('upvote', 'downvote') then
      insert into public.user_relation_votes (
        user_id,
        link_skill_relation_id,
        vote,
        created_at,
        updated_at
      )
      values (
        new.user_id,
        new.link_skill_relation_id,
        case when new.action_type = 'upvote' then 1 else -1 end,
        new.created_at,
        now()
      )
      on conflict (user_id, link_skill_relation_id) do update
         set vote = excluded.vote,
             updated_at = now();
    end if;
    return new;
  end if;

  if tg_op = 'DELETE' then
    if old.action_type in ('upvote', 'downvote') then
      select case when ua.action_type = 'upvote' then 1 else -1 end
        into v_next_vote
        from public.user_actions ua
       where ua.user_id = old.user_id
         and ua.link_skill_relation_id = old.link_skill_relation_id
         and ua.action_type in ('upvote', 'downvote')
       order by ua.created_at desc, ua.action_type desc
       limit 1;

      if v_next_vote is null then
        delete from public.user_relation_votes urv
         where urv.user_id = old.user_id
           and urv.link_skill_relation_id = old.link_skill_relation_id;
      else
        update public.user_relation_votes urv
           set vote = v_next_vote,
               updated_at = now()
         where urv.user_id = old.user_id
           and urv.link_skill_relation_id = old.link_skill_relation_id;
      end if;
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

insert into public.user_relation_votes (
  user_id,
  link_skill_relation_id,
  vote,
  created_at,
  updated_at
)
select distinct on (ua.user_id, ua.link_skill_relation_id)
  ua.user_id,
  ua.link_skill_relation_id,
  case when ua.action_type = 'upvote' then 1 else -1 end,
  ua.created_at,
  now()
from public.user_actions ua
where ua.action_type in ('upvote', 'downvote')
  and ua.link_skill_relation_id is not null
order by ua.user_id, ua.link_skill_relation_id, ua.created_at desc, ua.action_type desc
on conflict (user_id, link_skill_relation_id) do update
   set vote = excluded.vote,
       updated_at = now();

with aggregates as (
  select
    urv.link_skill_relation_id,
    count(*) filter (where urv.vote = 1)::integer as upvotes,
    count(*) filter (where urv.vote = -1)::integer as downvotes,
    coalesce(sum(urv.vote), 0)::real as user_score
  from public.user_relation_votes urv
  group by urv.link_skill_relation_id
),
coach_takes as (
  select distinct on (cv.link_skill_relation_id)
    cv.link_skill_relation_id,
    nullif(trim(cv.comment_public), '') as coach_take
  from public.curator_votes cv
  where nullif(trim(cv.comment_public), '') is not null
  order by
    cv.link_skill_relation_id,
    case cv.coach_role when 'value' then 0 else 1 end,
    cv.updated_at desc
)
update public.link_skill_relations lsr
   set upvote_count = coalesce(aggregates.upvotes, 0),
       downvote_count = coalesce(aggregates.downvotes, 0),
       user_score = coalesce(aggregates.user_score, 0),
       combined_score = (
         coalesce(lsr.relevance_vote, 0::real)
         + coalesce(lsr.value_vote, 0::real)
         + coalesce(aggregates.user_score, 0)
       ),
       coach_take = coach_takes.coach_take,
       updated_at = now()
  from public.link_skill_relations source
  left join aggregates on aggregates.link_skill_relation_id = source.id
  left join coach_takes on coach_takes.link_skill_relation_id = source.id
 where lsr.id = source.id;

create or replace function public.set_user_vote(
  p_relation_id uuid,
  p_vote smallint
) returns table (
  link_skill_relation_id uuid,
  vote smallint,
  user_score real,
  combined_score real,
  published boolean
)
language plpgsql
security definer
set search_path = public
as $fn$
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
    on conflict (user_id, link_skill_relation_id) do update
       set vote = excluded.vote,
           updated_at = now();
  end if;

  perform public.refresh_relation_publish_gate(2::smallint, 1.3::real, false);

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
$fn$;

revoke all on function public.set_user_vote(uuid, smallint) from public;
grant execute on function public.set_user_vote(uuid, smallint) to authenticated;

create or replace function public.set_user_bookmark(
  p_relation_id uuid,
  p_saved boolean
) returns table (
  link_skill_relation_id uuid,
  saved boolean,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $fn$
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
    on conflict (user_id, link_skill_relation_id) do nothing;
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
$fn$;

revoke all on function public.set_user_bookmark(uuid, boolean) from public;
grant execute on function public.set_user_bookmark(uuid, boolean) to authenticated;

create or replace function public.set_user_watched(
  p_relation_id uuid,
  p_watched boolean
) returns table (
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
    on conflict (user_id, link_skill_relation_id) do update
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
$fn$;

revoke all on function public.set_user_watched(uuid, boolean) from public;
grant execute on function public.set_user_watched(uuid, boolean) to authenticated;

create or replace function public.refresh_relation_publish_gate(
  p_min_reviews smallint default 2,
  p_min_score real default 1.3,
  p_unpublish_unreviewed boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_min_reviews smallint := greatest(coalesce(p_min_reviews, 2), 1);
  v_min_score real := coalesce(p_min_score, 1.3);
  v_published integer := 0;
  v_unpublished integer := 0;
  v_result jsonb;
begin
  with publishable as (
    select lsr.id
    from public.link_skill_relations lsr
    join public.links l on l.id = lsr.link_id
    where lsr.is_active = true
      and lsr.published = false
      and l.is_active = true
      and lsr.curator_reviews >= v_min_reviews
      and lsr.combined_score >= v_min_score
  ),
  published_rows as (
    update public.link_skill_relations lsr
       set published = true,
           published_at = coalesce(lsr.published_at, now()),
           updated_at = now()
      from publishable p
     where lsr.id = p.id
     returning lsr.id
  )
  select count(*)::integer into v_published
  from published_rows;

  with unpublishable as (
    select lsr.id
    from public.link_skill_relations lsr
    join public.links l on l.id = lsr.link_id
    where lsr.published = true
      and (
        lsr.is_active = false
        or l.is_active = false
        or (
          lsr.curator_reviews >= v_min_reviews
          and lsr.combined_score < v_min_score
        )
        or (
          p_unpublish_unreviewed = true
          and lsr.curator_reviews < v_min_reviews
        )
      )
  ),
  unpublished_rows as (
    update public.link_skill_relations lsr
       set published = false,
           published_at = null,
           updated_at = now()
      from unpublishable u
     where lsr.id = u.id
     returning lsr.id
  )
  select count(*)::integer into v_unpublished
  from unpublished_rows;

  v_result := jsonb_build_object(
    'ok', true,
    'published_count', v_published,
    'unpublished_count', v_unpublished,
    'min_reviews', v_min_reviews,
    'min_score', v_min_score,
    'unpublish_unreviewed', p_unpublish_unreviewed,
    'score_column', 'combined_score'
  );

  insert into public.relation_publish_gate_runs (
    min_reviews,
    min_score,
    unpublish_unreviewed,
    published_count,
    unpublished_count,
    metadata_json
  )
  values (
    v_min_reviews,
    v_min_score,
    p_unpublish_unreviewed,
    v_published,
    v_unpublished,
    v_result
  );

  return v_result;
end;
$fn$;

comment on function public.refresh_relation_publish_gate(smallint, real, boolean) is
  'Publishes fully-reviewed active relations using combined_score and unpublishes inactive or fully-reviewed low-scoring relations.';

revoke all on function public.refresh_relation_publish_gate(smallint, real, boolean) from public;
grant execute on function public.refresh_relation_publish_gate(smallint, real, boolean) to service_role;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'relation_publish_gate_15min') then
    perform cron.unschedule('relation_publish_gate_15min');
  end if;
end;
$$;

select cron.schedule(
  'relation_publish_gate_15min',
  '*/15 * * * *',
  $$select public.refresh_relation_publish_gate(2::smallint, 1.3::real, false);$$
);

commit;
