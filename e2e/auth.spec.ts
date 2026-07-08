import { expect, test } from "@playwright/test";
import { mockAuthenticated, mockUnauthenticated } from "./mocks";

test("redirects to /login when not authenticated", async ({ page }) => {
  await mockUnauthenticated(page);
  await page.goto("/dashboard");
  await expect(page).toHaveURL(/\/login$/);
  await expect(page.getByText("Login lewat Telegram untuk keamanan.")).toBeVisible();
});

test("unmatched routes fall back to the dashboard once authenticated", async ({ page }) => {
  await mockAuthenticated(page);
  await page.goto("/some/unknown/path");
  await expect(page).toHaveURL(/\/dashboard$/);
});
