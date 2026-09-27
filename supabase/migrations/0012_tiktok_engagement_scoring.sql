begin;

alter table public.trusted_sources
drop constraint if exists trusted_sources_source_type_check;

alter table public.trusted_sources
add constraint trusted_sources_source_type_check
check (source_type in ('youtube_channel', 'domain', 'rss', 'tiktok_search'));

alter table public.links
add column if not exists duration_seconds numeric(8,2),
add column if not exists like_count integer,
add column if not exists comment_count integer,
add column if not exists share_count integer,
add column if not exists favorite_count integer,
add column if not exists thumbnail_url text,
add column if not exists creator_handle text,
add column if not exists creator_url text,
add column if not exists scoring_strategy text not null default 'transcript_llm'
  check (scoring_strategy in ('transcript_llm', 'engagement_authority'));

create table if not exists public.creators (
  id uuid primary key default gen_random_uuid(),
  platform text not null check (platform in ('youtube', 'tiktok')),
  handle text not null,
  nickname text,
  bio text,
  bio_link text,
  followers_count integer,
  following_count integer,
  videos_count integer,
  verified boolean not null default false,
  authority_score numeric(10,3),
  last_probed_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (platform, handle)
);

create index if not exists creators_platform_followers_idx
on public.creators (platform, followers_count desc nulls last);

drop trigger if exists creators_set_updated_at on public.creators;
create trigger creators_set_updated_at
before update on public.creators
for each row execute function public.set_updated_at();

alter table public.creators enable row level security;

drop policy if exists "active creators are public" on public.creators;
create policy "active creators are public"
on public.creators for select
to anon, authenticated
using (is_active = true);

drop policy if exists "moderators manage creators" on public.creators;
create policy "moderators manage creators"
on public.creators for all
to authenticated
using (public.is_moderator())
with check (public.is_moderator());

alter table public.links
add column if not exists creator_id uuid references public.creators(id);

create index if not exists links_creator_id_idx
on public.links (creator_id)
where creator_id is not null;

commit;
