import type { Metadata } from "next";
import { notFound } from "next/navigation";
import type { CategorySummary, SkillSummary } from "@skillsaggregator/shared";
import { CategoryResourceBrowser } from "@/components/CategoryResourceBrowser";
import { JsonLd } from "@/components/JsonLd";
import {
  getAllCatalogs,
  getCategoryBrowserData,
  getCatalog,
} from "@/lib/data";
import { getBaseUrl } from "@/lib/env";

// Content publishes once daily (nightly collection), so revalidate every 24h
// instead of hourly — the base pages serve from edge cache the rest of the
// time (near-zero compute). One hour, not 24h: the old value assumed on-demand
// revalidation would cover the gap, but nothing calls /api/revalidate — see the
// note in [category]/[skill]/page.tsx.
export const revalidate = 3600;

export async function generateStaticParams() {
  const catalogs = await getAllCatalogs({ publicOnly: true });
  return catalogs.map(({ category }) => ({ category: category.slug }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ category: string }>;
}): Promise<Metadata> {
  const { category: slug } = await params;
  const { category } = await getCatalog(slug, { publicOnly: true });
  if (!category) return {};
  const canonical = `${getBaseUrl()}/${category.slug}`;
  const title = `${category.name} resources`;
  const description = category.description ?? `Curated resources for ${category.name}.`;
  return {
    title,
    description,
    alternates: { canonical },
    openGraph: {
      title,
      description,
      url: canonical,
    },
  };
}

function categoryJsonLd(category: CategorySummary, skills: SkillSummary[]) {
  const baseUrl = getBaseUrl();
  const categoryUrl = `${baseUrl}/${category.slug}`;
  return {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "BreadcrumbList",
        itemListElement: [
          { "@type": "ListItem", position: 1, name: "Home", item: `${baseUrl}/` },
          { "@type": "ListItem", position: 2, name: category.name, item: categoryUrl },
        ],
      },
      {
        "@type": "ItemList",
        name: `${category.name} sub-skills`,
        url: categoryUrl,
        itemListElement: skills.map((skill, index) => ({
          "@type": "ListItem",
          position: index + 1,
          name: skill.name,
          url: `${categoryUrl}/${skill.slug}`,
        })),
      },
    ],
  };
}

export default async function CategoryPage({
  params,
}: {
  params: Promise<{ category: string }>;
}) {
  const { category: slug } = await params;
  const { category, skills, resources } = await getCategoryBrowserData(slug);
  if (!category) notFound();

  return (
    <>
      <JsonLd data={categoryJsonLd(category, skills)} />
      <CategoryResourceBrowser
        category={category}
        skills={skills}
        resources={resources}
      />
    </>
  );
}
