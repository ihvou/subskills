"use client";

import { useMemo, useState, type ReactNode } from "react";
import {
  resourcePassesFilters,
  sortResources,
  type CategorySummary,
  type ResourceSourceFilter,
  type SkillLevel,
  type SkillResource,
  type SkillSummary,
} from "@skillsaggregator/shared";
import { PageHeader } from "@/components/PageHeader";
import { ResourceCard } from "@/components/ResourceCard";
import { SortFilterMenu } from "@/components/SortFilterMenu";
import { SuggestLinkButton } from "@/components/SuggestLinkButton";
import type { ResourceSort } from "@/lib/data";

interface SkillResourceBrowserProps {
  category: CategorySummary;
  skill: SkillSummary;
  resources: SkillResource[];
  /** Rendered between the skill description and the video list. */
  summarySlot?: ReactNode;
  /** Rendered under the video list. */
  footerSlot?: ReactNode;
}

const LEVEL_LABELS = {
  all: "All levels",
  beginner: "Beginner",
  intermediate: "Intermediate",
  advanced: "Advanced",
} as const;
const SORT_LABELS = { popular: "Popular", newest: "Newest" } as const;
const SOURCE_LABELS = { all: "All sources", youtube: "YouTube", tiktok: "TikTok", instagram: "Instagram" } as const;
// A description this short shares the category's line instead of taking a row of
// its own. Every one is today (89 characters at most); a longer one keeps its own
// paragraph.
const INLINE_DESCRIPTION_MAX = 100;

export function SkillResourceBrowser({ category, skill, resources, summarySlot, footerSlot }: SkillResourceBrowserProps) {
  const [level, setLevel] = useState<SkillLevel | null>(null);
  const [sort, setSort] = useState<ResourceSort>("popular");
  const [source, setSource] = useState<ResourceSourceFilter>("all");
  const filteredResources = useMemo(() => {
    const next = resources.filter((resource) =>
      resourcePassesFilters(resource, { level: level ?? "all", source }),
    );
    return sortResources(next, sort);
  }, [level, resources, sort, source]);
  // Same as mobile: the default sort is not worth a line. Category stays because
  // on the web the skill page can be entered straight from search or a link.
  const subtitleParts: string[] = [`${category.name}`];
  if (sort !== "popular") subtitleParts.push(SORT_LABELS[sort]);
  if (level) subtitleParts.push(LEVEL_LABELS[level]);
  if (source !== "all") subtitleParts.push(SOURCE_LABELS[source]);
  const inlineDescription =
    skill.description && skill.description.length <= INLINE_DESCRIPTION_MAX ? skill.description : null;
  const subtitle = inlineDescription
    ? `${subtitleParts.join(" / ")} · ${inlineDescription}`
    : subtitleParts.join(" / ");

  return (
    <div className="pb-20">
      <PageHeader
        title={skill.name}
        subtitle={subtitle}
        backHref={`/${category.slug}`}
        rightAccessory={
          <>
            <SuggestLinkButton categorySlug={category.slug} skillSlug={skill.slug} compact />
            <SortFilterMenu
              currentLevel={level}
              currentSort={sort}
              currentSource={source}
              onLevelChange={setLevel}
              onSortChange={setSort}
              onSourceChange={setSource}
            />
          </>
        }
      />

      {skill.description && !inlineDescription ? (
        <section className="mx-auto mt-6 max-w-5xl px-4">
          <p className="max-w-3xl text-base leading-7 text-muted md:text-lg">
            {skill.description}
          </p>
        </section>
      ) : null}

      {summarySlot ? (
        <section className="mx-auto mt-6 max-w-5xl px-4">{summarySlot}</section>
      ) : null}

      {/* data-nosnippet: search snippets for this page come from the part above
          (title, description, what coaches agree on, common mistakes), never from
          a creator's video title. The list is still indexed; it just isn't quoted,
          and Bing keeps it out of its AI answers too. */}
      <section className="mx-auto mt-6 max-w-5xl px-4" data-nosnippet="">
        {filteredResources.length === 0 ? (
          <p className="text-sm text-muted">
            No matches for this filter. Open the menu (...) to change sort or level.
          </p>
        ) : (
          <div className="divide-y divide-divider">
            {filteredResources.map((resource) => (
              <div key={resource.id} className="py-5 first:pt-0 last:pb-0">
                <ResourceCard resource={resource} />
              </div>
            ))}
          </div>
        )}
      </section>

      {footerSlot}
    </div>
  );
}
