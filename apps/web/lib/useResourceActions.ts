"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { boundedUserVoteWeight } from "@skillsaggregator/shared";
import { getOrCreateBrowserSession } from "./anonymousSession";
import { getBrowserSupabase } from "./browserSupabase";

export type UserVoteState = -1 | 0 | 1;

// The card shows the aggregate score between the vote arrows, so a vote produces
// visible feedback: before this, voting changed only an icon colour and the item
// never moved (user weight is damped and combined_score rarely ties), so the app
// asked for engagement and appeared to ignore it — 5 votes across 6,109 published
// items.
//
// The number shown is combined_score, NOT the net vote count. Every published
// resource has one (7,166 of 7,166, no nulls), whereas net votes are zero almost
// everywhere, so a vote-count display is blank on essentially every card.
//
// It is held as coach base + bounded vote weight rather than as a single figure so
// the viewer's own vote can move it locally, at the same 0.5-per-vote/±1.5-cap the
// database applies. The RPC returns the authoritative combined_score anyway; the
// local arithmetic only covers the moment before it answers.
export function useResourceActions(
  relationId: string | null,
  linkId: string,
  initialUserScore: number = 0,
  initialCombinedScore: number | null = null,
  options: { initialSaved?: boolean; initialWatched?: boolean } = {},
) {
  const supabase = useMemo(() => getBrowserSupabase(), []);
  const [userId, setUserId] = useState<string | null>(null);
  const [loaded, setLoaded] = useState(false);
  const [isSaved, setIsSaved] = useState(Boolean(options.initialSaved));
  const [isWatched, setIsWatched] = useState(Boolean(options.initialWatched));
  const [vote, setVote] = useState<UserVoteState>(0);
  const [userScore, setUserScore] = useState<number>(initialUserScore);
  const [baseScore, setBaseScore] = useState<number | null>(
    initialCombinedScore === null ? null : initialCombinedScore - boundedUserVoteWeight(initialUserScore),
  );
  const [error, setError] = useState<string | null>(null);

  const combinedScore = baseScore === null ? null : baseScore + boundedUserVoteWeight(userScore);

  const refresh = useCallback(async () => {
    if (!supabase) {
      setLoaded(true);
      return;
    }

    const {
      data: { session },
      error: sessionError,
    } = await supabase.auth.getSession();

    if (sessionError) {
      console.warn("resource_action_session_load_failed", sessionError.message);
    }

    const user = session?.user ?? null;
    setUserId(user?.id ?? null);
    if (!user) {
      setIsSaved(Boolean(options.initialSaved));
      setIsWatched(Boolean(options.initialWatched));
      setVote(0);
      setLoaded(true);
      return;
    }

    const [bookmarkResult, watchedResult, voteResult] = await Promise.all([
      supabase
        .from("user_bookmarks")
        .select("created_at")
        .eq("user_id", user.id)
        .eq("link_id", linkId)
        .maybeSingle(),
      // Watched state is keyed on the link (M158), so it reads the same whether
      // or not this card happens to carry a relation.
      supabase
        .from("user_watched")
        .select("watched_at")
        .eq("user_id", user.id)
        .eq("link_id", linkId)
        .maybeSingle(),
      relationId
        ? supabase
            .from("user_relation_votes")
            .select("vote")
            .eq("user_id", user.id)
            .eq("link_skill_relation_id", relationId)
            .maybeSingle()
        : Promise.resolve({ data: null, error: null }),
    ]);

    if (bookmarkResult.error) console.warn("resource_bookmark_load_failed", bookmarkResult.error.message);
    if (watchedResult.error) console.warn("resource_watched_load_failed", watchedResult.error.message);
    if (voteResult.error) console.warn("resource_vote_load_failed", voteResult.error.message);

    setIsSaved(Boolean(bookmarkResult.data));
    setIsWatched(Boolean(watchedResult.data));
    setVote(voteResult.data?.vote === -1 ? -1 : voteResult.data?.vote === 1 ? 1 : 0);
    setLoaded(true);
  }, [linkId, options.initialSaved, options.initialWatched, relationId, supabase]);

  useEffect(() => {
    setIsSaved(Boolean(options.initialSaved));
    setIsWatched(Boolean(options.initialWatched));
  }, [linkId, options.initialSaved, options.initialWatched, relationId]);

  useEffect(() => {
    let cancelled = false;
    refresh().catch((loadError) => {
      if (cancelled) return;
      console.warn("resource_actions_load_failed", loadError instanceof Error ? loadError.message : String(loadError));
      setLoaded(true);
    });

    if (!supabase) return () => {
      cancelled = true;
    };

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(() => {
      if (!cancelled) void refresh();
    });

    return () => {
      cancelled = true;
      subscription.unsubscribe();
    };
  }, [refresh, supabase]);

  const ensureActionSession = useCallback(async (action: string) => {
    setError(null);
    if (!supabase) {
      setError("Supabase is not configured for resource actions.");
      return null;
    }
    try {
      const session = await getOrCreateBrowserSession(supabase, action);
      setUserId(session.user.id);
      return session;
    } catch (actionError) {
      const message = actionError instanceof Error ? actionError.message : String(actionError);
      console.warn("resource_action_session_create_failed", {
        relation_id: relationId,
        link_id: linkId,
        action,
        message,
      });
      setError(message);
      return null;
    }
  }, [linkId, relationId, supabase]);

  const toggleSaved = useCallback(async () => {
    if (!(await ensureActionSession("save_resource"))) return false;
    const next = !isSaved;
    setIsSaved(next);
    const { error: mutationError } = relationId
      ? await supabase!.rpc("set_user_bookmark", {
          p_relation_id: relationId,
          p_saved: next,
        })
      : await supabase!.rpc("set_user_link_bookmark", {
          p_link_id: linkId,
          p_saved: next,
        });
    if (mutationError) {
      setIsSaved(!next);
      setError(mutationError.message);
      console.warn("resource_bookmark_write_failed", { relationId, linkId, message: mutationError.message });
      return false;
    }
    return true;
  }, [ensureActionSession, isSaved, linkId, relationId, supabase]);

  const toggleWatched = useCallback(async () => {
    if (!(await ensureActionSession("mark_watched"))) return false;
    const next = !isWatched;
    setIsWatched(next);
    // Mirrors toggleSaved: relation path where there is one, link path
    // otherwise, so private and in-review links can be marked watched (M158).
    const { error: mutationError } = relationId
      ? await supabase!.rpc("set_user_watched", {
          p_relation_id: relationId,
          p_watched: next,
        })
      : await supabase!.rpc("set_user_link_watched", {
          p_link_id: linkId,
          p_watched: next,
        });
    if (mutationError) {
      setIsWatched(!next);
      setError(mutationError.message);
      console.warn("resource_watched_write_failed", { relationId, linkId, message: mutationError.message });
      return false;
    }
    return true;
  }, [ensureActionSession, isWatched, linkId, relationId, supabase]);

  const setUserVote = useCallback(async (nextVote: UserVoteState) => {
    if (!relationId) {
      setError("This link needs catalogue review before votes are available.");
      return;
    }
    if (!(await ensureActionSession("vote_resource"))) return;
    const previousVote = vote;
    const previousScore = userScore;
    setVote(nextVote);
    // Optimistic: move the count immediately by the delta, then reconcile with the
    // authoritative value the RPC returns.
    setUserScore(previousScore - previousVote + nextVote);
    const { data, error: mutationError } = await supabase!
      .rpc("set_user_vote", {
        p_relation_id: relationId,
        p_vote: nextVote,
      })
      .single();
    if (mutationError) {
      setVote(previousVote);
      setUserScore(previousScore);
      setError(mutationError.message);
      console.warn("resource_vote_write_failed", { relationId, vote: nextVote, message: mutationError.message });
      return;
    }
    const row = data as {
      vote?: number | null;
      user_score?: number | null;
      combined_score?: number | null;
    } | null;
    const returnedVote = row?.vote;
    setVote(returnedVote === -1 ? -1 : returnedVote === 1 ? 1 : 0);
    if (typeof row?.user_score === "number") setUserScore(row.user_score);
    // Re-derive the coach half from the authoritative pair rather than storing the
    // total, so a coach re-score that landed since page render is picked up here
    // instead of being overwritten by stale local arithmetic.
    if (typeof row?.combined_score === "number" && typeof row?.user_score === "number") {
      setBaseScore(row.combined_score - boundedUserVoteWeight(row.user_score));
    }
  }, [ensureActionSession, relationId, supabase, userScore, vote]);

  return {
    loaded,
    isSignedIn: Boolean(userId),
    isSaved,
    isWatched,
    vote,
    userScore,
    combinedScore,
    error,
    toggleSaved,
    toggleWatched,
    setUserVote,
  };
}
