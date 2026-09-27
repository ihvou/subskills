import type { MetadataRoute } from "next";
import { getAllCatalogs, getContributorProfiles } from "@/lib/data";
import { getBaseUrl } from "@/lib/env";

// Regenerate hourly, the same as sitemap.txt. Without this the route is static:
// rendered once at build time and frozen until the next deploy, while the catalog
// publishes nightly. Search Console reads the .txt, but robots.txt lists this file
// too, and Bing re-reads it at least daily and prefers it to the .txt because it
// carries lastmod — a frozen copy hides every page published since the build.
export const revalidate = 3600;

// lastmod only where a real date exists. The home page and contributor rows used
// `new Date()`, which claims "changed at render time"; with hourly regeneration
// that becomes a change every hour whether or not anything changed, and search
// engines stop trusting lastmod for the whole file once it proves unreliable.
// Omitting it is valid and says nothing false.
function lastModified(value: string | null | undefined) {
  return value ? { lastModified: new Date(value) } : {};
}

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const [catalogs, contributors] = await Promise.all([
    getAllCatalogs({ publicOnly: true }),
    getContributorProfiles(),
  ]);
  const base = getBaseUrl();
  return [
    { url: base, changeFrequency: "weekly", priority: 1 },
    { url: `${base}/contributors`, changeFrequency: "weekly", priority: 0.6 },
    ...contributors.map((contributor) => ({
      url: `${base}/contributors/${contributor.slug}`,
      changeFrequency: "weekly" as const,
      priority: 0.5,
    })),
    ...catalogs.flatMap(({ category, skills }) => [
      {
        url: `${base}/${category.slug}`,
        ...lastModified(category.updated_at),
        changeFrequency: "weekly" as const,
        priority: 0.9,
      },
      ...skills.map((skill) => ({
        url: `${base}/${category.slug}/${skill.slug}`,
        ...lastModified(skill.updated_at),
        changeFrequency: "weekly" as const,
        priority: 0.8,
      })),
    ]),
  ];
}
