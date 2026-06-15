-- ============================================================
-- FinTrack — 01_schema.sql
-- 13 tabel. Amounts: BIGINT (rupiah bulat). Timestamps: TIMESTAMPTZ (UTC).
-- CREATE ORDER: chart_of_accounts -> periods -> sequences -> transactions
--   -> journal_lines -> bot_categories -> bot_category_accounts -> bot_aliases
--   -> bot_settings -> bot_state -> transfer_fee_rules -> auth_tokens -> audit_log
-- ============================================================

-- 1. chart_of_accounts (COA 3-level)
CREATE TABLE chart_of_accounts (
    code            VARCHAR(10) PRIMARY KEY,
    parent_code     VARCHAR(10) REFERENCES chart_of_accounts(code),
    level           SMALLINT    NOT NULL CHECK (level IN (1, 2, 3)),
    account_name    VARCHAR(100) NOT NULL,
    account_type    VARCHAR(20) NOT NULL CHECK (account_type IN ('aset','liabilitas','ekuitas','pendapatan','beban')),
    normal_balance  VARCHAR(10) NOT NULL CHECK (normal_balance IN ('debit','credit')),
    is_header       BOOLEAN     NOT NULL DEFAULT false,
    is_active       BOOLEAN     NOT NULL DEFAULT true,
    display_order   SMALLINT    NOT NULL DEFAULT 0,
    notes           TEXT
);

-- 2. periods
CREATE TABLE periods (
    year       SMALLINT NOT NULL,
    month      SMALLINT NOT NULL CHECK (month BETWEEN 1 AND 12),
    is_locked  BOOLEAN  NOT NULL DEFAULT false,
    locked_at  TIMESTAMPTZ,
    PRIMARY KEY (year, month)
);

-- 3. sequences (counter doc number, reset per bulan)
CREATE TABLE sequences (
    doc_type  VARCHAR(5) NOT NULL CHECK (doc_type IN ('OB','KK','KM','TR','JU','RV')),
    year      SMALLINT   NOT NULL,
    month     SMALLINT   NOT NULL CHECK (month BETWEEN 1 AND 12),
    last_seq  INTEGER    NOT NULL DEFAULT 0,
    PRIMARY KEY (doc_type, year, month)
);

-- 4. transactions
CREATE TABLE transactions (
    doc_number       VARCHAR(25) PRIMARY KEY,
    doc_type         VARCHAR(5)  NOT NULL CHECK (doc_type IN ('OB','KK','KM','TR','JU','RV')),
    transaction_date DATE        NOT NULL,
    period_year      SMALLINT    NOT NULL,
    period_month     SMALLINT    NOT NULL,
    description      TEXT,
    status           VARCHAR(10) NOT NULL DEFAULT 'POSTED' CHECK (status IN ('POSTED','REVERSED')),
    is_reversal      BOOLEAN     NOT NULL DEFAULT false,
    reversal_of_doc  VARCHAR(25) REFERENCES transactions(doc_number),
    input_source     VARCHAR(20) NOT NULL DEFAULT 'telegram' CHECK (input_source IN ('telegram','dashboard','system')),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    FOREIGN KEY (period_year, period_month) REFERENCES periods(year, month)
);
CREATE INDEX idx_tx_period   ON transactions(period_year, period_month);
CREATE INDEX idx_tx_date     ON transactions(transaction_date);
CREATE INDEX idx_tx_created  ON transactions(created_at DESC);

-- 5. journal_lines
CREATE TABLE journal_lines (
    id            BIGSERIAL   PRIMARY KEY,
    doc_number    VARCHAR(25) NOT NULL REFERENCES transactions(doc_number),
    line_order    SMALLINT    NOT NULL DEFAULT 1,
    account_code  VARCHAR(10) NOT NULL REFERENCES chart_of_accounts(code),
    debit_amount  BIGINT      NOT NULL DEFAULT 0 CHECK (debit_amount  >= 0),
    credit_amount BIGINT      NOT NULL DEFAULT 0 CHECK (credit_amount >= 0),
    CONSTRAINT one_side_only CHECK (
        (debit_amount > 0 AND credit_amount = 0) OR
        (debit_amount = 0 AND credit_amount > 0)
    )
);
CREATE INDEX idx_jl_doc     ON journal_lines(doc_number);
CREATE INDEX idx_jl_account ON journal_lines(account_code);

-- 6. bot_categories
CREATE TABLE bot_categories (
    id            SERIAL      PRIMARY KEY,
    name          VARCHAR(50) NOT NULL,
    emoji         VARCHAR(10),
    category_type VARCHAR(10) NOT NULL CHECK (category_type IN ('expense','income')),
    parent_id     INTEGER     REFERENCES bot_categories(id),
    display_order SMALLINT    NOT NULL DEFAULT 0,
    is_active     BOOLEAN     NOT NULL DEFAULT true
);

-- 7. bot_category_accounts (mapping kategori -> COA leaf)
CREATE TABLE bot_category_accounts (
    category_id   INTEGER     NOT NULL REFERENCES bot_categories(id),
    account_code  VARCHAR(10) NOT NULL REFERENCES chart_of_accounts(code),
    display_order SMALLINT    NOT NULL DEFAULT 0,
    PRIMARY KEY (category_id, account_code)
);

-- 8. bot_aliases
CREATE TABLE bot_aliases (
    alias        VARCHAR(50) PRIMARY KEY,
    account_code VARCHAR(10) NOT NULL REFERENCES chart_of_accounts(code),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 9. bot_settings (key-value config)
CREATE TABLE bot_settings (
    key   VARCHAR(50) PRIMARY KEY,
    value TEXT        NOT NULL,
    notes TEXT
);

-- 10. bot_state (state machine per user)
CREATE TABLE bot_state (
    user_id    BIGINT      PRIMARY KEY,
    state      VARCHAR(50) NOT NULL DEFAULT 'IDLE',
    state_data JSONB       NOT NULL DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 11. transfer_fee_rules
CREATE TABLE transfer_fee_rules (
    from_account VARCHAR(10) NOT NULL REFERENCES chart_of_accounts(code),
    to_account   VARCHAR(10) NOT NULL REFERENCES chart_of_accounts(code),
    fee_amount   BIGINT      NOT NULL DEFAULT 0 CHECK (fee_amount >= 0),
    fee_account  VARCHAR(10) REFERENCES chart_of_accounts(code),
    method_label VARCHAR(50),
    PRIMARY KEY (from_account, to_account)
);

-- 12. auth_tokens (HMAC magic link, single-use)
CREATE TABLE auth_tokens (
    token      VARCHAR(200) PRIMARY KEY,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ  NOT NULL,
    used_at    TIMESTAMPTZ,
    is_used    BOOLEAN      NOT NULL DEFAULT false
);
CREATE INDEX idx_auth_expires ON auth_tokens(expires_at);

-- 13. audit_log (append-only)
CREATE TABLE audit_log (
    id         BIGSERIAL    PRIMARY KEY,
    table_name VARCHAR(50)  NOT NULL,
    record_id  VARCHAR(100) NOT NULL,
    action     VARCHAR(10)  NOT NULL CHECK (action IN ('INSERT','UPDATE')),
    old_data   JSONB,
    new_data   JSONB,
    changed_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_audit_table ON audit_log(table_name, record_id);

-- ============================================================
-- Audit trail + No-Delete policy (Prinsip Akuntansi)
-- transactions & journal_lines: INSERT/UPDATE auto-log, DELETE diblok.
-- ============================================================
CREATE OR REPLACE FUNCTION fn_audit() RETURNS TRIGGER AS $$
DECLARE
    rid TEXT;
BEGIN
    IF TG_TABLE_NAME = 'transactions' THEN
        rid := COALESCE(NEW.doc_number, OLD.doc_number);
    ELSE
        rid := COALESCE(NEW.id::text, OLD.id::text);
    END IF;

    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log(table_name, record_id, action, old_data, new_data)
        VALUES (TG_TABLE_NAME, rid, 'INSERT', NULL, to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log(table_name, record_id, action, old_data, new_data)
        VALUES (TG_TABLE_NAME, rid, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_no_delete() RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'DELETE dilarang pada % — gunakan REVERSE (RV)', TG_TABLE_NAME;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_transactions
    AFTER INSERT OR UPDATE ON transactions
    FOR EACH ROW EXECUTE FUNCTION fn_audit();
CREATE TRIGGER trg_audit_journal_lines
    AFTER INSERT OR UPDATE ON journal_lines
    FOR EACH ROW EXECUTE FUNCTION fn_audit();

CREATE TRIGGER trg_nodelete_transactions
    BEFORE DELETE ON transactions
    FOR EACH ROW EXECUTE FUNCTION fn_no_delete();
CREATE TRIGGER trg_nodelete_journal_lines
    BEFORE DELETE ON journal_lines
    FOR EACH ROW EXECUTE FUNCTION fn_no_delete();
