alter type public.suggestion_type add value if not exists 'SOURCE_ADD';

alter table public.agent_runs
drop constraint if exists agent_runs_agent_type_check;

alter table public.agent_runs
add constraint agent_runs_agent_type_check
check (agent_type in ('link_searcher', 'link_checker', 'source_discoverer'));

alter table public.agent_runs
add column if not exists next_skill_priority_score numeric(10,3);

alter table public.trusted_sources
add column if not exists origin_type text not null default 'human'
  check (origin_type in ('human', 'agent', 'admin', 'import')),
add column if not exists discovered_at timestamptz,
add column if not exists discovery_score numeric(10,3),
add column if not exists discovery_evidence_json jsonb,
add column if not exists last_validated_at timestamptz,
add column if not exists last_seen_activity_at timestamptz;

create index if not exists agent_runs_priority_started_idx
on public.agent_runs (next_skill_priority_score, started_at desc)
where target_type = 'skill';

create index if not exists trusted_sources_discovered_idx
on public.trusted_sources (discovered_at desc)
where discovered_at is not null;
