"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { getBrowserSupabase } from "@/lib/browserSupabase";

type BrowserAuthUserResult = {
  data: {
    user: unknown | null;
  };
};

type BrowserAuthSession = {
  user?: unknown | null;
} | null;

/**
 * Auth-aware nav links.
 *
 * Deliberately a CLIENT component: reading the session server-side (cookies) in the
 * root layout would opt every route into dynamic rendering and silently kill the
 * `revalidate = 86400` ISR on the home, category and skill pages — the SEO-critical
 * catalog. Same pattern the resource actions already use.
 */
function useIsSignedIn() {
  const [signedIn, setSignedIn] = useState<boolean | null>(null);

  useEffect(() => {
    let cancelled = false;
    const supabase = getBrowserSupabase();
    if (!supabase) {
      setSignedIn(false);
      return;
    }

    supabase.auth
      .getUser()
      .then(({ data }: BrowserAuthUserResult) => {
        if (!cancelled) setSignedIn(Boolean(data.user));
      })
      .catch(() => {
        if (!cancelled) setSignedIn(false);
      });

    const { data } = supabase.auth.onAuthStateChange((_event: string, session: BrowserAuthSession) => {
      if (!cancelled) setSignedIn(Boolean(session?.user));
    });

    return () => {
      cancelled = true;
      data?.subscription?.unsubscribe();
    };
  }, []);

  return signedIn;
}

export function HeaderNavLinks() {
  const signedIn = useIsSignedIn();

  return (
    <>
      <Link className="focus-ring whitespace-nowrap transition hover:text-ink" href="/suggest">
        Suggest
      </Link>
      {/* The library is per-account, so it appears only once signed in — and it takes
          the place of the Sign in link rather than sitting next to it. `null` while the
          session is still resolving, so a signed-in user never sees "Sign in" flash. */}
      {signedIn === null ? null : signedIn ? (
        <Link className="focus-ring whitespace-nowrap transition hover:text-ink" href="/saved">
          My library
        </Link>
      ) : (
        <Link className="focus-ring whitespace-nowrap transition hover:text-ink" href="/sign-in">
          Sign in
        </Link>
      )}
    </>
  );
}

export function FooterNavLinks() {
  const signedIn = useIsSignedIn();

  return (
    <>
      <Link className="focus-ring transition hover:text-ink" href="/privacy">
        Privacy
      </Link>
      {signedIn ? (
        <Link className="focus-ring transition hover:text-ink" href="/saved">
          My library
        </Link>
      ) : null}
      <Link className="focus-ring transition hover:text-ink" href="/suggest">
        Suggest a link
      </Link>
      <Link className="focus-ring transition hover:text-ink" href="/contributors">
        Contributors
      </Link>
      <Link className="focus-ring transition hover:text-ink" href="/admin">
        Admin
      </Link>
    </>
  );
}
