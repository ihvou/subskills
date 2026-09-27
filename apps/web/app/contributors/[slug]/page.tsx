import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Flag } from "lucide-react";
import { PageHeader } from "@/components/PageHeader";
import { ResourceCard } from "@/components/ResourceCard";
import { getContributorProfileBySlug } from "@/lib/data";
import { getBaseUrl } from "@/lib/env";

export const revalidate = 300;

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const { profile } = await getContributorProfileBySlug(slug);
  if (!profile) return {};
  return {
    title: `${profile.display_name} | Contributors`,
    description: `${profile.display_name} has ${profile.accepted_count ?? 0} accepted Subskills suggestions.`,
    alternates: { canonical: `${getBaseUrl()}/contributors/${profile.slug}` },
  };
}

export default async function ContributorProfilePage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const { profile, resources } = await getContributorProfileBySlug(slug);
  if (!profile) notFound();
  const reportHref = `/support?contributor=${encodeURIComponent(profile.slug)}`;

  return (
    <div className="pb-20">
      <PageHeader
        title={profile.display_name}
        subtitle={`@${profile.slug} · ${profile.accepted_count ?? 0} accepted`}
        backHref="/contributors"
        rightAccessory={
          <Link
            href={reportHref}
            className="focus-ring inline-flex min-h-9 items-center gap-2 rounded-md bg-bgGroup px-3 text-sm font-bold text-muted transition hover:text-ink"
          >
            <Flag className="h-4 w-4" />
            Report
          </Link>
        }
      />

      {profile.bio ? (
        <section className="mx-auto mt-6 max-w-5xl px-4">
          <p className="max-w-3xl text-base leading-7 text-muted md:text-lg">{profile.bio}</p>
        </section>
      ) : null}

      <section className="mx-auto mt-10 max-w-5xl px-4">
        {resources.length === 0 ? (
          <p className="text-sm text-muted">No accepted public resources from this contributor yet.</p>
        ) : (
          <div className="divide-y divide-divider">
            {resources.map((resource) => (
              <div key={resource.id} className="py-5">
                <ResourceCard resource={resource} />
              </div>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
