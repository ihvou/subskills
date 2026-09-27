import { PageHeader } from "@/components/PageHeader";
import { SuggestForm } from "@/components/SuggestForm";
import { getAllCatalogs } from "@/lib/data";
import { getAuthSupabase } from "@/lib/supabase";

export const dynamic = "force-dynamic";
export const metadata = {
  title: "Suggest a link",
};

export default async function SuggestPage({
  searchParams,
}: {
  searchParams?: Promise<{ category?: string; skill?: string; url?: string }>;
}) {
  const resolvedSearchParams = (await searchParams) ?? {};
  const catalogs = await getAllCatalogs();
  const supabase = await getAuthSupabase();
  let contributorSlug: string | null = null;

  if (supabase) {
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (user) {
      const { data: profile } = await supabase
        .from("contributor_profiles")
        .select("slug")
        .eq("user_id", user.id)
        .maybeSingle();
      contributorSlug = profile?.slug ?? null;
    }
  }

  return (
    <div className="pb-20">
      <PageHeader
        title="Suggest a link"
        subtitle="Save a training link, submit it for review, or both."
        backHref="/"
      />
      <section className="mx-auto max-w-5xl px-4">
        <SuggestForm
          catalogs={catalogs}
          initialCategorySlug={resolvedSearchParams.category}
          initialSkillSlug={resolvedSearchParams.skill}
          initialUrl={resolvedSearchParams.url}
          contributorSlug={contributorSlug}
        />
      </section>
    </div>
  );
}
