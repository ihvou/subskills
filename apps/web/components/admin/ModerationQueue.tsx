"use client";

import { useEffect, useState, useTransition } from "react";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { Check, X } from "lucide-react";
import { createBrowserClient } from "@supabase/ssr";
import type { AdminSuggestion } from "@/lib/data";
import { approveSuggestion, declineSuggestion } from "@/app/admin/actions";
import { normalizeThumbnailUrl } from "@/lib/thumbnails";

interface ModerationQueueProps {
  initialSuggestions: AdminSuggestion[];
}

function getPreview(suggestion: AdminSuggestion) {
  const payload = suggestion.payload_json;
  if (suggestion.type === "SOURCE_ADD") {
    return {
      title: typeof payload.display_name === "string" ? payload.display_name : "New source",
      thumbnail: null,
      url: typeof payload.identifier === "string" ? payload.identifier : null,
      note:
        typeof payload.source_type === "string"
          ? `Source candidate: ${payload.source_type}`
          : "Source candidate",
      level: null,
    };
  }
  return {
    title:
      suggestion.link?.title ??
      (typeof payload.title === "string" ? payload.title : null) ??
      (typeof payload.url === "string" ? payload.url : "Untitled suggestion"),
    thumbnail:
      normalizeThumbnailUrl(
        suggestion.link?.thumbnail_storage_path ??
          (typeof payload.thumbnail_storage_path === "string" ? payload.thumbnail_storage_path : null) ??
          suggestion.link?.thumbnail_url ??
          (typeof payload.thumbnail_url === "string" ? payload.thumbnail_url : null),
        typeof payload.canonical_url === "string" ? payload.canonical_url : typeof payload.url === "string" ? payload.url : null,
        suggestion.link?.thumbnail_storage_path || typeof payload.thumbnail_storage_path === "string"
          ? suggestion.link?.thumbnail_url ?? (typeof payload.thumbnail_url === "string" ? payload.thumbnail_url : null)
          : null,
      ),
    url:
      typeof payload.canonical_url === "string"
        ? payload.canonical_url
        : typeof payload.url === "string"
          ? payload.url
          : null,
    note: typeof payload.public_note === "string" ? payload.public_note : null,
    level: typeof payload.skill_level === "string" ? payload.skill_level : null,
  };
}

function reviewLaneLabel(payload: Record<string, unknown>) {
  const lane = typeof payload.review_lane === "string" ? payload.review_lane : null;
  if (lane === "coach") return "Coach lane";
  if (lane === "founder") return "Founder lane";
  if (lane === "agent") return "Agent lane";
  if (lane === "private") return "Private";
  return null;
}

export function ModerationQueue({ initialSuggestions }: ModerationQueueProps) {
  const [suggestions, setSuggestions] = useState(initialSuggestions);
  const [isPending, startTransition] = useTransition();
  const router = useRouter();

  useEffect(() => {
    const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    if (!url || !anonKey) return;

    const supabase = createBrowserClient(url, anonKey);
    const channel = supabase
      .channel("moderation_queue")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "suggestions", filter: "status=eq.pending" },
        () => router.refresh(),
      )
      .subscribe();

    return () => {
      void supabase.removeChannel(channel);
    };
  }, [router]);

  useEffect(() => {
    setSuggestions(initialSuggestions);
  }, [initialSuggestions]);

  function decide(action: "approve" | "decline", suggestionId: string) {
    const formData = new FormData();
    formData.set("suggestion_id", suggestionId);
    startTransition(async () => {
      if (action === "approve") await approveSuggestion(formData);
      else await declineSuggestion(formData);
      setSuggestions((items) => items.filter((item) => item.id !== suggestionId));
    });
  }

  if (suggestions.length === 0) {
    return (
      <div className="rounded-lg border border-dashed border-ink/20 bg-white/70 p-6 text-sm leading-6 text-graphite">
        The moderation queue is empty.
      </div>
    );
  }

  return (
    <div className="grid gap-4">
      {suggestions.map((suggestion) => {
        const preview = getPreview(suggestion);
        const laneLabel = reviewLaneLabel(suggestion.payload_json);
        return (
          <article key={suggestion.id} className="rounded-lg border border-ink/10 bg-white p-4 shadow-sm">
            <div className="grid gap-4 md:grid-cols-[148px_1fr_auto]">
              <div className="relative aspect-video overflow-hidden rounded-md bg-ink/10">
                {preview.thumbnail ? (
                  <Image
                    src={preview.thumbnail}
                    alt={preview.title}
                    fill
                    sizes="148px"
                    className="object-cover"
                  />
                ) : (
                  <div className="flex h-full items-center justify-center text-xs text-graphite">
                    {suggestion.type}
                  </div>
                )}
              </div>
              <div className="min-w-0">
                <div className="flex flex-wrap items-center gap-2 text-xs font-medium uppercase tracking-wide text-graphite">
                  <span>{suggestion.type.replaceAll("_", " ")}</span>
                  <span>{suggestion.origin_name ?? suggestion.origin_type}</span>
                  {laneLabel ? <span>{laneLabel}</span> : null}
                  {suggestion.confidence ? <span>{Math.round(suggestion.confidence * 100)}%</span> : null}
                </div>
                <h2 className="mt-2 text-lg font-semibold text-ink">{preview.title}</h2>
                <p className="mt-1 text-sm text-graphite">
                  {suggestion.category?.name ?? "Category"} / {suggestion.skill?.name ?? "Skill"}
                </p>
                {preview.note ? <p className="mt-2 text-sm leading-6 text-graphite">{preview.note}</p> : null}
                {preview.url ? (
                  <a
                    className="focus-ring mt-2 inline-block truncate text-sm font-medium text-court hover:text-ink"
                    href={preview.url}
                    target="_blank"
                    rel="noreferrer"
                  >
                    {preview.url}
                  </a>
                ) : null}
                {suggestion.triangulation_json?.votes ? (
                  <div className="mt-3 flex flex-wrap gap-2">
                    {(suggestion.triangulation_json.votes as Array<{ model: string; approve: boolean; reason: string }>).map((vote) => (
                      <span
                        key={vote.model}
                        className="rounded-full bg-ink/5 px-2 py-1 text-xs text-graphite"
                        title={vote.reason}
                      >
                        {vote.model}: {vote.approve ? "approve" : "hold"}
                      </span>
                    ))}
                  </div>
                ) : null}
              </div>
              <div className="flex gap-2 md:flex-col">
                <button
                  type="button"
                  onClick={() => decide("approve", suggestion.id)}
                  disabled={isPending}
                  className="focus-ring inline-flex h-10 w-10 items-center justify-center rounded-md bg-court text-white hover:bg-ink disabled:opacity-50"
                  title="Approve suggestion"
                >
                  <Check className="h-4 w-4" aria-hidden="true" />
                  <span className="sr-only">Approve</span>
                </button>
                <button
                  type="button"
                  onClick={() => decide("decline", suggestion.id)}
                  disabled={isPending}
                  className="focus-ring inline-flex h-10 w-10 items-center justify-center rounded-md border border-ink/15 bg-white text-ink hover:border-amberline hover:text-amberline disabled:opacity-50"
                  title="Decline suggestion"
                >
                  <X className="h-4 w-4" aria-hidden="true" />
                  <span className="sr-only">Decline</span>
                </button>
              </div>
            </div>
          </article>
        );
      })}
    </div>
  );
}
