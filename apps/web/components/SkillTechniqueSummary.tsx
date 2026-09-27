import type { SkillTechniqueSummary as SummaryData } from "@/lib/data";

/**
 * The technique summary above a skill's video list — what the coaches on this page
 * agree on, synthesised from their transcripts (docs/skill-summary-routine.md).
 *
 * Three constraints shaped this component:
 *
 * 1. INDEXABLE WHILE COLLAPSED. This is the only unique prose on a sub-skill page,
 *    so the FULL text ships in the HTML and is collapsed with CSS. Collapsing by not
 *    rendering (state + conditional JSX) would hide it from Google, Bing and LLM
 *    crawlers and waste the point of the feature. `<details>` keeps every word in
 *    the served document, works with JavaScript disabled, and is semantic.
 *
 * 2. THE TOGGLE SITS AT THE BOTTOM WHEN OPEN. `<summary>` must be the first child of
 *    `<details>`, which would leave "Show less" stranded in the middle of the
 *    expanded block. Making the details a flex column and giving the summary
 *    `order: 2` when open moves it below the content — still CSS-only, no JS.
 *
 * 3. IT IS NOT THE MAIN EVENT. The videos are. Dots and the toggle use the same
 *    muted grey as the watch/save icons rather than the accent colour, so the block
 *    reads as supporting material instead of competing with the list.
 */
export function SkillTechniqueSummary({ summary }: { summary: SummaryData; skillName?: string }) {
  const consensus = summary.consensus ?? [];
  const mistakes = summary.mistakes ?? [];
  if (consensus.length === 0) return null;

  // Two visible when collapsed; the rest ride inside <details> and stay in the DOM.
  const visible = consensus.slice(0, 2);
  const hidden = consensus.slice(2);
  const hasMore = hidden.length > 0 || mistakes.length > 0;

  const bullet = <span aria-hidden className="mt-[0.45rem] h-1.5 w-1.5 shrink-0 rounded-full bg-muted" />;

  return (
    <section
      aria-labelledby="technique-summary-heading"
      className="rounded-xl border border-line bg-bgGroup/40 p-4 sm:p-5"
    >
      <h2 id="technique-summary-heading" className="text-sm font-bold uppercase tracking-wide text-muted">
        What coaches agree on
      </h2>

      <ul className="mt-3 space-y-2">
        {visible.map((item) => (
          <li key={item.point} className="flex gap-2 text-sm leading-snug text-ink">
            {bullet}
            <span>{item.point}</span>
          </li>
        ))}
      </ul>

      {hasMore ? (
        <details className="group mt-2 flex flex-col">
          {/* order-2 when open puts the toggle below the revealed content. */}
          <summary className="focus-ring inline-flex cursor-pointer list-none items-center gap-1 rounded-md py-1 text-sm font-semibold text-muted transition-colors hover:text-ink group-open:order-2 group-open:mt-3">
            <span className="group-open:hidden">Show more</span>
            <span className="hidden group-open:inline">Show less</span>
          </summary>

          <div className="group-open:order-1">
            {hidden.length > 0 ? (
              <ul className="mt-2 space-y-2">
                {hidden.map((item) => (
                  <li key={item.point} className="flex gap-2 text-sm leading-snug text-ink">
                    {bullet}
                    <span>{item.point}</span>
                  </li>
                ))}
              </ul>
            ) : null}

            {mistakes.length > 0 ? (
              <>
                <h3 className="mt-4 text-sm font-bold uppercase tracking-wide text-muted">Common mistakes</h3>
                <ul className="mt-2 space-y-2">
                  {mistakes.map((item) => (
                    <li key={item.point} className="flex gap-2 text-sm leading-snug text-ink">
                      {bullet}
                      <span>{item.point}</span>
                    </li>
                  ))}
                </ul>
              </>
            ) : null}
          </div>
        </details>
      ) : null}
    </section>
  );
}
