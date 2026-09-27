import { ActivityIndicator, Pressable, StyleSheet, Text, View } from "react-native";
import { RotateCw, X } from "lucide-react-native";
import type { PendingSubmission } from "@/lib/pendingSubmissions";
import { colors, radius, shadows, spacing, typography } from "@/lib/theme";

/**
 * A link the server has not finished with yet.
 *
 * Matches ResourceCard's geometry — same 16/9 thumbnail at the same body
 * height — so the list does not jump when the real row replaces it. What it
 * deliberately does NOT do is impersonate a finished card: the thumbnail is
 * empty, the title is the URL, and the row says what it is doing. A card that
 * quietly rewrites its own title and picture while being read is worse than one
 * that admits it is still working.
 */
const BODY_HEIGHT = 90;

export function PendingResourceCard({
  item,
  onRetry,
  onDismiss,
}: {
  item: PendingSubmission;
  onRetry: (item: PendingSubmission) => void;
  onDismiss: (item: PendingSubmission) => void;
}) {
  const failed = item.state === "failed";
  return (
    <View style={styles.row}>
      <View style={styles.thumbWrap}>
        {failed ? null : <ActivityIndicator size="small" color={colors.muted} />}
      </View>
      <View style={styles.body}>
        <View style={styles.topRow}>
          <Text style={[styles.status, failed && styles.statusFailed]} numberOfLines={1}>
            {failed ? "Couldn’t add" : "Adding…"}
          </Text>
        </View>

        <Text style={styles.title} numberOfLines={2}>
          {item.title ?? item.url}
        </Text>

        {failed ? (
          <View style={styles.actions}>
            <Pressable
              onPress={() => onRetry(item)}
              style={({ pressed }) => [styles.action, pressed && styles.pressed]}
              accessibilityRole="button"
              accessibilityLabel="Try adding this link again"
            >
              <RotateCw size={14} color={colors.ink} />
              <Text style={styles.actionText}>Retry</Text>
            </Pressable>
            <Pressable
              onPress={() => onDismiss(item)}
              style={({ pressed }) => [styles.action, pressed && styles.pressed]}
              accessibilityRole="button"
              accessibilityLabel="Discard this link"
            >
              <X size={14} color={colors.muted} />
              <Text style={[styles.actionText, styles.actionTextMuted]}>Discard</Text>
            </Pressable>
          </View>
        ) : (
          <Text style={styles.hint} numberOfLines={1}>
            {item.skillName ? `Saving to ${item.skillName}` : "Saving"}
          </Text>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: "row",
    alignItems: "stretch",
    gap: spacing.sm,
  },
  thumbWrap: {
    alignSelf: "stretch",
    aspectRatio: 16 / 9,
    alignItems: "center",
    justifyContent: "center",
    overflow: "hidden",
    borderRadius: radius.md,
    // NOT colors.bgGroup, which ResourceCard uses: there it sits under an image,
    // here it is the whole box, and bgGroup is the page background — the
    // placeholder rendered invisible and the row looked like floating text.
    backgroundColor: "#e4e3dd",
    ...shadows.thumbnail,
  },
  body: {
    flex: 1,
    height: BODY_HEIGHT,
    justifyContent: "space-between",
  },
  topRow: {
    flexDirection: "row",
    alignItems: "center",
  },
  status: {
    ...typography.meta,
    fontSize: 12,
    fontWeight: "800",
    color: colors.muted,
  },
  statusFailed: {
    color: colors.ink,
  },
  title: {
    ...typography.rowTitle,
    fontSize: 15,
    lineHeight: 20,
    fontWeight: "700",
    color: colors.muted,
  },
  hint: {
    ...typography.meta,
    fontSize: 12,
    color: colors.faint,
  },
  actions: {
    flexDirection: "row",
    gap: spacing.sm,
  },
  action: {
    minHeight: 32,
    flexDirection: "row",
    alignItems: "center",
    gap: 5,
    paddingHorizontal: spacing.sm,
    borderRadius: radius.sm,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: colors.divider,
    backgroundColor: colors.surface,
  },
  actionText: {
    fontSize: 12,
    fontWeight: "800",
    color: colors.ink,
  },
  actionTextMuted: {
    color: colors.muted,
  },
  pressed: {
    opacity: 0.7,
  },
});
