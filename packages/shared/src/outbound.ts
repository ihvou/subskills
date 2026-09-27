/**
 * Outbound video links, encoded.
 *
 * Public pages don't print the address of a YouTube, TikTok or Instagram video.
 * Each card links to `/go#<token>` instead: a click decodes the token in the
 * browser and opens the video, and opening the link any other way (new tab,
 * pasted) loads the static /go page, which decodes it and forwards. Everything
 * after `#` stays in the browser, so a crawler sees one URL (/go), which
 * robots.txt keeps it out of, instead of one per video.
 *
 * This is obfuscation, not secrecy: the key ships in the page's JavaScript. It
 * keeps the addresses out of the HTML and out of casual view, which is the point.
 *
 * Decoding refuses any host outside VIDEO_HOSTS. The key is public, so anyone
 * can mint a token; without that check /go would forward to any site they chose.
 *
 * Pure JavaScript on purpose (no TextEncoder, URL or btoa): the mobile app
 * bundles this package too.
 */

const VIDEO_HOSTS = ["youtube.com", "youtu.be", "tiktok.com", "instagram.com"] as const;
const TOKEN_VERSION = "1";
const KEY = "subskills/outbound/v1:3f9c2a71e8d44b0c";

const BASE64URL = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

function hostOf(url: string) {
  const match = /^https?:\/\/([^/?#:@]+)(?::\d+)?(?:[/?#]|$)/i.exec(url.trim());
  return match?.[1]?.toLowerCase() ?? null;
}

/** True when `url` is a video on a host whose links are encoded. */
export function isEncodedVideoUrl(url: string | null | undefined): url is string {
  if (!url) return false;
  const host = hostOf(url);
  if (!host) return false;
  return VIDEO_HOSTS.some((allowed) => host === allowed || host.endsWith(`.${allowed}`));
}

function fnv1a(bytes: number[]) {
  let hash = 0x811c9dc5;
  for (const byte of bytes) {
    hash ^= byte;
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash >>> 0;
}

function utf8Bytes(text: string) {
  const bytes: number[] = [];
  const encoded = encodeURIComponent(text);
  for (let i = 0; i < encoded.length; i += 1) {
    if (encoded[i] === "%") {
      bytes.push(parseInt(encoded.slice(i + 1, i + 3), 16));
      i += 2;
    } else {
      bytes.push(encoded.charCodeAt(i));
    }
  }
  return bytes;
}

function utf8Text(bytes: number[]) {
  return decodeURIComponent(bytes.map((byte) => `%${byte.toString(16).padStart(2, "0")}`).join(""));
}

/** A keystream seeded by the key and a per-link nonce (mulberry32). */
function keystream(nonce: number, length: number) {
  let state = (fnv1a(utf8Bytes(KEY)) ^ nonce) >>> 0;
  const out: number[] = [];
  for (let i = 0; i < length; i += 1) {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    out.push(((t ^ (t >>> 14)) >>> 0) & 0xff);
  }
  return out;
}

function toBase64Url(bytes: number[]) {
  let out = "";
  for (let i = 0; i < bytes.length; i += 3) {
    const chunk = (bytes[i]! << 16) | ((bytes[i + 1] ?? 0) << 8) | (bytes[i + 2] ?? 0);
    out += BASE64URL[(chunk >> 18) & 63]! + BASE64URL[(chunk >> 12) & 63]!;
    if (i + 1 < bytes.length) out += BASE64URL[(chunk >> 6) & 63]!;
    if (i + 2 < bytes.length) out += BASE64URL[chunk & 63]!;
  }
  return out;
}

function fromBase64Url(text: string) {
  const bytes: number[] = [];
  let buffer = 0;
  let bits = 0;
  for (const char of text) {
    const value = BASE64URL.indexOf(char);
    if (value < 0) return null;
    buffer = (buffer << 6) | value;
    bits += 6;
    if (bits >= 8) {
      bits -= 8;
      bytes.push((buffer >> bits) & 0xff);
    }
  }
  return bytes;
}

/**
 * Encodes a video URL into a /go token, or returns null for any other address.
 * Deterministic: the nonce comes from the URL itself, so the server render and
 * the browser agree, and two videos never share a token prefix.
 */
export function encodeOutboundToken(url: string | null | undefined): string | null {
  if (!isEncodedVideoUrl(url)) return null;
  const plain = utf8Bytes(url.trim());
  const nonce = fnv1a(plain);
  const stream = keystream(nonce, plain.length);
  const nonceBytes = [nonce >>> 24, (nonce >>> 16) & 0xff, (nonce >>> 8) & 0xff, nonce & 0xff];
  return TOKEN_VERSION + toBase64Url([...nonceBytes, ...plain.map((byte, i) => byte ^ stream[i]!)]);
}

/** Decodes a /go token back to its video URL, or null if it is malformed or not a video. */
export function decodeOutboundToken(token: string | null | undefined): string | null {
  if (!token || token[0] !== TOKEN_VERSION) return null;
  const bytes = fromBase64Url(token.slice(1));
  if (!bytes || bytes.length < 5) return null;
  const nonce = ((bytes[0]! << 24) | (bytes[1]! << 16) | (bytes[2]! << 8) | bytes[3]!) >>> 0;
  const cipher = bytes.slice(4);
  const stream = keystream(nonce, cipher.length);
  let url: string;
  try {
    url = utf8Text(cipher.map((byte, i) => byte ^ stream[i]!));
  } catch {
    return null;
  }
  if (fnv1a(utf8Bytes(url)) !== nonce) return null;
  return isEncodedVideoUrl(url) ? url : null;
}

/** The href a card uses for an encoded video. */
export function outboundHref(token: string) {
  return `/go#${token}`;
}
