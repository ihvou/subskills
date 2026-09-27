import { useCallback, useEffect, useRef } from "react";
import { AppState, type AppStateStatus } from "react-native";
import { useRootNavigationState, useRouter } from "expo-router";
import {
  drainPendingSharedRequests,
  drainPendingSharedUrls,
  type SharedRequest,
} from "@/modules/shared-inbox";
import { addPendingSubmission, failPendingSubmission, resolvePendingSubmission } from "./pendingSubmissions";
import { track } from "./analytics";
import { useAuth } from "./auth";
import { useQueryClient } from "@tanstack/react-query";
import { sendSuggestion, type SuggestionRequest } from "./submitSuggestion";

/**
 * Picks up what the iOS share extension left behind.
 *
 * Two kinds of thing can be waiting, and they are handled differently:
 *
 *  - A **complete request**. The share sheet form already asked for the sport,
 *    the skill and the two destinations, so there is nothing left to ask. It is
 *    sent in the background and shows up in Watch later as a pending row, the
 *    same as a submission made inside the app. The user opens Subskills and it
 *    is simply there.
 *  - A **bare URL**, from the extension as it was before it had a form. Only
 *    reachable by someone who shared on an older build and then upgraded. No
 *    skill is attached, so it still has to go through the in-app form.
 *
 * Draining and acting are separate. Draining is safe whenever the app is alive
 * and must not be skipped, because the native queue is cleared as it is read.
 * Navigating needs a mounted navigator, and on a cold start there isn't one
 * yet: an earlier version pushed straight from the mount effect and raced the
 * router, so sharing into a closed app either worked or crashed depending on
 * who won (TestFlight build 12).
 */
export function useSharedInbox() {
  const router = useRouter();
  const queryClient = useQueryClient();
  const { profile, ensureSession } = useAuth();
  // `key` is undefined until the root navigator has mounted. This is the
  // documented way to know a push will land somewhere.
  const rootState = useRootNavigationState();
  const navigatorReady = Boolean(rootState?.key);

  // Only bare URLs queue here. Complete requests need no screen, so they never
  // wait on the navigator.
  const queuedUrls = useRef<string[]>([]);
  const appState = useRef<AppStateStatus>(AppState.currentState);

  /**
   * Send something the form already fully specified.
   *
   * It appears in Watch later immediately as a pending row, so a share made
   * minutes ago in another app is visible the moment Subskills opens rather
   * than materialising silently once the network finishes.
   */
  const submitShared = useCallback(
    async (shared: SharedRequest) => {
      if (!shared.skillId || !shared.categoryId) {
        // The form could not load its pickers — offline on a device that had
        // never opened the app. Fall back to asking in the app.
        queuedUrls.current.push(shared.url);
        return;
      }
      const request: SuggestionRequest = {
        add_to_watch_later: shared.addToWatchLater,
        suggest_to_catalog: shared.suggestToCatalog,
        category_id: shared.categoryId,
        skill_id: shared.skillId,
        payload_json: {
          url: shared.url,
          canonical_url: shared.url,
          target_skill_id: shared.skillId,
          title: null,
          public_note: null,
          skill_level: null,
          language: "en",
        },
      };
      const pendingId = addPendingSubmission({
        url: shared.url,
        title: null,
        skillName: shared.skillName,
        request,
      });
      try {
        const activeSession = await ensureSession("share_extension");
        await sendSuggestion(request, {
          accessToken: activeSession.access_token,
          originName: profile
            ? `mobile_${profile.slug}`
            : activeSession.user.is_anonymous
              ? "mobile_anonymous"
              : "mobile_authenticated",
        });
        resolvePendingSubmission(pendingId);
        void queryClient.invalidateQueries({ queryKey: ["user-library"] });
      } catch (error) {
        // The row carries the failure and offers Retry, which is better than an
        // alert over whatever screen the user just opened.
        failPendingSubmission(pendingId, error instanceof Error ? error.message : String(error));
      }
    },
    [ensureSession, profile, queryClient],
  );

  const collect = useCallback(() => {
    for (const shared of drainPendingSharedRequests()) {
      track("resource_shared_in", { completed_in_extension: true });
      void submitShared(shared);
    }
    const urls = drainPendingSharedUrls();
    if (urls.length > 0) queuedUrls.current.push(...urls);
  }, [submitShared]);

  /** Show the next bare URL, but only once there is a navigator to show it in. */
  const present = useCallback(() => {
    if (!navigatorReady) return;
    const next = queuedUrls.current.shift();
    if (!next) return;
    try {
      track("resource_shared_in", { completed_in_extension: false });
      router.push({ pathname: "/suggest", params: { url: next } });
    } catch (error) {
      // Put it back rather than losing it: the container copy is already gone.
      queuedUrls.current.unshift(next);
      console.warn("[shared-inbox] could not present shared link", {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }, [navigatorReady, router]);

  useEffect(() => {
    collect();
    const subscription = AppState.addEventListener("change", (nextState) => {
      const wasBackground = /inactive|background/.test(appState.current);
      appState.current = nextState;
      if (wasBackground && nextState === "active") {
        collect();
        present();
      }
    });
    return () => subscription.remove();
  }, [collect, present]);

  // Present as soon as there is somewhere to present into. On a cold start this
  // is what delivers a bare URL, one render after the navigator appears.
  useEffect(() => {
    present();
  }, [present]);
}
