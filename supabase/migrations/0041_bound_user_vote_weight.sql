-- 0041: bound how much user votes can move combined_score.
--
-- BEFORE: combined_score = relevance_vote + value_vote + user_score, where
-- user_score is the RAW net vote sum (sum of +1/-1 over user_relation_votes) and
-- is unbounded. Curation contributes at most +4 (two coach axes, each [-2,+2]),
-- and published scores actually span roughly 1.3 to 4.6. So a single upvote
-- (+1.0) outweighed the entire quality gap between a mediocre and an excellent
-- curated video, and ten upvotes would have made curation irrelevant.
--
-- Worse, the publish gate is `combined_score >= min_score` (migrations 0025/0026),
-- so votes did not just reorder — they could PUBLISH content the coaches had
-- rejected. On a public site that is trivially abusable.
--
-- AFTER: the user contribution is damped and capped.
--     0.5 per net vote, clamped to +/- 1.5
-- so 1 vote = 0.5, 3+ votes = 1.5, 100 votes = 1.5. A genuinely popular video
-- climbs a few places; it can never overturn curation, and the number of accounts
-- needed to force a publish no longer scales.
--
-- Deliberately kept as simple arithmetic rather than a log/decay curve: this value
-- is user-visible through ordering, and an operator should be able to predict it.
--
-- NOTE: this does not fully separate ranking from publication — a relation the
-- coaches scored at -0.2 can still reach the 1.3 gate with 3 upvotes. Removing the
-- user term from the gate entirely (while keeping it in ranking) is the clean fix
-- and is worth doing next; it touches refresh_relation_publish_gate (0025) and the
-- single-relation path (0026).
begin;

create or replace function public.bounded_user_vote_weight(p_user_score real)
returns real
language sql
immutable
set search_path = public
as $fn$
  select greatest(-1.5::real, least(1.5::real, coalesce(p_user_score, 0::real) * 0.5::real));
$fn$;

comment on function public.bounded_user_vote_weight(real) is
  'Damped, capped contribution of user votes to combined_score: 0.5 per net vote, clamped to +/-1.5. Keeps community signal meaningful without letting it outweigh transcript-based curation (which spans at most +/-4).';

-- Rewrite the vote path to use it. Body is otherwise identical to 0025.
create or replace function public.refresh_relation_scores(p_relation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_upvotes integer := 0;
  v_downvotes integer := 0;
  v_user_score real := 0;
  v_coach_take text;
begin
  select
    count(*) filter (where urv.vote = 1)::integer,
    count(*) filter (where urv.vote = -1)::integer,
    coalesce(sum(urv.vote), 0)::real
  into v_upvotes, v_downvotes, v_user_score
  from public.user_relation_votes urv
  where urv.link_skill_relation_id = p_relation_id;

  select nullif(trim(cv.comment_public), '')
    into v_coach_take
    from public.curator_votes cv
   where cv.link_skill_relation_id = p_relation_id
     and nullif(trim(cv.comment_public), '') is not null
   order by
     case cv.coach_role when 'value' then 0 else 1 end,
     cv.updated_at desc
   limit 1;

  update public.link_skill_relations lsr
     set upvote_count = v_upvotes,
         downvote_count = v_downvotes,
         -- user_score stays the RAW net vote sum: it is the honest record of what
         -- users did, and the UI shows it. Only its influence on ranking is damped.
         user_score = v_user_score,
         combined_score = (
           coalesce(lsr.relevance_vote, 0::real)
           + coalesce(lsr.value_vote, 0::real)
           + public.bounded_user_vote_weight(v_user_score)
         ),
         coach_take = v_coach_take,
         updated_at = now()
   where lsr.id = p_relation_id;
end;
$fn$;

-- Re-apply to every relation that already carries votes, so existing rows stop
-- reflecting the unbounded weighting.
update public.link_skill_relations lsr
   set combined_score = (
         coalesce(lsr.relevance_vote, 0::real)
         + coalesce(lsr.value_vote, 0::real)
         + public.bounded_user_vote_weight(lsr.user_score)
       ),
       updated_at = now()
 where lsr.is_active
   and coalesce(lsr.user_score, 0) <> 0;

commit;
