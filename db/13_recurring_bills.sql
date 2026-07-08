-- ============================================================
-- FinTrack — 13_recurring_bills.sql  (v3 — recurring transactions + bill reminders)
-- Amounts: BIGINT. Timestamps: TIMESTAMPTZ (UTC).
-- Jalankan SETELAH 01–12 selesai.
-- ============================================================

-- 17. recurring_transactions — template transaksi yang di-posting otomatis via cron harian.
-- `lines` sama shape dengan p_lines RPC post_document: [{"account_code","debit","credit"}].
CREATE TABLE IF NOT EXISTS recurring_transactions (
    id          SERIAL      PRIMARY KEY,
    doc_type    VARCHAR(5)  NOT NULL CHECK (doc_type IN ('OB','KK','KM','TR','JU','RV')),
    description TEXT,
    lines       JSONB       NOT NULL,
    frequency   VARCHAR(10) NOT NULL CHECK (frequency IN ('daily','weekly','monthly')),
    next_run    DATE        NOT NULL,               -- cron cek WHERE next_run <= today AND is_active
    is_active   BOOLEAN     NOT NULL DEFAULT true,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_recurring_due ON recurring_transactions(next_run) WHERE is_active;

-- 18. bills — tagihan (bulanan berulang via due_day, atau sekali via due_date).
-- last_reminded_period ('YYYY-MM') cegah reminder terkirim berkali-kali dalam bulan yang sama.
CREATE TABLE IF NOT EXISTS bills (
    id                    SERIAL       PRIMARY KEY,
    name                  VARCHAR(100) NOT NULL,
    amount                BIGINT       NOT NULL CHECK (amount > 0),
    due_day               SMALLINT     CHECK (due_day BETWEEN 1 AND 31),
    due_date              DATE,
    is_recurring          BOOLEAN      NOT NULL DEFAULT true,
    is_active             BOOLEAN      NOT NULL DEFAULT true,
    last_reminded_period  VARCHAR(7),
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT bills_due_required CHECK (due_day IS NOT NULL OR due_date IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS idx_bills_active ON bills(is_active);

-- Keamanan: samakan dengan 08_security.sql — RLS ON, tanpa policy.
ALTER TABLE recurring_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE bills                  ENABLE ROW LEVEL SECURITY;

-- Audit: reuse fn_audit_config() dari 10_audit_extend.sql.
DROP TRIGGER IF EXISTS trg_audit_recurring ON recurring_transactions;
CREATE TRIGGER trg_audit_recurring
    AFTER INSERT OR UPDATE OR DELETE ON recurring_transactions
    FOR EACH ROW EXECUTE FUNCTION fn_audit_config('id');

DROP TRIGGER IF EXISTS trg_audit_bills ON bills;
CREATE TRIGGER trg_audit_bills
    AFTER INSERT OR UPDATE OR DELETE ON bills
    FOR EACH ROW EXECUTE FUNCTION fn_audit_config('id');
