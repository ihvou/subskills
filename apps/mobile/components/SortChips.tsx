import { Pressable, StyleSheet, Text, View } from "react-native";
import type { ResourceSort } from "@skillsaggregator/shared";
import { colors } from "@/lib/theme";

const sortOptions: Array<{ value: ResourceSort; label: string }> = [
  { value: "popular", label: "Popular" },
  { value: "newest", label: "Newest" },
];

interface SortChipsProps {
  value: ResourceSort;
  onChange: (value: ResourceSort) => void;
}

export function SortChips({ value, onChange }: SortChipsProps) {
  return (
    <View style={styles.wrap} accessibilityRole="tablist">
      {sortOptions.map((option) => {
        const selected = value === option.value;
        return (
          <Pressable
            key={option.value}
            onPress={() => onChange(option.value)}
            style={[styles.item, selected && styles.selected]}
            accessibilityRole="tab"
            accessibilityState={{ selected }}
          >
            <Text style={[styles.label, selected && styles.selectedLabel]}>{option.label}</Text>
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    flexDirection: "row",
    gap: 4,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: colors.line,
    backgroundColor: colors.white,
    padding: 4,
  },
  item: {
    minHeight: 36,
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 6,
    paddingHorizontal: 4,
  },
  selected: {
    backgroundColor: colors.court,
  },
  label: {
    color: colors.graphite,
    fontSize: 12,
    fontWeight: "700",
  },
  selectedLabel: {
    color: colors.white,
  },
});
