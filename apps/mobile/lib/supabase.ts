import { createClient, type SupabaseClient } from "@supabase/supabase-js";

let client: SupabaseClient | null = null;
const memory = new Map<string, string>();

type NativeAuthStorage = {
  getString: (key: string) => string | undefined;
  set: (key: string, value: string) => void;
  delete: (key: string) => void;
};

declare const require: (id: string) => {
  MMKV: new (options: { id: string }) => NativeAuthStorage;
};

let storage: NativeAuthStorage | null = null;
try {
  const { MMKV } = require("react-native-mmkv");
  storage = new MMKV({ id: "skillsaggregator-auth" });
} catch (_error) {
  storage = null;
}

const authStorage = {
  getItem(key: string) {
    return storage ? (storage.getString(key) ?? null) : (memory.get(key) ?? null);
  },
  setItem(key: string, value: string) {
    if (storage) storage.set(key, value);
    else memory.set(key, value);
  },
  removeItem(key: string) {
    if (storage) storage.delete(key);
    else memory.delete(key);
  },
};

export function getSupabase() {
  const url = process.env.EXPO_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !anonKey) return null;
  client ??= createClient(url, anonKey, {
    auth: {
      autoRefreshToken: true,
      detectSessionInUrl: false,
      flowType: "pkce",
      persistSession: true,
      storage: authStorage,
    },
  });
  return client;
}
