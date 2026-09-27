import { useCallback, useMemo, useState } from "react";
import { RefreshControl, ScrollView, StyleSheet, View } from "react-native";
import { useFocusEffect, useRouter } from "expo-router";
import { FlashList } from "@shopify/flash-list";
import { useQuery } from "@tanstack/react-query";
import { PageHeader } from "@/components/PageHeader";
import { Screen } from "@/components/Screen";
import { SearchBar } from "@/components/SearchBar";
import { SectionHeader } from "@/components/SectionHeader";
import { SkeletonList } from "@/components/SkeletonList";
import { SkillTile } from "@/components/SkillTile";
import {
  readCachedDiscoverSections,
  writeCachedDiscoverSections,
} from "@/lib/categoryCache";
import { getDiscoverSections } from "@/lib/data";
import {
  getOnboardingInterests,
  hasCompletedOnboarding,
} from "@/lib/localState";
import { useOnboardingGate } from "@/lib/useOnboardingGate";
import { colors, spacing } from "@/lib/theme";

export default function DiscoverTab() {
  const router = useRouter();
  const [search, setSearch] = useState("");
  const [interestSlugs, setInterestSlugs] = useState<string[]>([]);
  // Last payload from disk, so a returning user gets rails on the first frame
  // instead of placeholders while 46 round trips run.
  const cachedDiscover = useMemo(() => readCachedDiscoverSections(), []);
  const query = useQuery({
    queryKey: ["discover-sections"],
    // No cap. Batch 3 changed this from getDiscoverSections() to
    // getDiscoverSections(12) with no rationale in the commit and no mention in
    // its own change list, and it hid 290 of 554 skills — 52% of the catalogue,
    // in every single category, since all 22 hold more than 12. A skill you
    // cannot reach from Discover may as well not be collected.
    //
    // It buys nothing either: each rail is a horizontal FlashList, so it
    // virtualises and renders only the tiles on screen no matter how long the
    // row is. Thumbnails were already one round trip for every skill at once,
    // not one per skill.
    queryFn: async () => {
      const data = await getDiscoverSections();
      writeCachedDiscoverSections(data);
      return data;
    },
    staleTime: 300000,
    ...(cachedDiscover
      ? {
          initialData: cachedDiscover.data,
          initialDataUpdatedAt: cachedDiscover.updatedAt,
        }
      : {}),
  });

  useOnboardingGate();

  useFocusEffect(
    useCallback(() => {
      if (!hasCompletedOnboarding()) return;
      setInterestSlugs(getOnboardingInterests());
    }, []),
  );

  const sections = useMemo(() => {
    const items = query.data ?? [];
    if (interestSlugs.length === 0) return items;
    const rank = new Map(interestSlugs.map((slug, index) => [slug, index]));
    return [...items].sort((a, b) => {
      const left = rank.get(a.category.slug) ?? Number.MAX_SAFE_INTEGER;
      const right = rank.get(b.category.slug) ?? Number.MAX_SAFE_INTEGER;
      return left - right;
    });
  }, [interestSlugs, query.data]);

  const visibleSections = useMemo(() => {
    const needle = search.trim().toLowerCase();
    if (!needle) return sections;
    return sections
      .map((section) => {
        const matchedCategory =
          section.category.name.toLowerCase().includes(needle) ||
          (section.category.description?.toLowerCase().includes(needle) ?? false);
        if (matchedCategory) return section;
        const matchedSkills = section.skills.filter((tile) =>
          tile.skill.name.toLowerCase().includes(needle),
        );
        return matchedSkills.length ? { ...section, skills: matchedSkills } : null;
      })
      .filter((section): section is NonNullable<typeof section> => section !== null);
  }, [search, sections]);

  return (
    <Screen edges={["top"]} padded={false}>
      <ScrollView
        contentContainerStyle={styles.scroll}
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
        refreshControl={
          <RefreshControl
            refreshing={query.isRefetching}
            onRefresh={() => query.refetch()}
            tintColor={colors.ink}
          />
        }
      >
        <View style={styles.headerWrap}>
          <PageHeader title="Discover" />
          <View style={styles.searchWrap}>
            <SearchBar value={search} onChangeText={setSearch} placeholder="Search sports or skills" />
          </View>
        </View>

        {query.isLoading ? (
          <View style={styles.skeletonWrap}>
            <SkeletonList count={3} />
          </View>
        ) : (
          visibleSections.map((section, index) => (
            <View
              key={section.category.id}
              style={[styles.section, index === 0 ? styles.firstSection : null]}
            >
              <SectionHeader
                title={section.category.name}
                onPress={() => router.push(`/${section.category.slug}`)}
              />
              <FlashList
                horizontal
                data={section.skills}
                keyExtractor={(tile) => tile.skill.id}
                renderItem={({ item: tile }) => (
                  <SkillTile
                    skill={tile.skill}
                    thumbnailUrl={tile.latest_thumbnail}
                  />
                )}
                ItemSeparatorComponent={() => <View style={styles.horizontalGap} />}
                style={styles.horizontalList}
                showsHorizontalScrollIndicator={false}
                contentContainerStyle={styles.horizontalRow}
                nestedScrollEnabled
              />
              <View style={styles.divider} />
            </View>
          ))
        )}
      </ScrollView>
    </Screen>
  );
}

const styles = StyleSheet.create({
  scroll: {
    paddingBottom: spacing.xxl,
  },
  headerWrap: {
    paddingHorizontal: spacing.page,
    paddingTop: spacing.md,
  },
  searchWrap: {
    marginTop: spacing.md,
    marginBottom: spacing.sm,
  },
  firstSection: {
    marginTop: spacing.md,
  },
  section: {
    marginTop: spacing.xl,
  },
  horizontalRow: {
    paddingHorizontal: spacing.page,
  },
  horizontalList: {
    height: 104,
  },
  horizontalGap: {
    width: spacing.md,
  },
  divider: {
    height: StyleSheet.hairlineWidth,
    marginTop: spacing.lg,
    marginHorizontal: spacing.page,
    backgroundColor: colors.divider,
  },
  skeletonWrap: {
    paddingHorizontal: spacing.page,
    paddingTop: spacing.md,
  },
});
