import Link from "next/link";
import { PageHeader } from "@/components/PageHeader";
import { getContributorProfiles } from "@/lib/data";

export const revalidate = 300;
export const metadata = {
  title: "Contributors",
};

export default async function ContributorsPage() {
  const profiles = await getContributorProfiles();

  return (
    <div className="pb-20">
      <PageHeader
        title="Contributors"
        subtitle="People whose accepted suggestions have made the catalog better."
        backHref="/"
      />
      <section className="mx-auto mt-8 grid max-w-5xl gap-3 px-4 sm:grid-cols-2">
        {profiles.map((profile) => (
          <Link
            key={profile.id}
            href={`/contributors/${profile.slug}`}
            className="focus-ring rounded-lg bg-surface p-4 shadow-card ring-1 ring-divider transition hover:bg-bg"
          >
            <div className="text-lg font-extrabold text-ink">{profile.display_name}</div>
            <div className="mt-1 text-sm text-muted">@{profile.slug}</div>
            <div className="mt-4 text-sm font-bold text-accent">
              {profile.accepted_count ?? 0} accepted
            </div>
          </Link>
        ))}
        {profiles.length === 0 ? (
          <p className="text-sm text-muted">No public contributors yet.</p>
        ) : null}
      </section>
    </div>
  );
}
