import { expect, test } from "@playwright/test";
import { mockAuthenticated } from "./mocks";

test("export button is disabled with no ledger lines and enabled once lines load", async ({ page }) => {
  await mockAuthenticated(page); // default ledger mock returns { lines: [] }
  await page.goto("/ledger");
  await expect(page.getByRole("heading", { name: "Buku Besar" })).toBeVisible();
  await expect(page.getByRole("button", { name: "⬇️ Export .xlsx" })).toBeDisabled();

  await page.route("**/api/reports/ledger**", async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        lines: [
          {
            id: 1,
            account_code: "1120",
            debit_amount: 50000,
            credit_amount: null,
            running_balance: 150000,
            transactions: { transaction_date: "2026-07-01", doc_number: "OB-0001", description: "Saldo awal" },
          },
        ],
      }),
    });
  });
  // Switch to a different account (fresh query key, not served from the earlier empty-lines cache).
  await page.getByLabel("Aset").selectOption("1130");

  await expect(page.getByRole("button", { name: "⬇️ Export .xlsx" })).toBeEnabled();
});
