-- 0043: new categories — Golf, Table tennis, Climbing, Pickleball, Skiing,
-- Snowboarding, Brazilian jiu-jitsu (7 categories, 160 sub-skills).
--
-- Source: docs/new-category-research-2026-08.md (which categories) and
-- docs/new-category-subskills-2026-08.md (which sub-skills, with per-name
-- tutorial-supply evidence).
--
-- Categories are inserted is_active = FALSE on purpose. Two facts make this the
-- right sequencing:
--   * apps/web/lib/data.ts getCategories() filters on is_active, so an empty
--     category never renders on the site.
--   * scripts/run-collection.mjs's skill rotation filters `s.is_active` only --
--     it joins categories but does NOT filter c.is_active -- so the collector
--     picks these up and fills them while they are still hidden.
-- Flip a category to is_active = true once its sub-skills clear the 3-published
-- threshold (getPublishMinResources) that makes them visible.
--
-- NAMES ARE RETRIEVAL KEYS. run-collection.mjs builds YouTube queries from
-- skill.name, so every name below was probed through `yt-dlp ytsearch` and kept
-- only if it retrieved dedicated single-topic tutorials. Names that failed were
-- renamed (Ready stance -> Ready position, Smash -> Forehand smash) or dropped
-- (Wedge christie, open-hand grip, snowboard skating, pickleball drop shot).
--
-- learning_order and subskill_difficulty run 1.00 -> 5.00 in pedagogical order.
begin;

insert into public.categories (slug, name, description, is_active) values
  ('golf', 'Golf', 'Instructional content teaching golf technique: full swing, short game, putting, fault fixing, course strategy and equipment. Scoped to teachable skills, not tournament coverage or vlogs.', false),
  ('table-tennis', 'Table tennis', 'Instructional content on table tennis strokes, spin, serves, footwork and equipment. Scoped to teachable technique, not match footage or highlight reels.', false),
  ('climbing', 'Climbing', 'Instructional content on indoor and sport climbing: movement technique, grips, rope skills and training. Scoped to teachable skills, not send videos or expedition films.', false),
  ('pickleball', 'Pickleball', 'Instructional content on pickleball shots, positioning and strategy. Scoped to teachable technique, not tournament coverage or highlight compilations.', false),
  ('skiing', 'Skiing', 'Instructional content on alpine ski technique, terrain skills, equipment and safety. Scoped to teachable skills, not edits, vlogs or race coverage.', false),
  ('snowboarding', 'Snowboarding', 'Instructional content on snowboard riding technique, park skills, equipment and safety. Scoped to teachable skills, not edits or vlogs.', false),
  ('bjj', 'Brazilian jiu-jitsu', 'Instructional content on BJJ positions, escapes, sweeps, submissions and passing. Scoped to teachable technique, not competition footage or highlights.', false)
on conflict (slug) do nothing;

-- ---- Golf: 24 sub-skills -------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where slug = 'golf'), 'golf-grip', 'Golf grip', 'Build a neutral grip and understand strong and weak hand positions.', true),
  ((select id from public.categories where slug = 'golf'), 'setup-and-posture', 'Setup and posture', 'Set spine angle, ball position, stance width and alignment before every shot.', true),
  ((select id from public.categories where slug = 'golf'), 'golf-swing-basics', 'Golf swing basics', 'Learn the takeaway, backswing, transition and follow-through as one motion.', true),
  ((select id from public.categories where slug = 'golf'), 'how-to-stop-slicing', 'How to stop slicing', 'Diagnose an open face and out-to-in path, and fix the ball flight.', true),
  ((select id from public.categories where slug = 'golf'), 'how-to-stop-hooking', 'How to stop hooking', 'Fix a closed face and in-to-out path that sends the ball left.', true),
  ((select id from public.categories where slug = 'golf'), 'iron-shots', 'Iron shots', 'Strike irons ball-first with a descending blow and consistent low point.', true),
  ((select id from public.categories where slug = 'golf'), 'how-to-hit-a-driver', 'How to hit a driver', 'Tee height, ball position and upward attack angle for longer drives.', true),
  ((select id from public.categories where slug = 'golf'), 'fairway-woods', 'Fairway woods', 'Sweep fairway woods and hybrids cleanly off the turf.', true),
  ((select id from public.categories where slug = 'golf'), 'chipping', 'Chipping', 'Control low running shots around the green with a stable, simple motion.', true),
  ((select id from public.categories where slug = 'golf'), 'pitching', 'Pitching', 'Hit higher, softer shots from 30 to 60 yards with a controlled length of swing.', true),
  ((select id from public.categories where slug = 'golf'), 'bunker-shots', 'Bunker shots', 'Use bounce and a shallow sand entry to escape greenside bunkers.', true),
  ((select id from public.categories where slug = 'golf'), 'wedge-distance-control', 'Wedge distance control', 'Dial in partial wedge yardages with clock-face swing lengths.', true),
  ((select id from public.categories where slug = 'golf'), 'punch-shot', 'Punch shot', 'Play a low, controlled shot from trouble or into the wind.', true),
  ((select id from public.categories where slug = 'golf'), 'how-to-hit-a-draw', 'How to hit a draw', 'Shape the ball right-to-left by matching face and path.', true),
  ((select id from public.categories where slug = 'golf'), 'uneven-lies', 'Uneven lies', 'Adjust setup and swing for uphill, downhill and sidehill lies.', true),
  ((select id from public.categories where slug = 'golf'), 'putting-stroke', 'Putting stroke', 'Build a repeatable stroke with steady tempo, face control and solid contact.', true),
  ((select id from public.categories where slug = 'golf'), 'reading-greens', 'Reading greens', 'Read slope, grain and speed to pick a start line and pace.', true),
  ((select id from public.categories where slug = 'golf'), 'course-management', 'Course management', 'Pick targets and clubs that lower your score instead of chasing hero shots.', true),
  ((select id from public.categories where slug = 'golf'), 'golf-rules-for-beginners', 'Golf rules for beginners', 'Learn the rules that actually come up: penalties, drops, out of bounds and scoring.', true),
  ((select id from public.categories where slug = 'golf'), 'golf-etiquette', 'Golf etiquette', 'Pace of play, safety, bunker raking and green care on the course.', true),
  ((select id from public.categories where slug = 'golf'), 'how-to-choose-golf-clubs', 'How to choose golf clubs', 'Pick a starter set and understand shafts, lofts and what each club is for.', true),
  ((select id from public.categories where slug = 'golf'), 'driving-range-practice', 'Driving range practice', 'Structure range sessions so practice transfers to the course.', true),
  ((select id from public.categories where slug = 'golf'), 'golf-warm-up', 'Golf warm up', 'Prepare the body and swing in a short pre-round routine.', true),
  ((select id from public.categories where slug = 'golf'), 'golf-mental-game', 'Golf mental game', 'Manage nerves, pre-shot routine and recovery after a bad hole.', true)
on conflict (category_id, slug) do nothing;

update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'golf-grip' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 2, subskill_difficulty = 1.17 where slug = 'setup-and-posture' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 3, subskill_difficulty = 1.35 where slug = 'golf-swing-basics' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 4, subskill_difficulty = 1.52 where slug = 'how-to-stop-slicing' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 5, subskill_difficulty = 1.70 where slug = 'how-to-stop-hooking' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 6, subskill_difficulty = 1.87 where slug = 'iron-shots' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 7, subskill_difficulty = 2.04 where slug = 'how-to-hit-a-driver' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 8, subskill_difficulty = 2.22 where slug = 'fairway-woods' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 9, subskill_difficulty = 2.39 where slug = 'chipping' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 10, subskill_difficulty = 2.57 where slug = 'pitching' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 11, subskill_difficulty = 2.74 where slug = 'bunker-shots' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 12, subskill_difficulty = 2.91 where slug = 'wedge-distance-control' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 13, subskill_difficulty = 3.09 where slug = 'punch-shot' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 14, subskill_difficulty = 3.26 where slug = 'how-to-hit-a-draw' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 15, subskill_difficulty = 3.43 where slug = 'uneven-lies' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 16, subskill_difficulty = 3.61 where slug = 'putting-stroke' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 17, subskill_difficulty = 3.78 where slug = 'reading-greens' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 18, subskill_difficulty = 3.96 where slug = 'course-management' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 19, subskill_difficulty = 4.13 where slug = 'golf-rules-for-beginners' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 20, subskill_difficulty = 4.30 where slug = 'golf-etiquette' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 21, subskill_difficulty = 4.48 where slug = 'how-to-choose-golf-clubs' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 22, subskill_difficulty = 4.65 where slug = 'driving-range-practice' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 23, subskill_difficulty = 4.83 where slug = 'golf-warm-up' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 24, subskill_difficulty = 5.00 where slug = 'golf-mental-game' and category_id = (select id from public.categories where slug = 'golf');

-- ---- Table tennis: 22 sub-skills -------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where slug = 'table-tennis'), 'shakehand-grip', 'Shakehand grip', 'Hold the bat the way most players do, with a neutral wrist and free fingers.', true),
  ((select id from public.categories where slug = 'table-tennis'), 'penhold-grip', 'Penhold grip', 'Hold and play with the penhold grip, including reverse backhand.', true),
  ((select id from public.categories where slug = 'table-tennis'), 'ready-position', 'Ready position', 'Stand balanced and low so you can move to either wing.', true),
  ((select id from public.categories where slug = 'table-tennis'), 'forehand-drive', 'Forehand drive', 'Build the basic forehand drive with body rotation and a compact swing.', true),
  ((select id from public.categories where slug = 'table-tennis'), 'backhand-drive', 'Backhand drive', 'Play a controlled backhand drive from in front of the body.', true),
  ((select id from public.categories where slug = 'table-tennis'), 'forehand-push', 'Forehand push', 'Return short backspin balls with a controlled forehand push.', true),
  ((select id from public.categories where slug = 'table-tennis'), 'backhand-push', 'Backhand push', 'Keep the ball low and short with a backhand push.', true),
  ((select id from public.categories where slug = 'table-tennis'), 'block', 'Block', 'Absorb an opponent''s topspin with a passive or active block.', true),
  ((select id from public.categories where slug = 'table-tennis'), 'forehand-topspin', 'Forehand topspin', 'Brush up the back of the ball for heavy forehand topspin.', true),
  ((select id from public.categories where slug = 'table-tennis'), 'backhand-topspin', 'Backhand topspin', 'Generate backhand topspin using forearm and wrist snap.', true),
  ((select id from public.categories where slug = 'table-tennis'), 'looping-against-backspin', 'Looping against backspin', 'Open up on heavy backspin with a low-to-high loop.', true),
  ((select id from public.categories where slug = 'table-tennis'), 'backhand-flick', 'Backhand flick', 'Attack short balls over the table with a backhand flick.', true),
  ((select id from public.categories where slug = 'table-tennis'), 'forehand-smash', 'Forehand smash', 'Finish high balls with a flat, powerful smash.', true),
  ((select id from public.categories where slug = 'table-tennis'), 'chopping', 'Chopping', 'Play defensive chops from away from the table with heavy backspin.', true),
  ((select id from public.categories where slug = 'table-tennis'), 'topspin-serve', 'Topspin serve', 'Serve fast topspin to force a weak return.', true),
  ((select id from public.categories where slug = 'table-tennis'), 'backspin-serve', 'Backspin serve', 'Serve short and heavy so the ball stays low.', true),
  ((select id from public.categories where slug = 'table-tennis'), 'sidespin-serve', 'Sidespin serve', 'Add sidespin to pull the returner off the table.', true),
  ((select id from public.categories where slug = 'table-tennis'), 'serve-return', 'Serve return', 'Read the serve and choose push, flick or loop as the return.', true),
  ((select id from public.categories where slug = 'table-tennis'), 'reading-spin', 'Reading spin', 'Judge spin from contact, bat angle and ball flight.', true),
  ((select id from public.categories where slug = 'table-tennis'), 'table-tennis-footwork', 'Table tennis footwork', 'Move with side-to-side and in-and-out steps instead of reaching.', true),
  ((select id from public.categories where slug = 'table-tennis'), 'choosing-a-blade-and-rubber', 'Choosing a blade and rubber', 'Match blade speed and rubber type to your style and level.', true),
  ((select id from public.categories where slug = 'table-tennis'), 'doubles-rules-and-rotation', 'Doubles rules and rotation', 'Serve, receive and rotate correctly in doubles.', true)
on conflict (category_id, slug) do nothing;

update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'shakehand-grip' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 2, subskill_difficulty = 1.19 where slug = 'penhold-grip' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 3, subskill_difficulty = 1.38 where slug = 'ready-position' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 4, subskill_difficulty = 1.57 where slug = 'forehand-drive' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 5, subskill_difficulty = 1.76 where slug = 'backhand-drive' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 6, subskill_difficulty = 1.95 where slug = 'forehand-push' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 7, subskill_difficulty = 2.14 where slug = 'backhand-push' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 8, subskill_difficulty = 2.33 where slug = 'block' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 9, subskill_difficulty = 2.52 where slug = 'forehand-topspin' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 10, subskill_difficulty = 2.71 where slug = 'backhand-topspin' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 11, subskill_difficulty = 2.90 where slug = 'looping-against-backspin' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 12, subskill_difficulty = 3.10 where slug = 'backhand-flick' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 13, subskill_difficulty = 3.29 where slug = 'forehand-smash' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 14, subskill_difficulty = 3.48 where slug = 'chopping' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 15, subskill_difficulty = 3.67 where slug = 'topspin-serve' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 16, subskill_difficulty = 3.86 where slug = 'backspin-serve' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 17, subskill_difficulty = 4.05 where slug = 'sidespin-serve' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 18, subskill_difficulty = 4.24 where slug = 'serve-return' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 19, subskill_difficulty = 4.43 where slug = 'reading-spin' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 20, subskill_difficulty = 4.62 where slug = 'table-tennis-footwork' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 21, subskill_difficulty = 4.81 where slug = 'choosing-a-blade-and-rubber' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 22, subskill_difficulty = 5.00 where slug = 'doubles-rules-and-rotation' and category_id = (select id from public.categories where slug = 'table-tennis');

-- ---- Climbing: 22 sub-skills -------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where slug = 'climbing'), 'bouldering-for-beginners', 'Bouldering for beginners', 'What to expect, how to start and the habits that matter on your first sessions.', true),
  ((select id from public.categories where slug = 'climbing'), 'choosing-climbing-shoes', 'Choosing climbing shoes', 'Pick fit, shape and stiffness for your level and the climbing you do.', true),
  ((select id from public.categories where slug = 'climbing'), 'how-to-tie-in-figure-8', 'How to tie in (figure 8)', 'Tie a figure-8 follow-through into the harness and check it.', true),
  ((select id from public.categories where slug = 'climbing'), 'belaying', 'Belaying', 'Belay on top rope with correct hand position and rope management.', true),
  ((select id from public.categories where slug = 'climbing'), 'lead-belaying', 'Lead belaying', 'Manage slack, catch lead falls and give a soft catch.', true),
  ((select id from public.categories where slug = 'climbing'), 'clipping-quickdraws', 'Clipping quickdraws', 'Clip efficiently and avoid back-clipping and Z-clipping.', true),
  ((select id from public.categories where slug = 'climbing'), 'how-to-fall-safely', 'How to fall safely', 'Fall and land safely when bouldering and on lead.', true),
  ((select id from public.categories where slug = 'climbing'), 'climbing-footwork', 'Climbing footwork', 'Place feet precisely and trust them instead of pulling with the arms.', true),
  ((select id from public.categories where slug = 'climbing'), 'flagging', 'Flagging', 'Use a free leg as a counterweight to stop barn-dooring.', true),
  ((select id from public.categories where slug = 'climbing'), 'heel-hook', 'Heel hook', 'Load a heel to take weight off the arms and unlock moves.', true),
  ((select id from public.categories where slug = 'climbing'), 'toe-hook', 'Toe hook', 'Pull with the top of the foot to hold body tension on overhangs.', true),
  ((select id from public.categories where slug = 'climbing'), 'crimp-grip', 'Crimp grip', 'Use half and full crimp safely, and know when to open-hand instead.', true),
  ((select id from public.categories where slug = 'climbing'), 'drop-knee', 'Drop knee', 'Turn the hip in to lower the centre of gravity and extend reach.', true),
  ((select id from public.categories where slug = 'climbing'), 'dyno', 'Dyno', 'Generate and commit to a dynamic move, and stick the catch.', true),
  ((select id from public.categories where slug = 'climbing'), 'mantle', 'Mantle', 'Press over a lip or ledge to top out a boulder.', true),
  ((select id from public.categories where slug = 'climbing'), 'slab-climbing', 'Slab climbing', 'Balance and smear on low-angle rock where footwork is everything.', true),
  ((select id from public.categories where slug = 'climbing'), 'overhangs-and-body-tension', 'Overhangs and body tension', 'Keep hips in and core engaged so feet stay on steep walls.', true),
  ((select id from public.categories where slug = 'climbing'), 'resting-on-the-wall', 'Resting on the wall', 'Find and use rests to recover and control the pump.', true),
  ((select id from public.categories where slug = 'climbing'), 'reading-routes', 'Reading routes', 'Work out sequences from the ground before you leave it.', true),
  ((select id from public.categories where slug = 'climbing'), 'climbing-grades-explained', 'Climbing grades explained', 'Understand V-scale, Font, YDS and French grades and how they compare.', true),
  ((select id from public.categories where slug = 'climbing'), 'hangboard-training', 'Hangboard training', 'Start finger strength training safely with sensible loading.', true),
  ((select id from public.categories where slug = 'climbing'), 'climbing-warm-up', 'Climbing warm up', 'Warm fingers, shoulders and hips before hard climbing.', true)
on conflict (category_id, slug) do nothing;

update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'bouldering-for-beginners' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 2, subskill_difficulty = 1.19 where slug = 'choosing-climbing-shoes' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 3, subskill_difficulty = 1.38 where slug = 'how-to-tie-in-figure-8' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 4, subskill_difficulty = 1.57 where slug = 'belaying' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 5, subskill_difficulty = 1.76 where slug = 'lead-belaying' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 6, subskill_difficulty = 1.95 where slug = 'clipping-quickdraws' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 7, subskill_difficulty = 2.14 where slug = 'how-to-fall-safely' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 8, subskill_difficulty = 2.33 where slug = 'climbing-footwork' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 9, subskill_difficulty = 2.52 where slug = 'flagging' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 10, subskill_difficulty = 2.71 where slug = 'heel-hook' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 11, subskill_difficulty = 2.90 where slug = 'toe-hook' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 12, subskill_difficulty = 3.10 where slug = 'crimp-grip' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 13, subskill_difficulty = 3.29 where slug = 'drop-knee' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 14, subskill_difficulty = 3.48 where slug = 'dyno' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 15, subskill_difficulty = 3.67 where slug = 'mantle' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 16, subskill_difficulty = 3.86 where slug = 'slab-climbing' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 17, subskill_difficulty = 4.05 where slug = 'overhangs-and-body-tension' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 18, subskill_difficulty = 4.24 where slug = 'resting-on-the-wall' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 19, subskill_difficulty = 4.43 where slug = 'reading-routes' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 20, subskill_difficulty = 4.62 where slug = 'climbing-grades-explained' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 21, subskill_difficulty = 4.81 where slug = 'hangboard-training' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 22, subskill_difficulty = 5.00 where slug = 'climbing-warm-up' and category_id = (select id from public.categories where slug = 'climbing');

-- ---- Pickleball: 19 sub-skills -------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where slug = 'pickleball'), 'pickleball-rules', 'Pickleball rules', 'Scoring, serving rules, faults and how a game is actually played.', true),
  ((select id from public.categories where slug = 'pickleball'), 'kitchen-rules', 'Kitchen rules', 'The non-volley zone rules that new players get wrong most often.', true),
  ((select id from public.categories where slug = 'pickleball'), 'pickleball-serve', 'Pickleball serve', 'Build a deep, consistent, legal serve.', true),
  ((select id from public.categories where slug = 'pickleball'), 'return-of-serve', 'Return of serve', 'Return deep and get to the kitchen line.', true),
  ((select id from public.categories where slug = 'pickleball'), 'dink', 'Dink', 'Control soft shots into the kitchen without popping them up.', true),
  ((select id from public.categories where slug = 'pickleball'), 'third-shot-drop', 'Third shot drop', 'Drop the third shot softly into the kitchen to take the net.', true),
  ((select id from public.categories where slug = 'pickleball'), 'third-shot-drive', 'Third shot drive', 'Drive the third shot hard when the drop is not on.', true),
  ((select id from public.categories where slug = 'pickleball'), 'reset', 'Reset', 'Absorb pace and reset the ball into the kitchen under pressure.', true),
  ((select id from public.categories where slug = 'pickleball'), 'pickleball-volley', 'Pickleball volley', 'Punch clean volleys at the net with a stable paddle face.', true),
  ((select id from public.categories where slug = 'pickleball'), 'pickleball-backhand', 'Pickleball backhand', 'Build a reliable backhand for drives, dinks and blocks.', true),
  ((select id from public.categories where slug = 'pickleball'), 'overhead-smash', 'Overhead smash', 'Put away high balls without hitting them out.', true),
  ((select id from public.categories where slug = 'pickleball'), 'pickleball-lob', 'Pickleball lob', 'Use offensive and defensive lobs to move opponents off the line.', true),
  ((select id from public.categories where slug = 'pickleball'), 'erne', 'Erne', 'Jump around the kitchen to attack a wide ball.', true),
  ((select id from public.categories where slug = 'pickleball'), 'around-the-post', 'Around the post', 'Hit the ATP when the ball pulls you wide of the net post.', true),
  ((select id from public.categories where slug = 'pickleball'), 'pickleball-footwork', 'Pickleball footwork', 'Split step, move and recover instead of reaching.', true),
  ((select id from public.categories where slug = 'pickleball'), 'doubles-positioning', 'Doubles positioning', 'Move as a pair, cover the middle and hold the line.', true),
  ((select id from public.categories where slug = 'pickleball'), 'stacking', 'Stacking', 'Stack to keep both players on their stronger side.', true),
  ((select id from public.categories where slug = 'pickleball'), 'singles-strategy', 'Singles strategy', 'Build points and cover the court in singles.', true),
  ((select id from public.categories where slug = 'pickleball'), 'choosing-a-pickleball-paddle', 'Choosing a pickleball paddle', 'Pick weight, shape, core and face for your game.', true)
on conflict (category_id, slug) do nothing;

update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'pickleball-rules' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 2, subskill_difficulty = 1.22 where slug = 'kitchen-rules' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 3, subskill_difficulty = 1.44 where slug = 'pickleball-serve' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 4, subskill_difficulty = 1.67 where slug = 'return-of-serve' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 5, subskill_difficulty = 1.89 where slug = 'dink' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 6, subskill_difficulty = 2.11 where slug = 'third-shot-drop' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 7, subskill_difficulty = 2.33 where slug = 'third-shot-drive' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 8, subskill_difficulty = 2.56 where slug = 'reset' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 9, subskill_difficulty = 2.78 where slug = 'pickleball-volley' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 10, subskill_difficulty = 3.00 where slug = 'pickleball-backhand' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 11, subskill_difficulty = 3.22 where slug = 'overhead-smash' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 12, subskill_difficulty = 3.44 where slug = 'pickleball-lob' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 13, subskill_difficulty = 3.67 where slug = 'erne' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 14, subskill_difficulty = 3.89 where slug = 'around-the-post' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 15, subskill_difficulty = 4.11 where slug = 'pickleball-footwork' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 16, subskill_difficulty = 4.33 where slug = 'doubles-positioning' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 17, subskill_difficulty = 4.56 where slug = 'stacking' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 18, subskill_difficulty = 4.78 where slug = 'singles-strategy' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 19, subskill_difficulty = 5.00 where slug = 'choosing-a-pickleball-paddle' and category_id = (select id from public.categories where slug = 'pickleball');

-- ---- Skiing: 19 sub-skills -------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where slug = 'skiing'), 'how-to-ski-for-beginners', 'How to ski for beginners', 'Your first day: getting used to the skis, sliding and turning.', true),
  ((select id from public.categories where slug = 'skiing'), 'ski-stance-and-body-position', 'Ski stance and body position', 'Stack the body over the skis with balanced ankle, knee and hip flex.', true),
  ((select id from public.categories where slug = 'skiing'), 'how-to-stop-on-skis', 'How to stop on skis', 'Learn the snowplough stop and progress to a hockey stop.', true),
  ((select id from public.categories where slug = 'skiing'), 'snowplough-turns', 'Snowplough turns', 'Steer both skis to link your first turns in a wedge.', true),
  ((select id from public.categories where slug = 'skiing'), 'getting-up-after-a-fall', 'Getting up after a fall', 'Get back on your feet on a slope without exhausting yourself.', true),
  ((select id from public.categories where slug = 'skiing'), 'how-to-use-a-ski-lift', 'How to use a ski lift', 'Ride and get off chairlifts, button lifts and drag lifts.', true),
  ((select id from public.categories where slug = 'skiing'), 'parallel-turns', 'Parallel turns', 'Move from wedge to matched skis and link parallel turns.', true),
  ((select id from public.categories where slug = 'skiing'), 'carving-on-skis', 'Carving on skis', 'Tip the skis on edge and leave clean arcs instead of skidding.', true),
  ((select id from public.categories where slug = 'skiing'), 'short-turns', 'Short turns', 'Make quick, rhythmic turns on steeper and narrower terrain.', true),
  ((select id from public.categories where slug = 'skiing'), 'pole-plant', 'Pole plant', 'Time the pole plant to trigger and rhythm your turns.', true),
  ((select id from public.categories where slug = 'skiing'), 'skiing-moguls', 'Skiing moguls', 'Absorb and extend through bumps and pick a line.', true),
  ((select id from public.categories where slug = 'skiing'), 'skiing-powder', 'Skiing powder', 'Adjust stance and turn shape for deep snow.', true),
  ((select id from public.categories where slug = 'skiing'), 'skiing-steeps', 'Skiing steeps', 'Stay balanced and in control on steep pitches.', true),
  ((select id from public.categories where slug = 'skiing'), 'skiing-on-ice', 'Skiing on ice', 'Hold an edge and stay in control on hard, icy snow.', true),
  ((select id from public.categories where slug = 'skiing'), 'jumps-and-park-skiing', 'Jumps and park skiing', 'Take off, fly and land safely on park jumps.', true),
  ((select id from public.categories where slug = 'skiing'), 'ski-boot-fitting', 'Ski boot fitting', 'Get size, flex and fit right — the single biggest comfort and control factor.', true),
  ((select id from public.categories where slug = 'skiing'), 'how-to-choose-skis', 'How to choose skis', 'Pick length, width and type for the skiing you actually do.', true),
  ((select id from public.categories where slug = 'skiing'), 'avalanche-safety', 'Avalanche safety', 'Recognise avalanche terrain and know the basics of rescue.', true),
  ((select id from public.categories where slug = 'skiing'), 'ski-fitness-and-conditioning', 'Ski fitness and conditioning', 'Build the legs and core that keep you skiing all week.', true)
on conflict (category_id, slug) do nothing;

update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'how-to-ski-for-beginners' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 2, subskill_difficulty = 1.22 where slug = 'ski-stance-and-body-position' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 3, subskill_difficulty = 1.44 where slug = 'how-to-stop-on-skis' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 4, subskill_difficulty = 1.67 where slug = 'snowplough-turns' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 5, subskill_difficulty = 1.89 where slug = 'getting-up-after-a-fall' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 6, subskill_difficulty = 2.11 where slug = 'how-to-use-a-ski-lift' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 7, subskill_difficulty = 2.33 where slug = 'parallel-turns' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 8, subskill_difficulty = 2.56 where slug = 'carving-on-skis' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 9, subskill_difficulty = 2.78 where slug = 'short-turns' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 10, subskill_difficulty = 3.00 where slug = 'pole-plant' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 11, subskill_difficulty = 3.22 where slug = 'skiing-moguls' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 12, subskill_difficulty = 3.44 where slug = 'skiing-powder' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 13, subskill_difficulty = 3.67 where slug = 'skiing-steeps' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 14, subskill_difficulty = 3.89 where slug = 'skiing-on-ice' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 15, subskill_difficulty = 4.11 where slug = 'jumps-and-park-skiing' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 16, subskill_difficulty = 4.33 where slug = 'ski-boot-fitting' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 17, subskill_difficulty = 4.56 where slug = 'how-to-choose-skis' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 18, subskill_difficulty = 4.78 where slug = 'avalanche-safety' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 19, subskill_difficulty = 5.00 where slug = 'ski-fitness-and-conditioning' and category_id = (select id from public.categories where slug = 'skiing');

-- ---- Snowboarding: 18 sub-skills -------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where slug = 'snowboarding'), 'how-to-snowboard-for-beginners', 'How to snowboard for beginners', 'Your first day: strapping in, sliding and finding your edges.', true),
  ((select id from public.categories where slug = 'snowboarding'), 'snowboard-stance-and-binding-angles', 'Snowboard stance and binding angles', 'Set stance width, angles and highbacks for comfort and control.', true),
  ((select id from public.categories where slug = 'snowboarding'), 'how-to-stop-on-a-snowboard', 'How to stop on a snowboard', 'Stop reliably on heelside and toeside.', true),
  ((select id from public.categories where slug = 'snowboarding'), 'falling-leaf', 'Falling leaf', 'Slide down on one edge to build edge control and confidence.', true),
  ((select id from public.categories where slug = 'snowboarding'), 'heelside-turns', 'Heelside turns', 'Turn on the heel edge without washing out or jutting.', true),
  ((select id from public.categories where slug = 'snowboarding'), 'toeside-turns', 'Toeside turns', 'Commit to the toe edge and hold the turn.', true),
  ((select id from public.categories where slug = 'snowboarding'), 'linking-turns', 'Linking turns', 'Join heelside and toeside into smooth linked turns.', true),
  ((select id from public.categories where slug = 'snowboarding'), 'riding-the-chairlift', 'Riding the chairlift', 'Load, ride and unload a chairlift with one foot strapped in.', true),
  ((select id from public.categories where slug = 'snowboarding'), 'snowboard-carving', 'Snowboard carving', 'Ride on edge and leave a clean pencil line.', true),
  ((select id from public.categories where slug = 'snowboarding'), 'riding-switch', 'Riding switch', 'Ride and turn with your opposite foot forward.', true),
  ((select id from public.categories where slug = 'snowboarding'), 'ollie-on-a-snowboard', 'Ollie on a snowboard', 'Load the tail and pop off the snow.', true),
  ((select id from public.categories where slug = 'snowboarding'), 'butters', 'Butters', 'Press on the nose and tail and spin flat on the snow.', true),
  ((select id from public.categories where slug = 'snowboarding'), 'frontside-180', 'Frontside 180', 'Spin and land your first frontside 180.', true),
  ((select id from public.categories where slug = 'snowboarding'), 'park-jumps', 'Park jumps', 'Approach, pop and land park jumps safely.', true),
  ((select id from public.categories where slug = 'snowboarding'), 'boxes-and-rails', 'Boxes and rails', 'Get onto boxes and rails and slide them under control.', true),
  ((select id from public.categories where slug = 'snowboarding'), 'riding-powder', 'Riding powder', 'Keep the nose up and float through deep snow.', true),
  ((select id from public.categories where slug = 'snowboarding'), 'how-to-choose-a-snowboard', 'How to choose a snowboard', 'Pick length, shape, flex and camber profile for your riding.', true),
  ((select id from public.categories where slug = 'snowboarding'), 'avalanche-safety', 'Avalanche safety', 'Recognise avalanche terrain and know the basics of rescue.', true)
on conflict (category_id, slug) do nothing;

update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'how-to-snowboard-for-beginners' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 2, subskill_difficulty = 1.24 where slug = 'snowboard-stance-and-binding-angles' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 3, subskill_difficulty = 1.47 where slug = 'how-to-stop-on-a-snowboard' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 4, subskill_difficulty = 1.71 where slug = 'falling-leaf' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 5, subskill_difficulty = 1.94 where slug = 'heelside-turns' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 6, subskill_difficulty = 2.18 where slug = 'toeside-turns' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 7, subskill_difficulty = 2.41 where slug = 'linking-turns' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 8, subskill_difficulty = 2.65 where slug = 'riding-the-chairlift' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 9, subskill_difficulty = 2.88 where slug = 'snowboard-carving' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 10, subskill_difficulty = 3.12 where slug = 'riding-switch' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 11, subskill_difficulty = 3.35 where slug = 'ollie-on-a-snowboard' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 12, subskill_difficulty = 3.59 where slug = 'butters' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 13, subskill_difficulty = 3.82 where slug = 'frontside-180' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 14, subskill_difficulty = 4.06 where slug = 'park-jumps' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 15, subskill_difficulty = 4.29 where slug = 'boxes-and-rails' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 16, subskill_difficulty = 4.53 where slug = 'riding-powder' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 17, subskill_difficulty = 4.76 where slug = 'how-to-choose-a-snowboard' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 18, subskill_difficulty = 5.00 where slug = 'avalanche-safety' and category_id = (select id from public.categories where slug = 'snowboarding');

-- ---- Brazilian jiu-jitsu: 36 sub-skills -------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where slug = 'bjj'), 'bjj-for-beginners', 'BJJ for beginners', 'What happens in your first class, what to bring and how to survive it.', true),
  ((select id from public.categories where slug = 'bjj'), 'bjj-belt-system', 'BJJ belt system', 'How the belts and stripes work and what each level means.', true),
  ((select id from public.categories where slug = 'bjj'), 'breakfalls', 'Breakfalls', 'Land safely from throws and takedowns.', true),
  ((select id from public.categories where slug = 'bjj'), 'hip-escape-shrimp', 'Hip escape (shrimp)', 'The core movement for creating space and escaping bottom positions.', true),
  ((select id from public.categories where slug = 'bjj'), 'bridging', 'Bridging', 'Use the hips to lift and off-balance an opponent on top.', true),
  ((select id from public.categories where slug = 'bjj'), 'posture-and-base', 'Posture and base', 'Stay upright and heavy so you are hard to sweep or submit.', true),
  ((select id from public.categories where slug = 'bjj'), 'closed-guard', 'Closed guard', 'Control, break posture and attack from closed guard.', true),
  ((select id from public.categories where slug = 'bjj'), 'open-guard', 'Open guard', 'Use grips and frames to control distance in open guard.', true),
  ((select id from public.categories where slug = 'bjj'), 'half-guard', 'Half guard', 'Play and recover from half guard instead of getting flattened.', true),
  ((select id from public.categories where slug = 'bjj'), 'butterfly-guard', 'Butterfly guard', 'Elevate and off-balance with butterfly hooks.', true),
  ((select id from public.categories where slug = 'bjj'), 'de-la-riva-guard', 'De la Riva guard', 'Use the De la Riva hook to control and off-balance a standing opponent.', true),
  ((select id from public.categories where slug = 'bjj'), 'guard-retention', 'Guard retention', 'Stop your guard being passed with frames, hips and timing.', true),
  ((select id from public.categories where slug = 'bjj'), 'side-control', 'Side control', 'Hold and apply pressure from side control.', true),
  ((select id from public.categories where slug = 'bjj'), 'mount', 'Mount', 'Keep the mount and stop your opponent bucking you off.', true),
  ((select id from public.categories where slug = 'bjj'), 'back-control', 'Back control', 'Take and keep the back with hooks and seatbelt grip.', true),
  ((select id from public.categories where slug = 'bjj'), 'turtle-position', 'Turtle position', 'Attack and defend the turtle.', true),
  ((select id from public.categories where slug = 'bjj'), 'mount-escape', 'Mount escape', 'Escape the mount with the bridge-and-roll and elbow-knee escape.', true),
  ((select id from public.categories where slug = 'bjj'), 'side-control-escape', 'Side control escape', 'Frame, shrimp and recover guard from under side control.', true),
  ((select id from public.categories where slug = 'bjj'), 'back-escape', 'Back escape', 'Strip the hooks and escape back control before the choke.', true),
  ((select id from public.categories where slug = 'bjj'), 'scissor-sweep', 'Scissor sweep', 'The fundamental closed-guard sweep every white belt learns.', true),
  ((select id from public.categories where slug = 'bjj'), 'hip-bump-sweep', 'Hip bump sweep', 'Sit up and bump to reverse the position from guard.', true),
  ((select id from public.categories where slug = 'bjj'), 'butterfly-sweep', 'Butterfly sweep', 'Elevate and sweep with the butterfly hook.', true),
  ((select id from public.categories where slug = 'bjj'), 'armbar', 'Armbar', 'Attack the armbar from guard and mount.', true),
  ((select id from public.categories where slug = 'bjj'), 'triangle-choke', 'Triangle choke', 'Set up, lock and finish the triangle.', true),
  ((select id from public.categories where slug = 'bjj'), 'kimura', 'Kimura', 'Attack the kimura from guard, side control and half guard.', true),
  ((select id from public.categories where slug = 'bjj'), 'americana', 'Americana', 'Finish the americana shoulder lock from mount and side control.', true),
  ((select id from public.categories where slug = 'bjj'), 'rear-naked-choke', 'Rear naked choke', 'Finish the rear naked choke from back control.', true),
  ((select id from public.categories where slug = 'bjj'), 'guillotine-choke', 'Guillotine choke', 'Catch and finish the guillotine, high elbow and arm-in.', true),
  ((select id from public.categories where slug = 'bjj'), 'omoplata', 'Omoplata', 'Attack the shoulder lock with the legs from guard.', true),
  ((select id from public.categories where slug = 'bjj'), 'knee-cut-pass', 'Knee cut pass', 'Cut through the guard with a knee slice.', true),
  ((select id from public.categories where slug = 'bjj'), 'toreando-pass', 'Toreando pass', 'Pass by controlling the legs and moving around them.', true),
  ((select id from public.categories where slug = 'bjj'), 'leg-drag-pass', 'Leg drag pass', 'Drag the legs across to pass and take the back.', true),
  ((select id from public.categories where slug = 'bjj'), 'double-leg-takedown', 'Double leg takedown', 'Shoot, penetrate and finish the double leg.', true),
  ((select id from public.categories where slug = 'bjj'), 'single-leg-takedown', 'Single leg takedown', 'Take and finish the single leg.', true),
  ((select id from public.categories where slug = 'bjj'), 'gi-vs-no-gi', 'Gi vs no-gi', 'How grips, pace and technique differ between gi and no-gi.', true),
  ((select id from public.categories where slug = 'bjj'), 'competition-points-and-rules', 'Competition points and rules', 'How points, advantages and penalties work in a BJJ match.', true)
on conflict (category_id, slug) do nothing;

update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'bjj-for-beginners' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 2, subskill_difficulty = 1.11 where slug = 'bjj-belt-system' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 3, subskill_difficulty = 1.23 where slug = 'breakfalls' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 4, subskill_difficulty = 1.34 where slug = 'hip-escape-shrimp' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 5, subskill_difficulty = 1.46 where slug = 'bridging' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 6, subskill_difficulty = 1.57 where slug = 'posture-and-base' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 7, subskill_difficulty = 1.69 where slug = 'closed-guard' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 8, subskill_difficulty = 1.80 where slug = 'open-guard' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 9, subskill_difficulty = 1.91 where slug = 'half-guard' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 10, subskill_difficulty = 2.03 where slug = 'butterfly-guard' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 11, subskill_difficulty = 2.14 where slug = 'de-la-riva-guard' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 12, subskill_difficulty = 2.26 where slug = 'guard-retention' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 13, subskill_difficulty = 2.37 where slug = 'side-control' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 14, subskill_difficulty = 2.49 where slug = 'mount' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 15, subskill_difficulty = 2.60 where slug = 'back-control' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 16, subskill_difficulty = 2.71 where slug = 'turtle-position' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 17, subskill_difficulty = 2.83 where slug = 'mount-escape' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 18, subskill_difficulty = 2.94 where slug = 'side-control-escape' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 19, subskill_difficulty = 3.06 where slug = 'back-escape' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 20, subskill_difficulty = 3.17 where slug = 'scissor-sweep' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 21, subskill_difficulty = 3.29 where slug = 'hip-bump-sweep' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 22, subskill_difficulty = 3.40 where slug = 'butterfly-sweep' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 23, subskill_difficulty = 3.51 where slug = 'armbar' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 24, subskill_difficulty = 3.63 where slug = 'triangle-choke' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 25, subskill_difficulty = 3.74 where slug = 'kimura' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 26, subskill_difficulty = 3.86 where slug = 'americana' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 27, subskill_difficulty = 3.97 where slug = 'rear-naked-choke' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 28, subskill_difficulty = 4.09 where slug = 'guillotine-choke' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 29, subskill_difficulty = 4.20 where slug = 'omoplata' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 30, subskill_difficulty = 4.31 where slug = 'knee-cut-pass' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 31, subskill_difficulty = 4.43 where slug = 'toreando-pass' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 32, subskill_difficulty = 4.54 where slug = 'leg-drag-pass' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 33, subskill_difficulty = 4.66 where slug = 'double-leg-takedown' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 34, subskill_difficulty = 4.77 where slug = 'single-leg-takedown' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 35, subskill_difficulty = 4.89 where slug = 'gi-vs-no-gi' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 36, subskill_difficulty = 5.00 where slug = 'competition-points-and-rules' and category_id = (select id from public.categories where slug = 'bjj');

commit;
