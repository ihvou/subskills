import { describe, expect, it } from "vitest";
import {
  adjacentSkillsInLearningPath,
  buildLearningPathIndex,
  compareSkillsByLearningPath,
  filterLearningPathStages,
  sortResources,
} from "./resource-utils";
import type { SkillResource, SkillSummary } from "./types";

function skill(
  id: string,
  name: string,
  subskill_difficulty: number,
  learning_order: number,
): SkillSummary {
  return {
    id,
    category_id: "category",
    category_slug: "badminton",
    slug: name.toLowerCase().replace(/\s+/g, "-"),
    name,
    description: null,
    resource_count: 0,
    subskill_difficulty,
    learning_order,
  };
}

function resource(id: string, skillItem: SkillSummary, skill_level: SkillResource["skill_level"]): SkillResource {
  return {
    id,
    public_note: null,
    skill_level,
    upvote_count: 0,
    vote_score: 0,
    curator_score: 0,
    created_at: "2026-01-01T00:00:00.000Z",
    link: {
      id: `link-${id}`,
      url: "https://example.com",
      canonical_url: "https://example.com",
      domain: "example.com",
      title: id,
      description: null,
      thumbnail_url: null,
      content_type: "video",
    },
    skill: {
      id: skillItem.id,
      slug: skillItem.slug,
      name: skillItem.name,
      category_slug: skillItem.category_slug,
    },
  };
}

describe("buildLearningPathIndex", () => {
  it("places each skill once by skill difficulty instead of resource level", () => {
    const grip = skill("skill-1", "Grip technique", 1, 1);
    const smash = skill("skill-2", "Forehand smash", 4.2, 15);
    const backhand = skill("skill-3", "Backhand clear", 4.8, 19);
    const stages = buildLearningPathIndex(
      [backhand, smash, grip],
      [
        resource("grip-advanced-video", grip, "advanced"),
        resource("smash-beginner-video", smash, "beginner"),
        resource("backhand-intermediate-video", backhand, "intermediate"),
        resource("backhand-advanced-video", backhand, "advanced"),
      ],
    );

    expect(stages.find((stage) => stage.value === "beginner")?.entries.map((entry) => entry.skill.name))
      .toEqual(["Grip technique"]);
    expect(stages.find((stage) => stage.value === "advanced")?.entries.map((entry) => entry.skill.name))
      .toEqual(["Forehand smash", "Backhand clear"]);
    expect(stages.flatMap((stage) => stage.entries.map((entry) => entry.skill.id)))
      .toEqual(["skill-1", "skill-2", "skill-3"]);
  });

  it("filters learning path stages without dropping videos whose resource level differs from the skill stage", () => {
    const grip = skill("skill-1", "Grip technique", 1, 1);
    const stages = buildLearningPathIndex([grip], [resource("grip-advanced-video", grip, "advanced")]);
    const filtered = filterLearningPathStages(stages, { level: "beginner" });

    expect(filtered).toHaveLength(1);
    expect(filtered[0]?.entries[0]?.resources.map((item) => item.id)).toEqual(["grip-advanced-video"]);
  });

  it("ranks combined score ahead of legacy vote fallbacks", () => {
    const grip = skill("skill-1", "Grip technique", 1, 1);
    const highCommunity = {
      ...resource("community-and-coach-video", grip, "beginner"),
      combined_score: 2.2,
      curator_score: 1.2,
      vote_score: 1,
    };
    const legacyPopular = {
      ...resource("legacy-popular-video", grip, "beginner"),
      combined_score: 1.4,
      curator_score: 1.4,
      vote_score: 99,
    };

    expect(sortResources([legacyPopular, highCommunity], "popular").map((item) => item.id))
      .toEqual(["community-and-coach-video", "legacy-popular-video"]);
  });
});

describe("compareSkillsByLearningPath", () => {
  it("orders by difficulty, then learning order, then name, with unrated skills last", () => {
    const skills = [
      { name: "Clear", subskill_difficulty: 2, learning_order: 1 },
      { name: "Lob", subskill_difficulty: 1, learning_order: 5 },
      { name: "Drop", subskill_difficulty: 1, learning_order: 5 },
      { name: "Unrated", subskill_difficulty: null, learning_order: null },
      { name: "Grip", subskill_difficulty: 1, learning_order: 2 },
    ];
    expect([...skills].sort(compareSkillsByLearningPath).map((item) => item.name)).toEqual([
      "Grip",
      "Drop",
      "Lob",
      "Clear",
      "Unrated",
    ]);
  });
});

describe("adjacentSkillsInLearningPath", () => {
  const grip = { id: "grip", name: "Grip", subskill_difficulty: 1, learning_order: 1 };
  const clear = { id: "clear", name: "Clear", subskill_difficulty: 2, learning_order: 1 };
  const smash = { id: "smash", name: "Smash", subskill_difficulty: 3, learning_order: 1 };
  const published = [smash, grip, clear];

  it("links the neighbours in learning-path order", () => {
    expect(adjacentSkillsInLearningPath(published, clear)).toEqual({ previous: grip, next: smash });
  });

  it("has no previous for the first sub-skill and no next for the last", () => {
    expect(adjacentSkillsInLearningPath(published, grip)).toEqual({ previous: null, next: clear });
    expect(adjacentSkillsInLearningPath(published, smash)).toEqual({ previous: clear, next: null });
  });

  it("places an unpublished sub-skill in the order without linking to it", () => {
    const drop = { id: "drop", name: "Drop", subskill_difficulty: 2, learning_order: 2 };
    expect(adjacentSkillsInLearningPath(published, drop)).toEqual({ previous: clear, next: smash });
  });

  it("has no neighbours when nothing else is published", () => {
    expect(adjacentSkillsInLearningPath([grip], grip)).toEqual({ previous: null, next: null });
  });
});
