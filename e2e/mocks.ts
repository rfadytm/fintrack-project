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

const BUDGETS = {
  budgets: [{ account_code: "5130", account_name: "Beban Makan", monthly_limit: 1_000_000, spent: 300_000, last_alert_at: null }],
};
const GOALS = {
  goals: [{ id: 1, name: "Laptop baru", target_amount: 10_000_000, account_code: "1130", target_date: null, is_active: true, current_amount: 2_000_000 }],
};
const RECURRING = {
  recurring: [
    {
      id: 1,
      doc_type: "KK",
      description: "Langganan Netflix",
      lines: [
        { account_code: "5130", debit: 54000, credit: 0 },
        { account_code: "1130", debit: 0, credit: 54000 },
      ],
      frequency: "monthly",
      next_run: "2026-08-01",
      is_active: true,
    },
  ],
};
const BILLS = {
  bills: [{ id: 1, name: "Listrik PLN", amount: 250000, due_day: 20, due_date: null, is_recurring: true, is_active: true, last_reminded_period: null }],
};
const TAGS = { tags: [{ id: 1, name: "kerja", emoji: "💼" }] };
const RANGE_REPORT = {
  date_from: "2026-07-01",
  date_to: "2026-07-08",
  revenue: [],
  expense: [{ code: "5130", account_name: "Beban Makan", amount: 30000 }],
  total_revenue: 0,
  total_expense: 30000,
  net_income: -30000,
};
const FORECAST = {
  months: 6,
  income_history: [4000000, 4200000, 4100000, 4300000, 4500000, 5000000],
  expense_history: [3000000, 3100000, 2900000, 3200000, 3100000, 3200000],
  income_forecast: 5100000,
  expense_forecast: 3250000,
  top_categories: [{ code: "5130", account_name: "Beban Makan", history: [300000, 310000, 290000, 320000, 310000, 300000], forecast: 305000 }],
};

async function json(route: Route, body: unknown, status = 200) {
  await route.fulfill({ status, contentType: "application/json", body: JSON.stringify(body) });
}

function queryOf(route: Route): URLSearchParams {
  return new URL(route.request().url()).searchParams;
}

export async function mockAuthenticated(page: Page) {
  await page.route("**/api/auth/me", async (route) => {
    if (route.request().method() === "POST") return json(route, { ok: true });
    await json(route, { logged_in: true });
  });
  await page.route("**/api/accounts**", async (route) => {
    if (route.request().method() === "POST") return json(route, { code: "5940" }, 201);
    await json(route, ACCOUNTS);
  });
  // /reports is ONE consolidated function (see api/reports/index.py) — dispatch by ?report=.
  await page.route("**/api/reports**", async (route) => {
    const report = queryOf(route).get("report");
    const byReport: Record<string, unknown> = {
      balance: BALANCE,
      monthly: MONTHLY,
      "income-statement": INCOME_STATEMENT,
      "trial-balance": TRIAL_BALANCE,
      range: RANGE_REPORT,
      forecast: FORECAST,
      ledger: { lines: [] },
    };
    await json(route, byReport[report ?? ""] ?? { error: `unmocked report: ${report}` });
  });
  await page.route("**/api/transactions**", (route) => json(route, TRANSACTIONS));
  await page.route("**/api/settings", async (route) => {
    if (route.request().method() === "POST") return json(route, { ok: true });
    await json(route, SETTINGS);
  });
  // /budgets is ONE consolidated function (see api/budgets/index.py) — dispatch by ?resource=.
  await page.route("**/api/budgets**", async (route) => {
    const method = route.request().method();
    if (method === "POST" || method === "DELETE") return json(route, { ok: true });
    const isGoal = queryOf(route).get("resource") === "goal";
    await json(route, isGoal ? GOALS : BUDGETS);
  });
  // /recurring is ONE consolidated function (see api/recurring/index.py) — dispatch by ?resource=.
  await page.route("**/api/recurring**", async (route) => {
    const method = route.request().method();
    if (method === "POST" || method === "DELETE") return json(route, { ok: true });
    const isBill = queryOf(route).get("resource") === "bill";
    await json(route, isBill ? BILLS : RECURRING);
  });
  // /tags is ONE consolidated function (see api/tags/index.py) — assign uses ?action=assign.
  await page.route("**/api/tags**", async (route) => {
    const method = route.request().method();
    if (method === "POST" || method === "DELETE") return json(route, { ok: true });
    await json(route, TAGS);
  });
}

// Public-demo fixtures: same shape as the authenticated ones, but sensitive
// numeric fields replaced with null — mirroring shared/masking.py's real
// server-side behavior for unauthenticated viewers (see App.tsx's comment on
// the public-demo routes: /dashboard, /journal, /ledger, /reports stay
// reachable without a session, masked at the API layer, not route-blocked).
const MASKED_BALANCE = { balances: BALANCE.balances.map((b) => ({ ...b, balance: null })) };
const MASKED_MONTHLY = { income: null, expense: null, net: null, savings_rate: null };
const MASKED_INCOME_STATEMENT = {
  revenue: INCOME_STATEMENT.revenue.map((r) => ({ ...r, amount: null })),
  expense: INCOME_STATEMENT.expense.map((r) => ({ ...r, amount: null })),
  total_revenue: null,
  total_expense: null,
  net_income: null,
};
const MASKED_TRANSACTIONS = {
  transactions: TRANSACTIONS.transactions.map((t) => ({
    ...t,
    journal_lines: (t.journal_lines || []).map((l) => ({ ...l, debit_amount: null, credit_amount: null })),
  })),
  total: TRANSACTIONS.total,
};

export async function mockUnauthenticated(page: Page) {
  await page.route("**/api/auth/me", (route) => json(route, { logged_in: false }));
  await page.route("**/api/accounts**", (route) => json(route, ACCOUNTS));
  await page.route("**/api/reports**", async (route) => {
    const report = queryOf(route).get("report");
    const byReport: Record<string, unknown> = {
      balance: MASKED_BALANCE,
      monthly: MASKED_MONTHLY,
      "income-statement": MASKED_INCOME_STATEMENT,
    };
    await json(route, byReport[report ?? ""] ?? { error: `unmocked report: ${report}` });
  });
  await page.route("**/api/transactions**", (route) => json(route, MASKED_TRANSACTIONS));
}
