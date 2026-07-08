import { expect, test } from "@playwright/test";
import { mockAuthenticated } from "./mocks";

test.beforeEach(async ({ page }) => {
  await mockAuthenticated(page);
});

test("renders balances, monthly summary, and recent transactions", async ({ page }) => {
  await page.goto("/dashboard");
  await expect(page.getByRole("heading", { name: "Dashboard" })).toBeVisible();
  await expect(page.getByText("Kas Kecil")).toBeVisible();
  await expect(page.getByText("Rp 150.000")).toBeVisible();
  await expect(page.getByText("Rp 5.000.000")).toBeVisible(); // Pemasukan
  await expect(page.getByText("KK-0001")).toBeVisible();
  await expect(page.getByText("Makan siang")).toBeVisible();
});

test("month navigation buttons are reachable by their accessible name", async ({ page }) => {
  await page.goto("/dashboard");
  await expect(page.getByRole("button", { name: "Bulan sebelumnya" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Bulan berikutnya" })).toBeVisible();
});
