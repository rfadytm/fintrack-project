-- ============================================================
-- FinTrack — 07_functions.sql
-- RPC functions (dipanggil via supabase.rpc()).
-- ============================================================

-- Atomic doc-number sequence (anti race condition saat 2 transaksi bersamaan).
-- Return seq berikutnya untuk (doc_type, year, month), reset per bulan.
CREATE OR REPLACE FUNCTION next_doc_seq(p_doc_type VARCHAR, p_year INT, p_month INT)
RETURNS INT AS $$
DECLARE
    new_seq INT;
BEGIN
    INSERT INTO sequences (doc_type, year, month, last_seq)
    VALUES (p_doc_type, p_year, p_month, 1)
    ON CONFLICT (doc_type, year, month)
    DO UPDATE SET last_seq = sequences.last_seq + 1
    RETURNING last_seq INTO new_seq;
    RETURN new_seq;
END;
$$ LANGUAGE plpgsql;

-- Post 1 dokumen + journal_lines atomik, dengan guard double-entry & period lock.
-- p_lines: JSONB array of {account_code, debit, credit}.
CREATE OR REPLACE FUNCTION post_document(
    p_doc_number VARCHAR,
    p_doc_type   VARCHAR,
    p_date       DATE,
    p_description TEXT,
    p_input_source VARCHAR,
    p_is_reversal BOOLEAN,
    p_reversal_of VARCHAR,
    p_lines      JSONB
) RETURNS VARCHAR AS $$
DECLARE
    v_year  INT := EXTRACT(YEAR  FROM p_date);
    v_month INT := EXTRACT(MONTH FROM p_date);
    v_locked BOOLEAN;
    v_debit  BIGINT := 0;
    v_credit BIGINT := 0;
    v_line   JSONB;
    v_order  SMALLINT := 1;
BEGIN
    -- Period lock guard
    SELECT is_locked INTO v_locked FROM periods WHERE year = v_year AND month = v_month;
    IF v_locked THEN
        RAISE EXCEPTION 'Periode %-% terkunci', v_year, v_month;
    END IF;

    -- Double-entry guard
    FOR v_line IN SELECT * FROM jsonb_array_elements(p_lines) LOOP
        v_debit  := v_debit  + COALESCE((v_line->>'debit')::BIGINT, 0);
        v_credit := v_credit + COALESCE((v_line->>'credit')::BIGINT, 0);
    END LOOP;
    IF v_debit <> v_credit THEN
        RAISE EXCEPTION 'Tidak balance: debit % <> kredit %', v_debit, v_credit;
    END IF;
    IF v_debit = 0 THEN
        RAISE EXCEPTION 'Jurnal kosong';
    END IF;

    INSERT INTO transactions
        (doc_number, doc_type, transaction_date, period_year, period_month,
         description, status, is_reversal, reversal_of_doc, input_source)
    VALUES
        (p_doc_number, p_doc_type, p_date, v_year, v_month,
         p_description, 'POSTED', p_is_reversal, p_reversal_of, p_input_source);

    FOR v_line IN SELECT * FROM jsonb_array_elements(p_lines) LOOP
        INSERT INTO journal_lines (doc_number, line_order, account_code, debit_amount, credit_amount)
        VALUES (
            p_doc_number, v_order, v_line->>'account_code',
            COALESCE((v_line->>'debit')::BIGINT, 0),
            COALESCE((v_line->>'credit')::BIGINT, 0)
        );
        v_order := v_order + 1;
    END LOOP;

    RETURN p_doc_number;
END;
$$ LANGUAGE plpgsql;

-- Trial balance s.d. periode terpilih (cumulative). account_type filter opsional (NULL=semua).
CREATE OR REPLACE FUNCTION trial_balance(p_year INT, p_month INT, p_type VARCHAR DEFAULT NULL)
RETURNS TABLE (
    code VARCHAR, account_name VARCHAR, account_type VARCHAR, normal_balance VARCHAR,
    total_debit BIGINT, total_credit BIGINT, balance BIGINT
) AS $$
    SELECT coa.code, coa.account_name, coa.account_type, coa.normal_balance,
           COALESCE(SUM(jl.debit_amount), 0)  AS total_debit,
           COALESCE(SUM(jl.credit_amount), 0) AS total_credit,
           CASE WHEN coa.normal_balance = 'debit'
                THEN COALESCE(SUM(jl.debit_amount),0) - COALESCE(SUM(jl.credit_amount),0)
                ELSE COALESCE(SUM(jl.credit_amount),0) - COALESCE(SUM(jl.debit_amount),0)
           END AS balance
    FROM chart_of_accounts coa
    LEFT JOIN journal_lines jl ON coa.code = jl.account_code
    LEFT JOIN transactions t   ON jl.doc_number = t.doc_number
         AND t.status = 'POSTED'
         AND (t.period_year, t.period_month) <= (p_year, p_month)
    WHERE coa.is_header = false
      AND coa.is_active = true
      AND (p_type IS NULL OR coa.account_type = p_type)
    GROUP BY coa.code, coa.account_name, coa.account_type, coa.normal_balance
    HAVING COALESCE(SUM(jl.debit_amount),0) + COALESCE(SUM(jl.credit_amount),0) > 0
    ORDER BY coa.code;
$$ LANGUAGE sql STABLE;

-- Laba Rugi per bulan (hanya periode terpilih), per akun pendapatan & beban.
CREATE OR REPLACE FUNCTION income_statement(p_year INT, p_month INT)
RETURNS TABLE (
    code VARCHAR, account_name VARCHAR, account_type VARCHAR, amount BIGINT
) AS $$
    SELECT coa.code, coa.account_name, coa.account_type,
           CASE WHEN coa.account_type = 'pendapatan'
                THEN COALESCE(SUM(jl.credit_amount),0) - COALESCE(SUM(jl.debit_amount),0)
                ELSE COALESCE(SUM(jl.debit_amount),0) - COALESCE(SUM(jl.credit_amount),0)
           END AS amount
    FROM chart_of_accounts coa
    JOIN journal_lines jl ON coa.code = jl.account_code
    JOIN transactions t   ON jl.doc_number = t.doc_number
         AND t.status = 'POSTED'
         AND t.period_year = p_year AND t.period_month = p_month
    WHERE coa.is_header = false AND coa.account_type IN ('pendapatan','beban')
    GROUP BY coa.code, coa.account_name, coa.account_type
    HAVING COALESCE(SUM(jl.debit_amount),0) + COALESCE(SUM(jl.credit_amount),0) > 0
    ORDER BY coa.code;
$$ LANGUAGE sql STABLE;

-- Reverse: tandai dokumen asli REVERSED + buat dokumen RV (jurnal terbalik) di tanggal hari ini.
-- B14: RV dicatat di TANGGAL HARI INI (bukan tanggal asli) -> tidak kena period lock asli.
CREATE OR REPLACE FUNCTION reverse_document(p_doc VARCHAR, p_rv_doc VARCHAR, p_today DATE)
RETURNS VARCHAR AS $$
DECLARE
    v_status VARCHAR;
    v_year   INT := EXTRACT(YEAR  FROM p_today);
    v_month  INT := EXTRACT(MONTH FROM p_today);
    v_locked BOOLEAN;
    rec      RECORD;
    v_order  SMALLINT := 1;
BEGIN
    SELECT status INTO v_status FROM transactions WHERE doc_number = p_doc;
    IF v_status IS NULL THEN RAISE EXCEPTION 'Dokumen % tidak ditemukan', p_doc; END IF;
    IF v_status = 'REVERSED' THEN RAISE EXCEPTION 'Dokumen % sudah di-reverse', p_doc; END IF;

    SELECT is_locked INTO v_locked FROM periods WHERE year = v_year AND month = v_month;
    IF v_locked THEN RAISE EXCEPTION 'Periode hari ini terkunci'; END IF;

    INSERT INTO transactions
        (doc_number, doc_type, transaction_date, period_year, period_month,
         description, status, is_reversal, reversal_of_doc, input_source)
    VALUES
        (p_rv_doc, 'RV', p_today, v_year, v_month,
         'Reverse dari ' || p_doc, 'POSTED', true, p_doc, 'system');

    FOR rec IN SELECT account_code, debit_amount, credit_amount
               FROM journal_lines WHERE doc_number = p_doc ORDER BY line_order LOOP
        INSERT INTO journal_lines (doc_number, line_order, account_code, debit_amount, credit_amount)
        VALUES (p_rv_doc, v_order, rec.account_code, rec.credit_amount, rec.debit_amount);
        v_order := v_order + 1;
    END LOOP;

    UPDATE transactions SET status = 'REVERSED' WHERE doc_number = p_doc;
    RETURN p_rv_doc;
END;
$$ LANGUAGE plpgsql;
