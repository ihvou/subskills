import { expect, test } from "@playwright/test";

test("skill page renders its breadcrumbs json-ld and the resources area", async ({ page }) => {
  await page.goto("/badminton/forehand-smash");
  await expect(page.getByRole("heading", { level: 1, name: "Forehand smash" })).toBeVisible();
  // Breadcrumbs only: the ItemList of videos went with the raw video URLs.
  await expect(page.locator('script[type="application/ld+json"]')).toHaveCount(1);
});

// The previous/next links can't be checked here: the demo catalog publishes one
// sub-skill per category, so no page has a neighbour. adjacentSkillsInLearningPath
// is unit-tested in packages/shared instead.
test("skill page puts a short description on the category line", async ({ page }) => {
  await page.goto("/badminton/forehand-smash");
  await expect(page.locator("main header p").first()).toHaveText(/^Badminton · Generate steep power/);
});

test("skill page never prints a video's address and links videos through /go", async ({ page }) => {
  const response = await page.goto("/badminton/forehand-smash");
  // The HTML as sent, including the data React ships with it, not the live DOM.
  const html = (await response?.text()) ?? "";
  expect(html).not.toMatch(/youtube\.com\/(watch|results|shorts)|youtu\.be\/|tiktok\.com\/@|instagram\.com\/(reel|p)\//);
  const videoLinks = page.locator('a[href^="/go#"]');
  expect(await videoLinks.count()).toBeGreaterThan(0);
  await expect(videoLinks.first()).toHaveAttribute("rel", /nofollow/);
  // Video titles are link text, not headings: the page's headings are its own
  // (the name, and the summary's sections when a page has one).
  await expect(page.locator("section[data-nosnippet]").locator("h1, h2, h3, h4, h5, h6")).toHaveCount(0);
});
