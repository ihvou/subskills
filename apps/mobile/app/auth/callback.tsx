import { Redirect, useLocalSearchParams } from "expo-router";

/**
 * Auth deep-link landing for `subskills://auth/callback?code=...`.
 *
 * Without this static route, expo-router matches the `/auth/callback` path
 * against the dynamic `[category]/[skill]` route (category="auth", skill="callback")
 * and renders an empty "Skill" / "No matches for this filter" screen after sign-in.
 *
 * The OAuth / magic-link code exchange itself is handled by AuthProvider's
 * Linking listener (see lib/auth.tsx); this route sends the signed-in user
 * back to a safe `next` path instead of the broken skill screen.
 */
export default function AuthCallback() {
  const { next } = useLocalSearchParams<{ next?: string }>();
  const nextPath = typeof next === "string" && next.startsWith("/") ? next : "/account";
  return <Redirect href={nextPath} />;
}
