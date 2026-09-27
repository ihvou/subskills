import { useEffect, useMemo, useState } from "react";
import { Pressable, ScrollView, StyleSheet, Text, useWindowDimensions, View } from "react-native";
import { useRouter } from "expo-router";
import { useQuery } from "@tanstack/react-query";
import Svg, {
  Circle,
  Defs,
  LinearGradient,
  Path,
  Rect,
  Stop,
} from "react-native-svg";
import { Screen } from "@/components/Screen";
import { byLearningOrder, getCategories, getSkillsForCategory } from "@/lib/data";
import { setOnboardingCompleted, setOnboardingInterests } from "@/lib/localState";
import { colors, radius, shadows, spacing } from "@/lib/theme";
import { track } from "@/lib/analytics";

/**
 * Four screens, in the order agreed with the user:
 *
 *   1. levels — you get better by level, and here is what to improve
 *   2. skills — a sport is not one thing; it breaks into named skills
 *   3. watch  — queue tutorials and tick them off
 *   4. share  — bring outside videos into the same list
 *
 * Screens 1 and 2 lead with encouragement rather than description. The earlier
 * pass narrated the UI sitting directly underneath ("Pick your sports" above a
 * list of sports), which told the reader nothing they could not already see.
 *
 * Screen 2 is built from the choice made on screen 1: pick badminton and it
 * names badminton's real skills and real total. Pick nothing and it falls back
 * to a generic sport, because asserting "Badminton is 32 separate skills" to
 * someone who chose climbing is worse than saying nothing specific at all.
 */

// Palette values that only exist in this illustration set. Everything with a
// counterpart in the theme uses the theme.
const HAIRLINE = "rgba(0, 0, 0, 0.10)";
const BAR_TRACK = "#e8e7e1";
const THUMB_FILL = "#dcdbd5";
const LINE_FILL = "#e2e1db";
const ACCENT_WASH = "#faf5ff";
const INSTAGRAM = "#c13584";
const YOUTUBE = "#ff0000";

const SLIDES = ["levels", "skills", "watch", "share"] as const;
type SlideKind = (typeof SLIDES)[number];

/** A sentence with one phrase set in ink, so the eye lands on the claim. */
type BodyCopy = { pre: string; strong?: string; post?: string };

// Shown on screen 2 when no sport was chosen. Deliberately the four things
// every sport has, so the card still reads as a real character sheet.
const GENERIC_CATEGORY = "Sports category";
const GENERIC_SKILLS = ["Technique", "Footwork", "Positioning", "Tactics"];

// Illustrative progress, not the user's. A brand-new user has done nothing, but
// an empty card would not show what "level up by skill" means.
const STAT_FILLS = [0.66, 1, 0.33, 0, 0, 0];

const MAX_STAT_ROWS = 6;

/**
 * Height of the scrolling chip window on screen 1.
 *
 * Fixed at 124 it showed three rows on every device and left a large dead band
 * above the frame on a big phone, which made the area look complete rather than
 * scrollable. This spends that band instead: the rest of the slide — header,
 * ladder, title, copy, frame chrome, button, dots — is roughly 600pt, so give
 * the window what is left of the screen, bounded so it stays a window rather
 * than becoming a full list on a tall phone or a slot on a short one. The
 * bottom bound is a floor, not a guarantee: chipScrollWrap can shrink past it
 * when a small screen genuinely has no room.
 */
const CHIP_WINDOW_MIN = 124;
const CHIP_WINDOW_MAX = 260;
const SLIDE_ONE_FURNITURE = 600;

export default function OnboardingScreen() {
  const router = useRouter();
  const [index, setIndex] = useState(0);
  const [interests, setInterests] = useState<string[]>([]);
  const { height: screenHeight } = useWindowDimensions();
  const chipWindow = Math.round(
    Math.min(CHIP_WINDOW_MAX, Math.max(CHIP_WINDOW_MIN, screenHeight - SLIDE_ONE_FURNITURE)),
  );

  const categoriesQuery = useQuery({
    queryKey: ["onboarding-categories"],
    queryFn: getCategories,
    staleTime: 300_000,
  });
  const categories = useMemo(() => categoriesQuery.data ?? [], [categoriesQuery.data]);

  // The first sport picked drives screen 2. Fetched as soon as it is chosen —
  // while the user is still reading screen 1 — so the card is populated by the
  // time they reach it rather than swapping under them.
  const focusSlug = interests[0] ?? null;
  const focusQuery = useQuery({
    queryKey: ["onboarding-skills", focusSlug],
    queryFn: () => getSkillsForCategory(focusSlug as string),
    enabled: focusSlug !== null,
    staleTime: 300_000,
  });

  useEffect(() => {
    // M137 declared this event but nothing ever fired it, so the funnel had no
    // denominator between "installed" and "onboarded".
    track("onboarding_started");
  }, []);

  const kind = SLIDES[index] ?? SLIDES[0]!;
  const isLast = index === SLIDES.length - 1;

  /** Screen 2's card and copy: the chosen sport, or a generic stand-in. */
  const focus = useMemo(() => {
    const chosen = focusSlug ? categories.find((item) => item.slug === focusSlug) ?? null : null;
    const skills = focusQuery.data?.skills ?? [];
    if (!chosen || skills.length === 0) {
      return { label: GENERIC_CATEGORY, rows: GENERIC_SKILLS, total: null as number | null, examples: null as string[] | null };
    }
    // Curriculum order, not the alphabetical order the query returns. A card
    // that reads as a character sheet should show the path through the sport;
    // by name it opened on "Badminton rules explained, Badminton warm up".
    const ordered = [...skills].sort(byLearningOrder);
    return {
      label: chosen.name,
      rows: ordered.slice(0, MAX_STAT_ROWS).map((skill) => skill.name),
      total: ordered.length,
      examples: ordered.slice(0, 3).map((skill) => skill.name),
    };
  }, [focusSlug, categories, focusQuery.data]);

  function toggleInterest(slug: string) {
    setInterests((current) =>
      current.includes(slug) ? current.filter((item) => item !== slug) : [...current, slug],
    );
  }

  function finish(via: "completed" | "skipped") {
    // Skipping keeps whatever was already picked. Discarding it — which this
    // screen used to do — threw away a choice the user had actually made.
    setOnboardingInterests(interests);
    setOnboardingCompleted(true);
    // `skipped` distinguishes "got through it" from "dismissed it", which is the
    // difference between an onboarding that works and one people escape.
    track(via === "completed" ? "onboarding_completed" : "onboarding_skipped", {
      categories: interests.length,
      last_slide: index + 1,
    });
    if (interests.length > 0) track("categories_selected", { count: interests.length });
    router.replace("/");
  }

  const title = TITLES[kind];
  const body = bodyFor(kind, focus);

  return (
    <Screen edges={["top", "bottom"]}>
      <View style={styles.topRow}>
        <Text style={styles.step}>
          {index + 1} / {SLIDES.length}
        </Text>
        <Pressable
          onPress={() => finish("skipped")}
          style={({ pressed }) => [styles.skipButton, pressed && styles.pressed]}
          accessibilityRole="button"
          accessibilityLabel="Skip onboarding"
        >
          <Text style={styles.skipText}>Skip</Text>
        </Pressable>
      </View>

      {/* Screen 1 is top-aligned, because its choice frame is what sits against
          the bottom. The rest centre their block in whatever the header and
          footer leave — one flexing container rather than two competing
          spacers, which is both predictable and unable to push the button off
          the bottom of a short screen. */}
      {kind === "levels" ? (
        <>
          <View style={styles.artWrap}>
            <SlideArt kind={kind} focus={focus} />
          </View>
          <Text style={styles.title}>{title}</Text>
          <BodyText body={body} />
          {/* A hairline card rather than a heavy outline: it still groups the
              choice with its button without the box shouting over the art. */}
          <View style={styles.choiceFrame}>
            <View style={styles.choiceHead}>
              <Text style={styles.choiceTitle}>Pick what you want to improve</Text>
              {categories.length > 0 ? (
                <Text style={styles.choiceCount}>
                  {interests.length} of {categories.length}
                </Text>
              ) : null}
            </View>

            {/* All 20 categories wrap to far more rows than fit, so this is a
                fixed window that scrolls, with the count above carrying the
                total and a fade marking that there is more below. */}
            <View style={[styles.chipScrollWrap, { maxHeight: chipWindow }]}>
              <ScrollView
                contentContainerStyle={styles.chips}
                showsVerticalScrollIndicator={false}
              >
                {categories.map((category) => {
                  const selected = interests.includes(category.slug);
                  return (
                    <Pressable
                      key={category.id}
                      onPress={() => toggleInterest(category.slug)}
                      style={[styles.chip, selected && styles.chipActive]}
                      accessibilityRole="button"
                      accessibilityState={{ selected }}
                    >
                      <Text style={[styles.chipText, selected && styles.chipTextActive]}>
                        {category.name}
                      </Text>
                    </Pressable>
                  );
                })}
              </ScrollView>
              {/* Softens the clipped row into "there is more below" rather than
                  a hard cut that reads as a rendering glitch.
                  StyleSheet.absoluteFill + a unit viewBox, NOT width="100%":
                  a percentage-sized Svg here measures as zero and paints
                  nothing at all. preserveAspectRatio="none" lets the unit
                  square stretch to whatever the layout gives it. */}
              <View pointerEvents="none" style={styles.chipFade}>
                <Svg
                  style={StyleSheet.absoluteFill}
                  viewBox="0 0 1 1"
                  preserveAspectRatio="none"
                >
                  <Defs>
                    <LinearGradient id="chipFade" x1="0" y1="0" x2="0" y2="1">
                      <Stop offset="0" stopColor={colors.surface} stopOpacity="0" />
                      <Stop offset="1" stopColor={colors.surface} stopOpacity="1" />
                    </LinearGradient>
                  </Defs>
                  <Rect x="0" y="0" width="1" height="1" fill="url(#chipFade)" />
                </Svg>
              </View>
            </View>

            <Pressable
              onPress={() => setIndex((current) => Math.min(current + 1, SLIDES.length - 1))}
              style={({ pressed }) => [styles.cta, styles.ctaInFrame, pressed && styles.pressed]}
              accessibilityRole="button"
            >
              <Text style={styles.ctaText}>Continue</Text>
            </Pressable>
          </View>
          <Dots index={index} />
        </>
      ) : (
        <>
          <View style={styles.middle}>
            <View style={styles.artWrap}>
              <SlideArt kind={kind} focus={focus} />
            </View>
            <Text style={styles.title}>{title}</Text>
            <BodyText body={body} />
          </View>
          <Dots index={index} />
          <Pressable
            onPress={() => {
              if (isLast) finish("completed");
              else setIndex((current) => Math.min(current + 1, SLIDES.length - 1));
            }}
            style={({ pressed }) => [styles.cta, pressed && styles.pressed]}
            accessibilityRole="button"
          >
            <Text style={styles.ctaText}>{isLast ? "Get started" : "Continue"}</Text>
          </Pressable>
        </>
      )}
    </Screen>
  );
}

const TITLES: Record<SlideKind, string> = {
  levels: "Get better, level by level",
  skills: "Level up by specific skills",
  watch: "Build your Watch later list",
  share: "Add outside videos too",
};

type Focus = {
  label: string;
  rows: string[];
  total: number | null;
  examples: string[] | null;
};

function bodyFor(kind: SlideKind, focus: Focus): BodyCopy {
  if (kind === "levels") {
    return {
      pre: "Every tutorial is tagged beginner, intermediate or advanced, so you always know what to work on next.",
    };
  }
  if (kind === "skills") {
    if (focus.total !== null && focus.examples !== null) {
      return {
        pre: `A sport is not one thing. ${focus.label} is `,
        strong: `${focus.total} separate skills`,
        post: ` — ${focus.examples.join(", ")} — each with its own reviewed shortlist.`,
      };
    }
    return {
      pre: "A sport is not one thing. Each one breaks into ",
      strong: "separate skills",
      post: " — technique, footwork, positioning — each with its own reviewed shortlist.",
    };
  }
  if (kind === "watch") {
    return {
      pre: "From ",
      strong: "thousands",
      post: " of tutorials the app has already reviewed. Tap the bookmark to queue one, tick it off once you have trained it.",
    };
  }
  return {
    pre: "Hit ",
    strong: "share",
    post: " on a YouTube, TikTok or Instagram video and send it to Subskills — it lands in the same list as everything else.",
  };
}

function BodyText({ body }: { body: BodyCopy }) {
  return (
    <Text style={styles.body}>
      {body.pre}
      {body.strong ? <Text style={styles.bodyStrong}>{body.strong}</Text> : null}
      {body.post}
    </Text>
  );
}

function Dots({ index }: { index: number }) {
  return (
    <View style={styles.dots}>
      {SLIDES.map((slide, dotIndex) => (
        <View key={slide} style={[styles.dot, dotIndex === index && styles.dotActive]} />
      ))}
    </View>
  );
}

function SlideArt({ kind, focus }: { kind: SlideKind; focus: Focus }) {
  if (kind === "levels") return <LadderArt />;
  if (kind === "skills") return <PlayerCard focus={focus} />;
  if (kind === "watch") return <WatchStack />;
  return <ShareArt />;
}

/* ---------------------------------------------------------------- screen 1 */

/**
 * Three rungs rising left to right, with the target glyph gaining rings as the
 * level goes up. The middle rung is the accent one: the point is that there is
 * always a next step, not that the user is at any particular height.
 */
function LadderArt() {
  return (
    <View style={styles.ladder}>
      <Rung label="Beginner" state="done" lift={0} />
      <Rung label="Intermediate" state="now" lift={30} />
      <Rung label="Advanced" state="todo" lift={60} />
    </View>
  );
}

type RungState = "done" | "now" | "todo";

function Rung({ label, state, lift }: { label: string; state: RungState; lift: number }) {
  const tint = state === "done" ? colors.ink : state === "now" ? colors.accent : colors.muted;
  return (
    <View style={[styles.rung, { paddingBottom: lift }]}>
      <View
        style={[
          styles.glyph,
          state === "done" && styles.glyphDone,
          state === "now" && styles.glyphNow,
        ]}
      >
        <Svg width={19} height={19} viewBox="0 0 24 24" fill="none">
          <Circle cx={12} cy={12} r={8} stroke={tint} strokeWidth={2} />
          {state === "now" ? <Circle cx={12} cy={12} r={3} fill={tint} /> : null}
          {/* Separate conditionals rather than a Fragment: react-native-svg
              walks its own children, and a Fragment there is a known trap. */}
          {state === "todo" ? <Circle cx={12} cy={12} r={4.5} stroke={tint} strokeWidth={2} /> : null}
          {state === "todo" ? <Circle cx={12} cy={12} r={1.6} fill={tint} /> : null}
        </Svg>
      </View>
      <View
        style={[
          styles.plate,
          state === "done" && styles.plateDone,
          state === "now" && styles.plateNow,
        ]}
      />
      <Text style={[styles.rungLabel, { color: tint }]}>{label}</Text>
    </View>
  );
}

/* ---------------------------------------------------------------- screen 2 */

/** An RPG character sheet for a sport: one bar per named skill. */
function PlayerCard({ focus }: { focus: Focus }) {
  return (
    <View style={styles.playerCard}>
      <View style={styles.avatar}>
        <Svg width={80} height={90} viewBox="0 0 80 90" fill="none">
          <Circle cx={40} cy={14} r={10.5} fill={colors.ink} />
          <Path
            d="M27 34 C 27 32, 32 30, 40 30 C 48 30, 53 32, 53 34 L 51 84 C 50.9 85.3, 49.9 86, 48.7 86 L 31.3 86 C 30.1 86, 29.1 85.3, 29 84 Z"
            fill={colors.ink}
          />
          <Path
            d="M27 36 L 11 46 L 17 26"
            stroke={colors.ink}
            strokeWidth={9}
            strokeLinecap="round"
            strokeLinejoin="round"
            fill="none"
          />
          <Path
            d="M53 36 L 69 46 L 63 26"
            stroke={colors.ink}
            strokeWidth={9}
            strokeLinecap="round"
            strokeLinejoin="round"
            fill="none"
          />
        </Svg>
      </View>

      <View style={styles.stats}>
        <View style={styles.cardTop}>
          <View style={styles.categoryTag}>
            <Text style={styles.categoryTagText} numberOfLines={1}>
              {focus.label}
            </Text>
          </View>
          {/* Illustrative, and only where it can read sensibly — a category with
              one or two skills would render "2 / 1 done". */}
          {focus.total !== null && focus.total >= 3 ? (
            <Text style={styles.levelTag}>2 / {focus.total} done</Text>
          ) : null}
        </View>

        {focus.rows.map((name, rowIndex) => (
          <View key={`${name}-${rowIndex}`} style={styles.statRow}>
            <Text style={styles.statName} numberOfLines={1}>
              {name}
            </Text>
            <View style={styles.bar}>
              <View
                style={[
                  styles.barFill,
                  rowIndex === 0 && styles.barFillAccent,
                  { width: `${(STAT_FILLS[rowIndex] ?? 0) * 100}%` },
                ]}
              />
            </View>
          </View>
        ))}

        {focus.total !== null && focus.total > focus.rows.length ? (
          <Text style={styles.more}>+{focus.total - focus.rows.length} more</Text>
        ) : null}
      </View>
    </View>
  );
}

/* ---------------------------------------------------------------- screen 3 */

/** A stack of reviewed tutorials, with the bookmark on the front card ringed. */
function WatchStack() {
  return (
    <View style={styles.stack}>
      <View style={[styles.stackCard, styles.stackCardBack]}>
        <View style={styles.thumb} />
        <View style={styles.lines}>
          <View style={styles.line} />
          <View style={[styles.line, styles.lineShort]} />
        </View>
      </View>
      <View style={[styles.stackCard, styles.stackCardMid]}>
        <View style={styles.thumb} />
        <View style={styles.lines}>
          <View style={styles.line} />
          <View style={[styles.line, styles.lineShort]} />
        </View>
      </View>
      <View style={[styles.stackCard, styles.stackCardFront]}>
        <View style={styles.thumb} />
        <View style={styles.lines}>
          <View style={styles.line} />
          <View style={[styles.line, styles.lineShort]} />
        </View>
        <View style={styles.glyphSlot}>
          <Svg width={20} height={20} viewBox="0 0 24 24" fill="none">
            <Path
              d="M6 3h12a1 1 0 0 1 1 1v17l-7-4-7 4V4a1 1 0 0 1 1-1z"
              stroke={colors.accent}
              strokeWidth={2}
              strokeLinejoin="round"
              fill={colors.accentSoft}
            />
          </Svg>
        </View>
      </View>
      <View style={[styles.tapRing, { right: 3, top: 47 }]} />
    </View>
  );
}

/* ---------------------------------------------------------------- screen 4 */

/** Three sources on the left, one dashed hop into a Subskills Watch later. */
function ShareArt() {
  return (
    <View style={styles.shareStack}>
      <View style={[styles.sourceCard, styles.sourceBack]}>
        <View style={styles.glyphSlot}>
          <Svg width={17} height={17} viewBox="0 0 24 24" fill="none">
            <Rect x={3} y={3} width={18} height={18} rx={5} stroke={INSTAGRAM} strokeWidth={2} />
            <Circle cx={12} cy={12} r={4} stroke={INSTAGRAM} strokeWidth={2} />
          </Svg>
        </View>
        <View style={styles.lines}>
          <View style={styles.line} />
        </View>
      </View>

      <View style={[styles.sourceCard, styles.sourceMid]}>
        <View style={styles.glyphSlot}>
          <Svg width={17} height={17} viewBox="0 0 24 24" fill="none">
            <Circle cx={8} cy={18} r={3} stroke={colors.ink} strokeWidth={2} />
            <Path
              d="M11 18V4l8 2"
              stroke={colors.ink}
              strokeWidth={2}
              strokeLinecap="round"
              strokeLinejoin="round"
              fill="none"
            />
          </Svg>
        </View>
        <View style={styles.lines}>
          <View style={styles.line} />
        </View>
      </View>

      <View style={[styles.sourceCard, styles.sourceFront]}>
        <View style={styles.glyphSlot}>
          <Svg width={18} height={18} viewBox="0 0 24 24" fill="none">
            <Rect x={2} y={4} width={20} height={16} rx={4} stroke={YOUTUBE} strokeWidth={2} />
            <Path d="M10 9l6 3-6 3V9z" fill={YOUTUBE} />
          </Svg>
        </View>
        <View style={styles.lines}>
          <View style={styles.line} />
        </View>
        <View style={styles.glyphSlot}>
          <Svg width={17} height={17} viewBox="0 0 24 24" fill="none">
            <Path
              d="M4 12v7a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-7M12 15V3M8 7l4-4 4 4"
              stroke={colors.accent}
              strokeWidth={2.2}
              strokeLinecap="round"
              strokeLinejoin="round"
              fill="none"
            />
          </Svg>
        </View>
      </View>

      <View style={[styles.tapRing, styles.shareTapRing]} />

      <View style={styles.arrow} pointerEvents="none">
        <Svg width={58} height={72} viewBox="0 0 60 64" fill="none">
          <Path
            d="M2 58 C 16 56, 22 34, 30 20"
            stroke={colors.accent}
            strokeWidth={2.2}
            strokeLinecap="round"
            strokeDasharray="5 6"
            fill="none"
          />
          <Path
            d="M23 20 L32 15 L35 25"
            stroke={colors.accent}
            strokeWidth={2.2}
            strokeLinecap="round"
            strokeLinejoin="round"
            fill="none"
          />
        </Svg>
      </View>

      <View style={styles.nativePhone}>
        <View style={styles.phoneBrand}>
          <Text style={styles.phoneBrandTop}>Subskills</Text>
          <Text style={styles.phoneBrandSub}>Watch later</Text>
        </View>
        {Array.from({ length: 8 }).map((_, rowIndex) => (
          <View key={rowIndex} style={styles.phoneRow}>
            <View style={[styles.phoneThumb, rowIndex === 0 && styles.phoneThumbNew]} />
            <View style={[styles.phoneLine, rowIndex === 0 && styles.phoneLineNew]} />
          </View>
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  topRow: {
    minHeight: 40,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  step: {
    fontSize: 13,
    fontWeight: "700",
    color: colors.muted,
  },
  skipButton: {
    minHeight: 36,
    justifyContent: "center",
    paddingHorizontal: spacing.md,
    borderRadius: radius.pill,
    backgroundColor: colors.surface,
  },
  skipText: {
    color: colors.ink,
    fontSize: 14,
    fontWeight: "800",
  },
  artWrap: {
    alignItems: "center",
    justifyContent: "center",
    marginTop: spacing.xs,
    marginBottom: spacing.xxs,
  },
  title: {
    marginTop: 6,
    marginBottom: spacing.xs,
    fontSize: 29,
    fontWeight: "800",
    color: colors.ink,
    letterSpacing: -0.6,
    lineHeight: 33,
  },
  body: {
    fontSize: 15,
    lineHeight: 22,
    color: colors.muted,
  },
  bodyStrong: {
    fontWeight: "800",
    color: colors.ink,
  },
  // Takes whatever the header and footer leave and centres the slide in it, so
  // the button stays put while art and copy change height between slides.
  middle: {
    flex: 1,
    justifyContent: "center",
  },

  // Screen 1 choice frame -----------------------------------------------
  choiceFrame: {
    marginTop: "auto",
    flexShrink: 1,
    backgroundColor: colors.surface,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: HAIRLINE,
    borderRadius: radius.xl,
    padding: 13,
    gap: 11,
    ...shadows.thumbnail,
  },
  choiceHead: {
    flexDirection: "row",
    alignItems: "baseline",
    justifyContent: "space-between",
  },
  choiceTitle: {
    fontSize: 13,
    fontWeight: "800",
    color: colors.ink,
  },
  choiceCount: {
    fontSize: 12,
    fontWeight: "800",
    color: colors.accent,
  },
  // maxHeight is applied inline from the screen height. flexShrink lets it give
  // way when a short device leaves less room than even the floor asks for,
  // rather than pushing the button off the bottom.
  chipScrollWrap: {
    flexShrink: 1,
  },
  chips: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 7,
    paddingBottom: 10,
  },
  chipFade: {
    position: "absolute",
    left: 0,
    right: 0,
    bottom: 0,
    height: 26,
  },
  chip: {
    minHeight: 34,
    justifyContent: "center",
    paddingHorizontal: 13,
    borderRadius: radius.pill,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: colors.divider,
    backgroundColor: colors.surface,
  },
  chipActive: {
    borderColor: colors.ink,
    backgroundColor: colors.ink,
  },
  chipText: {
    color: colors.muted,
    fontSize: 13,
    fontWeight: "700",
  },
  chipTextActive: {
    color: colors.surface,
  },

  // Footer ---------------------------------------------------------------
  dots: {
    flexDirection: "row",
    gap: 6,
    alignItems: "center",
    marginTop: 14,
    marginBottom: 12,
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: colors.divider,
  },
  dotActive: {
    width: 22,
    backgroundColor: colors.ink,
  },
  cta: {
    height: 56,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: radius.lg,
    backgroundColor: colors.ink,
  },
  ctaInFrame: {
    height: 52,
    borderRadius: 12,
  },
  ctaText: {
    color: colors.surface,
    fontSize: 16,
    fontWeight: "800",
  },
  pressed: {
    opacity: 0.7,
  },

  // Screen 1 ladder ------------------------------------------------------
  ladder: {
    flexDirection: "row",
    alignItems: "flex-end",
    height: 190,
    alignSelf: "stretch",
    paddingHorizontal: 4,
  },
  rung: {
    flex: 1,
    alignItems: "center",
    gap: 9,
  },
  glyph: {
    width: 38,
    height: 38,
    borderRadius: 11,
    alignItems: "center",
    justifyContent: "center",
    borderWidth: 1.5,
    borderColor: colors.divider,
    backgroundColor: colors.surface,
  },
  glyphDone: {
    borderColor: colors.ink,
  },
  glyphNow: {
    borderColor: colors.accent,
    backgroundColor: ACCENT_WASH,
  },
  plate: {
    alignSelf: "stretch",
    height: 7,
    borderRadius: 4,
    backgroundColor: colors.divider,
  },
  plateDone: {
    backgroundColor: colors.ink,
  },
  plateNow: {
    backgroundColor: colors.accent,
  },
  rungLabel: {
    fontSize: 11,
    fontWeight: "800",
  },

  // Screen 2 player card -------------------------------------------------
  playerCard: {
    alignSelf: "stretch",
    flexDirection: "row",
    gap: 13,
    backgroundColor: colors.surface,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: HAIRLINE,
    borderRadius: 18,
    padding: 14,
    ...shadows.thumbnail,
  },
  avatar: {
    width: 88,
    height: 108,
    borderRadius: 12,
    backgroundColor: colors.bgGroup,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: HAIRLINE,
    alignItems: "center",
    justifyContent: "center",
    overflow: "hidden",
  },
  stats: {
    flex: 1,
    gap: 8,
    minWidth: 0,
  },
  cardTop: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    gap: spacing.xs,
    marginBottom: 0,
  },
  categoryTag: {
    flexShrink: 1,
    backgroundColor: colors.ink,
    borderRadius: radius.pill,
    paddingHorizontal: 11,
    paddingVertical: 4,
  },
  categoryTagText: {
    color: colors.surface,
    fontSize: 11,
    fontWeight: "800",
  },
  levelTag: {
    fontSize: 11,
    fontWeight: "800",
    color: colors.muted,
  },
  statRow: {
    gap: 3,
  },
  statName: {
    fontSize: 11.5,
    fontWeight: "800",
    color: colors.text,
  },
  bar: {
    height: 6,
    borderRadius: 3,
    backgroundColor: BAR_TRACK,
    overflow: "hidden",
  },
  barFill: {
    height: "100%",
    borderRadius: 3,
    backgroundColor: colors.ink,
  },
  barFillAccent: {
    backgroundColor: colors.accent,
  },
  more: {
    fontSize: 11,
    fontWeight: "800",
    color: colors.accent,
    marginTop: 2,
  },

  // Screen 3 stack -------------------------------------------------------
  stack: {
    alignSelf: "stretch",
    height: 156,
  },
  stackCard: {
    position: "absolute",
    left: 0,
    right: 0,
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
    backgroundColor: colors.surface,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: HAIRLINE,
    borderRadius: 14,
    padding: 11,
  },
  stackCardBack: {
    top: 0,
    opacity: 0.4,
    transform: [{ scale: 0.9 }],
  },
  stackCardMid: {
    top: 15,
    opacity: 0.68,
    transform: [{ scale: 0.95 }],
  },
  stackCardFront: {
    top: 32,
    ...shadows.card,
  },
  thumb: {
    width: 92,
    height: 52,
    borderRadius: 8,
    backgroundColor: THUMB_FILL,
  },
  lines: {
    flex: 1,
    gap: 6,
    minWidth: 0,
  },
  line: {
    height: 7,
    borderRadius: 4,
    backgroundColor: LINE_FILL,
  },
  lineShort: {
    width: "58%",
  },
  glyphSlot: {
    width: 20,
    height: 20,
    alignItems: "center",
    justifyContent: "center",
  },
  tapRing: {
    position: "absolute",
    width: 52,
    height: 52,
    borderRadius: 26,
    borderWidth: 2,
    borderColor: colors.accent,
    backgroundColor: colors.accentSoft,
  },

  // Screen 4 share -------------------------------------------------------
  shareStack: {
    alignSelf: "stretch",
    height: 255,
  },
  sourceCard: {
    position: "absolute",
    left: 0,
    right: 158,
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
    backgroundColor: colors.surface,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: HAIRLINE,
    borderRadius: 14,
    padding: 9,
  },
  sourceBack: {
    top: 18,
    opacity: 0.42,
    transform: [{ scale: 0.9 }],
  },
  sourceMid: {
    top: 82,
    opacity: 0.68,
    transform: [{ scale: 0.95 }],
  },
  sourceFront: {
    top: 146,
    ...shadows.card,
  },
  shareTapRing: {
    left: 176,
    top: 141,
    width: 46,
    height: 46,
    borderRadius: 23,
  },
  arrow: {
    position: "absolute",
    left: 214,
    top: 96,
  },
  nativePhone: {
    position: "absolute",
    right: 0,
    top: 0,
    width: 118,
    height: 255,
    borderWidth: 2,
    borderColor: colors.ink,
    borderRadius: 16,
    overflow: "hidden",
    backgroundColor: colors.surface,
  },
  phoneBrand: {
    paddingHorizontal: 8,
    paddingTop: 7,
    paddingBottom: 2,
  },
  phoneBrandTop: {
    fontSize: 9.5,
    fontWeight: "800",
    color: colors.ink,
    lineHeight: 12,
  },
  phoneBrandSub: {
    fontSize: 9.5,
    fontWeight: "700",
    color: colors.muted,
    lineHeight: 12,
  },
  phoneRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 5,
    paddingHorizontal: 8,
    paddingVertical: 4,
  },
  phoneThumb: {
    width: 22,
    height: 14,
    borderRadius: 3,
    backgroundColor: THUMB_FILL,
  },
  phoneThumbNew: {
    backgroundColor: "#cfcec8",
  },
  phoneLine: {
    flex: 1,
    height: 4,
    borderRadius: 3,
    backgroundColor: LINE_FILL,
  },
  phoneLineNew: {
    backgroundColor: colors.accent,
  },
});
