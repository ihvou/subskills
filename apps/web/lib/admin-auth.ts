import { redirect } from "next/navigation";
import { hasSupabaseConfig, isDemoMode } from "./env";
import { getAuthSupabase, getServiceSupabase } from "./supabase";

export interface ModeratorState {
  demo: boolean;
  email: string | null;
  userId: string | null;
}

export async function requireModerator(): Promise<ModeratorState> {
  if (!hasSupabaseConfig()) {
    if (isDemoMode()) return { demo: true, email: null, userId: null };
    throw new Error("Supabase auth is not configured. Set DEMO_MODE=1 only for local demo bypass.");
  }

  const supabase = await getAuthSupabase();
  if (!supabase) redirect("/admin/login");

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user?.email) redirect("/admin/login");

  const serviceSupabase = getServiceSupabase();
  if (!serviceSupabase) {
    throw new Error("SUPABASE_SERVICE_ROLE_KEY is required for moderator allowlist checks.");
  }

  const { data: moderator, error } = await serviceSupabase
    .from("moderators")
    .select("id")
    .eq("email", user.email.toLowerCase())
    .eq("is_active", true)
    .maybeSingle();
  if (error) throw error;
  if (!moderator) {
    redirect("/admin/login?error=not-allowlisted");
  }

  return { demo: false, email: user.email, userId: user.id };
}
