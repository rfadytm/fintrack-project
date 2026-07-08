import { expect, test } from "@playwright/test";
import { mockAuthenticated } from "./mocks";

test("renders active recurring transactions", async ({ page }) => {
  await mockAuthenticated(page);
  await page.goto("/recurring");
  await expect(page.getByRole("heading", { name: "Transaksi Berulang" })).toBeVisible();
  await expect(page.getByText("Langganan Netflix")).toBeVisible();
  await expect(page.getByText("Rp 54.000")).toBeVisible();
  await expect(page.getByRole("cell", { name: "Bulanan" })).toBeVisible();
});
