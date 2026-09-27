"use client";

import { useState } from "react";
import { Mail } from "lucide-react";
import { getBrowserSupabase } from "@/lib/browserSupabase";

interface SignInFormProps {
  nextPath?: string;
}

function callbackUrl(nextPath: string) {
  const origin = window.location.origin;
  const next = nextPath.startsWith("/") ? nextPath : "/contributors/me";
  return `${origin}/auth/callback?next=${encodeURIComponent(next)}`;
}

export function SignInForm({ nextPath = "/contributors/me" }: SignInFormProps) {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [emailExistsCollision, setEmailExistsCollision] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const supabase = getBrowserSupabase();

  function isEmailExistsError(error: { message?: string; code?: string | undefined } | null) {
    const message = error?.message?.toLowerCase() ?? "";
    return error?.code === "email_exists" || message.includes("email_exists") || message.includes("already registered");
  }

  async function sendMagicLink(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setStatus(null);
    setEmailExistsCollision(false);
    if (!supabase) {
      setError("Supabase is not configured for this environment.");
      return;
    }
    setIsSubmitting(true);
    const {
      data: { session },
    } = await supabase.auth.getSession();
    const { error: signInError } = session?.user.is_anonymous
      ? await supabase.auth.updateUser(
          { email },
          { emailRedirectTo: callbackUrl(nextPath) },
        )
      : await supabase.auth.signInWithOtp({
          email,
          options: {
            emailRedirectTo: callbackUrl(nextPath),
            shouldCreateUser: true,
          },
        });
    setIsSubmitting(false);
    if (signInError) {
      if (session?.user.is_anonymous && isEmailExistsError(signInError)) {
        setEmailExistsCollision(true);
        setError("That email already has a Subskills account.");
        return;
      }
      setError(signInError.message);
      return;
    }
    console.info("web_magic_link_flow_requested", {
      upgrading_anonymous: Boolean(session?.user.is_anonymous),
    });
    setStatus(
      session?.user.is_anonymous
        ? "Check your email to finish saving this account. Your account is not saved until you open that confirmation link."
        : "Check your email for a magic link.",
    );
  }

  async function signInToExistingAccount() {
    setError(null);
    setStatus(null);
    setEmailExistsCollision(false);
    if (!supabase) {
      setError("Supabase is not configured for this environment.");
      return;
    }
    if (!email.trim()) {
      setError("Enter the email for the account you want to sign in to.");
      return;
    }
    setIsSubmitting(true);
    const { error: signInError } = await supabase.auth.signInWithOtp({
      email,
      options: {
        emailRedirectTo: callbackUrl(nextPath),
        shouldCreateUser: false,
      },
    });
    setIsSubmitting(false);
    if (signInError) {
      setError(signInError.message);
      return;
    }
    console.info("web_existing_account_magic_link_requested");
    setStatus("Check your email to sign in. Items saved in this browser's temporary library will not carry over yet.");
  }

  async function signInWithGoogle() {
    setError(null);
    if (!supabase) {
      setError("Supabase is not configured for this environment.");
      return;
    }
    setEmailExistsCollision(false);
    const {
      data: { session },
    } = await supabase.auth.getSession();
    const { data, error: signInError } = session?.user.is_anonymous
      ? await supabase.auth.linkIdentity({
          provider: "google",
          options: {
            redirectTo: callbackUrl(nextPath),
            skipBrowserRedirect: true,
          },
        })
      : await supabase.auth.signInWithOAuth({
          provider: "google",
          options: {
            redirectTo: callbackUrl(nextPath),
            skipBrowserRedirect: true,
          },
        });
    if (signInError) setError(signInError.message);
    else {
      console.info("web_google_auth_flow_started", {
        upgrading_anonymous: Boolean(session?.user.is_anonymous),
      });
      if (data.url) window.location.assign(data.url);
    }
  }

  return (
    <div className="mx-auto mt-8 w-full max-w-md rounded-lg bg-surface p-4 shadow-card ring-1 ring-divider">
      <form onSubmit={sendMagicLink} className="space-y-4">
        <label className="block">
          <span className="text-sm font-bold text-ink">Email</span>
          <input
            type="email"
            required
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            className="focus-ring mt-2 w-full rounded-md border border-divider bg-bg px-3 py-2 text-base text-ink"
            placeholder="you@example.com"
            autoComplete="email"
          />
        </label>
        <button
          type="submit"
          disabled={isSubmitting}
          className="focus-ring inline-flex w-full items-center justify-center gap-2 rounded-md bg-ink px-4 py-2.5 text-sm font-bold text-surface transition hover:opacity-90 disabled:opacity-60"
        >
          <Mail className="h-4 w-4" />
          {isSubmitting ? "Sending..." : "Send magic link"}
        </button>
      </form>

      <div className="my-4 flex items-center gap-3 text-xs font-bold uppercase text-faint">
        <span className="h-px flex-1 bg-divider" />
        or
        <span className="h-px flex-1 bg-divider" />
      </div>

      <button
        type="button"
        onClick={signInWithGoogle}
        className="focus-ring w-full rounded-md border border-divider bg-bg px-4 py-2.5 text-sm font-bold text-ink transition hover:bg-bgGroup"
      >
        Continue with Google
      </button>

      {emailExistsCollision ? (
        <div className="mt-4 rounded-md bg-bgGroup p-3 text-sm text-muted">
          <p>
            Sign in to that account instead. Items saved in this browser&apos;s temporary library will not carry over yet.
          </p>
          <button
            type="button"
            onClick={signInToExistingAccount}
            disabled={isSubmitting}
            className="focus-ring mt-3 w-full rounded-md border border-divider bg-surface px-4 py-2 text-sm font-bold text-ink transition hover:bg-bg"
          >
            {isSubmitting ? "Sending..." : "Sign in to that account"}
          </button>
        </div>
      ) : null}

      {status ? <p className="mt-4 text-sm font-medium text-accent">{status}</p> : null}
      {error ? <p className="mt-4 text-sm font-medium text-red-600">{error}</p> : null}
    </div>
  );
}
