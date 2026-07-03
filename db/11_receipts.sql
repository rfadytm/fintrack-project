-- ============================================================
-- FinTrack — 11_receipts.sql  (v2 enhancement — OCR struk/nota)
-- Tabel penampung hasil OCR sebelum dikonfirmasi & di-posting jadi transaksi.
-- Renumber 11 (BUKAN 07): 07–10 sudah dipakai (functions/security/daily_log/audit).
-- Amounts: BIGINT (konsisten schema v1). Timestamps: TIMESTAMPTZ (UTC).
-- Jalankan SETELAH 01–10 selesai.
-- ============================================================

-- 14. receipts — 1 baris per foto struk / screenshot e-wallet yang masuk.
CREATE TABLE IF NOT EXISTS receipts (
    id                 BIGSERIAL   PRIMARY KEY,
    telegram_file_id   VARCHAR(200) NOT NULL,                    -- untuk re-download dari Telegram
    telegram_chat_id   BIGINT       NOT NULL,                    -- kirim konfirmasi balik ke user
    image_path         TEXT,                                     -- opsional: path Supabase Storage (audit)
    raw_ocr_text       TEXT,                                     -- output mentah OCR sebelum parsing
    parsed_merchant    VARCHAR(100),                             -- hasil parse: nama toko/merchant
    parsed_amount      BIGINT,                                   -- hasil parse: nominal (rupiah bulat)
    parsed_date        DATE,                                     -- hasil parse: tanggal di struk
    confidence_score   SMALLINT     CHECK (confidence_score BETWEEN 0 AND 100),
    note               TEXT,                                     -- caption/keterangan dari user saat kirim foto
    parse_source       VARCHAR(20)  NOT NULL DEFAULT 'receipt'
                       CHECK (parse_source IN ('receipt','ewallet')),
    ewallet_type       VARCHAR(20)                               -- gopay/ovo/dana/seabank/bca; null jika struk fisik
                       CHECK (ewallet_type IS NULL OR ewallet_type IN ('gopay','ovo','dana','seabank','bca')),
    status             VARCHAR(20)  NOT NULL DEFAULT 'pending'
                       CHECK (status IN ('pending','confirmed','rejected','manual')),
    doc_number         VARCHAR(25)  REFERENCES transactions(doc_number),  -- diisi setelah di-POST
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_receipts_status  ON receipts(status);
CREATE INDEX IF NOT EXISTS idx_receipts_created ON receipts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_receipts_doc     ON receipts(doc_number);

-- Keamanan: samakan dengan 08_security.sql — RLS ON, tanpa policy.
-- Backend pakai service_role key (BYPASSRLS) → tetap jalan; anon/publik DITOLAK total.
ALTER TABLE receipts ENABLE ROW LEVEL SECURITY;

-- ---------- Config default untuk pipeline OCR ----------
-- Akun beban default kalau merchant tidak match alias apa pun (catch-all 9999 ada di 03_seed_coa).
INSERT INTO bot_settings (key, value, notes) VALUES
('receipt_default_expense', '9999', 'Akun beban default hasil OCR kalau merchant tidak dikenali (catch-all)'),
('receipt_min_confidence', '50', 'Skor minimum (0-100) agar bot tawarkan simpan; di bawah ini minta input manual')
ON CONFLICT (key) DO NOTHING;

-- ---------- bot_aliases: tambah merchant umum (struk + e-wallet) ----------
-- Extend mapping existing; alias = substring lowercase yang dicari di merchant/keterangan.
INSERT INTO bot_aliases (alias, account_code) VALUES
('indomaret',  '5130'),   -- minimarket → jajan/konsumsi
('alfamart',   '5130'),
('alfamidi',   '5130'),
('superindo',  '5640'),   -- groceries → kebutuhan rumah tangga
('hypermart',  '5640'),
('transmart',  '5640'),
('warung',     '5110'),   -- warung makan → makan harian
('resto',      '5110'),
('restoran',   '5110'),
('kfc',        '5110'),
('mcd',        '5110'),
('mcdonald',   '5110'),
('starbucks',  '5120'),   -- kopi
('kopi',       '5120'),
('gojek',      '5220'),   -- ojek online (e-wallet: GoPay merchant)
('gofood',     '5110'),
('grab',       '5220'),
('grabfood',   '5110'),
('shopeefood', '5110'),
('pertamina',  '5210'),   -- BBM
('spbu',       '5210'),
('shell',      '5210'),
('pln',        '5620'),   -- listrik
('pdam',       '5630'),   -- air
('apotek',     '5410'),   -- obat
('kimia farma','5410'),
('k24',        '5410')
ON CONFLICT (alias) DO NOTHING;
