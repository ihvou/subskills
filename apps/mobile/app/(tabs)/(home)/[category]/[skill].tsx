import { useMemo, useState } from "react";
import { Pressable, RefreshControl, StyleSheet, Text, View } from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";
import { FlashList } from "@shopify/flash-list";
import { useQuery } from "@tanstack/react-query";
import {
  resourcePassesFilters,
  type ResourceSort,
  type ResourceSourceFilter,
  type SkillResource,
  sortResources,
} from "@skillsaggregator/shared";
import { PlusCircle, Search } from "lucide-react-native";
import { EmptyState } from "@/components/EmptyState";
import type { LevelFilterValue } from "@/components/LevelFilter";
import { PageHeader } from "@/components/PageHeader";
import { ResourceCard } from "@/components/ResourceCard";
import { Screen } from "@/components/Screen";
import { SkillTechniqueSummary } from "@/components/SkillTechniqueSummary";
import { SkeletonList } from "@/components/SkeletonList";
import { SortFilterSheet } from "@/components/SortFilterSheet";
import { getSkillResources } from "@/lib/data";
import { setLastSeenSkill } from "@/lib/localState";
import { readCachedSkillResources, writeCachedSkillResources } from "@/lib/categoryCache";
import { colors, spacing } from "@/lib/theme";

const SORT_LABELS: Record<ResourceSort, string> = {
  popular: "Popular",
  newest: "Newest",
};
const LEVEL_LABELS: Record<LevelFilterValue, string> = {
  all: "All levels",
  beginner: "Beginner",
  intermediate: "Intermediate",
  advanced: "Advanced",
};
const SOURCE_LABELS: Record<ResourceSourceFilter, string> = {
  all: "All sources",
  youtube: "YouTube",
  tiktok: "TikTok",
  instagram: "Instagram",
};

export default function SkillDetailScreen() {
  const router = useRouter();
  const { category, skill, level: initialLevel } = useLocalSearchParams<{
    category: string;
    skill: string;
    level?: LevelFilterValue;
  }>();
  const categorySlug = category ?? "badminton";
  const skillSlug = skill ?? "forehand-smash";
  const [level, setLevel] = useState<LevelFilterValue>(
    initialLevel === "beginner" || initialLevel === "intermediate" || initialLevel === "advanced"
      ? initialLevel
      : "all",
  );
  const [sort, setSort] = useState<ResourceSort>("popular");
  const [source, setSource] = useState<ResourceSourceFilter>("all");
  const [menuVisible, setMenuVisible] = useState(false);

  // Last payload from disk, so the screen paints instantly instead of showing a
  // skeleton for the length of a cold round trip. The category screen has done
  // this for a while; the skill screen did not, which is why it felt slower.
  const cachedSkillData = useMemo(
    () => readCachedSkillResources(categorySlug, skillSlug),
    [categorySlug, skillSlug],
  );

  const query = useQuery({
    queryKey: ["skill", categorySlug, skillSlug],
    queryFn: async () => {
      const data = await getSkillResources(categorySlug, skillSlug, "popular");
      if (data.skill) setLastSeenSkill(data.skill.id);
      writeCachedSkillResources(categorySlug, skillSlug, data);
      return data;
    },
    staleTime: 120000,
    ...(cachedSkillData
      ? {
          initialData: cachedSkillData.data as typeof cachedSkillData.data,
          initialDataUpdatedAt: cachedSkillData.updatedAt,
        }
      : {}),
  });

  const resources = useMemo(() => {
    const items = query.data?.resources ?? [];
    const filtered = items.filter((item) =>
      resourcePassesFilters(item, { level, source }),
    );
    return sortResources(filtered, sort);
  }, [level, query.data?.resources, sort, source]);
  const skillData = query.data?.skill ?? null;
  const summary = query.data?.summary ?? null;

  // Only describe the view when it is NOT the default. "Popular" on every skill
  // page told the user nothing and cost a line of vertical space on the screen
  // where the resource list matters most; a non-default sort or an active filter
  // still shows, so the header keeps signalling when the list is filtered.
  const headerSubtitle = useMemo(() => {
    const parts: string[] = [];
    if (sort !== "popular") parts.push(SORT_LABELS[sort]);
    if (level !== "all") parts.push(LEVEL_LABELS[level]);
    if (source !== "all") parts.push(SOURCE_LABELS[source]);
    return parts.length > 0 ? parts.join(" / ") : undefined;
  }, [sort, level, source]);

  return (
    <Screen edges={["top"]} padded={false}>
      <View style={styles.headerWrap}>
        <PageHeader
          title={skillData?.name ?? "Skill"}
          subtitle={headerSubtitle}
          showBack
          showMenu
          onMenuPress={() => setMenuVisible(true)}
          rightAccessory={
            <Pressable
              onPress={() => router.push({ pathname: "/suggest", params: { category: categorySlug, skill: skillSlug } })}
              style={({ pressed }) => [styles.suggestButton, pressed && styles.pressed]}
              accessibilityRole="button"
              accessibilityLabel="Suggest a link"
            >
              <PlusCircle size={18} color={colors.surface} />
              <Text style={styles.suggestButtonText}>Suggest</Text>
            </Pressable>
          }
        />
      </View>
      {query.isLoading ? (
        <View style={styles.skeletonWrap}>
          <SkeletonList count={3} />
        </View>
      ) : (
        <FlashList<SkillResource>
          data={resources}
          style={styles.list}
          keyExtractor={(item) => item.id}
          ListEmptyComponent={
            <View style={styles.emptyWrap}>
              <EmptyState
                icon={Search}
                title="No matches for this filter"
                subtitle="Open the menu (...) to change sort, level, or source."
              />
            </View>
          }
          ListHeaderComponent={
            skillData?.description || summary ? (
              <View style={styles.introWrap}>
                {skillData?.description ? (
                  <Text style={styles.skillDescription}>{skillData.description}</Text>
                ) : null}
                {summary ? (
                  <SkillTechniqueSummary summary={summary} />
                ) : null}
              </View>
            ) : null
          }
          ItemSeparatorComponent={() => <View style={styles.divider} />}
          renderItem={({ item }) => (
            <View style={styles.rowWrap}>
              <ResourceCard resource={item} />
            </View>
          )}
          contentContainerStyle={{ paddingBottom: spacing.xxl }}
          refreshControl={
            <RefreshControl
              refreshing={query.isRefetching}
              onRefresh={() => query.refetch()}
              tintColor={colors.ink}
            />
          }
          showsVerticalScrollIndicator={false}
        />
      )}
      <SortFilterSheet
        visible={menuVisible}
        sort={sort}
        level={level}
        source={source}
        onChangeSort={setSort}
        onChangeLevel={setLevel}
        onChangeSource={setSource}
        onClose={() => setMenuVisible(false)}
      />
    </Screen>
  );
}

const styles = StyleSheet.create({
  headerWrap: {
    paddingHorizontal: spacing.page,
    paddingTop: spacing.md,
  },
  list: {
    flex: 1,
  },
  rowWrap: {
    paddingHorizontal: spacing.page,
    paddingVertical: spacing.lg,
  },
  introWrap: {
    gap: spacing.md,
    paddingHorizontal: spacing.page,
    // No paddingTop: PageHeader already ends with paddingBottom md. While the
    // header still said "Popular" the two paddings sat either side of that text;
    // once it went, they stacked into a 32px empty band under the title.
    paddingBottom: spacing.sm,
  },
  skillDescription: {
    color: colors.muted,
    fontSize: 16,
    lineHeight: 23,
  },
  divider: {
    height: StyleSheet.hairlineWidth,
    marginHorizontal: spacing.page,
    backgroundColor: colors.divider,
  },
  skeletonWrap: {
    paddingHorizontal: spacing.page,
    paddingTop: spacing.md,
  },
  emptyWrap: {
    paddingHorizontal: spacing.page,
  },
  suggestButton: {
    minHeight: 36,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 5,
    paddingHorizontal: spacing.sm,
    borderRadius: 999,
    backgroundColor: colors.ink,
  },
  suggestButtonText: {
    color: colors.surface,
    fontSize: 12,
    fontWeight: "800",
  },
  pressed: {
    opacity: 0.7,
  },
});
