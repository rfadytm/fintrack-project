-- ============================================================
-- FinTrack — 06_seed_periods.sql
-- Seed periode Jun 2026 s.d. Des 2027 (unlocked). Transaksi butuh periode ada (FK).
-- ============================================================

INSERT INTO periods (year, month, is_locked)
SELECT y, m, false
FROM generate_series(2026, 2027) AS y
CROSS JOIN generate_series(1, 12) AS m
WHERE (y, m) >= (2026, 6)   -- mulai Juni 2026
ON CONFLICT (year, month) DO NOTHING;
