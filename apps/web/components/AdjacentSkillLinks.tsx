import { ChevronLeft, ChevronRight } from "lucide-react";
import { SkillTile } from "@/components/SkillTile";
import type { AdjacentSkill } from "@/lib/data";

interface AdjacentSkillLinksProps {
  previous: AdjacentSkill | null;
  next: AdjacentSkill | null;
}

/**
 * The sub-skills before and after this one in the category's learning path,
 * under the last video: somewhere to go when the list runs out, and links that
 * join each sub-skill page to its neighbours. Same tiles as the home page.
 */
export function AdjacentSkillLinks({ previous, next }: AdjacentSkillLinksProps) {
  if (!previous && !next) return null;
  return (
    <nav aria-label="Previous and next sub-skills" className="mx-auto mt-6 max-w-5xl px-4" data-nosnippet="">
      <div className="grid grid-cols-2 gap-3 sm:gap-6">
        <div className="flex flex-col items-start">
          {previous ? (
            <>
              <p className="mb-2 flex items-center gap-1 text-sm font-semibold text-muted">
                <ChevronLeft className="h-4 w-4" aria-hidden="true" />
                Previous
              </p>
              <div className="w-full sm:max-w-[320px]">
                <SkillTile skill={previous.skill} thumbnailUrl={previous.thumbnail_url} fluid />
              </div>
            </>
          ) : null}
        </div>
        <div className="flex flex-col items-end">
          {next ? (
            <>
              <p className="mb-2 flex items-center gap-1 text-sm font-semibold text-muted">
                Next
                <ChevronRight className="h-4 w-4" aria-hidden="true" />
              </p>
              <div className="w-full sm:max-w-[320px]">
                <SkillTile skill={next.skill} thumbnailUrl={next.thumbnail_url} fluid />
              </div>
            </>
          ) : null}
        </div>
      </div>
    </nav>
  );
}
