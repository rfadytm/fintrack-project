import { expect, test } from "@playwright/test";
import { mockAuthenticated } from "./mocks";

test("renders goal progress and validates the add form", async ({ page }) => {
  await mockAuthenticated(page);
  await page.goto("/goals");
  await expect(page.getByRole("heading", { name: "Goals" })).toBeVisible();
  await expect(page.getByText("Laptop baru")).toBeVisible();
  await expect(page.getByText("Rp 2.000.000 / Rp 10.000.000")).toBeVisible();

  await page.getByRole("button", { name: "Simpan" }).click();
  await expect(page.getByText("Wajib diisi")).toBeVisible();
});
