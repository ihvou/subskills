-- 0039: rename "Starting to run" -> "Couch to 5K".
--
-- The only sub-skill in the catalogue still below the 3-published visibility line.
-- Not a queue problem and not a coach problem — the coach was judging correctly.
-- Of 16 candidates it published 2 and rejected 14, with reasons like "wrong shelf",
-- "not a starting-to-run resource", "not for first-time beginners": cadence drills,
-- core work, runner's-knee rehab, return-to-running. All genuinely running content,
-- none of it beginner onboarding.
--
-- The fault is the NAME. Queries are built from skill.name (run-collection.mjs
-- ~line 823), so this page searched "Starting to run", "how to Starting to run
-- technique" and "beginner Running Starting to run" — phrasings no tutorial uses,
-- which retrieved the general running-channel pool instead. The audit's own
-- recommendation was "Starting to Run (Couch to 5K)", and the Couch-to-5K half was
-- dropped when the taxonomy migration was written; that is the half carrying the
-- actual corpus (NHS C25K and every derivative). The single best result the page
-- did find is literally titled "Couch To 5K: Week 1".
--
-- Named "Couch to 5K" rather than "Starting to Run (Couch to 5K)" because the
-- parenthetical is dead weight in a search query — the same reason the audit
-- renames "The Cross (Straight Right)" and "Rulo" -> "Kick smash". It is also the
-- phrase a beginner actually recognises, so it reads well in the UI too.
--
-- The slug is left alone: it is a URL key, nothing derives search terms from it,
-- and changing it would break any link already shared.
begin;

update public.skills
   set name = 'Couch to 5K',
       description = 'Run-walk your way from the couch to a continuous 5K.'
 where slug = 'starting-to-run'
   and category_id = (select id from public.categories where name = 'Running');

commit;
