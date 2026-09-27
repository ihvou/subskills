-- 0060: remember that a clip could not be transcribed, so it is not retried forever.
--
-- THE PROBLEM. A short-form clip whose audio is music produces no usable speech,
-- and the transcriber deliberately stores nothing for it — storing what whisper
-- returns for a song would feed the coach a Spanish lyric as surfing technique.
-- But "stored nothing" is indistinguishable from "never attempted", so
-- scripts/fetch-shortform-transcripts.mjs selects the same clip on every run and
-- pays for the download and the whisper pass again. Observed directly: two
-- consecutive runs re-processed the identical two TikToks. Across roughly 150
-- such links that is about twelve minutes of pointless downloading a night, and
-- it never converges. This had to be fixed before the gap-filler goes on a cron.
--
-- WHY NOT A ZERO-LENGTH link_transcripts ROW. Two reasons. char_count > 0 is
-- enforced, and more importantly a row in that table is served to the coach as
-- a transcript — the absence of one is load-bearing, and encoding "we tried"
-- into it would put text in front of the coach that we specifically judged
-- unusable.
--
-- WHY THE REASON DECIDES THE COOLDOWN. The reasons are not alike:
--
--   too_short, low_speech_density, not_a_video
--       properties of the clip. A music-only demo will still be music-only next
--       month. Long cooldown.
--
--   download_had_no_audio, no_audio_stream, download_failed
--       properties of OUR access, not of the clip. The instructive case: this
--       verdict was firing on roughly half of TikToks because yt-dlp preferred
--       the bytevc1 (h265) renditions, whose format metadata advertises aac and
--       which deliver video only. That was our bug, fixed by preferring h264,
--       and every clip written off under it deserves another attempt. Short
--       cooldown, so a tooling fix reclaims the backlog on its own.
--
-- Neither cooldown is permanent. A reel can be reuploaded with sound and the
-- density gate may be retuned, so an attempt expires rather than blacklisting.
begin;

create table if not exists public.link_transcript_attempts (
  link_id uuid primary key references public.links(id) on delete cascade,
  reason text not null,
  attempts integer not null default 1,
  -- What whisper actually got, kept so the gate can be retuned against real
  -- numbers rather than guesses about where the threshold should sit.
  seconds numeric,
  chars integer,
  chars_per_second numeric,
  last_attempt_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.link_transcript_attempts is
  'One row per short-form link that could not be transcribed, so the gap-filler stops re-downloading it every run. Cooldown depends on the reason: clip properties wait long, access failures wait briefly (0060).';

create index if not exists link_transcript_attempts_retry_idx
  on public.link_transcript_attempts (last_attempt_at);

drop trigger if exists link_transcript_attempts_set_updated_at on public.link_transcript_attempts;
create trigger link_transcript_attempts_set_updated_at
  before update on public.link_transcript_attempts
  for each row execute function public.set_updated_at();

alter table public.link_transcript_attempts enable row level security;
revoke all on table public.link_transcript_attempts from public, anon, authenticated;
grant select, insert, update, delete on table public.link_transcript_attempts to service_role;

commit;
