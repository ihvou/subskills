import { useEffect, useRef } from "react";
import { Alert, AppState, type AppStateStatus, Linking } from "react-native";
import type { SkillResource } from "@skillsaggregator/shared";
import { useQueryClient } from "@tanstack/react-query";
import { getStoredString, setStoredString } from "./localState";
import { getSupabase } from "./supabase";
import { recordWatchedForReviewPrompt } from "./storeReview";
import { useAuth } from "./auth";

const PENDING_TUTORIAL_KEY = "pending_tutorial_return_prompt";
const PROMPTED_TUTORIAL_TOKEN_KEY = "prompted_tutorial_return_token";

type PendingTutorial = {
  token: string;
  relationId: string;
  linkId: string;
  url: string;
  title: string | null;
  openedAt: number;
};

function parsePendingTutorial(): PendingTutorial | null {
  const raw = getStoredString(PENDING_TUTORIAL_KEY);
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as Partial<PendingTutorial>;
    if (
      typeof parsed.token !== "string" ||
      typeof parsed.relationId !== "string" ||
      typeof parsed.linkId !== "string" ||
      typeof parsed.url !== "string" ||
      typeof parsed.openedAt !== "number"
    ) {
      return null;
    }
    return {
      token: parsed.token,
      relationId: parsed.relationId,
      linkId: parsed.linkId,
      url: parsed.url,
      title: typeof parsed.title === "string" ? parsed.title : null,
      openedAt: parsed.openedAt,
    };
  } catch (error) {
    console.warn("[tutorial-return] Failed to parse pending tutorial", { error });
    setStoredString(PENDING_TUTORIAL_KEY, null);
    return null;
  }
}

function clearPendingTutorial(token?: string) {
  const pending = parsePendingTutorial();
  if (!token || pending?.token === token) {
    setStoredString(PENDING_TUTORIAL_KEY, null);
  }
}

export async function openTutorialResource(
  resource: SkillResource,
  options: { alreadyWatched?: boolean } = {},
) {
  const relationId = resource.link_skill_relation_id ?? (resource.catalog_status ? null : resource.id);
  const promptable = Boolean(relationId) && !options.alreadyWatched;

  if (promptable && relationId) {
    const pending: PendingTutorial = {
      token: `${Date.now()}:${relationId}`,
      relationId,
      linkId: resource.link.id,
      url: resource.link.url,
      title: resource.link.title,
      openedAt: Date.now(),
    };
    setStoredString(PENDING_TUTORIAL_KEY, JSON.stringify(pending));
    console.info("[tutorial-return] Recorded tutorial open", {
      relationId,
      linkId: resource.link.id,
    });
  }

  try {
    await Linking.openURL(resource.link.url);
  } catch (error) {
    if (promptable && relationId) clearPendingTutorial();
    console.warn("[tutorial-return] Failed to open tutorial URL", {
      relationId,
      linkId: resource.link.id,
      url: resource.link.url,
      error: error instanceof Error ? error.message : String(error),
    });
    Alert.alert("Could not open tutorial", "The link did not open on this device.");
  }
}

export function useTutorialReturnPrompt() {
  const { ensureSession, user } = useAuth();
  const queryClient = useQueryClient();
  const appStateRef = useRef<AppStateStatus>(AppState.currentState);
  const sawBackgroundRef = useRef(false);
  const showingTokenRef = useRef<string | null>(null);

  useEffect(() => {
    let promptTimer: ReturnType<typeof setTimeout> | null = null;

    async function isAlreadyWatched(pending: PendingTutorial) {
      const supabase = getSupabase();
      if (!supabase || !user) return false;
      // By link, not by relation (M158): watched state is per video now, so a
      // video already marked watched under a different skill — or saved
      // privately and ticked off there — must not be prompted for again.
      const { data, error } = await supabase
        .from("user_watched")
        .select("watched_at")
        .eq("user_id", user.id)
        .eq("link_id", pending.linkId)
        .maybeSingle();
      if (error) {
        console.warn("[tutorial-return] Watched preflight failed", {
          relationId: pending.relationId,
          linkId: pending.linkId,
          error: error.message,
        });
        return false;
      }
      return Boolean(data);
    }

    async function writeWatched(pending: PendingTutorial) {
      const session = await ensureSession("mark_watched_after_return");
      const supabase = getSupabase();
      if (!supabase || !session) return;
      const { error } = await supabase.rpc("set_user_watched", {
        p_relation_id: pending.relationId,
        p_watched: true,
      });
      if (error) {
        console.warn("[tutorial-return] Watched write failed", {
          relationId: pending.relationId,
          error: error.message,
        });
        Alert.alert("Watched update failed", error.message);
        return;
      }
      console.info("[tutorial-return] Marked tutorial watched", {
        relationId: pending.relationId,
      });
      await recordWatchedForReviewPrompt(pending.relationId);
      await queryClient.invalidateQueries({ queryKey: ["user-library"] });
    }

    async function writeSaved(pending: PendingTutorial) {
      const session = await ensureSession("save_resource_after_return");
      const supabase = getSupabase();
      if (!supabase || !session) return;
      const { error } = await supabase.rpc("set_user_bookmark", {
        p_relation_id: pending.relationId,
        p_saved: true,
      });
      if (error) {
        console.warn("[tutorial-return] Save write failed", {
          relationId: pending.relationId,
          linkId: pending.linkId,
          error: error.message,
        });
        Alert.alert("Save failed", error.message);
        return;
      }
      console.info("[tutorial-return] Saved tutorial after return", {
        relationId: pending.relationId,
      });
      await queryClient.invalidateQueries({ queryKey: ["user-library"] });
    }

    async function maybePrompt() {
      const pending = parsePendingTutorial();
      if (!pending) return;
      const promptedToken = getStoredString(PROMPTED_TUTORIAL_TOKEN_KEY);
      if (promptedToken === pending.token || showingTokenRef.current === pending.token) return;
      if (Date.now() - pending.openedAt < 1000) return;

      if (await isAlreadyWatched(pending)) {
        clearPendingTutorial(pending.token);
        return;
      }

      showingTokenRef.current = pending.token;
      setStoredString(PROMPTED_TUTORIAL_TOKEN_KEY, pending.token);
      const title = pending.title ? `"${pending.title}"` : "this tutorial";
      Alert.alert(
        "Add this tutorial?",
        `Keep ${title} in your learning history or add it to Watch later.`,
        [
          {
            text: "Not now",
            style: "cancel",
            onPress: () => {
              clearPendingTutorial(pending.token);
              showingTokenRef.current = null;
            },
          },
          {
            text: "Save to Watch later",
            onPress: () => {
              clearPendingTutorial(pending.token);
              showingTokenRef.current = null;
              void writeSaved(pending);
            },
          },
          {
            text: "Mark as watched",
            onPress: () => {
              clearPendingTutorial(pending.token);
              showingTokenRef.current = null;
              void writeWatched(pending);
            },
          },
        ],
        {
          cancelable: true,
          onDismiss: () => {
            clearPendingTutorial(pending.token);
            showingTokenRef.current = null;
          },
        },
      );
    }

    const subscription = AppState.addEventListener("change", (nextState) => {
      const previous = appStateRef.current;
      appStateRef.current = nextState;
      if (nextState === "background" || nextState === "inactive") {
        if (parsePendingTutorial()) sawBackgroundRef.current = true;
        return;
      }
      if (nextState !== "active") return;
      if (previous === "active" || !sawBackgroundRef.current) return;
      sawBackgroundRef.current = false;
      if (promptTimer) clearTimeout(promptTimer);
      promptTimer = setTimeout(() => {
        void maybePrompt();
      }, 450);
    });

    return () => {
      if (promptTimer) clearTimeout(promptTimer);
      subscription.remove();
    };
  }, [ensureSession, queryClient, user]);
}
