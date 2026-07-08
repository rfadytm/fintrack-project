import { expect, test } from "@playwright/test";
import { mockAuthenticated } from "./mocks";

test("pager disables Prev on the first page and enables Next when more pages exist", async ({ page }) => {
  await mockAuthenticated(page);
  // Override with enough rows to produce a second page (limit=25).
  await page.route("**/api/transactions**", async (route) => {
    const total = 40;
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        transactions: Array.from({ length: 25 }, (_, i) => ({
          doc_number: `KK-${String(i).padStart(4, "0")}`,
          transaction_date: "2026-07-01",
          doc_type: "KK",
          description: "Item " + i,
          status: "POSTED",
          journal_lines: [],
        })),
        total,
      }),
    });
  });

  await page.goto("/journal");
  await expect(page.getByRole("heading", { name: "Jurnal" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Halaman sebelumnya" })).toBeDisabled();
  await expect(page.getByRole("button", { name: "Halaman berikutnya" })).toBeEnabled();
  await expect(page.getByText("1 / 2")).toBeVisible();

  await page.getByRole("button", { name: "Halaman berikutnya" }).click();
  await expect(page.getByText("2 / 2")).toBeVisible();
  await expect(page.getByRole("button", { name: "Halaman berikutnya" })).toBeDisabled();
});
