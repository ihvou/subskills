-- 0047: trusted-source expansion for the seven staged categories (+32).
--
-- 0046 seeded a starter set of 41 from a shallow probe. This is the deep pass: for
-- each staged category, ~30 of its actual sub-skill names were run through
-- `yt-dlp ytsearch` in BOTH shapes openSearchQueriesForSkill() builds
-- ("<Category> <Skill>" and "how to <Category> <Skill> technique"), and channels
-- were ranked by how often they surfaced across those technique queries. Frequency
-- on technique queries is the signal that matters: it is literally what the
-- collector will search.
--
-- Every candidate at >=3 hits was then VALIDATED against the same gates
-- discover-sources.mjs uses -- >=2,000 subscribers and active within 180 days --
-- by resolving the channel's latest upload. Subscriber count and last-upload date
-- are recorded per row below.
--
-- REJECTED on validation, not on taste:
--   rockentry (186k but idle since 2025-01), Neil Gresham Climbing Masterclass
--   (24.2k, idle since 2016), MLFM Table Tennis (127k, idle since 2024-10),
--   Rational Table Tennis Analysis (24.9k, idle since 2025-01) -- all dead channels
--   with good back catalogues; open search still reaches their videos, they just do
--   not deserve a channel-search slot. SnowValleyResort (1,230 subs, under the
--   floor). Brandon Mccaghren (metadata would not resolve).
-- REJECTED as not primarily instructional, consistent with 0046: Titleist,
--   TaylorMade, Golf Digest, Golf Monthly, Golf.com (brand/magazine), FloGrappling
--   (event coverage), Howcast (generic cross-topic aggregator).
--
-- SEASONALITY NOTE. Carv is 5 days past the 180-day idle gate (last upload
-- 2026-02-16). It is included deliberately: northern-hemisphere ski and snowboard
-- channels publish Dec-Mar and go quiet all summer, so a 180-day idle rule applied
-- in August rejects healthy seasonal channels. If discover-sources.mjs is ever run
-- against skiing/snowboarding out of season, raise DISCOVER_SOURCES_MAX_IDLE_DAYS
-- to ~300 or it will prune the best channels in those categories.
--
-- REI is assigned to Climbing. The table is UNIQUE (source_type, identifier) so a
-- channel belongs to exactly one category; REI cleared the >=3 bar for climbing
-- only in this pass, so the assignment is no longer arbitrary as it was in 0046.
begin;

insert into public.trusted_sources (source_type, identifier, display_name, category_id, is_active, origin_type) values
  -- 516k, active 2026-08-17
  ('youtube_channel', 'UCKo7Y45mcjDtLKiCx6ZTvAg', 'ChrisRyanGolf', (select id from public.categories where slug = 'golf'), true, 'human'),
  -- 334k, active 2026-08-18
  ('youtube_channel', 'UCgz5-3igA0IfsyWGKTr6YKA', 'US GOLF TV', (select id from public.categories where slug = 'golf'), true, 'human'),
  -- 418k, active 2026-08-09
  ('youtube_channel', 'UCaeGjmOiTxekbGUDPKhoU-A', 'Golf Sidekick', (select id from public.categories where slug = 'golf'), true, 'human'),
  -- 99.5k, active 2026-07-27
  ('youtube_channel', 'UCQBxM2Beu2hsrrD3o8myRJA', 'Georgia Ball Golf', (select id from public.categories where slug = 'golf'), true, 'human'),
  -- 153k, active 2026-08-10
  ('youtube_channel', 'UCo-lKZldxD7u_ZtBw9PnZXg', 'Kerrod Gray Golf', (select id from public.categories where slug = 'golf'), true, 'human'),
  -- 50.2k, active 2026-04-11
  ('youtube_channel', 'UCEvcgVaClb94hXVOgWALRSg', 'Coach Shayain', (select id from public.categories where slug = 'golf'), true, 'human'),
  -- 36.6k, active 2026-08-16
  ('youtube_channel', 'UCqed8jLmVOx0i-faIwN5mgg', 'Andreas Levenko - Table Tennis', (select id from public.categories where slug = 'table-tennis'), true, 'human'),
  -- 5.67k, active 2026-08-18
  ('youtube_channel', 'UClhV3JzjOnxHrF6K8USlJFA', 'Acceleraq', (select id from public.categories where slug = 'table-tennis'), true, 'human'),
  -- 264k, active 2026-08-19
  ('youtube_channel', 'UC_GiI83OPF1cwYlT9wUpMBw', 'PingSunday EmRatThich', (select id from public.categories where slug = 'table-tennis'), true, 'human'),
  -- 178k, active 2026-07-28
  ('youtube_channel', 'UCIyhoU4jcjFWkeelzga-2qA', 'TI LONG', (select id from public.categories where slug = 'table-tennis'), true, 'human'),
  -- 29.2k, active 2026-08-16
  ('youtube_channel', 'UCuCBztyW7D8y_qE0q0YUiZg', 'Paradigm Climbing', (select id from public.categories where slug = 'climbing'), true, 'human'),
  -- 356k, active 2026-08-07
  ('youtube_channel', 'UCqiKFGkSZwrbMSfkkd2CQGg', 'Emil Abrahamsson', (select id from public.categories where slug = 'climbing'), true, 'human'),
  -- 454k, active 2026-08-18
  ('youtube_channel', 'UCwZcNfPpV9CXSVbpH1ckVmw', 'REI', (select id from public.categories where slug = 'climbing'), true, 'human'),
  -- 70.7k, active 2026-07-13
  ('youtube_channel', 'UCeY1xqmnyd8kyAIL2G1qDLw', 'BMC TV', (select id from public.categories where slug = 'climbing'), true, 'human'),
  -- 6.5k, active 2026-02-24
  ('youtube_channel', 'UCY4T1yt5nFq9wPaxDRZ43SA', 'The Boardroom Climbing Ltd', (select id from public.categories where slug = 'climbing'), true, 'human'),
  -- 231k, active 2026-03-11
  ('youtube_channel', 'UCifeM1yaAx3cCXN5xZogmJQ', 'The Pickleball Clinic', (select id from public.categories where slug = 'pickleball'), true, 'human'),
  -- 81.8k, active 2026-08-19
  ('youtube_channel', 'UCwkHWkyarHJFSQxk8SMs4zA', 'PickleballPlaybook - Austin Hardy', (select id from public.categories where slug = 'pickleball'), true, 'human'),
  -- 55k, active 2026-07-29
  ('youtube_channel', 'UCge5MvXGyRQPpFnxgRb_pXA', 'Pickleball Studio', (select id from public.categories where slug = 'pickleball'), true, 'human'),
  -- 27.1k, active 2026-08-14
  ('youtube_channel', 'UCWJsBBe49RVlDoEuSPTLshg', 'Richard Pickleball', (select id from public.categories where slug = 'pickleball'), true, 'human'),
  -- 151k, active 2026-08-09
  ('youtube_channel', 'UCxVy2LJKyDTprHtvkwGJ3oA', 'tanner.pickleball', (select id from public.categories where slug = 'pickleball'), true, 'human'),
  -- 71.4k, active 2026-05-21
  ('youtube_channel', 'UCf9oZN1ax969agc1bD7D49Q', 'Ski Addiction', (select id from public.categories where slug = 'skiing'), true, 'human'),
  -- 204k, last 2026-02-16 -- SEASONAL, see note
  ('youtube_channel', 'UCTxGMLFlXjI0U185EbkhNzA', 'Carv - Digital Ski Coach', (select id from public.categories where slug = 'skiing'), true, 'human'),
  -- 36.3k, active 2026-07-23
  ('youtube_channel', 'UCOXtmxWi7DuMmcH9d3jbqZA', 'Taevis Kapalka', (select id from public.categories where slug = 'snowboarding'), true, 'human'),
  -- 198k, active 2026-04-03
  ('youtube_channel', 'UCB2S9RyKJDBMULFg357q7og', 'Tommie Bennett', (select id from public.categories where slug = 'snowboarding'), true, 'human'),
  -- 113k, active 2026-06-10
  ('youtube_channel', 'UCUst-cOQdnJqPx3FA9tN7sA', 'Board Archive', (select id from public.categories where slug = 'snowboarding'), true, 'human'),
  -- 20.6k, active 2026-08-03
  ('youtube_channel', 'UC8wQpTbX6V_JdYPU-htbi1A', 'The Justaride Snowboard Channel', (select id from public.categories where slug = 'snowboarding'), true, 'human'),
  -- 393k, active 2026-08-17
  ('youtube_channel', 'UCGCZBBvu7ZnqHYHuScODbAQ', 'Chewjitsu', (select id from public.categories where slug = 'bjj'), true, 'human'),
  -- 1.02M, active 2026-08-19
  ('youtube_channel', 'UCAqme-CE-yLm01BV5nUjPPA', 'BJJ Fanatics', (select id from public.categories where slug = 'bjj'), true, 'human'),
  -- 111k, active 2026-08-16
  ('youtube_channel', 'UC2uvUWTuQXq1k5DOZhzJ8VQ', 'Atos Jiu-Jitsu HQ', (select id from public.categories where slug = 'bjj'), true, 'human'),
  -- 24.3k, active 2026-07-16
  ('youtube_channel', 'UCdtUoqo4WGNJFixRlPvQzNQ', 'Teaching you BJJ, MMA & Self-Defense', (select id from public.categories where slug = 'bjj'), true, 'human'),
  -- 181k, active 2026-08-19
  ('youtube_channel', 'UCJNi-p8f0nnB3cf_ujYm3Fg', 'ART OF JIU JITSU', (select id from public.categories where slug = 'bjj'), true, 'human'),
  -- 72.5k, active 2026-06-21
  ('youtube_channel', 'UC8eFlweeoWP_RLSYrRhiYTA', 'JeanJacquesMachado', (select id from public.categories where slug = 'bjj'), true, 'human')
on conflict (source_type, identifier) do nothing;

commit;
