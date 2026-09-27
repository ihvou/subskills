import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  webServer: {
    command: "npm run dev",
    url: "http://127.0.0.1:3000",
    reuseExistingServer: true,
    timeout: 120000,
    // With no Supabase env (CI), the site serves the offline demo catalog, which
    // carries one resource per sub-skill — below the production publish threshold
    // of 3. At that threshold every demo sub-skill is unpublished: noindex, and
    // absent from the sitemap, so sitemap.spec.ts has had nothing to find since
    // the threshold landed. Publishing at 1 lets the tests see the real page shape.
    env: { PUBLISH_MIN_RESOURCES: "1" },
  },
  use: {
    baseURL: "http://127.0.0.1:3000",
    trace: "on-first-retry",
  },
  projects: [
    { name: "chromium", use: { ...devices["Desktop Chrome"] } },
  ],
});
