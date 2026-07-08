import { expect, test } from "@playwright/test";
import { mockAuthenticated } from "./mocks";

const PAGES: [string, string][] = [
  ["Jurnal", "Jurnal"],
  ["Buku Besar", "Buku Besar"],
  ["Laporan", "Laporan Keuangan"],
  ["COA", "Chart of Accounts"],
  ["Budget", "Budget"],
  ["Goals", "Goals"],
  ["Berulang", "Transaksi Berulang"],
  ["Tagihan", "Tagihan"],
  ["Pengaturan", "Pengaturan"],
  ["Dashboard", "Dashboard"],
];

test("navigates across every page via the navbar", async ({ page }) => {
  await mockAuthenticated(page);
  await page.goto("/dashboard");
  for (const [link, heading] of PAGES) {
    await page.getByRole("link", { name: link, exact: true }).click();
    await expect(page.getByRole("heading", { name: heading, exact: true })).toBeVisible();
  }
});
