// Apple Podcasts-inspired neutral palette. Restraint over brand color.
export const colors = {
  // Backgrounds
  bg: "#ffffff",
  bgGroup: "#f2f1ec",   // slight cream behind cards
  surface: "#ffffff",   // card surface
  divider: "rgba(0, 0, 0, 0.14)",

  // Text
  ink: "#000000",       // primary
  text: "#1c1c1e",      // primary body text (near-black)
  muted: "#8a898e",     // secondary
  faint: "#b7b6bb",     // tertiary / disabled

  // Accents
  accent: "#a855f7",    // purple (saved/play state)
  accentSoft: "rgba(168, 85, 247, 0.10)",

  // Legacy aliases kept so existing references compile during the redesign
  court: "#000000",
  courtDark: "#000000",
  shuttle: "#f2f1ec",
  amber: "#a855f7",
  graphite: "#8a898e",
  line: "rgba(0, 0, 0, 0.14)",
  lineSoft: "rgba(0, 0, 0, 0.08)",
  tint: "rgba(168, 85, 247, 0.10)",
  tintStrong: "rgba(168, 85, 247, 0.18)",
  white: "#ffffff",
};

// Spacing on a 4pt grid
export const spacing = {
  xxs: 4,
  xs: 8,
  sm: 12,
  md: 16,
  lg: 20,
  xl: 24,
  xxl: 32,
  page: 20,            // standard horizontal page padding
};

// Card / thumbnail shape
export const radius = {
  sm: 6,
  md: 10,
  lg: 14,
  xl: 20,
  pill: 999,
};

export const shadows = {
  card: {
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.06,
    shadowRadius: 8,
    elevation: 2,
  },
  thumbnail: {
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.08,
    shadowRadius: 4,
    elevation: 1,
  },
  pill: {
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 6,
    elevation: 2,
  },
};

export const typography = {
  pageTitle: {
    fontSize: 34,
    fontWeight: "800" as const,
    color: colors.ink,
    letterSpacing: -0.5,
  },
  sectionTitle: {
    fontSize: 22,
    fontWeight: "800" as const,
    color: colors.ink,
    letterSpacing: -0.3,
  },
  rowTitle: {
    fontSize: 16,
    fontWeight: "700" as const,
    color: colors.text,
    lineHeight: 21,
    letterSpacing: -0.2,
  },
  date: {
    fontSize: 13,
    fontWeight: "400" as const,
    color: colors.muted,
  },
  meta: {
    fontSize: 13,
    fontWeight: "500" as const,
    color: colors.muted,
  },
  body: {
    fontSize: 15,
    fontWeight: "400" as const,
    color: colors.muted,
    lineHeight: 21,
  },
};
