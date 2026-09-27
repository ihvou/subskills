import { getStoredString, setStoredString } from "./localState";
import type { SuggestionRequest } from "./submitSuggestion";

/**
 * Links the user has submitted but the server has not finished with.
 *
 * Submitting used to block on the whole chain — session, Turnstile, rate limit,
 * oEmbed, several database round trips, and a second edge function invoked over
 * HTTP — with the form frozen throughout. On this project a cold round trip
 * costs 400-1200ms, so that is seconds of staring at a disabled button for work
 * the user does not need to watch.
 *
 * Now the link is accepted the moment it validates, appears in Watch later as a
 * visibly-loading row, and the request runs behind it. The row is deliberately
 * NOT dressed up as a finished card: a card that silently rewrites its own
 * title and thumbnail under the reader is worse than one that says it is still
 * working.
 *
 * Persisted rather than in-memory because the request dies with the process. An
 * item still marked `submitting` at startup was interrupted, not in flight —
 * see `reconcileInterrupted`, which surfaces it as failed so the user can
 * retry, instead of it vanishing as though it had never been typed.
 */

const STORAGE_KEY = "pending_submissions_v1";
// Enough for any real burst of sharing; a queue that only grows is a leak.
const MAX_PENDING = 25;

export type PendingSubmissionState = "submitting" | "failed";

export type PendingSubmission = {
  id: string;
  url: string;
  /** Shown while there is nothing better. Null until the server resolves one. */
  title: string | null;
  skillName: string | null;
  createdAt: string;
  /** Everything needed to send it again without reopening the form. */
  request: SuggestionRequest;
  state: PendingSubmissionState;
  error?: string;
};

type Listener = () => void;

let cache: PendingSubmission[] | null = null;
const listeners = new Set<Listener>();

function read(): PendingSubmission[] {
  if (cache) return cache;
  try {
    const raw = getStoredString(STORAGE_KEY);
    const parsed = raw ? JSON.parse(raw) : [];
    cache = Array.isArray(parsed) ? (parsed as PendingSubmission[]) : [];
  } catch {
    cache = [];
  }
  return cache;
}

function write(next: PendingSubmission[]) {
  cache = next.slice(-MAX_PENDING);
  try {
    setStoredString(STORAGE_KEY, JSON.stringify(cache));
  } catch {
    /* a full disk must not break submitting */
  }
  for (const listener of listeners) listener();
}

export function subscribePendingSubmissions(listener: Listener) {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

/**
 * Stable identity matters: useSyncExternalStore re-renders forever if the
 * snapshot is a fresh array each call, so `read()` returns the cached instance
 * and every mutation replaces it exactly once.
 */
export function getPendingSubmissions(): PendingSubmission[] {
  return read();
}

export function addPendingSubmission(
  input: Omit<PendingSubmission, "id" | "createdAt" | "state">,
): string {
  const id = `pending-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
  write([...read(), { ...input, id, createdAt: new Date().toISOString(), state: "submitting" }]);
  return id;
}

/** The server took it. Drop the placeholder; the real row arrives with the refetch. */
export function resolvePendingSubmission(id: string) {
  write(read().filter((item) => item.id !== id));
}

export function failPendingSubmission(id: string, error: string) {
  write(read().map((item) => (item.id === id ? { ...item, state: "failed", error } : item)));
}

export function removePendingSubmission(id: string) {
  resolvePendingSubmission(id);
}

/**
 * Anything still `submitting` when the app starts lost its request to the
 * process dying. Nothing is retrying it, so saying "submitting" would be a lie
 * that never resolves.
 */
export function reconcileInterruptedSubmissions() {
  const items = read();
  if (!items.some((item) => item.state === "submitting")) return;
  write(
    items.map((item) =>
      item.state === "submitting"
        ? { ...item, state: "failed" as const, error: "Interrupted before it finished sending." }
        : item,
    ),
  );
}
