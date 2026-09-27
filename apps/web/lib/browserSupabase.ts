"use client";

import { createBrowserClient } from "@supabase/ssr";

let browserClient: ReturnType<typeof createBrowserClient> | null = null;

export function getBrowserSupabase() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !anonKey) return null;
  // createBrowserClient (from @supabase/ssr) persists the session + PKCE code
  // verifier in COOKIES, so the server-side /auth/callback route can read the
  // verifier and complete exchangeCodeForSession. A plain createClient stores
  // them in localStorage, which the server route can't see -> OAuth/magic-link
  // "succeeds" but no session is established on return.
  browserClient ??= createBrowserClient(url, anonKey);
  return browserClient;
}
