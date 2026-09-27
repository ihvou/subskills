import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  transpilePackages: ["@skillsaggregator/shared"],
  images: {
    // Serve thumbnails directly from their source CDNs instead of through
    // /_next/image. Sources are already-optimized JPEGs (YouTube hqdefault
    // ~480px/~25KB, TikTok CDN, Supabase storage), so on-the-fly resizing buys
    // little — and costs a lot: next/image emitted a 16-variant srcset (16w to
    // 3840w) per thumbnail, ~2.6K image URLs per category page. Each variant a
    // client or bot fetched was host image-CDN work + bandwidth (part of the
    // 2026-06 bot-traffic bill), and the srcset bloat alone was ~300KB of HTML
    // per page.
    // Reassessed for M68 on 2026-06-18: keep this on until we introduce a
    // capped image loader/transform policy; reopening unbounded transforms
    // would trade a modest LCP win for the same bot-amplification cost risk.
    unoptimized: true,
    remotePatterns: [
      // Our own rehosted video thumbnails (Cloudflare R2; see lib/thumbnails.ts).
      { protocol: "https", hostname: "img.subskills.xyz" },
      { protocol: "https", hostname: "i.ytimg.com" },
      { protocol: "https", hostname: "*.ytimg.com" },
      { protocol: "https", hostname: "img.youtube.com" },
      { protocol: "https", hostname: "*.supabase.co" },
      { protocol: "https", hostname: "*.supabase.in" },
      { protocol: "https", hostname: "*.tiktokcdn.com" },
      { protocol: "https", hostname: "*.tiktokcdn-us.com" },
      { protocol: "https", hostname: "*.tiktokcdn-eu.com" },
      { protocol: "https", hostname: "*.muscdn.com" },
      { protocol: "https", hostname: "*.cdninstagram.com" },
      { protocol: "https", hostname: "*.fbcdn.net" },
      { protocol: "http", hostname: "127.0.0.1", port: "54321" },
      { protocol: "http", hostname: "localhost", port: "54321" },
      { protocol: "http", hostname: "192.168.10.108", port: "54321" },
    ],
  },

  // Keep shared caches away from React Server Component navigation payloads.
  //
  // A page is served under TWO cache keys: the HTML document, and the RSC payload
  // that client-side navigation fetches at `?_rsc=<hash>`. Netlify already varies on
  // `_rsc` (see the `netlify-vary` response header), and Cloudflare sits in front
  // caching both under the page's `max-age=14400`. The two keys then drift apart.
  //
  // Measured 2026-08-22 on /badminton/backhand-clear, whose summary was written at
  // 03:07 UTC:
  //     GET /badminton/backhand-clear              -> 192 kB, summary PRESENT
  //     GET /badminton/backhand-clear?_rsc=3lb4g   -> cf HIT,  summary ABSENT
  //     GET /badminton/backhand-clear?_rsc=<novel> -> cf MISS, summary PRESENT
  // The origin was correct throughout; Cloudflare was serving a stale RSC payload.
  // Because a given client sends a STABLE `_rsc` hash, it hits the same poisoned
  // entry on every attempt — so clicking through from the home page never showed the
  // summary while opening the URL directly always did, indefinitely.
  //
  // The HTML key self-heals: crawlers and direct loads request it often enough to
  // turn over. The RSC key is requested far more rarely, so with two layers of
  // stale-while-revalidate it can sit stale for hours.
  //
  // `no-store` stops shared caches holding it at all. These payloads are per-navigation
  // and cheap to render (one Supabase read against an ISR-backed route), so the cost is
  // small next to shipping stale pages to everyone who browses by clicking rather than
  // deep-linking. The HTML route keeps its normal ISR caching — this header applies only
  // when `_rsc` is present.
  async headers() {
    return [
      {
        source: "/:path*",
        has: [{ type: "query", key: "_rsc" }],
        headers: [
          { key: "Cache-Control", value: "no-store, must-revalidate" },
          { key: "CDN-Cache-Control", value: "no-store" },
          { key: "Netlify-CDN-Cache-Control", value: "no-store" },
        ],
      },
    ];
  },
};

export default nextConfig;
