import { useState } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import type { SkillTechniqueSummary as SummaryData } from "@/lib/data";
import { colors, radius, spacing, typography } from "@/lib/theme";

export function SkillTechniqueSummary({ summary }: { summary: SummaryData }) {
  const [expanded, setExpanded] = useState(false);
  const consensus = summary.consensus ?? [];
  const mistakes = summary.mistakes ?? [];
  if (consensus.length === 0) return null;

  const visible = consensus.slice(0, expanded ? undefined : 2);
  const hasMore = consensus.length > 2 || mistakes.length > 0;

  return (
    <View
      style={styles.card}
      accessibilityLabel="What coaches agree on"
    >
      <Text style={styles.heading}>What coaches agree on</Text>
      <View style={styles.list}>
        {visible.map((item) => (
          <SummaryPoint key={item.point} point={item.point} />
        ))}
      </View>

      {expanded && mistakes.length > 0 ? (
        <View style={styles.mistakes}>
          <Text style={styles.heading}>Common mistakes</Text>
          <View style={styles.list}>
            {mistakes.map((item) => (
              <SummaryPoint key={item.point} point={item.point} />
            ))}
          </View>
        </View>
      ) : null}

      {hasMore ? (
        <Pressable
          onPress={() => setExpanded((current) => !current)}
          style={({ pressed }) => [styles.toggle, pressed && styles.pressed]}
          accessibilityRole="button"
          accessibilityState={{ expanded }}
        >
          <Text style={styles.toggleText}>{expanded ? "Show less" : "Show more"}</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

function SummaryPoint({ point }: { point: string }) {
  return (
    <View style={styles.point}>
      <View style={styles.bullet} />
      <Text style={styles.pointText}>{point}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    gap: spacing.sm,
    padding: spacing.md,
    borderRadius: radius.md,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: colors.divider,
    backgroundColor: colors.bgGroup,
  },
  heading: {
    ...typography.meta,
    color: colors.muted,
    fontWeight: "900",
    textTransform: "uppercase",
  },
  list: {
    gap: spacing.xs,
  },
  point: {
    flexDirection: "row",
    gap: spacing.xs,
  },
  bullet: {
    width: 6,
    height: 6,
    marginTop: 7,
    borderRadius: 3,
    backgroundColor: colors.muted,
  },
  pointText: {
    flex: 1,
    color: colors.ink,
    fontSize: 14,
    fontWeight: "600",
    lineHeight: 20,
  },
  mistakes: {
    gap: spacing.sm,
    marginTop: spacing.xs,
  },
  toggle: {
    alignSelf: "flex-start",
    minHeight: 34,
    justifyContent: "center",
    borderRadius: radius.sm,
  },
  toggleText: {
    color: colors.muted,
    fontSize: 14,
    fontWeight: "800",
  },
  pressed: {
    opacity: 0.65,
  },
});
