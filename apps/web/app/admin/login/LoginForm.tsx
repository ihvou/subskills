"use client";

import { useState } from "react";
import { Mail } from "lucide-react";
import { createClient } from "@supabase/supabase-js";

type LoginStatus = {
  tone: "success" | "error";
  message: string;
};

function visibleAuthError(error: { message?: string | undefined; code?: string | undefined }) {
  const message = error.message ?? "Could not send a magic link.";
  if (error.code === "signup_disabled" || /signup|signups/i.test(message)) {
    return "Signups are not allowed; ask an admin to add this email before requesting a magic link.";
  }
  return message;
}

export function LoginForm() {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<LoginStatus | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  async function signIn() {
    const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    if (!url || !anonKey) {
      setStatus({ tone: "error", message: "Supabase env is not configured." });
      return;
    }
    if (!email.trim()) {
      setStatus({ tone: "error", message: "Enter the moderator email address first." });
      return;
    }

    setIsSubmitting(true);
    setStatus(null);
    const supabase = createClient(url, anonKey);
    const { error } = await supabase.auth.signInWithOtp({
      email: email.trim(),
      options: {
        emailRedirectTo: `${window.location.origin}/auth/callback?next=/admin`,
      },
    });
    setIsSubmitting(false);
    setStatus(
      error
        ? { tone: "error", message: visibleAuthError(error) }
        : { tone: "success", message: "Magic link sent. Check Mailpit or your inbox." },
    );
  }

  return (
    <div className="mx-auto max-w-md rounded-lg border border-ink/10 bg-white p-6 shadow-sm">
      <h1 className="text-2xl font-bold text-ink">Moderator login</h1>
      <p className="mt-2 text-sm leading-6 text-graphite">
        Use an allowlisted email to receive a Supabase magic link.
      </p>
      <label className="mt-5 block text-sm font-medium text-ink" htmlFor="email">
        Email
      </label>
      <input
        id="email"
        type="email"
        value={email}
        onChange={(event) => setEmail(event.target.value)}
        className="focus-ring mt-2 min-h-11 w-full rounded-md border border-ink/15 px-3"
      />
      <button
        type="button"
        onClick={signIn}
        disabled={isSubmitting}
        className="focus-ring mt-4 inline-flex min-h-11 w-full items-center justify-center gap-2 rounded-md bg-court px-4 text-sm font-semibold text-white hover:bg-ink disabled:cursor-not-allowed disabled:bg-graphite"
      >
        <Mail className="h-4 w-4" aria-hidden="true" />
        {isSubmitting ? "Sending..." : "Send magic link"}
      </button>
      {status ? (
        <p
          className={[
            "mt-3 rounded-md border px-3 py-2 text-sm leading-6",
            status.tone === "error"
              ? "border-red-200 bg-red-50 text-red-800"
              : "border-court/20 bg-court/10 text-court",
          ].join(" ")}
          role={status.tone === "error" ? "alert" : "status"}
        >
          {status.message}
        </p>
      ) : null}
    </div>
  );
}
