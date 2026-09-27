"use server";

import { revalidatePath } from "next/cache";
import { getBaseUrl, hasServiceRoleConfig } from "@/lib/env";
import { requireModerator } from "@/lib/admin-auth";
import { getServiceSupabase } from "@/lib/supabase";

async function callEdgeFunction(functionName: string, body: unknown) {
  if (!hasServiceRoleConfig()) {
    return { demo: true, functionName, body };
  }

  const response = await fetch(
    `${process.env.NEXT_PUBLIC_SUPABASE_URL!.replace(/\/+$/, "")}/functions/v1/${functionName}`,
    {
      method: "POST",
      headers: {
        apikey: process.env.SUPABASE_SERVICE_ROLE_KEY!,
        Authorization: `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY!}`,
        "Content-Type": "application/json",
        ...(process.env.INTERNAL_FUNCTION_TOKEN
          ? { "x-internal-token": process.env.INTERNAL_FUNCTION_TOKEN }
          : {}),
      },
      body: JSON.stringify(body),
      cache: "no-store",
    },
  );
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(payload.error ?? `${functionName} failed`);
  return payload;
}

export async function approveSuggestion(formData: FormData) {
  const moderator = await requireModerator();
  const suggestionId = String(formData.get("suggestion_id") ?? "");
  if (!suggestionId) throw new Error("suggestion_id is required");
  await callEdgeFunction("apply-suggestion", {
    suggestion_id: suggestionId,
    moderator_user_id: moderator.userId,
  });
  revalidatePath("/admin");
  revalidatePath("/badminton");
}

export async function declineSuggestion(formData: FormData) {
  const moderator = await requireModerator();
  const suggestionId = String(formData.get("suggestion_id") ?? "");
  if (!suggestionId) throw new Error("suggestion_id is required");

  const supabase = getServiceSupabase();
  if (supabase) {
    const { error } = await supabase
      .from("suggestions")
      .update({
        status: "declined",
        decided_at: new Date().toISOString(),
        moderator_user_id: moderator.userId,
      })
      .eq("id", suggestionId);
    if (error) throw error;
  }

  revalidatePath("/admin");
}

export async function runLinkSearcher(formData: FormData) {
  await requireModerator();
  const skillId = String(formData.get("skill_id") ?? "");
  if (!skillId) throw new Error("skill_id is required");
  const result = await callEdgeFunction("link-searcher", { skill_id: skillId });
  revalidatePath("/admin");
  revalidatePath("/admin/runs");
  return result as { run_id?: string; status?: string; demo?: boolean };
}

export async function demoRevalidate() {
  await requireModerator();
  await fetch(`${getBaseUrl()}/api/revalidate`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-revalidate-secret": process.env.REVALIDATE_SECRET ?? "demo",
    },
    body: JSON.stringify({ category: "badminton" }),
  }).catch(() => null);
}
