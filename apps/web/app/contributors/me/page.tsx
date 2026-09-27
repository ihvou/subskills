import { redirect } from "next/navigation";
import { getAuthSupabase } from "@/lib/supabase";

export const dynamic = "force-dynamic";

export default async function MyContributorProfilePage() {
  const supabase = await getAuthSupabase();
  if (!supabase) redirect("/sign-in?next=/contributors/me");

  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/sign-in?next=/contributors/me");

  const { data: profile } = await supabase
    .from("contributor_profiles")
    .select("slug")
    .eq("user_id", user.id)
    .maybeSingle();

  if (!profile?.slug) redirect("/contributors");
  redirect(`/contributors/${profile.slug}`);
}
