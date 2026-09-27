"use client";

import Image from "next/image";
import { useState } from "react";
import {
  Bookmark,
  BookmarkCheck,
  Camera,
  CircleCheck,
  Globe,
  MessageCircle,
  Music2,
  PlaySquare,
  ThumbsDown,
  ThumbsUp,
  UserRound,
} from "lucide-react";
import {
  formatAggregateScore,
  getLinkSource,
  type ResourceComment,
  type SkillResource,
} from "@skillsaggregator/shared";
import { CommentAvatar, CommentsDialog } from "@/components/CommentsDialog";
import { OutboundLink } from "@/components/OutboundLink";
import { ResourceActionMenu } from "@/components/ResourceActionMenu";
import { useResourceActions } from "@/lib/useResourceActions";

interface ResourceCardProps {
  resource: SkillResource;
  initialSaved?: boolean;
  initialWatched?: boolean;
  onSavedChange?: (resource: SkillResource, saved: boolean) => void;
  onWatchedChange?: (resource: SkillResource, watched: boolean) => void;
}

function capitalize(value: string) {
  return value.charAt(0).toUpperCase() + value.slice(1);
}

function isPortraitResource(resource: SkillResource) {
  const source = getLinkSource(resource.link);
  return source === "tiktok" || source === "instagram";
}

function SourceIcon({ resource }: { resource: SkillResource }) {
  const source = getLinkSource(resource.link);
  if (source === "youtube") return <PlaySquare className="h-4 w-4 text-[#ff0000]" />;
  if (source === "tiktok") return <Music2 className="h-4 w-4 text-ink" />;
  if (source === "instagram") return <Camera className="h-4 w-4 text-[#c13584]" />;
  return <Globe className="h-4 w-4 text-faint" />;
}

function CatalogStatusChip({ resource }: { resource: SkillResource }) {
  const status = resource.catalog_status;
  if (!status) return null;
  const labels: Record<NonNullable<SkillResource["catalog_status"]>, string> = {
    private: "Private",
    in_review: "In review",
    in_catalog: "In catalogue",
    not_added: "Reviewed",
  };
  return (
    <span className="inline-flex items-center rounded-pill bg-bgGroup px-2.5 py-0.5 text-xs font-bold text-muted">
      {labels[status]}
    </span>
  );
}

/**
 * The comments to show: what the page loaded, newest first, or, where it loaded
 * none (the library, or before 0067 reaches the database), the coach's take as
 * the Reviewer's comment, which is what 0067 turns it into.
 */
function cardComments(resource: SkillResource): ResourceComment[] {
  if (resource.comments) return resource.comments;
  return resource.coach_take
    ? [{ id: `${resource.id}-take`, author: "Reviewer", body: resource.coach_take, created_at: null }]
    : [];
}

/**
 * Web counterpart to the mobile ResourceCard row.
 *  - 16/9 thumbnail (left, click → opens the video through /go)
 *  - Source + level pill (top), bold 2-line title (clickable). The title is link
 *    text, not a heading: headings are the page's own structure, not 30 creators'
 *    titles.
 *  - The two newest comments, two lines each; the count opens them in full.
 *  - Save / watched / vote inline, and every action named in words, plus Report,
 *    in the "⋯" menu.
 *  - State (save / watched / vote) is authenticated and stored server-side.
 */
export function ResourceCard({
  resource,
  initialSaved = false,
  initialWatched = false,
  onSavedChange,
  onWatchedChange,
}: ResourceCardProps) {
  const resolvedRelationId = resource.link_skill_relation_id ?? (resource.catalog_status ? null : resource.id);
  const relationId =
    resource.catalog_status && resource.catalog_status !== "in_catalog"
      ? null
      : resolvedRelationId;
  const {
    isSaved,
    isWatched,
    vote,
    error,
    toggleSaved,
    toggleWatched,
    combinedScore,
    setUserVote,
  } = useResourceActions(
    relationId,
    resource.link.id,
    resource.user_score ?? 0,
    resource.combined_score ?? null,
    { initialSaved, initialWatched },
  );

  // TikTok serves thumbnails from a SIGNED CDN URL carrying an `x-expires` stamp,
  // good for roughly 3-7 days; after that the host returns 403 and the card renders
  // a broken image. 117 of 120 stored TikTok thumbnails had expired when this was
  // added. YouTube is immune because the collector CONSTRUCTS a stable
  // i.ytimg.com/vi/<id>/hqdefault.jpg rather than storing a scraped URL.
  //
  // The real fix is mirroring into the link-thumbnails bucket at collection time.
  // This is the seatbelt: any image that fails to load falls back to the empty
  // state, which is a plain bgGroup rectangle and reads as deliberate.
  const [thumbnailFailed, setThumbnailFailed] = useState(false);
  const [commentsOpen, setCommentsOpen] = useState(false);
  const thumbnail = thumbnailFailed ? null : resource.link.thumbnail_url;
  const portrait = isPortraitResource(resource);
  const url = resource.link.url;
  const go = resource.link.go ?? null;
  const title = resource.link.title ?? "Untitled video";
  const comments = cardComments(resource);
  const contributor = resource.link.contributor_profile;

  function onUpvote() {
    void setUserVote(vote === 1 ? 0 : 1);
  }
  function onDownvote() {
    void setUserVote(vote === -1 ? 0 : -1);
  }
  async function onToggleSaved() {
    const next = !isSaved;
    if (await toggleSaved()) onSavedChange?.(resource, next);
  }
  async function onToggleWatched() {
    const next = !isWatched;
    if (await toggleWatched()) onWatchedChange?.(resource, next);
  }

  const SavedIcon = isSaved ? BookmarkCheck : Bookmark;
  const reportParams = new URLSearchParams({
    resource: relationId ?? resource.id,
    link: resource.link.id,
  });
  if (resource.link.title) reportParams.set("title", resource.link.title);
  const reportHref = `/support?${reportParams.toString()}`;
  const commentCountLabel = comments.length === 1 ? "1 comment" : `${comments.length} comments`;

  return (
    // Stacked (thumbnail above text) below `sm` — a fixed-width thumb in a row
    // leaves too little room for the title/actions on phone screens.
    <article className="flex flex-col gap-3 sm:flex-row sm:items-stretch sm:gap-4">
      <OutboundLink
        go={go}
        href={url}
        aria-label={title}
        className="focus-ring relative aspect-video w-full shrink-0 overflow-hidden rounded-[14px] bg-bgGroup shadow-thumb transition hover:opacity-90 sm:w-[240px] sm:self-start"
      >
        {thumbnail ? (
          <>
            {portrait ? (
              <Image
                src={thumbnail}
                alt=""
                fill
                sizes="(max-width: 639px) 100vw, 240px"
                className="scale-110 object-cover blur-md"
                aria-hidden="true"
              />
            ) : null}
            <Image
              src={thumbnail}
              alt={resource.link.title ?? ""}
              fill
              sizes="(max-width: 639px) 100vw, 240px"
              className={portrait ? "object-contain" : "object-cover"}
              // Only the foreground image reports failure; the blurred backdrop above
              // uses the same src, so one handler covers both.
              onError={() => setThumbnailFailed(true)}
            />
          </>
        ) : null}
      </OutboundLink>

      <div className="flex min-w-0 flex-1 flex-col gap-2 sm:py-1">
        <div className="flex items-center justify-between gap-2">
          <div className="flex min-w-0 items-center gap-2">
            <SourceIcon resource={resource} />
          </div>
          <div className="flex shrink-0 items-center gap-2">
            <CatalogStatusChip resource={resource} />
            {resource.skill_level ? (
              <span className="inline-flex items-center rounded-pill bg-muted px-2.5 py-0.5 text-xs font-bold text-surface">
                {capitalize(resource.skill_level)}
              </span>
            ) : null}
          </div>
        </div>

        <OutboundLink go={go} href={url} className="focus-ring block transition hover:opacity-90">
          <span className="line-clamp-2 text-lg font-bold leading-snug text-ink md:text-xl">{title}</span>
        </OutboundLink>

        {comments.slice(0, 2).map((comment) => (
          <div key={comment.id} className="flex items-start gap-2">
            <CommentAvatar author={comment.author} />
            <p className="line-clamp-2 text-sm leading-snug text-[#3a393f]">
              <span className="font-bold text-ink">{comment.author}</span> {comment.body}
            </p>
          </div>
        ))}

        <div className="mt-auto flex items-center justify-between gap-3 pt-1 text-sm">
          <div className="flex min-w-0 items-center gap-2">
            {comments.length > 0 ? (
              <button
                type="button"
                onClick={() => setCommentsOpen(true)}
                aria-label={`Show ${commentCountLabel}`}
                aria-haspopup="dialog"
                className="focus-ring inline-flex h-7 items-center gap-1.5 rounded-md pr-1 font-semibold text-[#5f5e63] transition hover:bg-bgGroup hover:text-ink"
              >
                <MessageCircle className="h-[18px] w-[18px]" />
                {comments.length}
              </button>
            ) : null}
            {contributor ? (
              <a
                href={`/contributors/${contributor.slug}`}
                className="focus-ring inline-flex shrink-0 items-center gap-1 rounded-md bg-bgGroup px-2 py-1 text-xs font-bold text-muted transition hover:text-ink"
              >
                <UserRound className="h-3.5 w-3.5" />
                via @{contributor.slug}
              </a>
            ) : null}
          </div>
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={() => void onToggleSaved()}
              aria-label={isSaved ? "Remove from Watch later" : "Add to Watch later"}
              aria-pressed={isSaved}
              className="focus-ring inline-flex h-7 w-7 items-center justify-center rounded-md transition hover:bg-bgGroup"
            >
              <SavedIcon
                className={`h-5 w-5 ${isSaved ? "text-accent" : "text-muted"}`}
                fill={isSaved ? "currentColor" : "transparent"}
                strokeWidth={2}
              />
            </button>
            <button
              type="button"
              onClick={() => void onToggleWatched()}
              aria-label={isWatched ? "Mark not watched" : "Mark watched"}
              aria-pressed={isWatched}
              className="focus-ring inline-flex h-7 w-7 items-center justify-center rounded-md transition hover:bg-bgGroup"
            >
              <CircleCheck
                className={`h-5 w-5 ${isWatched ? "text-accent" : "text-muted"}`}
                fill={isWatched ? "currentColor" : "transparent"}
                stroke={isWatched ? "#ffffff" : "currentColor"}
                strokeWidth={2}
              />
            </button>
            <div className="flex items-center gap-1">
              <button
                type="button"
                onClick={onUpvote}
                aria-label={vote === 1 ? "Remove upvote" : "Upvote"}
                aria-pressed={vote === 1}
                className="focus-ring inline-flex h-7 w-7 items-center justify-center rounded-md transition hover:bg-bgGroup"
              >
                <ThumbsUp
                  className={`h-5 w-5 ${vote === 1 ? "text-accent" : "text-muted"}`}
                  fill={vote === 1 ? "currentColor" : "transparent"}
                  strokeWidth={2}
                />
              </button>
              {/* The aggregate score, Reddit-style: one number between the arrows,
                  always present, and it moves when you vote. This is combined_score
                  (coach curation + damped community votes) — the same value the list
                  is sorted by — not the net vote count, which is zero on all but a
                  handful of rows and so would render blank almost everywhere. */}
              {combinedScore !== null ? (
                <span
                  aria-live="polite"
                  aria-label={`Score ${formatAggregateScore(combinedScore)}, from coach review and community votes`}
                  title="Coach review + community votes"
                  className={`min-w-[1.75rem] text-center text-sm font-semibold tabular-nums transition-colors ${
                    vote === 1 ? "text-accent" : vote === -1 ? "text-ink" : "text-muted"
                  }`}
                >
                  {formatAggregateScore(combinedScore)}
                </span>
              ) : null}
              <button
                type="button"
                onClick={onDownvote}
                aria-label={vote === -1 ? "Remove downvote" : "Downvote"}
                aria-pressed={vote === -1}
                className="focus-ring inline-flex h-7 w-7 items-center justify-center rounded-md transition hover:bg-bgGroup"
              >
                <ThumbsDown
                  className={`h-5 w-5 ${vote === -1 ? "text-ink" : "text-muted"}`}
                  fill={vote === -1 ? "currentColor" : "transparent"}
                  strokeWidth={2}
                />
              </button>
            </div>
            <ResourceActionMenu
              isSaved={isSaved}
              isWatched={isWatched}
              vote={vote}
              onToggleSaved={() => void onToggleSaved()}
              onToggleWatched={() => void onToggleWatched()}
              onUpvote={onUpvote}
              onDownvote={onDownvote}
              reportHref={reportHref}
            />
          </div>
        </div>
        {error ? <p className="text-xs font-bold text-red-600">{error}</p> : null}
      </div>
      {commentsOpen ? (
        <CommentsDialog title={title} comments={comments} onClose={() => setCommentsOpen(false)} />
      ) : null}
    </article>
  );
}
