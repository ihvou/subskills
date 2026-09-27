import { Pressable, StyleSheet, Text, View } from "react-native";
import { ChevronRight } from "lucide-react-native";
import { colors, spacing, typography } from "@/lib/theme";

interface SectionHeaderProps {
  title: string;
  subtitle?: string | undefined;
  onPress?: () => void;
  /** Show the right-pointing chevron after the title (default: only when onPress is provided). */
  showChevron?: boolean;
}

/**
 * Apple-Podcasts-style section header.
 *  - Big bold title on the left
 *  - Inline chevron-right (»-style) directly after the title when tappable
 *  - Optional small muted subtitle below
 *  - The whole header is a tap target when `onPress` is provided
 */
export function SectionHeader({ title, subtitle, onPress, showChevron }: SectionHeaderProps) {
  const renderChevron = showChevron ?? Boolean(onPress);

  const content = (
    <View style={styles.wrap}>
      <View style={styles.titleRow}>
        <Text style={styles.title} numberOfLines={1}>
          {title}
        </Text>
        {renderChevron ? (
          <View style={styles.chevronWrap}>
            <ChevronRight size={26} color={colors.ink} strokeWidth={3} />
          </View>
        ) : null}
      </View>
      {subtitle ? <Text style={styles.subtitle}>{subtitle}</Text> : null}
    </View>
  );

  if (onPress) {
    return (
      <Pressable
        onPress={onPress}
        style={({ pressed }) => [pressed && styles.pressed]}
        accessibilityRole="button"
        accessibilityLabel={`Open ${title}`}
      >
        {content}
      </Pressable>
    );
  }

  return content;
}

const styles = StyleSheet.create({
  wrap: {
    paddingHorizontal: spacing.page,
    marginBottom: spacing.md,
  },
  titleRow: {
    flexDirection: "row",
    alignItems: "center",
  },
  title: {
    ...typography.sectionTitle,
    flexShrink: 1,
  },
  chevronWrap: {
    marginLeft: 4,
  },
  subtitle: {
    marginTop: spacing.xxs,
    ...typography.meta,
  },
  pressed: {
    opacity: 0.55,
  },
});
