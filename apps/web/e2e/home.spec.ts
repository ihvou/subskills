import { expect, test } from "@playwright/test";

test("home renders the multi-sport hero and category cards", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { name: /best free tutorials/i })).toBeVisible();
  await expect(page.getByRole("link", { name: /badminton/i }).first()).toBeVisible();
});
