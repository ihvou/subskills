import { PageHeader } from "@/components/PageHeader";
import { SignInForm } from "@/components/SignInForm";

export const metadata = {
  title: "Sign in",
};

export default async function SignInPage({
  searchParams,
}: {
  searchParams?: Promise<{ next?: string }>;
}) {
  const resolvedSearchParams = (await searchParams) ?? {};
  const nextPath = resolvedSearchParams.next?.startsWith("/")
    ? resolvedSearchParams.next
    : "/contributors/me";

  return (
    <div className="pb-20">
      <PageHeader
        title="Sign in"
        subtitle="Use a magic link or Google to keep your library across devices and get credit for accepted suggestions."
        backHref="/"
      />
      <section className="mx-auto max-w-5xl px-4">
        <SignInForm nextPath={nextPath} />
      </section>
    </div>
  );
}
