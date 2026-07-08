import type { Page, Route } from "@playwright/test";

// Real login goes through a Telegram-bot magic link, which can't be driven
// headlessly here — every e2e spec instead mocks the backend at the network
// boundary (`page.route`) and drives the already-authenticated dashboard/pages.
// This exercises real rendering in a real browser; it does not exercise the
// actual Telegram OTP exchange (see e2e/README.md).

const ACCOUNTS = {
  accounts: [
    { code: "1110", account_name: "Bank BCA", account_type: "aset", normal_balance: "debit", level: 2, is_header: false },
    { code: "1120", account_name: "Kas Kecil", account_type: "aset", normal_balance: "debit", level: 2, is_header: false },
    { code: "1130", account_name: "OVO", account_type: "aset", normal_balance: "debit", level: 2, is_header: false },
    { code: "5130", account_name: "Beban Makan", account_type: "beban", normal_balance: "debit", level: 2, is_header: false },
  ],
};

const BALANCE = {
  balances: [
    { code: "1110", account_name: "Bank BCA", balance: 2_500_000 },
    { code: "1120", account_name: "Kas Kecil", balance: 150_000 },
  ],
};

const MONTHLY = { income: 5_000_000, expense: 3_200_000, net: 1_800_000 };

const TRANSACTIONS = {
  transactions: [
    {
      doc_number: "KK-0001",
      transaction_date: "2026-07-01",
      doc_type: "KK",
      description: "Makan siang",
      status: "POSTED",
      journal_lines: [
        { account_code: "5130", debit_amount: 30000, credit_amount: null, line_order: 1 },
        { account_code: "1120", debit_amount: null, credit_amount: 30000, line_order: 2 },
      ],
    },
  ],
  total: 1,
};

const INCOME_STATEMENT = {
  revenue: [{ code: "4110", account_name: "Gaji", amount: 5_000_000 }],
  expense: [{ code: "5130", account_name: "Beban Makan", amount: 3_200_000 }],
  total_revenue: 5_000_000,
  total_expense: 3_200_000,
  net_income: 1_800_000,
};

const TRIAL_BALANCE = {
  accounts: [{ code: "1110", account_name: "Bank BCA", total_debit: 2_500_000, total_credit: 0 }],
  total_debit: 2_500_000,
  total_credit: 2_500_000,
  balanced: true,
};

const SETTINGS = {
  settings: [
    { key: "default_expense_source", value: "1120" },
    { key: "default_income_dest", value: "1110" },
    { key: "kas_kecil_source", value: "1120" },
    { key: "savings_account", value: "1130" },
    { key: "kas_kecil_target", value: "500000" },
    { key: "bi_fast_fee", value: "2500" },
  ],
};

async function json(route: Route, body: unknown, status = 200) {
  await route.fulfill({ status, contentType: "application/json", body: JSON.stringify(body) });
}

export async function mockAuthenticated(page: Page) {
  await page.route("**/api/auth/me", async (route) => {
    if (route.request().method() === "POST") return json(route, { ok: true });
    await json(route, { logged_in: true });
  });
  await page.route("**/api/accounts**", (route) => json(route, ACCOUNTS));
  await page.route("**/api/reports/balance**", (route) => json(route, BALANCE));
  await page.route("**/api/reports/monthly**", (route) => json(route, MONTHLY));
  await page.route("**/api/reports/income-statement**", (route) => json(route, INCOME_STATEMENT));
  await page.route("**/api/reports/trial-balance**", (route) => json(route, TRIAL_BALANCE));
  await page.route("**/api/reports/ledger**", (route) => json(route, { lines: [] }));
  await page.route("**/api/transactions**", (route) => json(route, TRANSACTIONS));
  await page.route("**/api/settings", async (route) => {
    if (route.request().method() === "POST") return json(route, { ok: true });
    await json(route, SETTINGS);
  });
}

export async function mockUnauthenticated(page: Page) {
  await page.route("**/api/auth/me", (route) => json(route, { logged_in: false }));
}
