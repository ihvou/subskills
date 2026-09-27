import { Platform } from "react-native";
import { requireOptionalNativeModule } from "expo-modules-core";

/**
 * The iOS half of share-in.
 *
 * Android does not use this: its share target launches the app with a
 * `subskills://` intent, which is a path iOS share extensions are not allowed
 * to take (see modules/shared-inbox/ios/SharedInboxModule.swift). So on Android
 * — and in Expo Go, and anywhere the native module is missing — these resolve
 * to nothing rather than throwing.
 */
type SharedInboxNativeModule = {
  drainPendingSharedRequests: () => string[];
  drainPendingSharedUrls: () => string[];
};

/** A complete submission the share sheet form already collected. */
export type SharedRequest = {
  url: string;
  categoryId: string | null;
  skillId: string | null;
  skillName: string | null;
  addToWatchLater: boolean;
  suggestToCatalog: boolean;
};

const native = requireOptionalNativeModule<SharedInboxNativeModule>("SharedInbox");

function drain(read: (m: SharedInboxNativeModule) => string[]): string[] {
  if (Platform.OS !== "ios" || !native) return [];
  try {
    return read(native);
  } catch (error) {
    // Never let the inbox break a foreground. A share that fails to arrive is
    // a bug; an app that cannot resume is worse.
    console.warn("[shared-inbox] drain failed", {
      error: error instanceof Error ? error.message : String(error),
    });
    return [];
  }
}

/**
 * Submissions the share sheet form completed — sport, skill and both toggles
 * already chosen. The app sends these without asking the user anything again.
 */
export function drainPendingSharedRequests(): SharedRequest[] {
  return drain((m) => m.drainPendingSharedRequests()).flatMap((raw) => {
    try {
      const parsed = JSON.parse(raw) as Record<string, unknown>;
      const url = typeof parsed.url === "string" ? parsed.url : null;
      if (!url) return [];
      return [
        {
          url,
          categoryId: typeof parsed.category_id === "string" ? parsed.category_id : null,
          skillId: typeof parsed.skill_id === "string" ? parsed.skill_id : null,
          skillName: typeof parsed.skill_name === "string" ? parsed.skill_name : null,
          // Absent means the form never wrote it, which should not happen —
          // default to the safer pair: keep it privately, do not propose it
          // publicly on the user's behalf.
          addToWatchLater: parsed.add_to_watch_later !== false,
          suggestToCatalog: parsed.suggest_to_catalog === true,
        },
      ];
    } catch {
      // One malformed row must not swallow the rest of the queue.
      return [];
    }
  });
}

/**
 * Bare URLs from the extension as it was before it had a form. Only ever
 * non-empty for someone who shared on the old build and then upgraded; those
 * have no skill attached, so they still go through the in-app form.
 */
export function drainPendingSharedUrls(): string[] {
  return drain((m) => m.drainPendingSharedUrls());
}
