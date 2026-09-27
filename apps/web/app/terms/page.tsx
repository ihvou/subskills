import { PageHeader } from "@/components/PageHeader";

export const metadata = {
  title: "Terms",
  description: "Terms for using Subskills.",
};

const sections = [
  {
    title: "Use Of The Catalog",
    body: "Subskills indexes public learning resources and links to third-party sites. Resource availability, safety, and content are controlled by the destination service.",
  },
  {
    title: "Accounts",
    body: "Accounts let you save resources, track watched state, vote, and suggest resources. You are responsible for keeping your sign-in method secure.",
  },
  {
    title: "Suggestions And Public Contributions",
    body: "Suggested resources and public notes may be reviewed, edited, declined, or removed. Do not submit illegal, harmful, abusive, infringing, or intentionally misleading content.",
  },
  {
    title: "No Professional Advice",
    body: "Subskills is an educational discovery tool. Training decisions are your responsibility, and sport or fitness activities may involve risk.",
  },
  {
    title: "Changes",
    body: "These terms may change as the product evolves. Continued use after an update means you accept the updated terms.",
  },
];

export default function TermsPage() {
  return (
    <div className="pb-20">
      <PageHeader
        title="Terms"
        subtitle="The basic rules for using Subskills."
        backHref="/"
      />
      <section className="mx-auto max-w-3xl px-4">
        <p className="mt-8 text-sm font-semibold uppercase text-muted">Last updated June 25, 2026</p>
        <div className="mt-6 space-y-8">
          {sections.map((section) => (
            <section key={section.title}>
              <h2 className="text-xl font-extrabold text-ink">{section.title}</h2>
              <p className="mt-3 text-base leading-7 text-muted">{section.body}</p>
            </section>
          ))}
        </div>
      </section>
    </div>
  );
}
