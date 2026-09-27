import { Pressable, StyleSheet, View } from "react-native";
import { Image } from "expo-image";
import { Camera, Globe, Music2, PlaySquare } from "lucide-react-native";
import { getLinkSource, type SkillResource } from "@skillsaggregator/shared";
import { colors, radius, shadows } from "@/lib/theme";
import { openTutorialResource } from "@/lib/tutorialReturnPrompt";

interface ResourceTileProps {
  resource: SkillResource;
  /** Pixel width override. Default matches the Skill-screen card thumbnail. */
  width?: number;
}

function isPortraitResource(resource: SkillResource) {
  const source = getLinkSource(resource.link);
  return source === "tiktok" || source === "instagram";
}

function SourceIcon({ resource }: { resource: SkillResource }) {
  const source = getLinkSource(resource.link);
  if (source === "youtube") return <PlaySquare size={13} color="#FF0000" />;
  if (source === "tiktok") return <Music2 size={12} color={colors.ink} />;
  if (source === "instagram") return <Camera size={12} color="#C13584" />;
  return <Globe size={11} color={colors.faint} />;
}

/**
 * Pure thumbnail tile used inside horizontal-scrolling rows on the Category
 * screen. 16/9 native YouTube proportions, same radius/shadow as the
 * Skill-screen card thumbnail.
 */
export function ResourceTile({ resource, width = 170 }: ResourceTileProps) {
  const portrait = isPortraitResource(resource);
  const height = Math.round((width * 9) / 16);
  const style = [styles.thumbnail, { width, height }];

  return (
    <Pressable
      onPress={() => {
        void openTutorialResource(resource);
      }}
      style={({ pressed }) => [styles.wrap, pressed && styles.pressed]}
      accessibilityRole="button"
      accessibilityLabel={resource.link.title ?? "Open resource"}
    >
      <View style={style}>
        {resource.link.thumbnail_url ? (
          <>
            {portrait ? (
              <Image
                source={resource.link.thumbnail_url}
                style={styles.imageBackdrop}
                contentFit="cover"
                blurRadius={16}
              />
            ) : null}
            <Image
              source={resource.link.thumbnail_url}
              style={styles.image}
              contentFit={portrait ? "contain" : "cover"}
              accessibilityLabel={resource.link.title ?? ""}
            />
          </>
        ) : (
          <View style={styles.fallback} />
        )}
        <View style={styles.sourceOverlay}>
          <SourceIcon resource={resource} />
        </View>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  wrap: {
    // sized by inner thumbnail; no extra width
  },
  pressed: {
    opacity: 0.7,
  },
  thumbnail: {
    overflow: "hidden",
    borderRadius: radius.md,
    backgroundColor: colors.bgGroup,
    ...shadows.thumbnail,
  },
  image: {
    width: "100%",
    height: "100%",
  },
  imageBackdrop: {
    ...StyleSheet.absoluteFillObject,
    transform: [{ scale: 1.12 }],
  },
  fallback: {
    flex: 1,
    backgroundColor: colors.bgGroup,
  },
  sourceOverlay: {
    position: "absolute",
    top: 8,
    left: 8,
    width: 22,
    height: 22,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 11,
    backgroundColor: "rgba(255,255,255,0.92)",
  },
});
