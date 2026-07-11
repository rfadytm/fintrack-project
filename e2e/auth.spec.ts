import { expect, test } from "@playwright/test";
import { mockAuthenticated, mockUnauthenticated } from "./mocks";

// Blindspot fix: this used to assert /dashboard redirects to /login when
// unauthenticated — that was true before the public-demo masking feature
// (App.tsx), which deliberately keeps /dashboard, /journal, /ledger, /reports
// reachable WITHOUT a session (data safety comes from server-side masking on
// those API responses, not from blocking the route). The old assertion was
// stale and failing against the app's actual, intended behavior.
test("public-demo dashboard stays reachable (masked) when not authenticated", async ({ page }) => {
  await mockUnauthenticated(page);
  await page.goto("/dashboard");
  await expect(page).toHaveURL(/\/dashboard$/);
  await expect(page.getByRole("heading", { name: "Dashboard" })).toBeVisible();
  // Masked (server returns null for sensitive amounts) — the real balance
  // from the authenticated fixtures must never leak through.
  await expect(page.getByText("Rp 2.500.000")).not.toBeVisible();
  // Public viewers see a blurred placeholder instead of the real number (or
  // a misleading "Rp 0") — verifies the auto-forced blur, not just absence
  // of the real figure. Two cash accounts are masked, so both cards render
  // the same placeholder text — take the first and check its wrapping div
  // (the text itself lives in AnimatedNumber's inner span; blur-md is on
  // the parent, same layout as BalanceCard.test.tsx).
  const balancePlaceholder = page.getByText("Rp 1.000.000").first();
  await expect(balancePlaceholder).toBeVisible();
  await expect(balancePlaceholder.locator("xpath=..")).toHaveClass(/blur-md/);
  // The manual privacy toggle only makes sense for a logged-in owner — a
  // public viewer's data is already masked server-side, so there is nothing
  // for the toggle to reveal.
  await expect(page.getByRole("button", { name: /nominal/ })).not.toBeVisible();
});

test("still-gated pages redirect to /login when not authenticated", async ({ page }) => {
  await mockUnauthenticated(page);
  await page.goto("/settings");
  await expect(page).toHaveURL(/\/login$/);
  await expect(page.getByText("Login lewat Telegram untuk keamanan.")).toBeVisible();
});

test("unmatched routes fall back to the dashboard once authenticated", async ({ page }) => {
  await mockAuthenticated(page);
  await page.goto("/some/unknown/path");
  await expect(page).toHaveURL(/\/dashboard$/);
});
