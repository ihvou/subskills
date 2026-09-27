import { useEffect, useRef, useState } from "react";
import { Alert, Linking, Pressable, StyleSheet, Text, View } from "react-native";
import { Image } from "expo-image";
import * as Haptics from "expo-haptics";
import { useQueryClient } from "@tanstack/react-query";
import {
  Bookmark,
  BookmarkCheck,
  Camera,
  CircleCheck,
  Globe,
  Music2,
  PlaySquare,
  ThumbsDown,
  ThumbsUp,
} from "lucide-react-native";
import {
  boundedUserVoteWeight,
  formatAggregateScore,
  getLinkSource,
  type SkillResource,
} from "@skillsaggregator/shared";
import { useAuth } from "@/lib/auth";
import { recordWatchedForReviewPrompt } from "@/lib/storeReview";
import { getSupabase } from "@/lib/supabase";
import { colors, radius, shadows, spacing, typography } from "@/lib/theme";
import { openTutorialResource } from "@/lib/tutorialReturnPrompt";
import { ResourceActionSheet } from "./ResourceActionSheet";
import { webUrl } from "@/lib/webLinks";
import { track } from "@/lib/analytics";

interface ResourceCardProps {
  resource: SkillResource;
  initialSaved?: boolean;
  initialCompleted?: boolean;
  /**
   * Recess the card once it is marked watched (M128). Defaults on, because the
   * point of marking something watched is to stop having to look at it.
   *
   * Pass `false` wherever EVERY row is watched — the Library's Watched tab —
   * or the whole list renders dimmed and reads as disabled.
   */
  dimWhenWatched?: boolean;
  /**
   * The state this list already implies, whose toggle is therefore hidden.
   *
   * In Watch later every row is saved, so a filled bookmark says nothing — and
   * tapping it deletes the row outright, with no undo, from a 40pt target
   * sitting between three others. Same for the tick in Watched. Removal still
   * exists on long-press, where the sheet spells it out as "Remove from Watch
   * later" instead of relying on the user recognising a filled icon.
   */
  impliedState?: "saved" | "watched";
}

/**
 * The right-hand metadata column owns this height (4 visual rows: source+pill,
 * title line 1, title line 2, actions). The 16/9 thumbnail then
 * stretches to match it via `alignSelf: "stretch"` + `aspectRatio`, so 90 -> 160x90.
 */
const BODY_HEIGHT = 90;

function triggerSelectionHaptic() {
  Haptics.selectionAsync().catch(() => undefined);
}

function capitalize(value: string) {
  return value.charAt(0).toUpperCase() + value.slice(1);
}

// Small platform icon shown top-left in place of the domain text.
function SourceIcon({ link }: { link: SkillResource["link"] }) {
  const source = getLinkSource(link);
  if (source === "youtube") {
    return <PlaySquare size={15} color="#FF0000" />;
  }
  if (source === "tiktok") return <Music2 size={14} color={colors.ink} />;
  if (source === "instagram") return <Camera size={14} color="#C13584" />;
  return <Globe size={12} color={colors.faint} />;
}

function isPortraitResource(resource: SkillResource) {
  const source = getLinkSource(resource.link);
  return source === "tiktok" || source === "instagram";
}

/**
 * What happened to a link the user submitted (MI35). Only the states where the
 * card cannot otherwise say it.
 *
 * "In catalogue" is deliberately absent: `relationId` is non-null exactly when
 * `catalog_status` is `in_catalog`, and `canVote` follows `relationId`, so the
 * vote controls already mean "this is in the catalogue". Labelling it too put
 * the word on nearly every row in Watch later — most saves come from the
 * catalogue — to repeat what the thumbs were saying.
 *
 * The other three earn their place: none of them shows vote controls, so the
 * label is the only thing distinguishing a private save from one still in
 * review from one that was reviewed and not taken.
 */
function statusLabel(status: SkillResource["catalog_status"]) {
  if (status === "private") return "Private";
  if (status === "in_review") return "In review";
  if (status === "not_added") return "Reviewed";
  return null;
}

/**
 * Skill-screen resource row.
 *  - 16/9 thumbnail on the left at row height
 *  - Right column: top meta row (source + level pill), 2-line title, then the
 *    action row in two groups —
 *    Watch later | Watched  ......  Upvote | score | Downvote
 *  - Thumbnail/title taps open the URL; long-press opens the action sheet, which
 *    is where Report lives. Action buttons are siblings rather than nested inside
 *    a card-wide press handler.
 */
export function ResourceCard({
  resource,
  initialSaved = false,
  initialCompleted = false,
  dimWhenWatched = true,
  impliedState,
}: ResourceCardProps) {
  const resolvedRelationId = resource.link_skill_relation_id ?? (resource.catalog_status ? null : resource.id);
  const relationId =
    resource.catalog_status && resource.catalog_status !== "in_catalog"
      ? null
      : resolvedRelationId;
  const linkId = resource.link.id;
  const { user, ensureSession } = useAuth();
  const queryClient = useQueryClient();
  const savedFromResource = initialSaved || Boolean(resource.personal_list_id);
  const [isSaved, setIsSaved] = useState(savedFromResource);
  const [isCompleted, setIsCompleted] = useState(initialCompleted);
  const [vote, setVote] = useState<-1 | 0 | 1>(0);
  const [menuOpen, setMenuOpen] = useState(false);
  const [userScore, setUserScore] = useState(resource.user_score ?? 0);
  const [baseScore, setBaseScore] = useState<number | null>(
    typeof resource.combined_score === "number" && Number.isFinite(resource.combined_score)
      ? resource.combined_score - boundedUserVoteWeight(resource.user_score)
      : null,
  );
  const combinedScore = baseScore === null ? null : baseScore + boundedUserVoteWeight(userScore);

  useEffect(() => {
    setIsSaved(savedFromResource);
    setIsCompleted(initialCompleted);
    setUserScore(resource.user_score ?? 0);
    setBaseScore(
      typeof resource.combined_score === "number" && Number.isFinite(resource.combined_score)
        ? resource.combined_score - boundedUserVoteWeight(resource.user_score)
        : null,
    );
  }, [initialCompleted, resource.combined_score, resource.id, resource.user_score, savedFromResource]);

  // How many writes this card has in flight. Read by loadState, which must not
  // apply a server read that raced one of them.
  const writesInFlight = useRef(0);

  useEffect(() => {
    let cancelled = false;
    const supabase = getSupabase();
    if (!supabase || !user) {
      setIsSaved(savedFromResource);
      setIsCompleted(initialCompleted);
      setVote(0);
      return;
    }
    const supabaseClient = supabase;
    const currentUser = user;

    async function loadState() {
      const [bookmarkResult, watchedResult, voteResult] = await Promise.all([
        supabaseClient
          .from("user_bookmarks")
          .select("created_at")
          .eq("user_id", currentUser.id)
          .eq("link_id", linkId)
          .maybeSingle(),
        // Keyed on the link, not the relation (M158): a private save has no
        // relation, and the same video watched under one skill is watched
        // everywhere it appears.
        supabaseClient
          .from("user_watched")
          .select("watched_at")
          .eq("user_id", currentUser.id)
          .eq("link_id", linkId)
          .maybeSingle(),
        relationId
          ? supabaseClient
              .from("user_relation_votes")
              .select("vote")
              .eq("user_id", currentUser.id)
              .eq("link_skill_relation_id", relationId)
              .maybeSingle()
          : Promise.resolve({ data: null, error: null }),
      ]);
      if (cancelled) return;
      // A read that started before a write can still land after it, carrying the
      // pre-write value and overwriting what the user just did. That is M164:
      // the first save signs the user in anonymously, `user` changes, this
      // effect re-runs mid-write, and the fresh read says "not saved" — so the
      // bookmark icon emptied itself even though the row was written. Drop the
      // read instead; the write is the newer truth.
      if (writesInFlight.current > 0) return;
      if (bookmarkResult.error) console.warn("[resource-actions] Bookmark load failed", bookmarkResult.error.message);
      if (watchedResult.error) console.warn("[resource-actions] Watched load failed", watchedResult.error.message);
      if (voteResult.error) console.warn("[resource-actions] Vote load failed", voteResult.error.message);
      setIsSaved(Boolean(bookmarkResult.data));
      setIsCompleted(Boolean(watchedResult.data));
      setVote(voteResult.data?.vote === -1 ? -1 : voteResult.data?.vote === 1 ? 1 : 0);
    }

    void loadState();
    return () => {
      cancelled = true;
    };
  }, [initialCompleted, linkId, relationId, savedFromResource, user]);

  async function ensureActionSession(action: string) {
    try {
      return await ensureSession(action);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.warn("[resource-actions] Anonymous session creation failed", {
        relationId,
        linkId,
        action,
        error: message,
      });
      Alert.alert("Action unavailable", message);
      return null;
    }
  }

  async function toggleSaved() {
    // Icon and haptic belong to the tap. Both used to wait for the write to come
    // back — 400-1200ms on this backend, plus an anonymous sign-in on a new
    // user's first action — so the buzz arrived a beat after the finger left the
    // screen and testers read it as lag.
    const next = !isSaved;
    setIsSaved(next);
    triggerSelectionHaptic();
    writesInFlight.current += 1;
    try {
      if (!(await ensureActionSession("save_resource"))) {
        setIsSaved(!next);
        return;
      }
      const supabase = getSupabase();
      if (!supabase) {
        setIsSaved(!next);
        return;
      }
      const { error } = relationId
        ? await supabase.rpc("set_user_bookmark", {
            p_relation_id: relationId,
            p_saved: next,
          })
        : await supabase.rpc("set_user_link_bookmark", {
            p_link_id: linkId,
            p_saved: next,
          });
      if (error) {
        setIsSaved(!next);
        Alert.alert("Save failed", error.message);
        console.warn("[resource-actions] Bookmark write failed", { relationId, linkId, error: error.message });
        return;
      }
      // Fired after the write succeeds, so the funnel counts real actions rather
      // than taps that failed.
      if (next) track("resource_saved", { source: getLinkSource(resource.link) });
      void queryClient.invalidateQueries({ queryKey: ["user-library"] });
    } finally {
      writesInFlight.current -= 1;
    }
  }

  async function toggleCompleted() {
    const next = !isCompleted;
    setIsCompleted(next);
    triggerSelectionHaptic();
    writesInFlight.current += 1;
    try {
      if (!(await ensureActionSession("mark_watched"))) {
        setIsCompleted(!next);
        return;
      }
      const supabase = getSupabase();
      if (!supabase) {
        setIsCompleted(!next);
        return;
      }
      // Same split as toggleSaved: the relation path keeps the catalogue
      // validation for items that have one, and everything else — private saves,
      // links still in review — goes in by link id (M158).
      const { error } = relationId
        ? await supabase.rpc("set_user_watched", {
            p_relation_id: relationId,
            p_watched: next,
          })
        : await supabase.rpc("set_user_link_watched", {
            p_link_id: linkId,
            p_watched: next,
          });
      if (error) {
        setIsCompleted(!next);
        Alert.alert("Watched update failed", error.message);
        console.warn("[resource-actions] Watched write failed", { relationId, linkId, error: error.message });
        return;
      }
      if (next) {
        track("resource_watched", { source: getLinkSource(resource.link) });
        // The return prompt asks the user to rate a catalogue entry, so there is
        // nothing to schedule for a link that has none.
        if (relationId) void recordWatchedForReviewPrompt(relationId);
      }
      void queryClient.invalidateQueries({ queryKey: ["user-library"] });
    } finally {
      writesInFlight.current -= 1;
    }
  }

  async function writeVote(nextVote: -1 | 0 | 1) {
    if (!relationId) {
      Alert.alert("Still in review", "Votes are available after this link joins the catalogue.");
      return;
    }
    const previousVote = vote;
    const previousUserScore = userScore;
    setVote(nextVote);
    setUserScore(previousUserScore - previousVote + nextVote);
    triggerSelectionHaptic();
    writesInFlight.current += 1;
    try {
      if (!(await ensureActionSession("vote_resource"))) {
        setVote(previousVote);
        setUserScore(previousUserScore);
        return;
      }
      const supabase = getSupabase();
      if (!supabase) {
        setVote(previousVote);
        setUserScore(previousUserScore);
        return;
      }
      const { data, error } = await supabase
        .rpc("set_user_vote", {
          p_relation_id: relationId,
          p_vote: nextVote,
        })
        .single();
      if (error) {
        setVote(previousVote);
        setUserScore(previousUserScore);
        Alert.alert("Vote failed", error.message);
        console.warn("[resource-actions] Vote write failed", { relationId, vote: nextVote, error: error.message });
        return;
      }
      const row = data as {
        vote?: number | null;
        user_score?: number | null;
        combined_score?: number | null;
      } | null;
      const returnedVote = row?.vote;
      setVote(returnedVote === -1 ? -1 : returnedVote === 1 ? 1 : 0);
      if (typeof row?.user_score === "number") setUserScore(row.user_score);
      if (typeof row?.combined_score === "number" && typeof row?.user_score === "number") {
        setBaseScore(row.combined_score - boundedUserVoteWeight(row.user_score));
      }
      if (nextVote !== 0) track("resource_voted", { direction: nextVote > 0 ? "up" : "down" });
    } finally {
      writesInFlight.current -= 1;
    }
  }

  function toggleUpvote() {
    void writeVote(vote === 1 ? 0 : 1);
  }

  function toggleDownvote() {
    void writeVote(vote === -1 ? 0 : -1);
  }

  function openResource() {
    track("resource_opened", { source: getLinkSource(resource.link), watched: isCompleted });
    void openTutorialResource(resource, { alreadyWatched: isCompleted });
  }

  function reportResource() {
    const resourceId = encodeURIComponent(relationId ?? resource.id);
    const link = encodeURIComponent(linkId);
    const title = resource.link.title ? `&title=${encodeURIComponent(resource.link.title)}` : "";
    void Linking.openURL(webUrl(`/support?resource=${resourceId}&link=${link}${title}`));
  }

  function openMenu() {
    triggerSelectionHaptic();
    setMenuOpen(true);
  }

  const SavedIcon = isSaved ? BookmarkCheck : Bookmark;
  const portrait = isPortraitResource(resource);
  const catalogueStatus = statusLabel(resource.catalog_status);
  // Only the thumbnail and title recede. The action bar stays at full opacity so
  // the controls still read as live and re-tappable — including the check that
  // undoes this state.
  const dimmed = dimWhenWatched && isCompleted;
  // Voting needs a catalogue relation, and `relationId` is null for exactly the
  // states that lack one: `private` (never submitted) and `in_review` (relation
  // exists but is unpublished). Rendering thumbs there gives the user two buttons
  // whose only effect is an alert, so hide the group and the score (M136). The
  // card upgrades itself when the link publishes — catalog_status flips to
  // `in_catalog`, relationId resolves, and these come back on their own.
  const canVote = relationId !== null;

  return (
    <View style={styles.card}>
      <View style={styles.row}>
        <Pressable
          onPress={openResource}
          onLongPress={openMenu}
          delayLongPress={350}
          style={({ pressed }) => [styles.thumbWrap, pressed && styles.pressed]}
          accessibilityRole="button"
          accessibilityLabel={resource.link.title ?? "Open resource"}
          accessibilityHint="Long press for more actions"
        >
          {resource.link.thumbnail_url ? (
            <>
              {portrait ? (
                <Image
                  source={resource.link.thumbnail_url}
                  style={styles.thumbnailBackdrop}
                  contentFit="cover"
                  blurRadius={16}
                />
              ) : null}
              <Image
                source={resource.link.thumbnail_url}
                style={[styles.thumbnail, dimmed && styles.dimmedMedia]}
                contentFit={portrait ? "contain" : "cover"}
                accessibilityLabel={resource.link.title ?? "Resource thumbnail"}
              />
            </>
          ) : (
            <View style={styles.thumbnailFallback} />
          )}
        </Pressable>
        <View style={styles.body}>
          <View style={styles.topRow}>
            <View style={styles.dateGroup}>
              <SourceIcon link={resource.link} />
            </View>
            <View style={styles.pillGroup}>
              {catalogueStatus ? (
                <View style={styles.statusPill}>
                  <Text style={styles.statusText} numberOfLines={1}>
                    {catalogueStatus}
                  </Text>
                </View>
              ) : null}
              {resource.skill_level ? (
                <View style={styles.levelPill}>
                  {/* numberOfLines guards against "Intermedi/ate" wrapping mid-word
                      when the title row is tight on narrow screens. */}
                  <Text style={styles.levelText} numberOfLines={1}>
                    {capitalize(resource.skill_level)}
                  </Text>
                </View>
              ) : null}
            </View>
          </View>
          <Pressable
            onPress={openResource}
            onLongPress={openMenu}
            delayLongPress={350}
            style={({ pressed }) => [styles.titleTap, pressed && styles.pressed]}
            accessibilityRole="button"
            accessibilityLabel={resource.link.title ?? "Open resource"}
            accessibilityHint="Long press for more actions"
          >
            <Text style={[styles.title, dimmed && styles.dimmedTitle]} numberOfLines={2}>
              {resource.link.title ?? resource.link.url}
            </Text>
          </Pressable>
          <View style={styles.bottomRow}>
            {/* Two groups inside the right-hand column: Watch later + Watched sit
                left, next to the thumbnail; the vote cluster is pushed hard right
                by actionSpacer. Buttons are 40pt wide, flush and shrinkable, so
                there is no gap for a tap to fall between and a 320dp screen
                compresses rather than overflows. Removing Report (M125) bought
                the room. The vote cluster only renders when the link has a
                catalogue relation to vote on (M136). */}
            <View style={styles.actions}>
              {impliedState === "saved" ? null : (
              <Pressable
                onPress={toggleSaved}
                style={styles.iconTap}
                accessibilityRole="button"
                accessibilityLabel={isSaved ? "Remove from Watch later" : "Add to Watch later"}
              >
                <SavedIcon
                  size={20}
                  color={isSaved ? colors.accent : colors.muted}
                  fill={isSaved ? colors.accent : "transparent"}
                  strokeWidth={2}
                />
              </Pressable>
              )}
              {impliedState === "watched" ? null : (
              <Pressable
                onPress={toggleCompleted}
                style={styles.iconTap}
                accessibilityRole="button"
                accessibilityLabel={isCompleted ? "Mark not completed" : "Mark completed"}
              >
                <CircleCheck
                  size={20}
                  color={isCompleted ? colors.accent : colors.muted}
                  fill={isCompleted ? colors.accent : "transparent"}
                  stroke={isCompleted ? colors.surface : colors.muted}
                  strokeWidth={2}
                />
              </Pressable>
              )}
              <View style={styles.actionSpacer} />
              {canVote ? (
                <>
                  <Pressable
                    onPress={toggleUpvote}
                    style={styles.iconTap}
                    accessibilityRole="button"
                    accessibilityLabel={vote === 1 ? "Remove upvote" : "Upvote"}
                  >
                    <ThumbsUp
                      size={20}
                      color={vote === 1 ? colors.accent : colors.muted}
                      fill={vote === 1 ? colors.accent : "transparent"}
                      strokeWidth={2}
                    />
                  </Pressable>
                  {combinedScore !== null ? (
                    <Text
                      style={[
                        styles.scoreText,
                        vote === 1 ? styles.scorePositive : vote === -1 ? styles.scoreNegative : null,
                      ]}
                      accessibilityLabel={`Score ${formatAggregateScore(combinedScore)}, from coach review and community votes`}
                      accessibilityLiveRegion="polite"
                    >
                      {formatAggregateScore(combinedScore)}
                    </Text>
                  ) : null}
                  <Pressable
                    onPress={toggleDownvote}
                    style={styles.iconTap}
                    accessibilityRole="button"
                    accessibilityLabel={vote === -1 ? "Remove downvote" : "Downvote"}
                  >
                    <ThumbsDown
                      size={20}
                      color={vote === -1 ? colors.ink : colors.muted}
                      fill={vote === -1 ? colors.ink : "transparent"}
                      strokeWidth={2}
                    />
                  </Pressable>
                </>
              ) : null}
            </View>
          </View>
        </View>
      </View>

      <ResourceActionSheet
        visible={menuOpen}
        title={resource.link.title}
        isSaved={isSaved}
        isCompleted={isCompleted}
        onToggleSaved={() => {
          setMenuOpen(false);
          toggleSaved();
        }}
        onToggleCompleted={() => {
          setMenuOpen(false);
          toggleCompleted();
        }}
        onReport={() => {
          setMenuOpen(false);
          reportResource();
        }}
        onClose={() => setMenuOpen(false)}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  card: {},
  row: {
    flexDirection: "row",
    alignItems: "stretch",
    gap: spacing.sm,
  },
  pressed: {
    opacity: 0.6,
  },
  thumbWrap: {
    alignSelf: "stretch",
    aspectRatio: 16 / 9,
    overflow: "hidden",
    borderRadius: radius.md,
    backgroundColor: colors.bgGroup,
    ...shadows.thumbnail,
  },
  thumbnail: {
    width: "100%",
    height: "100%",
  },
  thumbnailBackdrop: {
    ...StyleSheet.absoluteFillObject,
    transform: [{ scale: 1.12 }],
  },
  thumbnailFallback: {
    flex: 1,
    backgroundColor: colors.bgGroup,
  },
  body: {
    flex: 1,
    height: BODY_HEIGHT,
    justifyContent: "space-between",
  },
  topRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    minHeight: 22,
  },
  dateGroup: {
    flexDirection: "row",
    alignItems: "center",
    gap: 5,
  },
  pillGroup: {
    flexShrink: 1,
    flexDirection: "row",
    justifyContent: "flex-end",
    alignItems: "center",
    gap: 4,
  },
  levelPill: {
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: radius.pill,
    backgroundColor: colors.muted,
  },
  statusPill: {
    maxWidth: 88,
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: radius.pill,
    backgroundColor: colors.bgGroup,
  },
  statusText: {
    color: colors.muted,
    fontSize: 11,
    fontWeight: "800",
  },
  levelText: {
    color: colors.surface,
    fontSize: 11,
    fontWeight: "700",
  },
  title: {
    ...typography.rowTitle,
    fontSize: 15,
    lineHeight: 22,
    fontWeight: "700",
  },
  titleTap: {
    minHeight: 44,
    justifyContent: "center",
  },
  bottomRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.xs,
    minHeight: 36,
  },
  // Takes the rest of the column so the four buttons can divide it evenly.
  actions: {
    flex: 1,
    flexDirection: "row",
    alignItems: "center",
    // No gap: the buttons sit flush and each is flex:1, so the whole strip is
    // live and there is no dead space between them for a tap to fall into.
    gap: 0,
  },
  // 44x44 is the iOS HIG / Android Material minimum. The previous 20x28 relied
  // on 8px of horizontal hitSlop to be usable, but the row's 2px gap meant
  // neighbouring slop regions OVERLAPPED — and React Native resolves an
  // overlapping touch by view order, not by proximity, so a tap between two
  // icons activated an arbitrary one. That is almost certainly the Huawei
  // "nothing happens when I tap Watch later" report (M119).
  //
  // Do not re-add horizontal hitSlop here. At 44pt the target is already the
  // full recommended size, and slop would only recreate the overlap at a
  // larger scale.
  iconTap: {
    width: 40,
    minHeight: 36,
    // Fixed width so the two groups keep their shape, but shrinkable so a
    // 320dp screen compresses them instead of overflowing the column.
    flexShrink: 1,
    alignItems: "center",
    justifyContent: "center",
  },
  // Splits the row into two groups: Watch later + Watched sit left, next to the
  // thumbnail; the vote cluster sits hard right. Reads as two intents rather
  // than one undifferentiated strip.
  actionSpacer: {
    flex: 1,
    minWidth: 4,
  },
  // 0.55 is the floor: below it the title stops passing contrast against the
  // cream surface. The filled check icon still carries the state non-visually,
  // so opacity is a redundant cue rather than the only one.
  dimmedMedia: {
    opacity: 0.55,
  },
  dimmedTitle: {
    color: colors.muted,
  },
  scoreText: {
    minWidth: 22,
    textAlign: "center",
    color: colors.muted,
    fontSize: 12,
    fontWeight: "800",
  },
  scorePositive: {
    color: colors.accent,
  },
  scoreNegative: {
    color: colors.ink,
  },
});
