import { createContext, PropsWithChildren, useContext, useEffect, useRef, useState } from "react";
import { Linking } from "react-native";
import * as AppleAuthentication from "expo-apple-authentication";
import * as ExpoLinking from "expo-linking";
import type { Session, User } from "@supabase/supabase-js";
import { getSupabase } from "./supabase";
import { flushQueuedEvents } from "./analytics";
import { webUrl } from "./webLinks";

export interface ContributorProfile {
  id: string;
  slug: string;
  display_name: string;
  avatar_url: string | null;
  accepted_count: number;
}

interface AuthContextValue {
  session: Session | null;
  user: User | null;
  profile: ContributorProfile | null;
  isAnonymous: boolean;
  isLoading: boolean;
  ensureSession: (reason?: string) => Promise<Session>;
  signInWithMagicLink: (email: string) => Promise<string>;
  signInToExistingWithMagicLink: (email: string) => Promise<string>;
  signInWithGoogle: () => Promise<void>;
  signInWithApple: () => Promise<void>;
  signOut: () => Promise<void>;
  deleteAccount: () => Promise<void>;
  refreshProfile: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);
const supabase = getSupabase();
type ConfiguredSupabaseClient = NonNullable<ReturnType<typeof getSupabase>>;
type IdTokenCredentials = Parameters<ConfiguredSupabaseClient["auth"]["signInWithIdToken"]>[0];
type IdTokenResponse = ReturnType<ConfiguredSupabaseClient["auth"]["signInWithIdToken"]>;

function redirectTo(nextPath = "/account") {
  const next = nextPath.startsWith("/") ? nextPath : `/${nextPath}`;
  const base = ExpoLinking.createURL("auth/callback");
  const separator = base.includes("?") ? "&" : "?";
  return `${base}${separator}next=${encodeURIComponent(next)}`;
}

function appleFullName(fullName: AppleAuthentication.AppleAuthenticationFullName | null | undefined) {
  if (!fullName) return null;
  const name = [fullName.givenName, fullName.middleName, fullName.familyName]
    .filter(Boolean)
    .join(" ")
    .trim();
  return name.length > 0 ? name : null;
}

export function AuthProvider({ children }: PropsWithChildren) {
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<ContributorProfile | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const anonymousSessionPromiseRef = useRef<Promise<Session> | null>(null);

  async function refreshProfileForSession(nextSession: Session | null) {
    if (!supabase || !nextSession?.user) {
      setProfile(null);
      return;
    }
    const { data, error } = await supabase
      .from("contributor_profiles")
      .select("id, slug, display_name, avatar_url, accepted_count")
      .eq("user_id", nextSession.user.id)
      .maybeSingle();
    if (error) {
      console.warn("mobile_profile_load_failed", error.message);
      setProfile(null);
      return;
    }
    setProfile(data ?? null);
  }

  useEffect(() => {
    if (!supabase) {
      setIsLoading(false);
      return;
    }
    const supabaseClient = supabase;

    let cancelled = false;

    async function applySession(nextSession: Session | null) {
      if (cancelled) return;
      setSession(nextSession);
      await refreshProfileForSession(nextSession);
      if (!cancelled) setIsLoading(false);
    }

    supabase.auth.getSession().then(({ data }) => applySession(data.session));

    const { data: listener } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      void applySession(nextSession);
    });

    async function handleUrl(url: string | null) {
      if (!url || !url.includes("code=")) return;
      const code = decodeURIComponent(url.match(/[?&]code=([^&]+)/)?.[1] ?? "");
      if (!code) return;
      const { error } = await supabaseClient.auth.exchangeCodeForSession(code);
      if (error) console.warn("mobile_auth_callback_failed", error.message);
    }

    ExpoLinking.getInitialURL().then(handleUrl);
    const subscription = Linking.addEventListener("url", (event) => {
      void handleUrl(event.url);
    });

    return () => {
      cancelled = true;
      listener.subscription.unsubscribe();
      subscription.remove();
    };
  }, []);

  async function activeSession() {
    if (!supabase) throw new Error("Supabase is not configured.");
    const { data, error } = await supabase.auth.getSession();
    if (error) throw error;
    return data.session;
  }

  async function ensureSession(reason = "user_action") {
    if (!supabase) throw new Error("Supabase is not configured.");
    const existing = await activeSession();
    if (existing) return existing;

    if (!anonymousSessionPromiseRef.current) {
      anonymousSessionPromiseRef.current = supabase.auth
        .signInAnonymously({
          options: {
            data: {
              first_action: reason,
              first_action_at: new Date().toISOString(),
              client: "mobile",
            },
          },
        })
        .then(async ({ data, error }) => {
          if (error) throw error;
          if (!data.session) throw new Error("Anonymous sign-in did not return a session.");
          console.info("[auth] Created lazy anonymous mobile session", {
            userId: data.session.user.id,
            reason,
          });
          // Events recorded before the user had an identity (app_open,
          // onboarding) are queued locally rather than creating a session just
          // to log them. Attribute them now that one exists.
          flushQueuedEvents(data.session.user.id);
          setSession(data.session);
          await refreshProfileForSession(data.session);
          return data.session;
        })
        .finally(() => {
          anonymousSessionPromiseRef.current = null;
        });
    }

    return anonymousSessionPromiseRef.current;
  }

  const value: AuthContextValue = {
    session,
    user: session?.user ?? null,
    profile,
    isAnonymous: Boolean(session?.user?.is_anonymous),
    isLoading,
    ensureSession,
    async signInWithMagicLink(email: string) {
      if (!supabase) throw new Error("Supabase is not configured.");
      const currentSession = await activeSession().catch(() => null);
      const { error } = currentSession?.user.is_anonymous
        ? await supabase.auth.updateUser({ email }, { emailRedirectTo: redirectTo() })
        : await supabase.auth.signInWithOtp({
            email,
            options: { emailRedirectTo: redirectTo(), shouldCreateUser: true },
          });
      if (error) throw error;
      console.info("[auth] Magic-link email flow requested", {
        upgradingAnonymous: Boolean(currentSession?.user.is_anonymous),
      });
      return currentSession?.user.is_anonymous
        ? "Check your email to finish saving this account. The account is not saved until you open that confirmation link."
        : "Check your email for a magic link.";
    },
    async signInToExistingWithMagicLink(email: string) {
      if (!supabase) throw new Error("Supabase is not configured.");
      const { error } = await supabase.auth.signInWithOtp({
        email,
        options: {
          emailRedirectTo: redirectTo(),
          shouldCreateUser: false,
        },
      });
      if (error) throw error;
      console.info("[auth] Existing-account magic-link flow requested");
      return "Check your email to sign in. Items saved on this device's temporary library will not carry over yet.";
    },
    async signInWithGoogle() {
      if (!supabase) throw new Error("Supabase is not configured.");
      const currentSession = await activeSession().catch(() => null);
      const { data, error } = currentSession?.user.is_anonymous
        ? await supabase.auth.linkIdentity({
            provider: "google",
            options: { redirectTo: redirectTo(), skipBrowserRedirect: true },
          })
        : await supabase.auth.signInWithOAuth({
            provider: "google",
            options: { redirectTo: redirectTo(), skipBrowserRedirect: true },
          });
      if (error) throw error;
      console.info("[auth] Google auth flow started", {
        upgradingAnonymous: Boolean(currentSession?.user.is_anonymous),
      });
      if (data.url) await Linking.openURL(data.url);
    },
    async signInWithApple() {
      if (!supabase) throw new Error("Supabase is not configured.");
      const isAvailable = await AppleAuthentication.isAvailableAsync();
      if (!isAvailable) throw new Error("Sign in with Apple is not available on this device.");

      const credential = await AppleAuthentication.signInAsync({
        requestedScopes: [
          AppleAuthentication.AppleAuthenticationScope.FULL_NAME,
          AppleAuthentication.AppleAuthenticationScope.EMAIL,
        ],
      });

      if (!credential.identityToken) {
        throw new Error("Apple did not return an identity token.");
      }

      const currentSession = await activeSession().catch(() => null);
      const appleTokenCredentials: IdTokenCredentials = {
        provider: "apple",
        token: credential.identityToken,
      };
      const upgradingAnonymous = Boolean(currentSession?.user.is_anonymous);
      let nextSession: Session | null = null;
      if (upgradingAnonymous) {
        const linkIdentityWithIdToken = supabase.auth.linkIdentity as unknown as (
          credentials: typeof appleTokenCredentials,
        ) => IdTokenResponse;
        const { data, error } = await linkIdentityWithIdToken(appleTokenCredentials);
        if (error) throw error;
        nextSession = data.session;
      } else {
        const { data, error } = await supabase.auth.signInWithIdToken(appleTokenCredentials);
        if (error) throw error;
        nextSession = data.session;
      }
      console.info("[auth] Apple auth flow completed", {
        upgradingAnonymous,
        userId: nextSession?.user.id ?? session?.user.id ?? null,
      });

      const fullName = appleFullName(credential.fullName);
      if (fullName) {
        const { error: updateError } = await supabase.auth.updateUser({
          data: {
            full_name: fullName,
            given_name: credential.fullName?.givenName ?? undefined,
            family_name: credential.fullName?.familyName ?? undefined,
          },
        });
        if (updateError) console.warn("mobile_apple_profile_name_update_failed", updateError.message);
      }

      await refreshProfileForSession(nextSession ?? session);
    },
    async signOut() {
      if (!supabase) return;
      await supabase.auth.signOut();
      setSession(null);
      setProfile(null);
    },
    async deleteAccount() {
      if (!supabase) throw new Error("Supabase is not configured.");
      const activeSession = session ?? (await supabase.auth.getSession()).data.session;
      if (!activeSession?.access_token) throw new Error("Sign in again before deleting your account.");

      const response = await fetch(webUrl("/api/account/delete"), {
        method: "DELETE",
        headers: {
          Accept: "application/json",
          Authorization: `Bearer ${activeSession.access_token}`,
        },
      });
      let responseBody: { error?: string } | null = null;
      try {
        responseBody = (await response.json()) as { error?: string };
      } catch {
        responseBody = null;
      }
      if (!response.ok) {
        throw new Error(responseBody?.error ?? "Account deletion failed.");
      }

      await supabase.auth.signOut();
      setSession(null);
      setProfile(null);
    },
    refreshProfile() {
      return refreshProfileForSession(session);
    },
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) throw new Error("useAuth must be used inside AuthProvider");
  return context;
}
