-- Two fixes to the product-analytics funnel added in 0058_app_events.sql.
--
-- FIX 1 — the cohort view reported impossible conversion rates.
--   pct_activated_of_onboarded divided `activated` (counted over ALL users) by
--   `onboarded` (only users who COMPLETED onboarding). Onboarding is optional in
--   this app — onboarding_skipped is a real event, and 6 of 13 users activated
--   without ever completing it — so the numerator was not a subset of the
--   denominator and the rate came out at 200% and 300%. Fed to a BI tool that
--   renders as a funnel which widens in the middle.
--
--   Every rate below now has a denominator its numerator is provably a subset of,
--   and step rates additionally require the steps to be in chronological order
--   (one user activated BEFORE finishing onboarding, so ordering was not implied).
--
-- FIX 2 — "installed" was not installs.
--   The anonymous user is created lazily on first real action (M120), and
--   analytics.ts deliberately queues pre-session events rather than creating an
--   identity just to log one. A user who installs, opens the app, browses and
--   never acts therefore produces no auth.users row and no app_events row at all:
--   they are invisible. `installed` meant "users who eventually did something",
--   which is why activated/installed was 12/13 — near-100% by construction.
--
--   public.app_installs fixes the denominator. It needs no identity, so it counts
--   the people app_events cannot see.

begin;

-- ---------------------------------------------------------------------------
-- app_installs — the real top of the funnel
-- ---------------------------------------------------------------------------
create table if not exists public.app_installs (
  install_id    uuid primary key,
  platform      text,
  app_version   text,
  -- Server-set on purpose. This is a cohort boundary, so unlike app_events.occurred_at
  -- it must not be movable by a device with a wrong clock.
  first_seen_at timestamptz not null default now(),
  constraint app_installs_platform_ck check (platform is null or platform in ('ios','android','web')),
  constraint app_installs_version_len check (app_version is null or char_length(app_version) <= 32)
);

comment on table public.app_installs is
  'One row per app install, written by the unauthenticated track-install edge function. Needs no identity, so it captures the users app_events cannot see. Counts FIRST LAUNCHES, not store installs: a reinstall wipes local storage and produces a new id, so treat it as directional.';

create index if not exists app_installs_first_seen_idx on public.app_installs (first_seen_at desc);

alter table public.app_installs enable row level security;
-- No policies at all: service role only, matching app_events. The edge function
-- holds the service key; the anon key shipped in the apps can do nothing here.

-- ---------------------------------------------------------------------------
-- Tie events to an install, so the funnel can run install -> activation
-- ---------------------------------------------------------------------------
alter table public.app_events add column if not exists install_id uuid;

comment on column public.app_events.install_id is
  'The install that produced this event. Null for every event written before 2026-09-18, and for any client older than the build that started sending it.';

create index if not exists app_events_install_idx on public.app_events (install_id, occurred_at);

-- The insert policy only constrains user_id, so clients may set install_id freely.
-- It is a client-generated opaque id with no authority attached to it.

-- ---------------------------------------------------------------------------
-- Per-user stage timestamps. No rates here — this is a fact table.
--
-- Dropped rather than replaced: the column list changes shape, and
-- `create or replace view` can only add columns to the end. Dependency order
-- matters — the cohort view reads this one.
-- ---------------------------------------------------------------------------
drop view if exists public.analytics_funnel_by_cohort;
drop view if exists public.analytics_user_funnel;

create view public.analytics_user_funnel as
with stages as (
  select
    e.user_id,
    (array_agg(e.install_id) filter (where e.install_id is not null))[1] as install_id,
    min(e.occurred_at)                                                   as first_event_at,
    min(e.occurred_at) filter (where e.event = 'onboarding_started')     as onboarding_started_at,
    -- Finishing onboarding means leaving it, by either door. Counting only
    -- 'completed' was what made onboarding look like a funnel stage that
    -- activation depends on, which it is not.
    min(e.occurred_at) filter (
      where e.event in ('onboarding_completed', 'onboarding_skipped')
    )                                                                    as onboarding_finished_at,
    min(e.occurred_at) filter (where e.event = 'onboarding_completed')   as onboarding_completed_at,
    -- "Activated" = did something that creates a library. A set of events rather
    -- than one, because any of them is the same moment of commitment.
    min(e.occurred_at) filter (
      where e.event in ('resource_saved', 'resource_watched', 'resource_voted', 'suggestion_submitted')
    )                                                                    as activated_at
  from public.app_events e
  where e.user_id is not null
  group by e.user_id
),
returns as (
  -- Retained = opened the app on a LATER calendar day than the first event.
  -- Calendar-day rather than 24h so a report reads the same as the dashboards
  -- people are used to.
  select s.user_id, min(e.occurred_at) as retained_at
  from stages s
  join public.app_events e
    on e.user_id = s.user_id
   and e.event = 'app_open'
   and e.occurred_at::date > s.first_event_at::date
  group by s.user_id
)
select
  s.user_id,
  s.install_id,
  s.first_event_at,
  s.onboarding_started_at,
  s.onboarding_finished_at,
  s.onboarding_completed_at,
  s.activated_at,
  r.retained_at,
  -- Order-enforced variants. A step rate is only meaningful when the later step
  -- actually happened after the earlier one, and here it sometimes did not.
  case when s.onboarding_started_at is not null
        and s.onboarding_finished_at >= s.onboarding_started_at
       then s.onboarding_finished_at end as finished_after_starting_at,
  case when s.onboarding_finished_at is not null
        and s.activated_at >= s.onboarding_finished_at
       then s.activated_at end           as activated_after_onboarding_at,
  -- The install's own date when we have one, else the first event we saw. Mixed
  -- by design: cohorts before install tracking existed still need a date.
  coalesce(i.first_seen_at::date, s.first_event_at::date) as cohort_date,
  i.first_seen_at                                        as installed_at
from stages s
left join returns r on r.user_id = s.user_id
left join public.app_installs i on i.install_id = s.install_id;

comment on view public.analytics_user_funnel is
  'One row per user with the first timestamp for each funnel stage; null means not reached. The *_after_* columns are order-enforced variants for step rates. Service role only.';

-- ---------------------------------------------------------------------------
-- Cohort rollup. Every rate's numerator is a subset of its denominator.
-- ---------------------------------------------------------------------------
create view public.analytics_funnel_by_cohort as
with installs as (
  select first_seen_at::date as cohort_date, count(*) as installs
  from public.app_installs
  group by 1
),
users as (
  select
    cohort_date,
    count(*)                                  as first_actors,
    count(onboarding_started_at)              as onboarding_started,
    count(onboarding_finished_at)             as onboarding_finished,
    count(onboarding_completed_at)            as onboarding_completed,
    count(finished_after_starting_at)         as finished_after_starting,
    count(activated_at)                       as activated,
    count(activated_after_onboarding_at)      as activated_after_onboarding,
    count(retained_at)                        as retained
  from public.analytics_user_funnel
  group by cohort_date
),
-- Full outer join: a cohort can have installs with nobody acting yet, and the
-- cohorts from before install tracking have actors but no installs.
spine as (
  select cohort_date from installs
  union
  select cohort_date from users
)
select
  sp.cohort_date,
  coalesce(i.installs, 0)                as installs,
  coalesce(u.first_actors, 0)            as first_actors,
  coalesce(u.onboarding_started, 0)      as onboarding_started,
  coalesce(u.onboarding_finished, 0)     as onboarding_finished,
  coalesce(u.onboarding_completed, 0)    as onboarding_completed,
  coalesce(u.activated, 0)               as activated,
  coalesce(u.retained, 0)                as retained,

  -- Share of real installs that ever did anything. Null before install tracking
  -- existed, because there is genuinely no denominator for those days.
  round(100.0 * u.first_actors / nullif(i.installs, 0), 1)                     as pct_acted_of_installs,
  -- The rest are shares of users we can actually see. Each numerator is a subset
  -- of first_actors, so none of these can exceed 100%.
  round(100.0 * u.onboarding_started / nullif(u.first_actors, 0), 1)           as pct_onboarding_started,
  round(100.0 * u.onboarding_finished / nullif(u.first_actors, 0), 1)          as pct_onboarding_finished,
  round(100.0 * u.activated / nullif(u.first_actors, 0), 1)                    as pct_activated,
  round(100.0 * u.retained / nullif(u.first_actors, 0), 1)                     as pct_retained,
  -- Step rates: numerator restricted to users who reached the previous step AND
  -- reached this one afterwards.
  round(100.0 * u.finished_after_starting / nullif(u.onboarding_started, 0), 1)     as pct_finished_of_started,
  round(100.0 * u.activated_after_onboarding / nullif(u.onboarding_finished, 0), 1) as pct_activated_of_onboarded
from spine sp
left join installs i on i.cohort_date = sp.cohort_date
left join users    u on u.cohort_date = sp.cohort_date
order by sp.cohort_date desc;

comment on view public.analytics_funnel_by_cohort is
  'Daily cohorts with funnel counts and conversion rates. installs is the true top (null/0 before 2026-09-18); first_actors is what the old view misnamed "installed". Every rate is a subset of its denominator, so none can exceed 100%. Service role only.';

revoke all on public.analytics_user_funnel from anon, authenticated;
revoke all on public.analytics_funnel_by_cohort from anon, authenticated;

commit;
