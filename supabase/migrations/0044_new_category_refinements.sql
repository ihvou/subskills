-- 0044: second-pass refinements to the seven new categories.
--
-- Source: an independent ChatGPT deep-research pass (docs/chatgpt-subskill-research-prompt.md),
-- reviewed against this repo and re-probed. Accepted 16 additions and 5 renames.
--
-- REJECTED, and why it matters: the report's largest recommendation was to prefix ~25 bare
-- sub-skill names with their category ("Block" -> "Table tennis block", "Reset" ->
-- "Pickleball reset", "Mount" -> "BJJ mount"), on the premise that the collector searches the
-- bare skill string across all of YouTube. It does not. run-collection.mjs has TWO query
-- builders: searchQueriesForSkill() uses the bare name and is only used for channel-scoped
-- search, where the channel already disambiguates; openSearchQueriesForSkill() prepends the
-- category to every query and DROPS the bare-name query entirely -- the exact fix, already
-- shipped, for the padel "Bandeja"/cumbia-band failure documented in its comment.
-- Production confirms it: bare-named pages are among the best performers in the catalogue
-- (Surfing "Pop-up" 55 published, Badminton "Drive" 25, Surfing "Cutback" 25, Padel "Lob" 23).
-- Prefixing would also double the token in open search ("Table tennis Table tennis block").
--
-- Also rejected: counterloop (table tennis), poaching (pickleball), nollie (snowboarding),
-- downclimbing (climbing) -- all thin or overlapping, matching the report's own reservations.
begin;

update public.skills set slug = 'posture', name = 'Posture', description = 'Set spine angle, knee flex and distance from the ball.' where slug = 'setup-and-posture' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set slug = 'top-rope-belaying', name = 'Top rope belaying', description = 'Belay on top rope with correct hand position and rope management.' where slug = 'belaying' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set slug = 'how-to-tie-a-figure-8', name = 'How to tie a figure 8', description = 'Tie a figure-8 follow-through into the harness and check it.' where slug = 'how-to-tie-in-figure-8' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set slug = 'body-tension', name = 'Body tension', description = 'Keep hips in and core engaged so feet stay on steep walls.' where slug = 'overhangs-and-body-tension' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set slug = 'how-to-jump-on-skis', name = 'How to jump on skis', description = 'Take off, fly and land safely on a jump.' where slug = 'jumps-and-park-skiing' and category_id = (select id from public.categories where slug = 'skiing');

-- ---- golf: +3 -------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where slug = 'golf'), 'alignment', 'Alignment', 'Aim the clubface and body at the target instead of where it feels right.', true),
  ((select id from public.categories where slug = 'golf'), 'ball-position', 'Ball position', 'Move the ball through the stance correctly for each club.', true),
  ((select id from public.categories where slug = 'golf'), 'putting-distance-control', 'Putting distance control', 'Control pace and lag long putts close.', true)
on conflict (category_id, slug) do nothing;

-- ---- table-tennis: +2 -------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where slug = 'table-tennis'), 'forehand-flick', 'Forehand flick', 'Attack short balls over the table on the forehand side.', true),
  ((select id from public.categories where slug = 'table-tennis'), 'lob', 'Lob', 'Defend high and deep from away from the table.', true)
on conflict (category_id, slug) do nothing;

-- ---- climbing: +2 -------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where slug = 'climbing'), 'how-to-put-on-a-harness', 'How to put on a harness', 'Fit and wear a climbing harness correctly before you tie in.', true),
  ((select id from public.categories where slug = 'climbing'), 'rockover', 'Rockover', 'Transfer weight over a high foot to stand up on it.', true)
on conflict (category_id, slug) do nothing;

-- ---- pickleball: +2 -------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where slug = 'pickleball'), 'pickleball-forehand-drive', 'Pickleball forehand drive', 'Drive the forehand with depth and control from the baseline.', true),
  ((select id from public.categories where slug = 'pickleball'), 'speed-ups', 'Speed-ups', 'Recognise an attackable dink and speed the ball up with purpose.', true)
on conflict (category_id, slug) do nothing;

-- ---- skiing: +2 -------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where slug = 'skiing'), 'side-slipping', 'Side slipping', 'Release and engage the edges to slip sideways down a steep pitch.', true),
  ((select id from public.categories where slug = 'skiing'), 'hockey-stop', 'Hockey stop', 'Pivot both skis across the fall line for a fast, controlled stop.', true)
on conflict (category_id, slug) do nothing;

-- ---- snowboarding: +2 -------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where slug = 'snowboarding'), 'backside-180', 'Backside 180', 'Spin and land a backside 180.', true),
  ((select id from public.categories where slug = 'snowboarding'), 'riding-moguls', 'Riding moguls', 'Pick a line and absorb repeated bumps and troughs.', true)
on conflict (category_id, slug) do nothing;

-- ---- bjj: +3 -------------------------
insert into public.skills (category_id, slug, name, description, is_active) values
  ((select id from public.categories where slug = 'bjj'), 'breaking-closed-guard', 'Breaking closed guard', 'Open a locked closed guard before you can start passing.', true),
  ((select id from public.categories where slug = 'bjj'), 'knee-on-belly', 'Knee on belly', 'Hold, attack and transition from knee on belly.', true),
  ((select id from public.categories where slug = 'bjj'), 'arm-triangle', 'Arm triangle', 'Finish the head-and-arm choke from mount and side control.', true)
on conflict (category_id, slug) do nothing;

-- ---- renumber every affected category -------------------------
update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'golf-grip' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 2, subskill_difficulty = 1.15 where slug = 'posture' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 3, subskill_difficulty = 1.31 where slug = 'alignment' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 4, subskill_difficulty = 1.46 where slug = 'ball-position' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 5, subskill_difficulty = 1.62 where slug = 'golf-swing-basics' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 6, subskill_difficulty = 1.77 where slug = 'how-to-stop-slicing' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 7, subskill_difficulty = 1.92 where slug = 'how-to-stop-hooking' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 8, subskill_difficulty = 2.08 where slug = 'iron-shots' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 9, subskill_difficulty = 2.23 where slug = 'how-to-hit-a-driver' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 10, subskill_difficulty = 2.38 where slug = 'fairway-woods' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 11, subskill_difficulty = 2.54 where slug = 'chipping' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 12, subskill_difficulty = 2.69 where slug = 'pitching' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 13, subskill_difficulty = 2.85 where slug = 'bunker-shots' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 14, subskill_difficulty = 3.00 where slug = 'wedge-distance-control' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 15, subskill_difficulty = 3.15 where slug = 'punch-shot' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 16, subskill_difficulty = 3.31 where slug = 'how-to-hit-a-draw' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 17, subskill_difficulty = 3.46 where slug = 'uneven-lies' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 18, subskill_difficulty = 3.62 where slug = 'putting-stroke' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 19, subskill_difficulty = 3.77 where slug = 'putting-distance-control' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 20, subskill_difficulty = 3.92 where slug = 'reading-greens' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 21, subskill_difficulty = 4.08 where slug = 'course-management' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 22, subskill_difficulty = 4.23 where slug = 'golf-rules-for-beginners' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 23, subskill_difficulty = 4.38 where slug = 'golf-etiquette' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 24, subskill_difficulty = 4.54 where slug = 'how-to-choose-golf-clubs' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 25, subskill_difficulty = 4.69 where slug = 'driving-range-practice' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 26, subskill_difficulty = 4.85 where slug = 'golf-warm-up' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 27, subskill_difficulty = 5.00 where slug = 'golf-mental-game' and category_id = (select id from public.categories where slug = 'golf');
update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'shakehand-grip' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 2, subskill_difficulty = 1.17 where slug = 'penhold-grip' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 3, subskill_difficulty = 1.35 where slug = 'ready-position' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 4, subskill_difficulty = 1.52 where slug = 'forehand-drive' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 5, subskill_difficulty = 1.70 where slug = 'backhand-drive' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 6, subskill_difficulty = 1.87 where slug = 'forehand-push' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 7, subskill_difficulty = 2.04 where slug = 'backhand-push' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 8, subskill_difficulty = 2.22 where slug = 'block' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 9, subskill_difficulty = 2.39 where slug = 'forehand-topspin' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 10, subskill_difficulty = 2.57 where slug = 'backhand-topspin' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 11, subskill_difficulty = 2.74 where slug = 'looping-against-backspin' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 12, subskill_difficulty = 2.91 where slug = 'backhand-flick' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 13, subskill_difficulty = 3.09 where slug = 'forehand-flick' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 14, subskill_difficulty = 3.26 where slug = 'forehand-smash' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 15, subskill_difficulty = 3.43 where slug = 'chopping' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 16, subskill_difficulty = 3.61 where slug = 'lob' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 17, subskill_difficulty = 3.78 where slug = 'topspin-serve' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 18, subskill_difficulty = 3.96 where slug = 'backspin-serve' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 19, subskill_difficulty = 4.13 where slug = 'sidespin-serve' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 20, subskill_difficulty = 4.30 where slug = 'serve-return' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 21, subskill_difficulty = 4.48 where slug = 'reading-spin' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 22, subskill_difficulty = 4.65 where slug = 'table-tennis-footwork' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 23, subskill_difficulty = 4.83 where slug = 'choosing-a-blade-and-rubber' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 24, subskill_difficulty = 5.00 where slug = 'doubles-rules-and-rotation' and category_id = (select id from public.categories where slug = 'table-tennis');
update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'bouldering-for-beginners' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 2, subskill_difficulty = 1.17 where slug = 'choosing-climbing-shoes' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 3, subskill_difficulty = 1.35 where slug = 'how-to-put-on-a-harness' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 4, subskill_difficulty = 1.52 where slug = 'how-to-tie-a-figure-8' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 5, subskill_difficulty = 1.70 where slug = 'top-rope-belaying' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 6, subskill_difficulty = 1.87 where slug = 'lead-belaying' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 7, subskill_difficulty = 2.04 where slug = 'clipping-quickdraws' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 8, subskill_difficulty = 2.22 where slug = 'how-to-fall-safely' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 9, subskill_difficulty = 2.39 where slug = 'climbing-footwork' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 10, subskill_difficulty = 2.57 where slug = 'flagging' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 11, subskill_difficulty = 2.74 where slug = 'rockover' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 12, subskill_difficulty = 2.91 where slug = 'heel-hook' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 13, subskill_difficulty = 3.09 where slug = 'toe-hook' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 14, subskill_difficulty = 3.26 where slug = 'crimp-grip' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 15, subskill_difficulty = 3.43 where slug = 'drop-knee' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 16, subskill_difficulty = 3.61 where slug = 'dyno' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 17, subskill_difficulty = 3.78 where slug = 'mantle' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 18, subskill_difficulty = 3.96 where slug = 'slab-climbing' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 19, subskill_difficulty = 4.13 where slug = 'body-tension' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 20, subskill_difficulty = 4.30 where slug = 'resting-on-the-wall' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 21, subskill_difficulty = 4.48 where slug = 'reading-routes' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 22, subskill_difficulty = 4.65 where slug = 'climbing-grades-explained' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 23, subskill_difficulty = 4.83 where slug = 'hangboard-training' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 24, subskill_difficulty = 5.00 where slug = 'climbing-warm-up' and category_id = (select id from public.categories where slug = 'climbing');
update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'pickleball-rules' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 2, subskill_difficulty = 1.20 where slug = 'kitchen-rules' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 3, subskill_difficulty = 1.40 where slug = 'pickleball-serve' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 4, subskill_difficulty = 1.60 where slug = 'return-of-serve' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 5, subskill_difficulty = 1.80 where slug = 'pickleball-forehand-drive' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 6, subskill_difficulty = 2.00 where slug = 'pickleball-backhand' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 7, subskill_difficulty = 2.20 where slug = 'dink' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 8, subskill_difficulty = 2.40 where slug = 'third-shot-drop' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 9, subskill_difficulty = 2.60 where slug = 'third-shot-drive' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 10, subskill_difficulty = 2.80 where slug = 'reset' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 11, subskill_difficulty = 3.00 where slug = 'speed-ups' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 12, subskill_difficulty = 3.20 where slug = 'pickleball-volley' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 13, subskill_difficulty = 3.40 where slug = 'overhead-smash' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 14, subskill_difficulty = 3.60 where slug = 'pickleball-lob' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 15, subskill_difficulty = 3.80 where slug = 'erne' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 16, subskill_difficulty = 4.00 where slug = 'around-the-post' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 17, subskill_difficulty = 4.20 where slug = 'pickleball-footwork' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 18, subskill_difficulty = 4.40 where slug = 'doubles-positioning' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 19, subskill_difficulty = 4.60 where slug = 'stacking' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 20, subskill_difficulty = 4.80 where slug = 'singles-strategy' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 21, subskill_difficulty = 5.00 where slug = 'choosing-a-pickleball-paddle' and category_id = (select id from public.categories where slug = 'pickleball');
update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'how-to-ski-for-beginners' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 2, subskill_difficulty = 1.20 where slug = 'ski-stance-and-body-position' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 3, subskill_difficulty = 1.40 where slug = 'how-to-stop-on-skis' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 4, subskill_difficulty = 1.60 where slug = 'snowplough-turns' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 5, subskill_difficulty = 1.80 where slug = 'side-slipping' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 6, subskill_difficulty = 2.00 where slug = 'getting-up-after-a-fall' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 7, subskill_difficulty = 2.20 where slug = 'how-to-use-a-ski-lift' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 8, subskill_difficulty = 2.40 where slug = 'parallel-turns' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 9, subskill_difficulty = 2.60 where slug = 'hockey-stop' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 10, subskill_difficulty = 2.80 where slug = 'carving-on-skis' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 11, subskill_difficulty = 3.00 where slug = 'short-turns' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 12, subskill_difficulty = 3.20 where slug = 'pole-plant' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 13, subskill_difficulty = 3.40 where slug = 'skiing-moguls' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 14, subskill_difficulty = 3.60 where slug = 'skiing-powder' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 15, subskill_difficulty = 3.80 where slug = 'skiing-steeps' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 16, subskill_difficulty = 4.00 where slug = 'skiing-on-ice' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 17, subskill_difficulty = 4.20 where slug = 'how-to-jump-on-skis' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 18, subskill_difficulty = 4.40 where slug = 'ski-boot-fitting' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 19, subskill_difficulty = 4.60 where slug = 'how-to-choose-skis' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 20, subskill_difficulty = 4.80 where slug = 'avalanche-safety' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 21, subskill_difficulty = 5.00 where slug = 'ski-fitness-and-conditioning' and category_id = (select id from public.categories where slug = 'skiing');
update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'how-to-snowboard-for-beginners' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 2, subskill_difficulty = 1.21 where slug = 'snowboard-stance-and-binding-angles' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 3, subskill_difficulty = 1.42 where slug = 'how-to-stop-on-a-snowboard' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 4, subskill_difficulty = 1.63 where slug = 'falling-leaf' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 5, subskill_difficulty = 1.84 where slug = 'heelside-turns' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 6, subskill_difficulty = 2.05 where slug = 'toeside-turns' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 7, subskill_difficulty = 2.26 where slug = 'linking-turns' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 8, subskill_difficulty = 2.47 where slug = 'riding-the-chairlift' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 9, subskill_difficulty = 2.68 where slug = 'snowboard-carving' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 10, subskill_difficulty = 2.89 where slug = 'riding-switch' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 11, subskill_difficulty = 3.11 where slug = 'ollie-on-a-snowboard' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 12, subskill_difficulty = 3.32 where slug = 'butters' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 13, subskill_difficulty = 3.53 where slug = 'frontside-180' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 14, subskill_difficulty = 3.74 where slug = 'backside-180' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 15, subskill_difficulty = 3.95 where slug = 'park-jumps' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 16, subskill_difficulty = 4.16 where slug = 'boxes-and-rails' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 17, subskill_difficulty = 4.37 where slug = 'riding-moguls' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 18, subskill_difficulty = 4.58 where slug = 'riding-powder' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 19, subskill_difficulty = 4.79 where slug = 'how-to-choose-a-snowboard' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 20, subskill_difficulty = 5.00 where slug = 'avalanche-safety' and category_id = (select id from public.categories where slug = 'snowboarding');
update public.skills set learning_order = 1, subskill_difficulty = 1.00 where slug = 'bjj-for-beginners' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 2, subskill_difficulty = 1.11 where slug = 'bjj-belt-system' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 3, subskill_difficulty = 1.21 where slug = 'breakfalls' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 4, subskill_difficulty = 1.32 where slug = 'hip-escape-shrimp' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 5, subskill_difficulty = 1.42 where slug = 'bridging' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 6, subskill_difficulty = 1.53 where slug = 'posture-and-base' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 7, subskill_difficulty = 1.63 where slug = 'closed-guard' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 8, subskill_difficulty = 1.74 where slug = 'open-guard' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 9, subskill_difficulty = 1.84 where slug = 'half-guard' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 10, subskill_difficulty = 1.95 where slug = 'butterfly-guard' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 11, subskill_difficulty = 2.05 where slug = 'de-la-riva-guard' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 12, subskill_difficulty = 2.16 where slug = 'guard-retention' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 13, subskill_difficulty = 2.26 where slug = 'side-control' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 14, subskill_difficulty = 2.37 where slug = 'knee-on-belly' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 15, subskill_difficulty = 2.47 where slug = 'mount' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 16, subskill_difficulty = 2.58 where slug = 'back-control' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 17, subskill_difficulty = 2.68 where slug = 'turtle-position' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 18, subskill_difficulty = 2.79 where slug = 'mount-escape' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 19, subskill_difficulty = 2.89 where slug = 'side-control-escape' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 20, subskill_difficulty = 3.00 where slug = 'back-escape' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 21, subskill_difficulty = 3.11 where slug = 'scissor-sweep' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 22, subskill_difficulty = 3.21 where slug = 'hip-bump-sweep' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 23, subskill_difficulty = 3.32 where slug = 'butterfly-sweep' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 24, subskill_difficulty = 3.42 where slug = 'armbar' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 25, subskill_difficulty = 3.53 where slug = 'triangle-choke' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 26, subskill_difficulty = 3.63 where slug = 'kimura' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 27, subskill_difficulty = 3.74 where slug = 'americana' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 28, subskill_difficulty = 3.84 where slug = 'arm-triangle' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 29, subskill_difficulty = 3.95 where slug = 'rear-naked-choke' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 30, subskill_difficulty = 4.05 where slug = 'guillotine-choke' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 31, subskill_difficulty = 4.16 where slug = 'omoplata' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 32, subskill_difficulty = 4.26 where slug = 'breaking-closed-guard' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 33, subskill_difficulty = 4.37 where slug = 'knee-cut-pass' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 34, subskill_difficulty = 4.47 where slug = 'toreando-pass' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 35, subskill_difficulty = 4.58 where slug = 'leg-drag-pass' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 36, subskill_difficulty = 4.68 where slug = 'double-leg-takedown' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 37, subskill_difficulty = 4.79 where slug = 'single-leg-takedown' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 38, subskill_difficulty = 4.89 where slug = 'gi-vs-no-gi' and category_id = (select id from public.categories where slug = 'bjj');
update public.skills set learning_order = 39, subskill_difficulty = 5.00 where slug = 'competition-points-and-rules' and category_id = (select id from public.categories where slug = 'bjj');

commit;
