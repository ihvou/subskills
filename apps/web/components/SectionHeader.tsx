import Link from "next/link";
import { ChevronRight } from "lucide-react";

interface SectionHeaderProps {
  title: string;
  subtitle?: string | undefined;
  href?: string | undefined;
  showChevron?: boolean | undefined;
}

/**
 * Apple-Podcasts-style section header. Title + optional chevron-right »
 * (clickable when `href` is provided), optional muted subtitle.
 */
export function SectionHeader({ title, subtitle, href, showChevron }: SectionHeaderProps) {
  const renderChevron = showChevron ?? Boolean(href);
  const content = (
    <>
      <div className="flex items-center gap-1">
        <h2 className="text-2xl font-extrabold tracking-tight text-ink md:text-3xl">{title}</h2>
        {renderChevron ? (
          <ChevronRight className="h-7 w-7 text-ink" strokeWidth={3} />
        ) : null}
      </div>
      {subtitle ? <p className="mt-1 text-sm text-muted">{subtitle}</p> : null}
    </>
  );

  if (href) {
    return (
      <Link
        href={href}
        className="focus-ring group block w-fit transition hover:opacity-60"
        aria-label={`Open ${title}`}
      >
        {content}
      </Link>
    );
  }
  return <div className="w-fit">{content}</div>;
}
