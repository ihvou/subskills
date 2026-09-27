/**
 * The submit-suggestion request, extracted so the form and a retry from the
 * Library send exactly the same thing. Two call sites building this body
 * separately is how they drift.
 */
export type SuggestionRequest = {
  add_to_watch_later: boolean;
  suggest_to_catalog: boolean;
  category_id: string;
  skill_id: string;
  payload_json: {
    url: string;
    canonical_url: string;
    target_skill_id: string;
    title: string | null;
    public_note: string | null;
    skill_level: string | null;
    language: string;
  };
};

export type SuggestionResult = { saved: boolean; duplicate: boolean };

/**
 * Sends one suggestion. Throws on failure with a message worth showing.
 *
 * Nothing here is fast: the function it calls verifies a Turnstile token,
 * checks a rate limit, fetches oEmbed, makes several database round trips and
 * then invokes a second edge function over HTTP. That is why no screen waits
 * on it any more — see lib/pendingSubmissions.ts.
 */
export async function sendSuggestion(
  request: SuggestionRequest,
  auth: { accessToken: string; originName: string },
): Promise<SuggestionResult> {
  const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL?.replace(/\/+$/, "");
  const anonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;
  if (!supabaseUrl || !anonKey) throw new Error("Supabase is not configured for this build.");

  const response = await fetch(`${supabaseUrl}/functions/v1/submit-suggestion`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: anonKey,
      Authorization: `Bearer ${auth.accessToken}`,
    },
    body: JSON.stringify({
      type: "LINK_ADD",
      origin_type: "human",
      origin_name: auth.originName,
      ...request,
    }),
  });

  const body = (await response.json().catch(() => ({}))) as {
    error?: string;
    saved?: boolean;
    duplicate?: boolean;
  };
  if (!response.ok) throw new Error(body.error ?? "Suggestion failed.");
  return { saved: Boolean(body.saved), duplicate: Boolean(body.duplicate) };
}
