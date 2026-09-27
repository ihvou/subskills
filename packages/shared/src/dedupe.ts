import { suggestionPayloadByType } from "./schemas";
import type { SuggestionType } from "./types";

export function normalizeCanonicalUrl(input: string): string {
  const parsed = new URL(input);
  parsed.hash = "";
  parsed.hostname = parsed.hostname.toLowerCase();

  if (parsed.hostname === "youtu.be") {
    const videoId = parsed.pathname.replace("/", "");
    parsed.hostname = "www.youtube.com";
    parsed.pathname = "/watch";
    parsed.search = videoId ? `?v=${videoId}` : "";
  }

  for (const key of [...parsed.searchParams.keys()]) {
    if (
      key.startsWith("utm_") ||
      ["fbclid", "gclid", "si", "feature", "ab_channel"].includes(key)
    ) {
      parsed.searchParams.delete(key);
    }
  }

  const ordered = [...parsed.searchParams.entries()].sort(([a], [b]) => a.localeCompare(b));
  parsed.search = "";
  for (const [key, value] of ordered) {
    parsed.searchParams.append(key, value);
  }

  if (parsed.pathname.length > 1) {
    parsed.pathname = parsed.pathname.replace(/\/+$/, "");
  }

  return parsed.toString();
}

export function getDomain(input: string): string {
  return new URL(input).hostname.replace(/^www\./, "");
}

export function normalizeSkillName(name: string): string {
  return name.trim().toLowerCase().replace(/\s+/g, " ");
}

export function slugify(input: string): string {
  return input
    .trim()
    .toLowerCase()
    .replace(/&/g, " and ")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

export function buildDedupeKey(
  type: SuggestionType,
  payload: unknown,
  authorInternalUserId?: string | null,
): string {
  const parsed = suggestionPayloadByType[type].parse(payload) as Record<string, string>;
  const requireValue = (key: string) => {
    const value = parsed[key];
    if (!value) throw new Error(`Missing ${key} for ${type}`);
    return value;
  };

  switch (type) {
    case "LINK_ADD":
      return [
        "LINK_ADD",
        normalizeCanonicalUrl(requireValue("canonical_url")),
        requireValue("target_skill_id"),
      ].join(":");
    case "LINK_ATTACH_SKILL":
      return ["LINK_ATTACH_SKILL", requireValue("link_id"), requireValue("target_skill_id"), "attach"].join(":");
    case "LINK_DETACH_SKILL":
      return ["LINK_DETACH_SKILL", requireValue("link_id"), requireValue("target_skill_id"), "detach"].join(":");
    case "LINK_UPVOTE_SKILL":
      if (!authorInternalUserId) {
        throw new Error("LINK_UPVOTE_SKILL requires a resolved author");
      }
      return [
        "LINK_UPVOTE_SKILL",
        requireValue("link_id"),
        requireValue("target_skill_id"),
        authorInternalUserId,
        "upvote",
      ].join(":");
    case "SOURCE_ADD":
      return [
        "SOURCE_ADD",
        requireValue("source_type"),
        requireValue("identifier").toLowerCase(),
        parsed.category_id ?? "global",
      ].join(":");
    case "SKILL_CREATE":
      return ["SKILL_CREATE", requireValue("category_id"), normalizeSkillName(requireValue("name"))].join(":");
    case "SKILL_DELETE":
      return ["SKILL_DELETE", requireValue("skill_id"), "delete"].join(":");
  }
}
