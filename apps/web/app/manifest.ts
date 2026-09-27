import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Subskills",
    short_name: "Subskills",
    description: "Free sport and training tutorials organized by sub-skill, level, and source.",
    start_url: "/",
    display: "standalone",
    background_color: "#f7f6ef",
    theme_color: "#171717",
    icons: [
      {
        src: "/icon-v2.svg",
        sizes: "any",
        type: "image/svg+xml",
      },
      {
        src: "/apple-icon-v2.png",
        sizes: "180x180",
        type: "image/png",
      },
    ],
  };
}
