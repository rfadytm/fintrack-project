import { expect, test } from "@playwright/test";
import { mockAuthenticated } from "./mocks";

test("renders bills and validates the add form", async ({ page }) => {
  await mockAuthenticated(page);
  await page.goto("/bills");
  await expect(page.getByRole("heading", { name: "Tagihan", exact: true })).toBeVisible();
  await expect(page.getByText("Listrik PLN")).toBeVisible();
  await expect(page.getByText("Tgl 20")).toBeVisible();

  await page.getByRole("button", { name: "Simpan" }).click();
  await expect(page.getByText("Wajib diisi")).toBeVisible();
});
