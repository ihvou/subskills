-- 0034: taxonomy expansion — 97 sub-skills from the pre-launch audit.
--
-- Source: docs/taxonomy-audit-2026-08.md. Every entry is a MUST-HAVE with HIGH
-- verified tutorial supply, checked against governing-body syllabi (BWF L1, USTA
-- NTRP, ITF, RPP, the FA's ten core skills, AIBA/England Boxing, Red Cross/Swim
-- England, ISA L1, UESCA/RRCA/USATF, Yoga Alliance, classical Pilates,
-- UK National Standard for Cycle Training, NSCA/NASM/ACE).
--
-- What this fixes, per the audit:
--   * the 8 AI-seeded categories had ZERO tactical/decision content (Tennis could
--     not describe an NTRP 3.5+ player; Soccer had 5/5 attacking and 0/5 defending
--     of the FA core skills)
--   * NEITHER gym category had a horizontal pull, one of six canonical patterns,
--     and Gym (women) was missing or downgraded on five of seven
--   * Swimming gave breaststroke and butterfly only "Timing" — the element every
--     curriculum teaches LAST — with no kick, pull or undulation beneath it
--   * Running was 6/10 form micro-components with no training, injury or gear
--
-- NAMES ARE RETRIEVAL KEYS. scripts/run-collection.mjs builds YouTube queries from
-- skill.name, so each name is written the way a tutorial would title it, and the
-- ambiguous ones carry disambiguation ("Swimming (Pilates)"). Same reason the
-- audit flags "Rulo" -> "Kick smash" and "M-check" -> "Pre-ride check".
--
-- Safe to run before launch: the apps hide a sub-skill until it has 3 PUBLISHED
-- resources (getPublishMinResources in apps/web/lib/data.ts), so these stay
-- invisible until genuinely populated. The collector's rotation orders by
-- published count, so they are picked up first.
--
-- learning_order and subskill_difficulty are renumbered for the whole category so
-- new entries sit in pedagogical sequence rather than appended at the end.
begin;

-- ---- Padel: +8 (total 20) -------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where name = 'Padel'), 'return-of-serve', 'Return of serve', 'Take control of the point from the return and win the net.', true),
  ((select id from public.categories where name = 'Padel'), 'bajada', 'Bajada', 'Attack off the back glass and turn defence into offence.', true),
  ((select id from public.categories where name = 'Padel'), 'court-positioning', 'Court positioning', 'Hold attack and defence positions and move as a pair.', true),
  ((select id from public.categories where name = 'Padel'), 'transition-to-net', 'Transition to the net', 'Move forward together at the right moment, and when to retreat.', true),
  ((select id from public.categories where name = 'Padel'), 'defending-from-the-back', 'Defending from the back', 'Absorb the smash and rebuild the point from two-back.', true),
  ((select id from public.categories where name = 'Padel'), 'coming-off-the-wall', 'Coming off the wall', 'Time the bounce and footwork to play the ball off the back glass.', true),
  ((select id from public.categories where name = 'Padel'), 'kick-smash', 'Kick smash', 'Brush up the back of the ball for a heavy, high-bouncing smash.', true),
  ((select id from public.categories where name = 'Padel'), 'drop-shot', 'Drop shot', 'Finish softly at the net with the dejada.', true)
on conflict (category_id, slug) do nothing;

update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'continental-grip' and category_id = (select id from public.categories where name = 'Padel');
update public.skills set learning_order = 2, subskill_difficulty = 1.21 where slug = 'serve-first-volley' and category_id = (select id from public.categories where name = 'Padel');
update public.skills set learning_order = 3, subskill_difficulty = 1.42 where slug = 'return-of-serve' and category_id = (select id from public.categories where name = 'Padel');
update public.skills set learning_order = 4, subskill_difficulty = 1.63 where slug = 'forehand-groundstroke' and category_id = (select id from public.categories where name = 'Padel');
update public.skills set learning_order = 5, subskill_difficulty = 1.84 where slug = 'backhand-groundstroke' and category_id = (select id from public.categories where name = 'Padel');
update public.skills set learning_order = 6, subskill_difficulty = 2.05 where slug = 'lob' and category_id = (select id from public.categories where name = 'Padel');
update public.skills set learning_order = 7, subskill_difficulty = 2.26 where slug = 'glass-defense' and category_id = (select id from public.categories where name = 'Padel');
update public.skills set learning_order = 8, subskill_difficulty = 2.47 where slug = 'defending-from-the-back' and category_id = (select id from public.categories where name = 'Padel');
update public.skills set learning_order = 9, subskill_difficulty = 2.68 where slug = 'coming-off-the-wall' and category_id = (select id from public.categories where name = 'Padel');
update public.skills set learning_order = 10, subskill_difficulty = 2.89 where slug = 'volley-technique' and category_id = (select id from public.categories where name = 'Padel');
update public.skills set learning_order = 11, subskill_difficulty = 3.11 where slug = 'net-positioning' and category_id = (select id from public.categories where name = 'Padel');
update public.skills set learning_order = 12, subskill_difficulty = 3.32 where slug = 'court-positioning' and category_id = (select id from public.categories where name = 'Padel');
update public.skills set learning_order = 13, subskill_difficulty = 3.53 where slug = 'transition-to-net' and category_id = (select id from public.categories where name = 'Padel');
update public.skills set learning_order = 14, subskill_difficulty = 3.74 where slug = 'bandeja' and category_id = (select id from public.categories where name = 'Padel');
update public.skills set learning_order = 15, subskill_difficulty = 3.95 where slug = 'bajada' and category_id = (select id from public.categories where name = 'Padel');
update public.skills set learning_order = 16, subskill_difficulty = 4.16 where slug = 'chiquita' and category_id = (select id from public.categories where name = 'Padel');
update public.skills set learning_order = 17, subskill_difficulty = 4.37 where slug = 'drop-shot' and category_id = (select id from public.categories where name = 'Padel');
update public.skills set learning_order = 18, subskill_difficulty = 4.58 where slug = 'vibora' and category_id = (select id from public.categories where name = 'Padel');
update public.skills set learning_order = 19, subskill_difficulty = 4.79 where slug = 'smash-x3' and category_id = (select id from public.categories where name = 'Padel');
update public.skills set learning_order = 20, subskill_difficulty = 5.00 where slug = 'kick-smash' and category_id = (select id from public.categories where name = 'Padel');

-- ---- Tennis: +9 (total 20) ------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where name = 'Tennis'), 'grip-fundamentals', 'Grip fundamentals', 'Continental, eastern and semi-western grips and when to use each.', true),
  ((select id from public.categories where name = 'Tennis'), 'second-serve', 'Second serve', 'Build a reliable second serve with spin, depth and margin.', true),
  ((select id from public.categories where name = 'Tennis'), 'slice-serve', 'Slice serve', 'Curve the ball away with a slice serve to open the court.', true),
  ((select id from public.categories where name = 'Tennis'), 'approach-shot', 'Approach shot', 'Move forward behind the right ball and take the net.', true),
  ((select id from public.categories where name = 'Tennis'), 'drop-shot', 'Drop shot', 'Disguise and float the drop shot to pull opponents forward.', true),
  ((select id from public.categories where name = 'Tennis'), 'half-volley', 'Half volley', 'Handle the ball off the bounce in transition.', true),
  ((select id from public.categories where name = 'Tennis'), 'lob', 'Lob', 'Hit offensive and defensive lobs over the net player.', true),
  ((select id from public.categories where name = 'Tennis'), 'singles-strategy', 'Singles strategy', 'Build points, pick patterns and play the percentages.', true),
  ((select id from public.categories where name = 'Tennis'), 'doubles-strategy', 'Doubles strategy', 'Positioning, poaching and formations for doubles.', true)
on conflict (category_id, slug) do nothing;

update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'grip-fundamentals' and category_id = (select id from public.categories where name = 'Tennis');
update public.skills set learning_order = 2, subskill_difficulty = 1.21 where slug = 'footwork-split-step' and category_id = (select id from public.categories where name = 'Tennis');
update public.skills set learning_order = 3, subskill_difficulty = 1.42 where slug = 'forehand' and category_id = (select id from public.categories where name = 'Tennis');
update public.skills set learning_order = 4, subskill_difficulty = 1.63 where slug = 'two-handed-backhand' and category_id = (select id from public.categories where name = 'Tennis');
update public.skills set learning_order = 5, subskill_difficulty = 1.84 where slug = 'volley' and category_id = (select id from public.categories where name = 'Tennis');
update public.skills set learning_order = 6, subskill_difficulty = 2.05 where slug = 'approach-shot' and category_id = (select id from public.categories where name = 'Tennis');
update public.skills set learning_order = 7, subskill_difficulty = 2.26 where slug = 'half-volley' and category_id = (select id from public.categories where name = 'Tennis');
update public.skills set learning_order = 8, subskill_difficulty = 2.47 where slug = 'drop-shot' and category_id = (select id from public.categories where name = 'Tennis');
update public.skills set learning_order = 9, subskill_difficulty = 2.68 where slug = 'serve-technique' and category_id = (select id from public.categories where name = 'Tennis');
update public.skills set learning_order = 10, subskill_difficulty = 2.89 where slug = 'slice-serve' and category_id = (select id from public.categories where name = 'Tennis');
update public.skills set learning_order = 11, subskill_difficulty = 3.11 where slug = 'return-of-serve' and category_id = (select id from public.categories where name = 'Tennis');
update public.skills set learning_order = 12, subskill_difficulty = 3.32 where slug = 'slice-backhand' and category_id = (select id from public.categories where name = 'Tennis');
update public.skills set learning_order = 13, subskill_difficulty = 3.53 where slug = 'topspin' and category_id = (select id from public.categories where name = 'Tennis');
update public.skills set learning_order = 14, subskill_difficulty = 3.74 where slug = 'singles-strategy' and category_id = (select id from public.categories where name = 'Tennis');
update public.skills set learning_order = 15, subskill_difficulty = 3.95 where slug = 'doubles-strategy' and category_id = (select id from public.categories where name = 'Tennis');
update public.skills set learning_order = 16, subskill_difficulty = 4.16 where slug = 'kick-serve' and category_id = (select id from public.categories where name = 'Tennis');
update public.skills set learning_order = 17, subskill_difficulty = 4.37 where slug = 'second-serve' and category_id = (select id from public.categories where name = 'Tennis');
update public.skills set learning_order = 18, subskill_difficulty = 4.58 where slug = 'overhead-smash' and category_id = (select id from public.categories where name = 'Tennis');
update public.skills set learning_order = 19, subskill_difficulty = 4.79 where slug = 'lob' and category_id = (select id from public.categories where name = 'Tennis');
update public.skills set learning_order = 20, subskill_difficulty = 5.00 where slug = 'one-handed-backhand' and category_id = (select id from public.categories where name = 'Tennis');

-- ---- Badminton: +7 (total 28) ---------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where name = 'Badminton'), 'net-kill', 'Net kill', 'Finish loose net shots with a fast, controlled kill.', true),
  ((select id from public.categories where name = 'Badminton'), 'serve-flick', 'Serve (flick)', 'Flick the serve past the receiver to punish a tight stance.', true),
  ((select id from public.categories where name = 'Badminton'), 'return-of-serve', 'Return of serve', 'Win the serve-receive battle in singles and doubles.', true),
  ((select id from public.categories where name = 'Badminton'), 'around-the-head', 'Around the head shot', 'Play the round-the-head clear, drop and smash.', true),
  ((select id from public.categories where name = 'Badminton'), 'jump-smash', 'Jump smash', 'Time the take-off, scissor kick and landing for a jump smash.', true),
  ((select id from public.categories where name = 'Badminton'), 'deception', 'Deception', 'Disguise shots so every stroke starts the same way.', true),
  ((select id from public.categories where name = 'Badminton'), 'mixed-doubles-tactics', 'Mixed doubles tactics', 'Roles, rotation and positioning in mixed doubles.', true)
on conflict (category_id, slug) do nothing;

update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'grip-technique' and category_id = (select id from public.categories where name = 'Badminton');
update public.skills set learning_order = 2, subskill_difficulty = 1.15 where slug = 'serve-low' and category_id = (select id from public.categories where name = 'Badminton');
update public.skills set learning_order = 3, subskill_difficulty = 1.30 where slug = 'serve-high' and category_id = (select id from public.categories where name = 'Badminton');
update public.skills set learning_order = 4, subskill_difficulty = 1.44 where slug = 'serve-flick' and category_id = (select id from public.categories where name = 'Badminton');
update public.skills set learning_order = 5, subskill_difficulty = 1.59 where slug = 'return-of-serve' and category_id = (select id from public.categories where name = 'Badminton');
update public.skills set learning_order = 6, subskill_difficulty = 1.74 where slug = 'footwork-split-step' and category_id = (select id from public.categories where name = 'Badminton');
update public.skills set learning_order = 7, subskill_difficulty = 1.89 where slug = 'footwork-front-court' and category_id = (select id from public.categories where name = 'Badminton');
update public.skills set learning_order = 8, subskill_difficulty = 2.04 where slug = 'footwork-rear-court' and category_id = (select id from public.categories where name = 'Badminton');
update public.skills set learning_order = 9, subskill_difficulty = 2.19 where slug = 'lift' and category_id = (select id from public.categories where name = 'Badminton');
update public.skills set learning_order = 10, subskill_difficulty = 2.33 where slug = 'net-shot' and category_id = (select id from public.categories where name = 'Badminton');
update public.skills set learning_order = 11, subskill_difficulty = 2.48 where slug = 'net-kill' and category_id = (select id from public.categories where name = 'Badminton');
update public.skills set learning_order = 12, subskill_difficulty = 2.63 where slug = 'push' and category_id = (select id from public.categories where name = 'Badminton');
update public.skills set learning_order = 13, subskill_difficulty = 2.78 where slug = 'drive' and category_id = (select id from public.categories where name = 'Badminton');
update public.skills set learning_order = 14, subskill_difficulty = 2.93 where slug = 'forehand-clear' and category_id = (select id from public.categories where name = 'Badminton');
update public.skills set learning_order = 15, subskill_difficulty = 3.07 where slug = 'around-the-head' and category_id = (select id from public.categories where name = 'Badminton');
update public.skills set learning_order = 16, subskill_difficulty = 3.22 where slug = 'drop-shot' and category_id = (select id from public.categories where name = 'Badminton');
update public.skills set learning_order = 17, subskill_difficulty = 3.37 where slug = 'defense-block' and category_id = (select id from public.categories where name = 'Badminton');
update public.skills set learning_order = 18, subskill_difficulty = 3.52 where slug = 'defense-lift' and category_id = (select id from public.categories where name = 'Badminton');
update public.skills set learning_order = 19, subskill_difficulty = 3.67 where slug = 'forehand-smash' and category_id = (select id from public.categories where name = 'Badminton');
update public.skills set learning_order = 20, subskill_difficulty = 3.81 where slug = 'jump-smash' and category_id = (select id from public.categories where name = 'Badminton');
update public.skills set learning_order = 21, subskill_difficulty = 3.96 where slug = 'wrist-rotation' and category_id = (select id from public.categories where name = 'Badminton');
update public.skills set learning_order = 22, subskill_difficulty = 4.11 where slug = 'singles-strategy' and category_id = (select id from public.categories where name = 'Badminton');
update public.skills set learning_order = 23, subskill_difficulty = 4.26 where slug = 'deception' and category_id = (select id from public.categories where name = 'Badminton');
update public.skills set learning_order = 24, subskill_difficulty = 4.41 where slug = 'doubles-rotation' and category_id = (select id from public.categories where name = 'Badminton');
update public.skills set learning_order = 25, subskill_difficulty = 4.56 where slug = 'mixed-doubles-tactics' and category_id = (select id from public.categories where name = 'Badminton');
update public.skills set learning_order = 26, subskill_difficulty = 4.70 where slug = 'backhand-clear' and category_id = (select id from public.categories where name = 'Badminton');
update public.skills set learning_order = 27, subskill_difficulty = 4.85 where slug = 'backhand-smash' and category_id = (select id from public.categories where name = 'Badminton');
update public.skills set learning_order = 28, subskill_difficulty = 5.00 where slug = 'stringing-and-tension' and category_id = (select id from public.categories where name = 'Badminton');

-- ---- Soccer (Individual Skills): +6 (total 17) ----
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where name = 'Soccer (Individual Skills)'), 'turning-with-the-ball', 'Turning with the ball', 'Escape pressure with the Cruyff, drag-back and hook turns.', true),
  ((select id from public.categories where name = 'Soccer (Individual Skills)'), 'defending-1v1', 'Defending 1v1', 'Approach, jockey and force the attacker where you want.', true),
  ((select id from public.categories where name = 'Soccer (Individual Skills)'), 'heading', 'Heading', 'Attacking and defensive heading technique and timing.', true),
  ((select id from public.categories where name = 'Soccer (Individual Skills)'), 'crossing', 'Crossing', 'Whipped, driven and cut-back crosses from wide areas.', true),
  ((select id from public.categories where name = 'Soccer (Individual Skills)'), 'long-passing', 'Long passing and switching play', 'Strike accurate lofted and driven long passes.', true),
  ((select id from public.categories where name = 'Soccer (Individual Skills)'), 'penalty-technique', 'Penalty technique', 'Placement, run-up and composure from the spot.', true)
on conflict (category_id, slug) do nothing;

update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'ball-mastery' and category_id = (select id from public.categories where name = 'Soccer (Individual Skills)');
update public.skills set learning_order = 2, subskill_difficulty = 1.25 where slug = 'juggling' and category_id = (select id from public.categories where name = 'Soccer (Individual Skills)');
update public.skills set learning_order = 3, subskill_difficulty = 1.50 where slug = 'first-touch' and category_id = (select id from public.categories where name = 'Soccer (Individual Skills)');
update public.skills set learning_order = 4, subskill_difficulty = 1.75 where slug = 'heading' and category_id = (select id from public.categories where name = 'Soccer (Individual Skills)');
update public.skills set learning_order = 5, subskill_difficulty = 2.00 where slug = 'passing-technique' and category_id = (select id from public.categories where name = 'Soccer (Individual Skills)');
update public.skills set learning_order = 6, subskill_difficulty = 2.25 where slug = 'long-passing' and category_id = (select id from public.categories where name = 'Soccer (Individual Skills)');
update public.skills set learning_order = 7, subskill_difficulty = 2.50 where slug = 'crossing' and category_id = (select id from public.categories where name = 'Soccer (Individual Skills)');
update public.skills set learning_order = 8, subskill_difficulty = 2.75 where slug = 'weak-foot-development' and category_id = (select id from public.categories where name = 'Soccer (Individual Skills)');
update public.skills set learning_order = 9, subskill_difficulty = 3.00 where slug = 'dribbling-close-control' and category_id = (select id from public.categories where name = 'Soccer (Individual Skills)');
update public.skills set learning_order = 10, subskill_difficulty = 3.25 where slug = 'turning-with-the-ball' and category_id = (select id from public.categories where name = 'Soccer (Individual Skills)');
update public.skills set learning_order = 11, subskill_difficulty = 3.50 where slug = 'step-overs' and category_id = (select id from public.categories where name = 'Soccer (Individual Skills)');
update public.skills set learning_order = 12, subskill_difficulty = 3.75 where slug = 'la-croqueta' and category_id = (select id from public.categories where name = 'Soccer (Individual Skills)');
update public.skills set learning_order = 13, subskill_difficulty = 4.00 where slug = '1v1-moves' and category_id = (select id from public.categories where name = 'Soccer (Individual Skills)');
update public.skills set learning_order = 14, subskill_difficulty = 4.25 where slug = 'defending-1v1' and category_id = (select id from public.categories where name = 'Soccer (Individual Skills)');
update public.skills set learning_order = 15, subskill_difficulty = 4.50 where slug = 'finishing-shooting' and category_id = (select id from public.categories where name = 'Soccer (Individual Skills)');
update public.skills set learning_order = 16, subskill_difficulty = 4.75 where slug = 'free-kick-technique' and category_id = (select id from public.categories where name = 'Soccer (Individual Skills)');
update public.skills set learning_order = 17, subskill_difficulty = 5.00 where slug = 'penalty-technique' and category_id = (select id from public.categories where name = 'Soccer (Individual Skills)');

-- ---- Boxing: +6 (total 17) ------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where name = 'Boxing'), 'hand-wrapping', 'Hand wrapping', 'Wrap your hands to protect the wrist and knuckles.', true),
  ((select id from public.categories where name = 'Boxing'), 'body-punching', 'Body punching', 'Hooks, straights and uppercuts to the body.', true),
  ((select id from public.categories where name = 'Boxing'), 'counter-punching', 'Counter-punching', 'Read, slip and answer with the right counter.', true),
  ((select id from public.categories where name = 'Boxing'), 'distance-range', 'Distance and range management', 'Control the gap and choose the punch the range allows.', true),
  ((select id from public.categories where name = 'Boxing'), 'pad-work', 'Pad work', 'Hold and work the focus mitts with clean combinations.', true),
  ((select id from public.categories where name = 'Boxing'), 'sparring-fundamentals', 'Sparring fundamentals', 'Start sparring safely with the right intensity and etiquette.', true)
on conflict (category_id, slug) do nothing;

update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'hand-wrapping' and category_id = (select id from public.categories where name = 'Boxing');
update public.skills set learning_order = 2, subskill_difficulty = 1.25 where slug = 'stance-guard' and category_id = (select id from public.categories where name = 'Boxing');
update public.skills set learning_order = 3, subskill_difficulty = 1.50 where slug = 'jab' and category_id = (select id from public.categories where name = 'Boxing');
update public.skills set learning_order = 4, subskill_difficulty = 1.75 where slug = 'cross' and category_id = (select id from public.categories where name = 'Boxing');
update public.skills set learning_order = 5, subskill_difficulty = 2.00 where slug = 'footwork' and category_id = (select id from public.categories where name = 'Boxing');
update public.skills set learning_order = 6, subskill_difficulty = 2.25 where slug = 'distance-range' and category_id = (select id from public.categories where name = 'Boxing');
update public.skills set learning_order = 7, subskill_difficulty = 2.50 where slug = 'defense-blocking' and category_id = (select id from public.categories where name = 'Boxing');
update public.skills set learning_order = 8, subskill_difficulty = 2.75 where slug = 'hook' and category_id = (select id from public.categories where name = 'Boxing');
update public.skills set learning_order = 9, subskill_difficulty = 3.00 where slug = 'uppercut' and category_id = (select id from public.categories where name = 'Boxing');
update public.skills set learning_order = 10, subskill_difficulty = 3.25 where slug = 'body-punching' and category_id = (select id from public.categories where name = 'Boxing');
update public.skills set learning_order = 11, subskill_difficulty = 3.50 where slug = 'head-movement-slipping' and category_id = (select id from public.categories where name = 'Boxing');
update public.skills set learning_order = 12, subskill_difficulty = 3.75 where slug = 'counter-punching' and category_id = (select id from public.categories where name = 'Boxing');
update public.skills set learning_order = 13, subskill_difficulty = 4.00 where slug = 'shadow-boxing' and category_id = (select id from public.categories where name = 'Boxing');
update public.skills set learning_order = 14, subskill_difficulty = 4.25 where slug = 'combinations' and category_id = (select id from public.categories where name = 'Boxing');
update public.skills set learning_order = 15, subskill_difficulty = 4.50 where slug = 'heavy-bag-work' and category_id = (select id from public.categories where name = 'Boxing');
update public.skills set learning_order = 16, subskill_difficulty = 4.75 where slug = 'pad-work' and category_id = (select id from public.categories where name = 'Boxing');
update public.skills set learning_order = 17, subskill_difficulty = 5.00 where slug = 'sparring-fundamentals' and category_id = (select id from public.categories where name = 'Boxing');

-- ---- Swimming: +6 (total 16) ----------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where name = 'Swimming'), 'breath-control', 'Breath control', 'Exhale underwater and stay relaxed for beginners.', true),
  ((select id from public.categories where name = 'Swimming'), 'floating', 'Front and back float', 'Find balance and float on the front and back.', true),
  ((select id from public.categories where name = 'Swimming'), 'breaststroke-kick', 'Breaststroke kick', 'Master the whip kick, the most-failed element in breaststroke.', true),
  ((select id from public.categories where name = 'Swimming'), 'breaststroke-pull', 'Breaststroke pull', 'Out-sweep, in-sweep and recovery for the breaststroke pull.', true),
  ((select id from public.categories where name = 'Swimming'), 'butterfly-undulation', 'Butterfly undulation', 'Press the chest and build the body dolphin for butterfly.', true),
  ((select id from public.categories where name = 'Swimming'), 'racing-dive', 'Racing dive', 'Dive from the blocks with a tight, fast entry.', true)
on conflict (category_id, slug) do nothing;

update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'breath-control' and category_id = (select id from public.categories where name = 'Swimming');
update public.skills set learning_order = 2, subskill_difficulty = 1.27 where slug = 'floating' and category_id = (select id from public.categories where name = 'Swimming');
update public.skills set learning_order = 3, subskill_difficulty = 1.53 where slug = 'streamline-pushoff' and category_id = (select id from public.categories where name = 'Swimming');
update public.skills set learning_order = 4, subskill_difficulty = 1.80 where slug = 'freestyle-kick' and category_id = (select id from public.categories where name = 'Swimming');
update public.skills set learning_order = 5, subskill_difficulty = 2.07 where slug = 'body-rotation' and category_id = (select id from public.categories where name = 'Swimming');
update public.skills set learning_order = 6, subskill_difficulty = 2.33 where slug = 'freestyle-catch' and category_id = (select id from public.categories where name = 'Swimming');
update public.skills set learning_order = 7, subskill_difficulty = 2.60 where slug = 'bilateral-breathing' and category_id = (select id from public.categories where name = 'Swimming');
update public.skills set learning_order = 8, subskill_difficulty = 2.87 where slug = 'sculling-drills' and category_id = (select id from public.categories where name = 'Swimming');
update public.skills set learning_order = 9, subskill_difficulty = 3.13 where slug = 'backstroke-technique' and category_id = (select id from public.categories where name = 'Swimming');
update public.skills set learning_order = 10, subskill_difficulty = 3.40 where slug = 'breaststroke-timing' and category_id = (select id from public.categories where name = 'Swimming');
update public.skills set learning_order = 11, subskill_difficulty = 3.67 where slug = 'breaststroke-kick' and category_id = (select id from public.categories where name = 'Swimming');
update public.skills set learning_order = 12, subskill_difficulty = 3.93 where slug = 'breaststroke-pull' and category_id = (select id from public.categories where name = 'Swimming');
update public.skills set learning_order = 13, subskill_difficulty = 4.20 where slug = 'flip-turn' and category_id = (select id from public.categories where name = 'Swimming');
update public.skills set learning_order = 14, subskill_difficulty = 4.47 where slug = 'racing-dive' and category_id = (select id from public.categories where name = 'Swimming');
update public.skills set learning_order = 15, subskill_difficulty = 4.73 where slug = 'butterfly-timing' and category_id = (select id from public.categories where name = 'Swimming');
update public.skills set learning_order = 16, subskill_difficulty = 5.00 where slug = 'butterfly-undulation' and category_id = (select id from public.categories where name = 'Swimming');

-- ---- Surfing: +6 (total 18) -----------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where name = 'Surfing'), 'paddling-out', 'Paddling out', 'Pick your route, time the sets and use the channel.', true),
  ((select id from public.categories where name = 'Surfing'), 'rip-currents', 'Rip currents', 'Spot rips, escape them, and use them to paddle out.', true),
  ((select id from public.categories where name = 'Surfing'), 'surf-forecast', 'Reading the surf forecast', 'Read swell, period, wind and tide before you go.', true),
  ((select id from public.categories where name = 'Surfing'), 'trimming', 'Trimming down the line', 'Angle the take-off and ride across the face.', true),
  ((select id from public.categories where name = 'Surfing'), 'generating-speed', 'Generating speed', 'Pump the board to build and hold speed.', true),
  ((select id from public.categories where name = 'Surfing'), 'top-turn', 'Top turn', 'Redirect off the lip to complete the bottom-turn combo.', true)
on conflict (category_id, slug) do nothing;

update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'surf-etiquette' and category_id = (select id from public.categories where name = 'Surfing');
update public.skills set learning_order = 2, subskill_difficulty = 1.24 where slug = 'rip-currents' and category_id = (select id from public.categories where name = 'Surfing');
update public.skills set learning_order = 3, subskill_difficulty = 1.47 where slug = 'board-choice' and category_id = (select id from public.categories where name = 'Surfing');
update public.skills set learning_order = 4, subskill_difficulty = 1.71 where slug = 'surf-stance' and category_id = (select id from public.categories where name = 'Surfing');
update public.skills set learning_order = 5, subskill_difficulty = 1.94 where slug = 'paddling-technique' and category_id = (select id from public.categories where name = 'Surfing');
update public.skills set learning_order = 6, subskill_difficulty = 2.18 where slug = 'paddling-out' and category_id = (select id from public.categories where name = 'Surfing');
update public.skills set learning_order = 7, subskill_difficulty = 2.41 where slug = 'turtle-roll' and category_id = (select id from public.categories where name = 'Surfing');
update public.skills set learning_order = 8, subskill_difficulty = 2.65 where slug = 'pop-up' and category_id = (select id from public.categories where name = 'Surfing');
update public.skills set learning_order = 9, subskill_difficulty = 2.88 where slug = 'lineup-positioning' and category_id = (select id from public.categories where name = 'Surfing');
update public.skills set learning_order = 10, subskill_difficulty = 3.12 where slug = 'wave-selection' and category_id = (select id from public.categories where name = 'Surfing');
update public.skills set learning_order = 11, subskill_difficulty = 3.35 where slug = 'surf-forecast' and category_id = (select id from public.categories where name = 'Surfing');
update public.skills set learning_order = 12, subskill_difficulty = 3.59 where slug = 'takeoff-timing' and category_id = (select id from public.categories where name = 'Surfing');
update public.skills set learning_order = 13, subskill_difficulty = 3.82 where slug = 'trimming' and category_id = (select id from public.categories where name = 'Surfing');
update public.skills set learning_order = 14, subskill_difficulty = 4.06 where slug = 'generating-speed' and category_id = (select id from public.categories where name = 'Surfing');
update public.skills set learning_order = 15, subskill_difficulty = 4.29 where slug = 'duck-dive' and category_id = (select id from public.categories where name = 'Surfing');
update public.skills set learning_order = 16, subskill_difficulty = 4.53 where slug = 'bottom-turn' and category_id = (select id from public.categories where name = 'Surfing');
update public.skills set learning_order = 17, subskill_difficulty = 4.76 where slug = 'top-turn' and category_id = (select id from public.categories where name = 'Surfing');
update public.skills set learning_order = 18, subskill_difficulty = 5.00 where slug = 'cutback' and category_id = (select id from public.categories where name = 'Surfing');

-- ---- Running: +10 (total 20) -----------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where name = 'Running'), 'starting-to-run', 'Starting to run', 'Run-walk your way from the couch to a continuous 5K.', true),
  ((select id from public.categories where name = 'Running'), 'choosing-running-shoes', 'Choosing running shoes', 'Pick shoes that fit your foot, gait and mileage.', true),
  ((select id from public.categories where name = 'Running'), 'easy-runs', 'Easy runs', 'Run genuinely easy to build an aerobic base.', true),
  ((select id from public.categories where name = 'Running'), 'long-run', 'The long run', 'Build endurance with a weekly long run.', true),
  ((select id from public.categories where name = 'Running'), 'interval-tempo', 'Interval and tempo runs', 'Structure threshold, tempo and interval sessions.', true),
  ((select id from public.categories where name = 'Running'), 'race-pacing', 'Race pacing', 'Pace a 5K to a marathon without blowing up.', true),
  ((select id from public.categories where name = 'Running'), 'strength-for-runners', 'Strength training for runners', 'Build the strength that keeps you injury-free.', true),
  ((select id from public.categories where name = 'Running'), 'shin-splints', 'Shin splints', 'Prevent and rehab the classic beginner shin pain.', true),
  ((select id from public.categories where name = 'Running'), 'runners-knee', 'Runner''s knee and IT band pain', 'Fix the two most common overuse injuries in running.', true),
  ((select id from public.categories where name = 'Running'), 'post-run-stretching', 'Post-run stretching', 'Cool down and stretch after a run.', true)
on conflict (category_id, slug) do nothing;

update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'starting-to-run' and category_id = (select id from public.categories where name = 'Running');
update public.skills set learning_order = 2, subskill_difficulty = 1.21 where slug = 'choosing-running-shoes' and category_id = (select id from public.categories where name = 'Running');
update public.skills set learning_order = 3, subskill_difficulty = 1.42 where slug = 'dynamic-warmup' and category_id = (select id from public.categories where name = 'Running');
update public.skills set learning_order = 4, subskill_difficulty = 1.63 where slug = 'post-run-stretching' and category_id = (select id from public.categories where name = 'Running');
update public.skills set learning_order = 5, subskill_difficulty = 1.84 where slug = 'running-form-posture' and category_id = (select id from public.categories where name = 'Running');
update public.skills set learning_order = 6, subskill_difficulty = 2.05 where slug = 'easy-runs' and category_id = (select id from public.categories where name = 'Running');
update public.skills set learning_order = 7, subskill_difficulty = 2.26 where slug = 'long-run' and category_id = (select id from public.categories where name = 'Running');
update public.skills set learning_order = 8, subskill_difficulty = 2.47 where slug = 'interval-tempo' and category_id = (select id from public.categories where name = 'Running');
update public.skills set learning_order = 9, subskill_difficulty = 2.68 where slug = 'race-pacing' and category_id = (select id from public.categories where name = 'Running');
update public.skills set learning_order = 10, subskill_difficulty = 2.89 where slug = 'strength-for-runners' and category_id = (select id from public.categories where name = 'Running');
update public.skills set learning_order = 11, subskill_difficulty = 3.11 where slug = 'shin-splints' and category_id = (select id from public.categories where name = 'Running');
update public.skills set learning_order = 12, subskill_difficulty = 3.32 where slug = 'runners-knee' and category_id = (select id from public.categories where name = 'Running');
update public.skills set learning_order = 13, subskill_difficulty = 3.53 where slug = 'arm-swing' and category_id = (select id from public.categories where name = 'Running');
update public.skills set learning_order = 14, subskill_difficulty = 3.74 where slug = 'breathing-rhythm' and category_id = (select id from public.categories where name = 'Running');
update public.skills set learning_order = 15, subskill_difficulty = 3.95 where slug = 'cadence-optimization' and category_id = (select id from public.categories where name = 'Running');
update public.skills set learning_order = 16, subskill_difficulty = 4.16 where slug = 'foot-strike' and category_id = (select id from public.categories where name = 'Running');
update public.skills set learning_order = 17, subskill_difficulty = 4.37 where slug = 'running-drills' and category_id = (select id from public.categories where name = 'Running');
update public.skills set learning_order = 18, subskill_difficulty = 4.58 where slug = 'strides-form-sprints' and category_id = (select id from public.categories where name = 'Running');
update public.skills set learning_order = 19, subskill_difficulty = 4.79 where slug = 'hill-running' and category_id = (select id from public.categories where name = 'Running');
update public.skills set learning_order = 20, subskill_difficulty = 5.00 where slug = 'downhill-running' and category_id = (select id from public.categories where name = 'Running');

-- ---- Cycling: +8 (total 18) -----------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where name = 'Cycling'), 'riding-in-traffic', 'Riding in traffic', 'Road positioning, junctions and being seen in traffic.', true),
  ((select id from public.categories where name = 'Cycling'), 'choosing-first-bike', 'Choosing your first bike', 'Road, gravel or hybrid, and how it should fit.', true),
  ((select id from public.categories where name = 'Cycling'), 'chain-cleaning', 'Chain cleaning and lubrication', 'Keep the drivetrain clean, quiet and fast.', true),
  ((select id from public.categories where name = 'Cycling'), 'gear-adjustment', 'Adjusting your gears', 'Index the derailleur and fix skipping gears.', true),
  ((select id from public.categories where name = 'Cycling'), 'brake-adjustment', 'Brake adjustment and pads', 'Set up rim and disc brakes and replace pads.', true),
  ((select id from public.categories where name = 'Cycling'), 'fuelling-hydration', 'Fuelling and hydration on the bike', 'Eat and drink to avoid bonking on long rides.', true),
  ((select id from public.categories where name = 'Cycling'), 'training-zones', 'Training zones and FTP', 'Test FTP and train by zones.', true),
  ((select id from public.categories where name = 'Cycling'), 'indoor-training', 'Indoor training and turbo setup', 'Set up the turbo and train indoors effectively.', true)
on conflict (category_id, slug) do nothing;

update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'riding-in-traffic' and category_id = (select id from public.categories where name = 'Cycling');
update public.skills set learning_order = 2, subskill_difficulty = 1.24 where slug = 'bike-fit-basics' and category_id = (select id from public.categories where name = 'Cycling');
update public.skills set learning_order = 3, subskill_difficulty = 1.47 where slug = 'choosing-first-bike' and category_id = (select id from public.categories where name = 'Cycling');
update public.skills set learning_order = 4, subskill_difficulty = 1.71 where slug = 'puncture-repair' and category_id = (select id from public.categories where name = 'Cycling');
update public.skills set learning_order = 5, subskill_difficulty = 1.94 where slug = 'chain-cleaning' and category_id = (select id from public.categories where name = 'Cycling');
update public.skills set learning_order = 6, subskill_difficulty = 2.18 where slug = 'gear-adjustment' and category_id = (select id from public.categories where name = 'Cycling');
update public.skills set learning_order = 7, subskill_difficulty = 2.41 where slug = 'brake-adjustment' and category_id = (select id from public.categories where name = 'Cycling');
update public.skills set learning_order = 8, subskill_difficulty = 2.65 where slug = 'clipping-in-clipless' and category_id = (select id from public.categories where name = 'Cycling');
update public.skills set learning_order = 9, subskill_difficulty = 2.88 where slug = 'braking-technique' and category_id = (select id from public.categories where name = 'Cycling');
update public.skills set learning_order = 10, subskill_difficulty = 3.12 where slug = 'gear-shifting' and category_id = (select id from public.categories where name = 'Cycling');
update public.skills set learning_order = 11, subskill_difficulty = 3.35 where slug = 'pedaling-efficiency' and category_id = (select id from public.categories where name = 'Cycling');
update public.skills set learning_order = 12, subskill_difficulty = 3.59 where slug = 'cornering' and category_id = (select id from public.categories where name = 'Cycling');
update public.skills set learning_order = 13, subskill_difficulty = 3.82 where slug = 'climbing-technique' and category_id = (select id from public.categories where name = 'Cycling');
update public.skills set learning_order = 14, subskill_difficulty = 4.06 where slug = 'fuelling-hydration' and category_id = (select id from public.categories where name = 'Cycling');
update public.skills set learning_order = 15, subskill_difficulty = 4.29 where slug = 'training-zones' and category_id = (select id from public.categories where name = 'Cycling');
update public.skills set learning_order = 16, subskill_difficulty = 4.53 where slug = 'indoor-training' and category_id = (select id from public.categories where name = 'Cycling');
update public.skills set learning_order = 17, subskill_difficulty = 4.76 where slug = 'group-riding' and category_id = (select id from public.categories where name = 'Cycling');
update public.skills set learning_order = 18, subskill_difficulty = 5.00 where slug = 'descending' and category_id = (select id from public.categories where name = 'Cycling');

-- ---- Yoga: +7 (total 17) --------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where name = 'Yoga'), 'yoga-for-beginners', 'Yoga for beginners', 'Your first yoga class, step by step.', true),
  ((select id from public.categories where name = 'Yoga'), 'headstand', 'Headstand (Sirsasana)', 'Build a safe, controlled headstand.', true),
  ((select id from public.categories where name = 'Yoga'), 'forearm-stand', 'Forearm stand (Pincha Mayurasana)', 'Work toward a balanced forearm stand.', true),
  ((select id from public.categories where name = 'Yoga'), 'handstand', 'Handstand', 'Drills and progressions toward a handstand.', true),
  ((select id from public.categories where name = 'Yoga'), 'yin-yoga', 'Yin yoga', 'Long-held floor poses for deep connective-tissue release.', true),
  ((select id from public.categories where name = 'Yoga'), 'restorative-yoga', 'Restorative yoga', 'Fully supported poses for rest and recovery.', true),
  ((select id from public.categories where name = 'Yoga'), 'yoga-for-back-pain', 'Yoga for back pain', 'Safe sequences to ease and prevent back pain.', true)
on conflict (category_id, slug) do nothing;

update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'yoga-for-beginners' and category_id = (select id from public.categories where name = 'Yoga');
update public.skills set learning_order = 2, subskill_difficulty = 1.25 where slug = 'pranayama-breathing' and category_id = (select id from public.categories where name = 'Yoga');
update public.skills set learning_order = 3, subskill_difficulty = 1.50 where slug = 'tree-pose-balance' and category_id = (select id from public.categories where name = 'Yoga');
update public.skills set learning_order = 4, subskill_difficulty = 1.75 where slug = 'downward-dog' and category_id = (select id from public.categories where name = 'Yoga');
update public.skills set learning_order = 5, subskill_difficulty = 2.00 where slug = 'sun-salutation' and category_id = (select id from public.categories where name = 'Yoga');
update public.skills set learning_order = 6, subskill_difficulty = 2.25 where slug = 'seated-forward-fold' and category_id = (select id from public.categories where name = 'Yoga');
update public.skills set learning_order = 7, subskill_difficulty = 2.50 where slug = 'warrior-poses' and category_id = (select id from public.categories where name = 'Yoga');
update public.skills set learning_order = 8, subskill_difficulty = 2.75 where slug = 'hip-openers' and category_id = (select id from public.categories where name = 'Yoga');
update public.skills set learning_order = 9, subskill_difficulty = 3.00 where slug = 'yin-yoga' and category_id = (select id from public.categories where name = 'Yoga');
update public.skills set learning_order = 10, subskill_difficulty = 3.25 where slug = 'restorative-yoga' and category_id = (select id from public.categories where name = 'Yoga');
update public.skills set learning_order = 11, subskill_difficulty = 3.50 where slug = 'yoga-for-back-pain' and category_id = (select id from public.categories where name = 'Yoga');
update public.skills set learning_order = 12, subskill_difficulty = 3.75 where slug = 'bridge-wheel-backbend' and category_id = (select id from public.categories where name = 'Yoga');
update public.skills set learning_order = 13, subskill_difficulty = 4.00 where slug = 'chaturanga' and category_id = (select id from public.categories where name = 'Yoga');
update public.skills set learning_order = 14, subskill_difficulty = 4.25 where slug = 'crow-pose' and category_id = (select id from public.categories where name = 'Yoga');
update public.skills set learning_order = 15, subskill_difficulty = 4.50 where slug = 'headstand' and category_id = (select id from public.categories where name = 'Yoga');
update public.skills set learning_order = 16, subskill_difficulty = 4.75 where slug = 'forearm-stand' and category_id = (select id from public.categories where name = 'Yoga');
update public.skills set learning_order = 17, subskill_difficulty = 5.00 where slug = 'handstand' and category_id = (select id from public.categories where name = 'Yoga');

-- ---- Pilates: +8 (total 18) -----------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where name = 'Pilates'), 'pilates-breathing', 'Pilates breathing', 'Lateral thoracic breathing, the first Pilates principle.', true),
  ((select id from public.categories where name = 'Pilates'), 'neutral-spine', 'Neutral spine and imprint', 'Find neutral pelvis and imprint before every exercise.', true),
  ((select id from public.categories where name = 'Pilates'), 'pilates-for-beginners', 'Pilates for beginners', 'Your first mat class, cue by cue.', true),
  ((select id from public.categories where name = 'Pilates'), 'double-leg-stretch', 'Double leg stretch', 'The partner exercise to single leg stretch.', true),
  ((select id from public.categories where name = 'Pilates'), 'rolling-like-a-ball', 'Rolling like a ball', 'Control the roll and find balance.', true),
  ((select id from public.categories where name = 'Pilates'), 'roll-over', 'Roll-over', 'Articulate the spine overhead with control.', true),
  ((select id from public.categories where name = 'Pilates'), 'pilates-swimming', 'Swimming (Pilates)', 'Prone back-extension progression after the swan.', true),
  ((select id from public.categories where name = 'Pilates'), 'reformer-footwork', 'Reformer basics: footwork', 'Toes, arches, heels and tendon stretch on the reformer.', true)
on conflict (category_id, slug) do nothing;

update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'pilates-breathing' and category_id = (select id from public.categories where name = 'Pilates');
update public.skills set learning_order = 2, subskill_difficulty = 1.24 where slug = 'neutral-spine' and category_id = (select id from public.categories where name = 'Pilates');
update public.skills set learning_order = 3, subskill_difficulty = 1.47 where slug = 'pilates-for-beginners' and category_id = (select id from public.categories where name = 'Pilates');
update public.skills set learning_order = 4, subskill_difficulty = 1.71 where slug = 'the-hundred' and category_id = (select id from public.categories where name = 'Pilates');
update public.skills set learning_order = 5, subskill_difficulty = 1.94 where slug = 'pilates-bridge' and category_id = (select id from public.categories where name = 'Pilates');
update public.skills set learning_order = 6, subskill_difficulty = 2.18 where slug = 'leg-circles' and category_id = (select id from public.categories where name = 'Pilates');
update public.skills set learning_order = 7, subskill_difficulty = 2.41 where slug = 'rolling-like-a-ball' and category_id = (select id from public.categories where name = 'Pilates');
update public.skills set learning_order = 8, subskill_difficulty = 2.65 where slug = 'single-leg-stretch' and category_id = (select id from public.categories where name = 'Pilates');
update public.skills set learning_order = 9, subskill_difficulty = 2.88 where slug = 'double-leg-stretch' and category_id = (select id from public.categories where name = 'Pilates');
update public.skills set learning_order = 10, subskill_difficulty = 3.12 where slug = 'spine-stretch-forward' and category_id = (select id from public.categories where name = 'Pilates');
update public.skills set learning_order = 11, subskill_difficulty = 3.35 where slug = 'side-leg-series' and category_id = (select id from public.categories where name = 'Pilates');
update public.skills set learning_order = 12, subskill_difficulty = 3.59 where slug = 'roll-up' and category_id = (select id from public.categories where name = 'Pilates');
update public.skills set learning_order = 13, subskill_difficulty = 3.82 where slug = 'roll-over' and category_id = (select id from public.categories where name = 'Pilates');
update public.skills set learning_order = 14, subskill_difficulty = 4.06 where slug = 'swan-prep' and category_id = (select id from public.categories where name = 'Pilates');
update public.skills set learning_order = 15, subskill_difficulty = 4.29 where slug = 'pilates-swimming' and category_id = (select id from public.categories where name = 'Pilates');
update public.skills set learning_order = 16, subskill_difficulty = 4.53 where slug = 'plank-series' and category_id = (select id from public.categories where name = 'Pilates');
update public.skills set learning_order = 17, subskill_difficulty = 4.76 where slug = 'teaser' and category_id = (select id from public.categories where name = 'Pilates');
update public.skills set learning_order = 18, subskill_difficulty = 5.00 where slug = 'reformer-footwork' and category_id = (select id from public.categories where name = 'Pilates');

-- ---- Gym (men): +7 (total 19) ---------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where name = 'Gym (men)'), 'barbell-row', 'Barbell row', 'The missing horizontal pull: row with a braced, flat back.', true),
  ((select id from public.categories where name = 'Gym (men)'), 'dumbbell-row', 'Dumbbell row', 'Single-arm row for a strong, controlled horizontal pull.', true),
  ((select id from public.categories where name = 'Gym (men)'), 'lunge-split-squat', 'Lunge and split squat', 'Single-leg strength with lunges and split squats.', true),
  ((select id from public.categories where name = 'Gym (men)'), 'hamstring-training', 'Hamstring training', 'Romanian deadlifts, curls and hamstring accessories.', true),
  ((select id from public.categories where name = 'Gym (men)'), 'training-split-basics', 'Training split basics', 'Full body, upper/lower or push-pull-legs.', true),
  ((select id from public.categories where name = 'Gym (men)'), 'bulking-nutrition', 'Bulking nutrition', 'Eat to gain muscle without unnecessary fat.', true),
  ((select id from public.categories where name = 'Gym (men)'), 'cardio-for-lifters', 'Cardio for lifters', 'Add conditioning without hurting your gains.', true)
on conflict (category_id, slug) do nothing;

update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'mobility-warm-up' and category_id = (select id from public.categories where name = 'Gym (men)');
update public.skills set learning_order = 2, subskill_difficulty = 1.22 where slug = 'core-bracing' and category_id = (select id from public.categories where name = 'Gym (men)');
update public.skills set learning_order = 3, subskill_difficulty = 1.44 where slug = 'recovery-habits' and category_id = (select id from public.categories where name = 'Gym (men)');
update public.skills set learning_order = 4, subskill_difficulty = 1.67 where slug = 'cardio-for-lifters' and category_id = (select id from public.categories where name = 'Gym (men)');
update public.skills set learning_order = 5, subskill_difficulty = 1.89 where slug = 'fat-loss-nutrition' and category_id = (select id from public.categories where name = 'Gym (men)');
update public.skills set learning_order = 6, subskill_difficulty = 2.11 where slug = 'bulking-nutrition' and category_id = (select id from public.categories where name = 'Gym (men)');
update public.skills set learning_order = 7, subskill_difficulty = 2.33 where slug = 'barbell-squat' and category_id = (select id from public.categories where name = 'Gym (men)');
update public.skills set learning_order = 8, subskill_difficulty = 2.56 where slug = 'lunge-split-squat' and category_id = (select id from public.categories where name = 'Gym (men)');
update public.skills set learning_order = 9, subskill_difficulty = 2.78 where slug = 'hamstring-training' and category_id = (select id from public.categories where name = 'Gym (men)');
update public.skills set learning_order = 10, subskill_difficulty = 3.00 where slug = 'bench-press' and category_id = (select id from public.categories where name = 'Gym (men)');
update public.skills set learning_order = 11, subskill_difficulty = 3.22 where slug = 'deadlift' and category_id = (select id from public.categories where name = 'Gym (men)');
update public.skills set learning_order = 12, subskill_difficulty = 3.44 where slug = 'barbell-row' and category_id = (select id from public.categories where name = 'Gym (men)');
update public.skills set learning_order = 13, subskill_difficulty = 3.67 where slug = 'dumbbell-row' and category_id = (select id from public.categories where name = 'Gym (men)');
update public.skills set learning_order = 14, subskill_difficulty = 3.89 where slug = 'pull-up-progression' and category_id = (select id from public.categories where name = 'Gym (men)');
update public.skills set learning_order = 15, subskill_difficulty = 4.11 where slug = 'overhead-press' and category_id = (select id from public.categories where name = 'Gym (men)');
update public.skills set learning_order = 16, subskill_difficulty = 4.33 where slug = 'arm-training' and category_id = (select id from public.categories where name = 'Gym (men)');
update public.skills set learning_order = 17, subskill_difficulty = 4.56 where slug = 'shoulder-health' and category_id = (select id from public.categories where name = 'Gym (men)');
update public.skills set learning_order = 18, subskill_difficulty = 4.78 where slug = 'hypertrophy-programming' and category_id = (select id from public.categories where name = 'Gym (men)');
update public.skills set learning_order = 19, subskill_difficulty = 5.00 where slug = 'training-split-basics' and category_id = (select id from public.categories where name = 'Gym (men)');

-- ---- Gym (women): +9 (total 21) -------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where name = 'Gym (women)'), 'beginner-lifting-program', 'Beginner lifting program', 'Your first weeks in the gym, session by session.', true),
  ((select id from public.categories where name = 'Gym (women)'), 'barbell-back-squat', 'Barbell back squat', 'Take the squat from goblet to barbell.', true),
  ((select id from public.categories where name = 'Gym (women)'), 'deadlift', 'Deadlift', 'Conventional and sumo deadlift technique.', true),
  ((select id from public.categories where name = 'Gym (women)'), 'overhead-press', 'Overhead press', 'Press overhead with a stable core and shoulders.', true),
  ((select id from public.categories where name = 'Gym (women)'), 'pull-up-progression', 'Pull-up progression', 'Build to your first unassisted pull-up.', true),
  ((select id from public.categories where name = 'Gym (women)'), 'dumbbell-cable-row', 'Dumbbell and cable row', 'The missing horizontal pull for a strong back.', true),
  ((select id from public.categories where name = 'Gym (women)'), 'bulgarian-split-squat', 'Bulgarian split squat and lunges', 'Single-leg work for glutes and quads.', true),
  ((select id from public.categories where name = 'Gym (women)'), 'postpartum-core', 'Postpartum core and diastasis recti', 'Rebuild core strength safely after birth.', true),
  ((select id from public.categories where name = 'Gym (women)'), 'cardio-with-lifting', 'Running alongside lifting', 'Combine cardio and lifting without losing strength.', true)
on conflict (category_id, slug) do nothing;

update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'gym-confidence' and category_id = (select id from public.categories where name = 'Gym (women)');
update public.skills set learning_order = 2, subskill_difficulty = 1.20 where slug = 'beginner-lifting-program' and category_id = (select id from public.categories where name = 'Gym (women)');
update public.skills set learning_order = 3, subskill_difficulty = 1.40 where slug = 'mobility-stability' and category_id = (select id from public.categories where name = 'Gym (women)');
update public.skills set learning_order = 4, subskill_difficulty = 1.60 where slug = 'goblet-squat' and category_id = (select id from public.categories where name = 'Gym (women)');
update public.skills set learning_order = 5, subskill_difficulty = 1.80 where slug = 'barbell-back-squat' and category_id = (select id from public.categories where name = 'Gym (women)');
update public.skills set learning_order = 6, subskill_difficulty = 2.00 where slug = 'bulgarian-split-squat' and category_id = (select id from public.categories where name = 'Gym (women)');
update public.skills set learning_order = 7, subskill_difficulty = 2.20 where slug = 'glute-bridge-hip-thrust' and category_id = (select id from public.categories where name = 'Gym (women)');
update public.skills set learning_order = 8, subskill_difficulty = 2.40 where slug = 'dumbbell-bench-press' and category_id = (select id from public.categories where name = 'Gym (women)');
update public.skills set learning_order = 9, subskill_difficulty = 2.60 where slug = 'lat-pulldown' and category_id = (select id from public.categories where name = 'Gym (women)');
update public.skills set learning_order = 10, subskill_difficulty = 2.80 where slug = 'pull-up-progression' and category_id = (select id from public.categories where name = 'Gym (women)');
update public.skills set learning_order = 11, subskill_difficulty = 3.00 where slug = 'dumbbell-cable-row' and category_id = (select id from public.categories where name = 'Gym (women)');
update public.skills set learning_order = 12, subskill_difficulty = 3.20 where slug = 'romanian-deadlift' and category_id = (select id from public.categories where name = 'Gym (women)');
update public.skills set learning_order = 13, subskill_difficulty = 3.40 where slug = 'deadlift' and category_id = (select id from public.categories where name = 'Gym (women)');
update public.skills set learning_order = 14, subskill_difficulty = 3.60 where slug = 'nutrition-for-strength' and category_id = (select id from public.categories where name = 'Gym (women)');
update public.skills set learning_order = 15, subskill_difficulty = 3.80 where slug = 'cardio-with-lifting' and category_id = (select id from public.categories where name = 'Gym (women)');
update public.skills set learning_order = 16, subskill_difficulty = 4.00 where slug = 'lower-body-hypertrophy' and category_id = (select id from public.categories where name = 'Gym (women)');
update public.skills set learning_order = 17, subskill_difficulty = 4.20 where slug = 'upper-body-hypertrophy' and category_id = (select id from public.categories where name = 'Gym (women)');
update public.skills set learning_order = 18, subskill_difficulty = 4.40 where slug = 'overhead-press' and category_id = (select id from public.categories where name = 'Gym (women)');
update public.skills set learning_order = 19, subskill_difficulty = 4.60 where slug = 'pelvic-floor-aware-lifting' and category_id = (select id from public.categories where name = 'Gym (women)');
update public.skills set learning_order = 20, subskill_difficulty = 4.80 where slug = 'postpartum-core' and category_id = (select id from public.categories where name = 'Gym (women)');
update public.skills set learning_order = 21, subskill_difficulty = 5.00 where slug = 'cycle-aware-training' and category_id = (select id from public.categories where name = 'Gym (women)');

commit;
