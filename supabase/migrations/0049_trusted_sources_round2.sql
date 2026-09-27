-- 0049: trusted-source expansion round 2 (+32) from an independent ChatGPT pass.
--
-- Source: docs/chatgpt-trusted-sources-prompt.md. 37 candidates proposed; every one
-- was re-validated here against the real gates by resolving its latest upload with
-- yt-dlp -- subscriber count, last-upload date, and a sample of recent titles to
-- judge format. Their own metadata was stale in several places, so independent
-- verification mattered:
--   * Top Speed Golf: reported "~2 months ago", actually 8 days.
--   * Meandmygolf: reported "May 2026", actually 3 days.
--   * Coach Jess: reported "~4 months ago", actually 11 days.
--   * John Connors: reported "~4-5 months ago", actually 2 days.
-- All three channels they marked "Conditional" in Golf/BJJ resolved cleanly and are
-- included; the unresolved channel IDs (Kesting, SilverFox, Deb Armstrong, Warren
-- Smith, Ed Ju, Flying Pickle, Universal Rackets, PechPong) were all resolved here.
--
-- REJECTED ON LIVENESS (their claim did not survive checking):
--   Tyson McGuffin Pickleball -- reported active "~5 days ago"; actual last upload
--     2025-12-30, ~8 months idle. Pickleball has no seasonality defence.
--   howtoskiapp -- last upload 2019-04-07, seven years idle.
--
-- REJECTED ON FORMAT after sampling recent uploads (all three were flagged by the
-- report itself as mixed; sampling confirmed it):
--   Ryan Knapton -- recent feed is riding footage and board demos ("Sun Boots
--     Snowboarding #1", "Lucas Snowboarding on the Martin Snowboards RKT 150"),
--     not tutorials.
--   John Connors -- mindset and lifestyle ("What 27 Years of Jiu-Jitsu Taught Me
--     About Confidence"), not technique.
--   Hard Is Easy -- rope-physics experiments and entertainment ("Neox does NOT like
--     DIRT!", "Sketchy Low Falls | Ep.13") rather than instruction. Same call made
--     when it surfaced in our own harvest for 0046.
--
-- SEASONAL PASSES: Darren Turner (2026-01-24) and Deb Armstrong (2026-02-19) are
-- past the 180-day idle gate but published during the last northern-hemisphere
-- winter, which is the correct liveness test for ski channels -- see the note in 0047.
begin;

insert into public.trusted_sources (source_type, identifier, display_name, category_id, is_active, origin_type) values
  -- 388k, 2026-08-17
  ('youtube_channel', 'UClOp9ASmFYATO1zFfpB7QlA', 'Eric Cogorno Golf', (select id from public.categories where slug = 'golf'), true, 'human'),
  -- 190k, 2026-08-13
  ('youtube_channel', 'UCsdU6wpjCe-s-8NR75aTnMQ', 'Porzak Golf', (select id from public.categories where slug = 'golf'), true, 'human'),
  -- 720k, 2026-08-12
  ('youtube_channel', 'UC_iddZiEUKR0Byb_eHbHHAQ', 'Top Speed Golf', (select id from public.categories where slug = 'golf'), true, 'human'),
  -- 65.7k, 2026-08-17
  ('youtube_channel', 'UCfeAhVD6-RJUn5T65F3_kBQ', 'Andrew Cullen PGA', (select id from public.categories where slug = 'golf'), true, 'human'),
  -- 52.5k, 2026-08-17
  ('youtube_channel', 'UC8mb9jkIteXUVnpuqnmNREg', 'True Swing by Erika Larkin', (select id from public.categories where slug = 'golf'), true, 'human'),
  -- 107k, 2026-08-16
  ('youtube_channel', 'UCHVQWDSbgwei0qsBXLYBvLA', 'Andy Carter Golf', (select id from public.categories where slug = 'golf'), true, 'human'),
  -- 1.10M, 2026-08-17; format sampled - single-technique
  ('youtube_channel', 'UCTwywdg9Sw5xs4wdN-qz7yw', 'Meandmygolf', (select id from public.categories where slug = 'golf'), true, 'human'),
  -- 254k, 2026-08-18; report's caveat resolved
  ('youtube_channel', 'UCvtpTGbGiMgI8gWlsMUmdLA', 'Athletic Motion Golf', (select id from public.categories where slug = 'golf'), true, 'human'),
  -- 52.9k, 2026-08-15; report's caveat resolved
  ('youtube_channel', 'UC14EwLYUwQ_hZJG09z8O2kw', 'Rob Cheney Golf', (select id from public.categories where slug = 'golf'), true, 'human'),
  -- 144k, 2026-07-22
  ('youtube_channel', 'UCcE-QCzqcSMkfz9O5hTI7iA', 'Doctor Karol Table Tennis', (select id from public.categories where slug = 'table-tennis'), true, 'human'),
  -- 283k, 2026-08-19; JAPANESE-language, technique-led
  ('youtube_channel', 'UC0ML1BOQVPYv6GLOz854S7w', 'WRM-TV JAPAN', (select id from public.categories where slug = 'table-tennis'), true, 'human'),
  -- 38.2k, 2026-08-19; KOREAN-language; some local-association content mixed in
  ('youtube_channel', 'UC9kSgD6xzwFYwmPT4wquTdQ', 'TTNuri Table Tennis', (select id from public.categories where slug = 'table-tennis'), true, 'human'),
  -- 41.9k, 2026-08-01; id resolved from handle
  ('youtube_channel', 'UCvOMtsU7xji-PybQ5tzpkWA', 'PechPong TT', (select id from public.categories where slug = 'table-tennis'), true, 'human'),
  -- 35.7k, 2026-08-16
  ('youtube_channel', 'UCKTSAIi67jEFKJ3NulUqRBg', 'ROAP Coaching', (select id from public.categories where slug = 'climbing'), true, 'human'),
  -- 12.8k, 2026-07-13; GERMAN/English mix
  ('youtube_channel', 'UC5r4Qt-Bt46zkdatK2kjxuQ', 'VERTICALNETWORK CLIMBING COACH', (select id from public.categories where slug = 'climbing'), true, 'human'),
  -- 82.2k, 2026-08-13
  ('youtube_channel', 'UCCebVtm8TyEpKAkB6Jfk0PA', 'John Cincola Pickleball', (select id from public.categories where slug = 'pickleball'), true, 'human'),
  -- 17.4k, 2026-08-09
  ('youtube_channel', 'UCRnFc8wwJNXgUspK65TI-Ew', 'Coach Jess | Athena Pickleball', (select id from public.categories where slug = 'pickleball'), true, 'human'),
  -- 98.9k, 2026-08-11; subscriber count resolved
  ('youtube_channel', 'UCpXAHjWyvgd9QCbIiwrrdPQ', 'Ed Ju Pickleball', (select id from public.categories where slug = 'pickleball'), true, 'human'),
  -- 4.44k, 2026-08-16; subscriber count resolved
  ('youtube_channel', 'UCcq6brQFbwUN9QGodtlo2zA', 'Still Got Game', (select id from public.categories where slug = 'pickleball'), true, 'human'),
  -- 14.4k, 2026-08-01; id + count resolved
  ('youtube_channel', 'UCM57II3Px0rLy1qZPhiJB5g', 'The Flying Pickle Academy', (select id from public.categories where slug = 'pickleball'), true, 'human'),
  -- 45.4k, 2026-08-18; format sampled - excellent
  ('youtube_channel', 'UCSLiGfnBttHPUyo6wSsL18w', 'Universal Rackets', (select id from public.categories where slug = 'pickleball'), true, 'human'),
  -- 11.2k, 2026-01-24 - SEASONAL pass
  ('youtube_channel', 'UCn9A4YXNjcc6qITa7jRRthQ', 'Darren Turner Skiing', (select id from public.categories where slug = 'skiing'), true, 'human'),
  -- 87.2k, 2026-02-19 - SEASONAL pass; id resolved
  ('youtube_channel', 'UCGn7idUXVyGb8XZ_ADQ5cdg', 'Deb Armstrong | Ski Strong', (select id from public.categories where slug = 'skiing'), true, 'human'),
  -- 21.3k, 2026-08-07; id resolved
  ('youtube_channel', 'UCrnIFBa70OyqkFhXk_EZfqw', 'Warren Smith Ski Academy', (select id from public.categories where slug = 'skiing'), true, 'human'),
  -- 9.11k, 2026-07-06
  ('youtube_channel', 'UChTn-FmyezDlmkd2s-xiGFQ', 'FreeFloFloss', (select id from public.categories where slug = 'skiing'), true, 'human'),
  -- 6.40k, 2026-07-11
  ('youtube_channel', 'UCBkLZUbreKudeBz8p-xVKLg', 'Cody Lander', (select id from public.categories where slug = 'snowboarding'), true, 'human'),
  -- 46.6k, 2026-08-11
  ('youtube_channel', 'UCHDPspEXGaVTwxHL11Tsygw', 'Brian Glick', (select id from public.categories where slug = 'bjj'), true, 'human'),
  -- 341k, 2026-06-26; id resolved
  ('youtube_channel', 'UCXpu025o8edxR9b4NMbH11A', 'Stephan Kesting | Grapplearts', (select id from public.categories where slug = 'bjj'), true, 'human'),
  -- 21.9k, 2026-07-24; id resolved
  ('youtube_channel', 'UCzQZ0KRPq2WyAzw-KaAMkRw', 'SilverFoxBJJ', (select id from public.categories where slug = 'bjj'), true, 'human'),
  -- 7.42k, 2026-06-18
  ('youtube_channel', 'UCkV37Bx_bqYgvsrkefXYXQg', 'Jason Rau | No-Gi Jiu-Jitsu', (select id from public.categories where slug = 'bjj'), true, 'human'),
  -- 6.83k, 2026-08-02
  ('youtube_channel', 'UCTjrCoHOLPoJpI8xfi1mrpQ', 'CorePRO BJJ', (select id from public.categories where slug = 'bjj'), true, 'human'),
  -- 5.04k, 2026-06-28
  ('youtube_channel', 'UCU82Man_XdMbVW-ivK8ofgg', 'ARMA BJJ', (select id from public.categories where slug = 'bjj'), true, 'human')
on conflict (source_type, identifier) do nothing;

commit;
