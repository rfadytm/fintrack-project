-- ============================================================
-- FinTrack — 02_views.sql
-- 2 views: account_balances + monthly_summary
-- ============================================================

-- Saldo realtime per akun (dipakai /saldo bot + BalanceCard dashboard)
CREATE OR REPLACE VIEW account_balances AS
SELECT coa.code,
       coa.account_name,
       coa.account_type,
       coa.normal_balance,
       COALESCE(SUM(jl.debit_amount),  0) AS total_debit,
       COALESCE(SUM(jl.credit_amount), 0) AS total_credit,
       CASE WHEN coa.normal_balance = 'debit'
            THEN COALESCE(SUM(jl.debit_amount),  0) - COALESCE(SUM(jl.credit_amount), 0)
            ELSE COALESCE(SUM(jl.credit_amount), 0) - COALESCE(SUM(jl.debit_amount),  0)
       END AS balance
FROM chart_of_accounts coa
LEFT JOIN journal_lines jl ON coa.code = jl.account_code
LEFT JOIN transactions t   ON jl.doc_number = t.doc_number AND t.status = 'POSTED'
WHERE coa.is_header = false AND coa.is_active = true
GROUP BY coa.code, coa.account_name, coa.account_type, coa.normal_balance;

-- Agregasi income vs expense per bulan (dipakai /bulan bot + Reports dashboard)
CREATE OR REPLACE VIEW monthly_summary AS
SELECT t.period_year,
       t.period_month,
       coa.account_type,
       COALESCE(SUM(jl.debit_amount),  0) AS total_debit,
       COALESCE(SUM(jl.credit_amount), 0) AS total_credit
FROM transactions t
JOIN journal_lines jl       ON t.doc_number = jl.doc_number
JOIN chart_of_accounts coa  ON jl.account_code = coa.code
WHERE t.status = 'POSTED' AND coa.is_header = false
GROUP BY t.period_year, t.period_month, coa.account_type;
