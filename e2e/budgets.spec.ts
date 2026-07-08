import { expect, test } from "@playwright/test";
import { mockAuthenticated } from "./mocks";

test("renders existing budgets with progress and blocks save with no category picked", async ({ page }) => {
  await mockAuthenticated(page);
  await page.goto("/budgets");
  await expect(page.getByRole("heading", { name: "Budget", exact: true })).toBeVisible();
  await expect(page.getByText("Beban Makan")).toBeVisible();
  await expect(page.getByText("Rp 300.000")).toBeVisible();

  await page.getByRole("button", { name: "Simpan" }).click();
  await expect(page.getByText("Wajib dipilih")).toBeVisible();
});
