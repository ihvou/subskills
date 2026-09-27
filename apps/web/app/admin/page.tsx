import { ModerationQueue } from "@/components/admin/ModerationQueue";
import { RunNowForm } from "@/components/admin/RunNowForm";
import { getCatalog, getPendingSuggestions } from "@/lib/data";
import { requireModerator } from "@/lib/admin-auth";

export const dynamic = "force-dynamic";

export default async function AdminPage() {
  const moderator = await requireModerator();
  const [{ skills }, suggestions] = await Promise.all([getCatalog(), getPendingSuggestions()]);

  return (
    <div className="grid gap-6">
      {moderator.demo ? (
        <p className="rounded-lg border border-amberline/20 bg-amberline/10 px-4 py-3 text-sm text-ink">
          Demo mode: Supabase env is not configured.
        </p>
      ) : null}
      <RunNowForm skills={skills} />
      <ModerationQueue initialSuggestions={suggestions} />
    </div>
  );
}
