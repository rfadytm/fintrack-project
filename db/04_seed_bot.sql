-- ============================================================
-- FinTrack — 04_seed_bot.sql
-- bot_categories + bot_category_accounts + bot_aliases + bot_settings
-- ============================================================

-- ---------- bot_settings (key-value config) ----------
INSERT INTO bot_settings (key, value, notes) VALUES
('default_expense_source', '1130', 'Akun sumber default pengeluaran (SeaBank)'),
('default_income_dest',    '1120', 'Akun tujuan default pemasukan (BNI)'),
('kas_kecil_account',      '1130', 'Akun kas kecil imprest (SeaBank)'),
('kas_kecil_target',       '500000', 'Target balance kas kecil = Rp 500.000'),
('kas_kecil_source',       '1120', 'Sumber pengisian kas kecil (BNI)'),
('savings_account',        '1140', 'Akun tabungan TBD'),
('auth_token_expiry_mins', '60', 'Expiry magic link dashboard (menit)'),
('session_days',           '30', 'Durasi session browser (hari)'),
('state_timeout_mins',     '30', 'Timeout bot conversation state (menit)'),
('bi_fast_fee',            '2500', 'Fee BI-Fast default = Rp 2.500'),
('owner_telegram_id',      '', 'Telegram ID pemilik — diisi saat setup (atau pakai env OWNER_TELEGRAM_ID)');

-- ---------- bot_categories: EXPENSE (9 kategori) ----------
INSERT INTO bot_categories (id, name, emoji, category_type, display_order) VALUES
(1, 'Konsumsi',          '🍔', 'expense', 1),
(2, 'Transport',         '🚌', 'expense', 2),
(3, 'Komunikasi',        '📱', 'expense', 3),
(4, 'Tempat Tinggal',    '🏠', 'expense', 4),
(5, 'Kesehatan',         '🏥', 'expense', 5),
(6, 'Pengembangan',      '📚', 'expense', 6),
(7, 'Sosial & Keluarga', '👨‍👩‍👧', 'expense', 7),
(8, 'Finansial',         '💳', 'expense', 8),
(9, 'Lain-lain',         '📦', 'expense', 9),

-- ---------- bot_categories: INCOME (5 kategori) ----------
(10, 'Honor/Upah',          '💼', 'income', 1),
(11, 'Gaji',                '💵', 'income', 2),
(12, 'Bunga/Investasi',     '📈', 'income', 3),
(13, 'Dividen',             '💰', 'income', 4),
(14, 'Lain-lain Pendapatan','📦', 'income', 5);

SELECT setval(pg_get_serial_sequence('bot_categories', 'id'), 14, true);

-- ---------- bot_category_accounts (mapping kategori -> COA leaf) ----------
INSERT INTO bot_category_accounts (category_id, account_code, display_order) VALUES
-- Konsumsi
(1, '5110', 1), (1, '5120', 2), (1, '5130', 3),
-- Transport
(2, '5210', 1), (2, '5220', 2), (2, '5230', 3), (2, '5240', 4), (2, '5250', 5),
-- Komunikasi
(3, '5310', 1), (3, '5320', 2),
-- Tempat Tinggal
(4, '5610', 1), (4, '5620', 2), (4, '5630', 3), (4, '5640', 4),
-- Kesehatan
(5, '5410', 1), (5, '5420', 2), (5, '5430', 3),
-- Pengembangan
(6, '5510', 1), (6, '5520', 2), (6, '5530', 3), (6, '5540', 4),
-- Sosial & Keluarga
(7, '5710', 1), (7, '5720', 2), (7, '5730', 3), (7, '5740', 4),
-- Finansial
(8, '5810', 1), (8, '5820', 2), (8, '5830', 3),
-- Lain-lain (personal)
(9, '5910', 1), (9, '5920', 2), (9, '5930', 3), (9, '5990', 4), (9, '9999', 5),
-- Honor/Upah
(10, '4110', 1),
-- Gaji
(11, '4120', 1),
-- Bunga/Investasi
(12, '4310', 1),
-- Dividen
(13, '4320', 1),
-- Lain-lain Pendapatan
(14, '4330', 1), (14, '4390', 2);

-- ---------- bot_aliases (shortcut nama -> akun) ----------
INSERT INTO bot_aliases (alias, account_code) VALUES
('makan',   '5110'),
('kopi',    '5120'),
('jajan',   '5130'),
('bensin',  '5210'),
('ojek',    '5220'),
('pulsa',   '5310'),
('wifi',    '5320'),
('kos',     '5610'),
('listrik', '5620'),
('claude',  '5530'),
('zakat',   '5720'),
('keluarga','5710');
