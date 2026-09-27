alter table public.link_skill_relations
add column if not exists downvote_count integer not null default 0 check (downvote_count >= 0);

alter table public.link_skill_relations
add column if not exists vote_score integer generated always as (greatest(upvote_count - downvote_count, 0)) stored;

update public.link_skill_relations
set upvote_count = greatest(upvote_count, 0),
    downvote_count = greatest(downvote_count, 0);

alter table public.user_actions
add column if not exists link_skill_relation_id uuid;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'user_actions_link_skill_relation_id_fkey'
      and conrelid = 'public.user_actions'::regclass
  ) then
    alter table public.user_actions
    add constraint user_actions_link_skill_relation_id_fkey
    foreign key (link_skill_relation_id)
    references public.link_skill_relations(id)
    on delete cascade;
  end if;
end;
$$;

alter table public.user_actions
add column if not exists action_context_id uuid generated always as (
  coalesce(link_skill_relation_id, '00000000-0000-0000-0000-000000000000'::uuid)
) stored;

drop trigger if exists user_actions_sync_vote_count on public.user_actions;

update public.user_actions as ua
set link_skill_relation_id = (
  select id
  from public.link_skill_relations
  where link_id = ua.link_id
  order by is_active desc, upvote_count desc, created_at asc
  limit 1
)
where ua.action_type in ('upvote', 'downvote')
  and ua.link_skill_relation_id is null;

delete from public.user_actions
where action_type in ('upvote', 'downvote')
  and link_skill_relation_id is null;

alter table public.user_actions
drop constraint if exists user_actions_pkey;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'user_actions_unique_context'
      and conrelid = 'public.user_actions'::regclass
  ) then
    alter table public.user_actions
    add constraint user_actions_unique_context
    unique (user_id, link_id, action_type, action_context_id);
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'user_actions_vote_context_required'
      and conrelid = 'public.user_actions'::regclass
  ) then
    alter table public.user_actions
    add constraint user_actions_vote_context_required
    check (action_type not in ('upvote', 'downvote') or link_skill_relation_id is not null);
  end if;
end;
$$;

create index if not exists user_actions_relation_idx
on public.user_actions (link_skill_relation_id)
where link_skill_relation_id is not null;

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

drop trigger if exists user_actions_validate_context on public.user_actions;
create trigger user_actions_validate_context
before insert or update on public.user_actions
for each row execute function public.validate_user_action_context();

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
      where id = new.link_skill_relation_id
        and link_id = new.link_id;
    elsif new.action_type = 'downvote' then
      update public.link_skill_relations
      set downvote_count = downvote_count + 1
      where id = new.link_skill_relation_id
        and link_id = new.link_id;
    end if;
    return new;
  end if;

  if tg_op = 'DELETE' then
    if old.action_type = 'upvote' then
      update public.link_skill_relations
      set upvote_count = greatest(upvote_count - 1, 0)
      where id = old.link_skill_relation_id
        and link_id = old.link_id;
    elsif old.action_type = 'downvote' then
      update public.link_skill_relations
      set downvote_count = greatest(downvote_count - 1, 0)
      where id = old.link_skill_relation_id
        and link_id = old.link_id;
    end if;
    return old;
  end if;

  return null;
end;
$$;

create trigger user_actions_sync_vote_count
after insert or delete on public.user_actions
for each row execute function public.sync_user_action_vote_count();

create or replace function public.check_suggest_rate_limit(
  p_ip text,
  p_limit integer,
  p_window_seconds integer
)
returns table (allowed boolean, request_count integer, window_start timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ip text := coalesce(nullif(trim(p_ip), ''), 'unknown');
  v_now timestamptz := now();
  v_window interval := make_interval(secs => greatest(p_window_seconds, 1));
  v_row public.suggest_rate_limits%rowtype;
begin
  select *
  into v_row
  from public.suggest_rate_limits
  where ip = v_ip
  for update;

  if not found then
    insert into public.suggest_rate_limits (ip, window_start, count, updated_at)
    values (v_ip, v_now, 1, v_now)
    returning * into v_row;

    allowed := true;
    request_count := v_row.count;
    window_start := v_row.window_start;
    return next;
    return;
  end if;

  if v_row.window_start < v_now - v_window then
    update public.suggest_rate_limits
    set window_start = v_now,
        count = 1,
        updated_at = v_now
    where ip = v_ip
    returning * into v_row;

    allowed := true;
    request_count := v_row.count;
    window_start := v_row.window_start;
    return next;
    return;
  end if;

  if v_row.count >= p_limit then
    allowed := false;
    request_count := v_row.count;
    window_start := v_row.window_start;
    return next;
    return;
  end if;

  update public.suggest_rate_limits
  set count = count + 1,
      updated_at = v_now
  where ip = v_ip
  returning * into v_row;

  allowed := true;
  request_count := v_row.count;
  window_start := v_row.window_start;
  return next;
end;
$$;

revoke all on function public.check_suggest_rate_limit(text, integer, integer) from public, anon, authenticated;
grant execute on function public.check_suggest_rate_limit(text, integer, integer) to service_role;

select cron.schedule(
  'cleanup_suggest_rate_limits',
  '0 3 * * *',
  $$delete from public.suggest_rate_limits where window_start < now() - interval '24 hours';$$
)
where not exists (select 1 from cron.job where jobname = 'cleanup_suggest_rate_limits');
