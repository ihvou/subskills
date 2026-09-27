-- 0034: per-(skill, channel) search rotation, so the trusted-channel pool can grow
--       without the nightly run getting proportionally slower.
--
-- THE PROBLEM. loadChannels() in scripts/run-collection.mjs has no ORDER BY and no
-- LIMIT: it returns every active channel in the skill's category, and the collection
-- loop searches all of them, for every query, for every skill. Cost is linear in pool
-- size, and each yt-dlp call carries --sleep-requests (currently 10s), so channel count
-- translates almost directly into wall-clock.
--
-- Measured on the 2026-08-12 nightly run: 830 channel searches / 3.5 queries per skill
-- = ~237 channel-visits in the 6h budget, at ~4.2 channels per skill, covering 62 of
-- 152 skills before the run was SIGTERMed (exit 124) mid-skill on foot-strike.
--
-- Expanding trusted_sources from 61 to ~250 channels would raise the average to ~19
-- channels per skill, cutting the nightly reach from ~60 skills to ~12. This migration
-- is the precondition for that expansion.
--
-- THE FIX. Record which channels each skill has already been searched against, so
-- loadChannels() can take a bounded slice ordered "never searched for this skill first,
-- then longest ago". Each skill then round-robins its own category's channels across
-- successive nights at constant per-night cost.
--
-- Why the pair and not a single last_searched_at column on trusted_sources: a global
-- column couples channel rotation to skill rotation. Within one night the first skill
-- of a category would take channels 1-5, the next 6-10, and so on, so which channels a
-- skill sees depends on how many same-category skills happened to run before it. The
-- two cycles can alias, leaving some (skill, channel) pairs starved indefinitely.
-- Keying on the pair makes each skill's walk independent and deterministic.
--
-- A newly inserted channel has no row here, so it sorts first for EVERY skill and is
-- picked up on the next run of each — which is what makes a bulk source expansion blend
-- into the catalogue immediately rather than eventually.

begin;

create table if not exists public.skill_source_searches (
  skill_id uuid not null references public.skills(id) on delete cascade,
  source_id uuid not null references public.trusted_sources(id) on delete cascade,
  last_searched_at timestamptz not null default now(),
  search_count integer not null default 1,
  primary key (skill_id, source_id)
);

-- The read path is "for this skill, order candidate channels by last_searched_at
-- nulls first". Covering index on (skill_id, last_searched_at).
create index if not exists skill_source_searches_skill_recency_idx
on public.skill_source_searches (skill_id, last_searched_at);

alter table public.skill_source_searches enable row level security;

-- Same posture as the other collection-internal tables: service_role only, no
-- anon/authenticated read. Nothing in the web app reads this.
drop policy if exists skill_source_searches_service_all on public.skill_source_searches;
create policy skill_source_searches_service_all
on public.skill_source_searches for all
to service_role
using (true)
with check (true);

commit;
