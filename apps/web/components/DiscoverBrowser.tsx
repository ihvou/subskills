"use client";

import { useMemo, useState } from "react";
import { AppDownloadButtons } from "@/components/AppDownloadButtons";
import { PageHeader } from "@/components/PageHeader";
import { SectionHeader } from "@/components/SectionHeader";
import { SkillSearch } from "@/components/SkillSearch";
import { SkillTile } from "@/components/SkillTile";
import { SuggestLinkButton } from "@/components/SuggestLinkButton";
import type { DiscoverCategorySection } from "@/lib/data";

interface DiscoverBrowserProps {
  sections: DiscoverCategorySection[];
}

function matches(value: string | null | undefined, query: string) {
  return value?.toLowerCase().includes(query) ?? false;
}

export function DiscoverBrowser({ sections }: DiscoverBrowserProps) {
  const [search, setSearch] = useState("");
  const query = search.trim().toLowerCase();
  const visibleSections = useMemo(() => {
    if (!query) return sections;
    return sections
      .map((section) => {
        const categoryMatched =
          matches(section.category.name, query) || matches(section.category.description, query);
        if (categoryMatched) return section;
        const skills = section.skills.filter(
          (tile) =>
            matches(tile.skill.name, query) || matches(tile.skill.description, query),
        );
        return skills.length ? { ...section, skills } : null;
      })
      .filter((section): section is DiscoverCategorySection => Boolean(section));
  }, [query, sections]);

  return (
    <div className="pb-20">
      <PageHeader
        title="The best free tutorials, sorted by skill."
        subtitle="Curated free tutorials for every sub-skill across sports and training."
      />

      <section className="mx-auto mt-6 max-w-5xl px-4">
        <AppDownloadButtons />
        <div className="mt-5 max-w-2xl">
          <SkillSearch
            value={search}
            onChange={setSearch}
            placeholder="Search sports or sub-skills"
            label="Search sports or sub-skills"
          />
        </div>
        <div className="mt-4">
          <SuggestLinkButton />
        </div>
      </section>

      <div className="mt-12 space-y-14">
        {visibleSections.map((section) => (
          <section key={section.category.id} aria-labelledby={`cat-${section.category.slug}`}>
            <div className="mx-auto max-w-5xl px-4">
              <SectionHeader title={section.category.name} href={`/${section.category.slug}`} />
            </div>
            <div className="mt-5 overflow-x-auto no-scrollbar">
              <div className="mx-auto flex max-w-5xl gap-4 px-4 pb-2">
                {section.skills.map((tile) => (
                  <SkillTile
                    key={tile.skill.id}
                    skill={tile.skill}
                    thumbnailUrl={tile.latest_thumbnail}
                  />
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
            No matching sports or sub-skills yet.
          </div>
        ) : null}
      </div>
    </div>
  );
}
