import { useEffect, useRef } from "react";
import { Animated, StyleSheet, View } from "react-native";

interface SkeletonListProps {
  count?: number;
}

/**
 * Placeholder rows shown while a screen's first payload is in flight.
 *
 * The blocks pulse. Static grey boxes read as content the app failed to draw —
 * testers reported the home and category screens as "slow and then broken"
 * rather than "loading" — and movement is what separates the two. One animated
 * node drives the whole list, and it uses the native driver, so the pulse keeps
 * running smoothly while the JS thread parses the response that replaces it.
 */
export function SkeletonList({ count = 4 }: SkeletonListProps) {
  const pulse = useRef(new Animated.Value(0.55)).current;

  useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(pulse, { toValue: 1, duration: 700, useNativeDriver: true }),
        Animated.timing(pulse, { toValue: 0.55, duration: 700, useNativeDriver: true }),
      ]),
    );
    loop.start();
    return () => loop.stop();
  }, [pulse]);

  return (
    <Animated.View style={[styles.wrap, { opacity: pulse }]}>
      {Array.from({ length: count }).map((_, index) => (
        <View key={index} style={styles.card}>
          <View style={styles.thumb} />
          <View style={styles.body}>
            <View style={styles.lineWide} />
            <View style={styles.lineMedium} />
            <View style={styles.lineShort} />
          </View>
        </View>
      ))}
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    gap: 12,
  },
  card: {
    minHeight: 118,
    flexDirection: "row",
    gap: 12,
    borderRadius: 8,
    backgroundColor: "rgba(255,255,255,0.8)",
    padding: 10,
  },
  thumb: {
    width: 92,
    borderRadius: 7,
    backgroundColor: "rgba(16,32,38,0.08)",
  },
  body: {
    flex: 1,
    justifyContent: "center",
    gap: 10,
  },
  lineWide: {
    height: 16,
    borderRadius: 8,
    backgroundColor: "rgba(16,32,38,0.10)",
  },
  lineMedium: {
    width: "72%",
    height: 14,
    borderRadius: 7,
    backgroundColor: "rgba(16,32,38,0.08)",
  },
  lineShort: {
    width: "42%",
    height: 12,
    borderRadius: 6,
    backgroundColor: "rgba(16,32,38,0.07)",
  },
});
