-- ============================================================
-- FinTrack — 14_tags.sql  (v3 — transaction tags)
-- Jalankan SETELAH 01–13 selesai.
-- ============================================================

-- 19. tags — daftar tag bebas (mis. "kerja", "bisa-dikurangi-pajak").
CREATE TABLE IF NOT EXISTS tags (
    id    SERIAL      PRIMARY KEY,
    name  VARCHAR(30) NOT NULL UNIQUE,
    emoji VARCHAR(10)
);

-- 20. transaction_tags — many-to-many transaksi <-> tag.
CREATE TABLE IF NOT EXISTS transaction_tags (
    doc_number VARCHAR(25) NOT NULL REFERENCES transactions(doc_number),
    tag_id     INTEGER     NOT NULL REFERENCES tags(id),
    PRIMARY KEY (doc_number, tag_id)
);
CREATE INDEX IF NOT EXISTS idx_transaction_tags_tag ON transaction_tags(tag_id);

-- Keamanan: samakan dengan 08_security.sql — RLS ON, tanpa policy.
ALTER TABLE tags             ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_tags ENABLE ROW LEVEL SECURITY;

-- Audit: reuse fn_audit_config() dari 10_audit_extend.sql (hanya tabel tags; join table tidak perlu).
DROP TRIGGER IF EXISTS trg_audit_tags ON tags;
CREATE TRIGGER trg_audit_tags
    AFTER INSERT OR UPDATE OR DELETE ON tags
    FOR EACH ROW EXECUTE FUNCTION fn_audit_config('id');
