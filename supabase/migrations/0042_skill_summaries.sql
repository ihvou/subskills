-- 0042: per-skill technique summaries synthesised from the videos on the page.
--
-- WHY. A sub-skill page is currently a list of links. The transcripts we already
-- store make it possible to say what the coaches on that page AGREE on — which no
-- single video gives you, and which is the thing that makes this a learning
-- resource rather than a link directory. It is also the strongest SEO surface we
-- have: unique prose per page, generated from primary sources.
--
-- SHAPE (settled by testing on 9 real skills before building anything):
--   * "consensus": 2-4 points, DECLARATIVE only — no "don't/avoid/never". A first
--     test leaked negatives into this half and it read as a muddle.
--   * "mistakes": 2-3 genuine errors, not restated advice.
--   * NO PADDING. Fewer strong points beat a fixed count. An early draft invented
--     "place your own ball on the spot" purely to reach four bullets.
--   * Each point carries `support` — how many of the videos back it — so weakly
--     supported claims can be dropped or de-emphasised. For physical technique an
--     unattributed assertion is not good enough.
--
-- THRESHOLD. Below ~6 videos there is no consensus to find and the model invents
-- one: tested on Gym (women) "Dumbbell bench press" (3 videos, two of them
-- follow-along workouts) and the result was fabrication. Hence min_videos.
--
-- REGENERATION. Summaries go stale as pages grow. `source_count` records how many
-- videos a summary was built from; the queue returns a skill again once the page
-- has grown by more than 30%. Self-maintaining, and it terminates — once every
-- eligible skill is summarised the routine no-ops until a page actually changes.
begin;

create table if not exists public.skill_summaries (
  skill_id uuid primary key references public.skills(id) on delete cascade,
  -- [{ "point": "...", "support": 12 }, ...]
  consensus jsonb not null default '[]'::jsonb,
  mistakes jsonb not null default '[]'::jsonb,
  -- How many published videos existed when this was generated: the regeneration trigger.
  source_count integer not null default 0,
  -- How many of those the model judged actually on-topic and used. A large gap
  -- between source_count and used_count is a curation signal for that page.
  used_count integer not null default 0,
  generated_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.skill_summaries is
  'One synthesised technique summary per sub-skill, built from the transcripts of the videos published on that page. Regenerated when the page grows >30% (see get_skill_for_summary).';

drop trigger if exists skill_summaries_set_updated_at on public.skill_summaries;
create trigger skill_summaries_set_updated_at
  before update on public.skill_summaries
  for each row execute function public.set_updated_at();

alter table public.skill_summaries enable row level security;

-- Public read: this is page content and must be reachable by the anon key and by
-- crawlers. Writes stay service-role only (the routine goes through an edge function).
drop policy if exists "skill_summaries_public_read" on public.skill_summaries;
create policy "skill_summaries_public_read"
  on public.skill_summaries for select
  to anon, authenticated
  using (true);

grant select on public.skill_summaries to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Queue: ONE skill at a time, with ALL of its published transcripts.
--
-- One skill per call is deliberate. Consensus is the product, so the model must
-- see every video on the page, not a sample — a 30-video skill is ~200k characters
-- and two of those would not fit comfortably alongside the reasoning. Cloud
-- Routines have no inline-read limit, so a large single-skill response is fine.
-- ---------------------------------------------------------------------------
create or replace function public.get_skill_for_summary(
  p_min_videos integer default 6,
  p_growth_factor real default 1.3,
  p_max_videos integer default 40,
  p_transcript_chars integer default 6000
) returns table (
  skill_id uuid,
  skill_name text,
  skill_description text,
  category_name text,
  published_count integer,
  previous_source_count integer,
  reason text,
  videos jsonb
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_skill record;
begin
  -- Pick the neediest skill: never-summarised first, then the most-grown.
  select s.id, s.name, s.description, c.name as category_name,
         cnt.published_count, ss.source_count,
         case when ss.skill_id is null then 'initial' else 'regenerate_growth' end as reason
    into v_skill
    from public.skills s
    join public.categories c on c.id = s.category_id
    join lateral (
      select count(*)::integer as published_count
        from public.link_skill_relations lsr
        join public.links l on l.id = lsr.link_id
        join public.link_transcripts lt on lt.link_id = l.id
       where lsr.skill_id = s.id and lsr.is_active and lsr.published and l.is_active
    ) cnt on true
    left join public.skill_summaries ss on ss.skill_id = s.id
   where s.is_active and c.is_active
     and cnt.published_count >= p_min_videos
     and (
       ss.skill_id is null
       or cnt.published_count > greatest(ss.source_count, 1) * p_growth_factor
     )
   order by (ss.skill_id is not null),                         -- never-summarised first
            case when ss.skill_id is null then 0
                 else cnt.published_count::real / greatest(ss.source_count, 1) end desc,
            cnt.published_count desc
   limit 1;

  if v_skill.id is null then
    return;
  end if;

  return query
    select
      v_skill.id,
      v_skill.name,
      coalesce(v_skill.description, ''),
      v_skill.category_name,
      v_skill.published_count,
      coalesce(v_skill.source_count, 0),
      v_skill.reason,
      coalesce(
        (select jsonb_agg(jsonb_build_object(
                  'title', l.title,
                  'transcript', left(regexp_replace(lt.transcript_text, '\s+', ' ', 'g'), p_transcript_chars))
                order by lsr.combined_score desc nulls last)
           from (
             select lsr2.link_id, lsr2.combined_score
               from public.link_skill_relations lsr2
               join public.links l2 on l2.id = lsr2.link_id
               join public.link_transcripts lt2 on lt2.link_id = l2.id
              where lsr2.skill_id = v_skill.id and lsr2.is_active and lsr2.published and l2.is_active
              order by lsr2.combined_score desc nulls last
              limit p_max_videos
           ) lsr
           join public.links l on l.id = lsr.link_id
           join public.link_transcripts lt on lt.link_id = l.id),
        '[]'::jsonb);
end;
$fn$;

comment on function public.get_skill_for_summary(integer, real, integer, integer) is
  'Returns ONE skill needing a summary — never-summarised first, then most-grown — with ALL its published transcripts (capped). Consensus needs the whole page, not a sample. Empty result means nothing needs generating.';

-- ---------------------------------------------------------------------------
-- Store. Validates shape here rather than trusting the caller, because the caller
-- is a language model and a malformed summary would render as page content.
-- ---------------------------------------------------------------------------
create or replace function public.store_skill_summary(
  p_skill_id uuid,
  p_consensus jsonb,
  p_mistakes jsonb,
  p_source_count integer,
  p_used_count integer
) returns void
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if jsonb_typeof(p_consensus) <> 'array' or jsonb_typeof(p_mistakes) <> 'array' then
    raise exception 'consensus and mistakes must be JSON arrays';
  end if;
  if jsonb_array_length(p_consensus) < 1 or jsonb_array_length(p_consensus) > 4 then
    raise exception 'consensus must hold 1-4 points (got %)', jsonb_array_length(p_consensus);
  end if;
  if jsonb_array_length(p_mistakes) > 3 then
    raise exception 'mistakes must hold at most 3 points (got %)', jsonb_array_length(p_mistakes);
  end if;

  insert into public.skill_summaries (skill_id, consensus, mistakes, source_count, used_count, generated_at)
  values (p_skill_id, p_consensus, p_mistakes, greatest(coalesce(p_source_count, 0), 0), greatest(coalesce(p_used_count, 0), 0), now())
  on conflict (skill_id) do update
    set consensus = excluded.consensus,
        mistakes = excluded.mistakes,
        source_count = excluded.source_count,
        used_count = excluded.used_count,
        generated_at = now();
end;
$fn$;

comment on function public.store_skill_summary(uuid, jsonb, jsonb, integer, integer) is
  'Upserts a skill summary. Enforces 1-4 consensus points and at most 3 mistakes so a malformed generation cannot become page content. source_count drives regeneration.';

revoke all on function public.get_skill_for_summary(integer, real, integer, integer) from public, anon, authenticated;
revoke all on function public.store_skill_summary(uuid, jsonb, jsonb, integer, integer) from public, anon, authenticated;
grant execute on function public.get_skill_for_summary(integer, real, integer, integer) to service_role;
grant execute on function public.store_skill_summary(uuid, jsonb, jsonb, integer, integer) to service_role;

commit;
