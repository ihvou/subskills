import { getAgentRuns } from "@/lib/data";
import { requireModerator } from "@/lib/admin-auth";

export const dynamic = "force-dynamic";

export default async function RunsPage() {
  await requireModerator();
  const runs = await getAgentRuns();

  return (
    <div className="overflow-hidden rounded-lg border border-ink/10 bg-white shadow-sm">
      <table className="w-full border-collapse text-left text-sm">
        <thead className="bg-ink/5 text-xs uppercase tracking-wide text-graphite">
          <tr>
            <th className="px-4 py-3">Agent</th>
            <th className="px-4 py-3">Status</th>
            <th className="px-4 py-3">Suggestions</th>
            <th className="px-4 py-3">Triangulation</th>
            <th className="px-4 py-3">Latest event</th>
            <th className="px-4 py-3">Cost</th>
            <th className="px-4 py-3">Started</th>
          </tr>
        </thead>
        <tbody>
          {runs.map((run) => (
            <tr key={run.id} className="border-t border-ink/10">
              <td className="px-4 py-3 font-medium text-ink">{run.agent_type}</td>
              <td className="px-4 py-3 text-graphite">{run.status}</td>
              <td className="px-4 py-3 text-graphite">{run.suggestions_created}</td>
              <td className="px-4 py-3 text-graphite">{run.triangulation_calls}</td>
              <td className="max-w-[280px] px-4 py-3 text-graphite">
                <span className="block truncate" title={run.error_message ?? run.latest_event?.message ?? ""}>
                  {run.error_message ?? run.latest_event?.message ?? "Queued"}
                </span>
              </td>
              <td className="px-4 py-3 text-graphite">${Number(run.cost_usd ?? 0).toFixed(4)}</td>
              <td className="px-4 py-3 text-graphite">{new Date(run.started_at).toLocaleString()}</td>
            </tr>
          ))}
          {runs.length === 0 ? (
            <tr>
              <td className="px-4 py-6 text-graphite" colSpan={7}>
                No agent runs yet.
              </td>
            </tr>
          ) : null}
        </tbody>
      </table>
    </div>
  );
}
