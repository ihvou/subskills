import * as StoreReview from "expo-store-review";
import { getFlag, getStoredString, setFlag, setStoredString } from "./localState";

const REVIEW_REQUESTED_KEY = "store_review_requested_after_watched";
const REVIEW_WATCHED_RELATIONS_KEY = "store_review_watched_relations";
const REVIEW_WATCHED_TARGET = 3;

function readWatchedRelations() {
  const raw = getStoredString(REVIEW_WATCHED_RELATIONS_KEY);
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw) as unknown;
    return Array.isArray(parsed)
      ? parsed.filter((item): item is string => typeof item === "string")
      : [];
  } catch (error) {
    console.warn("[store-review] Failed to parse watched relation list", { error });
    return [];
  }
}

export async function recordWatchedForReviewPrompt(relationId: string) {
  if (!relationId || getFlag(REVIEW_REQUESTED_KEY)) return;

  const current = readWatchedRelations();
  if (current.includes(relationId)) return;

  const next = [...current, relationId].slice(-100);
  setStoredString(REVIEW_WATCHED_RELATIONS_KEY, JSON.stringify(next));

  if (next.length < REVIEW_WATCHED_TARGET) return;

  try {
    const available = await StoreReview.isAvailableAsync();
    if (!available) {
      console.info("[store-review] Native review prompt unavailable", {
        watchedCount: next.length,
      });
      return;
    }

    setFlag(REVIEW_REQUESTED_KEY, true);
    console.info("[store-review] Requesting native review prompt", {
      watchedCount: next.length,
    });
    await StoreReview.requestReview();
  } catch (error) {
    console.warn("[store-review] Native review prompt failed", {
      error: error instanceof Error ? error.message : String(error),
    });
  }
}
