import Link from "next/link";
import { ChevronLeft } from "lucide-react";
import type { ReactNode } from "react";

interface PageHeaderProps {
  title: string;
  subtitle?: string | undefined;
  /** Back-link target. Omit to skip the back pill (tab-root pages). */
  backHref?: string | undefined;
  rightAccessory?: ReactNode;
  eyebrow?: ReactNode;
}

/**
 * Web counterpart to the mobile PageHeader.
 *  - Optional round back pill in the top-left
 *  - Optional accessory in the top-right (e.g. the sort/filter menu trigger)
 *  - Big bold left-aligned title with optional muted subtitle below
 */
export function PageHeader({
  title,
  subtitle,
  backHref,
  rightAccessory,
  eyebrow,
}: PageHeaderProps) {
  return (
    <header className="mx-auto w-full max-w-5xl px-4 pt-8 md:pt-12">
      {(backHref || rightAccessory || eyebrow) && (
        <div className="mb-6 flex items-center justify-between gap-3">
          <div>
            {backHref ? (
              <Link
                href={backHref}
                className="focus-ring inline-flex h-10 w-10 items-center justify-center rounded-full bg-surface shadow-pill ring-1 ring-divider transition hover:bg-bgGroup"
                aria-label="Back"
              >
                <ChevronLeft className="h-5 w-5 text-ink" strokeWidth={2.5} />
              </Link>
            ) : null}
            {eyebrow && !backHref ? eyebrow : null}
          </div>
          <div className="flex items-center gap-2">{rightAccessory}</div>
        </div>
      )}
      <h1 className="text-4xl font-extrabold tracking-tight text-ink md:text-5xl">
        {title}
      </h1>
      {subtitle ? (
        <p className="mt-2 text-base text-muted md:text-lg">{subtitle}</p>
      ) : null}
    </header>
  );
}
