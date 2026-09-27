import { describe, expect, it } from "vitest";
import {
  badmintonSkills,
  decodeOutboundToken,
  makeCanonical,
  makeSkillMetaDescription,
} from "@skillsaggregator/shared";
import robots from "../app/robots";
import { shapeLinkWithContributor, type LinkRow } from "../lib/resourceRows";
import { normalizeThumbnailUrl } from "../lib/thumbnails";

describe("outbound video links", () => {
  it("strips a video's address and carries it as a /go token", () => {
    const link = shapeLinkWithContributor<LinkRow>({
      id: "l1",
      url: "https://www.youtube.com/watch?v=abc123def45",
      canonical_url: "https://www.youtube.com/watch?v=abc123def45",
      domain: "youtube.com",
      description: "Full platform description with https://youtu.be/other links",
      creator_url: "https://www.youtube.com/@coach",
    });
    expect(link.url).toBe("");
    expect(link.canonical_url).toBe("");
    expect(link.description).toBeNull();
    expect(link.creator_url).toBeNull();
    expect(decodeOutboundToken(link.go)).toBe("https://www.youtube.com/watch?v=abc123def45");
    // The thumbnail is still derived from the real URL before it is blanked.
    expect(link.thumbnail_url).toBe("https://i.ytimg.com/vi/abc123def45/hqdefault.jpg");
    expect(JSON.stringify(link)).not.toContain("youtube.com/watch");
  });

  it("keeps the source detectable when the stored domain is missing", () => {
    const link = shapeLinkWithContributor<LinkRow>({ id: "l2", url: "https://www.tiktok.com/@coach/video/123", domain: null });
    expect(link.domain).toBe("www.tiktok.com");
    expect(link.url).toBe("");
  });

  it("shows the rehosted thumbnail and keeps storage keys that name the video off the page", () => {
    const link = shapeLinkWithContributor<LinkRow>({
      id: "l4",
      url: "https://www.tiktok.com/@coach/video/7300000000000000001",
      domain: "tiktok.com",
      thumbnail_storage_path: "thumbnails/tiktok/7300000000000000001.jpg",
      web_thumbnail_key: "v1/0123456789abcdef0123456789abcdef.webp",
    });
    expect(link.thumbnail_url).toBe("https://img.subskills.xyz/v1/0123456789abcdef0123456789abcdef.webp");
    expect(link.thumbnail_storage_path).toBeNull();
    expect(JSON.stringify(link)).not.toContain("7300000000000000001");
  });

  it("leaves links that aren't videos alone", () => {
    const link = shapeLinkWithContributor<LinkRow>({ id: "l3", url: "https://example.com/article", domain: "example.com" });
    expect(link.url).toBe("https://example.com/article");
    expect(link.go).toBeNull();
  });
});

describe("robots.txt", () => {
  it("blocks the report and /go URLs without catching /golf", () => {
    const rules = robots().rules;
    const disallow = (Array.isArray(rules) ? rules[0] : rules)?.disallow ?? [];
    expect(disallow).toEqual(expect.arrayContaining(["/support?", "/go$"]));
    expect(disallow).not.toContain("/go");
  });
});

describe("SEO helpers", () => {
  it("builds canonical skill URLs", () => {
    expect(makeCanonical("https://example.com/", "badminton", "forehand-smash")).toBe(
      "https://example.com/badminton/forehand-smash",
    );
  });

  it("keeps meta descriptions within search-friendly length", () => {
    expect(makeSkillMetaDescription(badmintonSkills[2]!).length).toBeLessThanOrEqual(150);
  });

  it("normalizes unsafe thumbnail URLs before they reach next/image", () => {
    process.env.NEXT_PUBLIC_SUPABASE_URL = "https://project.supabase.co";
    expect(
      normalizeThumbnailUrl(
        "http://kong:8000/storage/v1/object/public/link-thumbnails/demo.jpg",
        "https://example.com/article",
      ),
    ).toBe("https://project.supabase.co/storage/v1/object/public/link-thumbnails/demo.jpg");
    expect(normalizeThumbnailUrl("https://bad.example/image.jpg", "https://youtu.be/abc123def45")).toBe(
      "https://i.ytimg.com/vi/abc123def45/hqdefault.jpg",
    );
    expect(
      normalizeThumbnailUrl(
        "https://bad.example/image.jpg",
        "https://example.com/article",
        "https://bad.example/image.jpg",
      ),
    ).toBeNull();
  });
});
