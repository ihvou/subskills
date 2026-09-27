"use client";

import { useMemo, useState } from "react";
import type { CategorySummary, SkillLevel, SkillSummary } from "@skillsaggregator/shared";
import type { Session } from "@supabase/supabase-js";
import { getOrCreateBrowserSession } from "@/lib/anonymousSession";
import { getBrowserSupabase } from "@/lib/browserSupabase";

interface CatalogOption {
  category: CategorySummary;
  skills: SkillSummary[];
}

interface SuggestFormProps {
  catalogs: CatalogOption[];
  initialCategorySlug?: string | undefined;
  initialSkillSlug?: string | undefined;
  initialUrl?: string | undefined;
  contributorSlug?: string | null;
}

const LEVELS: Array<{ value: SkillLevel; label: string }> = [
  { value: "beginner", label: "Beginner" },
  { value: "intermediate", label: "Intermediate" },
  { value: "advanced", label: "Advanced" },
];

export function SuggestForm({
  catalogs,
  initialCategorySlug,
  initialSkillSlug,
  initialUrl,
  contributorSlug,
}: SuggestFormProps) {
  const initialCatalog =
    catalogs.find((item) => item.category.slug === initialCategorySlug) ?? catalogs[0] ?? null;
  const [categoryId, setCategoryId] = useState(initialCatalog?.category.id ?? "");
  const selectedCatalog = catalogs.find((item) => item.category.id === categoryId) ?? catalogs[0];
  const initialSkill =
    selectedCatalog?.skills.find((skill) => skill.slug === initialSkillSlug) ??
    selectedCatalog?.skills[0] ??
    null;
  const [skillId, setSkillId] = useState(initialSkill?.id ?? "");
  const [url, setUrl] = useState(initialUrl ?? "");
  const [fallbackTitle, setFallbackTitle] = useState("");
  const [note, setNote] = useState("");
  const [level, setLevel] = useState<SkillLevel | "">("");
  const [addToWatchLater, setAddToWatchLater] = useState(true);
  const [suggestToCatalog, setSuggestToCatalog] = useState(true);
  const [status, setStatus] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const supabase = useMemo(() => getBrowserSupabase(), []);

  function onCategoryChange(nextCategoryId: string) {
    const nextCatalog = catalogs.find((item) => item.category.id === nextCategoryId);
    setCategoryId(nextCategoryId);
    setSkillId(nextCatalog?.skills[0]?.id ?? "");
  }

  const urlSource = useMemo(() => {
    try {
      const hostname = new URL(url).hostname.replace(/^www\./, "").toLowerCase();
      if (hostname === "youtu.be" || hostname === "youtube.com" || hostname.endsWith(".youtube.com")) return "youtube";
      if (hostname === "tiktok.com" || hostname.endsWith(".tiktok.com")) return "tiktok";
      if (hostname === "instagram.com" || hostname.endsWith(".instagram.com")) return "instagram";
    } catch {
      return null;
    }
    return "other";
  }, [url]);
  const showFallbackTitle = url.trim().length > 0 && urlSource !== "youtube";

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatus(null);
    setError(null);

    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL?.replace(/\/+$/, "");
    const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    if (!supabase || !supabaseUrl || !anonKey) {
      setError("Supabase is not configured for public suggestions.");
      return;
    }
    if (!skillId) {
      setError("Choose a skill before submitting.");
      return;
    }
    if (!addToWatchLater && !suggestToCatalog) {
      setError("Choose Watch later, catalogue review, or both.");
      return;
    }

    setIsSubmitting(true);
    let session: Session;
    try {
      session = await getOrCreateBrowserSession(supabase, "suggest_resource");
    } catch (sessionError) {
      setIsSubmitting(false);
      setError(sessionError instanceof Error ? sessionError.message : String(sessionError));
      return;
    }
    const bearer = session.access_token;
    const response = await fetch(`${supabaseUrl}/functions/v1/submit-suggestion`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: anonKey,
        Authorization: `Bearer ${bearer}`,
      },
      body: JSON.stringify({
        type: "LINK_ADD",
        origin_type: "human",
        add_to_watch_later: addToWatchLater,
        suggest_to_catalog: suggestToCatalog,
        origin_name: contributorSlug
          ? `web_${contributorSlug}`
          : session.user.is_anonymous
            ? "web_anonymous"
            : "web_authenticated",
        category_id: categoryId,
        skill_id: skillId,
        payload_json: {
          url,
          canonical_url: url,
          target_skill_id: skillId,
          title: showFallbackTitle && fallbackTitle.trim() ? fallbackTitle.trim() : null,
          public_note: note.trim() || null,
          skill_level: level || null,
          language: "en",
        },
      }),
    });
    const body = await response.json().catch(() => ({}));
    setIsSubmitting(false);

    if (!response.ok) {
      setError(body.error ?? "Suggestion failed. Please try again.");
      return;
    }

    setUrl("");
    setFallbackTitle("");
    setNote("");
    setLevel("");
    const saved = Boolean(body.saved);
    setStatus(() => {
      if (body.duplicate && saved) return "Already submitted; added to Watch later.";
      if (body.duplicate) return "Already submitted; the existing item is still in review.";
      if (saved && suggestToCatalog) return "Saved to Watch later and submitted for review.";
      if (saved) return "Saved to Watch later.";
      return "Submitted for review.";
    });
  }

  return (
    <form
      onSubmit={submit}
      className="mx-auto mt-8 max-w-2xl space-y-5 rounded-lg bg-surface p-4 shadow-card ring-1 ring-divider"
    >
      <label className="block">
        <span className="text-sm font-bold text-ink">URL</span>
        <input
          type="url"
          required
          value={url}
          onChange={(event) => setUrl(event.target.value)}
          className="focus-ring mt-2 w-full rounded-md border border-divider bg-bg px-3 py-2 text-base text-ink"
          placeholder="https://..."
        />
      </label>

      {showFallbackTitle ? (
        <label className="block">
          <span className="text-sm font-bold text-ink">Title</span>
          <input
            type="text"
            value={fallbackTitle}
            onChange={(event) => setFallbackTitle(event.target.value.slice(0, 180))}
            className="focus-ring mt-2 w-full rounded-md border border-divider bg-bg px-3 py-2 text-base text-ink"
            placeholder="Optional fallback title"
            maxLength={180}
          />
        </label>
      ) : null}

      <fieldset className="space-y-2">
        <legend className="text-sm font-bold text-ink">What should Subskills do?</legend>
        <label className="focus-within:ring-focus flex items-start gap-3 rounded-md border border-divider bg-bg px-3 py-2 text-sm font-medium text-muted">
          <input
            type="checkbox"
            checked={addToWatchLater}
            onChange={(event) => setAddToWatchLater(event.target.checked)}
            className="mt-1"
          />
          <span>
            <span className="block font-bold text-ink">Add to Watch later</span>
            <span className="block">Keep it in your private library.</span>
          </span>
        </label>
        <label className="focus-within:ring-focus flex items-start gap-3 rounded-md border border-divider bg-bg px-3 py-2 text-sm font-medium text-muted">
          <input
            type="checkbox"
            checked={suggestToCatalog}
            onChange={(event) => setSuggestToCatalog(event.target.checked)}
            className="mt-1"
          />
          <span>
            <span className="block font-bold text-ink">Also suggest to the catalogue</span>
            <span className="block">Send it for review before it can appear publicly.</span>
          </span>
        </label>
      </fieldset>

      <div className="grid gap-4 sm:grid-cols-2">
        <label className="block">
          <span className="text-sm font-bold text-ink">Category</span>
          <select
            value={categoryId}
            onChange={(event) => onCategoryChange(event.target.value)}
            className="focus-ring mt-2 w-full rounded-md border border-divider bg-bg px-3 py-2 text-base text-ink"
          >
            {catalogs.map((catalog) => (
              <option key={catalog.category.id} value={catalog.category.id}>
                {catalog.category.name}
              </option>
            ))}
          </select>
        </label>
        <label className="block">
          <span className="text-sm font-bold text-ink">Skill</span>
          <select
            value={skillId}
            onChange={(event) => setSkillId(event.target.value)}
            className="focus-ring mt-2 w-full rounded-md border border-divider bg-bg px-3 py-2 text-base text-ink"
          >
            {(selectedCatalog?.skills ?? []).map((skill) => (
              <option key={skill.id} value={skill.id}>
                {skill.name}
              </option>
            ))}
          </select>
        </label>
      </div>

      <fieldset>
        <legend className="text-sm font-bold text-ink">Level</legend>
        <div className="mt-2 flex flex-wrap gap-2">
          <label className="focus-within:ring-focus inline-flex items-center gap-2 rounded-md border border-divider px-3 py-2 text-sm font-bold text-muted">
            <input
              type="radio"
              name="level"
              checked={level === ""}
              onChange={() => setLevel("")}
            />
            Not sure
          </label>
          {LEVELS.map((item) => (
            <label
              key={item.value}
              className="focus-within:ring-focus inline-flex items-center gap-2 rounded-md border border-divider px-3 py-2 text-sm font-bold text-muted"
            >
              <input
                type="radio"
                name="level"
                checked={level === item.value}
                onChange={() => setLevel(item.value)}
              />
              {item.label}
            </label>
          ))}
        </div>
      </fieldset>

      <label className="block">
        <span className="text-sm font-bold text-ink">Public note</span>
        <textarea
          value={note}
          onChange={(event) => setNote(event.target.value.slice(0, 140))}
          className="focus-ring mt-2 min-h-24 w-full rounded-md border border-divider bg-bg px-3 py-2 text-base text-ink"
          placeholder="Why is this useful?"
          maxLength={140}
        />
        <span className="mt-1 block text-right text-xs text-faint">{note.length}/140</span>
      </label>

      <button
        type="submit"
        disabled={isSubmitting || (!addToWatchLater && !suggestToCatalog)}
        className="focus-ring inline-flex w-full items-center justify-center rounded-md bg-ink px-4 py-2.5 text-sm font-bold text-surface transition hover:opacity-90 disabled:opacity-60"
      >
        {isSubmitting ? "Submitting..." : "Save / suggest link"}
      </button>

      {status ? <p className="text-sm font-bold text-accent">{status}</p> : null}
      {error ? <p className="text-sm font-bold text-red-600">{error}</p> : null}
    </form>
  );
}
