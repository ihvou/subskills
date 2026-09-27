import type { CategorySummary, SkillResource, SkillSummary } from "./types";

export const badmintonCategory: CategorySummary = {
  id: "00000000-0000-4000-8000-000000000001",
  slug: "badminton",
  name: "Badminton",
  description:
    "A focused library of technique, movement, strategy, and equipment resources for badminton learners.",
};

export const padelCategory: CategorySummary = {
  id: "00000000-0000-4000-8000-000000000002",
  slug: "padel",
  name: "Padel",
  description:
    "Practical technique, movement, tactics, and equipment resources for improving padel players.",
};

export const gymMenCategory: CategorySummary = {
  id: "00000000-0000-4000-8000-000000000003",
  slug: "gym-men",
  name: "Gym (men)",
  description:
    "Strength, hypertrophy, mobility, and nutrition resources for men's gym training.",
};

export const gymWomenCategory: CategorySummary = {
  id: "00000000-0000-4000-8000-000000000004",
  slug: "gym-women",
  name: "Gym (women)",
  description:
    "Strength, hypertrophy, mobility, and confidence-building resources for women's gym training.",
};

export const surfingCategory: CategorySummary = {
  id: "00000000-0000-4000-8000-000000000005",
  slug: "surfing",
  name: "Surfing",
  description:
    "Technique, ocean reading, board handling, and progression resources for surfers.",
};

export const fallbackCategories = [
  badmintonCategory,
  padelCategory,
  gymMenCategory,
  gymWomenCategory,
  surfingCategory,
] satisfies CategorySummary[];

const badmintonSkillRows: Array<[string, string, string]> = [
  ["Forehand clear", "forehand-clear", "Send the shuttle deep from the rear court with a relaxed overhead action."],
  ["Backhand clear", "backhand-clear", "Recover from pressure with a compact backhand clear toward the rear court."],
  ["Forehand smash", "forehand-smash", "Generate steep power from rotation, timing, contact point, and follow-through."],
  ["Backhand smash", "backhand-smash", "Use a short backhand action to attack from awkward rear-court positions."],
  ["Drop shot", "drop-shot", "Disguise soft overhead shots that pull opponents into the front court."],
  ["Net shot", "net-shot", "Control tight spinning replies close to the tape."],
  ["Drive", "drive", "Play fast flat exchanges through the mid-court with compact preparation."],
  ["Lift", "lift", "Lift from the front court to reset rallies or move opponents backward."],
  ["Push", "push", "Push the shuttle into open mid-court spaces with quick racket preparation."],
  ["Serve (high)", "serve-high", "Use a high serve to start singles rallies with depth and height."],
  ["Serve (low)", "serve-low", "Keep low serves tight and legal for doubles and singles pressure."],
  ["Footwork (front court)", "footwork-front-court", "Move efficiently into lunges and recover from front-court shots."],
  ["Footwork (rear court)", "footwork-rear-court", "Reach rear-court corners with chasse, scissor, and recovery steps."],
  ["Footwork (split step)", "footwork-split-step", "Time the split step to react explosively to the opponent's hit."],
  ["Defense (block)", "defense-block", "Absorb smashes and guide controlled blocks into the front court."],
  ["Defense (lift)", "defense-lift", "Defend hard attacks by lifting high and deep under pressure."],
  ["Singles strategy", "singles-strategy", "Construct rallies with space, patience, tempo, and recovery position."],
  ["Doubles rotation", "doubles-rotation", "Coordinate attack, defense, and side-by-side rotations with a partner."],
  ["Grip technique", "grip-technique", "Switch between forehand, backhand, bevel, and panhandle grips cleanly."],
  ["Wrist rotation", "wrist-rotation", "Use forearm and wrist rotation for deception, speed, and control."],
  ["Stringing and tension", "stringing-and-tension", "Understand string choice and tension tradeoffs for feel, control, and power."],
];

const padelSkillRows: Array<[string, string, string]> = [
  ["Continental grip", "continental-grip", "Hold the racket for volleys, bandejas, viboras, and controlled defensive shots."],
  ["Forehand groundstroke", "forehand-groundstroke", "Build a compact forehand with clean contact, depth, and direction changes."],
  ["Backhand groundstroke", "backhand-groundstroke", "Develop a reliable backhand for low balls, blocks, and resets."],
  ["Volley technique", "volley-technique", "Control forehand and backhand volleys with short preparation and stable contact."],
  ["Bandeja", "bandeja", "Use the bandeja to keep net position and neutralize lobs without over-attacking."],
  ["Vibora", "vibora", "Add sidespin and pressure from overhead positions while keeping placement under control."],
  ["Smash and x3", "smash-x3", "Choose and execute attacking smashes, including kick-smash patterns that leave the court."],
  ["Glass defense", "glass-defense", "Read wall rebounds and defend after the ball hits the back or side glass."],
  ["Lob", "lob", "Use height, depth, and timing to recover court position or move opponents back."],
  ["Chiquita", "chiquita", "Play low, soft attacks at opponents' feet to transition toward the net."],
  ["Net positioning", "net-positioning", "Coordinate distance, angles, and partner spacing while attacking at the net."],
  ["Serve and first volley", "serve-first-volley", "Start points with a serve plan and move into a balanced first volley."],
];

const gymMenSkillRows: Array<[string, string, string]> = [
  ["Barbell squat", "barbell-squat", "Train squat depth, bracing, bar path, and progressive loading safely."],
  ["Bench press", "bench-press", "Build pressing strength with stable setup, touch point, and shoulder-friendly technique."],
  ["Deadlift", "deadlift", "Hinge and brace for strong pulls while managing grip, setup, and lockout mechanics."],
  ["Pull-up progression", "pull-up-progression", "Develop vertical pulling strength from assisted reps to loaded pull-ups."],
  ["Overhead press", "overhead-press", "Press overhead with stacked posture, bar path control, and scalable loading."],
  ["Hypertrophy programming", "hypertrophy-programming", "Plan sets, reps, volume, proximity to failure, and exercise selection for muscle gain."],
  ["Fat-loss nutrition", "fat-loss-nutrition", "Use calorie targets, protein, adherence, and training support for sustainable fat loss."],
  ["Mobility warm-up", "mobility-warm-up", "Prepare shoulders, hips, ankles, and spine for productive lifting sessions."],
  ["Core bracing", "core-bracing", "Coordinate breath, trunk tension, and rib position for compound lifts."],
  ["Shoulder health", "shoulder-health", "Manage pressing volume, scapular control, and rotator cuff accessory work."],
  ["Arm training", "arm-training", "Train biceps, triceps, and forearms with joint-friendly volume and progression."],
  ["Recovery habits", "recovery-habits", "Balance sleep, deloads, soreness, and training stress across a lifting block."],
];

const gymWomenSkillRows: Array<[string, string, string]> = [
  ["Glute bridge and hip thrust", "glute-bridge-hip-thrust", "Set up hip thrusts and bridges for glute stimulus without low-back overload."],
  ["Goblet squat", "goblet-squat", "Use goblet squats to learn depth, balance, and bracing before heavier loading."],
  ["Romanian deadlift", "romanian-deadlift", "Train the hip hinge with hamstring tension, neutral spine, and controlled tempo."],
  ["Dumbbell bench press", "dumbbell-bench-press", "Press with stable shoulders, range of motion, and balanced dumbbell control."],
  ["Lat pulldown", "lat-pulldown", "Build back strength with controlled shoulder position and clean pulling mechanics."],
  ["Lower-body hypertrophy", "lower-body-hypertrophy", "Program quads, glutes, and hamstrings with balanced volume and progression."],
  ["Upper-body hypertrophy", "upper-body-hypertrophy", "Train shoulders, back, chest, and arms with confidence and recovery in mind."],
  ["Pelvic floor aware lifting", "pelvic-floor-aware-lifting", "Coordinate breath, pressure, and load for lifters managing pelvic-floor symptoms."],
  ["Cycle-aware training", "cycle-aware-training", "Adjust training expectations and recovery around menstrual-cycle symptoms when helpful."],
  ["Gym confidence", "gym-confidence", "Navigate equipment, etiquette, and progression without feeling lost on the gym floor."],
  ["Nutrition for strength", "nutrition-for-strength", "Support performance with protein, energy availability, hydration, and consistent habits."],
  ["Mobility and stability", "mobility-stability", "Improve usable range, control, and joint stability for lifting sessions."],
];

const surfingSkillRows: Array<[string, string, string]> = [
  ["Paddling technique", "paddling-technique", "Paddle efficiently with body position, stroke mechanics, and breathing control."],
  ["Pop-up", "pop-up", "Move from prone to stance quickly with stable foot placement and low posture."],
  ["Wave selection", "wave-selection", "Read sets, peaks, shoulders, and wave quality before committing to a paddle."],
  ["Takeoff timing", "takeoff-timing", "Match paddle speed and timing to enter waves with control."],
  ["Bottom turn", "bottom-turn", "Set the rail and redirect speed from the lower third of the wave."],
  ["Cutback", "cutback", "Return to the power source with rail control, rotation, and rebound timing."],
  ["Duck dive", "duck-dive", "Get under breaking waves with board angle, body weight, and recovery timing."],
  ["Turtle roll", "turtle-roll", "Pass whitewater on longer boards with safe grip, rotation, and reset."],
  ["Surf stance", "surf-stance", "Build balance, compression, foot placement, and upper-body alignment on the board."],
  ["Lineup positioning", "lineup-positioning", "Choose takeoff spots while respecting priority, currents, and crowd flow."],
  ["Surf etiquette", "surf-etiquette", "Understand right of way, paddling lanes, communication, and safe decision-making."],
  ["Board choice", "board-choice", "Match volume, shape, fin setup, and length to waves and ability level."],
];

const fallbackLearningOrders: Record<string, string[]> = {
  badminton: [
    "grip-technique",
    "serve-low",
    "serve-high",
    "footwork-split-step",
    "footwork-front-court",
    "footwork-rear-court",
    "lift",
    "net-shot",
    "push",
    "drive",
    "forehand-clear",
    "drop-shot",
    "defense-block",
    "defense-lift",
    "forehand-smash",
    "wrist-rotation",
    "singles-strategy",
    "doubles-rotation",
    "backhand-clear",
    "backhand-smash",
    "stringing-and-tension",
  ],
  padel: [
    "continental-grip",
    "serve-first-volley",
    "forehand-groundstroke",
    "backhand-groundstroke",
    "lob",
    "glass-defense",
    "volley-technique",
    "net-positioning",
    "bandeja",
    "chiquita",
    "vibora",
    "smash-x3",
  ],
  "gym-men": [
    "mobility-warm-up",
    "core-bracing",
    "recovery-habits",
    "fat-loss-nutrition",
    "barbell-squat",
    "bench-press",
    "deadlift",
    "pull-up-progression",
    "overhead-press",
    "arm-training",
    "shoulder-health",
    "hypertrophy-programming",
  ],
  "gym-women": [
    "gym-confidence",
    "mobility-stability",
    "goblet-squat",
    "glute-bridge-hip-thrust",
    "dumbbell-bench-press",
    "lat-pulldown",
    "romanian-deadlift",
    "nutrition-for-strength",
    "lower-body-hypertrophy",
    "upper-body-hypertrophy",
    "pelvic-floor-aware-lifting",
    "cycle-aware-training",
  ],
  surfing: [
    "surf-etiquette",
    "board-choice",
    "surf-stance",
    "paddling-technique",
    "turtle-roll",
    "pop-up",
    "lineup-positioning",
    "wave-selection",
    "takeoff-timing",
    "duck-dive",
    "bottom-turn",
    "cutback",
  ],
};

function fallbackLearningPosition(categorySlug: string, skillSlug: string) {
  const order = fallbackLearningOrders[categorySlug] ?? [];
  const index = order.indexOf(skillSlug);
  if (index === -1) return { learning_order: null, subskill_difficulty: null };
  const denominator = Math.max(order.length - 1, 1);
  return {
    learning_order: index + 1,
    subskill_difficulty: Math.round((1 + (index * 4) / denominator) * 100) / 100,
  };
}

function makeSkills(
  category: CategorySummary,
  firstId: number,
  rows: Array<[string, string, string]>,
): SkillSummary[] {
  return rows.map(([name, slug, description], index) => ({
    id: `00000000-0000-4000-8000-${String(firstId + index).padStart(12, "0")}`,
    category_id: category.id,
    category_slug: category.slug,
    name,
    slug,
    description,
    resource_count: 0,
    ...fallbackLearningPosition(category.slug, slug),
  }));
}

export const badmintonSkills = makeSkills(badmintonCategory, 101, badmintonSkillRows);
export const padelSkills = makeSkills(padelCategory, 1001, padelSkillRows);
export const gymMenSkills = makeSkills(gymMenCategory, 2001, gymMenSkillRows);
export const gymWomenSkills = makeSkills(gymWomenCategory, 3001, gymWomenSkillRows);
export const surfingSkills = makeSkills(surfingCategory, 4001, surfingSkillRows);

export const fallbackSkills = [
  ...badmintonSkills,
  ...padelSkills,
  ...gymMenSkills,
  ...gymWomenSkills,
  ...surfingSkills,
] satisfies SkillSummary[];

export const fallbackResources: Record<string, SkillResource[]> = {
  "forehand-smash": [
    {
      id: "demo-relation-forehand-smash-1",
      public_note: "Clear demonstration of rotation, contact height, and recovery after the smash.",
      skill_level: "intermediate",
      upvote_count: 8,
      created_at: "2026-05-01T00:00:00.000Z",
      link: {
        id: "demo-link-forehand-smash-1",
        url: "https://www.youtube.com/results?search_query=badminton+forehand+smash+tutorial",
        canonical_url: "https://www.youtube.com/results?search_query=badminton+forehand+smash+tutorial",
        domain: "youtube.com",
        title: "Badminton forehand smash tutorials",
        description: "Search-backed demo placeholder until the ingestion pipeline is run.",
        thumbnail_url: null,
        content_type: "video",
      },
    },
  ],
  bandeja: [
    {
      id: "demo-relation-bandeja-1",
      public_note: "Good starting point for understanding how the bandeja protects net position.",
      skill_level: "beginner",
      upvote_count: 6,
      created_at: "2026-05-02T00:00:00.000Z",
      link: {
        id: "demo-link-bandeja-1",
        url: "https://www.youtube.com/results?search_query=padel+bandeja+tutorial",
        canonical_url: "https://www.youtube.com/results?search_query=padel+bandeja+tutorial",
        domain: "youtube.com",
        title: "Padel bandeja tutorials",
        description: "Search-backed demo placeholder until the ingestion pipeline is run.",
        thumbnail_url: null,
        content_type: "video",
      },
    },
  ],
  "bench-press": [
    {
      id: "demo-relation-bench-press-1",
      public_note: "Useful setup cues for shoulder position, leg drive, and repeatable bar path.",
      skill_level: "intermediate",
      upvote_count: 11,
      created_at: "2026-05-03T00:00:00.000Z",
      link: {
        id: "demo-link-bench-press-1",
        url: "https://www.youtube.com/results?search_query=bench+press+technique+science",
        canonical_url: "https://www.youtube.com/results?search_query=bench+press+technique+science",
        domain: "youtube.com",
        title: "Bench press technique tutorials",
        description: "Search-backed demo placeholder until the ingestion pipeline is run.",
        thumbnail_url: null,
        content_type: "video",
      },
    },
  ],
  "glute-bridge-hip-thrust": [
    {
      id: "demo-relation-hip-thrust-1",
      public_note: "Clear setup and range-of-motion cues for glute-focused hip thrusts.",
      skill_level: "beginner",
      upvote_count: 9,
      created_at: "2026-05-04T00:00:00.000Z",
      link: {
        id: "demo-link-hip-thrust-1",
        url: "https://www.youtube.com/results?search_query=hip+thrust+technique+women",
        canonical_url: "https://www.youtube.com/results?search_query=hip+thrust+technique+women",
        domain: "youtube.com",
        title: "Hip thrust setup tutorials",
        description: "Search-backed demo placeholder until the ingestion pipeline is run.",
        thumbnail_url: null,
        content_type: "video",
      },
    },
  ],
  "pop-up": [
    {
      id: "demo-relation-pop-up-1",
      public_note: "Simple dry-land cues for foot placement, compression, and faster takeoffs.",
      skill_level: "beginner",
      upvote_count: 7,
      created_at: "2026-05-05T00:00:00.000Z",
      link: {
        id: "demo-link-pop-up-1",
        url: "https://www.youtube.com/results?search_query=surfing+pop+up+tutorial",
        canonical_url: "https://www.youtube.com/results?search_query=surfing+pop+up+tutorial",
        domain: "youtube.com",
        title: "Surf pop-up tutorials",
        description: "Search-backed demo placeholder until the ingestion pipeline is run.",
        thumbnail_url: null,
        content_type: "video",
      },
    },
  ],
};
