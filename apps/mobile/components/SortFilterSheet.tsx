import { Modal, Pressable, StyleSheet, Text, View } from "react-native";
import { Check } from "lucide-react-native";
import type { ResourceSort, ResourceSourceFilter } from "@skillsaggregator/shared";
import type { LevelFilterValue } from "./LevelFilter";
import { colors, radius, spacing, typography } from "@/lib/theme";

interface SortFilterSheetProps {
  visible: boolean;
  sort: ResourceSort;
  level: LevelFilterValue;
  source: ResourceSourceFilter;
  onChangeSort: (next: ResourceSort) => void;
  onChangeLevel: (next: LevelFilterValue) => void;
  onChangeSource: (next: ResourceSourceFilter) => void;
  onClose: () => void;
}

const SORTS: Array<{ value: ResourceSort; label: string }> = [
  { value: "popular", label: "Popular" },
  { value: "newest", label: "Newest" },
];

const LEVELS: Array<{ value: LevelFilterValue; label: string }> = [
  { value: "all", label: "All levels" },
  { value: "beginner", label: "Beginner" },
  { value: "intermediate", label: "Intermediate" },
  { value: "advanced", label: "Advanced" },
];

const SOURCES: Array<{ value: ResourceSourceFilter; label: string }> = [
  { value: "all", label: "All sources" },
  { value: "youtube", label: "YouTube" },
  { value: "tiktok", label: "TikTok" },
  { value: "instagram", label: "Instagram" },
];

/**
 * Single-step bottom sheet that surfaces both Sort and Filter options at
 * once: tap the "more" header button to open, tap an option to commit, tap
 * the backdrop or Done to dismiss.
 */
export function SortFilterSheet({
  visible,
  sort,
  level,
  source,
  onChangeSort,
  onChangeLevel,
  onChangeSource,
  onClose,
}: SortFilterSheetProps) {
  return (
    <Modal
      visible={visible}
      transparent
      animationType="slide"
      statusBarTranslucent
      onRequestClose={onClose}
    >
      <Pressable style={styles.backdrop} onPress={onClose} accessibilityRole="button">
        <Pressable
          style={styles.sheet}
          onPress={(event) => event.stopPropagation()}
          accessibilityRole="none"
        >
          <View style={styles.handle} />

          <Text style={styles.groupTitle}>Sort by</Text>
          {SORTS.map((option) => {
            const selected = option.value === sort;
            return (
              <Pressable
                key={`sort-${option.value}`}
                onPress={() => onChangeSort(option.value)}
                style={({ pressed }) => [styles.row, pressed && styles.pressed]}
                accessibilityRole="button"
                accessibilityLabel={`Sort by ${option.label}`}
                accessibilityState={{ selected }}
              >
                <Text style={[styles.rowLabel, selected && styles.rowLabelSelected]}>
                  {option.label}
                </Text>
                {selected ? <Check size={20} color={colors.accent} strokeWidth={3} /> : null}
              </Pressable>
            );
          })}

          <View style={styles.groupDivider} />

          <Text style={styles.groupTitle}>Filter by level</Text>
          {LEVELS.map((option) => {
            const selected = option.value === level;
            return (
              <Pressable
                key={`level-${option.value}`}
                onPress={() => onChangeLevel(option.value)}
                style={({ pressed }) => [styles.row, pressed && styles.pressed]}
                accessibilityRole="button"
                accessibilityLabel={`Filter by ${option.label}`}
                accessibilityState={{ selected }}
              >
                <Text style={[styles.rowLabel, selected && styles.rowLabelSelected]}>
                  {option.label}
                </Text>
                {selected ? <Check size={20} color={colors.accent} strokeWidth={3} /> : null}
              </Pressable>
            );
          })}

          <View style={styles.groupDivider} />

          <Text style={styles.groupTitle}>Filter by source</Text>
          {SOURCES.map((option) => {
            const selected = option.value === source;
            return (
              <Pressable
                key={`source-${option.value}`}
                onPress={() => onChangeSource(option.value)}
                style={({ pressed }) => [styles.row, pressed && styles.pressed]}
                accessibilityRole="button"
                accessibilityLabel={`Filter by ${option.label}`}
                accessibilityState={{ selected }}
              >
                <Text style={[styles.rowLabel, selected && styles.rowLabelSelected]}>
                  {option.label}
                </Text>
                {selected ? <Check size={20} color={colors.accent} strokeWidth={3} /> : null}
              </Pressable>
            );
          })}

          <Pressable
            onPress={onClose}
            style={({ pressed }) => [styles.doneButton, pressed && styles.pressed]}
            accessibilityRole="button"
          >
            <Text style={styles.doneLabel}>Done</Text>
          </Pressable>
        </Pressable>
      </Pressable>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: "rgba(0, 0, 0, 0.4)",
    justifyContent: "flex-end",
  },
  sheet: {
    backgroundColor: colors.surface,
    borderTopLeftRadius: radius.xl,
    borderTopRightRadius: radius.xl,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.sm,
    paddingBottom: spacing.xl,
  },
  handle: {
    width: 36,
    height: 4,
    borderRadius: 2,
    backgroundColor: colors.divider,
    alignSelf: "center",
    marginBottom: spacing.md,
  },
  groupTitle: {
    ...typography.meta,
    fontSize: 12,
    fontWeight: "700",
    textTransform: "uppercase",
    letterSpacing: 0.4,
    color: colors.muted,
    marginTop: spacing.xs,
    marginBottom: spacing.xs,
  },
  row: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingVertical: spacing.sm + 2,
  },
  pressed: {
    opacity: 0.6,
  },
  rowLabel: {
    fontSize: 16,
    color: colors.text,
    fontWeight: "500",
  },
  rowLabelSelected: {
    fontWeight: "700",
    color: colors.ink,
  },
  groupDivider: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: colors.divider,
    marginVertical: spacing.sm,
  },
  doneButton: {
    marginTop: spacing.md,
    paddingVertical: spacing.sm + 2,
    borderRadius: radius.md,
    backgroundColor: colors.ink,
    alignItems: "center",
  },
  doneLabel: {
    color: colors.surface,
    fontSize: 16,
    fontWeight: "700",
  },
});
