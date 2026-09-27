import { Pressable, StyleSheet, Text, View } from "react-native";
import { Image } from "expo-image";
import { Link } from "expo-router";
import type { SkillSummary } from "@skillsaggregator/shared";
import { colors, radius, shadows } from "@/lib/theme";

interface SkillTileProps {
  skill: SkillSummary;
  thumbnailUrl: string | null;
  /** Pixel width override. Default matches the shared 16/9 thumbnail size. */
  width?: number;
}

/**
 * Home-screen tile representing a SKILL.
 *  - Uses the latest resource's thumbnail as background
 *  - Native 16/9 proportions (same as ResourceCard/ResourceTile)
 *  - Dark scrim + centered white skill name overlay
 */
export function SkillTile({ skill, thumbnailUrl, width = 170 }: SkillTileProps) {
  const height = Math.round((width * 9) / 16);

  return (
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    <Link href={`/${skill.category_slug}/${skill.slug}` as any} asChild>
      <Pressable style={({ pressed }) => [styles.wrap, pressed && styles.pressed]}>
        <View style={[styles.thumb, { width, height }]}>
          {thumbnailUrl ? (
            <Image
              source={thumbnailUrl}
              style={styles.image}
              contentFit="cover"
              accessibilityLabel={skill.name}
            />
          ) : (
            <View style={styles.fallback} />
          )}
          <View style={styles.scrim} />
          <View style={styles.labelWrap}>
            <Text style={styles.label} numberOfLines={2}>
              {skill.name}
            </Text>
          </View>
        </View>
      </Pressable>
    </Link>
  );
}

const styles = StyleSheet.create({
  wrap: {
    // sized by inner thumb
  },
  pressed: {
    opacity: 0.85,
  },
  thumb: {
    overflow: "hidden",
    borderRadius: radius.md,
    backgroundColor: colors.bgGroup,
    ...shadows.thumbnail,
  },
  image: {
    width: "100%",
    height: "100%",
  },
  fallback: {
    flex: 1,
    backgroundColor: colors.bgGroup,
  },
  scrim: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: "rgba(0, 0, 0, 0.38)",
  },
  labelWrap: {
    position: "absolute",
    left: 10,
    right: 10,
    top: 0,
    bottom: 0,
    alignItems: "center",
    justifyContent: "center",
  },
  label: {
    color: "#ffffff",
    fontSize: 17,
    fontWeight: "800",
    letterSpacing: -0.2,
    textAlign: "center",
    lineHeight: 21,
    textShadowColor: "rgba(0,0,0,0.45)",
    textShadowOffset: { width: 0, height: 1 },
    textShadowRadius: 5,
  },
});
