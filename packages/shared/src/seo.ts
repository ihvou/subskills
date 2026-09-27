import type { SkillResource, SkillSummary } from "./types";

export function groupResourcesByLevel(resources: SkillResource[]) {
  return {
    beginner: resources.filter((resource) => resource.skill_level === "beginner"),
    intermediate: resources.filter((resource) => resource.skill_level === "intermediate"),
    advanced: resources.filter((resource) => resource.skill_level === "advanced"),
    uncategorized: resources.filter((resource) => resource.skill_level === null),
  };
}

export function makeSkillMetaDescription(skill: Pick<SkillSummary, "name" | "description">) {
  const fallback = `Curated badminton resources for improving ${skill.name.toLowerCase()}.`;
  return (skill.description ?? fallback).slice(0, 150);
}

export function makeCanonical(baseUrl: string, categorySlug: string, skillSlug?: string) {
  const cleanBase = baseUrl.replace(/\/+$/, "");
  return skillSlug ? `${cleanBase}/${categorySlug}/${skillSlug}` : `${cleanBase}/${categorySlug}`;
}
