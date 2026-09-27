-- 0048: unpark Gym (women) -> Dumbbell bench press by retiring its rejected candidates.
--
-- THE PROBLEM. The page sat at 3 published from 68 active relations (4.4%), which
-- trips the collector's low-publish guard (COLLECT_LOW_PUBLISH_MIN_ACTIVE=60,
-- COLLECT_LOW_PUBLISH_RATIO=0.05 in run-collection.mjs). A parked skill is dropped
-- from the rotation entirely -- including open search -- so it could never recover
-- on its own. It was the only skill in the catalogue in this state.
--
-- ROOT CAUSE, corrected. An earlier audit (docs/subskill-gap-audit-round-2.md)
-- called this "a pipeline bug, not a taxonomy problem". That was wrong. All 68
-- relations were reviewed: 3 published, 65 rejected, none pending. The rejected
-- pool is follow-along workout content -- "20 Minute Dumbbell Upper Body Circuit
-- Workout | Caroline Girvan", "20 MIN CHEST AND SHOULDERS WORKOUT with Dumbbells"
-- -- which the coach was correctly refusing. Channel search had been mining
-- follow-along channels in the Gym (women) source pool for a single-exercise
-- technique page.
--
-- WHY NOT REMOVE THE SOURCE. Caroline Girvan measures 9 published of 51 across the
-- category, and 6 of those 9 are on Upper-body hypertrophy (6/8 on that page) where
-- the follow-along format genuinely fits. trusted_sources is category-scoped with no
-- per-skill granularity, so dropping her to fix one technique page would trade away
-- content that is working elsewhere. The category-level lever is the wrong one for a
-- skill-level problem, so the source pool is left intact.
--
-- WHY THIS IS SAFE. Deactivating a relation does not make the video re-collectable:
-- loadKnownCanonicalUrls() in run-collection.mjs selects from link_skill_relations
-- WITHOUT filtering is_active, and additionally unions the permanent suggestions
-- LINK_ADD record. So these 65 stay known and will not be re-fetched, re-transcribed
-- or re-scored. Nothing unreviewed is discarded -- every row touched here carries a
-- curator vote.
--
-- EFFECT. Active relations drop 68 -> 3, which is below lowPublishMinActive, so the
-- skill re-enters the rotation and can collect fresh candidates. Open search returns
-- good technique content for this page ("Dumbbell Bench Press - Modern Woman's Guide
-- to Strength", "Dumbbell Bench Press - Chest Exercise"), so the refill should be on
-- target this time.
begin;

update public.link_skill_relations lsr
   set is_active = false
 where lsr.skill_id = (
         select s.id from public.skills s
           join public.categories c on c.id = s.category_id
          where c.slug = 'gym-women' and s.slug = 'dumbbell-bench-press')
   and lsr.is_active
   and not lsr.published
   and exists (select 1 from public.curator_votes cv
                where cv.link_skill_relation_id = lsr.id);

commit;
