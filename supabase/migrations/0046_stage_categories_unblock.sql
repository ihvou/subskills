-- 0046: unblock the staged categories -- coach queue fix + trusted-source seed.
--
-- TWO BLOCKERS found while checking nightly readiness after 0043-0045.
--
-- 1. get_unscored_for_coach() filtered the category's is_active flag. The seven new
--    categories are staged inactive so they do not render while empty, but
--    run-collection.mjs's rotation does NOT filter it. The result was a deadlock:
--    the collector would fill those categories, the coach would never see the
--    candidates, nothing would ever be published, and the category could never be
--    switched on. The filter is dropped below.
--
-- 2. The seven new categories had ZERO trusted_sources, while every existing
--    category has 18-25. loadChannels() matches category EXPLICITLY (an
--    uncategorised channel is not global), so those categories would have run
--    open-search only -- no channel pass at all. Seeded below with 41 channels.
--
-- Channel ids are VERIFIED UC ids harvested from real `yt-dlp ytsearch` results
-- across five instructional queries per category, ranked by how often each channel
-- surfaced. Media, retail and event channels that ranked (Golf.com, Golf Digest,
-- TaylorMade, DICK'S, FloGrappling) were excluded as not primarily instructional;
-- REI was kept because its outdoor how-to content ranked repeatedly on merit.
-- Per the source-discovery rule, channels are identified by id, never by name.
--
-- REI ranked well for climbing, skiing AND snowboarding but is NOT seeded: the table
-- has UNIQUE (source_type, identifier), so a channel can belong to exactly one
-- category, and loadChannels() matches category explicitly. Seeding it would have
-- silently bound a generalist outdoor channel to whichever category was inserted
-- first and denied it to the other two. Open search still reaches REI content, and
-- the promotion path can adopt it later against whichever category it earns.
begin;

CREATE OR REPLACE FUNCTION public.get_unscored_for_coach(p_coach_role text, p_limit integer DEFAULT 30)
 RETURNS TABLE(relation_id uuid, source text, title text, description text, url text, duration_seconds numeric, like_count integer, comment_count integer, share_count integer, favorite_count integer, creator_handle text, skill_name text, category_name text, transcript text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_limit integer;
begin
  if p_coach_role not in ('relevance', 'value') then
    raise exception 'invalid coach_role: %', p_coach_role;
  end if;

  v_limit := least(greatest(coalesce(p_limit, 30), 1), 60);

  return query
    with skill_pub as (
      select r.skill_id, count(*) filter (where r.is_active and r.published) as pub
      from public.link_skill_relations r
      group by r.skill_id
    )
    select
      lsr.id as relation_id,
      case
        when lower(l.domain) like '%tiktok.com%' or lower(l.url) like '%tiktok.com%' then 'tiktok'
        when lower(l.domain) like '%youtube.com%'
          or lower(l.domain) like '%youtu.be%'
          or lower(l.url) like '%youtube.com%'
          or lower(l.url) like '%youtu.be%' then 'youtube'
        else 'other'
      end as source,
      l.title,
      left(l.description, 300) as description,
      l.canonical_url as url,
      l.duration_seconds,
      l.like_count,
      l.comment_count,
      l.share_count,
      l.favorite_count,
      l.creator_handle,
      s.name as skill_name,
      c.name as category_name,
      left(lt.transcript_text, 5000) as transcript
    from public.link_skill_relations lsr
    join public.links l on l.id = lsr.link_id
    join public.skills s on s.id = lsr.skill_id
    join public.categories c on c.id = s.category_id
    join skill_pub sp on sp.skill_id = lsr.skill_id
    left join public.link_transcripts lt on lt.link_id = l.id
    where lsr.is_active = true
      and l.is_active = true
      and s.is_active = true
      -- 0046: the category is_active filter is DELIBERATELY GONE. A staged
      -- category sits inactive while it fills, and run-collection.mjs's rotation
      -- already ignores it -- so filtering here deadlocked staging: the collector
      -- fed categories the coach could never review, so nothing was ever
      -- published, so the category could never be switched on. s.is_active still
      -- applies, which is the correct lever for retiring content.
      and not exists (
        select 1
          from public.curator_votes cv
         where cv.link_skill_relation_id = lsr.id
           and cv.coach_role = p_coach_role
      )
    -- Scarcest skill first; oldest first within a skill so it stays deterministic.
    order by coalesce(sp.pub, 0) asc,
             lsr.created_at asc,
             lsr.id asc
    limit v_limit;
end;
$function$;

insert into public.trusted_sources (source_type, identifier, display_name, category_id, is_active, origin_type) values
  ('youtube_channel', 'UCUct4nBOq47nXbHtq7p8eUA', 'The Art of Simple Golf', (select id from public.categories where slug = 'golf'), true, 'human'),
  ('youtube_channel', 'UCFHZHhZaH7Rc_FOMIzUziJA', 'Rick Shiels Golf', (select id from public.categories where slug = 'golf'), true, 'human'),
  ('youtube_channel', 'UCSwdmDQhAi_-ICkAvNBLEBw', 'Danny Maude', (select id from public.categories where slug = 'golf'), true, 'human'),
  ('youtube_channel', 'UC79FyJ_choPudvaY5Tx_TvA', 'Scratch Golf Academy', (select id from public.categories where slug = 'golf'), true, 'human'),
  ('youtube_channel', 'UCLdwDMdtrcW_WlhXI0Kli9Q', 'GlobalTTStudio', (select id from public.categories where slug = 'table-tennis'), true, 'human'),
  ('youtube_channel', 'UC9HfQ0MtTxlmPBE0MVEV-yg', 'Table tennis teaching channel', (select id from public.categories where slug = 'table-tennis'), true, 'human'),
  ('youtube_channel', 'UCqHc12tVGhzBtlMUq7MR7wA', 'Tom Lodziak', (select id from public.categories where slug = 'table-tennis'), true, 'human'),
  ('youtube_channel', 'UCSFVQcf1sWEIEgr3rYOz3MQ', 'Learn Table Tennis', (select id from public.categories where slug = 'table-tennis'), true, 'human'),
  ('youtube_channel', 'UC_TNBWPjmGGNV3CA_vwK97Q', 'PingSkills', (select id from public.categories where slug = 'table-tennis'), true, 'human'),
  ('youtube_channel', 'UCtPbV9Cnq4YILSTycVDgz_Q', 'ElevateYourPing', (select id from public.categories where slug = 'table-tennis'), true, 'human'),
  ('youtube_channel', 'UCMQzIsi7kwz1_xZjqNhz9kw', 'Lattice Training', (select id from public.categories where slug = 'climbing'), true, 'human'),
  ('youtube_channel', 'UCsqZk5V2d44TNLRFSI5aVfg', 'Hooper''s Beta', (select id from public.categories where slug = 'climbing'), true, 'human'),
  ('youtube_channel', 'UCdjL64S-IS84HjDhSc6XZ2A', 'Geek Climber', (select id from public.categories where slug = 'climbing'), true, 'human'),
  ('youtube_channel', 'UC6-rliFvsdCUTZndrZTQjMA', 'Movement for Climbers', (select id from public.categories where slug = 'climbing'), true, 'human'),
  ('youtube_channel', 'UC5CSgrlchwozIeFlacSztHw', 'Catalyst Climbing', (select id from public.categories where slug = 'climbing'), true, 'human'),
  ('youtube_channel', 'UCAAyG437_Q-zfkoOThoAsqw', 'Send Edition', (select id from public.categories where slug = 'climbing'), true, 'human'),
  ('youtube_channel', 'UCb6veypzEzufZ38NaY3fd_w', 'Enhance Pickleball', (select id from public.categories where slug = 'pickleball'), true, 'human'),
  ('youtube_channel', 'UCuHP7q94VYp-9W19pk8cjjw', 'ThatPickleballGuy - Kyle Koszuta', (select id from public.categories where slug = 'pickleball'), true, 'human'),
  ('youtube_channel', 'UCn2nenHT9hdxC_WmStTXYMQ', 'PlayPickleball.com', (select id from public.categories where slug = 'pickleball'), true, 'human'),
  ('youtube_channel', 'UCdEjdg9MkhnITa1AGz78Kjw', 'Briones Pickleball Academy', (select id from public.categories where slug = 'pickleball'), true, 'human'),
  ('youtube_channel', 'UCZQP57kPK6LVOxbiAbdWebg', 'Troy Akin Pickleball', (select id from public.categories where slug = 'pickleball'), true, 'human'),
  ('youtube_channel', 'UCX9eQazPI3uB9OHG7cKZ_ow', 'Alpine Tutorials with George', (select id from public.categories where slug = 'skiing'), true, 'human'),
  ('youtube_channel', 'UC1Ho5YvHCtyReazatbhBowA', 'Stomp It Tutorials', (select id from public.categories where slug = 'skiing'), true, 'human'),
  ('youtube_channel', 'UCee2z4tQp6bgG5bff-KKUXA', 'Maison Sport', (select id from public.categories where slug = 'skiing'), true, 'human'),
  ('youtube_channel', 'UCVLc2nsrRA8ikf_bo74mqFQ', 'Inspirational Skiing', (select id from public.categories where slug = 'skiing'), true, 'human'),
  ('youtube_channel', 'UC2jvpwCE6Ybmizxid2qnRHg', 'SKNG Ski School', (select id from public.categories where slug = 'skiing'), true, 'human'),
  ('youtube_channel', 'UCuAvs_8xgJoN_lvfZ0sZpOQ', 'SkiCoachingOnline', (select id from public.categories where slug = 'skiing'), true, 'human'),
  ('youtube_channel', 'UClZ8L0sM5_tzrqJXwgL1MXQ', 'Tom Gellie - Big Picture Skiing', (select id from public.categories where slug = 'skiing'), true, 'human'),
  ('youtube_channel', 'UCtDdB-mu47GeMOroAQOb0Sg', 'SnowboardProCamp', (select id from public.categories where slug = 'snowboarding'), true, 'human'),
  ('youtube_channel', 'UCqyZMlq1g_IPez-weFh6-xA', 'Malcolm Moore', (select id from public.categories where slug = 'snowboarding'), true, 'human'),
  ('youtube_channel', 'UCX9chJwW7gL93LIcC3xP2uQ', 'Snowboard Addiction', (select id from public.categories where slug = 'snowboarding'), true, 'human'),
  ('youtube_channel', 'UCskAVnKylQSaU2hU6M_Vw9g', 'The Butter Dojo', (select id from public.categories where slug = 'snowboarding'), true, 'human'),
  ('youtube_channel', 'UC_i8SQjQOrPUpD3tpjMEuAw', 'Johnathan Buckhouse', (select id from public.categories where slug = 'snowboarding'), true, 'human'),
  ('youtube_channel', 'UClPPFsjX8haeh8I0jH37QhA', 'Carving Like A Pro', (select id from public.categories where slug = 'snowboarding'), true, 'human'),
  ('youtube_channel', 'UCtXtqlLdZYZm3060qVExXkA', 'Bernardo Faria BJJ Fanatics', (select id from public.categories where slug = 'bjj'), true, 'human'),
  ('youtube_channel', 'UCDaSNu2fM3JL4VdlSwcFtOw', 'Knight Jiu-Jitsu', (select id from public.categories where slug = 'bjj'), true, 'human'),
  ('youtube_channel', 'UCBNsOFfO-TZDIpygfz5paaQ', 'JonThomasBJJ', (select id from public.categories where slug = 'bjj'), true, 'human'),
  ('youtube_channel', 'UC-ZO8c74hCXEjUCUatj-L2g', 'The BJJ Project', (select id from public.categories where slug = 'bjj'), true, 'human'),
  ('youtube_channel', 'UCexKjyhZ5EvBTWyg6U6e5Og', 'Jordan Teaches Jiujitsu', (select id from public.categories where slug = 'bjj'), true, 'human'),
  ('youtube_channel', 'UC_qwyBcWFKqCotbrDqkjXPQ', 'Matt Arroyo Jiu Jitsu', (select id from public.categories where slug = 'bjj'), true, 'human'),
  ('youtube_channel', 'UC39B1m3jwr-ryMPgSjBqwqg', 'Gordon Ryan', (select id from public.categories where slug = 'bjj'), true, 'human')
on conflict do nothing;

commit;
