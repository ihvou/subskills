import { Pressable, StyleSheet } from "react-native";
import { ChevronLeft } from "lucide-react-native";
import { useRouter } from "expo-router";
import { colors, shadows } from "@/lib/theme";

interface BackPillButtonProps {
  onPress?: () => void;
}

export function BackPillButton({ onPress }: BackPillButtonProps) {
  const router = useRouter();
  return (
    <Pressable
      onPress={() => (onPress ? onPress() : router.back())}
      style={({ pressed }) => [styles.button, pressed && styles.pressed]}
      hitSlop={{ top: 8, right: 8, bottom: 8, left: 8 }}
      accessibilityRole="button"
      accessibilityLabel="Back"
    >
      <ChevronLeft size={26} color={colors.ink} strokeWidth={2.5} />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: {
    width: 36,
    height: 36,
    borderRadius: 999,
    backgroundColor: colors.surface,
    alignItems: "center",
    justifyContent: "center",
    ...shadows.pill,
  },
  pressed: {
    opacity: 0.7,
  },
});
