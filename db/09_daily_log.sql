-- ============================================================
-- FinTrack — 09_daily_log.sql
-- Catatan harian "tidak ada transaksi" (nihil). Memberi aktivitas/ping ke Supabase
-- di hari tanpa transaksi + jejak bahwa hari itu sudah dicek. Bukan jurnal keuangan.
-- ============================================================

CREATE TABLE IF NOT EXISTS daily_log (
    log_date   DATE        PRIMARY KEY,
    user_id    BIGINT,
    note       TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE daily_log ENABLE ROW LEVEL SECURITY;  -- service_role bypass; anon ditolak
