import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Not found",
  robots: { index: false, follow: false },
};

export default function NotFound() {
  return (
    <div className="mx-auto max-w-3xl px-4 py-16">
      <p className="text-sm font-semibold uppercase tracking-wide text-court">Not found</p>
      <h1 className="mt-3 text-4xl font-bold text-ink">This page is not in the library yet</h1>
      <p className="mt-4 text-base leading-7 text-graphite">
        The resource or skill may have moved, or it may still be waiting for moderation.
      </p>
      <Link
        href="/"
        className="focus-ring mt-6 inline-flex min-h-10 items-center rounded-md bg-court px-4 text-sm font-semibold text-white hover:bg-ink"
      >
        Browse resources
      </Link>
    </div>
  );
}
