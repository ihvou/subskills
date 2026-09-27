import Link from "next/link";
import { PlusCircle } from "lucide-react";

interface SuggestLinkButtonProps {
  categorySlug?: string;
  skillSlug?: string;
  compact?: boolean;
}

export function SuggestLinkButton({ categorySlug, skillSlug, compact = false }: SuggestLinkButtonProps) {
  const params = new URLSearchParams();
  if (categorySlug) params.set("category", categorySlug);
  if (skillSlug) params.set("skill", skillSlug);
  const href = `/suggest${params.size ? `?${params.toString()}` : ""}`;

  return (
    <Link
      href={href}
      className="focus-ring inline-flex items-center justify-center gap-2 rounded-md bg-ink px-3 py-2 text-sm font-bold text-surface transition hover:opacity-90"
    >
      <PlusCircle className="h-4 w-4" />
      {compact ? "Suggest" : "Suggest a link"}
    </Link>
  );
}
