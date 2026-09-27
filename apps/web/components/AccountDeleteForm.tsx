"use client";

import { useState } from "react";
import { Trash2 } from "lucide-react";
import { getBrowserSupabase } from "@/lib/browserSupabase";

export function AccountDeleteForm() {
  const [confirmation, setConfirmation] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [isDeleting, setIsDeleting] = useState(false);
  const canDelete = confirmation.trim().toUpperCase() === "DELETE";

  async function deleteAccount(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!canDelete || isDeleting) return;

    setError(null);
    setIsDeleting(true);
    const response = await fetch("/api/account/delete", {
      method: "DELETE",
      headers: { Accept: "application/json" },
    });
    const body = await response.json().catch(() => null) as { error?: string } | null;

    if (!response.ok) {
      setError(body?.error ?? "Account deletion failed.");
      setIsDeleting(false);
      return;
    }

    await getBrowserSupabase()?.auth.signOut();
    window.location.assign("/");
  }

  return (
    <form onSubmit={deleteAccount} className="mt-8 max-w-xl rounded-lg bg-surface p-4 shadow-card ring-1 ring-divider">
      <div className="flex items-start gap-3">
        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-md bg-red-50 text-red-700">
          <Trash2 className="h-5 w-5" />
        </div>
        <div>
          <h2 className="text-lg font-extrabold text-ink">Delete your account</h2>
          <p className="mt-2 text-sm leading-6 text-muted">
            This permanently deletes your Subskills account, private Watch later/watched/vote state,
            and contributor profile. Public resources you submitted may remain in the catalog
            without your profile attached.
          </p>
        </div>
      </div>

      <label className="mt-5 block">
        <span className="text-sm font-bold text-ink">Type DELETE to confirm</span>
        <input
          value={confirmation}
          onChange={(event) => setConfirmation(event.target.value)}
          className="focus-ring mt-2 w-full rounded-md border border-divider bg-bg px-3 py-2 text-base text-ink"
          autoComplete="off"
        />
      </label>

      <button
        type="submit"
        disabled={!canDelete || isDeleting}
        className="focus-ring mt-4 inline-flex w-full items-center justify-center rounded-md bg-red-700 px-4 py-2.5 text-sm font-bold text-white transition hover:bg-red-800 disabled:cursor-not-allowed disabled:opacity-50"
      >
        {isDeleting ? "Deleting..." : "Delete account"}
      </button>

      {error ? <p className="mt-4 text-sm font-semibold text-red-700">{error}</p> : null}
    </form>
  );
}
