import { useEffect, useMemo, useState, useSyncExternalStore } from "react";
import { Alert, Pressable, RefreshControl, ScrollView, StyleSheet, Text, View } from "react-native";
import { FlashList } from "@shopify/flash-list";
import { useRouter } from "expo-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { ArrowDown, ArrowUp, Bookmark, CheckCircle, PlusCircle } from "lucide-react-native";
import type { SkillResource } from "@skillsaggregator/shared";
import { EmptyState } from "@/components/EmptyState";
import { PageHeader } from "@/components/PageHeader";
import { PendingResourceCard } from "@/components/PendingResourceCard";
import { ResourceCard } from "@/components/ResourceCard";
import { Screen } from "@/components/Screen";
import { SkeletonList } from "@/components/SkeletonList";
import {
  getUserLibraryResources,
  getUserSkillProgress,
  type UserLibraryView,
  type UserSkillProgress,
} from "@/lib/data";
import { useAuth } from "@/lib/auth";
import { getSupabase } from "@/lib/supabase";
import {
  failPendingSubmission,
  getPendingSubmissions,
  removePendingSubmission,
  resolvePendingSubmission,
  subscribePendingSubmissions,
  type PendingSubmission,
} from "@/lib/pendingSubmissions";
import { sendSuggestion } from "@/lib/submitSuggestion";
import { useOnboardingGate } from "@/lib/useOnboardingGate";
import { colors, radius, spacing } from "@/lib/theme";

export default function SavedTab() {
  const router = useRouter();
  const queryClient = useQueryClient();
  useOnboardingGate();
  const { user, profile, ensureSession } = useAuth();
  const [view, setView] = useState<UserLibraryView>("saved");
  const [selectedSkillId, setSelectedSkillId] = useState<string>("all");
  const queryKey = ["user-library", user?.id, view] as const;

  const query = useQuery({
    queryKey,
    queryFn: () => getUserLibraryResources(user!.id, view),
    enabled: Boolean(user),
    staleTime: 600000,
  });

  const allResources = query.data ?? [];
  const skillOptions = useMemo(() => {
    const bySkill = new Map<string, { id: string; name: string; count: number }>();
    for (const resource of allResources) {
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
  }, [allResources]);
  const skillIds = useMemo(() => skillOptions.map((skill) => skill.id), [skillOptions]);
  const progressQuery = useQuery({
    queryKey: ["user-skill-progress", user?.id, skillIds.join(",")],
    queryFn: () => getUserSkillProgress(skillIds),
    enabled: Boolean(user && skillIds.length > 0),
    staleTime: 300000,
  });
  const progressBySkill = useMemo(() => {
    const rows = new Map<string, UserSkillProgress>();
    for (const row of progressQuery.data ?? []) rows.set(row.skill_id, row);
    return rows;
  }, [progressQuery.data]);
  const displayResources = useMemo(() => {
    if (selectedSkillId === "all") return allResources;
    return allResources.filter((resource) => resource.skill?.id === selectedSkillId);
  }, [allResources, selectedSkillId]);
  // Links the user submitted that the server has not finished with. Held
  // outside react-query on purpose: they are not rows yet, and inventing fake
  // SkillResources to sit in the list would put an object shaped like a saved
  // resource where nothing has been saved.
  const pending = useSyncExternalStore(subscribePendingSubmissions, getPendingSubmissions);
  const showSkeleton =
    Boolean(user) && displayResources.length === 0 && query.isLoading && pending.length === 0;
  const emptyIcon = view === "saved" ? Bookmark : CheckCircle;

  useEffect(() => {
    if (selectedSkillId === "all") return;
    if (!skillOptions.some((skill) => skill.id === selectedSkillId)) {
      setSelectedSkillId("all");
    }
  }, [selectedSkillId, skillOptions]);

  const visiblePending = useMemo(() => {
    // Only Watch later — a submission is not watched — and only under a chip it
    // actually belongs to.
    if (view !== "saved") return [];
    return pending.filter(
      (item) => selectedSkillId === "all" || item.request.skill_id === selectedSkillId,
    );
  }, [pending, selectedSkillId, view]);

  async function retryPending(item: PendingSubmission) {
    try {
      const activeSession = await ensureSession("suggest_resource");
      await sendSuggestion(item.request, {
        accessToken: activeSession.access_token,
        originName: profile
          ? `mobile_${profile.slug}`
          : activeSession.user.is_anonymous
            ? "mobile_anonymous"
            : "mobile_authenticated",
      });
      resolvePendingSubmission(item.id);
      void queryClient.invalidateQueries({ queryKey: ["user-library"] });
    } catch (error) {
      failPendingSubmission(item.id, error instanceof Error ? error.message : String(error));
    }
  }

  async function moveResource(resourceId: string, direction: -1 | 1) {
    if (view !== "saved" || !user) return;
    const current = query.data ?? [];
    const from = current.findIndex((resource) => resource.id === resourceId);
    const to = from + direction;
    if (from < 0 || to < 0 || to >= current.length) return;
    const next = [...current];
    const [moved] = next.splice(from, 1);
    if (!moved) return;
    next.splice(to, 0, moved);
    const ids = next
      .map((resource) => resource.personal_list_id)
      .filter((id): id is string => Boolean(id));
    if (ids.length !== next.length) return;

    queryClient.setQueryData(queryKey, next);
    const supabase = getSupabase();
    if (!supabase) return;
    const { error } = await supabase.rpc("reorder_user_bookmarks", {
      p_bookmark_ids: ids,
    });
    if (error) {
      queryClient.setQueryData(queryKey, current);
      console.warn("[library] Reorder failed", { error: error.message, ids });
      Alert.alert("Reorder failed", error.message);
      return;
    }
    console.info("[library] Watch later order saved", { count: ids.length });
  }

  return (
    <Screen edges={["top"]} padded={false}>
      <View style={styles.headerWrap}>
        <PageHeader
          title="Library"
          subtitle="Watch later and watched resources"
          rightAccessory={<SubmitLinkButton onPress={() => router.push("/suggest")} />}
        />
        <View style={styles.tabs}>
          {(["saved", "watched"] as const).map((item) => (
            <Pressable
              key={item}
              onPress={() => setView(item)}
              style={[styles.tab, view === item && styles.tabActive]}
              accessibilityRole="button"
            >
              <Text style={[styles.tabText, view === item && styles.tabTextActive]}>
                {item === "saved" ? "Watch later" : "Watched"}
              </Text>
            </Pressable>
          ))}
        </View>
        {skillOptions.length > 0 ? (
          <SkillFilterChips
            skills={skillOptions}
            selectedSkillId={selectedSkillId}
            progressBySkill={progressBySkill}
            onSelect={setSelectedSkillId}
          />
        ) : null}
      </View>
      {showSkeleton ? (
        <View style={styles.skeletonWrap}>
          <SkeletonList count={3} />
        </View>
      ) : (
        <FlashList<SkillResource>
          // Saved and Watched are different datasets in the SAME list, and FlashList
          // keeps its scroll offset across the swap — switching while scrolled lands you
          // mid-list, or past the shorter list's content, which reads as a big blank gap
          // under the header. Keying by view remounts it so the new list starts at the top.
          //
          // The skill filter does exactly the same thing and was missed: tapping a chip
          // swaps in a much shorter dataset while the offset survives, so the list renders
          // empty or with its rows pushed far down the screen. It looked intermittent
          // because it only shows up once you have scrolled. Found on TestFlight, iOS,
          // 2026-09-10.
          key={`${view}:${selectedSkillId}`}
          data={displayResources}
          style={styles.list}
          keyExtractor={(item) => item.id}
          ListEmptyComponent={
            // Silent while something is pending: the header already shows a row,
            // so "Nothing in Watch later" directly above it contradicts itself.
            visiblePending.length > 0 ? null : (
            <View style={styles.emptyWrap}>
              {user ? (
                <EmptyState
                  icon={emptyIcon}
                  title={view === "saved" ? "Nothing in Watch later" : "Nothing watched yet"}
                  subtitle={
                    view === "saved"
                      ? "Tap the bookmark on any resource to keep it for later."
                      : "Tap the check button after you watch a resource."
                  }
                />
              ) : (
                <EmptyState
                  icon={Bookmark}
                  title="Start your library"
                  subtitle="Save, watch, vote or suggest to create a private library automatically. Add email later to keep it across devices."
                />
              )}
            </View>
            )
          }
          ListHeaderComponent={
            visiblePending.length > 0 ? (
              <View>
                {visiblePending.map((item) => (
                  <View key={item.id}>
                    <View style={styles.rowWrap}>
                      <PendingResourceCard
                        item={item}
                        onRetry={(target) => {
                          void retryPending(target);
                        }}
                        onDismiss={(target) => removePendingSubmission(target.id)}
                      />
                    </View>
                    <View style={styles.divider} />
                  </View>
                ))}
              </View>
            ) : null
          }
          ItemSeparatorComponent={() => <View style={styles.divider} />}
          renderItem={({ item, index }) => (
            <View style={styles.rowWrap}>
              <View style={styles.resourceRow}>
                {view === "saved" && selectedSkillId === "all" && displayResources.length > 1 ? (
                  <View style={styles.reorderControls}>
                    <Pressable
                      onPress={() => {
                        void moveResource(item.id, -1);
                      }}
                      disabled={index === 0}
                      style={({ pressed }) => [
                        styles.reorderButton,
                        pressed && styles.pressed,
                        index === 0 && styles.disabled,
                      ]}
                      accessibilityRole="button"
                      accessibilityLabel="Move earlier"
                    >
                      <ArrowUp size={16} color={colors.muted} />
                    </Pressable>
                    <Pressable
                      onPress={() => {
                        void moveResource(item.id, 1);
                      }}
                      disabled={index === displayResources.length - 1}
                      style={({ pressed }) => [
                        styles.reorderButton,
                        pressed && styles.pressed,
                        index === displayResources.length - 1 && styles.disabled,
                      ]}
                      accessibilityRole="button"
                      accessibilityLabel="Move later"
                    >
                      <ArrowDown size={16} color={colors.muted} />
                    </Pressable>
                  </View>
                ) : null}
                <View style={styles.resourceCardWrap}>
                  <ResourceCard
                    resource={item}
                    initialSaved={view === "saved" || Boolean(item.personal_list_id)}
                    initialCompleted={view === "watched"}
                    // Every row in the Watched tab is watched, so dimming them all
                    // would make the whole tab look disabled (M128).
                    dimWhenWatched={view !== "watched"}
                    // Hide the toggle this list already implies. It restates the
                    // list, and its single tap deletes the row with no undo.
                    impliedState={view === "saved" ? "saved" : "watched"}
                  />
                </View>
              </View>
            </View>
          )}
          contentContainerStyle={{ paddingBottom: spacing.xxl }}
          refreshControl={
            <RefreshControl
              refreshing={query.isRefetching}
              onRefresh={() => {
                query.refetch();
              }}
              tintColor={colors.ink}
            />
          }
          showsVerticalScrollIndicator={false}
        />
      )}
    </Screen>
  );
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
    <ScrollView
      horizontal
      showsHorizontalScrollIndicator={false}
      contentContainerStyle={styles.skillChips}
      nestedScrollEnabled
      directionalLockEnabled
    >
      <SkillFilterChip
        label="All"
        count={skills.reduce((total, skill) => total + skill.count, 0)}
        selected={selectedSkillId === "all"}
        progress={100}
        onPress={() => onSelect("all")}
      />
      {skills.map((skill) => (
        <SkillFilterChip
          key={skill.id}
          label={skill.name}
          count={skill.count}
          selected={selectedSkillId === skill.id}
          progress={progressBySkill.get(skill.id)?.percent ?? 0}
          onPress={() => onSelect(skill.id)}
        />
      ))}
    </ScrollView>
  );
}

function SkillFilterChip({
  label,
  count,
  selected,
  progress,
  onPress,
}: {
  label: string;
  count: number;
  selected: boolean;
  progress: number;
  onPress: () => void;
}) {
  return (
    <Pressable
      onPress={onPress}
      style={[styles.skillChip, selected && styles.skillChipActive]}
      accessibilityRole="button"
      accessibilityState={{ selected }}
      accessibilityLabel={`${label}, ${count} ${count === 1 ? "resource" : "resources"}, ${progress}% progress`}
    >
      <Text style={[styles.skillChipText, selected && styles.skillChipTextActive]} numberOfLines={1}>
        {label}
      </Text>
      <View style={[styles.skillChipBarTrack, selected && styles.skillChipBarTrackActive]}>
        <View
          style={[
            styles.skillChipBarFill,
            selected && styles.skillChipBarFillActive,
            { width: `${Math.max(0, Math.min(100, progress))}%` },
          ]}
        />
      </View>
    </Pressable>
  );
}

/**
 * Header action, top right (M129). It used to be the list's ListFooterComponent,
 * which put the one action that grows the catalogue behind a full scroll of the
 * Watch later list — worst for exactly the new user we most want submitting.
 *
 * Icon-only: the header already has a title and subtitle competing for width at
 * 320dp, and the accessibilityLabel carries the meaning for assistive tech.
 */
function SubmitLinkButton({ onPress }: { onPress: () => void }) {
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [styles.submitLink, pressed && styles.pressed]}
      accessibilityRole="button"
      accessibilityLabel="Submit a new link"
    >
      <PlusCircle size={22} color={colors.ink} />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  headerWrap: {
    paddingHorizontal: spacing.page,
    paddingTop: spacing.md,
    paddingBottom: spacing.md,
  },
  tabs: {
    flexDirection: "row",
    gap: 4,
    padding: 4,
    borderRadius: radius.sm,
    backgroundColor: colors.bgGroup,
  },
  tab: {
    minHeight: 34,
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: radius.sm,
  },
  tabActive: {
    backgroundColor: colors.surface,
  },
  tabText: {
    color: colors.muted,
    fontSize: 13,
    fontWeight: "800",
  },
  tabTextActive: {
    color: colors.ink,
  },
  skillChips: {
    gap: spacing.xs,
    paddingTop: spacing.md,
    paddingRight: spacing.page,
  },
  skillChip: {
    width: 118,
    minHeight: 46,
    justifyContent: "center",
    gap: 6,
    paddingHorizontal: spacing.sm,
    borderRadius: radius.sm,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: colors.divider,
    backgroundColor: colors.surface,
  },
  skillChipActive: {
    borderColor: colors.ink,
    backgroundColor: colors.ink,
  },
  skillChipText: {
    color: colors.muted,
    fontSize: 12,
    fontWeight: "800",
  },
  skillChipTextActive: {
    color: colors.surface,
  },
  skillChipBarTrack: {
    height: 4,
    overflow: "hidden",
    borderRadius: 2,
    backgroundColor: colors.bgGroup,
  },
  skillChipBarTrackActive: {
    backgroundColor: "rgba(255,255,255,0.24)",
  },
  skillChipBarFill: {
    height: "100%",
    borderRadius: 2,
    backgroundColor: colors.muted,
  },
  skillChipBarFillActive: {
    backgroundColor: colors.surface,
  },
  list: {
    flex: 1,
  },
  rowWrap: {
    paddingHorizontal: spacing.page,
    paddingVertical: spacing.lg,
  },
  resourceRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.sm,
  },
  resourceCardWrap: {
    flex: 1,
    minWidth: 0,
  },
  reorderControls: {
    width: 32,
    alignItems: "center",
    justifyContent: "center",
    gap: 6,
  },
  reorderButton: {
    width: 28,
    height: 28,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 14,
    backgroundColor: colors.bgGroup,
  },
  divider: {
    height: StyleSheet.hairlineWidth,
    marginHorizontal: spacing.page,
    backgroundColor: colors.divider,
  },
  skeletonWrap: {
    paddingHorizontal: spacing.page,
  },
  emptyWrap: {
    paddingHorizontal: spacing.page,
  },
  submitLink: {
    width: 44,
    height: 44,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 999,
    backgroundColor: colors.surface,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: colors.divider,
  },
  pressed: {
    opacity: 0.7,
  },
  disabled: {
    opacity: 0.35,
  },
});
