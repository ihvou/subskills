import { NextRequest, NextResponse } from "next/server";
import { getAuthSupabase, getPublicSupabase, getServiceSupabase } from "@/lib/supabase";

type ResolvedUser = {
  id: string;
};

function json(status: number, body: { ok?: boolean; error?: string }) {
  return NextResponse.json(body, { status });
}

function bearerToken(request: NextRequest) {
  const authorization = request.headers.get("authorization");
  if (!authorization?.toLowerCase().startsWith("bearer ")) return null;
  return authorization.slice("bearer ".length).trim() || null;
}

async function userFromBearer(request: NextRequest) {
  const token = bearerToken(request);
  if (!token) return null;

  const supabase = getPublicSupabase();
  if (!supabase) return null;

  const { data, error } = await supabase.auth.getUser(token);
  if (error) {
    console.warn("[account-delete] bearer_user_lookup_failed", { error: error.message });
    return null;
  }
  return data.user ?? null;
}

async function userFromCookies() {
  const supabase = await getAuthSupabase();
  if (!supabase) return null;

  const { data, error } = await supabase.auth.getUser();
  if (error) {
    console.warn("[account-delete] cookie_user_lookup_failed", { error: error.message });
    return null;
  }
  return data.user ?? null;
}

async function resolveUser(request: NextRequest): Promise<ResolvedUser | null> {
  return (await userFromBearer(request)) ?? (await userFromCookies());
}

async function detachPublicProfileReferences(userId: string) {
  const supabase = getServiceSupabase();
  if (!supabase) throw new Error("Service role Supabase client is not configured.");

  const { data: profiles, error: profileError } = await supabase
    .from("contributor_profiles")
    .select("id")
    .eq("user_id", userId);
  if (profileError) throw profileError;

  const profileIds = (profiles ?? []).map((profile) => profile.id).filter(Boolean);
  if (profileIds.length === 0) return { detachedLinks: 0, profileCount: 0 };

  const { data: detachedLinks, error: linkError } = await supabase
    .from("links")
    .update({ contributor_profile_id: null })
    .in("contributor_profile_id", profileIds)
    .select("id");
  if (linkError) throw linkError;

  return { detachedLinks: detachedLinks?.length ?? 0, profileCount: profileIds.length };
}

async function deleteCurrentUser(request: NextRequest) {
  const serviceSupabase = getServiceSupabase();
  if (!serviceSupabase) {
    console.error("[account-delete] service_client_missing");
    return json(503, { error: "Account deletion is temporarily unavailable." });
  }

  const user = await resolveUser(request);
  if (!user) return json(401, { error: "Sign in before deleting your account." });

  console.info("[account-delete] deletion_started", { userId: user.id });

  try {
    const detachResult = await detachPublicProfileReferences(user.id);
    const { error } = await serviceSupabase.auth.admin.deleteUser(user.id);
    if (error) throw error;

    console.info("[account-delete] deletion_completed", {
      userId: user.id,
      ...detachResult,
    });
    return json(200, { ok: true });
  } catch (error) {
    console.error("[account-delete] deletion_failed", {
      userId: user.id,
      error: error instanceof Error ? error.message : String(error),
    });
    return json(500, { error: "Account deletion failed. Contact support if the problem continues." });
  }
}

export async function DELETE(request: NextRequest) {
  return deleteCurrentUser(request);
}

export async function POST(request: NextRequest) {
  return deleteCurrentUser(request);
}
