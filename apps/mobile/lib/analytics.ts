import { Platform } from "react-native";
import Constants from "expo-constants";
import * as Application from "expo-application";
import {
  getFlag,
  getOrCreateInstallId,
  getStoredString,
  setFlag,
  setStoredString,
} from "./localState";
import { getSupabase } from "./supabase";

/**
 * First-party product events, written straight into `public.app_events`.
 *
 * No third-party SDK on purpose: the store listing claims "No ads. No
 * third-party trackers", and PostHog/Amplitude/Firebase would make that false
 * and change the Data Safety declaration. Every user already has a real
 * Supabase identity, so events are rows the user owns under RLS.
 *
 * Two rules this module keeps:
 *
 *  1. **Never block, never throw.** Analytics failing must not affect anything
 *     the user is doing. Every call is fire-and-forget with a swallowed error.
 *  2. **Never create a session just to log.** M120 deliberately creates the
 *     anonymous user lazily on first real action, so tracking must not inflate
 *     the user table with people who only opened the app. Events fired before a
 *     session exists are queued locally and flushed once one does — see
 *     `flushQueuedEvents`, called from ensureSession.
 */

const QUEUE_KEY = "analytics_queue_v1";
const SESSION_KEY = "analytics_session_id";
// Set only once the server confirms it holds this install, so a lost first ping
// is retried rather than costing an install from the count for good.
const INSTALL_REPORTED_KEY = "install_reported";
const MAX_QUEUE = 50;

export type AppEvent =
  | "app_open"
  | "onboarding_started"
  | "onboarding_completed"
  | "onboarding_skipped"
  | "categories_selected"
  | "resource_opened"
  | "resource_saved"
  | "resource_watched"
  | "resource_voted"
  | "suggestion_submitted"
  // Fired when a link shared from another app is picked up. On iOS that is the
  // App Group drain on foreground, which is the only signal we get that the
  // share extension ran at all — it cannot report anything itself.
  | "resource_shared_in"
  | "search_performed";

type QueuedEvent = {
  event: AppEvent;
  props: Record<string, unknown>;
  occurred_at: string;
};

function appVersion() {
  return Constants.expoConfig?.version ?? null;
}

function platform() {
  return Platform.OS === "ios" ? "ios" : Platform.OS === "android" ? "android" : "web";
}

/**
 * How this build was distributed, so install counts can be read against App Store
 * Connect instead of silently disagreeing with it.
 *
 * IMPORTANT: this does NOT identify TestFlight. expo-application derives the type
 * from `embedded.mobileprovision`, and App Store and TestFlight builds both ship
 * without one, so both come back as `app_store`. What it does separate is our own
 * launches — simulator, Xcode, ad hoc — which is where the noise was: three
 * installs nine minutes apart on 2026-09-18, two with no events at all.
 *
 * iOS only. Android has no equivalent and returns null rather than a guess.
 */
async function releaseType(): Promise<string | null> {
  if (Platform.OS !== "ios") return null;
  try {
    const type = await Application.getIosApplicationReleaseTypeAsync();
    switch (type) {
      case Application.ApplicationReleaseType.APP_STORE: return "app_store";
      case Application.ApplicationReleaseType.AD_HOC: return "ad_hoc";
      case Application.ApplicationReleaseType.ENTERPRISE: return "enterprise";
      case Application.ApplicationReleaseType.DEVELOPMENT: return "development";
      case Application.ApplicationReleaseType.SIMULATOR: return "simulator";
      default: return "unknown";
    }
  } catch {
    // Never let a metadata lookup stop the install from being recorded.
    return null;
  }
}

/**
 * Stable for one app run. Regenerated whenever the module is re-initialised,
 * which is close enough to "a session" for counting purposes and stores nothing
 * that identifies the device.
 */
let runSessionId: string | null = null;
function sessionId() {
  if (!runSessionId) {
    runSessionId = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
    setStoredString(SESSION_KEY, runSessionId);
  }
  return runSessionId;
}

function readQueue(): QueuedEvent[] {
  try {
    const raw = getStoredString(QUEUE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? (parsed as QueuedEvent[]) : [];
  } catch {
    return [];
  }
}

function writeQueue(events: QueuedEvent[]) {
  try {
    // Keep the newest. A queue that grows without bound on a device that never
    // signs in is a slow leak, and old pre-session events have little value.
    setStoredString(QUEUE_KEY, JSON.stringify(events.slice(-MAX_QUEUE)));
  } catch {
    /* storage full or unavailable — dropping analytics is the right trade */
  }
}

// Every object in a batch must have IDENTICAL keys — PostgREST rejects a mixed
// batch with PGRST102 "All object keys must match". Build rows uniformly.
async function insertEvents(userId: string, events: QueuedEvent[]) {
  const supabase = getSupabase();
  if (!supabase || events.length === 0) return false;
  // NOTE: no .select() here on purpose. supabase-js then sends
  // `Prefer: return=minimal`; asking for the inserted rows back would make
  // PostgREST run INSERT ... RETURNING, which needs a SELECT policy — and
  // app_events deliberately has none, so it would fail with a misleading
  // "violates row-level security policy".
  const { error } = await supabase.from("app_events").insert(
    events.map((item) => ({
      user_id: userId,
      event: item.event,
      platform: platform(),
      app_version: appVersion(),
      session_id: sessionId(),
      // Ties the event back to public.app_installs, which is what lets the funnel
      // start at installs instead of at "users who eventually did something".
      install_id: getOrCreateInstallId().id,
      props: item.props,
      occurred_at: item.occurred_at,
    })),
  );
  if (error) {
    console.warn("[analytics] insert failed", { count: events.length, error: error.message });
    return false;
  }
  return true;
}

/**
 * Record an event. Safe to call from anywhere, including render paths.
 */
export function track(event: AppEvent, props: Record<string, unknown> = {}) {
  const item: QueuedEvent = { event, props, occurred_at: new Date().toISOString() };
  void (async () => {
    try {
      const supabase = getSupabase();
      if (!supabase) return;
      const { data } = await supabase.auth.getSession();
      const userId = data.session?.user?.id;
      if (!userId) {
        // No identity yet. Queue rather than creating one — see rule 2 above.
        writeQueue([...readQueue(), item]);
        return;
      }
      const ok = await insertEvents(userId, [item]);
      if (!ok) writeQueue([...readQueue(), item]);
    } catch (error) {
      console.warn("[analytics] track failed", {
        event,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  })();
}

/**
 * Register this install, once, on the launch that mints the install id.
 *
 * This is the ONLY signal we get from someone who opens the app and never acts:
 * they never trigger ensureSession, so they never get an identity, so none of
 * their queued events are ever sent. Without this the funnel's top row was
 * "users who did something", and every rate below it was near 100% by
 * construction.
 *
 * Goes to an edge function rather than straight to the table because there is no
 * identity yet, and opening an unauthenticated write path on a public table is
 * the exact shape of the exposure 0062 was written to close.
 */
export function trackInstall() {
  void (async () => {
    try {
      // Ping on every launch until the server confirms it holds this install.
      // Pinging only on the launch that minted the id lost the install for good
      // whenever that first ping failed — an offline first launch, or a
      // rate-limited one, which answers 200 and looks like success.
      if (getFlag(INSTALL_REPORTED_KEY)) return;
      const { id } = getOrCreateInstallId();
      const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL?.replace(/\/+$/, "");
      const anonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;
      if (!supabaseUrl || !anonKey) return;
      const response = await fetch(`${supabaseUrl}/functions/v1/track-install`, {
        method: "POST",
        headers: { "Content-Type": "application/json", apikey: anonKey },
        body: JSON.stringify({
          install_id: id,
          platform: platform(),
          app_version: appVersion(),
          release_type: await releaseType(),
        }),
      });
      const body = (await response.json().catch(() => null)) as
        | { stored?: boolean; recorded?: boolean }
        | null;
      // Only a server that says it has the row stops the retries. Anything else —
      // offline, rate limited, 500 — leaves the flag unset and we try next launch.
      // `recorded` is what the function answered before the audit fix; accepting it
      // means this build behaves correctly whichever version is deployed, and it
      // can go once the new function is live everywhere.
      const stored = body?.stored === true || body?.recorded === true;
      if (response.ok && stored) setFlag(INSTALL_REPORTED_KEY, true);
    } catch (error) {
      // Same rule as track(): analytics never affects what the user is doing. The
      // id is already stored, so a lost ping costs one install from the count and
      // the events still carry the id.
      console.warn("[analytics] install ping failed", {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  })();
}

/**
 * Send anything recorded before the user had an identity. Called once a session
 * exists, so pre-session events (app_open, onboarding) are attributed to the
 * user who eventually acted rather than lost.
 */
export function flushQueuedEvents(userId: string) {
  void (async () => {
    try {
      const queued = readQueue();
      if (queued.length === 0) return;
      // Clear first: a failed insert re-queues, and losing a few events is far
      // better than a poison item retrying forever on every action.
      writeQueue([]);
      const ok = await insertEvents(userId, queued);
      if (!ok) writeQueue(queued);
      else console.info("[analytics] flushed queued events", { count: queued.length });
    } catch {
      /* non-fatal by design */
    }
  })();
}
