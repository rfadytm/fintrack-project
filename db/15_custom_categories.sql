-- ============================================================
-- FinTrack — 15_custom_categories.sql  (v3 — user-added categories beyond seeded COA)
-- Jalankan SETELAH 01–14 selesai.
-- ============================================================

-- Tandai baris yang ditambah user sendiri (lewat bot /kategori atau dashboard COA),
-- dibanding baris yang di-seed dari 03_seed_coa.sql. Dipakai UI untuk membolehkan
-- edit/hapus hanya pada kategori custom, bukan COA bawaan.
ALTER TABLE chart_of_accounts ADD COLUMN IF NOT EXISTS is_custom BOOLEAN NOT NULL DEFAULT false;
