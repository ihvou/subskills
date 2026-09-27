import { describe, expect, it } from "vitest";
import { getDiscoverSections } from "../lib/data";
import { normalizeThumbnailUrl } from "../lib/thumbnails";

describe("mobile catalog fallback", () => {
  it("returns category sections with badminton skills when Supabase env is absent", async () => {
    const sections = await getDiscoverSections();
    expect(sections.length).toBeGreaterThan(0);
    const badminton = sections.find((section) => section.category.slug === "badminton");
    expect(badminton).toBeDefined();
    expect(badminton!.skills.length).toBeGreaterThanOrEqual(5);
    expect(badminton!.skills.some((tile) => tile.skill.slug === "forehand-smash")).toBe(true);
  });

  it("normalizes repeated bad thumbnail fallbacks without recursion", () => {
    expect(
      normalizeThumbnailUrl(
        "not-a-thumbnail",
        "https://example.com/article",
        "not-a-thumbnail",
      ),
    ).toBeNull();
  });
});
