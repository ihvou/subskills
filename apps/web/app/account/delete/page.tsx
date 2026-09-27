import Link from "next/link";
import { AccountDeleteForm } from "@/components/AccountDeleteForm";
import { PageHeader } from "@/components/PageHeader";
import { getAuthSupabase } from "@/lib/supabase";

export const dynamic = "force-dynamic";
export const metadata = {
  title: "Delete account",
  description: "How to delete your Subskills account and what deletion removes.",
};

/**
 * Signed out, this page explains the deletion process instead of redirecting to
 * sign-in. That is a store requirement, not a preference: Play's Data Safety form
 * demands a deletion URL reachable WITHOUT signing in, and the previous
 * `redirect("/sign-in?next=/account/delete")` answered every anonymous request —
 * including Google's reviewer — with a 307 to a login wall.
 *
 * Keep the description here in step with /privacy; a mismatch between the two is
 * exactly what a Data Safety audit looks for.
 */
function DeletionExplainer() {
  return (
    <div className="mt-8 space-y-8 rounded-lg bg-surface p-5 shadow-card ring-1 ring-divider">
      <section>
        <h2 className="text-xl font-extrabold text-ink">How to delete your account</h2>
        <p className="mt-3 text-base leading-7 text-muted">
          Deletion is self-service and takes effect immediately — there is no request queue
          and nothing to email. Either:
        </p>
        <ul className="mt-3 list-disc space-y-2 pl-5 text-base leading-7 text-muted">
          <li>
            In the mobile app, open <span className="font-semibold text-ink">Account</span> and
            choose <span className="font-semibold text-ink">Delete account</span>.
          </li>
          <li>
            On the web, sign in and return to this page — the confirmation control appears here.
          </li>
        </ul>
      </section>

      <section>
        <h2 className="text-xl font-extrabold text-ink">What deletion removes</h2>
        <ul className="mt-3 list-disc space-y-2 pl-5 text-base leading-7 text-muted">
          <li>Your sign-in account and email address.</li>
          <li>Your private library: Watch later resources, watched history, and your votes.</li>
          <li>Your contributor profile and public contributor page.</li>
        </ul>
      </section>

      <section>
        <h2 className="text-xl font-extrabold text-ink">What stays</h2>
        <p className="mt-3 text-base leading-7 text-muted">
          Resources you suggested that were reviewed and published stay in the public catalog,
          with your contributor profile detached from them. They are links to public tutorials,
          not personal data, and removing them would take reviewed material away from other
          learners.
        </p>
      </section>

      <section>
        <h2 className="text-xl font-extrabold text-ink">Questions</h2>
        <p className="mt-3 text-base leading-7 text-muted">
          See the{" "}
          <Link
            className="focus-ring font-semibold text-ink underline decoration-divider underline-offset-4 transition hover:decoration-ink"
            href="/privacy"
          >
            privacy policy
          </Link>{" "}
          or{" "}
          <Link
            className="focus-ring font-semibold text-ink underline decoration-divider underline-offset-4 transition hover:decoration-ink"
            href="/support"
          >
            support
          </Link>
          .
        </p>
      </section>

      <div>
        <Link
          className="focus-ring inline-flex items-center rounded-full bg-ink px-5 py-3 text-sm font-bold text-white transition hover:opacity-90"
          href="/sign-in?next=/account/delete"
        >
          Sign in to delete your account
        </Link>
      </div>
    </div>
  );
}

export default async function DeleteAccountPage() {
  const supabase = await getAuthSupabase();
  const {
    data: { user },
  } = supabase ? await supabase.auth.getUser() : { data: { user: null } };

  return (
    <div className="pb-20">
      <PageHeader
        title="Delete account"
        subtitle="Remove your Subskills account and private account state."
        backHref="/"
      />
      {/* Signed-in width is unchanged (max-w-5xl); the explainer is prose, so it reads
          better at the narrower measure the other static pages use. */}
      {user ? (
        <section className="mx-auto max-w-5xl px-4">
          <AccountDeleteForm />
        </section>
      ) : (
        <section className="mx-auto max-w-3xl px-4">
          <DeletionExplainer />
        </section>
      )}
    </div>
  );
}
