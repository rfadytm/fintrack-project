-- ============================================================
-- FinTrack — 17_v3_preferences.sql  (v3 — preferensi baru di bot_settings)
-- Tabel bot_settings sudah generic key/value (01_schema.sql) — murni seed, tanpa DDL.
-- Jalankan SETELAH 01–16 selesai.
-- ============================================================

INSERT INTO bot_settings (key, value, notes) VALUES
    ('currency_preference',     'IDR',   'Mata uang default tampilan (IDR/USD/SGD/dst)'),
    ('timezone',                'Asia/Jakarta', 'Timezone untuk cron & laporan terjadwal'),
    ('daily_report_enabled',    'true',  'Aktif/nonaktifkan laporan harian jam 9 pagi'),
    ('weekly_report_enabled',   'true',  'Aktif/nonaktifkan laporan mingguan (Minggu)'),
    ('alert_sensitivity',       'normal', 'Sensitivitas deteksi anomali: strict/normal/relaxed'),
    ('rate_limit_per_minute',   '20',    'Maks pesan bot per user per menit sebelum ditolak'),
    ('budget_alert_throttle_mins', '120', 'Jarak minimum antar alert budget per kategori (menit)')
ON CONFLICT (key) DO NOTHING;
