-- ============================================================
-- FinTrack — 10_audit_extend.sql
-- Gabungan Opsi A (extend audit_log trigger) + Opsi B (soft delete bot_aliases).
-- ============================================================

-- ---------- Opsi A: audit untuk tabel konfigurasi ----------
-- Izinkan DELETE tercatat di audit_log (sebelumnya hanya INSERT/UPDATE).
ALTER TABLE audit_log DROP CONSTRAINT IF EXISTS audit_log_action_check;
ALTER TABLE audit_log ADD CONSTRAINT audit_log_action_check
    CHECK (action IN ('INSERT', 'UPDATE', 'DELETE'));

-- Fungsi audit generik: record_id dirakit dari kolom PK (via TG_ARGV).
CREATE OR REPLACE FUNCTION fn_audit_config() RETURNS TRIGGER AS $$
DECLARE
    j_old JSONB := CASE WHEN TG_OP <> 'INSERT' THEN to_jsonb(OLD) END;
    j_new JSONB := CASE WHEN TG_OP <> 'DELETE' THEN to_jsonb(NEW) END;
    j     JSONB := COALESCE(j_new, j_old);
    rid   TEXT  := '';
    col   TEXT;
BEGIN
    FOREACH col IN ARRAY TG_ARGV LOOP
        rid := rid || COALESCE(j->>col, '') || ':';
    END LOOP;
    INSERT INTO audit_log(table_name, record_id, action, old_data, new_data)
    VALUES (TG_TABLE_NAME, rtrim(rid, ':'), TG_OP, j_old, j_new);
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_audit_bot_aliases ON bot_aliases;
CREATE TRIGGER trg_audit_bot_aliases
    AFTER INSERT OR UPDATE OR DELETE ON bot_aliases
    FOR EACH ROW EXECUTE FUNCTION fn_audit_config('alias');

DROP TRIGGER IF EXISTS trg_audit_bot_settings ON bot_settings;
CREATE TRIGGER trg_audit_bot_settings
    AFTER INSERT OR UPDATE OR DELETE ON bot_settings
    FOR EACH ROW EXECUTE FUNCTION fn_audit_config('key');

DROP TRIGGER IF EXISTS trg_audit_transfer_fee_rules ON transfer_fee_rules;
CREATE TRIGGER trg_audit_transfer_fee_rules
    AFTER INSERT OR UPDATE OR DELETE ON transfer_fee_rules
    FOR EACH ROW EXECUTE FUNCTION fn_audit_config('from_account', 'to_account');

-- ---------- Opsi B: soft delete + tracking di bot_aliases ----------
ALTER TABLE bot_aliases ADD COLUMN IF NOT EXISTS is_active      BOOLEAN     NOT NULL DEFAULT true;
ALTER TABLE bot_aliases ADD COLUMN IF NOT EXISTS deactivated_at TIMESTAMPTZ;
ALTER TABLE bot_aliases ADD COLUMN IF NOT EXISTS updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE bot_aliases ADD COLUMN IF NOT EXISTS updated_by     BIGINT;
-- Hapus alias = UPDATE is_active=false (bukan DELETE) → alias lama tetap tersimpan.
