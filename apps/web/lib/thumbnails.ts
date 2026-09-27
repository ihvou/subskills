const SUPABASE_STORAGE_MARKER = "/storage/v1/object/public/";

/**
 * The web's own copies of video thumbnails, on Cloudflare R2 behind our domain
 * (scripts/rehost-thumbnails.mjs, links.web_thumbnail_key). They are named by a
 * hash of the image, so unlike the platform addresses they don't name the video.
 */
export const WEB_THUMBNAIL_BASE_URL = "https://img.subskills.xyz";
const WEB_THUMBNAIL_HOST = new URL(WEB_THUMBNAIL_BASE_URL).hostname;

export function webThumbnailUrl(key: string | null | undefined): string | null {
  const trimmed = key?.trim().replace(/^\/+/, "");
  return trimmed ? `${WEB_THUMBNAIL_BASE_URL}/${trimmed}` : null;
}

function cleanHost(hostname: string) {
  return hostname.replace(/^www\./, "").toLowerCase();
}

export function youtubeVideoIdFromUrl(value: string | null | undefined) {
  if (!value) return null;
  try {
    const parsed = new URL(value);
    const host = cleanHost(parsed.hostname);
    if (host === "youtu.be") return parsed.pathname.split("/").filter(Boolean)[0] ?? null;
    if (host === "youtube.com" || host.endsWith(".youtube.com")) {
      if (parsed.pathname.startsWith("/shorts/")) return parsed.pathname.split("/")[2] ?? null;
      if (parsed.pathname.startsWith("/embed/")) return parsed.pathname.split("/")[2] ?? null;
      return parsed.searchParams.get("v");
    }
    if (host === "i.ytimg.com" || host.endsWith(".ytimg.com") || host === "img.youtube.com") {
      const parts = parsed.pathname.split("/").filter(Boolean);
      const videoIndex = parts.findIndex((part) => part === "vi");
      return videoIndex >= 0 ? parts[videoIndex + 1] ?? null : null;
    }
  } catch {
    return null;
  }
  return null;
}

function youtubeThumbnailUrl(value: string | null | undefined) {
  const videoId = youtubeVideoIdFromUrl(value);
  return videoId ? `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg` : null;
}

function isAllowedAbsoluteThumbnail(parsed: URL) {
  const host = cleanHost(parsed.hostname);
  if (parsed.protocol === "https:") {
    return (
      host === WEB_THUMBNAIL_HOST ||
      host === "i.ytimg.com" ||
      host.endsWith(".ytimg.com") ||
      host === "img.youtube.com" ||
      host.endsWith(".supabase.co") ||
      host.endsWith(".supabase.in") ||
      host.endsWith(".tiktokcdn.com") ||
      host.endsWith(".tiktokcdn-us.com") ||
      host.endsWith(".tiktokcdn-eu.com") ||
      host.endsWith(".muscdn.com")
    );
  }
  if (parsed.protocol !== "http:") return false;
  return (
    (host === "localhost" || host === "127.0.0.1" || host === "192.168.10.108") &&
    parsed.port === "54321"
  );
}

function storageKeyFromValue(value: string) {
  const trimmed = value.trim().replace(/^\/+/, "");
  if (!trimmed) return null;

  try {
    const parsed = new URL(trimmed);
    const markerIndex = parsed.pathname.indexOf(SUPABASE_STORAGE_MARKER);
    if (markerIndex === -1) return null;
    return decodeURIComponent(parsed.pathname.slice(markerIndex + SUPABASE_STORAGE_MARKER.length));
  } catch {
    return trimmed.startsWith("link-thumbnails/") || trimmed.startsWith("thumbnails/") ? trimmed : null;
  }
}

function publicStorageUrl(key: string) {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL?.replace(/\/+$/, "");
  if (!supabaseUrl) return null;
  return `${supabaseUrl}/storage/v1/object/public/${key.replace(/^\/+/, "")}`;
}

export function normalizeThumbnailUrl(
  thumbnailUrl: string | null | undefined,
  canonicalUrl?: string | null,
  fallbackThumbnailUrl?: string | null,
): string | null {
  const youtubeFallback =
    youtubeThumbnailUrl(thumbnailUrl) ??
    youtubeThumbnailUrl(fallbackThumbnailUrl) ??
    youtubeThumbnailUrl(canonicalUrl);
  const candidates = [thumbnailUrl, fallbackThumbnailUrl]
    .map((value) => (typeof value === "string" ? value.trim() : ""))
    .filter(Boolean);
  const seen = new Set<string>();

  for (const candidate of candidates) {
    if (seen.has(candidate)) continue;
    seen.add(candidate);

    try {
      const parsed = new URL(candidate);
      if (isAllowedAbsoluteThumbnail(parsed)) return candidate;

      const storageKey = storageKeyFromValue(candidate);
      const storageUrl = storageKey ? publicStorageUrl(storageKey) : null;
      if (storageUrl) return storageUrl;
    } catch {
      const storageKey = storageKeyFromValue(candidate);
      const storageUrl = storageKey ? publicStorageUrl(storageKey) : null;
      if (storageUrl) return storageUrl;
    }
  }

  return youtubeFallback;
}
