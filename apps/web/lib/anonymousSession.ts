"use client";

import type { Session, SupabaseClient } from "@supabase/supabase-js";

let pendingAnonymousSession: Promise<Session> | null = null;

export async function getOrCreateBrowserSession(
  supabase: SupabaseClient,
  reason = "user_action",
) {
  const { data: existing, error: sessionError } = await supabase.auth.getSession();
  if (sessionError) throw sessionError;
  if (existing.session) return existing.session;

  if (!pendingAnonymousSession) {
    pendingAnonymousSession = supabase.auth
      .signInAnonymously({
        options: {
          data: {
            first_action: reason,
            first_action_at: new Date().toISOString(),
            client: "web",
          },
        },
      })
      .then(({ data, error }) => {
        if (error) throw error;
        if (!data.session) throw new Error("Anonymous sign-in did not return a session.");
        console.info("anonymous_web_session_created", {
          user_id: data.session.user.id,
          reason,
        });
        return data.session;
      })
      .finally(() => {
        pendingAnonymousSession = null;
      });
  }

  return pendingAnonymousSession;
}
