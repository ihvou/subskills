"use client";

import { useEffect, useId, useRef, useState, type KeyboardEvent, type ReactNode } from "react";
import {
  Bookmark,
  BookmarkCheck,
  CircleCheck,
  Flag,
  MoreHorizontal,
  ThumbsDown,
  ThumbsUp,
} from "lucide-react";

interface ResourceActionMenuProps {
  isSaved: boolean;
  isWatched: boolean;
  vote: number;
  onToggleSaved: () => void;
  onToggleWatched: () => void;
  onUpvote: () => void;
  onDownvote: () => void;
  reportHref: string;
}

function MenuItem({ icon, label, onSelect }: { icon: ReactNode; label: string; onSelect: () => void }) {
  return (
    <button
      type="button"
      role="menuitem"
      onClick={onSelect}
      className="focus-ring flex w-full items-center gap-2.5 rounded-lg px-2.5 py-2 text-left text-sm font-medium text-text transition hover:bg-bgGroup"
    >
      {icon}
      {label}
    </button>
  );
}

/**
 * The card's "⋯" menu: every action on the card, named in words, for anyone the
 * icons don't speak to, plus Report. Report lives only here, and the menu renders
 * only while open, so the report link is not in the page's HTML: it was one
 * crawlable /support?... URL per video (robots.txt blocks the ones already found).
 */
export function ResourceActionMenu({
  isSaved,
  isWatched,
  vote,
  onToggleSaved,
  onToggleWatched,
  onUpvote,
  onDownvote,
  reportHref,
}: ResourceActionMenuProps) {
  const [open, setOpen] = useState(false);
  const buttonRef = useRef<HTMLButtonElement>(null);
  const menuRef = useRef<HTMLDivElement>(null);
  const menuId = useId();

  useEffect(() => {
    if (!open) return;
    menuRef.current?.querySelector<HTMLElement>('[role="menuitem"]')?.focus();
    function onPointerDown(event: PointerEvent) {
      const target = event.target as Node;
      if (!menuRef.current?.contains(target) && !buttonRef.current?.contains(target)) setOpen(false);
    }
    document.addEventListener("pointerdown", onPointerDown);
    return () => document.removeEventListener("pointerdown", onPointerDown);
  }, [open]);

  function closeAndRefocus() {
    setOpen(false);
    buttonRef.current?.focus();
  }

  function run(action: () => void) {
    return () => {
      closeAndRefocus();
      action();
    };
  }

  function onMenuKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    const items = Array.from(menuRef.current?.querySelectorAll<HTMLElement>('[role="menuitem"]') ?? []);
    const index = items.indexOf(document.activeElement as HTMLElement);
    if (event.key === "Escape") {
      event.preventDefault();
      closeAndRefocus();
    } else if (event.key === "ArrowDown") {
      event.preventDefault();
      items[(index + 1) % items.length]?.focus();
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      items[(index - 1 + items.length) % items.length]?.focus();
    } else if (event.key === "Tab") {
      setOpen(false);
    }
  }

  const SavedIcon = isSaved ? BookmarkCheck : Bookmark;
  const iconClass = "h-4 w-4 shrink-0 text-muted";

  return (
    <div className="relative">
      <button
        ref={buttonRef}
        type="button"
        aria-label="More actions"
        aria-haspopup="menu"
        aria-expanded={open}
        aria-controls={open ? menuId : undefined}
        onClick={() => setOpen((value) => !value)}
        className="focus-ring inline-flex h-7 w-7 items-center justify-center rounded-md text-muted transition hover:bg-bgGroup hover:text-ink aria-expanded:bg-bgGroup aria-expanded:text-ink"
      >
        <MoreHorizontal className="h-5 w-5" />
      </button>
      {open ? (
        <div
          ref={menuRef}
          id={menuId}
          role="menu"
          aria-label="More actions"
          onKeyDown={onMenuKeyDown}
          className="absolute right-0 top-9 z-20 flex w-56 flex-col gap-0.5 rounded-xl bg-surface p-1.5 shadow-panel ring-1 ring-divider"
        >
          <MenuItem
            icon={<SavedIcon className={iconClass} />}
            label={isSaved ? "Remove from Watch later" : "Save to Watch later"}
            onSelect={run(onToggleSaved)}
          />
          <MenuItem
            icon={<CircleCheck className={iconClass} />}
            label={isWatched ? "Mark as not watched" : "Mark as watched"}
            onSelect={run(onToggleWatched)}
          />
          <MenuItem
            icon={<ThumbsUp className={iconClass} />}
            label={vote === 1 ? "Remove upvote" : "Upvote"}
            onSelect={run(onUpvote)}
          />
          <MenuItem
            icon={<ThumbsDown className={iconClass} />}
            label={vote === -1 ? "Remove downvote" : "Downvote"}
            onSelect={run(onDownvote)}
          />
          <div role="separator" className="mx-1.5 my-1 h-px bg-divider" />
          <a
            role="menuitem"
            href={reportHref}
            rel="nofollow"
            className="focus-ring flex w-full items-center gap-2.5 rounded-lg px-2.5 py-2 text-sm font-medium text-[#a32d2d] transition hover:bg-bgGroup"
          >
            <Flag className="h-4 w-4 shrink-0" />
            Report this video
          </a>
        </div>
      ) : null}
    </div>
  );
}
