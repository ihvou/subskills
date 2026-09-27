"use client";

import { Search, X } from "lucide-react";

interface SkillSearchProps {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  label?: string;
}

export function SkillSearch({
  value,
  onChange,
  placeholder = "Search skills",
  label = "Search",
}: SkillSearchProps) {
  return (
    <label className="block">
      <span className="sr-only">{label}</span>
      <span className="focus-within:ring-accent/35 flex min-h-12 items-center gap-3 rounded-lg border border-divider bg-surface px-3 shadow-sm ring-0 transition focus-within:ring-4">
        <Search className="h-5 w-5 shrink-0 text-muted" />
        <input
          value={value}
          onChange={(event) => onChange(event.target.value)}
          placeholder={placeholder}
          type="search"
          autoComplete="off"
          // Chrome draws its own clear button inside type="search", right next to
          // the one below it, so a filled box showed two X's.
          className="min-w-0 flex-1 bg-transparent text-base font-semibold text-ink outline-none placeholder:text-faint [&::-webkit-search-cancel-button]:appearance-none"
        />
        {value ? (
          <button
            type="button"
            onClick={() => onChange("")}
            className="focus-ring inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-muted transition hover:bg-bgGroup hover:text-ink"
            aria-label="Clear search"
          >
            <X className="h-4 w-4" />
          </button>
        ) : null}
      </span>
    </label>
  );
}
