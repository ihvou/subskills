"use client";

import { useMemo, useState } from "react";
import {
  buildLearningPathIndex,
  buildSkillResourceSections,
  filterLearningPathStages,
  type CategorySummary,
  type ResourceSourceFilter,
  type SkillLevel,
  type SkillResource,
  type SkillSummary,
} from "@skillsaggregator/shared";
import { PageHeader } from "@/components/PageHeader";
import { ResourceCard } from "@/components/ResourceCard";
import { ResourceTile } from "@/components/ResourceTile";
import { SectionHeader } from "@/components/SectionHeader";
import { SkillSearch } from "@/components/SkillSearch";
import { SortFilterMenu } from "@/components/SortFilterMenu";
import { SuggestLinkButton } from "@/components/SuggestLinkButton";
import type { ResourceSort } from "@/lib/data";

interface CategoryResourceBrowserProps {
  category: CategorySummary;
  skills: SkillSummary[];
  resources: SkillResource[];
}

type CategoryTab = "subskills" | "path";

export function CategoryResourceBrowser({
  category,
  skills,
  resources,
}: CategoryResourceBrowserProps) {
  const [tab, setTab] = useState<CategoryTab>("subskills");
  const [search, setSearch] = useState("");
  const [level, setLevel] = useState<SkillLevel | null>(null);
  const [sort, setSort] = useState<ResourceSort>("popular");
  const [source, setSource] = useState<ResourceSourceFilter>("all");

  const query = search.trim().toLowerCase();
  const visibleSections = useMemo(() => {
    return buildSkillResourceSections(skills, resources, {
      query,
      level: level ?? "all",
      source,
      sort,
      perSkill: 12,
    });
  }, [level, query, resources, skills, sort, source]);

  const learningPathIndex = useMemo(
    () => buildLearningPathIndex(skills, resources),
    [resources, skills],
  );

  const learningPathStages = useMemo(() => {
    // Search lives only in the Sub-skills tab, so the Learning Path is never
    // filtered by the query (it would otherwise filter invisibly).
    return filterLearningPathStages(learningPathIndex, {
      query: "",
      level: level ?? "all",
      source,
      perSkill: 3,
    });
  }, [learningPathIndex, level, source]);

  return (
    <div className="pb-20">
      <PageHeader
        title={category.name}
        subtitle={category.description ?? undefined}
        backHref="/"
        rightAccessory={
          <>
            <SuggestLinkButton categorySlug={category.slug} />
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

      <section className="mx-auto mt-8 max-w-5xl px-4">
        <div className="inline-flex rounded-lg bg-surface p-1 shadow-sm ring-1 ring-divider">
          {[
            { value: "subskills" as const, label: "Sub-skills" },
            { value: "path" as const, label: "Learning Path" },
          ].map((item) => {
            const selected = tab === item.value;
            return (
              <button
                key={item.value}
                type="button"
                onClick={() => setTab(item.value)}
                aria-pressed={selected}
                className={`focus-ring rounded-md px-3 py-2 text-sm font-bold transition ${
                  selected ? "bg-ink text-surface" : "text-muted hover:text-ink"
                }`}
              >
                {item.label}
              </button>
            );
          })}
        </div>
      </section>

      {tab === "subskills" ? (
        <div className="mt-8">
          <div className="mx-auto max-w-5xl px-4">
            <SkillSearch
              value={search}
              onChange={setSearch}
              placeholder={`Search ${category.name} sub-skills`}
              label={`Search ${category.name} sub-skills`}
            />
          </div>
          <div className="mt-8 space-y-14">
          {visibleSections.map((section) => (
            <section key={section.skill.id} aria-labelledby={`skill-${section.skill.slug}`}>
              <div className="mx-auto max-w-5xl px-4">
                <SectionHeader
                  title={section.skill.name}
                  href={`/${category.slug}/${section.skill.slug}`}
                  subtitle={
                    section.skill.resource_count
                      ? `${section.skill.resource_count} ${section.skill.resource_count === 1 ? "resource" : "resources"}`
                      : undefined
                  }
                />
              </div>
              <div className="mt-5 overflow-x-auto no-scrollbar">
                <div className="mx-auto flex max-w-5xl gap-4 px-4 pb-2">
                  {section.resources.map((resource) => (
                    <ResourceTile key={resource.id} resource={resource} />
                  ))}
                </div>
              </div>
              <div className="mx-auto mt-6 max-w-5xl px-4">
                <div className="h-px bg-divider" />
              </div>
            </section>
          ))}
          {visibleSections.length === 0 ? (
            <div className="mx-auto max-w-5xl px-4 text-sm text-muted">
              No sub-skills match these filters yet.
            </div>
          ) : null}
          </div>
        </div>
      ) : (
        <div className="mt-12 space-y-14">
          {learningPathStages.map((stage) => (
            <section key={stage.value} aria-labelledby={`path-${stage.value}`}>
              <div className="mx-auto max-w-5xl px-4">
                <div className="mb-5 flex items-end justify-between gap-3">
                  <div>
                    <h2 id={`path-${stage.value}`} className="text-2xl font-extrabold text-ink">
                      {stage.label}
                    </h2>
                    <p className="mt-1 text-sm text-muted">
                      {stage.entries.length} {stage.entries.length === 1 ? "sub-skill" : "sub-skills"}
                    </p>
                  </div>
                </div>

                {stage.entries.length ? (
                  <div className="space-y-10">
                    {stage.entries.map((entry) => (
                      <div key={`${stage.value}-${entry.skill.id}`}>
                        <h3 className="text-lg font-extrabold text-ink">{entry.skill.name}</h3>
                        <p className="mt-1 text-sm text-muted">
                          {entry.total} {entry.total === 1 ? "resource" : "resources"}
                        </p>
                        <div className="mt-3 divide-y divide-divider">
                          {entry.resources.map((resource) => (
                            <div key={resource.id} className="py-5">
                              <ResourceCard resource={resource} />
                            </div>
                          ))}
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <p className="text-sm text-muted">No matching resources in this stage yet.</p>
                )}
              </div>
            </section>
          ))}
        </div>
      )}
    </div>
  );
}
