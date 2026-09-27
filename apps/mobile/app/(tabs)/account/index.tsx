import { useEffect, useMemo, useState } from "react";
import { Alert, Linking, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import * as AppleAuthentication from "expo-apple-authentication";
import * as Application from "expo-application";
import { useRouter } from "expo-router";
import { useQuery } from "@tanstack/react-query";
import { ExternalLink, Mail, Trash2 } from "lucide-react-native";
import { PageHeader } from "@/components/PageHeader";
import { Screen } from "@/components/Screen";
import { useAuth } from "@/lib/auth";
import { getCategories } from "@/lib/data";
import {
  getOnboardingInterests,
  setOnboardingCompleted,
  setOnboardingInterests,
} from "@/lib/localState";
import { useOnboardingGate } from "@/lib/useOnboardingGate";
import { colors, radius, spacing, typography } from "@/lib/theme";
import { webUrl } from "@/lib/webLinks";

const accountLinks = [
  { label: "Privacy Policy", path: "/privacy" },
  { label: "Terms", path: "/terms" },
  { label: "Support", path: "/support" },
  { label: "Delete account on web", path: "/account/delete" },
];

function errorCode(error: unknown) {
  return typeof error === "object" && error && "code" in error
    ? String((error as { code?: unknown }).code)
    : null;
}

export default function AccountScreen() {
  const router = useRouter();
  useOnboardingGate();
  const {
    profile,
    user,
    isAnonymous,
    signInWithMagicLink,
    signInToExistingWithMagicLink,
    signInWithGoogle,
    signInWithApple,
    signOut,
    deleteAccount,
    isLoading,
  } = useAuth();
  const [email, setEmail] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const [isAppleAvailable, setIsAppleAvailable] = useState(false);
  const [sports, setSports] = useState<string[]>(() => getOnboardingInterests());
  const permanentUser = user && !isAnonymous ? user : null;
  const categoriesQuery = useQuery({
    queryKey: ["account-categories"],
    queryFn: getCategories,
    staleTime: 300000,
  });
  const categories = useMemo(() => categoriesQuery.data ?? [], [categoriesQuery.data]);

  useEffect(() => {
    let cancelled = false;
    AppleAuthentication.isAvailableAsync()
      .then((available) => {
        if (!cancelled) setIsAppleAvailable(available);
      })
      .catch(() => {
        if (!cancelled) setIsAppleAvailable(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  async function sendMagicLink() {
    if (!email.trim()) return;
    setIsSubmitting(true);
    try {
      const message = await signInWithMagicLink(email.trim());
      Alert.alert("Check your email", message);
    } catch (error) {
      if (isAnonymous && isEmailExistsError(error)) {
        Alert.alert(
          "Account already exists",
          "Sign in to that account instead. Items saved on this device's temporary library will not carry over yet.",
          [
            { text: "Cancel", style: "cancel" },
            {
              text: "Sign in",
              onPress: () => {
                void signInExistingAccount();
              },
            },
          ],
        );
        return;
      }
      Alert.alert("Sign in failed", error instanceof Error ? error.message : String(error));
    } finally {
      setIsSubmitting(false);
    }
  }

  function isEmailExistsError(error: unknown) {
    const code = errorCode(error);
    const message = error instanceof Error ? error.message.toLowerCase() : String(error).toLowerCase();
    return code === "email_exists" || message.includes("email_exists") || message.includes("already registered");
  }

  async function signInExistingAccount() {
    if (!email.trim()) return;
    setIsSubmitting(true);
    try {
      const message = await signInToExistingWithMagicLink(email.trim());
      Alert.alert("Check your email", message);
    } catch (error) {
      Alert.alert("Sign in failed", error instanceof Error ? error.message : String(error));
    } finally {
      setIsSubmitting(false);
    }
  }

  async function googleSignIn() {
    try {
      await signInWithGoogle();
    } catch (error) {
      Alert.alert("Google sign in failed", error instanceof Error ? error.message : String(error));
    }
  }

  async function appleSignIn() {
    try {
      await signInWithApple();
    } catch (error) {
      if (errorCode(error) === "ERR_REQUEST_CANCELED") return;
      Alert.alert("Apple sign in failed", error instanceof Error ? error.message : String(error));
    }
  }

  async function openPublicProfile() {
    if (!profile) return;
    await Linking.openURL(webUrl(`/contributors/${profile.slug}`));
  }

  async function openWebPath(path: string) {
    await Linking.openURL(webUrl(path));
  }

  function replayIntro() {
    setOnboardingCompleted(false);
    router.push("/onboarding");
  }

  function toggleSport(slug: string) {
    setSports((current) => {
      const next = current.includes(slug)
        ? current.filter((item) => item !== slug)
        : [...current, slug];
      setOnboardingInterests(next);
      return next;
    });
  }

  function confirmDeleteAccount() {
    Alert.alert(
      "Delete account?",
      "This permanently deletes your Subskills account, private Watch later/watched/vote state, and contributor profile. Public resources you submitted may remain without your profile attached.",
      [
        { text: "Cancel", style: "cancel" },
        {
          text: "Delete account",
          style: "destructive",
          onPress: () => {
            void deleteCurrentAccount();
          },
        },
      ],
    );
  }

  async function deleteCurrentAccount() {
    setIsDeleting(true);
    try {
      await deleteAccount();
      Alert.alert("Account deleted", "Your account has been deleted.");
    } catch (error) {
      Alert.alert("Deletion failed", error instanceof Error ? error.message : String(error));
    } finally {
      setIsDeleting(false);
    }
  }

  return (
    <Screen edges={["top"]}>
      <ScrollView contentContainerStyle={styles.scrollContent} showsVerticalScrollIndicator={false}>
        <PageHeader
          title={user ? "Account" : "Sign in"}
          subtitle={
            permanentUser
              ? "Contributor profile and suggestion credit."
              : isAnonymous
                ? "Add email or social sign-in to keep this library."
                : "Start with an account when you want one."
          }
        />

        {permanentUser ? (
          <View style={styles.card}>
            <Text style={styles.name}>{profile?.display_name ?? permanentUser.email ?? "Contributor"}</Text>
            <Text style={styles.meta}>{profile ? `@${profile.slug}` : permanentUser.email}</Text>
            <Text style={styles.accepted}>{profile?.accepted_count ?? 0} accepted suggestions</Text>
            <View style={styles.buttonRow}>
              <Pressable
                onPress={openPublicProfile}
                disabled={!profile}
                style={({ pressed }) => [styles.primaryButton, pressed && styles.pressed, !profile && styles.disabled]}
                accessibilityRole="button"
              >
                <Text style={styles.primaryButtonText}>Public profile</Text>
              </Pressable>
              <Pressable
                onPress={signOut}
                style={({ pressed }) => [styles.secondaryButton, pressed && styles.pressed]}
                accessibilityRole="button"
              >
                <Text style={styles.secondaryButtonText}>Sign out</Text>
              </Pressable>
            </View>
            <Pressable
              onPress={confirmDeleteAccount}
              disabled={isDeleting}
              style={({ pressed }) => [styles.dangerButton, pressed && styles.pressed, isDeleting && styles.disabled]}
              accessibilityRole="button"
            >
              <Trash2 size={17} color="#b91c1c" />
              <Text style={styles.dangerButtonText}>{isDeleting ? "Deleting..." : "Delete account"}</Text>
            </Pressable>
          </View>
        ) : (
          <View style={styles.card}>
            {isAnonymous ? (
              <View style={styles.upgradeIntro}>
                <Text style={styles.name}>Temporary library</Text>
                <Text style={styles.meta}>
                  Your saves, watched items, votes, and suggestions are tied to this install. Add a login to keep them across devices.
                </Text>
              </View>
            ) : null}
            <Text style={styles.label}>Email</Text>
            <TextInput
              value={email}
              onChangeText={setEmail}
              keyboardType="email-address"
              autoCapitalize="none"
              autoComplete="email"
              placeholder="you@example.com"
              placeholderTextColor={colors.faint}
              style={styles.input}
            />
            <Pressable
              onPress={sendMagicLink}
              disabled={isSubmitting || isLoading}
              style={({ pressed }) => [styles.primaryButton, pressed && styles.pressed, (isSubmitting || isLoading) && styles.disabled]}
              accessibilityRole="button"
            >
              <Mail size={17} color={colors.surface} />
              <Text style={styles.primaryButtonText}>
                {isSubmitting ? "Sending..." : isAnonymous ? "Add email" : "Send magic link"}
              </Text>
            </Pressable>
            {isAppleAvailable ? (
              <AppleAuthentication.AppleAuthenticationButton
                buttonType={
                  isAnonymous
                    ? AppleAuthentication.AppleAuthenticationButtonType.SIGN_UP
                    : AppleAuthentication.AppleAuthenticationButtonType.CONTINUE
                }
                buttonStyle={AppleAuthentication.AppleAuthenticationButtonStyle.BLACK}
                cornerRadius={6}
                style={styles.appleButton}
                onPress={appleSignIn}
              />
            ) : null}
            <Pressable
              onPress={googleSignIn}
              disabled={isLoading}
              style={({ pressed }) => [styles.secondaryButton, pressed && styles.pressed, isLoading && styles.disabled]}
              accessibilityRole="button"
            >
              <Text style={styles.secondaryButtonText}>{isAnonymous ? "Add Google" : "Continue with Google"}</Text>
            </Pressable>
            {isAnonymous ? (
              <Pressable
                onPress={signInExistingAccount}
                disabled={isSubmitting || isLoading || !email.trim()}
                style={({ pressed }) => [
                  styles.secondaryButton,
                  pressed && styles.pressed,
                  (isSubmitting || isLoading || !email.trim()) && styles.disabled,
                ]}
                accessibilityRole="button"
              >
                <Text style={styles.secondaryButtonText}>Sign in to existing account</Text>
              </Pressable>
            ) : null}
            {isAnonymous ? (
              <Pressable
                onPress={signOut}
                style={({ pressed }) => [styles.secondaryButton, pressed && styles.pressed]}
                accessibilityRole="button"
              >
                <Text style={styles.secondaryButtonText}>Sign out</Text>
              </Pressable>
            ) : null}
          </View>
        )}

        <View style={[styles.card, styles.secondaryCard]}>
          <Text style={styles.label}>App</Text>
          <Pressable
            onPress={replayIntro}
            style={({ pressed }) => [styles.secondaryButton, pressed && styles.pressed]}
            accessibilityRole="button"
          >
            <Text style={styles.secondaryButtonText}>Replay intro</Text>
          </Pressable>
          {categories.length > 0 ? (
            <View style={styles.sportsBlock}>
              {/* "Category preferences" rather than "Sports preferences" (M130):
                  it survives the first non-sport category with no further edit,
                  and chess is already in the discovery pipeline. The persisted
                  key stays `onboarding_interests` — renaming it would silently
                  discard every existing user's picks. */}
              <Text style={styles.label}>Category preferences</Text>
              <Text style={styles.sportsHint}>
                Picked categories appear first on Discover. Everything else stays browsable.
              </Text>
              <View style={styles.sportChips}>
                {categories.map((category) => {
                  const selected = sports.includes(category.slug);
                  return (
                    <Pressable
                      key={category.id}
                      onPress={() => toggleSport(category.slug)}
                      style={[styles.sportChip, selected && styles.sportChipActive]}
                      accessibilityRole="button"
                      accessibilityState={{ selected }}
                    >
                      <Text style={[styles.sportChipText, selected && styles.sportChipTextActive]}>
                        {category.name}
                      </Text>
                    </Pressable>
                  );
                })}
              </View>
            </View>
          ) : null}
          <View style={styles.linkList}>
            {accountLinks.map((link) => (
              <Pressable
                key={link.path}
                onPress={() => openWebPath(link.path)}
                style={({ pressed }) => [styles.linkRow, pressed && styles.pressed]}
                accessibilityRole="link"
              >
                <Text style={styles.linkText}>{link.label}</Text>
                <ExternalLink size={16} color={colors.muted} />
              </Pressable>
            ))}
          </View>
        </View>

        {/* Which build am I actually running? Two preview APKs from different
            commits both reported 1.0.0 (6), so a tester could not tell whether a
            fix was installed — and neither could we. Read from the binary via
            expo-application rather than from app.json, because EAS assigns the
            build number remotely and app.json never sees it. */}
        <Text style={styles.buildLine} selectable>
          {`Version ${Application.nativeApplicationVersion ?? "?"} (${Application.nativeBuildVersion ?? "?"})`}
        </Text>
      </ScrollView>
    </Screen>
  );
}

const styles = StyleSheet.create({
  buildLine: {
    marginTop: spacing.lg,
    textAlign: "center",
    fontSize: 12,
    color: colors.faint,
  },
  scrollContent: {
    paddingBottom: spacing.xxl,
  },
  card: {
    gap: spacing.md,
    padding: spacing.lg,
    borderRadius: radius.md,
    backgroundColor: colors.surface,
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 8,
    elevation: 2,
  },
  secondaryCard: {
    marginTop: spacing.md,
  },
  upgradeIntro: {
    gap: spacing.xs,
  },
  label: {
    fontSize: 13,
    fontWeight: "800",
    color: colors.ink,
  },
  input: {
    minHeight: 46,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: colors.divider,
    borderRadius: radius.sm,
    paddingHorizontal: spacing.md,
    color: colors.ink,
    fontSize: 16,
    backgroundColor: colors.bg,
  },
  name: {
    ...typography.pageTitle,
    fontSize: 28,
  },
  meta: {
    ...typography.meta,
    color: colors.muted,
  },
  accepted: {
    fontSize: 14,
    fontWeight: "800",
    color: colors.accent,
  },
  buttonRow: {
    flexDirection: "row",
    gap: spacing.sm,
  },
  primaryButton: {
    minHeight: 44,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: spacing.xs,
    paddingHorizontal: spacing.md,
    borderRadius: radius.sm,
    backgroundColor: colors.ink,
  },
  primaryButtonText: {
    color: colors.surface,
    fontSize: 14,
    fontWeight: "800",
  },
  secondaryButton: {
    minHeight: 44,
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: spacing.md,
    borderRadius: radius.sm,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: colors.divider,
    backgroundColor: colors.bg,
  },
  secondaryButtonText: {
    color: colors.ink,
    fontSize: 14,
    fontWeight: "800",
  },
  appleButton: {
    width: "100%",
    height: 44,
  },
  dangerButton: {
    minHeight: 44,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: spacing.xs,
    paddingHorizontal: spacing.md,
    borderRadius: radius.sm,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: "rgba(185, 28, 28, 0.35)",
    backgroundColor: "rgba(185, 28, 28, 0.08)",
  },
  dangerButtonText: {
    color: "#b91c1c",
    fontSize: 14,
    fontWeight: "800",
  },
  linkList: {
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: colors.divider,
  },
  sportsHint: {
    color: colors.muted,
    fontSize: 13,
    lineHeight: 18,
    marginTop: 2,
    marginBottom: spacing.xs,
  },
  sportsBlock: {
    gap: spacing.xs,
  },
  sportChips: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: spacing.xs,
  },
  sportChip: {
    minHeight: 34,
    justifyContent: "center",
    paddingHorizontal: spacing.sm,
    borderRadius: radius.pill,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: colors.divider,
    backgroundColor: colors.bg,
  },
  sportChipActive: {
    borderColor: colors.ink,
    backgroundColor: colors.ink,
  },
  sportChipText: {
    color: colors.muted,
    fontSize: 12,
    fontWeight: "800",
  },
  sportChipTextActive: {
    color: colors.surface,
  },
  linkRow: {
    minHeight: 44,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    gap: spacing.md,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.divider,
  },
  linkText: {
    color: colors.ink,
    fontSize: 14,
    fontWeight: "700",
  },
  pressed: {
    opacity: 0.7,
  },
  disabled: {
    opacity: 0.5,
  },
});
