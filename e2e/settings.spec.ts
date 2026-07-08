import { expect, test } from "@playwright/test";
import { mockAuthenticated } from "./mocks";

test.beforeEach(async ({ page }) => {
  await mockAuthenticated(page);
  await page.goto("/settings");
  await expect(page.getByRole("heading", { name: "Pengaturan" })).toBeVisible();
});

test("blocks save and shows an inline error when a required select is cleared", async ({ page }) => {
  let saveCalls = 0;
  await page.route("**/api/settings", async (route, request) => {
    if (request.method() === "POST") {
      saveCalls++;
      return route.fulfill({ status: 200, contentType: "application/json", body: "{}" });
    }
    await route.continue();
  });

  await page.getByLabel("Sumber default pengeluaran").selectOption("");
  await page.getByRole("button", { name: "Simpan" }).click();

  await expect(page.getByText("Wajib dipilih")).toBeVisible();
  expect(saveCalls).toBe(0);
});

test("accepts a valid form and shows the saved confirmation", async ({ page }) => {
  await page.getByRole("button", { name: "Simpan" }).click();
  await expect(page.getByText("Tersimpan ✓")).toBeVisible();
});

test("logout requires confirmation in a dialog before navigating to /login", async ({ page }) => {
  await page.getByRole("button", { name: "Logout" }).click();
  await expect(page.getByRole("dialog")).toBeVisible();

  await page.getByRole("button", { name: "Batal" }).click();
  await expect(page.getByRole("dialog")).not.toBeVisible();
  await expect(page).toHaveURL(/\/settings$/);

  await page.getByRole("button", { name: "Logout" }).click();
  await page.getByRole("button", { name: "Ya, logout" }).click();
  await expect(page).toHaveURL(/\/login$/);
});
