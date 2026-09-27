begin;

create table if not exists public.link_transcripts (
  link_id uuid primary key references public.links(id) on delete cascade,
  source text not null default 'youtube'
    check (source in ('youtube')),
  provider text not null
    check (provider in ('ytdlp', 'browser', 'disk_backfill', 'manual')),
  video_id text,
  language text,
  transcript_text text not null check (char_length(transcript_text) > 0),
  char_count integer generated always as (char_length(transcript_text)) stored,
  transcript_hash text not null,
  fetched_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (char_count > 0)
);

comment on table public.link_transcripts is
  'Full scraped transcripts keyed by link. Used by offline scoring/backfill jobs; not exposed through the public API.';
comment on column public.link_transcripts.provider is
  'Fetcher/import path that produced the current transcript.';
comment on column public.link_transcripts.transcript_hash is
  'SHA-256 of the normalized transcript text for idempotent imports and drift checks.';
comment on column public.link_transcripts.char_count is
  'Generated character count for the normalized transcript text.';

create index if not exists link_transcripts_video_id_idx
on public.link_transcripts (video_id)
where video_id is not null;

create index if not exists link_transcripts_fetched_at_idx
on public.link_transcripts (fetched_at desc);

drop trigger if exists link_transcripts_set_updated_at on public.link_transcripts;
create trigger link_transcripts_set_updated_at
before update on public.link_transcripts
for each row execute function public.set_updated_at();

alter table public.link_transcripts enable row level security;

revoke all on public.link_transcripts from public, anon, authenticated;
grant select, insert, update, delete on public.link_transcripts to service_role;

commit;
