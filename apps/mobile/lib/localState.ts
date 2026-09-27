import { MMKV } from "react-native-mmkv";

let storage: MMKV | null = null;
const memory = new Map<string, string>();
const ONBOARDING_COMPLETED_KEY = "onboarding_completed";
const ONBOARDING_INTERESTS_KEY = "onboarding_interests";
const INSTALL_ID_KEY = "install_id";

try {
  storage = new MMKV({ id: "skillsaggregator" });
} catch (_error) {
  storage = null;
}

export function setFlag(key: string, value: boolean) {
  if (storage) storage.set(key, value ? "1" : "0");
  else if (value) memory.set(key, "1");
  else memory.delete(key);
}

export function getFlag(key: string) {
  return storage ? storage.getString(key) === "1" : memory.get(key) === "1";
}

function setString(key: string, value: string) {
  if (storage) storage.set(key, value);
  else memory.set(key, value);
}

function getString(key: string) {
  return storage ? storage.getString(key) : memory.get(key);
}

function deleteKey(key: string) {
  if (storage) storage.delete(key);
  else memory.delete(key);
}

export function setStoredString(key: string, value: string | null) {
  if (value === null) deleteKey(key);
  else setString(key, value);
}

export function getStoredString(key: string) {
  return getString(key) ?? null;
}

/**
 * A random id for this install, kept in MMKV. It is the only way to count people
 * who open the app and never act: the anonymous Supabase user is created lazily
 * on first real action, so those users have no identity to attribute anything to.
 *
 * Deliberately NOT the IDFV or an advertising id. A random uuid says nothing
 * about the device and does not survive a reinstall, which keeps the store
 * listing's privacy claim true — the cost is that this counts first launches
 * rather than store installs.
 *
 * Returns `{ id, created }`, where `created` says whether this launch minted the
 * id. The install ping does not key off it — it retries until the server
 * confirms — because a first ping that fails must not cost the install for good.
 */
export function getOrCreateInstallId(): { id: string; created: boolean } {
  const existing = getString(INSTALL_ID_KEY);
  if (existing) return { id: existing, created: false };
  // crypto.randomUUID is not in the Hermes/RN runtime, so build the v4 layout by
  // hand rather than pulling in a uuid dependency. The server validates the shape.
  const hex = () => Math.floor(Math.random() * 16).toString(16);
  const block = (length: number) => Array.from({ length }, hex).join("");
  const variant = () => ((Math.floor(Math.random() * 16) & 0x3) | 0x8).toString(16);
  const id = `${block(8)}-${block(4)}-4${block(3)}-${variant()}${block(3)}-${block(12)}`;
  setString(INSTALL_ID_KEY, id);
  // If storage is unavailable the id lives in `memory` for this run only, so the
  // install is counted again next launch. Over-counting installs is a far better
  // failure than blocking the app on analytics.
  return { id, created: true };
}

export function hasCompletedOnboarding() {
  return getFlag(ONBOARDING_COMPLETED_KEY);
}

export function setOnboardingCompleted(value: boolean) {
  setFlag(ONBOARDING_COMPLETED_KEY, value);
}

export function getOnboardingInterests() {
  const raw = getString(ONBOARDING_INTERESTS_KEY);
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw) as unknown;
    return Array.isArray(parsed)
      ? parsed.filter((item): item is string => typeof item === "string")
      : [];
  } catch (error) {
    console.warn("[onboarding] Failed to parse saved interests", { error });
    deleteKey(ONBOARDING_INTERESTS_KEY);
    return [];
  }
}

export function setOnboardingInterests(categorySlugs: string[]) {
  setString(ONBOARDING_INTERESTS_KEY, JSON.stringify([...new Set(categorySlugs)]));
}

export function setLastSeenSkill(skillId: string) {
  if (storage) storage.set("last_seen_skill", skillId);
  else memory.set("last_seen_skill", skillId);
}
