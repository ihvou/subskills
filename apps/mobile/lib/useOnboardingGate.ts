import { useCallback } from "react";
import { useFocusEffect, useRouter } from "expo-router";
import { hasCompletedOnboarding } from "@/lib/localState";

/**
 * First-run gate. Call this from every root tab screen (Discover / Library /
 * Account) so onboarding is shown no matter which tab the app launches or
 * restores into — not just Discover.
 *
 * Deep links into Category/Skill sub-routes intentionally bypass this: those
 * screens are what gets focused, so a tab index's focus effect never runs and
 * a shared link opens its content directly.
 */
export function useOnboardingGate() {
  const router = useRouter();
  useFocusEffect(
    useCallback(() => {
      if (!hasCompletedOnboarding()) {
        router.replace("/onboarding");
      }
    }, [router]),
  );
}
