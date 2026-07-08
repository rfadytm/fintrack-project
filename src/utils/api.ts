import { z } from "zod";
import {
  AccountsResponseSchema,
  TransactionsResponseSchema,
  BalanceResponseSchema,
  LedgerResponseSchema,
  MonthlyReportSchema,
  IncomeStatementSchema,
  TrialBalanceSchema,
  AuthMeSchema,
  SettingsResponseSchema,
  BudgetsResponseSchema,
  GoalsResponseSchema,
  RecurringResponseSchema,
  BillsResponseSchema,
  TagsResponseSchema,
  RangeReportSchema,
  ForecastSchema,
} from "../types/api";

// Base URL: kosong = same-origin (produksi Vercel). Dev pakai proxy Vite.
const BASE = import.meta.env.VITE_API_URL || "";

export class ApiError extends Error {}
export class UnauthorizedError extends ApiError {
  constructor() {
    super("unauthorized");
    this.name = "UnauthorizedError";
  }
}

async function request<T>(
  path: string,
  schema: z.ZodType<T>,
  options: RequestInit = {}
): Promise<T> {
  const res = await fetch(`${BASE}/api${path}`, {
    credentials: "include",
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  if (res.status === 401) {
    throw new UnauthorizedError();
  }
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new ApiError(body.error || `HTTP ${res.status}`);
  }
  const json = await res.json();
  const parsed = schema.safeParse(json);
  if (!parsed.success) {
    // Blindspot fix: don't let a backend shape change crash the UI deep inside
    // a .map() — fail loudly and early, with the mismatch logged for debugging.
    console.error(`API shape mismatch on ${path}:`, parsed.error.issues);
    throw new ApiError(`Data dari server tidak sesuai format yang diharapkan (${path}).`);
  }
  return parsed.data;
}

const unknownSchema = z.unknown();

export const api = {
  // Auth
  me: () => request("/auth/me", AuthMeSchema),
  verify: (token: string) =>
    request("/auth/verify", unknownSchema, {
      method: "POST",
      body: JSON.stringify({ token }),
    }),
  logout: () => request("/auth/me", unknownSchema, { method: "POST" }),

  // Settings (bot_settings)
  settings: () => request("/settings", SettingsResponseSchema),
  updateSettings: (settings: Record<string, unknown>) =>
    request("/settings", unknownSchema, {
      method: "POST",
      body: JSON.stringify({ settings }),
    }),

  // Data
  accounts: (params = "") => request(`/accounts${params}`, AccountsResponseSchema),
  transactions: (qs = "") => request(`/transactions${qs}`, TransactionsResponseSchema),
  balance: (params = "") => request(`/reports/balance${params}`, BalanceResponseSchema),
  monthly: (year: number, month: number) =>
    request(`/reports/monthly?year=${year}&month=${month}`, MonthlyReportSchema),
  ledger: (account: string, year: number, month: number) =>
    request(`/reports/ledger?account=${account}&year=${year}&month=${month}`, LedgerResponseSchema),
  trialBalance: (year: number, month: number) =>
    request(`/reports/trial-balance?year=${year}&month=${month}`, TrialBalanceSchema),
  incomeStatement: (year: number, month: number) =>
    request(`/reports/income-statement?year=${year}&month=${month}`, IncomeStatementSchema),
  reportRange: (dateFrom: string, dateTo: string) =>
    request(`/reports/range?date_from=${dateFrom}&date_to=${dateTo}`, RangeReportSchema),
  forecast: (months = 6) => request(`/reports/forecast?months=${months}`, ForecastSchema),

  // v3: Budgets
  budgets: () => request("/budgets", BudgetsResponseSchema),
  saveBudget: (account_code: string, monthly_limit: number) =>
    request("/budgets", unknownSchema, {
      method: "POST",
      body: JSON.stringify({ account_code, monthly_limit }),
    }),
  deleteBudget: (account_code: string) =>
    request(`/budgets?account_code=${encodeURIComponent(account_code)}`, unknownSchema, {
      method: "DELETE",
    }),

  // v3: Goals
  goals: () => request("/goals", GoalsResponseSchema),
  saveGoal: (goal: { id?: number; name: string; target_amount: number; account_code: string; target_date?: string }) =>
    request("/goals", unknownSchema, { method: "POST", body: JSON.stringify(goal) }),
  deleteGoal: (id: number) => request(`/goals?id=${id}`, unknownSchema, { method: "DELETE" }),

  // v3: Recurring transactions
  recurring: () => request("/recurring", RecurringResponseSchema),
  saveRecurring: (row: {
    id?: number;
    doc_type: string;
    description?: string;
    lines: { account_code: string; debit?: number; credit?: number }[];
    frequency: string;
    next_run?: string;
  }) => request("/recurring", unknownSchema, { method: "POST", body: JSON.stringify(row) }),
  deleteRecurring: (id: number) => request(`/recurring?id=${id}`, unknownSchema, { method: "DELETE" }),

  // v3: Bills
  bills: () => request("/bills", BillsResponseSchema),
  saveBill: (bill: { id?: number; name: string; amount: number; due_day?: number; due_date?: string }) =>
    request("/bills", unknownSchema, { method: "POST", body: JSON.stringify(bill) }),
  deleteBill: (id: number) => request(`/bills?id=${id}`, unknownSchema, { method: "DELETE" }),

  // v3: Tags
  tags: () => request("/tags", TagsResponseSchema),
  createTag: (name: string, emoji?: string) =>
    request("/tags", unknownSchema, { method: "POST", body: JSON.stringify({ name, emoji }) }),
  deleteTag: (id: number) => request(`/tags?id=${id}`, unknownSchema, { method: "DELETE" }),
  assignTags: (doc_number: string, tag_ids: number[]) =>
    request("/tags/assign", unknownSchema, {
      method: "POST",
      body: JSON.stringify({ doc_number, tag_ids }),
    }),

  // v3: custom expense category
  createCategory: (account_name: string) =>
    request("/accounts", unknownSchema, {
      method: "POST",
      body: JSON.stringify({ account_name, account_type: "beban" }),
    }),
};
