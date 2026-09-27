import type { Metadata } from "next";
import Link from "next/link";
import { BrandMark } from "@/components/BrandMark";
import { FooterNavLinks, HeaderNavLinks } from "@/components/NavLinks";
import { getBaseUrl } from "@/lib/env";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL(getBaseUrl()),
  title: {
    default: "Subskills",
    template: "%s | Subskills",
  },
  description:
    "Find the best free tutorials for any skill you want to learn, across sports and training.",
  // Served from /public under a VERSIONED filename on purpose. Next serves the
  // app/icon.* convention at a stable URL with `max-age=31536000, immutable`, so a
  // rebrand is invisible to anyone who ever loaded the old icon (we shipped a red
  // mark and browsers/CDN kept serving the green one for days). Bump the -vN suffix
  // whenever the icon changes so the URL — and therefore the cache entry — is new.
  icons: {
    icon: "/icon-v2.svg",
    apple: "/apple-icon-v2.png",
  },
  manifest: "/manifest.webmanifest",
  openGraph: {
    title: "Subskills",
    description:
      "Find the best free tutorials for any skill you want to learn, across sports and training.",
    images: [{ url: "/og-image.png", width: 1200, height: 630, alt: "Subskills" }],
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body className="flex min-h-screen flex-col bg-bgGroup text-text">
        <header className="bg-bgGroup">
          <nav className="mx-auto flex w-full max-w-5xl items-center justify-between gap-3 px-4 py-4 sm:py-5">
            <Link
              href="/"
              className="focus-ring inline-flex items-center gap-2 whitespace-nowrap text-base font-extrabold tracking-tight text-ink"
            >
              <BrandMark className="h-7 w-7 shrink-0" />
              Subskills
            </Link>
            <div className="flex items-center gap-3 text-[13px] font-medium text-muted sm:gap-4 sm:text-sm">
              <HeaderNavLinks />
            </div>
          </nav>
        </header>
        <main className="flex-1">{children}</main>
        <footer className="border-t border-divider">
          <div className="mx-auto flex w-full max-w-5xl flex-wrap items-center justify-between gap-3 px-4 py-6 text-sm text-muted">
            <span>© {new Date().getFullYear()} Subskills</span>
            <div className="flex items-center gap-4">
              <FooterNavLinks />
            </div>
          </div>
        </footer>
      </body>
    </html>
  );
}
