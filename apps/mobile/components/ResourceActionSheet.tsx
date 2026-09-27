import { Modal, Pressable, StyleSheet, Text, View } from "react-native";
import { Bookmark, BookmarkCheck, CircleCheck, Flag } from "lucide-react-native";
import { colors, radius, spacing, typography } from "@/lib/theme";

interface ResourceActionSheetProps {
  visible: boolean;
  title?: string | null | undefined;
  isSaved: boolean;
  isCompleted: boolean;
  onToggleSaved: () => void;
  onToggleCompleted: () => void;
  onReport: () => void;
  onClose: () => void;
}

/**
 * Long-press menu for a resource row.
 *
 * Exists so Report can leave the action row (M125). Report is rare and
 * unrecoverable-ish; the row's horizontal space belongs to the four everyday
 * actions, which need it to reach a 44pt target (M126).
 *
 * Watch later and Watched are repeated here deliberately. Long-press on the
 * thumbnail/title used to save directly, and replacing that with a menu would
 * have silently removed the shortcut — this keeps the capability, one tap
 * further away, and makes it discoverable instead of hidden.
 *
 * Follows the SortFilterSheet pattern (Modal + backdrop + bottom sheet) rather
 * than ActionSheetIOS, which has no Android equivalent, or a new dependency.
 */
export function ResourceActionSheet({
  visible,
  title,
  isSaved,
  isCompleted,
  onToggleSaved,
  onToggleCompleted,
  onReport,
  onClose,
}: ResourceActionSheetProps) {
  const SavedIcon = isSaved ? BookmarkCheck : Bookmark;

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

          {title ? (
            <Text style={styles.title} numberOfLines={2}>
              {title}
            </Text>
          ) : null}

          <Pressable
            onPress={onToggleSaved}
            style={({ pressed }) => [styles.row, pressed && styles.pressed]}
            accessibilityRole="button"
            accessibilityLabel={isSaved ? "Remove from Watch later" : "Add to Watch later"}
          >
            <SavedIcon size={20} color={isSaved ? colors.accent : colors.ink} strokeWidth={2} />
            <Text style={styles.rowLabel}>
              {isSaved ? "Remove from Watch later" : "Add to Watch later"}
            </Text>
          </Pressable>

          <Pressable
            onPress={onToggleCompleted}
            style={({ pressed }) => [styles.row, pressed && styles.pressed]}
            accessibilityRole="button"
            accessibilityLabel={isCompleted ? "Mark as not watched" : "Mark as watched"}
          >
            <CircleCheck
              size={20}
              color={isCompleted ? colors.accent : colors.ink}
              strokeWidth={2}
            />
            <Text style={styles.rowLabel}>
              {isCompleted ? "Mark as not watched" : "Mark as watched"}
            </Text>
          </Pressable>

          <View style={styles.groupDivider} />

          <Pressable
            onPress={onReport}
            style={({ pressed }) => [styles.row, pressed && styles.pressed]}
            accessibilityRole="button"
            accessibilityLabel="Report resource"
          >
            <Flag size={20} color={colors.muted} strokeWidth={2} />
            <Text style={[styles.rowLabel, styles.rowLabelMuted]}>Report this resource</Text>
          </Pressable>

          <Pressable
            onPress={onClose}
            style={({ pressed }) => [styles.doneButton, pressed && styles.pressed]}
            accessibilityRole="button"
          >
            <Text style={styles.doneLabel}>Cancel</Text>
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
  title: {
    ...typography.meta,
    fontSize: 13,
    fontWeight: "700",
    color: colors.muted,
    marginBottom: spacing.xs,
  },
  row: {
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.sm,
    // 44pt minimum, same rule the action row now follows.
    minHeight: 44,
    paddingVertical: spacing.sm,
  },
  pressed: {
    opacity: 0.6,
  },
  rowLabel: {
    fontSize: 16,
    color: colors.text,
    fontWeight: "500",
  },
  rowLabelMuted: {
    color: colors.muted,
  },
  groupDivider: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: colors.divider,
    marginVertical: spacing.xs,
  },
  doneButton: {
    marginTop: spacing.md,
    minHeight: 44,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: radius.lg,
    backgroundColor: colors.bgGroup,
  },
  doneLabel: {
    fontSize: 16,
    fontWeight: "700",
    color: colors.ink,
  },
});
