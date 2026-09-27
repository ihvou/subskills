import { describe, expect, it } from "vitest";
import { buildDedupeKey, normalizeCanonicalUrl, slugify } from "./dedupe";

describe("dedupe helpers", () => {
  it("normalizes noisy youtube URLs", () => {
    expect(
      normalizeCanonicalUrl("https://youtu.be/abc123?si=share&utm_source=test#chapter"),
    ).toBe("https://www.youtube.com/watch?v=abc123");
  });

  it("builds LINK_ADD keys from canonical URL and target skill", () => {
    expect(
      buildDedupeKey("LINK_ADD", {
        url: "https://example.com/watch",
        canonical_url: "https://example.com/watch?utm_medium=social",
        target_skill_id: "00000000-0000-4000-8000-000000000101",
      }),
    ).toBe("LINK_ADD:https://example.com/watch:00000000-0000-4000-8000-000000000101");
  });

  it("requires a resolved author for LINK_UPVOTE_SKILL keys", () => {
    expect(() =>
      buildDedupeKey("LINK_UPVOTE_SKILL", {
        link_id: "00000000-0000-4000-8000-000000000301",
        target_skill_id: "00000000-0000-4000-8000-000000000101",
      }),
    ).toThrow("resolved author");
  });

  it("builds SOURCE_ADD keys from the source and category", () => {
    expect(
      buildDedupeKey("SOURCE_ADD", {
        source_type: "youtube_channel",
        identifier: "UCExample",
        display_name: "Example Coach",
        category_id: "00000000-0000-4000-8000-000000000001",
      }),
    ).toBe("SOURCE_ADD:youtube_channel:ucexample:00000000-0000-4000-8000-000000000001");
  });

  it("slugifies skill names", () => {
    expect(slugify("Serve (low)")).toBe("serve-low");
  });
});
