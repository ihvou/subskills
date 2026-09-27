"use client";

import { useEffect, useRef, useState } from "react";
import { Check, MoreHorizontal } from "lucide-react";
import type { ResourceSourceFilter, SkillLevel } from "@skillsaggregator/shared";
import type { ResourceSort } from "@/lib/data";

interface SortFilterMenuProps {
  currentLevel: SkillLevel | null;
  currentSort: ResourceSort;
  currentSource: ResourceSourceFilter;
  onLevelChange: (level: SkillLevel | null) => void;
  onSortChange: (sort: ResourceSort) => void;
  onSourceChange: (source: ResourceSourceFilter) => void;
}

const SORTS: Array<{ value: ResourceSort; label: string }> = [
  { value: "popular", label: "Popular" },
  { value: "newest", label: "Newest" },
];

const LEVELS: Array<{ value: "all" | SkillLevel; label: string }> = [
  { value: "all", label: "All levels" },
  { value: "beginner", label: "Beginner" },
  { value: "intermediate", label: "Intermediate" },
  { value: "advanced", label: "Advanced" },
];

const SOURCES: Array<{ value: ResourceSourceFilter; label: string }> = [
  { value: "all", label: "All sources" },
  { value: "youtube", label: "YouTube" },
  { value: "tiktok", label: "TikTok" },
  { value: "instagram", label: "Instagram" },
];

/**
 * Web counterpart to the mobile SortFilterSheet: a single dropdown anchored
 * to the "more" button that surfaces sort and filter options at once.
 * Selecting an option updates client-side state only; the canonical category
 * and skill pages stay static/ISR and filter clicks do not create server
 * renders for query-string permutations.
 */
export function SortFilterMenu({
  currentLevel,
  currentSort,
  currentSource,
  onLevelChange,
  onSortChange,
  onSourceChange,
}: SortFilterMenuProps) {
  const [open, setOpen] = useState(false);
  const buttonRef = useRef<HTMLButtonElement>(null);
  const menuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    function onClick(event: MouseEvent) {
      const target = event.target as Node;
      if (
        buttonRef.current?.contains(target) ||
        menuRef.current?.contains(target)
      ) {
        return;
      }
      setOpen(false);
    }
    function onKey(event: KeyboardEvent) {
      if (event.key === "Escape") setOpen(false);
    }
    document.addEventListener("mousedown", onClick);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onClick);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  function selectSort(value: ResourceSort) {
    onSortChange(value);
    setOpen(false);
  }

  function selectLevel(value: "all" | SkillLevel) {
    onLevelChange(value === "all" ? null : value);
    setOpen(false);
  }

  function selectSource(value: ResourceSourceFilter) {
    onSourceChange(value);
    setOpen(false);
  }

  return (
    <div className="relative">
      <button
        ref={buttonRef}
        type="button"
        onClick={() => setOpen((current) => !current)}
        aria-haspopup="menu"
        aria-expanded={open}
        aria-label="Sort and filter"
        className="focus-ring inline-flex h-10 w-10 items-center justify-center rounded-full bg-surface shadow-pill ring-1 ring-divider transition hover:bg-bgGroup"
      >
        <MoreHorizontal className="h-5 w-5 text-ink" />
      </button>
      {open ? (
        <div
          ref={menuRef}
          role="menu"
          className="absolute right-0 z-20 mt-2 w-72 origin-top-right rounded-2xl bg-surface p-3 shadow-panel ring-1 ring-divider"
        >
          <p className="px-2 pb-1 text-xs font-bold uppercase tracking-wide text-muted">
            Sort by
          </p>
          {SORTS.map((option) => {
            const selected = option.value === currentSort;
            return (
              <button
                key={`sort-${option.value}`}
                type="button"
                role="menuitemradio"
                aria-checked={selected}
                onClick={() => selectSort(option.value)}
                className="focus-ring flex w-full items-center justify-between rounded-lg px-3 py-2 text-left transition hover:bg-bgGroup"
              >
                <span
                  className={`text-sm ${selected ? "font-bold text-ink" : "font-medium text-text"}`}
                >
                  {option.label}
                </span>
                {selected ? <Check className="h-4 w-4 text-accent" strokeWidth={3} /> : null}
              </button>
            );
          })}

          <div className="my-2 h-px bg-divider" />

          <p className="px-2 pb-1 text-xs font-bold uppercase tracking-wide text-muted">
            Filter by level
          </p>
          {LEVELS.map((option) => {
            const selected = option.value === (currentLevel ?? "all");
            return (
              <button
                key={`level-${option.value}`}
                type="button"
                role="menuitemradio"
                aria-checked={selected}
                onClick={() => selectLevel(option.value)}
                className="focus-ring flex w-full items-center justify-between rounded-lg px-3 py-2 text-left transition hover:bg-bgGroup"
              >
                <span
                  className={`text-sm ${selected ? "font-bold text-ink" : "font-medium text-text"}`}
                >
                  {option.label}
                </span>
                {selected ? <Check className="h-4 w-4 text-accent" strokeWidth={3} /> : null}
              </button>
            );
          })}

          <div className="my-2 h-px bg-divider" />

          <p className="px-2 pb-1 text-xs font-bold uppercase tracking-wide text-muted">
            Filter by source
          </p>
          {SOURCES.map((option) => {
            const selected = option.value === currentSource;
            return (
              <button
                key={`source-${option.value}`}
                type="button"
                role="menuitemradio"
                aria-checked={selected}
                onClick={() => selectSource(option.value)}
                className="focus-ring flex w-full items-center justify-between rounded-lg px-3 py-2 text-left transition hover:bg-bgGroup"
              >
                <span
                  className={`text-sm ${selected ? "font-bold text-ink" : "font-medium text-text"}`}
                >
                  {option.label}
                </span>
                {selected ? <Check className="h-4 w-4 text-accent" strokeWidth={3} /> : null}
              </button>
            );
          })}
        </div>
      ) : null}
    </div>
  );
}
