"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";
import { GripVertical } from "lucide-react";
import type { SkillResource } from "@skillsaggregator/shared";
import { PageHeader } from "@/components/PageHeader";
import { ResourceCard } from "@/components/ResourceCard";
import { SuggestLinkButton } from "@/components/SuggestLinkButton";
import { getBrowserSupabase } from "@/lib/browserSupabase";
import {
  type LibraryResourceRow,
  shapeLibraryResource,
} from "@/lib/resourceRows";

type LibraryView = "saved" | "watched";

// get_user_library_resources is shared with the app, which has no use for the web's
// rehosted thumbnails, so their keys come from links directly. In batches: the ids
// travel in the URL. On any error the cards keep their original thumbnails.
async function loadWebThumbnailKeys(linkIds: Array<string | null | undefined>) {
  const keys = new Map<string, string>();
  const supabase = getBrowserSupabase();
  const ids = [...new Set(linkIds.filter((id): id is string => Boolean(id)))];
  if (!supabase) return keys;
  for (let start = 0; start < ids.length; start += 100) {
    const { data, error } = await supabase
      .from("links")
      .select("id, web_thumbnail_key")
      .in("id", ids.slice(start, start + 100))
      .not("web_thumbnail_key", "is", null);
    if (error) return keys;
    for (const row of (data ?? []) as Array<{ id: string; web_thumbnail_key: string | null }>) {
      if (row.web_thumbnail_key) keys.set(row.id, row.web_thumbnail_key);
    }
  }
  return keys;
}
type UserSkillProgress = {
  skill_id: string;
  total_count: number;
  watched_count: number;
  target: number;
  completed: boolean;
};

export function SavedResourceBrowser() {
  const [view, setView] = useState<LibraryView>("saved");
  const [signedIn, setSignedIn] = useState<boolean | null>(null);
  const [isAnonymous, setIsAnonymous] = useState(false);
  const [resources, setResources] = useState<SkillResource[]>([]);
  const [selectedSkillId, setSelectedSkillId] = useState("all");
  const [progressBySkill, setProgressBySkill] = useState<Map<string, UserSkillProgress>>(() => new Map());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const loadedKeyRef = useRef<string | null>(null);
  const inFlightKeyRef = useRef<string | null>(null);
  const draggedIdRef = useRef<string | null>(null);

  const refresh = useCallback(async () => {
    const supabase = getBrowserSupabase();
    if (!supabase) {
      setSignedIn(false);
      setIsAnonymous(false);
      setResources([]);
      setLoading(false);
      setError("Library resources cannot be loaded until Supabase public env vars are available.");
      return;
    }

    const {
      data: { session },
      error: sessionError,
    } = await supabase.auth.getSession();
    if (sessionError) console.warn("library_session_load_failed", sessionError.message);
    const user = session?.user ?? null;
    setSignedIn(Boolean(user));
    setIsAnonymous(Boolean(user?.is_anonymous));
    setError(null);

    if (!user) {
      loadedKeyRef.current = null;
      setIsAnonymous(false);
      setResources([]);
      setLoading(false);
      return;
    }

    const idsKey = `${user.id}:${view}`;
    if (loadedKeyRef.current === idsKey) {
      setLoading(false);
      return;
    }
    if (inFlightKeyRef.current === idsKey) return;

    inFlightKeyRef.current = idsKey;
    setLoading(true);
    const { data, error: queryError } = await supabase.rpc("get_user_library_resources", {
      p_view: view,
    });

    if (inFlightKeyRef.current === idsKey) inFlightKeyRef.current = null;

    if (queryError) {
      setError(queryError.message);
      setResources([]);
      setLoading(false);
      return;
    }

    const rows = (data ?? []) as LibraryResourceRow[];
    const webThumbnailKeys = await loadWebThumbnailKeys(rows.map((row) => row.link_id));
    setResources(rows.flatMap((row) => {
      const resource = shapeLibraryResource({ ...row, web_thumbnail_key: webThumbnailKeys.get(row.link_id) ?? null });
      return resource ? [resource] : [];
    }));
    loadedKeyRef.current = idsKey;
    setLoading(false);
  }, [view]);

  const skillOptions = useMemo(() => {
    const bySkill = new Map<string, { id: string; name: string; count: number }>();
    for (const resource of resources) {
      const skill = resource.skill;
      if (!skill?.id) continue;
      const current = bySkill.get(skill.id);
      bySkill.set(skill.id, {
        id: skill.id,
        name: skill.name,
        count: (current?.count ?? 0) + 1,
      });
    }
    return [...bySkill.values()].sort((a, b) => a.name.localeCompare(b.name));
  }, [resources]);
  const skillIdsKey = useMemo(
    () => skillOptions.map((skill) => skill.id).join(","),
    [skillOptions],
  );
  const visibleResources = useMemo(() => {
    if (selectedSkillId === "all") return resources;
    return resources.filter((resource) => resource.skill?.id === selectedSkillId);
  }, [resources, selectedSkillId]);

  useEffect(() => {
    if (selectedSkillId === "all") return;
    if (!skillOptions.some((skill) => skill.id === selectedSkillId)) {
      setSelectedSkillId("all");
    }
  }, [selectedSkillId, skillOptions]);

  useEffect(() => {
    const supabase = getBrowserSupabase();
    const skillIds = skillIdsKey ? skillIdsKey.split(",").filter(Boolean) : [];
    if (!supabase || !signedIn || skillIds.length === 0) {
      setProgressBySkill(new Map());
      return;
    }

    let cancelled = false;
    // An arrow, not a function declaration: declarations are hoisted, so TypeScript
    // drops the `!supabase` narrowing above inside them and the build fails.
    const loadProgress = async () => {
      try {
        const { data, error: progressError } = await supabase.rpc("get_user_skill_progress", {
          p_skill_ids: skillIds,
        });
        if (cancelled) return;
        if (progressError) {
          console.warn("library_skill_progress_load_failed", {
            message: progressError.message,
            skillCount: skillIds.length,
          });
          setProgressBySkill(new Map());
          return;
        }
        const next = new Map<string, UserSkillProgress>();
        for (const row of (data ?? []) as UserSkillProgress[]) {
          next.set(row.skill_id, row);
        }
        setProgressBySkill(next);
      } catch (progressError) {
        if (cancelled) return;
        console.warn("library_skill_progress_load_failed", {
          message: progressError instanceof Error ? progressError.message : String(progressError),
          skillCount: skillIds.length,
        });
        setProgressBySkill(new Map());
      }
    };

    void loadProgress();

    return () => {
      cancelled = true;
    };
  }, [signedIn, skillIdsKey]);

  useEffect(() => {
    void refresh();
    function onFocus() {
      void refresh();
    }
    window.addEventListener("focus", onFocus);

    const supabase = getBrowserSupabase();
    const authListener = supabase?.auth.onAuthStateChange(() => {
      loadedKeyRef.current = null;
      void refresh();
    });
    const subscription = authListener?.data.subscription;

    return () => {
      window.removeEventListener("focus", onFocus);
      subscription?.unsubscribe();
    };
  }, [refresh]);

  function bookmarkId(resource: SkillResource) {
    return resource.personal_list_id ?? null;
  }

  async function persistSavedOrder(nextResources: SkillResource[], previousResources: SkillResource[]) {
    const supabase = getBrowserSupabase();
    const ids = nextResources.map(bookmarkId).filter((id): id is string => Boolean(id));
    if (!supabase || ids.length !== nextResources.length) return;
    setResources(nextResources);
    setError(null);
    const { error: reorderError } = await supabase.rpc("reorder_user_bookmarks", {
      p_bookmark_ids: ids,
    });
    if (reorderError) {
      setResources(previousResources);
      setError(reorderError.message);
      console.warn("library_reorder_failed", {
        message: reorderError.message,
        ids,
      });
      return;
    }
    console.info("library_reorder_saved", {
      count: ids.length,
    });
  }

  function moveDraggedResource(targetId: string | null) {
    if (view !== "saved" || !targetId) return;
    const draggedId = draggedIdRef.current;
    draggedIdRef.current = null;
    if (!draggedId || draggedId === targetId) return;
    const previousResources = resources;
    const from = previousResources.findIndex((resource) => bookmarkId(resource) === draggedId);
    const to = previousResources.findIndex((resource) => bookmarkId(resource) === targetId);
    if (from < 0 || to < 0) return;
    const nextResources = [...previousResources];
    const [moved] = nextResources.splice(from, 1);
    if (!moved) return;
    nextResources.splice(to, 0, moved);
    void persistSavedOrder(nextResources, previousResources);
  }

  function applySavedChange(resource: SkillResource, saved: boolean) {
    if (view !== "saved" || saved) return;
    setResources((current) => current.filter((item) => item.id !== resource.id));
    loadedKeyRef.current = null;
  }

  function applyWatchedChange(resource: SkillResource, watched: boolean) {
    if (view !== "saved" || !watched) return;
    setResources((current) => current.filter((item) => item.id !== resource.id));
    loadedKeyRef.current = null;
  }

  return (
    <div className="pb-20">
      <PageHeader
        title="Library"
        subtitle="Watch later and watched resources tied to your private Subskills identity."
        backHref="/"
        rightAccessory={<SuggestLinkButton />}
      />

      <section className="mx-auto mt-10 max-w-5xl px-4">
        <div className="mb-6 inline-flex rounded-lg bg-bgGroup p-1">
          {(["saved", "watched"] as const).map((item) => (
            <button
              key={item}
              type="button"
              onClick={() => {
                loadedKeyRef.current = null;
                setSelectedSkillId("all");
                setView(item);
              }}
              className={`focus-ring rounded-md px-4 py-2 text-sm font-bold capitalize transition ${
                view === item ? "bg-surface text-ink shadow-sm" : "text-muted hover:text-ink"
              }`}
            >
              {item === "saved" ? "Watch later" : "Watched"}
            </button>
          ))}
        </div>
        {skillOptions.length > 0 ? (
          <SkillFilterChips
            skills={skillOptions}
            selectedSkillId={selectedSkillId}
            progressBySkill={progressBySkill}
            onSelect={setSelectedSkillId}
          />
        ) : null}
        {loading ? <p className="text-sm text-muted">Loading {view === "saved" ? "Watch later" : view} resources...</p> : null}
        {!loading && error ? <p className="text-sm font-medium text-red-600">{error}</p> : null}
        {!loading && !error && signedIn === false ? (
          <p className="text-sm text-muted">
            Save a resource, mark one watched, vote, or suggest a link to start a private library automatically.{" "}
            <Link className="focus-ring font-bold text-ink underline underline-offset-2" href="/sign-in?next=/saved">
              Add email or Google
            </Link>{" "}
            when you want to keep it across devices.
          </p>
        ) : null}
        {!loading && !error && signedIn && isAnonymous && resources.length > 0 ? (
          <p className="mb-5 rounded-md bg-bgGroup px-3 py-2 text-sm text-muted">
            This library is saved to this browser.{" "}
            <Link className="focus-ring font-bold text-ink underline underline-offset-2" href="/sign-in?next=/saved">
              Add email or Google
            </Link>{" "}
            to keep it if you change devices or clear browser data.
          </p>
        ) : null}
        {!loading && !error && signedIn && resources.length === 0 ? (
          <p className="text-sm text-muted">
            {view === "saved"
              ? "Your Watch later is empty. Use the bookmark button on any resource to keep it here."
              : "Nothing watched yet. Use the check button on a resource after you watch it."}
          </p>
        ) : null}
        {!loading && !error && signedIn && resources.length > 0 && visibleResources.length === 0 ? (
          <p className="text-sm text-muted">No resources match this skill filter.</p>
        ) : null}
        {visibleResources.length > 0 ? (
          <div className="divide-y divide-divider">
            {visibleResources.map((resource) => {
              const id = bookmarkId(resource);
              const canReorder = view === "saved" && selectedSkillId === "all" && Boolean(id);
              return (
                <div
                  key={resource.id}
                  className="py-5"
                  draggable={canReorder}
                  onDragStart={() => {
                    draggedIdRef.current = id;
                  }}
                  onDragOver={(event) => {
                    if (canReorder) event.preventDefault();
                  }}
                  onDrop={() => moveDraggedResource(id)}
                >
                  <div className="flex gap-3">
                    {canReorder ? (
                      <span
                        className="mt-9 hidden cursor-grab text-faint sm:inline-flex"
                        aria-label="Drag to reorder"
                        title="Drag to reorder"
                      >
                        <GripVertical className="h-5 w-5" />
                      </span>
                    ) : null}
                    <div className="min-w-0 flex-1">
                      <ResourceCard
                        resource={resource}
                        initialSaved={view === "saved" || Boolean(resource.personal_list_id)}
                        initialWatched={view === "watched"}
                        onSavedChange={applySavedChange}
                        onWatchedChange={applyWatchedChange}
                      />
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        ) : null}
      </section>
    </div>
  );
}

function progressPercent(row: UserSkillProgress | undefined) {
  if (!row || row.target <= 0) return 0;
  return Math.min(100, Math.round((Math.min(row.watched_count, row.target) / row.target) * 100));
}

function SkillFilterChips({
  skills,
  selectedSkillId,
  progressBySkill,
  onSelect,
}: {
  skills: Array<{ id: string; name: string; count: number }>;
  selectedSkillId: string;
  progressBySkill: Map<string, UserSkillProgress>;
  onSelect: (skillId: string) => void;
}) {
  return (
    <div className="mb-6 flex gap-2 overflow-x-auto pb-2 no-scrollbar">
      <SkillFilterChip
        label="All"
        count={skills.reduce((total, skill) => total + skill.count, 0)}
        selected={selectedSkillId === "all"}
        progress={100}
        onClick={() => onSelect("all")}
      />
      {skills.map((skill) => (
        <SkillFilterChip
          key={skill.id}
          label={skill.name}
          count={skill.count}
          selected={selectedSkillId === skill.id}
          progress={progressPercent(progressBySkill.get(skill.id))}
          onClick={() => onSelect(skill.id)}
        />
      ))}
    </div>
  );
}

function SkillFilterChip({
  label,
  count,
  selected,
  progress,
  onClick,
}: {
  label: string;
  count: number;
  selected: boolean;
  progress: number;
  onClick: () => void;
}) {
  const boundedProgress = Math.max(0, Math.min(100, progress));
  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={selected}
      aria-label={`${label}, ${count} ${count === 1 ? "resource" : "resources"}, ${boundedProgress}% progress`}
      className={`focus-ring w-36 shrink-0 rounded-md border px-3 py-2 text-left transition ${
        selected
          ? "border-ink bg-ink text-surface"
          : "border-divider bg-surface text-muted hover:text-ink"
      }`}
    >
      <span className="block truncate text-xs font-extrabold">{label}</span>
      <span className={`mt-2 block h-1 overflow-hidden rounded-full ${selected ? "bg-white/25" : "bg-bgGroup"}`}>
        <span
          className={`block h-full rounded-full ${selected ? "bg-surface" : "bg-muted"}`}
          style={{ width: `${boundedProgress}%` }}
        />
      </span>
    </button>
  );
}
