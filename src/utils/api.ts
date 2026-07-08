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
};
