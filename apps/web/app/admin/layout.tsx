import Link from "next/link";

export default async function AdminLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <div className="mx-auto max-w-6xl px-4 py-10">
      <div className="mb-6 flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="text-sm font-semibold uppercase tracking-wide text-court">
            Admin moderation
          </p>
          <h1 className="mt-1 text-3xl font-bold text-ink">Queue</h1>
        </div>
        <nav className="flex gap-3 text-sm font-semibold text-graphite">
          <Link className="focus-ring hover:text-court" href="/admin">
            Pending
          </Link>
          <Link className="focus-ring hover:text-court" href="/admin/runs">
            Runs
          </Link>
        </nav>
      </div>
      {children}
    </div>
  );
}
