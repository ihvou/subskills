-- 0045: round-2 gap fill for the 13 existing categories -- 67 sub-skills, 6 renames.
--
-- Source: docs/subskill-gap-audit-round-2.md. Every entry was probed through
-- `yt-dlp ytsearch` and kept only where dedicated single-topic tutorials exist.
-- Everything the audit marked "Flagged LOW -- do not build" is deliberately absent
-- (pilates back pain/posture, menopause and women's core training, boxing clinch,
-- tennis passing shot, prenatal yoga, ab training, treadmill running, fear of water).
--
-- RENAMES CHANGE name ONLY, NEVER slug -- the slug is the public URL and these
-- categories are live. Same pattern as 0039, where "Starting to run" became
-- "Couch to 5K" while the slug stayed `starting-to-run`.
--
-- NOT renamed: "Running alongside lifting". An earlier draft of the audit called for
-- it on the evidence of Indonesian-language search results. That evidence was wrong --
-- YouTube serves auto-translated title metadata, and the underlying videos are
-- Natacha Oceane and Alan Thrall, exactly on topic. See the correction in the audit.
--
-- New sub-skills are inserted at their pedagogical position and the whole category is
-- renumbered. They are safe to add is_active = true: apps/web hides any sub-skill
-- below 3 published resources (getPublishMinResources), so they stay invisible until
-- the collector has actually filled them.
begin;

update public.skills set name = 'Round the head shot' where slug = 'around-the-head' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set name = 'High serve' where slug = 'serve-high' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set name = 'Riding down the line' where slug = 'trimming' and category_id = (select id from public.categories where slug = 'surfing');
update public.skills set name = 'Turns to beat a defender' where slug = 'turning-with-the-ball' and category_id = (select id from public.categories where slug = 'soccer');
update public.skills set name = 'How to take a penalty' where slug = 'penalty-technique' and category_id = (select id from public.categories where slug = 'soccer');
update public.skills set name = 'Cycling nutrition' where slug = 'fuelling-hydration' and category_id = (select id from public.categories where slug = 'cycling');

-- ---- badminton: +4 -------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where slug = 'badminton'), 'badminton-rules', 'Badminton rules explained', 'Scoring, service rules, court boundaries and lets.', true),
  ((select id from public.categories where slug = 'badminton'), 'badminton-warm-up', 'Badminton warm up', 'Prepare shoulders, hips and ankles before playing.', true),
  ((select id from public.categories where slug = 'badminton'), 'cross-court-net-shot', 'Cross court net shot', 'Play a tight net shot across the court to move the opponent.', true),
  ((select id from public.categories where slug = 'badminton'), 'choosing-a-badminton-racket', 'How to choose a badminton racket', 'Match weight, balance and flex to your game.', true)
on conflict (category_id, slug) do nothing;

-- ---- boxing: +6 -------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where slug = 'boxing'), 'choosing-boxing-gloves', 'How to choose boxing gloves', 'Pick glove weight and type for bag, pads and sparring.', true),
  ((select id from public.categories where slug = 'boxing'), 'boxer-skip', 'Boxer skip', 'Skip with the boxer''s step to build rhythm and footwork.', true),
  ((select id from public.categories where slug = 'boxing'), 'cutting-off-the-ring', 'How to cut off the ring', 'Herd a moving opponent instead of chasing them.', true),
  ((select id from public.categories where slug = 'boxing'), 'beating-a-southpaw', 'How to beat a southpaw', 'Angles, foot position and the shots that work against southpaws.', true),
  ((select id from public.categories where slug = 'boxing'), 'feinting', 'Feinting', 'Sell a shot you do not throw to open up the real one.', true),
  ((select id from public.categories where slug = 'boxing'), 'double-end-bag', 'Double end bag', 'Build timing and accuracy on the double end bag.', true)
on conflict (category_id, slug) do nothing;

-- ---- cycling: +7 -------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where slug = 'cycling'), 'how-to-ride-a-bike', 'How to ride a bike for adults', 'Balance, start and stop for a first-time adult rider.', true),
  ((select id from public.categories where slug = 'cycling'), 'tubeless-tyre-setup', 'Tubeless tyre setup', 'Fit tubeless tyres, add sealant and seat the bead.', true),
  ((select id from public.categories where slug = 'cycling'), 'replacing-a-bike-chain', 'How to replace a bike chain', 'Measure chain wear, size a new chain and fit a quick link.', true),
  ((select id from public.categories where slug = 'cycling'), 'cleat-position', 'Cleat position', 'Set fore-aft, lateral and rotational cleat position.', true),
  ((select id from public.categories where slug = 'cycling'), 'cycling-sprint', 'Cycling sprint technique', 'Position, gear and cadence for a road sprint.', true),
  ((select id from public.categories where slug = 'cycling'), 'cycling-in-the-rain', 'Cycling in the rain', 'Braking, cornering, kit and bike care in the wet.', true),
  ((select id from public.categories where slug = 'cycling'), 'strength-training-for-cyclists', 'Strength training for cyclists', 'Off-bike work that makes you faster and more durable.', true)
on conflict (category_id, slug) do nothing;

-- ---- gym-men: +9 -------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where slug = 'gym-men'), 'farmers-walk', 'Farmer''s walk', 'Load and carry heavy for grip, core and trunk stability.', true),
  ((select id from public.categories where slug = 'gym-men'), 'pallof-press', 'Pallof press', 'Resist rotation to build a braced, stable trunk.', true),
  ((select id from public.categories where slug = 'gym-men'), 'lifting-belt', 'How to use a lifting belt', 'When to wear a belt and how to brace against it.', true),
  ((select id from public.categories where slug = 'gym-men'), 'creatine', 'Creatine', 'What creatine does, how to dose it and what to expect.', true),
  ((select id from public.categories where slug = 'gym-men'), 'front-squat', 'Front squat', 'Squat with a front rack for quad emphasis and upright posture.', true),
  ((select id from public.categories where slug = 'gym-men'), 'calf-raises', 'Calf raises', 'Train gastrocnemius and soleus through a full range.', true),
  ((select id from public.categories where slug = 'gym-men'), 'dips', 'Dips', 'Build pressing strength on parallel bars with shoulder-safe depth.', true),
  ((select id from public.categories where slug = 'gym-men'), 'power-clean', 'Power clean', 'Pull, extend and catch the bar in the front rack.', true),
  ((select id from public.categories where slug = 'gym-men'), 'kettlebell-swing', 'Kettlebell swing', 'Hinge and snap the hips to drive the bell.', true)
on conflict (category_id, slug) do nothing;

-- ---- gym-women: +3 -------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where slug = 'gym-women'), 'recovery-habits', 'Recovery habits', 'Sleep, deloads and managing soreness across a training block.', true),
  ((select id from public.categories where slug = 'gym-women'), 'fat-loss-nutrition', 'Fat loss nutrition', 'Calorie targets, protein and adherence for sustainable fat loss.', true),
  ((select id from public.categories where slug = 'gym-women'), 'lifting-while-pregnant', 'Lifting while pregnant', 'Adjust load, movements and bracing through pregnancy.', true)
on conflict (category_id, slug) do nothing;

-- ---- padel: +4 -------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where slug = 'padel'), 'padel-rules', 'Padel rules for beginners', 'Scoring, serving, walls and what counts as out.', true),
  ((select id from public.categories where slug = 'padel'), 'padel-footwork', 'Padel footwork', 'Split step, move to the glass and recover position.', true),
  ((select id from public.categories where slug = 'padel'), 'playing-with-your-partner', 'Playing with your partner', 'Communication, calling balls and covering for each other.', true),
  ((select id from public.categories where slug = 'padel'), 'choosing-a-padel-racket', 'How to choose a padel racket', 'Shape, weight, balance and core for your level.', true)
on conflict (category_id, slug) do nothing;

-- ---- pilates: +3 -------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where slug = 'pilates'), 'criss-cross', 'Criss-cross', 'The oblique twist from the classical mat order.', true),
  ((select id from public.categories where slug = 'pilates'), 'the-saw', 'The Saw', 'Rotate and reach past the foot to wring out the spine.', true),
  ((select id from public.categories where slug = 'pilates'), 'neck-pull', 'Neck Pull', 'Roll up and down with hands behind the head.', true)
on conflict (category_id, slug) do nothing;

-- ---- running: +7 -------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where slug = 'running'), 'zone-2-running', 'Zone 2 running', 'Train at an easy aerobic heart rate and know why it works.', true),
  ((select id from public.categories where slug = 'running'), 'hill-repeats', 'Hill repeats', 'Structure a hill repeat session for power and form.', true),
  ((select id from public.categories where slug = 'running'), 'marathon-fuelling', 'Marathon fuelling', 'Carbs per hour, gels and practising race nutrition.', true),
  ((select id from public.categories where slug = 'running'), 'marathon-taper', 'How to taper for a marathon', 'Cut volume without losing fitness in the final weeks.', true),
  ((select id from public.categories where slug = 'running'), 'plantar-fasciitis', 'Plantar fasciitis', 'Recognise, treat and rehab heel and arch pain.', true),
  ((select id from public.categories where slug = 'running'), 'achilles-tendonitis', 'Achilles tendonitis', 'Load management and rehab for achilles pain.', true),
  ((select id from public.categories where slug = 'running'), 'trail-running', 'Trail running', 'Adjust footing, effort and technique off-road.', true)
on conflict (category_id, slug) do nothing;

-- ---- soccer: +4 -------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where slug = 'soccer'), 'shielding-the-ball', 'How to shield the ball', 'Use your body to protect possession under pressure.', true),
  ((select id from public.categories where slug = 'soccer'), 'off-the-ball-movement', 'Off the ball movement', 'Create space and time your runs without the ball.', true),
  ((select id from public.categories where slug = 'soccer'), 'how-to-tackle', 'How to tackle in football', 'Block tackle, poke tackle and the slide tackle without fouling.', true),
  ((select id from public.categories where slug = 'soccer'), 'volley-technique', 'How to hit a volley', 'Strike the ball cleanly out of the air.', true)
on conflict (category_id, slug) do nothing;

-- ---- surfing: +6 -------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where slug = 'surfing'), 'waxing-a-surfboard', 'How to wax a surfboard', 'Base coat, top coat and getting proper bumps.', true),
  ((select id from public.categories where slug = 'surfing'), 'ding-repair', 'Surfboard ding repair', 'Fix dings so water stays out of the foam.', true),
  ((select id from public.categories where slug = 'surfing'), 'falling-off-safely', 'How to fall off safely', 'Fall flat, protect your head and come up covered.', true),
  ((select id from public.categories where slug = 'surfing'), 'catching-a-green-wave', 'How to catch a green wave', 'Move from whitewater to unbroken waves.', true),
  ((select id from public.categories where slug = 'surfing'), 'floater', 'Floater', 'Ride up and over the breaking section.', true),
  ((select id from public.categories where slug = 'surfing'), 'cross-stepping', 'Cross stepping', 'Walk the board to the nose on a longboard.', true)
on conflict (category_id, slug) do nothing;

-- ---- swimming: +6 -------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where slug = 'swimming'), 'treading-water', 'How to tread water', 'Stay vertical and calm using eggbeater and sculling.', true),
  ((select id from public.categories where slug = 'swimming'), 'swimming-without-getting-tired', 'How to swim without getting tired', 'Pace, breathe and relax to swim further.', true),
  ((select id from public.categories where slug = 'swimming'), 'backstroke-kick', 'Backstroke kick', 'Kick from the hip with a steady, compact backstroke kick.', true),
  ((select id from public.categories where slug = 'swimming'), 'open-turn', 'Open turn', 'Turn at the wall in breaststroke and butterfly.', true),
  ((select id from public.categories where slug = 'swimming'), 'open-water-sighting', 'Open water sighting', 'Lift, look and swim straight in open water.', true),
  ((select id from public.categories where slug = 'swimming'), 'pull-buoy', 'How to use a pull buoy', 'Use a pull buoy and paddles to build a stronger pull.', true)
on conflict (category_id, slug) do nothing;

-- ---- tennis: +3 -------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where slug = 'tennis'), 'tennis-scoring', 'Tennis scoring explained', 'Games, sets, deuce and tie-breaks.', true),
  ((select id from public.categories where slug = 'tennis'), 'tennis-elbow', 'Tennis elbow', 'Manage and rehab lateral elbow pain.', true),
  ((select id from public.categories where slug = 'tennis'), 'choosing-a-tennis-racket', 'How to choose a tennis racket', 'Head size, weight, balance and string tension.', true)
on conflict (category_id, slug) do nothing;

-- ---- yoga: +5 -------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where slug = 'yoga'), 'seated-spinal-twist', 'Seated spinal twist', 'Rotate the spine safely from a seated position.', true),
  ((select id from public.categories where slug = 'yoga'), 'triangle-pose', 'Triangle pose', 'Align hips, ribs and reach in Trikonasana.', true),
  ((select id from public.categories where slug = 'yoga'), 'splits', 'How to do the splits', 'Progress hamstring and hip flexor range toward a split.', true),
  ((select id from public.categories where slug = 'yoga'), 'shoulderstand', 'Shoulderstand', 'Build a supported shoulderstand and plough safely.', true),
  ((select id from public.categories where slug = 'yoga'), 'camel-pose', 'Camel pose', 'Open the chest in Ustrasana without crunching the low back.', true)
on conflict (category_id, slug) do nothing;

-- ---- renumber every touched category -------------------------
update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'badminton-rules' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 2, subskill_difficulty = 1.13 where slug = 'badminton-warm-up' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 3, subskill_difficulty = 1.26 where slug = 'grip-technique' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 4, subskill_difficulty = 1.39 where slug = 'serve-low' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 5, subskill_difficulty = 1.52 where slug = 'serve-high' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 6, subskill_difficulty = 1.65 where slug = 'serve-flick' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 7, subskill_difficulty = 1.77 where slug = 'return-of-serve' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 8, subskill_difficulty = 1.90 where slug = 'footwork-split-step' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 9, subskill_difficulty = 2.03 where slug = 'footwork-front-court' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 10, subskill_difficulty = 2.16 where slug = 'footwork-rear-court' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 11, subskill_difficulty = 2.29 where slug = 'lift' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 12, subskill_difficulty = 2.42 where slug = 'net-shot' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 13, subskill_difficulty = 2.55 where slug = 'cross-court-net-shot' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 14, subskill_difficulty = 2.68 where slug = 'net-kill' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 15, subskill_difficulty = 2.81 where slug = 'push' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 16, subskill_difficulty = 2.94 where slug = 'drive' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 17, subskill_difficulty = 3.06 where slug = 'forehand-clear' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 18, subskill_difficulty = 3.19 where slug = 'around-the-head' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 19, subskill_difficulty = 3.32 where slug = 'drop-shot' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 20, subskill_difficulty = 3.45 where slug = 'defense-block' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 21, subskill_difficulty = 3.58 where slug = 'defense-lift' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 22, subskill_difficulty = 3.71 where slug = 'forehand-smash' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 23, subskill_difficulty = 3.84 where slug = 'jump-smash' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 24, subskill_difficulty = 3.97 where slug = 'wrist-rotation' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 25, subskill_difficulty = 4.10 where slug = 'singles-strategy' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 26, subskill_difficulty = 4.23 where slug = 'deception' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 27, subskill_difficulty = 4.35 where slug = 'doubles-rotation' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 28, subskill_difficulty = 4.48 where slug = 'mixed-doubles-tactics' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 29, subskill_difficulty = 4.61 where slug = 'backhand-clear' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 30, subskill_difficulty = 4.74 where slug = 'backhand-smash' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 31, subskill_difficulty = 4.87 where slug = 'stringing-and-tension' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 32, subskill_difficulty = 5.00 where slug = 'choosing-a-badminton-racket' and category_id = (select id from public.categories where slug = 'badminton');
update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'choosing-boxing-gloves' and category_id = (select id from public.categories where slug = 'boxing');
update public.skills set learning_order = 2, subskill_difficulty = 1.18 where slug = 'hand-wrapping' and category_id = (select id from public.categories where slug = 'boxing');
update public.skills set learning_order = 3, subskill_difficulty = 1.36 where slug = 'stance-guard' and category_id = (select id from public.categories where slug = 'boxing');
update public.skills set learning_order = 4, subskill_difficulty = 1.55 where slug = 'jab' and category_id = (select id from public.categories where slug = 'boxing');
update public.skills set learning_order = 5, subskill_difficulty = 1.73 where slug = 'cross' and category_id = (select id from public.categories where slug = 'boxing');
update public.skills set learning_order = 6, subskill_difficulty = 1.91 where slug = 'footwork' and category_id = (select id from public.categories where slug = 'boxing');
update public.skills set learning_order = 7, subskill_difficulty = 2.09 where slug = 'boxer-skip' and category_id = (select id from public.categories where slug = 'boxing');
update public.skills set learning_order = 8, subskill_difficulty = 2.27 where slug = 'distance-range' and category_id = (select id from public.categories where slug = 'boxing');
update public.skills set learning_order = 9, subskill_difficulty = 2.45 where slug = 'cutting-off-the-ring' and category_id = (select id from public.categories where slug = 'boxing');
update public.skills set learning_order = 10, subskill_difficulty = 2.64 where slug = 'defense-blocking' and category_id = (select id from public.categories where slug = 'boxing');
update public.skills set learning_order = 11, subskill_difficulty = 2.82 where slug = 'hook' and category_id = (select id from public.categories where slug = 'boxing');
update public.skills set learning_order = 12, subskill_difficulty = 3.00 where slug = 'uppercut' and category_id = (select id from public.categories where slug = 'boxing');
update public.skills set learning_order = 13, subskill_difficulty = 3.18 where slug = 'body-punching' and category_id = (select id from public.categories where slug = 'boxing');
update public.skills set learning_order = 14, subskill_difficulty = 3.36 where slug = 'head-movement-slipping' and category_id = (select id from public.categories where slug = 'boxing');
update public.skills set learning_order = 15, subskill_difficulty = 3.55 where slug = 'counter-punching' and category_id = (select id from public.categories where slug = 'boxing');
update public.skills set learning_order = 16, subskill_difficulty = 3.73 where slug = 'feinting' and category_id = (select id from public.categories where slug = 'boxing');
update public.skills set learning_order = 17, subskill_difficulty = 3.91 where slug = 'beating-a-southpaw' and category_id = (select id from public.categories where slug = 'boxing');
update public.skills set learning_order = 18, subskill_difficulty = 4.09 where slug = 'shadow-boxing' and category_id = (select id from public.categories where slug = 'boxing');
update public.skills set learning_order = 19, subskill_difficulty = 4.27 where slug = 'combinations' and category_id = (select id from public.categories where slug = 'boxing');
update public.skills set learning_order = 20, subskill_difficulty = 4.45 where slug = 'heavy-bag-work' and category_id = (select id from public.categories where slug = 'boxing');
update public.skills set learning_order = 21, subskill_difficulty = 4.64 where slug = 'double-end-bag' and category_id = (select id from public.categories where slug = 'boxing');
update public.skills set learning_order = 22, subskill_difficulty = 4.82 where slug = 'pad-work' and category_id = (select id from public.categories where slug = 'boxing');
update public.skills set learning_order = 23, subskill_difficulty = 5.00 where slug = 'sparring-fundamentals' and category_id = (select id from public.categories where slug = 'boxing');
update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'how-to-ride-a-bike' and category_id = (select id from public.categories where slug = 'cycling');
update public.skills set learning_order = 2, subskill_difficulty = 1.17 where slug = 'riding-in-traffic' and category_id = (select id from public.categories where slug = 'cycling');
update public.skills set learning_order = 3, subskill_difficulty = 1.33 where slug = 'bike-fit-basics' and category_id = (select id from public.categories where slug = 'cycling');
update public.skills set learning_order = 4, subskill_difficulty = 1.50 where slug = 'choosing-first-bike' and category_id = (select id from public.categories where slug = 'cycling');
update public.skills set learning_order = 5, subskill_difficulty = 1.67 where slug = 'puncture-repair' and category_id = (select id from public.categories where slug = 'cycling');
update public.skills set learning_order = 6, subskill_difficulty = 1.83 where slug = 'tubeless-tyre-setup' and category_id = (select id from public.categories where slug = 'cycling');
update public.skills set learning_order = 7, subskill_difficulty = 2.00 where slug = 'chain-cleaning' and category_id = (select id from public.categories where slug = 'cycling');
update public.skills set learning_order = 8, subskill_difficulty = 2.17 where slug = 'replacing-a-bike-chain' and category_id = (select id from public.categories where slug = 'cycling');
update public.skills set learning_order = 9, subskill_difficulty = 2.33 where slug = 'gear-adjustment' and category_id = (select id from public.categories where slug = 'cycling');
update public.skills set learning_order = 10, subskill_difficulty = 2.50 where slug = 'brake-adjustment' and category_id = (select id from public.categories where slug = 'cycling');
update public.skills set learning_order = 11, subskill_difficulty = 2.67 where slug = 'clipping-in-clipless' and category_id = (select id from public.categories where slug = 'cycling');
update public.skills set learning_order = 12, subskill_difficulty = 2.83 where slug = 'cleat-position' and category_id = (select id from public.categories where slug = 'cycling');
update public.skills set learning_order = 13, subskill_difficulty = 3.00 where slug = 'braking-technique' and category_id = (select id from public.categories where slug = 'cycling');
update public.skills set learning_order = 14, subskill_difficulty = 3.17 where slug = 'gear-shifting' and category_id = (select id from public.categories where slug = 'cycling');
update public.skills set learning_order = 15, subskill_difficulty = 3.33 where slug = 'pedaling-efficiency' and category_id = (select id from public.categories where slug = 'cycling');
update public.skills set learning_order = 16, subskill_difficulty = 3.50 where slug = 'cornering' and category_id = (select id from public.categories where slug = 'cycling');
update public.skills set learning_order = 17, subskill_difficulty = 3.67 where slug = 'climbing-technique' and category_id = (select id from public.categories where slug = 'cycling');
update public.skills set learning_order = 18, subskill_difficulty = 3.83 where slug = 'cycling-sprint' and category_id = (select id from public.categories where slug = 'cycling');
update public.skills set learning_order = 19, subskill_difficulty = 4.00 where slug = 'fuelling-hydration' and category_id = (select id from public.categories where slug = 'cycling');
update public.skills set learning_order = 20, subskill_difficulty = 4.17 where slug = 'training-zones' and category_id = (select id from public.categories where slug = 'cycling');
update public.skills set learning_order = 21, subskill_difficulty = 4.33 where slug = 'strength-training-for-cyclists' and category_id = (select id from public.categories where slug = 'cycling');
update public.skills set learning_order = 22, subskill_difficulty = 4.50 where slug = 'indoor-training' and category_id = (select id from public.categories where slug = 'cycling');
update public.skills set learning_order = 23, subskill_difficulty = 4.67 where slug = 'group-riding' and category_id = (select id from public.categories where slug = 'cycling');
update public.skills set learning_order = 24, subskill_difficulty = 4.83 where slug = 'descending' and category_id = (select id from public.categories where slug = 'cycling');
update public.skills set learning_order = 25, subskill_difficulty = 5.00 where slug = 'cycling-in-the-rain' and category_id = (select id from public.categories where slug = 'cycling');
update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'mobility-warm-up' and category_id = (select id from public.categories where slug = 'gym-men');
update public.skills set learning_order = 2, subskill_difficulty = 1.15 where slug = 'core-bracing' and category_id = (select id from public.categories where slug = 'gym-men');
update public.skills set learning_order = 3, subskill_difficulty = 1.30 where slug = 'lifting-belt' and category_id = (select id from public.categories where slug = 'gym-men');
update public.skills set learning_order = 4, subskill_difficulty = 1.44 where slug = 'pallof-press' and category_id = (select id from public.categories where slug = 'gym-men');
update public.skills set learning_order = 5, subskill_difficulty = 1.59 where slug = 'farmers-walk' and category_id = (select id from public.categories where slug = 'gym-men');
update public.skills set learning_order = 6, subskill_difficulty = 1.74 where slug = 'recovery-habits' and category_id = (select id from public.categories where slug = 'gym-men');
update public.skills set learning_order = 7, subskill_difficulty = 1.89 where slug = 'cardio-for-lifters' and category_id = (select id from public.categories where slug = 'gym-men');
update public.skills set learning_order = 8, subskill_difficulty = 2.04 where slug = 'fat-loss-nutrition' and category_id = (select id from public.categories where slug = 'gym-men');
update public.skills set learning_order = 9, subskill_difficulty = 2.19 where slug = 'bulking-nutrition' and category_id = (select id from public.categories where slug = 'gym-men');
update public.skills set learning_order = 10, subskill_difficulty = 2.33 where slug = 'creatine' and category_id = (select id from public.categories where slug = 'gym-men');
update public.skills set learning_order = 11, subskill_difficulty = 2.48 where slug = 'barbell-squat' and category_id = (select id from public.categories where slug = 'gym-men');
update public.skills set learning_order = 12, subskill_difficulty = 2.63 where slug = 'front-squat' and category_id = (select id from public.categories where slug = 'gym-men');
update public.skills set learning_order = 13, subskill_difficulty = 2.78 where slug = 'lunge-split-squat' and category_id = (select id from public.categories where slug = 'gym-men');
update public.skills set learning_order = 14, subskill_difficulty = 2.93 where slug = 'hamstring-training' and category_id = (select id from public.categories where slug = 'gym-men');
update public.skills set learning_order = 15, subskill_difficulty = 3.07 where slug = 'calf-raises' and category_id = (select id from public.categories where slug = 'gym-men');
update public.skills set learning_order = 16, subskill_difficulty = 3.22 where slug = 'bench-press' and category_id = (select id from public.categories where slug = 'gym-men');
update public.skills set learning_order = 17, subskill_difficulty = 3.37 where slug = 'dips' and category_id = (select id from public.categories where slug = 'gym-men');
update public.skills set learning_order = 18, subskill_difficulty = 3.52 where slug = 'deadlift' and category_id = (select id from public.categories where slug = 'gym-men');
update public.skills set learning_order = 19, subskill_difficulty = 3.67 where slug = 'kettlebell-swing' and category_id = (select id from public.categories where slug = 'gym-men');
update public.skills set learning_order = 20, subskill_difficulty = 3.81 where slug = 'power-clean' and category_id = (select id from public.categories where slug = 'gym-men');
update public.skills set learning_order = 21, subskill_difficulty = 3.96 where slug = 'barbell-row' and category_id = (select id from public.categories where slug = 'gym-men');
update public.skills set learning_order = 22, subskill_difficulty = 4.11 where slug = 'dumbbell-row' and category_id = (select id from public.categories where slug = 'gym-men');
update public.skills set learning_order = 23, subskill_difficulty = 4.26 where slug = 'pull-up-progression' and category_id = (select id from public.categories where slug = 'gym-men');
update public.skills set learning_order = 24, subskill_difficulty = 4.41 where slug = 'overhead-press' and category_id = (select id from public.categories where slug = 'gym-men');
update public.skills set learning_order = 25, subskill_difficulty = 4.56 where slug = 'arm-training' and category_id = (select id from public.categories where slug = 'gym-men');
update public.skills set learning_order = 26, subskill_difficulty = 4.70 where slug = 'shoulder-health' and category_id = (select id from public.categories where slug = 'gym-men');
update public.skills set learning_order = 27, subskill_difficulty = 4.85 where slug = 'hypertrophy-programming' and category_id = (select id from public.categories where slug = 'gym-men');
update public.skills set learning_order = 28, subskill_difficulty = 5.00 where slug = 'training-split-basics' and category_id = (select id from public.categories where slug = 'gym-men');
update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'gym-confidence' and category_id = (select id from public.categories where slug = 'gym-women');
update public.skills set learning_order = 2, subskill_difficulty = 1.17 where slug = 'beginner-lifting-program' and category_id = (select id from public.categories where slug = 'gym-women');
update public.skills set learning_order = 3, subskill_difficulty = 1.35 where slug = 'mobility-stability' and category_id = (select id from public.categories where slug = 'gym-women');
update public.skills set learning_order = 4, subskill_difficulty = 1.52 where slug = 'recovery-habits' and category_id = (select id from public.categories where slug = 'gym-women');
update public.skills set learning_order = 5, subskill_difficulty = 1.70 where slug = 'goblet-squat' and category_id = (select id from public.categories where slug = 'gym-women');
update public.skills set learning_order = 6, subskill_difficulty = 1.87 where slug = 'barbell-back-squat' and category_id = (select id from public.categories where slug = 'gym-women');
update public.skills set learning_order = 7, subskill_difficulty = 2.04 where slug = 'bulgarian-split-squat' and category_id = (select id from public.categories where slug = 'gym-women');
update public.skills set learning_order = 8, subskill_difficulty = 2.22 where slug = 'glute-bridge-hip-thrust' and category_id = (select id from public.categories where slug = 'gym-women');
update public.skills set learning_order = 9, subskill_difficulty = 2.39 where slug = 'dumbbell-bench-press' and category_id = (select id from public.categories where slug = 'gym-women');
update public.skills set learning_order = 10, subskill_difficulty = 2.57 where slug = 'lat-pulldown' and category_id = (select id from public.categories where slug = 'gym-women');
update public.skills set learning_order = 11, subskill_difficulty = 2.74 where slug = 'pull-up-progression' and category_id = (select id from public.categories where slug = 'gym-women');
update public.skills set learning_order = 12, subskill_difficulty = 2.91 where slug = 'dumbbell-cable-row' and category_id = (select id from public.categories where slug = 'gym-women');
update public.skills set learning_order = 13, subskill_difficulty = 3.09 where slug = 'romanian-deadlift' and category_id = (select id from public.categories where slug = 'gym-women');
update public.skills set learning_order = 14, subskill_difficulty = 3.26 where slug = 'deadlift' and category_id = (select id from public.categories where slug = 'gym-women');
update public.skills set learning_order = 15, subskill_difficulty = 3.43 where slug = 'nutrition-for-strength' and category_id = (select id from public.categories where slug = 'gym-women');
update public.skills set learning_order = 16, subskill_difficulty = 3.61 where slug = 'fat-loss-nutrition' and category_id = (select id from public.categories where slug = 'gym-women');
update public.skills set learning_order = 17, subskill_difficulty = 3.78 where slug = 'cardio-with-lifting' and category_id = (select id from public.categories where slug = 'gym-women');
update public.skills set learning_order = 18, subskill_difficulty = 3.96 where slug = 'lower-body-hypertrophy' and category_id = (select id from public.categories where slug = 'gym-women');
update public.skills set learning_order = 19, subskill_difficulty = 4.13 where slug = 'upper-body-hypertrophy' and category_id = (select id from public.categories where slug = 'gym-women');
update public.skills set learning_order = 20, subskill_difficulty = 4.30 where slug = 'overhead-press' and category_id = (select id from public.categories where slug = 'gym-women');
update public.skills set learning_order = 21, subskill_difficulty = 4.48 where slug = 'pelvic-floor-aware-lifting' and category_id = (select id from public.categories where slug = 'gym-women');
update public.skills set learning_order = 22, subskill_difficulty = 4.65 where slug = 'lifting-while-pregnant' and category_id = (select id from public.categories where slug = 'gym-women');
update public.skills set learning_order = 23, subskill_difficulty = 4.83 where slug = 'postpartum-core' and category_id = (select id from public.categories where slug = 'gym-women');
update public.skills set learning_order = 24, subskill_difficulty = 5.00 where slug = 'cycle-aware-training' and category_id = (select id from public.categories where slug = 'gym-women');
update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'padel-rules' and category_id = (select id from public.categories where slug = 'padel');
update public.skills set learning_order = 2, subskill_difficulty = 1.17 where slug = 'continental-grip' and category_id = (select id from public.categories where slug = 'padel');
update public.skills set learning_order = 3, subskill_difficulty = 1.35 where slug = 'padel-footwork' and category_id = (select id from public.categories where slug = 'padel');
update public.skills set learning_order = 4, subskill_difficulty = 1.52 where slug = 'serve-first-volley' and category_id = (select id from public.categories where slug = 'padel');
update public.skills set learning_order = 5, subskill_difficulty = 1.70 where slug = 'return-of-serve' and category_id = (select id from public.categories where slug = 'padel');
update public.skills set learning_order = 6, subskill_difficulty = 1.87 where slug = 'forehand-groundstroke' and category_id = (select id from public.categories where slug = 'padel');
update public.skills set learning_order = 7, subskill_difficulty = 2.04 where slug = 'backhand-groundstroke' and category_id = (select id from public.categories where slug = 'padel');
update public.skills set learning_order = 8, subskill_difficulty = 2.22 where slug = 'lob' and category_id = (select id from public.categories where slug = 'padel');
update public.skills set learning_order = 9, subskill_difficulty = 2.39 where slug = 'glass-defense' and category_id = (select id from public.categories where slug = 'padel');
update public.skills set learning_order = 10, subskill_difficulty = 2.57 where slug = 'defending-from-the-back' and category_id = (select id from public.categories where slug = 'padel');
update public.skills set learning_order = 11, subskill_difficulty = 2.74 where slug = 'coming-off-the-wall' and category_id = (select id from public.categories where slug = 'padel');
update public.skills set learning_order = 12, subskill_difficulty = 2.91 where slug = 'volley-technique' and category_id = (select id from public.categories where slug = 'padel');
update public.skills set learning_order = 13, subskill_difficulty = 3.09 where slug = 'net-positioning' and category_id = (select id from public.categories where slug = 'padel');
update public.skills set learning_order = 14, subskill_difficulty = 3.26 where slug = 'court-positioning' and category_id = (select id from public.categories where slug = 'padel');
update public.skills set learning_order = 15, subskill_difficulty = 3.43 where slug = 'playing-with-your-partner' and category_id = (select id from public.categories where slug = 'padel');
update public.skills set learning_order = 16, subskill_difficulty = 3.61 where slug = 'transition-to-net' and category_id = (select id from public.categories where slug = 'padel');
update public.skills set learning_order = 17, subskill_difficulty = 3.78 where slug = 'bandeja' and category_id = (select id from public.categories where slug = 'padel');
update public.skills set learning_order = 18, subskill_difficulty = 3.96 where slug = 'bajada' and category_id = (select id from public.categories where slug = 'padel');
update public.skills set learning_order = 19, subskill_difficulty = 4.13 where slug = 'chiquita' and category_id = (select id from public.categories where slug = 'padel');
update public.skills set learning_order = 20, subskill_difficulty = 4.30 where slug = 'drop-shot' and category_id = (select id from public.categories where slug = 'padel');
update public.skills set learning_order = 21, subskill_difficulty = 4.48 where slug = 'vibora' and category_id = (select id from public.categories where slug = 'padel');
update public.skills set learning_order = 22, subskill_difficulty = 4.65 where slug = 'smash-x3' and category_id = (select id from public.categories where slug = 'padel');
update public.skills set learning_order = 23, subskill_difficulty = 4.83 where slug = 'kick-smash' and category_id = (select id from public.categories where slug = 'padel');
update public.skills set learning_order = 24, subskill_difficulty = 5.00 where slug = 'choosing-a-padel-racket' and category_id = (select id from public.categories where slug = 'padel');
update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'pilates-breathing' and category_id = (select id from public.categories where slug = 'pilates');
update public.skills set learning_order = 2, subskill_difficulty = 1.20 where slug = 'neutral-spine' and category_id = (select id from public.categories where slug = 'pilates');
update public.skills set learning_order = 3, subskill_difficulty = 1.40 where slug = 'pilates-for-beginners' and category_id = (select id from public.categories where slug = 'pilates');
update public.skills set learning_order = 4, subskill_difficulty = 1.60 where slug = 'the-hundred' and category_id = (select id from public.categories where slug = 'pilates');
update public.skills set learning_order = 5, subskill_difficulty = 1.80 where slug = 'pilates-bridge' and category_id = (select id from public.categories where slug = 'pilates');
update public.skills set learning_order = 6, subskill_difficulty = 2.00 where slug = 'leg-circles' and category_id = (select id from public.categories where slug = 'pilates');
update public.skills set learning_order = 7, subskill_difficulty = 2.20 where slug = 'rolling-like-a-ball' and category_id = (select id from public.categories where slug = 'pilates');
update public.skills set learning_order = 8, subskill_difficulty = 2.40 where slug = 'single-leg-stretch' and category_id = (select id from public.categories where slug = 'pilates');
update public.skills set learning_order = 9, subskill_difficulty = 2.60 where slug = 'double-leg-stretch' and category_id = (select id from public.categories where slug = 'pilates');
update public.skills set learning_order = 10, subskill_difficulty = 2.80 where slug = 'criss-cross' and category_id = (select id from public.categories where slug = 'pilates');
update public.skills set learning_order = 11, subskill_difficulty = 3.00 where slug = 'spine-stretch-forward' and category_id = (select id from public.categories where slug = 'pilates');
update public.skills set learning_order = 12, subskill_difficulty = 3.20 where slug = 'the-saw' and category_id = (select id from public.categories where slug = 'pilates');
update public.skills set learning_order = 13, subskill_difficulty = 3.40 where slug = 'side-leg-series' and category_id = (select id from public.categories where slug = 'pilates');
update public.skills set learning_order = 14, subskill_difficulty = 3.60 where slug = 'roll-up' and category_id = (select id from public.categories where slug = 'pilates');
update public.skills set learning_order = 15, subskill_difficulty = 3.80 where slug = 'neck-pull' and category_id = (select id from public.categories where slug = 'pilates');
update public.skills set learning_order = 16, subskill_difficulty = 4.00 where slug = 'roll-over' and category_id = (select id from public.categories where slug = 'pilates');
update public.skills set learning_order = 17, subskill_difficulty = 4.20 where slug = 'swan-prep' and category_id = (select id from public.categories where slug = 'pilates');
update public.skills set learning_order = 18, subskill_difficulty = 4.40 where slug = 'pilates-swimming' and category_id = (select id from public.categories where slug = 'pilates');
update public.skills set learning_order = 19, subskill_difficulty = 4.60 where slug = 'plank-series' and category_id = (select id from public.categories where slug = 'pilates');
update public.skills set learning_order = 20, subskill_difficulty = 4.80 where slug = 'teaser' and category_id = (select id from public.categories where slug = 'pilates');
update public.skills set learning_order = 21, subskill_difficulty = 5.00 where slug = 'reformer-footwork' and category_id = (select id from public.categories where slug = 'pilates');
update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'starting-to-run' and category_id = (select id from public.categories where slug = 'running');
update public.skills set learning_order = 2, subskill_difficulty = 1.15 where slug = 'choosing-running-shoes' and category_id = (select id from public.categories where slug = 'running');
update public.skills set learning_order = 3, subskill_difficulty = 1.31 where slug = 'dynamic-warmup' and category_id = (select id from public.categories where slug = 'running');
update public.skills set learning_order = 4, subskill_difficulty = 1.46 where slug = 'post-run-stretching' and category_id = (select id from public.categories where slug = 'running');
update public.skills set learning_order = 5, subskill_difficulty = 1.62 where slug = 'running-form-posture' and category_id = (select id from public.categories where slug = 'running');
update public.skills set learning_order = 6, subskill_difficulty = 1.77 where slug = 'easy-runs' and category_id = (select id from public.categories where slug = 'running');
update public.skills set learning_order = 7, subskill_difficulty = 1.92 where slug = 'zone-2-running' and category_id = (select id from public.categories where slug = 'running');
update public.skills set learning_order = 8, subskill_difficulty = 2.08 where slug = 'long-run' and category_id = (select id from public.categories where slug = 'running');
update public.skills set learning_order = 9, subskill_difficulty = 2.23 where slug = 'interval-tempo' and category_id = (select id from public.categories where slug = 'running');
update public.skills set learning_order = 10, subskill_difficulty = 2.38 where slug = 'hill-repeats' and category_id = (select id from public.categories where slug = 'running');
update public.skills set learning_order = 11, subskill_difficulty = 2.54 where slug = 'race-pacing' and category_id = (select id from public.categories where slug = 'running');
update public.skills set learning_order = 12, subskill_difficulty = 2.69 where slug = 'marathon-taper' and category_id = (select id from public.categories where slug = 'running');
update public.skills set learning_order = 13, subskill_difficulty = 2.85 where slug = 'marathon-fuelling' and category_id = (select id from public.categories where slug = 'running');
update public.skills set learning_order = 14, subskill_difficulty = 3.00 where slug = 'strength-for-runners' and category_id = (select id from public.categories where slug = 'running');
update public.skills set learning_order = 15, subskill_difficulty = 3.15 where slug = 'shin-splints' and category_id = (select id from public.categories where slug = 'running');
update public.skills set learning_order = 16, subskill_difficulty = 3.31 where slug = 'runners-knee' and category_id = (select id from public.categories where slug = 'running');
update public.skills set learning_order = 17, subskill_difficulty = 3.46 where slug = 'achilles-tendonitis' and category_id = (select id from public.categories where slug = 'running');
update public.skills set learning_order = 18, subskill_difficulty = 3.62 where slug = 'plantar-fasciitis' and category_id = (select id from public.categories where slug = 'running');
update public.skills set learning_order = 19, subskill_difficulty = 3.77 where slug = 'arm-swing' and category_id = (select id from public.categories where slug = 'running');
update public.skills set learning_order = 20, subskill_difficulty = 3.92 where slug = 'breathing-rhythm' and category_id = (select id from public.categories where slug = 'running');
update public.skills set learning_order = 21, subskill_difficulty = 4.08 where slug = 'cadence-optimization' and category_id = (select id from public.categories where slug = 'running');
update public.skills set learning_order = 22, subskill_difficulty = 4.23 where slug = 'foot-strike' and category_id = (select id from public.categories where slug = 'running');
update public.skills set learning_order = 23, subskill_difficulty = 4.38 where slug = 'running-drills' and category_id = (select id from public.categories where slug = 'running');
update public.skills set learning_order = 24, subskill_difficulty = 4.54 where slug = 'strides-form-sprints' and category_id = (select id from public.categories where slug = 'running');
update public.skills set learning_order = 25, subskill_difficulty = 4.69 where slug = 'hill-running' and category_id = (select id from public.categories where slug = 'running');
update public.skills set learning_order = 26, subskill_difficulty = 4.85 where slug = 'downhill-running' and category_id = (select id from public.categories where slug = 'running');
update public.skills set learning_order = 27, subskill_difficulty = 5.00 where slug = 'trail-running' and category_id = (select id from public.categories where slug = 'running');
update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'ball-mastery' and category_id = (select id from public.categories where slug = 'soccer');
update public.skills set learning_order = 2, subskill_difficulty = 1.20 where slug = 'juggling' and category_id = (select id from public.categories where slug = 'soccer');
update public.skills set learning_order = 3, subskill_difficulty = 1.40 where slug = 'first-touch' and category_id = (select id from public.categories where slug = 'soccer');
update public.skills set learning_order = 4, subskill_difficulty = 1.60 where slug = 'shielding-the-ball' and category_id = (select id from public.categories where slug = 'soccer');
update public.skills set learning_order = 5, subskill_difficulty = 1.80 where slug = 'heading' and category_id = (select id from public.categories where slug = 'soccer');
update public.skills set learning_order = 6, subskill_difficulty = 2.00 where slug = 'passing-technique' and category_id = (select id from public.categories where slug = 'soccer');
update public.skills set learning_order = 7, subskill_difficulty = 2.20 where slug = 'long-passing' and category_id = (select id from public.categories where slug = 'soccer');
update public.skills set learning_order = 8, subskill_difficulty = 2.40 where slug = 'crossing' and category_id = (select id from public.categories where slug = 'soccer');
update public.skills set learning_order = 9, subskill_difficulty = 2.60 where slug = 'weak-foot-development' and category_id = (select id from public.categories where slug = 'soccer');
update public.skills set learning_order = 10, subskill_difficulty = 2.80 where slug = 'dribbling-close-control' and category_id = (select id from public.categories where slug = 'soccer');
update public.skills set learning_order = 11, subskill_difficulty = 3.00 where slug = 'off-the-ball-movement' and category_id = (select id from public.categories where slug = 'soccer');
update public.skills set learning_order = 12, subskill_difficulty = 3.20 where slug = 'turning-with-the-ball' and category_id = (select id from public.categories where slug = 'soccer');
update public.skills set learning_order = 13, subskill_difficulty = 3.40 where slug = 'step-overs' and category_id = (select id from public.categories where slug = 'soccer');
update public.skills set learning_order = 14, subskill_difficulty = 3.60 where slug = 'la-croqueta' and category_id = (select id from public.categories where slug = 'soccer');
update public.skills set learning_order = 15, subskill_difficulty = 3.80 where slug = '1v1-moves' and category_id = (select id from public.categories where slug = 'soccer');
update public.skills set learning_order = 16, subskill_difficulty = 4.00 where slug = 'defending-1v1' and category_id = (select id from public.categories where slug = 'soccer');
update public.skills set learning_order = 17, subskill_difficulty = 4.20 where slug = 'how-to-tackle' and category_id = (select id from public.categories where slug = 'soccer');
update public.skills set learning_order = 18, subskill_difficulty = 4.40 where slug = 'finishing-shooting' and category_id = (select id from public.categories where slug = 'soccer');
update public.skills set learning_order = 19, subskill_difficulty = 4.60 where slug = 'volley-technique' and category_id = (select id from public.categories where slug = 'soccer');
update public.skills set learning_order = 20, subskill_difficulty = 4.80 where slug = 'free-kick-technique' and category_id = (select id from public.categories where slug = 'soccer');
update public.skills set learning_order = 21, subskill_difficulty = 5.00 where slug = 'penalty-technique' and category_id = (select id from public.categories where slug = 'soccer');
update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'surf-etiquette' and category_id = (select id from public.categories where slug = 'surfing');
update public.skills set learning_order = 2, subskill_difficulty = 1.17 where slug = 'rip-currents' and category_id = (select id from public.categories where slug = 'surfing');
update public.skills set learning_order = 3, subskill_difficulty = 1.35 where slug = 'board-choice' and category_id = (select id from public.categories where slug = 'surfing');
update public.skills set learning_order = 4, subskill_difficulty = 1.52 where slug = 'ding-repair' and category_id = (select id from public.categories where slug = 'surfing');
update public.skills set learning_order = 5, subskill_difficulty = 1.70 where slug = 'waxing-a-surfboard' and category_id = (select id from public.categories where slug = 'surfing');
update public.skills set learning_order = 6, subskill_difficulty = 1.87 where slug = 'surf-stance' and category_id = (select id from public.categories where slug = 'surfing');
update public.skills set learning_order = 7, subskill_difficulty = 2.04 where slug = 'paddling-technique' and category_id = (select id from public.categories where slug = 'surfing');
update public.skills set learning_order = 8, subskill_difficulty = 2.22 where slug = 'paddling-out' and category_id = (select id from public.categories where slug = 'surfing');
update public.skills set learning_order = 9, subskill_difficulty = 2.39 where slug = 'turtle-roll' and category_id = (select id from public.categories where slug = 'surfing');
update public.skills set learning_order = 10, subskill_difficulty = 2.57 where slug = 'pop-up' and category_id = (select id from public.categories where slug = 'surfing');
update public.skills set learning_order = 11, subskill_difficulty = 2.74 where slug = 'falling-off-safely' and category_id = (select id from public.categories where slug = 'surfing');
update public.skills set learning_order = 12, subskill_difficulty = 2.91 where slug = 'lineup-positioning' and category_id = (select id from public.categories where slug = 'surfing');
update public.skills set learning_order = 13, subskill_difficulty = 3.09 where slug = 'wave-selection' and category_id = (select id from public.categories where slug = 'surfing');
update public.skills set learning_order = 14, subskill_difficulty = 3.26 where slug = 'surf-forecast' and category_id = (select id from public.categories where slug = 'surfing');
update public.skills set learning_order = 15, subskill_difficulty = 3.43 where slug = 'takeoff-timing' and category_id = (select id from public.categories where slug = 'surfing');
update public.skills set learning_order = 16, subskill_difficulty = 3.61 where slug = 'catching-a-green-wave' and category_id = (select id from public.categories where slug = 'surfing');
update public.skills set learning_order = 17, subskill_difficulty = 3.78 where slug = 'trimming' and category_id = (select id from public.categories where slug = 'surfing');
update public.skills set learning_order = 18, subskill_difficulty = 3.96 where slug = 'generating-speed' and category_id = (select id from public.categories where slug = 'surfing');
update public.skills set learning_order = 19, subskill_difficulty = 4.13 where slug = 'duck-dive' and category_id = (select id from public.categories where slug = 'surfing');
update public.skills set learning_order = 20, subskill_difficulty = 4.30 where slug = 'bottom-turn' and category_id = (select id from public.categories where slug = 'surfing');
update public.skills set learning_order = 21, subskill_difficulty = 4.48 where slug = 'top-turn' and category_id = (select id from public.categories where slug = 'surfing');
update public.skills set learning_order = 22, subskill_difficulty = 4.65 where slug = 'floater' and category_id = (select id from public.categories where slug = 'surfing');
update public.skills set learning_order = 23, subskill_difficulty = 4.83 where slug = 'cutback' and category_id = (select id from public.categories where slug = 'surfing');
update public.skills set learning_order = 24, subskill_difficulty = 5.00 where slug = 'cross-stepping' and category_id = (select id from public.categories where slug = 'surfing');
update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'breath-control' and category_id = (select id from public.categories where slug = 'swimming');
update public.skills set learning_order = 2, subskill_difficulty = 1.19 where slug = 'floating' and category_id = (select id from public.categories where slug = 'swimming');
update public.skills set learning_order = 3, subskill_difficulty = 1.38 where slug = 'treading-water' and category_id = (select id from public.categories where slug = 'swimming');
update public.skills set learning_order = 4, subskill_difficulty = 1.57 where slug = 'streamline-pushoff' and category_id = (select id from public.categories where slug = 'swimming');
update public.skills set learning_order = 5, subskill_difficulty = 1.76 where slug = 'freestyle-kick' and category_id = (select id from public.categories where slug = 'swimming');
update public.skills set learning_order = 6, subskill_difficulty = 1.95 where slug = 'body-rotation' and category_id = (select id from public.categories where slug = 'swimming');
update public.skills set learning_order = 7, subskill_difficulty = 2.14 where slug = 'freestyle-catch' and category_id = (select id from public.categories where slug = 'swimming');
update public.skills set learning_order = 8, subskill_difficulty = 2.33 where slug = 'bilateral-breathing' and category_id = (select id from public.categories where slug = 'swimming');
update public.skills set learning_order = 9, subskill_difficulty = 2.52 where slug = 'swimming-without-getting-tired' and category_id = (select id from public.categories where slug = 'swimming');
update public.skills set learning_order = 10, subskill_difficulty = 2.71 where slug = 'sculling-drills' and category_id = (select id from public.categories where slug = 'swimming');
update public.skills set learning_order = 11, subskill_difficulty = 2.90 where slug = 'backstroke-technique' and category_id = (select id from public.categories where slug = 'swimming');
update public.skills set learning_order = 12, subskill_difficulty = 3.10 where slug = 'backstroke-kick' and category_id = (select id from public.categories where slug = 'swimming');
update public.skills set learning_order = 13, subskill_difficulty = 3.29 where slug = 'breaststroke-timing' and category_id = (select id from public.categories where slug = 'swimming');
update public.skills set learning_order = 14, subskill_difficulty = 3.48 where slug = 'breaststroke-kick' and category_id = (select id from public.categories where slug = 'swimming');
update public.skills set learning_order = 15, subskill_difficulty = 3.67 where slug = 'breaststroke-pull' and category_id = (select id from public.categories where slug = 'swimming');
update public.skills set learning_order = 16, subskill_difficulty = 3.86 where slug = 'open-turn' and category_id = (select id from public.categories where slug = 'swimming');
update public.skills set learning_order = 17, subskill_difficulty = 4.05 where slug = 'flip-turn' and category_id = (select id from public.categories where slug = 'swimming');
update public.skills set learning_order = 18, subskill_difficulty = 4.24 where slug = 'racing-dive' and category_id = (select id from public.categories where slug = 'swimming');
update public.skills set learning_order = 19, subskill_difficulty = 4.43 where slug = 'butterfly-timing' and category_id = (select id from public.categories where slug = 'swimming');
update public.skills set learning_order = 20, subskill_difficulty = 4.62 where slug = 'butterfly-undulation' and category_id = (select id from public.categories where slug = 'swimming');
update public.skills set learning_order = 21, subskill_difficulty = 4.81 where slug = 'open-water-sighting' and category_id = (select id from public.categories where slug = 'swimming');
update public.skills set learning_order = 22, subskill_difficulty = 5.00 where slug = 'pull-buoy' and category_id = (select id from public.categories where slug = 'swimming');
update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'tennis-scoring' and category_id = (select id from public.categories where slug = 'tennis');
update public.skills set learning_order = 2, subskill_difficulty = 1.18 where slug = 'grip-fundamentals' and category_id = (select id from public.categories where slug = 'tennis');
update public.skills set learning_order = 3, subskill_difficulty = 1.36 where slug = 'footwork-split-step' and category_id = (select id from public.categories where slug = 'tennis');
update public.skills set learning_order = 4, subskill_difficulty = 1.55 where slug = 'forehand' and category_id = (select id from public.categories where slug = 'tennis');
update public.skills set learning_order = 5, subskill_difficulty = 1.73 where slug = 'two-handed-backhand' and category_id = (select id from public.categories where slug = 'tennis');
update public.skills set learning_order = 6, subskill_difficulty = 1.91 where slug = 'volley' and category_id = (select id from public.categories where slug = 'tennis');
update public.skills set learning_order = 7, subskill_difficulty = 2.09 where slug = 'approach-shot' and category_id = (select id from public.categories where slug = 'tennis');
update public.skills set learning_order = 8, subskill_difficulty = 2.27 where slug = 'half-volley' and category_id = (select id from public.categories where slug = 'tennis');
update public.skills set learning_order = 9, subskill_difficulty = 2.45 where slug = 'drop-shot' and category_id = (select id from public.categories where slug = 'tennis');
update public.skills set learning_order = 10, subskill_difficulty = 2.64 where slug = 'serve-technique' and category_id = (select id from public.categories where slug = 'tennis');
update public.skills set learning_order = 11, subskill_difficulty = 2.82 where slug = 'slice-serve' and category_id = (select id from public.categories where slug = 'tennis');
update public.skills set learning_order = 12, subskill_difficulty = 3.00 where slug = 'return-of-serve' and category_id = (select id from public.categories where slug = 'tennis');
update public.skills set learning_order = 13, subskill_difficulty = 3.18 where slug = 'slice-backhand' and category_id = (select id from public.categories where slug = 'tennis');
update public.skills set learning_order = 14, subskill_difficulty = 3.36 where slug = 'topspin' and category_id = (select id from public.categories where slug = 'tennis');
update public.skills set learning_order = 15, subskill_difficulty = 3.55 where slug = 'singles-strategy' and category_id = (select id from public.categories where slug = 'tennis');
update public.skills set learning_order = 16, subskill_difficulty = 3.73 where slug = 'doubles-strategy' and category_id = (select id from public.categories where slug = 'tennis');
update public.skills set learning_order = 17, subskill_difficulty = 3.91 where slug = 'kick-serve' and category_id = (select id from public.categories where slug = 'tennis');
update public.skills set learning_order = 18, subskill_difficulty = 4.09 where slug = 'second-serve' and category_id = (select id from public.categories where slug = 'tennis');
update public.skills set learning_order = 19, subskill_difficulty = 4.27 where slug = 'overhead-smash' and category_id = (select id from public.categories where slug = 'tennis');
update public.skills set learning_order = 20, subskill_difficulty = 4.45 where slug = 'lob' and category_id = (select id from public.categories where slug = 'tennis');
update public.skills set learning_order = 21, subskill_difficulty = 4.64 where slug = 'one-handed-backhand' and category_id = (select id from public.categories where slug = 'tennis');
update public.skills set learning_order = 22, subskill_difficulty = 4.82 where slug = 'tennis-elbow' and category_id = (select id from public.categories where slug = 'tennis');
update public.skills set learning_order = 23, subskill_difficulty = 5.00 where slug = 'choosing-a-tennis-racket' and category_id = (select id from public.categories where slug = 'tennis');
update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'yoga-for-beginners' and category_id = (select id from public.categories where slug = 'yoga');
update public.skills set learning_order = 2, subskill_difficulty = 1.19 where slug = 'pranayama-breathing' and category_id = (select id from public.categories where slug = 'yoga');
update public.skills set learning_order = 3, subskill_difficulty = 1.38 where slug = 'tree-pose-balance' and category_id = (select id from public.categories where slug = 'yoga');
update public.skills set learning_order = 4, subskill_difficulty = 1.57 where slug = 'downward-dog' and category_id = (select id from public.categories where slug = 'yoga');
update public.skills set learning_order = 5, subskill_difficulty = 1.76 where slug = 'sun-salutation' and category_id = (select id from public.categories where slug = 'yoga');
update public.skills set learning_order = 6, subskill_difficulty = 1.95 where slug = 'seated-forward-fold' and category_id = (select id from public.categories where slug = 'yoga');
update public.skills set learning_order = 7, subskill_difficulty = 2.14 where slug = 'seated-spinal-twist' and category_id = (select id from public.categories where slug = 'yoga');
update public.skills set learning_order = 8, subskill_difficulty = 2.33 where slug = 'warrior-poses' and category_id = (select id from public.categories where slug = 'yoga');
update public.skills set learning_order = 9, subskill_difficulty = 2.52 where slug = 'triangle-pose' and category_id = (select id from public.categories where slug = 'yoga');
update public.skills set learning_order = 10, subskill_difficulty = 2.71 where slug = 'hip-openers' and category_id = (select id from public.categories where slug = 'yoga');
update public.skills set learning_order = 11, subskill_difficulty = 2.90 where slug = 'splits' and category_id = (select id from public.categories where slug = 'yoga');
update public.skills set learning_order = 12, subskill_difficulty = 3.10 where slug = 'yin-yoga' and category_id = (select id from public.categories where slug = 'yoga');
update public.skills set learning_order = 13, subskill_difficulty = 3.29 where slug = 'restorative-yoga' and category_id = (select id from public.categories where slug = 'yoga');
update public.skills set learning_order = 14, subskill_difficulty = 3.48 where slug = 'yoga-for-back-pain' and category_id = (select id from public.categories where slug = 'yoga');
update public.skills set learning_order = 15, subskill_difficulty = 3.67 where slug = 'bridge-wheel-backbend' and category_id = (select id from public.categories where slug = 'yoga');
update public.skills set learning_order = 16, subskill_difficulty = 3.86 where slug = 'camel-pose' and category_id = (select id from public.categories where slug = 'yoga');
update public.skills set learning_order = 17, subskill_difficulty = 4.05 where slug = 'shoulderstand' and category_id = (select id from public.categories where slug = 'yoga');
update public.skills set learning_order = 18, subskill_difficulty = 4.24 where slug = 'chaturanga' and category_id = (select id from public.categories where slug = 'yoga');
update public.skills set learning_order = 19, subskill_difficulty = 4.43 where slug = 'crow-pose' and category_id = (select id from public.categories where slug = 'yoga');
update public.skills set learning_order = 20, subskill_difficulty = 4.62 where slug = 'headstand' and category_id = (select id from public.categories where slug = 'yoga');
update public.skills set learning_order = 21, subskill_difficulty = 4.81 where slug = 'forearm-stand' and category_id = (select id from public.categories where slug = 'yoga');
update public.skills set learning_order = 22, subskill_difficulty = 5.00 where slug = 'handstand' and category_id = (select id from public.categories where slug = 'yoga');

commit;
