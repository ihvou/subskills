-- Three corrections to 0063, from a code audit of the funnel work.
--
-- 1. pct_acted_of_installs could still exceed 100%. It divided `first_actors`
--    (users) by `installs` (install rows), two populations collected
--    independently: a user whose install ping never landed — an offline first
--    launch, a rate-limited ping — still writes events carrying an install_id,
--    joins to no app_installs row, falls back to first_event_at::date, and lands
--    in a cohort whose `installs` never counted them. So the rate that the whole
--    0063 exercise was about could break the same way as before. The numerator is
--    now the number of DISTINCT INSTALLS that produced an acting user, which is
--    provably a subset of that cohort's installs.
--
-- 2. The install a user is attributed to was picked nondeterministically:
--    array_agg with no ORDER BY, so a user with two installs could land in
--    different cohorts on different runs of the same query. No user has two
--    today, but on iOS the keychain survives app deletion, so a reinstall keeps
--    the account and mints a new install id — it becomes reachable as soon as the
--    client ships. Now the earliest event's install wins.
--
-- 3. app_installs still carried Supabase's default anon/authenticated GRANT ALL.
--    RLS with no policies did hold the door shut (verified: anon reads [] and
--    inserts 42501), but the grants meant any future policy, or RLS being turned
--    off, would expose the table to the key that ships inside the apps. 0062
--    revoked those grants on the tables that existed then; its event trigger only
--    turns RLS on for new ones, so everything created since inherited them.

begin;

-- 3 ---------------------------------------------------------------------------
revoke all on table public.app_installs from anon, authenticated;

-- 1 and 2 ---------------------------------------------------------------------
-- Dropped rather than replaced: the cohort view gains a column, and
-- `create or replace view` can only add columns at the end. Dependency order
-- matters — the cohort view reads the user one.
drop view if exists public.analytics_funnel_by_cohort;
drop view if exists public.analytics_user_funnel;

create view public.analytics_user_funnel as
with stages as (
  select
    e.user_id,
    -- Earliest event's install, deterministically. Without the ORDER BY this was
    -- whichever row the plan happened to produce first.
    (array_agg(e.install_id order by e.occurred_at, e.id)
       filter (where e.install_id is not null))[1]                   as install_id,
    min(e.occurred_at)                                               as first_event_at,
    min(e.occurred_at) filter (where e.event = 'onboarding_started') as onboarding_started_at,
    -- Finishing onboarding means leaving it, by either door. Counting only
    -- 'completed' was what made onboarding look like a funnel stage that
    -- activation depends on, which it is not.
    min(e.occurred_at) filter (
      where e.event in ('onboarding_completed', 'onboarding_skipped')
    )                                                                as onboarding_finished_at,
    min(e.occurred_at) filter (where e.event = 'onboarding_completed') as onboarding_completed_at,
    -- "Activated" = did something that creates a library. A set of events rather
    -- than one, because any of them is the same moment of commitment.
    min(e.occurred_at) filter (
      where e.event in ('resource_saved', 'resource_watched', 'resource_voted', 'suggestion_submitted')
    )                                                                as activated_at
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
  'One row per user with the first timestamp for each funnel stage; null means not reached. install_id is the install behind the user''s earliest event. The *_after_* columns are order-enforced variants for step rates. Service role only.';

create view public.analytics_funnel_by_cohort as
with installs as (
  select first_seen_at::date as cohort_date, count(*) as installs
  from public.app_installs
  group by 1
),
users as (
  select
    cohort_date,
    count(*)                              as first_actors,
    -- Installs that produced at least one acting user. Only rows whose install is
    -- actually in app_installs count, and those rows take their cohort_date from
    -- that install — so this can never exceed the cohort's install count, which
    -- first_actors could.
    count(distinct install_id) filter (where installed_at is not null)
                                          as installs_that_acted,
    count(onboarding_started_at)          as onboarding_started,
    count(onboarding_finished_at)         as onboarding_finished,
    count(onboarding_completed_at)        as onboarding_completed,
    count(finished_after_starting_at)     as finished_after_starting,
    count(activated_at)                   as activated,
    count(activated_after_onboarding_at)  as activated_after_onboarding,
    count(retained_at)                    as retained
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
  coalesce(u.installs_that_acted, 0)     as installs_that_acted,
  coalesce(u.onboarding_started, 0)      as onboarding_started,
  coalesce(u.onboarding_finished, 0)     as onboarding_finished,
  coalesce(u.onboarding_completed, 0)    as onboarding_completed,
  coalesce(u.activated, 0)               as activated,
  coalesce(u.retained, 0)                as retained,

  -- Share of real installs that ever did anything. Null before install tracking
  -- existed, because there is genuinely no denominator for those days. Counted
  -- over installs, not users: a user whose install ping never landed is invisible
  -- here rather than inflating the rate past 100%.
  round(100.0 * u.installs_that_acted / nullif(i.installs, 0), 1)              as pct_acted_of_installs,
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
  'Daily cohorts with funnel counts and conversion rates. installs is the true top (0 before 2026-09-18); first_actors is what the 0058 view misnamed "installed"; installs_that_acted is the install-side numerator for pct_acted_of_installs. Every rate now has a numerator provably inside its denominator, so none can exceed 100%. Cohort dates are calendar dates in the database timezone (UTC). Service role only.';

revoke all on public.analytics_user_funnel from anon, authenticated;
revoke all on public.analytics_funnel_by_cohort from anon, authenticated;

commit;
