// Base URL: kosong = same-origin (produksi Vercel). Dev pakai proxy Vite.
const BASE = import.meta.env.VITE_API_URL || "";

async function request(path, options = {}) {
  const res = await fetch(`${BASE}/api${path}`, {
    credentials: "include",
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  if (res.status === 401) {
    throw new Error("unauthorized");
  }
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.error || `HTTP ${res.status}`);
  }
  return res.json();
}

export const api = {
  // Auth
  me: () => request("/auth/me"),
  verify: (token) =>
    request("/auth/verify", { method: "POST", body: JSON.stringify({ token }) }),

  // Data
  accounts: (params = "") => request(`/accounts${params}`),
  transactions: (qs = "") => request(`/transactions${qs}`),
  balance: (params = "") => request(`/reports/balance${params}`),
  monthly: (year, month) => request(`/reports/monthly?year=${year}&month=${month}`),
  ledger: (account, year, month) =>
    request(`/reports/ledger?account=${account}&year=${year}&month=${month}`),
  trialBalance: (year, month) =>
    request(`/reports/trial-balance?year=${year}&month=${month}`),
  incomeStatement: (year, month) =>
    request(`/reports/income-statement?year=${year}&month=${month}`),
};
