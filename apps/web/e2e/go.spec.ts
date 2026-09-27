import { expect, test } from "@playwright/test";

const VIDEO_SITE = /^https:\/\/([a-z0-9-]+\.)*(youtube\.com|youtu\.be|tiktok\.com|instagram\.com)\//;

// The path a middle-click, "open in new tab" or a copied link takes. A plain
// click never loads /go (OutboundLink opens the video itself).
test("/go forwards a card's video link to the video", async ({ page }) => {
  // Stands in for the video site: the test is about where /go sends the browser.
  await page.route(VIDEO_SITE, (route) =>
    route.fulfill({ status: 200, contentType: "text/html", body: "video" }),
  );
  await page.goto("/badminton/forehand-smash");
  const href = await page.locator('a[href^="/go#"]').first().getAttribute("href");
  expect(href).toBeTruthy();
  await page.goto(href!);
  await page.waitForURL(VIDEO_SITE);
});

test("/go stops on a link it can't read", async ({ page }) => {
  await page.goto("/go#not-a-real-token");
  await expect(page.getByRole("heading", { name: "This link doesn't work" })).toBeVisible();
});
