import { PageHeader } from "@/components/PageHeader";

export const metadata = {
  title: "Support",
  description: "Support and catalog problem reporting for Subskills.",
};

type SupportSearchParams = Record<string, string | string[] | undefined>;

function firstParam(searchParams: SupportSearchParams, key: string) {
  const value = searchParams[key];
  return Array.isArray(value) ? value[0] : value;
}

function issueUrl(searchParams: SupportSearchParams) {
  const resource = firstParam(searchParams, "resource");
  const link = firstParam(searchParams, "link");
  const contributor = firstParam(searchParams, "contributor");
  const title = firstParam(searchParams, "title");
  const reportTitle = contributor
    ? `Report contributor @${contributor}`
    : title
      ? `Report resource: ${title}`
      : resource
        ? `Report resource ${resource}`
        : "Support request";
  const body = [
    "What should we review?",
    "",
    resource ? `Resource id: ${resource}` : null,
    link ? `Link id: ${link}` : null,
    contributor ? `Contributor: @${contributor}` : null,
    title ? `Title: ${title}` : null,
    "",
    "Problem type: inaccurate / unsafe / duplicated / broken / off-topic / profile",
    "",
    "What happened?",
  ].filter(Boolean).join("\n");
  const url = new URL("https://github.com/ihvou/skillsaggregator/issues/new");
  url.searchParams.set("title", reportTitle);
  url.searchParams.set("body", body);
  return url.toString();
}

export default async function SupportPage({
  searchParams,
}: {
  searchParams: Promise<SupportSearchParams>;
}) {
  const resolvedSearchParams = await searchParams;
  const resource = firstParam(resolvedSearchParams, "resource");
  const contributor = firstParam(resolvedSearchParams, "contributor");
  const hasReportContext = Boolean(resource || contributor);
  const reportIssueUrl = issueUrl(resolvedSearchParams);

  return (
    <div className="pb-20">
      <PageHeader
        title="Support"
        subtitle="Get help, report catalog problems, or ask privacy/account questions."
        backHref="/"
      />
      <section className="mx-auto max-w-3xl px-4">
        <div className="mt-8 space-y-8 rounded-lg bg-surface p-5 shadow-card ring-1 ring-divider">
          {hasReportContext ? (
            <section>
              <h2 className="text-xl font-extrabold text-ink">Report Context</h2>
              <p className="mt-3 text-base leading-7 text-muted">
                This report is prefilled for{" "}
                {resource ? `resource ${resource}` : `contributor @${contributor}`}.
              </p>
              <a
                className="focus-ring mt-4 inline-flex min-h-10 items-center rounded-md bg-ink px-4 text-sm font-bold text-surface transition hover:opacity-90"
                href={reportIssueUrl}
              >
                Open prefilled report
              </a>
            </section>
          ) : null}
          <section>
            <h2 className="text-xl font-extrabold text-ink">Contact</h2>
            <p className="mt-3 text-base leading-7 text-muted">
              Open a support issue at{" "}
              <a
                className="focus-ring font-semibold text-ink underline decoration-divider underline-offset-4 transition hover:decoration-ink"
                href="https://github.com/ihvou/skillsaggregator/issues"
              >
                github.com/ihvou/skillsaggregator/issues
              </a>
              . Include the affected resource URL, category, skill, and a short description
              of the problem.
            </p>
          </section>
          <section>
            <h2 className="text-xl font-extrabold text-ink">Resource Reports</h2>
            <p className="mt-3 text-base leading-7 text-muted">
              Subskills reviews submitted resources before they appear publicly. Reports about
              inaccurate, unsafe, duplicated, broken, or off-topic resources are routed back
              into the same moderation process.
            </p>
          </section>
          <section>
            <h2 className="text-xl font-extrabold text-ink">Account Deletion</h2>
            <p className="mt-3 text-base leading-7 text-muted">
              Anonymous and upgraded users can delete their account from the mobile Account tab
              or the dedicated web deletion page after opening that account on the device.
            </p>
          </section>
        </div>
      </section>
    </div>
  );
}
