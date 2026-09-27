import type { Config } from "tailwindcss";

/**
 * Same DNA as the mobile theme — Apple-Podcasts-inspired neutral palette
 * with a single purple accent. Legacy tokens (court / shuttle / amberline /
 * graphite) are kept aliased so existing admin code still compiles.
 */
const config: Config = {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}", "./lib/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        // New neutral palette
        bg: "#ffffff",
        bgGroup: "#f2f1ec",
        surface: "#ffffff",
        ink: "#000000",
        text: "#1c1c1e",
        muted: "#8a898e",
        faint: "#b7b6bb",
        accent: "#a855f7",
        accentSoft: "rgba(168, 85, 247, 0.10)",
        divider: "rgba(0, 0, 0, 0.14)",

        // Legacy aliases (used by admin pages) — map to the new palette
        court: "#000000",
        courtDark: "#000000",
        shuttle: "#f2f1ec",
        amberline: "#a855f7",
        graphite: "#8a898e",
      },
      boxShadow: {
        thumb: "0 1px 4px rgba(0, 0, 0, 0.08)",
        card: "0 2px 8px rgba(0, 0, 0, 0.06)",
        pill: "0 2px 6px rgba(0, 0, 0, 0.08)",
        panel: "0 18px 60px rgba(0, 0, 0, 0.08)",
      },
      borderRadius: {
        pill: "999px",
      },
      fontFamily: {
        sans: [
          "-apple-system",
          "BlinkMacSystemFont",
          "ui-sans-serif",
          "system-ui",
          "Segoe UI",
          "Roboto",
          "Helvetica Neue",
          "Arial",
          "sans-serif",
        ],
      },
    },
  },
  plugins: [],
};

export default config;
