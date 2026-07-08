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
  balance: z.number(),
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
});
export type MonthlyReport = z.infer<typeof MonthlyReportSchema>;

const IncomeStatementRowSchema = z.object({
  code: z.string(),
  account_name: z.string(),
  amount: z.number(),
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
