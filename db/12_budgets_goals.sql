-- ============================================================
-- FinTrack — 12_budgets_goals.sql  (v3 — budget alerts + goal tracking)
-- Amounts: BIGINT. Timestamps: TIMESTAMPTZ (UTC).
-- Jalankan SETELAH 01–11 selesai.
-- ============================================================

-- 15. budgets — 1 baris per akun beban yang punya limit bulanan.
-- Spend bulan berjalan DIHITUNG on-the-fly dari journal_lines (tidak disimpan di sini),
-- supaya selalu akurat tanpa perlu sync manual.
CREATE TABLE IF NOT EXISTS budgets (
    account_code   VARCHAR(10) PRIMARY KEY REFERENCES chart_of_accounts(code),
    monthly_limit  BIGINT      NOT NULL CHECK (monthly_limit > 0),  -- batas Rp per bulan
    last_alert_at  TIMESTAMPTZ,                                     -- throttle: min budget_alert_throttle_mins antar alert
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 16. goals — target tabungan. Progress = saldo live account_code (view account_balances),
-- bukan kolom current_amount yang perlu disinkron manual.
CREATE TABLE IF NOT EXISTS goals (
    id            SERIAL       PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,             -- ex: "Laptop baru"
    target_amount BIGINT       NOT NULL CHECK (target_amount > 0),
    account_code  VARCHAR(10)  REFERENCES chart_of_accounts(code),  -- akun yang jadi acuan progress (mis. tabungan)
    target_date   DATE,                               -- opsional, deadline
    is_active     BOOLEAN      NOT NULL DEFAULT true,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_goals_active ON goals(is_active);

-- Keamanan: samakan dengan 08_security.sql — RLS ON, tanpa policy.
ALTER TABLE budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE goals    ENABLE ROW LEVEL SECURITY;

-- Audit: reuse fn_audit_config() dari 10_audit_extend.sql, sama seperti bot_aliases/bot_settings.
DROP TRIGGER IF EXISTS trg_audit_budgets ON budgets;
CREATE TRIGGER trg_audit_budgets
    AFTER INSERT OR UPDATE OR DELETE ON budgets
    FOR EACH ROW EXECUTE FUNCTION fn_audit_config('account_code');

DROP TRIGGER IF EXISTS trg_audit_goals ON goals;
CREATE TRIGGER trg_audit_goals
    AFTER INSERT OR UPDATE OR DELETE ON goals
    FOR EACH ROW EXECUTE FUNCTION fn_audit_config('id');
