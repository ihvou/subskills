-- First-party product analytics.
--
-- Deliberately NOT a third-party SDK. The store listing claims "No ads. No
-- third-party trackers. Nothing about you is sold or shared", and adding
-- PostHog/Amplitude/Firebase would make that false and change the Data Safety
-- declaration. Every user already has a real Supabase identity (anonymous
-- included, since M120), so events can be first-party rows the user owns.
--
-- The table is deliberately thin and append-only. Funnels are derived in SQL
-- (see the views at the bottom) rather than precomputed, so the definition of
-- "activated" can change without a backfill.

create table if not exists public.app_events (
  id            uuid primary key default gen_random_uuid(),
  -- Null only if the event predates a session; every client path calls
  -- ensureSession() first, so in practice this is always set.
  user_id       uuid references auth.users(id) on delete cascade,
  event         text not null,
  platform      text,
  app_version   text,
  -- Client-generated, stable for one app run. Lets us count sessions without
  -- storing anything that identifies a device.
  session_id    text,
  props         jsonb not null default '{}'::jsonb,
  occurred_at   timestamptz not null default now(),
  created_at    timestamptz not null default now(),

  -- Bound the free-text fields. Without this a client can write arbitrarily
  -- large rows, and this table is writable by every anonymous user.
  constraint app_events_event_len check (char_length(event) between 1 and 64),
  constraint app_events_platform_ck check (platform is null or platform in ('ios','android','web')),
  constraint app_events_version_len check (app_version is null or char_length(app_version) <= 32),
  constraint app_events_session_len check (session_id is null or char_length(session_id) <= 64),
  constraint app_events_props_size check (pg_column_size(props) <= 4096)
);

comment on table public.app_events is
  'Append-only first-party product events. Written by the client with the user''s own JWT; read only by service role. Funnels are derived in SQL, not precomputed.';

-- Funnel queries slice by event within a time window; retention slices by user.
create index if not exists app_events_event_time_idx on public.app_events (event, occurred_at desc);
create index if not exists app_events_user_time_idx  on public.app_events (user_id, occurred_at desc);
create index if not exists app_events_time_idx       on public.app_events (occurred_at desc);

alter table public.app_events enable row level security;

-- Insert-only for the owner. No select policy at all: the client never needs to
-- read events back, and not granting select means one user's activity can never
-- leak to another even if a future policy is written carelessly.
drop policy if exists app_events_insert_own on public.app_events;
create policy app_events_insert_own on public.app_events
  for insert to authenticated
  with check (user_id = auth.uid());

-- No update/delete policies: the table is append-only for clients. Service role
-- bypasses RLS for retention pruning.

-- ---------------------------------------------------------------------------
-- Funnel: installed -> onboarded -> activated -> retained
--
-- One row per user, with the timestamp each stage was first reached. Null means
-- the user has not reached that stage. Feed this straight into a BI tool, or
-- count non-nulls for the four funnel numbers.
-- ---------------------------------------------------------------------------
create or replace view public.analytics_user_funnel as
with first_seen as (
  select
    user_id,
    min(occurred_at)                                             as installed_at,
    min(occurred_at) filter (where event = 'onboarding_completed') as onboarded_at,
    -- "Activated" = the user did something that creates a library. Deliberately
    -- a set of events rather than one, because any of them is the same moment
    -- of commitment.
    min(occurred_at) filter (
      where event in ('resource_saved','resource_watched','resource_voted','suggestion_submitted')
    )                                                            as activated_at
  from public.app_events
  where user_id is not null
  group by user_id
),
returns as (
  -- Retained = opened the app on a LATER calendar day than the first event.
  -- Calendar-day rather than 24h so a report reads the same as the dashboards
  -- people are used to.
  select f.user_id, min(e.occurred_at) as retained_at
  from first_seen f
  join public.app_events e
    on e.user_id = f.user_id
   and e.event = 'app_open'
   and e.occurred_at::date > f.installed_at::date
  group by f.user_id
)
select
  f.user_id,
  f.installed_at,
  f.onboarded_at,
  f.activated_at,
  r.retained_at,
  f.installed_at::date as install_date
from first_seen f
left join returns r on r.user_id = f.user_id;

comment on view public.analytics_user_funnel is
  'One row per user with the first timestamp for each funnel stage. Null = not reached. Service role only.';

-- Convenience rollup: the four funnel numbers per install cohort.
create or replace view public.analytics_funnel_by_cohort as
select
  install_date,
  count(*)                                        as installed,
  count(onboarded_at)                             as onboarded,
  count(activated_at)                             as activated,
  count(retained_at)                              as retained,
  round(100.0 * count(onboarded_at) / nullif(count(*), 0), 1)            as pct_onboarded,
  round(100.0 * count(activated_at) / nullif(count(onboarded_at), 0), 1) as pct_activated_of_onboarded,
  round(100.0 * count(retained_at)  / nullif(count(*), 0), 1)            as pct_retained
from public.analytics_user_funnel
group by install_date
order by install_date desc;

comment on view public.analytics_funnel_by_cohort is
  'Daily install cohorts with counts and conversion rates for each funnel stage.';

-- Views inherit the base table's RLS, and app_events has no select policy, so
-- only the service role can read these. Revoke anyway to make that explicit.
revoke all on public.analytics_user_funnel from anon, authenticated;
revoke all on public.analytics_funnel_by_cohort from anon, authenticated;
