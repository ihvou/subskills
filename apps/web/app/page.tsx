import type { Metadata } from "next";
import { DiscoverBrowser } from "@/components/DiscoverBrowser";
import { JsonLd } from "@/components/JsonLd";
import { getDiscoverSections } from "@/lib/data";
import { getBaseUrl } from "@/lib/env";

// One hour. The previous 24h assumed on-demand revalidation would cover the gap,
// but nothing calls /api/revalidate — see the note in [category]/[skill]/page.tsx.
export const revalidate = 3600;

const homeDescription =
  "Free sport and training tutorials organized by sub-skill, level, and source.";

export const metadata: Metadata = {
  title: { absolute: "Subskills — Free tutorials, sorted by skill" },
  description: homeDescription,
  alternates: { canonical: "/" },
  openGraph: {
    title: "Subskills — Free tutorials, sorted by skill",
    description: homeDescription,
    url: "/",
  },
};

function homeJsonLd() {
  const baseUrl = getBaseUrl();
  return {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebSite",
        "@id": `${baseUrl}/#website`,
        name: "Subskills",
        url: `${baseUrl}/`,
        description: homeDescription,
      },
      {
        "@type": "Organization",
        "@id": `${baseUrl}/#organization`,
        name: "Subskills",
        url: `${baseUrl}/`,
        logo: `${baseUrl}/apple-icon.png`,
      },
    ],
  };
}

export default async function HomePage() {
  // No cap. At 12 per category the page carried 264 of the 554 published
  // sub-skills, so 290 of them — every category holds more than 12 — were
  // missing from the rails AND from the search below them, which filters the
  // sections it is given. "Vibora" is a real padel sub-skill with 32 published
  // tutorials and the home page could not find it. Mobile dropped the same cap
  // in dd8852b (M148); this is the web half of it, M169.
  //
  // The rails are horizontally scrollable, the tiles are next/image and load
  // lazily, and this runs once an hour at revalidate, not per request.
  const sections = await getDiscoverSections();

  return (
    <>
      <JsonLd data={homeJsonLd()} />
      <DiscoverBrowser sections={sections} />
    </>
  );
}
