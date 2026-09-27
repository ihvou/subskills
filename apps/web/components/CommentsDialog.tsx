"use client";

import { useEffect, useId, useRef } from "react";
import { X } from "lucide-react";
import type { ResourceComment } from "@skillsaggregator/shared";

const AUTHOR_COLORS: Record<string, string> = {
  Moderator: "#5a6b7d",
  Reviewer: "#8a6a4f",
};
const MEMBER_COLORS = ["#4a6b8a", "#7a5a7d", "#5f7a4f", "#8a5a4f", "#4f6f7a"];

function authorColor(author: string) {
  const known = AUTHOR_COLORS[author];
  if (known) return known;
  let hash = 0;
  for (const char of author) hash = (hash * 31 + char.charCodeAt(0)) >>> 0;
  return MEMBER_COLORS[hash % MEMBER_COLORS.length]!;
}

export function CommentAvatar({ author, size = 22 }: { author: string; size?: number }) {
  return (
    <span
      aria-hidden="true"
      className="mt-0.5 inline-flex shrink-0 items-center justify-center rounded-full font-bold text-white"
      style={{
        width: size,
        height: size,
        fontSize: size > 24 ? 13 : 11,
        background: authorColor(author),
      }}
    >
      {author.charAt(0).toUpperCase()}
    </span>
  );
}

interface CommentsDialogProps {
  title: string;
  comments: ResourceComment[];
  onClose: () => void;
}

/**
 * Every comment on a video, in full. The card clamps each to two lines; this is
 * where they are read whole. Mounted only while open, so the page's HTML carries
 * each comment once. Nobody can post yet (M170), so there is no input.
 *
 * A native <dialog> opened with showModal(): it traps focus, closes on Escape and
 * hands focus back to the button that opened it. Centred on desktop, a bottom
 * sheet on phones; the list scrolls when it doesn't fit.
 */
export function CommentsDialog({ title, comments, onClose }: CommentsDialogProps) {
  const ref = useRef<HTMLDialogElement>(null);
  const headingId = useId();

  useEffect(() => {
    const dialog = ref.current;
    if (dialog && !dialog.open) dialog.showModal();
  }, []);

  const countLabel = comments.length === 1 ? "1 comment" : `${comments.length} comments`;

  return (
    <dialog
      ref={ref}
      aria-labelledby={headingId}
      onClose={onClose}
      onClick={(event) => {
        if (event.target === ref.current) ref.current?.close();
      }}
      className="m-0 mt-auto w-full max-w-none rounded-t-[20px] bg-surface p-0 text-text shadow-panel backdrop:bg-black/45 sm:m-auto sm:w-[620px] sm:max-w-[calc(100vw-2rem)] sm:rounded-[18px]"
    >
      <div className="flex max-h-[80vh] flex-col gap-4 px-4 pb-8 pt-3 sm:gap-5 sm:p-6">
        <span aria-hidden="true" className="mx-auto h-1 w-10 rounded-full bg-divider sm:hidden" />
        <div className="flex items-start justify-between gap-4">
          <div className="min-w-0">
            <h2 id={headingId} className="text-[17px] font-bold text-ink sm:text-xl">
              {countLabel}
            </h2>
            <p className="line-clamp-1 text-[13px] text-muted sm:text-sm">{title}</p>
          </div>
          <button
            type="button"
            onClick={() => ref.current?.close()}
            aria-label="Close comments"
            className="focus-ring inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-md text-text transition hover:bg-bgGroup"
          >
            <X className="h-5 w-5" />
          </button>
        </div>
        <ul className="flex min-h-0 flex-col gap-[18px] overflow-y-auto">
          {comments.map((comment) => (
            <li key={comment.id} className="flex items-start gap-2.5">
              <CommentAvatar author={comment.author} size={28} />
              <div className="min-w-0">
                <p className="text-[13px] font-bold text-ink">{comment.author}</p>
                <p className="text-[15px] leading-normal text-[#3a393f]">{comment.body}</p>
              </div>
            </li>
          ))}
        </ul>
      </div>
    </dialog>
  );
}
