begin;

alter table public.skills
  add column if not exists subskill_difficulty real,
  add column if not exists learning_order integer;

comment on column public.skills.subskill_difficulty is
  'Pedagogical difficulty for this sub-skill. Lower means earlier/easier in the Learning Path.';
comment on column public.skills.learning_order is
  'Stable tiebreaker for Learning Path ordering within a category.';

create index if not exists skills_active_category_learning_order_idx
on public.skills (category_id, subskill_difficulty, learning_order, name)
where is_active;

create or replace function public.set_skill_learning_order(
  p_category_slug text,
  p_items jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_category_id uuid;
  v_updated_count integer := 0;
begin
  if nullif(trim(p_category_slug), '') is null then
    raise exception 'category slug is required';
  end if;

  if jsonb_typeof(p_items) is distinct from 'array' then
    raise exception 'p_items must be a JSON array';
  end if;

  select id
    into v_category_id
    from public.categories
   where slug = p_category_slug;

  if v_category_id is null then
    raise exception 'category not found: %', p_category_slug;
  end if;

  with input as (
    select
      nullif(trim(item.slug), '') as slug,
      item.subskill_difficulty,
      item.learning_order
    from jsonb_to_recordset(p_items) as item(
      slug text,
      subskill_difficulty real,
      learning_order integer
    )
    where nullif(trim(item.slug), '') is not null
      and item.subskill_difficulty is not null
      and item.learning_order is not null
  ),
  updated as (
    update public.skills s
       set subskill_difficulty = input.subskill_difficulty,
           learning_order = input.learning_order,
           updated_at = now()
      from input
     where s.category_id = v_category_id
       and s.slug = input.slug
     returning s.id
  )
  select count(*)::integer into v_updated_count
  from updated;

  return jsonb_build_object(
    'ok', true,
    'category_slug', p_category_slug,
    'updated_count', v_updated_count
  );
end;
$fn$;

comment on function public.set_skill_learning_order(text, jsonb) is
  'Service-role helper used by scripts/populate-subskill-learning-order.mjs to re-run pedagogical Learning Path ordering.';

revoke all on function public.set_skill_learning_order(text, jsonb) from public;
grant execute on function public.set_skill_learning_order(text, jsonb) to service_role;

with curated_orders(category_slug, skill_slugs) as (
  values
    ('badminton', array[
      'grip-technique',
      'serve-low',
      'serve-high',
      'footwork-split-step',
      'footwork-front-court',
      'footwork-rear-court',
      'lift',
      'net-shot',
      'push',
      'drive',
      'forehand-clear',
      'drop-shot',
      'defense-block',
      'defense-lift',
      'forehand-smash',
      'wrist-rotation',
      'singles-strategy',
      'doubles-rotation',
      'backhand-clear',
      'backhand-smash',
      'stringing-and-tension'
    ]::text[]),
    ('padel', array[
      'continental-grip',
      'serve-first-volley',
      'forehand-groundstroke',
      'backhand-groundstroke',
      'lob',
      'glass-defense',
      'volley-technique',
      'net-positioning',
      'bandeja',
      'chiquita',
      'vibora',
      'smash-x3'
    ]::text[]),
    ('gym-men', array[
      'mobility-warm-up',
      'core-bracing',
      'recovery-habits',
      'fat-loss-nutrition',
      'barbell-squat',
      'bench-press',
      'deadlift',
      'pull-up-progression',
      'overhead-press',
      'arm-training',
      'shoulder-health',
      'hypertrophy-programming'
    ]::text[]),
    ('gym-women', array[
      'gym-confidence',
      'mobility-stability',
      'goblet-squat',
      'glute-bridge-hip-thrust',
      'dumbbell-bench-press',
      'lat-pulldown',
      'romanian-deadlift',
      'nutrition-for-strength',
      'lower-body-hypertrophy',
      'upper-body-hypertrophy',
      'pelvic-floor-aware-lifting',
      'cycle-aware-training'
    ]::text[]),
    ('surfing', array[
      'surf-etiquette',
      'board-choice',
      'surf-stance',
      'paddling-technique',
      'turtle-roll',
      'pop-up',
      'lineup-positioning',
      'wave-selection',
      'takeoff-timing',
      'duck-dive',
      'bottom-turn',
      'cutback'
    ]::text[]),
    ('yoga', array[
      'pranayama-breathing',
      'tree-pose-balance',
      'downward-dog',
      'sun-salutation',
      'seated-forward-fold',
      'warrior-poses',
      'hip-openers',
      'bridge-wheel-backbend',
      'chaturanga',
      'crow-pose'
    ]::text[]),
    ('running', array[
      'dynamic-warmup',
      'running-form-posture',
      'arm-swing',
      'breathing-rhythm',
      'cadence-optimization',
      'foot-strike',
      'running-drills',
      'strides-form-sprints',
      'hill-running',
      'downhill-running'
    ]::text[]),
    ('pilates', array[
      'the-hundred',
      'pilates-bridge',
      'leg-circles',
      'single-leg-stretch',
      'spine-stretch-forward',
      'side-leg-series',
      'roll-up',
      'swan-prep',
      'plank-series',
      'teaser'
    ]::text[]),
    ('swimming', array[
      'streamline-pushoff',
      'freestyle-kick',
      'body-rotation',
      'freestyle-catch',
      'bilateral-breathing',
      'sculling-drills',
      'backstroke-technique',
      'breaststroke-timing',
      'flip-turn',
      'butterfly-timing'
    ]::text[]),
    ('cycling', array[
      'bike-fit-basics',
      'puncture-repair',
      'clipping-in-clipless',
      'braking-technique',
      'gear-shifting',
      'pedaling-efficiency',
      'cornering',
      'climbing-technique',
      'group-riding',
      'descending'
    ]::text[]),
    ('soccer', array[
      'ball-mastery',
      'juggling',
      'first-touch',
      'passing-technique',
      'weak-foot-development',
      'dribbling-close-control',
      'step-overs',
      'la-croqueta',
      '1v1-moves',
      'finishing-shooting',
      'free-kick-technique'
    ]::text[]),
    ('boxing', array[
      'stance-guard',
      'jab',
      'cross',
      'footwork',
      'defense-blocking',
      'hook',
      'uppercut',
      'head-movement-slipping',
      'shadow-boxing',
      'combinations',
      'heavy-bag-work'
    ]::text[]),
    ('tennis', array[
      'footwork-split-step',
      'forehand',
      'two-handed-backhand',
      'volley',
      'serve-technique',
      'return-of-serve',
      'slice-backhand',
      'topspin',
      'kick-serve',
      'overhead-smash',
      'one-handed-backhand'
    ]::text[])
),
ranked as (
  select
    s.id,
    array_position(co.skill_slugs, s.slug) as learning_order,
    cardinality(co.skill_slugs) as skill_count
  from public.skills s
  join public.categories c on c.id = s.category_id
  join curated_orders co on co.category_slug = c.slug
  where array_position(co.skill_slugs, s.slug) is not null
),
scored as (
  select
    id,
    learning_order,
    round(
      (
        1.0 + ((learning_order - 1)::numeric * 4.0 / greatest(skill_count - 1, 1))
      ),
      2
    )::real as subskill_difficulty
  from ranked
)
update public.skills s
   set subskill_difficulty = scored.subskill_difficulty,
       learning_order = scored.learning_order,
       updated_at = now()
  from scored
 where s.id = scored.id;

with fallback as (
  select
    s.id,
    900 + row_number() over (partition by s.category_id order by s.name, s.id) as fallback_order
  from public.skills s
  where s.is_active = true
    and (s.subskill_difficulty is null or s.learning_order is null)
)
update public.skills s
   set subskill_difficulty = coalesce(s.subskill_difficulty, 3.0),
       learning_order = coalesce(s.learning_order, fallback.fallback_order),
       updated_at = now()
  from fallback
 where s.id = fallback.id;

commit;
