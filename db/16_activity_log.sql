-- ============================================================
-- FinTrack — 16_activity_log.sql  (v3 — rate limiting + anti-abuse + activity audit)
-- Beda dari audit_log (perubahan data tabel): activity_log mencatat SETIAP
-- interaksi masuk ke bot (command/callback/text), dipakai untuk 3 hal sekaligus:
-- rate limiting (hitung baris N detik terakhir), anti-abuse (deteksi pola/nominal
-- tidak wajar), dan log aktivitas umum.
-- Jalankan SETELAH 01–15 selesai.
-- ============================================================

CREATE TABLE IF NOT EXISTS activity_log (
    id         BIGSERIAL   PRIMARY KEY,
    user_id    BIGINT      NOT NULL,
    action     VARCHAR(50) NOT NULL,           -- ex: "message", "callback:exp_post", "command:/saldo"
    meta       JSONB       NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_activity_user_time ON activity_log(user_id, created_at DESC);

-- Keamanan: samakan dengan 08_security.sql — RLS ON, tanpa policy.
ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;

-- Tanpa trigger audit di sini secara sengaja — tabel ini SENDIRI adalah log,
-- meng-audit log-nya sendiri cuma dobel data tanpa manfaat.
