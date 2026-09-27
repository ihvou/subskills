create extension if not exists supabase_vault with schema vault;

create or replace function public.is_moderator()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.moderators
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
      and is_active = true
  );
$$;

create or replace function public.get_vault_secret(secret_name text)
returns text
language sql
stable
security definer
set search_path = public, vault
as $$
  select decrypted_secret
  from vault.decrypted_secrets
  where name = secret_name
  limit 1;
$$;

revoke execute on function public.get_vault_secret(text) from public, anon, authenticated;
grant execute on function public.get_vault_secret(text) to service_role;

with ranked as (
  select
    id,
    row_number() over (
      partition by dedupe_key
      order by
        case status
          when 'auto_approved' then 1
          when 'approved' then 2
          when 'pending' then 3
          else 4
        end,
        created_at
    ) as rank
  from public.suggestions
  where status in ('pending','approved','auto_approved')
)
update public.suggestions
set status = 'declined',
    decided_at = coalesce(decided_at, now())
where id in (select id from ranked where rank > 1);

alter table public.suggestions
drop constraint if exists suggestions_dedupe_key_status_key;

drop index if exists public.suggestions_dedupe_key_status_key;
drop index if exists public.suggestions_active_dedupe_key_idx;

create unique index suggestions_active_dedupe_key_idx
on public.suggestions (dedupe_key)
where status in ('pending','approved','auto_approved');

create table if not exists public.agent_run_events (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.agent_runs(id) on delete cascade,
  level text not null check (level in ('debug','info','warn','error')),
  event_type text not null,
  message text not null,
  metadata_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists agent_run_events_run_created_idx
on public.agent_run_events (run_id, created_at);

alter table public.agent_run_events enable row level security;

drop policy if exists "moderators manage agent run events" on public.agent_run_events;
create policy "moderators manage agent run events"
on public.agent_run_events for all
to authenticated
using (public.is_moderator())
with check (public.is_moderator());

create or replace function public.get_skill_resource_counts(p_skill_ids uuid[])
returns table(skill_id uuid, resource_count bigint)
language sql
stable
security definer
set search_path = public
as $$
  select lsr.skill_id, count(*)::bigint
  from public.link_skill_relations lsr
  where lsr.is_active
    and lsr.skill_id = any(p_skill_ids)
  group by lsr.skill_id;
$$;

grant execute on function public.get_skill_resource_counts(uuid[]) to anon, authenticated;
