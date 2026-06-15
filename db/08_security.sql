-- ============================================================
-- FinTrack — 08_security.sql
-- Kunci akses publik. Backend pakai service_role key (BYPASSRLS) → tetap jalan.
-- Tanpa file ini, anon key (publik) bisa baca/tulis semua tabel via Supabase REST.
-- ============================================================

-- 1) Enable RLS di semua base table. Tanpa policy = anon/authenticated DITOLAK total.
ALTER TABLE chart_of_accounts     ENABLE ROW LEVEL SECURITY;
ALTER TABLE periods               ENABLE ROW LEVEL SECURITY;
ALTER TABLE sequences             ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions          ENABLE ROW LEVEL SECURITY;
ALTER TABLE journal_lines         ENABLE ROW LEVEL SECURITY;
ALTER TABLE bot_categories        ENABLE ROW LEVEL SECURITY;
ALTER TABLE bot_category_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE bot_aliases           ENABLE ROW LEVEL SECURITY;
ALTER TABLE bot_settings          ENABLE ROW LEVEL SECURITY;
ALTER TABLE bot_state             ENABLE ROW LEVEL SECURITY;
ALTER TABLE transfer_fee_rules    ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth_tokens           ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log             ENABLE ROW LEVEL SECURITY;

-- 2) Views ikut RLS pemanggil (PG15). Tanpa ini, view jalan sebagai owner → bypass RLS untuk anon.
ALTER VIEW account_balances SET (security_invoker = true);
ALTER VIEW monthly_summary  SET (security_invoker = true);

-- 3) Cabut EXECUTE function dari publik (post_document, reverse_document, dll hanya untuk backend).
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM anon, authenticated;

-- 4) Default privileges: object baru pun tidak otomatis terbuka ke anon/authenticated.
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE SELECT, INSERT, UPDATE, DELETE ON TABLES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM anon, authenticated;
