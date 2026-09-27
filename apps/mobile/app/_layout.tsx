import { useEffect, useState } from "react";
import { StyleSheet } from "react-native";
import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { SafeAreaProvider, initialWindowMetrics } from "react-native-safe-area-context";
import { AuthProvider } from "@/lib/auth";
import { useTutorialReturnPrompt } from "@/lib/tutorialReturnPrompt";
import { useSharedInbox } from "@/lib/useSharedInbox";
import { reconcileInterruptedSubmissions } from "@/lib/pendingSubmissions";
import { track, trackInstall } from "@/lib/analytics";

function TutorialReturnPromptGate() {
  useTutorialReturnPrompt();
  return null;
}

/**
 * Inside the router, because it navigates; a hook that calls useRouter cannot
 * live in RootLayout itself.
 */
function SharedInboxGate() {
  useSharedInbox();
  return null;
}

export default function RootLayout() {
  useEffect(() => {
    // Before track(): on a first launch this is the only record that will exist
    // if the user never acts, since app_open gets queued behind an identity that
    // is never created.
    trackInstall();
    track("app_open");
    // A submission still marked in-flight at startup lost its request when the
    // process died; nothing is retrying it. Surface it as failed so it can be
    // retried, rather than leaving a row that says "Adding..." forever.
    reconcileInterruptedSubmissions();
  }, []);

  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            // Measured against production: the SAME query costs 20-35ms on a warm
            // connection and 480-1180ms cold, so what hurts is the number of cold
            // round trips, not query cost. Defaults here cut the avoidable ones.
            //
            // v5 ships staleTime 0, which refetches on every mount — screens that
            // did not set their own were re-hitting the network on each visit.
            staleTime: 60_000,
            // v5 ships 5 minutes, so navigating away for longer threw the payload
            // out and the next visit paid full price. An hour costs only memory.
            gcTime: 60 * 60 * 1000,
            // A retry doubles the wait on a genuinely dead network, and the
            // screens already render a cached or empty state.
            retry: 1,
            refetchOnReconnect: true,
          },
        },
      }),
  );

  return (
    <GestureHandlerRootView style={styles.root}>
      <SafeAreaProvider initialMetrics={initialWindowMetrics}>
        <QueryClientProvider client={queryClient}>
          <AuthProvider>
            <TutorialReturnPromptGate />
            <SharedInboxGate />
            <StatusBar style="dark" />
            <Stack screenOptions={{ headerShown: false }}>
              <Stack.Screen name="(tabs)" />
              <Stack.Screen name="onboarding" options={{ presentation: "modal" }} />
              <Stack.Screen name="suggest" options={{ presentation: "modal" }} />
            </Stack>
          </AuthProvider>
        </QueryClientProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
  },
});
