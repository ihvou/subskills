import { getAllCatalogs, getContributorProfiles } from "@/lib/data";
import { getBaseUrl } from "@/lib/env";

/**
 * Plain-text sitemap — the same URL set as `sitemap.ts`, in Google's other
 * supported sitemap format: one absolute URL per line, UTF-8, nothing else.
 *
 * WHY THIS EXISTS. Search Console reported "Sitemap could not be read" for
 * /sitemap.xml on 2026-08-15 and again on 08-23 after a resubmit, with 0
 * discovered pages, while every check from outside passed: HTTP 200,
 * application/xml, no BOM, 307 balanced <url> blocks, xmllint clean, valid
 * under gzip and brotli, and correct when fetched with Googlebot's exact
 * User-Agent and Accept headers. Disabling Cloudflare Bot Fight Mode did not
 * change it.
 *
 * So this is a discriminator as much as a workaround. Submit both and read the
 * result:
 *   - .txt reads, .xml does not  -> the XML document or its content type is at
 *     fault, and the URL set is fine.
 *   - both fail                  -> the format is innocent; something between
 *     Google and the origin is serving them different bytes than we see. Look
 *     at the CDN edge next, per-PoP.
 *
 * A text sitemap carries no lastmod, changefreq or priority. That costs almost
 * nothing here: those are hints Google largely ignores, and lastmod on every
 * row is `new Date()` at render time anyway, which is not a real modification
 * date. Discovery is the whole job, and a bare URL list does that.
 *
 * Keep the URL set identical to sitemap.ts. The comparison only means something
 * if both files list the same pages.
 */
export const revalidate = 3600;

export async function GET() {
  const [catalogs, contributors] = await Promise.all([
    getAllCatalogs({ publicOnly: true }),
    getContributorProfiles(),
  ]);
  const base = getBaseUrl();

  const urls = [
    base,
    `${base}/contributors`,
    ...contributors.map((contributor) => `${base}/contributors/${contributor.slug}`),
    ...catalogs.flatMap(({ category, skills }) => [
      `${base}/${category.slug}`,
      ...skills.map((skill) => `${base}/${category.slug}/${skill.slug}`),
    ]),
  ];

  // Trailing newline: the spec is one URL per line, and a final newline keeps
  // the last entry a complete line rather than a truncated one.
  return new Response(`${urls.join("\n")}\n`, {
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
    },
  });
}
