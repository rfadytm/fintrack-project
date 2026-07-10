import { z } from "zod";

// Runtime shape guards for backend responses (blindspot fix: TS types alone don't
// protect against the API actually returning something different at runtime).
// Kept intentionally permissive (nullable/optional where the backend allows it)
// so a genuinely-absent field doesn't itself trigger a shape-mismatch error.

export const AccountSchema = z.object({
  code: z.string(),
  account_name: z.string(),
  account_type: z.string(),
  normal_balance: z.enum(["debit", "credit"]),
  level: z.number(),
  is_header: z.boolean(),
});
export type Account = z.infer<typeof AccountSchema>;

export const JournalLineSchema = z.object({
  id: z.union([z.string(), z.number()]).optional(),
  account_code: z.string(),
  debit_amount: z.number().nullable().optional(),
  credit_amount: z.number().nullable().optional(),
  line_order: z.number().optional(),
  running_balance: z.number().nullable().optional(),
  transactions: z
    .object({
      transaction_date: z.string(),
      doc_number: z.string(),
      description: z.string().nullable().optional(),
    })
    .optional(),
});
export type JournalLine = z.infer<typeof JournalLineSchema>;

export const TransactionSchema = z.object({
  doc_number: z.string(),
  transaction_date: z.string(),
  doc_type: z.string(),
  description: z.string().nullable().optional(),
  status: z.string(),
  journal_lines: z.array(JournalLineSchema).optional(),
});
export type Transaction = z.infer<typeof TransactionSchema>;

export const BalanceRowSchema = z.object({
  code: z.string(),
  account_name: z.string(),
  // nullable: masked to null for unauthenticated public-demo viewers, see
  // shared/masking.py — a real balance is never actually absent otherwise.
  balance: z.number().nullable(),
});
export type BalanceRow = z.infer<typeof BalanceRowSchema>;

export const AccountsResponseSchema = z.object({ accounts: z.array(AccountSchema) });
export const TransactionsResponseSchema = z.object({
  transactions: z.array(TransactionSchema),
  total: z.number().optional(),
});
export const BalanceResponseSchema = z.object({ balances: z.array(BalanceRowSchema) });
export const LedgerResponseSchema = z.object({ lines: z.array(JournalLineSchema) });

export const MonthlyReportSchema = z.object({
  income: z.number().nullable().optional(),
  expense: z.number().nullable().optional(),
  net: z.number().nullable().optional(),
  // Saldo awal (/setup, doc OB) HANYA muncul kalau periode yang dilihat = bulan
  // setup dilakukan. Sengaja dipisah dari `income` — modal awal (ekuitas) bukan
  // pendapatan secara akuntansi, jadi tidak ikut Laba Rugi/savings_rate.
  opening_balance: z.number().nullable().optional(),
  savings_rate: z.number().nullable().optional(),
});
export type MonthlyReport = z.infer<typeof MonthlyReportSchema>;

const IncomeStatementRowSchema = z.object({
  code: z.string(),
  account_name: z.string(),
  // nullable: masked to null for public-demo viewers (income-statement AND
  // range reports both use this row shape) — see shared/masking.py.
  amount: z.number().nullable(),
});
export const IncomeStatementSchema = z.object({
  revenue: z.array(IncomeStatementRowSchema).optional(),
  expense: z.array(IncomeStatementRowSchema).optional(),
  total_revenue: z.number().nullable().optional(),
  total_expense: z.number().nullable().optional(),
  net_income: z.number().nullable().optional(),
});
export type IncomeStatement = z.infer<typeof IncomeStatementSchema>;

const TrialBalanceRowSchema = z.object({
  code: z.string(),
  account_name: z.string(),
  total_debit: z.number().nullable().optional(),
  total_credit: z.number().nullable().optional(),
});
export const TrialBalanceSchema = z.object({
  accounts: z.array(TrialBalanceRowSchema).optional(),
  total_debit: z.number().nullable().optional(),
  total_credit: z.number().nullable().optional(),
  balanced: z.boolean().optional(),
});
export type TrialBalance = z.infer<typeof TrialBalanceSchema>;

export const AuthMeSchema = z.object({ logged_in: z.boolean() });

export const SettingRowSchema = z.object({ key: z.string(), value: z.unknown() });
export const SettingsResponseSchema = z.object({ settings: z.array(SettingRowSchema) });

// Settings form validation (blindspot fix: number fields were sent to the API as
// raw strings straight off e.target.value, with no check they were even numeric).
export const SettingsFormSchema = z.object({
  default_expense_source: z.string().min(1, "Wajib dipilih"),
  default_income_dest: z.string().min(1, "Wajib dipilih"),
  kas_kecil_source: z.string().min(1, "Wajib dipilih"),
  savings_account: z.string().min(1, "Wajib dipilih"),
  kas_kecil_target: z.coerce
    .number({ message: "Harus berupa angka" })
    .nonnegative("Tidak boleh negatif"),
  bi_fast_fee: z.coerce
    .number({ message: "Harus berupa angka" })
    .nonnegative("Tidak boleh negatif"),
});
export type SettingsFormValues = z.infer<typeof SettingsFormSchema>;

// ---------- v3 ----------

export const BudgetSchema = z.object({
  account_code: z.string(),
  account_name: z.string().nullable().optional(),
  // nullable: masked to null for public-demo viewers, see shared/masking.py.
  monthly_limit: z.number().nullable(),
  spent: z.number().nullable(),
  last_alert_at: z.string().nullable().optional(),
});
export type Budget = z.infer<typeof BudgetSchema>;
export const BudgetsResponseSchema = z.object({ budgets: z.array(BudgetSchema) });

export const GoalSchema = z.object({
  id: z.number(),
  name: z.string(),
  // nullable: masked to null for public-demo viewers, see shared/masking.py.
  target_amount: z.number().nullable(),
  account_code: z.string().nullable().optional(),
  target_date: z.string().nullable().optional(),
  is_active: z.boolean(),
  current_amount: z.number().nullable(),
});
export type Goal = z.infer<typeof GoalSchema>;
export const GoalsResponseSchema = z.object({ goals: z.array(GoalSchema) });

const RecurringLineSchema = z.object({
  account_code: z.string(),
  debit: z.number().optional(),
  credit: z.number().optional(),
});
export const RecurringSchema = z.object({
  id: z.number(),
  doc_type: z.string(),
  description: z.string().nullable().optional(),
  lines: z.array(RecurringLineSchema),
  frequency: z.enum(["daily", "weekly", "monthly"]),
  next_run: z.string(),
  is_active: z.boolean(),
});
export type Recurring = z.infer<typeof RecurringSchema>;
export const RecurringResponseSchema = z.object({ recurring: z.array(RecurringSchema) });

export const BillSchema = z.object({
  id: z.number(),
  name: z.string(),
  amount: z.number(),
  due_day: z.number().nullable().optional(),
  due_date: z.string().nullable().optional(),
  is_recurring: z.boolean(),
  is_active: z.boolean(),
  last_reminded_period: z.string().nullable().optional(),
});
export type Bill = z.infer<typeof BillSchema>;
export const BillsResponseSchema = z.object({ bills: z.array(BillSchema) });

export const TagSchema = z.object({
  id: z.number(),
  name: z.string(),
  emoji: z.string().nullable().optional(),
});
export type Tag = z.infer<typeof TagSchema>;
export const TagsResponseSchema = z.object({ tags: z.array(TagSchema) });

export const RangeReportSchema = z.object({
  date_from: z.string(),
  date_to: z.string(),
  revenue: z.array(IncomeStatementRowSchema).optional(),
  expense: z.array(IncomeStatementRowSchema).optional(),
  // nullable: masked to null for public-demo viewers, see shared/masking.py.
  total_revenue: z.number().nullable().optional(),
  total_expense: z.number().nullable().optional(),
  net_income: z.number().nullable().optional(),
});
export type RangeReport = z.infer<typeof RangeReportSchema>;

const CategoryForecastSchema = z.object({
  code: z.string(),
  account_name: z.string().nullable().optional(),
  // nullable elements: masked to null for public-demo viewers, see
  // shared/masking.py mask_number_list().
  history: z.array(z.number().nullable()),
  forecast: z.number().nullable().optional(),
});
// v3.1: forecast dipecah jadi 3 horizon dari model tren yang sama — makin
// panjang horizon, makin banyak bulan lengkap yang disyaratkan sebelum
// ditampilkan (null = belum cukup data, bukan diam-diam 0). Lihat
// api/reports/index.py::_report_forecast & doc.txt §9.14.
const ForecastTierSchema = z.object({
  label: z.string(),
  months: z.number(),
  min_real_months: z.number(),
  income: z.number().nullable(),
  expense: z.number().nullable(),
});
export type ForecastTier = z.infer<typeof ForecastTierSchema>;
export const ForecastSchema = z.object({
  months: z.number(),
  real_months_available: z.number(),
  // nullable elements: masked to null for public-demo viewers, see
  // shared/masking.py mask_number_list().
  income_history: z.array(z.number().nullable()),
  expense_history: z.array(z.number().nullable()),
  short_term: ForecastTierSchema,
  medium_term: ForecastTierSchema,
  long_term: ForecastTierSchema,
  top_categories: z.array(CategoryForecastSchema),
});
export type Forecast = z.infer<typeof ForecastSchema>;

// Budget/Goal/Recurring/Bill forms (dashboard CRUD) — mirror the bot wizards' validation.
export const BudgetFormSchema = z.object({
  account_code: z.string().min(1, "Wajib dipilih"),
  monthly_limit: z.coerce.number({ message: "Harus berupa angka" }).positive("Harus > 0"),
});
export type BudgetFormValues = z.infer<typeof BudgetFormSchema>;

export const GoalFormSchema = z.object({
  name: z.string().min(1, "Wajib diisi"),
  target_amount: z.coerce.number({ message: "Harus berupa angka" }).positive("Harus > 0"),
  account_code: z.string().min(1, "Wajib dipilih"),
  target_date: z.string().optional(),
});
export type GoalFormValues = z.infer<typeof GoalFormSchema>;

export const BillFormSchema = z.object({
  name: z.string().min(1, "Wajib diisi"),
  amount: z.coerce.number({ message: "Harus berupa angka" }).positive("Harus > 0"),
  due_day: z.coerce.number().int().min(1).max(31),
});
export type BillFormValues = z.infer<typeof BillFormSchema>;

export const RecurringFormSchema = z.object({
  description: z.string().min(1, "Wajib diisi"),
  account_code: z.string().min(1, "Wajib dipilih"),
  source: z.string().min(1, "Wajib dipilih"),
  amount: z.coerce.number({ message: "Harus berupa angka" }).positive("Harus > 0"),
  frequency: z.enum(["daily", "weekly", "monthly"]),
});
export type RecurringFormValues = z.infer<typeof RecurringFormSchema>;
