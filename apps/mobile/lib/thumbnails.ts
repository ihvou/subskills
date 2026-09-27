const SUPABASE_STORAGE_MARKER = "/storage/v1/object/public/";

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
      return videoIndex >= 0 ? (parts[videoIndex + 1] ?? null) : null;
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
  const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL?.replace(/\/+$/, "");
  if (!supabaseUrl) return null;
  return `${supabaseUrl}/storage/v1/object/public/${key.replace(/^\/+/, "")}`;
}

/**
 * Resolves a stored `thumbnail_url` into something `expo-image` can load.
 *
 * The collection pipeline stores three shapes:
 *  - a YouTube thumbnail URL (`https://i.ytimg.com/vi/<id>/hqdefault.jpg`)
 *  - a bare Supabase storage key for cached non-YouTube thumbnails
 *    (`link-thumbnails/<id>.jpg`) — these MUST be expanded to an absolute URL
 *  - occasionally a full Supabase public URL (re-pointed to the configured host)
 *
 * Unlike the web build (which gates on `next/image` remotePatterns), the native
 * client can load any absolute http(s) URL, so we only rewrite storage values
 * and otherwise pass absolute URLs straight through.
 */
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

    const storageKey = storageKeyFromValue(candidate);
    const storageUrl = storageKey ? publicStorageUrl(storageKey) : null;
    if (storageUrl) return storageUrl;

    try {
      const parsed = new URL(candidate);
      if (parsed.protocol === "http:" || parsed.protocol === "https:") return candidate;
    } catch {
      // Not an absolute URL and not a recognizable storage key — try fallback.
    }
  }

  return youtubeFallback;
}
