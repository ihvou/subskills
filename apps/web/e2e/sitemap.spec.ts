import { expect, test } from "@playwright/test";

test("sitemap lists skill pages", async ({ page }) => {
  const response = await page.goto("/sitemap.xml");
  expect(response?.ok()).toBeTruthy();
  await expect(page.locator("body")).toContainText("/badminton/forehand-smash");
});
