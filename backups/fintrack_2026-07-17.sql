--
-- PostgreSQL database dump
--

\restrict LcVA9j8nqAbqvctzBzRLJ13lMsdqUgA7wu6l7x9bBoyPDlI5QWwUAixttHnuuEU

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.10 (Ubuntu 17.10-1.pgdg24.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: auth; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA auth;


--
-- Name: extensions; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA extensions;


--
-- Name: graphql; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA graphql;


--
-- Name: graphql_public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA graphql_public;


--
-- Name: pgbouncer; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA pgbouncer;


--
-- Name: realtime; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA realtime;


--
-- Name: storage; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA storage;


--
-- Name: vault; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA vault;


--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA extensions;


--
-- Name: EXTENSION pg_stat_statements; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_stat_statements IS 'track planning and execution statistics of all SQL statements executed';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: supabase_vault; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS supabase_vault WITH SCHEMA vault;


--
-- Name: EXTENSION supabase_vault; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION supabase_vault IS 'Supabase Vault Extension';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: aal_level; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.aal_level AS ENUM (
    'aal1',
    'aal2',
    'aal3'
);


--
-- Name: code_challenge_method; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.code_challenge_method AS ENUM (
    's256',
    'plain'
);


--
-- Name: factor_status; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.factor_status AS ENUM (
    'unverified',
    'verified'
);


--
-- Name: factor_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.factor_type AS ENUM (
    'totp',
    'webauthn',
    'phone'
);


--
-- Name: oauth_authorization_status; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_authorization_status AS ENUM (
    'pending',
    'approved',
    'denied',
    'expired'
);


--
-- Name: oauth_client_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_client_type AS ENUM (
    'public',
    'confidential'
);


--
-- Name: oauth_registration_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_registration_type AS ENUM (
    'dynamic',
    'manual'
);


--
-- Name: oauth_response_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_response_type AS ENUM (
    'code'
);


--
-- Name: one_time_token_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.one_time_token_type AS ENUM (
    'confirmation_token',
    'reauthentication_token',
    'recovery_token',
    'email_change_token_new',
    'email_change_token_current',
    'phone_change_token'
);


--
-- Name: action; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.action AS ENUM (
    'INSERT',
    'UPDATE',
    'DELETE',
    'TRUNCATE',
    'ERROR'
);


--
-- Name: equality_op; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.equality_op AS ENUM (
    'eq',
    'neq',
    'lt',
    'lte',
    'gt',
    'gte',
    'in',
    'like',
    'ilike',
    'is',
    'match',
    'imatch',
    'isdistinct'
);


--
-- Name: user_defined_filter; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.user_defined_filter AS (
	column_name text,
	op realtime.equality_op,
	value text,
	negate boolean
);


--
-- Name: wal_column; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.wal_column AS (
	name text,
	type_name text,
	type_oid oid,
	value jsonb,
	is_pkey boolean,
	is_selectable boolean
);


--
-- Name: wal_rls; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.wal_rls AS (
	wal jsonb,
	is_rls_enabled boolean,
	subscription_ids uuid[],
	errors text[]
);


--
-- Name: buckettype; Type: TYPE; Schema: storage; Owner: -
--

CREATE TYPE storage.buckettype AS ENUM (
    'STANDARD',
    'ANALYTICS',
    'VECTOR'
);


--
-- Name: email(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.email() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email')
  )::text
$$;


--
-- Name: FUNCTION email(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.email() IS 'Deprecated. Use auth.jwt() -> ''email'' instead.';


--
-- Name: jwt(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.jwt() RETURNS jsonb
    LANGUAGE sql STABLE
    AS $$
  select 
    coalesce(
        nullif(current_setting('request.jwt.claim', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')
    )::jsonb
$$;


--
-- Name: role(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.role() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$$;


--
-- Name: FUNCTION role(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.role() IS 'Deprecated. Use auth.jwt() -> ''role'' instead.';


--
-- Name: uid(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.uid() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;


--
-- Name: FUNCTION uid(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.uid() IS 'Deprecated. Use auth.jwt() -> ''sub'' instead.';


--
-- Name: grant_pg_cron_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_cron_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (
    SELECT
    FROM pg_event_trigger_ddl_commands() AS ev
    JOIN pg_extension AS ext
    ON ev.objid = ext.oid
    WHERE ext.extname = 'pg_cron'
  )
  THEN
    grant usage on schema cron to postgres with grant option;

    alter default privileges in schema cron grant all on tables to postgres with grant option;
    alter default privileges in schema cron grant all on functions to postgres with grant option;
    alter default privileges in schema cron grant all on sequences to postgres with grant option;

    alter default privileges for user supabase_admin in schema cron grant all
        on sequences to postgres with grant option;
    alter default privileges for user supabase_admin in schema cron grant all
        on tables to postgres with grant option;
    alter default privileges for user supabase_admin in schema cron grant all
        on functions to postgres with grant option;

    grant all privileges on all tables in schema cron to postgres with grant option;
    revoke all on table cron.job from postgres;
    grant select on table cron.job to postgres with grant option;
  END IF;
END;
$$;


--
-- Name: FUNCTION grant_pg_cron_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_cron_access() IS 'Grants access to pg_cron';


--
-- Name: grant_pg_graphql_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_graphql_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $_$
begin
    if not exists (
        select 1
        from pg_event_trigger_ddl_commands() ev
        join pg_catalog.pg_extension e on ev.objid = e.oid
        where e.extname = 'pg_graphql'
    ) then
        return;
    end if;

    drop function if exists graphql_public.graphql;
    create or replace function graphql_public.graphql(
        "operationName" text default null,
        query text default null,
        variables jsonb default null,
        extensions jsonb default null
    )
        returns jsonb
        language sql
    as $$
        select graphql.resolve(
            query := query,
            variables := coalesce(variables, '{}'),
            "operationName" := "operationName",
            extensions := extensions
        );
    $$;

    -- Attach the wrapper to the extension so DROP EXTENSION cascades to it,
    -- which in turn triggers set_graphql_placeholder to reinstall the "not enabled" stub.
    alter extension pg_graphql add function graphql_public.graphql(text, text, jsonb, jsonb);

    grant usage on schema graphql to postgres, anon, authenticated, service_role;
    grant execute on function graphql.resolve to postgres, anon, authenticated, service_role;
    grant usage on schema graphql to postgres with grant option;
    grant usage on schema graphql_public to postgres with grant option;
end;
$_$;


--
-- Name: FUNCTION grant_pg_graphql_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_graphql_access() IS 'Grants access to pg_graphql';


--
-- Name: grant_pg_net_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_net_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_event_trigger_ddl_commands() AS ev
    JOIN pg_extension AS ext
    ON ev.objid = ext.oid
    WHERE ext.extname = 'pg_net'
  )
  THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_roles
      WHERE rolname = 'supabase_functions_admin'
    )
    THEN
      CREATE USER supabase_functions_admin NOINHERIT CREATEROLE LOGIN NOREPLICATION;
    END IF;

    GRANT USAGE ON SCHEMA net TO supabase_functions_admin, postgres, anon, authenticated, service_role;

    IF EXISTS (
      SELECT FROM pg_extension
      WHERE extname = 'pg_net'
      -- all versions in use on existing projects as of 2025-02-20
      -- version 0.12.0 onwards don't need these applied
      AND extversion IN ('0.2', '0.6', '0.7', '0.7.1', '0.8', '0.10.0', '0.11.0')
    ) THEN
      ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;
      ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;

      ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;
      ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;

      REVOKE ALL ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;
      REVOKE ALL ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;

      GRANT EXECUTE ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
      GRANT EXECUTE ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
    END IF;
  END IF;
END;
$$;


--
-- Name: FUNCTION grant_pg_net_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_net_access() IS 'Grants access to pg_net';


--
-- Name: pgrst_ddl_watch(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.pgrst_ddl_watch() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN SELECT * FROM pg_event_trigger_ddl_commands()
  LOOP
    IF cmd.command_tag IN (
      'CREATE SCHEMA', 'ALTER SCHEMA'
    , 'CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO', 'ALTER TABLE'
    , 'CREATE FOREIGN TABLE', 'ALTER FOREIGN TABLE'
    , 'CREATE VIEW', 'ALTER VIEW'
    , 'CREATE MATERIALIZED VIEW', 'ALTER MATERIALIZED VIEW'
    , 'CREATE FUNCTION', 'ALTER FUNCTION'
    , 'CREATE TRIGGER'
    , 'CREATE TYPE', 'ALTER TYPE'
    , 'CREATE RULE'
    , 'COMMENT'
    )
    -- don't notify in case of CREATE TEMP table or other objects created on pg_temp
    AND cmd.schema_name is distinct from 'pg_temp'
    THEN
      NOTIFY pgrst, 'reload schema';
    END IF;
  END LOOP;
END; $$;


--
-- Name: pgrst_drop_watch(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.pgrst_drop_watch() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  obj record;
BEGIN
  FOR obj IN SELECT * FROM pg_event_trigger_dropped_objects()
  LOOP
    IF obj.object_type IN (
      'schema'
    , 'table'
    , 'foreign table'
    , 'view'
    , 'materialized view'
    , 'function'
    , 'trigger'
    , 'type'
    , 'rule'
    )
    AND obj.is_temporary IS false -- no pg_temp objects
    THEN
      NOTIFY pgrst, 'reload schema';
    END IF;
  END LOOP;
END; $$;


--
-- Name: set_graphql_placeholder(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.set_graphql_placeholder() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $_$
    DECLARE
    graphql_is_dropped bool;
    BEGIN
    graphql_is_dropped = (
        SELECT ev.schema_name = 'graphql_public'
        FROM pg_event_trigger_dropped_objects() AS ev
        WHERE ev.schema_name = 'graphql_public'
    );

    IF graphql_is_dropped
    THEN
        create or replace function graphql_public.graphql(
            "operationName" text default null,
            query text default null,
            variables jsonb default null,
            extensions jsonb default null
        )
            returns jsonb
            language plpgsql
        as $$
            DECLARE
                server_version float;
            BEGIN
                server_version = (SELECT (SPLIT_PART((select version()), ' ', 2))::float);

                IF server_version >= 14 THEN
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql extension is not enabled.'
                            )
                        )
                    );
                ELSE
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql is only available on projects running Postgres 14 onwards.'
                            )
                        )
                    );
                END IF;
            END;
        $$;
    END IF;

    END;
$_$;


--
-- Name: FUNCTION set_graphql_placeholder(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.set_graphql_placeholder() IS 'Reintroduces placeholder function for graphql_public.graphql';


--
-- Name: graphql(text, text, jsonb, jsonb); Type: FUNCTION; Schema: graphql_public; Owner: -
--

CREATE FUNCTION graphql_public.graphql("operationName" text DEFAULT NULL::text, query text DEFAULT NULL::text, variables jsonb DEFAULT NULL::jsonb, extensions jsonb DEFAULT NULL::jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
            DECLARE
                server_version float;
            BEGIN
                server_version = (SELECT (SPLIT_PART((select version()), ' ', 2))::float);

                IF server_version >= 14 THEN
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql extension is not enabled.'
                            )
                        )
                    );
                ELSE
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql is only available on projects running Postgres 14 onwards.'
                            )
                        )
                    );
                END IF;
            END;
        $$;


--
-- Name: get_auth(text); Type: FUNCTION; Schema: pgbouncer; Owner: -
--

CREATE FUNCTION pgbouncer.get_auth(p_usename text) RETURNS TABLE(username text, password text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
  BEGIN
      RAISE DEBUG 'PgBouncer auth request: %', p_usename;

      RETURN QUERY
      SELECT
          rolname::text,
          CASE WHEN rolvaliduntil < now()
              THEN null
              ELSE rolpassword::text
          END
      FROM pg_authid
      WHERE rolname=$1 and rolcanlogin;
  END;
  $_$;


--
-- Name: fn_audit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_audit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: fn_audit_config(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_audit_config() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: fn_no_delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_no_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION 'DELETE dilarang pada % — gunakan REVERSE (RV)', TG_TABLE_NAME;
END;
$$;


--
-- Name: income_statement(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.income_statement(p_year integer, p_month integer) RETURNS TABLE(code character varying, account_name character varying, account_type character varying, amount bigint)
    LANGUAGE sql STABLE
    AS $$
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
$$;


--
-- Name: next_doc_seq(character varying, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.next_doc_seq(p_doc_type character varying, p_year integer, p_month integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: post_document(character varying, character varying, date, text, character varying, boolean, character varying, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.post_document(p_doc_number character varying, p_doc_type character varying, p_date date, p_description text, p_input_source character varying, p_is_reversal boolean, p_reversal_of character varying, p_lines jsonb) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: reverse_document(character varying, character varying, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reverse_document(p_doc character varying, p_rv_doc character varying, p_today date) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: trial_balance(integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trial_balance(p_year integer, p_month integer, p_type character varying DEFAULT NULL::character varying) RETURNS TABLE(code character varying, account_name character varying, account_type character varying, normal_balance character varying, total_debit bigint, total_credit bigint, balance bigint)
    LANGUAGE sql STABLE
    AS $$
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
$$;


--
-- Name: apply_rls(jsonb, integer); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.apply_rls(wal jsonb, max_record_bytes integer DEFAULT (1024 * 1024)) RETURNS SETOF realtime.wal_rls
    LANGUAGE plpgsql
    AS $$
declare
    -- Regclass of the table e.g. public.notes
    entity_ regclass = (quote_ident(wal ->> 'schema') || '.' || quote_ident(wal ->> 'table'))::regclass;

    -- I, U, D, T: insert, update ...
    action realtime.action = (
        case wal ->> 'action'
            when 'I' then 'INSERT'
            when 'U' then 'UPDATE'
            when 'D' then 'DELETE'
            else 'ERROR'
        end
    );

    -- Is row level security enabled for the table
    is_rls_enabled bool = relrowsecurity from pg_class where oid = entity_;

    subscriptions realtime.subscription[] = array_agg(subs)
        from
            realtime.subscription subs
        where
            subs.entity = entity_
            -- Filter by action early - only get subscriptions interested in this action
            -- action_filter column can be: '*' (all), 'INSERT', 'UPDATE', or 'DELETE'
            and (subs.action_filter = '*' or subs.action_filter = action::text);

    -- Subscription vars
    working_role regrole;
    working_selected_columns text[];
    claimed_role regrole;
    claims jsonb;

    subscription_id uuid;
    subscription_has_access bool;
    visible_to_subscription_ids uuid[] = '{}';

    -- structured info for wal's columns
    columns realtime.wal_column[];
    -- previous identity values for update/delete
    old_columns realtime.wal_column[];

    error_record_exceeds_max_size boolean = octet_length(wal::text) > max_record_bytes;

    -- Primary jsonb output for record
    output jsonb;

    -- Loop record for iterating unique roles (outer loop)
    role_record record;
    -- Loop record for iterating unique selected_columns within a role (inner loop)
    cols_record record;
    -- Subscription ids visible at the role level (before fanning out by selected_columns)
    visible_role_sub_ids uuid[] = '{}';

begin
    perform set_config('role', null, true);

    columns =
        array_agg(
            (
                x->>'name',
                x->>'type',
                x->>'typeoid',
                realtime.cast(
                    (x->'value') #>> '{}',
                    coalesce(
                        (x->>'typeoid')::regtype, -- null when wal2json version <= 2.4
                        (x->>'type')::regtype
                    )
                ),
                (pks ->> 'name') is not null,
                true
            )::realtime.wal_column
        )
        from
            jsonb_array_elements(wal -> 'columns') x
            left join jsonb_array_elements(wal -> 'pk') pks
                on (x ->> 'name') = (pks ->> 'name');

    old_columns =
        array_agg(
            (
                x->>'name',
                x->>'type',
                x->>'typeoid',
                realtime.cast(
                    (x->'value') #>> '{}',
                    coalesce(
                        (x->>'typeoid')::regtype, -- null when wal2json version <= 2.4
                        (x->>'type')::regtype
                    )
                ),
                (pks ->> 'name') is not null,
                true
            )::realtime.wal_column
        )
        from
            jsonb_array_elements(wal -> 'identity') x
            left join jsonb_array_elements(wal -> 'pk') pks
                on (x ->> 'name') = (pks ->> 'name');

    for role_record in
        select claims_role
        from (select distinct claims_role from unnest(subscriptions)) t
        order by claims_role::text
    loop
        working_role := role_record.claims_role;

        -- Update `is_selectable` for columns and old_columns (once per role)
        columns =
            array_agg(
                (
                    c.name,
                    c.type_name,
                    c.type_oid,
                    c.value,
                    c.is_pkey,
                    pg_catalog.has_column_privilege(working_role, entity_, c.name, 'SELECT')
                )::realtime.wal_column
            )
            from
                unnest(columns) c;

        old_columns =
                array_agg(
                    (
                        c.name,
                        c.type_name,
                        c.type_oid,
                        c.value,
                        c.is_pkey,
                        pg_catalog.has_column_privilege(working_role, entity_, c.name, 'SELECT')
                    )::realtime.wal_column
                )
                from
                    unnest(old_columns) c;

        if action <> 'DELETE' and count(1) = 0 from unnest(columns) c where c.is_pkey then
            -- Fan out 400 error per distinct selected_columns for this role
            for cols_record in
                select selected_columns
                from (select distinct selected_columns from unnest(subscriptions) s where s.claims_role = working_role) t
                order by coalesce(array_to_string(selected_columns, ','), '')
            loop
                working_selected_columns := cols_record.selected_columns;
                return next (
                    jsonb_build_object(
                        'schema', wal ->> 'schema',
                        'table', wal ->> 'table',
                        'type', action
                    ),
                    is_rls_enabled,
                    (select array_agg(s.subscription_id) from unnest(subscriptions) as s where s.claims_role = working_role and (s.selected_columns is not distinct from working_selected_columns)),
                    array['Error 400: Bad Request, no primary key']
                )::realtime.wal_rls;
            end loop;

        -- The claims role does not have SELECT permission to the primary key of entity
        elsif action <> 'DELETE' and sum(c.is_selectable::int) <> count(1) from unnest(columns) c where c.is_pkey then
            -- Fan out 401 error per distinct selected_columns for this role
            for cols_record in
                select selected_columns
                from (select distinct selected_columns from unnest(subscriptions) s where s.claims_role = working_role) t
                order by coalesce(array_to_string(selected_columns, ','), '')
            loop
                working_selected_columns := cols_record.selected_columns;
                return next (
                    jsonb_build_object(
                        'schema', wal ->> 'schema',
                        'table', wal ->> 'table',
                        'type', action
                    ),
                    is_rls_enabled,
                    (select array_agg(s.subscription_id) from unnest(subscriptions) as s where s.claims_role = working_role and (s.selected_columns is not distinct from working_selected_columns)),
                    array['Error 401: Unauthorized']
                )::realtime.wal_rls;
            end loop;

        else
            -- Create the prepared statement (once per role)
            if is_rls_enabled and action <> 'DELETE' then
                if (select 1 from pg_prepared_statements where name = 'walrus_rls_stmt' limit 1) > 0 then
                    deallocate walrus_rls_stmt;
                end if;
                execute realtime.build_prepared_statement_sql('walrus_rls_stmt', entity_, columns);
            end if;

            -- Collect all visible subscription IDs for this role (filter check + RLS check)
            visible_role_sub_ids = '{}';

            for subscription_id, claims in (
                    select
                        subs.subscription_id,
                        subs.claims
                    from
                        unnest(subscriptions) subs
                    where
                        subs.entity = entity_
                        and subs.claims_role = working_role
                        and (
                            realtime.is_visible_through_filters(columns, subs.filters)
                            or (
                              action = 'DELETE'
                              and realtime.is_visible_through_filters(old_columns, subs.filters)
                            )
                        )
            ) loop

                if not is_rls_enabled or action = 'DELETE' then
                    visible_role_sub_ids = visible_role_sub_ids || subscription_id;
                else
                    -- Check if RLS allows the role to see the record
                    perform
                        -- Trim leading and trailing quotes from working_role because set_config
                        -- doesn't recognize the role as valid if they are included
                        set_config('role', trim(both '"' from working_role::text), true),
                        set_config('request.jwt.claims', claims::text, true);

                    execute 'execute walrus_rls_stmt' into subscription_has_access;

                    -- Reset the role on every FOR..LOOP batch execution.
                    -- The first batch of 10 rows is pre-fetched using the current connection role (PG internal behaviour)
                    -- then we have to reset it again otherwise it would use the role defined in the `set_config` above
                    -- to fetch the remaining rows when rows>10, which could be a user-defined role that lacks execution grants.
                    -- The flow is:
                    --   1. run batch with conn role
                    --   2. set_config working_role
                    --   3. execute walrus
                    --   4. reset role (revert)
                    --   5. repeat
                    perform set_config('role', null, true);

                    if subscription_has_access then
                        visible_role_sub_ids = visible_role_sub_ids || subscription_id;
                    end if;
                end if;
            end loop;

            perform set_config('role', null, true);

            -- Inner loop: per distinct selected_columns for this role
            for cols_record in
                select selected_columns
                from (select distinct selected_columns from unnest(subscriptions) s where s.claims_role = working_role) t
                order by coalesce(array_to_string(selected_columns, ','), '')
            loop
                working_selected_columns := cols_record.selected_columns;

                output = jsonb_build_object(
                    'schema', wal ->> 'schema',
                    'table', wal ->> 'table',
                    'type', action,
                    'commit_timestamp', to_char(
                        ((wal ->> 'timestamp')::timestamptz at time zone 'utc'),
                        'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'
                    ),
                    'columns', (
                        select
                            jsonb_agg(
                                jsonb_build_object(
                                    'name', pa.attname,
                                    'type', pt.typname
                                )
                                order by pa.attnum asc
                            )
                        from
                            pg_attribute pa
                            join pg_type pt
                                on pa.atttypid = pt.oid
                            left join (
                                select unnest(conkey) as pkey_attnum
                                from pg_constraint
                                where conrelid = entity_ and contype = 'p'
                            ) pk on pk.pkey_attnum = pa.attnum
                        where
                            attrelid = entity_
                            and attnum > 0
                            and pg_catalog.has_column_privilege(working_role, entity_, pa.attname, 'SELECT')
                            and (working_selected_columns is null or pa.attname = any(working_selected_columns) or pk.pkey_attnum is not null)
                    )
                )
                -- Add "record" key for insert and update
                || case
                    when action in ('INSERT', 'UPDATE') then
                        jsonb_build_object(
                            'record',
                            (
                                select
                                    jsonb_object_agg(
                                        -- if unchanged toast, get column name and value from old record
                                        coalesce((c).name, (oc).name),
                                        case
                                            when (c).name is null then (oc).value
                                            else (c).value
                                        end
                                    )
                                from
                                    unnest(columns) c
                                    full outer join unnest(old_columns) oc
                                        on (c).name = (oc).name
                                where
                                    coalesce((c).is_selectable, (oc).is_selectable)
                                    and (working_selected_columns is null or coalesce((c).name, (oc).name) = any(working_selected_columns) or coalesce((c).is_pkey, (oc).is_pkey))
                                    and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                            )
                        )
                    else '{}'::jsonb
                end
                -- Add "old_record" key for update and delete
                || case
                    when action = 'UPDATE' then
                        jsonb_build_object(
                                'old_record',
                                (
                                    select jsonb_object_agg((c).name, (c).value)
                                    from unnest(old_columns) c
                                    where
                                        (c).is_selectable
                                        and (working_selected_columns is null or (c).name = any(working_selected_columns) or (c).is_pkey)
                                        and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                                )
                            )
                    when action = 'DELETE' then
                        jsonb_build_object(
                            'old_record',
                            (
                                select jsonb_object_agg((c).name, (c).value)
                                from unnest(old_columns) c
                                where
                                    (c).is_selectable
                                    and (working_selected_columns is null or (c).name = any(working_selected_columns) or (c).is_pkey)
                                    and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                                    and ( not is_rls_enabled or (c).is_pkey ) -- if RLS enabled, we can't secure deletes so filter to pkey
                            )
                        )
                    else '{}'::jsonb
                end;

                -- Filter visible_role_sub_ids to those matching the current selected_columns group
                visible_to_subscription_ids = coalesce(
                    (
                        select array_agg(s.subscription_id)
                        from unnest(subscriptions) s
                        where s.claims_role = working_role
                          and (s.selected_columns is not distinct from working_selected_columns)
                          and s.subscription_id = any(visible_role_sub_ids)
                    ),
                    '{}'::uuid[]
                );

                return next (
                    output,
                    is_rls_enabled,
                    visible_to_subscription_ids,
                    case
                        when error_record_exceeds_max_size then array['Error 413: Payload Too Large']
                        else '{}'
                    end
                )::realtime.wal_rls;
            end loop;

        end if;
    end loop;

    perform set_config('role', null, true);
end;
$$;


--
-- Name: broadcast_changes(text, text, text, text, text, record, record, text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.broadcast_changes(topic_name text, event_name text, operation text, table_name text, table_schema text, new record, old record, level text DEFAULT 'ROW'::text) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- Declare a variable to hold the JSONB representation of the row
    row_data jsonb := '{}'::jsonb;
BEGIN
    IF level = 'STATEMENT' THEN
        RAISE EXCEPTION 'function can only be triggered for each row, not for each statement';
    END IF;
    -- Check the operation type and handle accordingly
    IF operation = 'INSERT' OR operation = 'UPDATE' OR operation = 'DELETE' THEN
        row_data := jsonb_build_object('old_record', OLD, 'record', NEW, 'operation', operation, 'table', table_name, 'schema', table_schema);
        PERFORM realtime.send (row_data, event_name, topic_name);
    ELSE
        RAISE EXCEPTION 'Unexpected operation type: %', operation;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to process the row: %', SQLERRM;
END;

$$;


--
-- Name: build_prepared_statement_sql(text, regclass, realtime.wal_column[]); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.build_prepared_statement_sql(prepared_statement_name text, entity regclass, columns realtime.wal_column[]) RETURNS text
    LANGUAGE sql
    AS $$
      /*
      Builds a sql string that, if executed, creates a prepared statement to
      tests retrive a row from *entity* by its primary key columns.
      Example
          select realtime.build_prepared_statement_sql('public.notes', '{"id"}'::text[], '{"bigint"}'::text[])
      */
          select
      'prepare ' || prepared_statement_name || ' as
          select
              exists(
                  select
                      1
                  from
                      ' || entity || '
                  where
                      ' || string_agg(quote_ident(pkc.name) || '=' || quote_nullable(pkc.value #>> '{}') , ' and ') || '
              )'
          from
              unnest(columns) pkc
          where
              pkc.is_pkey
          group by
              entity
      $$;


--
-- Name: cast(text, regtype); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime."cast"(val text, type_ regtype) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE
    AS $$
declare
  res jsonb;
begin
  if type_::text = 'bytea' then
    return to_jsonb(val);
  end if;
  execute format('select to_jsonb(%L::'|| type_::text || ')', val) into res;
  return res;
end
$$;


--
-- Name: check_equality_op(realtime.equality_op, regtype, text, text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.check_equality_op(op realtime.equality_op, type_ regtype, val_1 text, val_2 text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $$
/*
Casts *val_1* and *val_2* as type *type_* and check the *op* condition for truthiness
*/
declare
    op_symbol text = (
        case
            when op = 'eq' then '='
            when op = 'neq' then '!='
            when op = 'lt' then '<'
            when op = 'lte' then '<='
            when op = 'gt' then '>'
            when op = 'gte' then '>='
            when op = 'in' then '= any'
            else 'UNKNOWN OP'
        end
    );
    res boolean;
begin
    execute format(
        'select %L::'|| type_::text || ' ' || op_symbol
        || ' ( %L::'
        || (
            case
                when op = 'in' then type_::text || '[]'
                else type_::text end
        )
        || ')', val_1, val_2) into res;
    return res;
end;
$$;


--
-- Name: check_equality_op(realtime.equality_op, regtype, text, text, boolean); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.check_equality_op(op realtime.equality_op, type_ regtype, val_1 text, val_2 text, negate boolean) RETURNS boolean
    LANGUAGE plpgsql STABLE
    AS $$
declare
    op_symbol text;
    res boolean;
begin
    -- IS DISTINCT FROM / IS NOT DISTINCT FROM: infix, both sides typed literals
    if op = 'isdistinct' then
        execute format(
            'select %L::%s %s %L::%s',
            val_1,
            type_::text,
            case when negate then 'IS NOT DISTINCT FROM' else 'IS DISTINCT FROM' end,
            val_2,
            type_::text
        ) into res;
        return res;
    end if;

    -- IS requires a keyword RHS (NULL, TRUE, FALSE, UNKNOWN), not a typed literal
    if op = 'is' then
        if val_2 not in ('null', 'true', 'false', 'unknown') then
            raise exception 'invalid value for is filter: must be null, true, false, or unknown';
        end if;
        execute format(
            'select %L::%s %s %s',
            val_1,
            type_::text,
            case when negate then 'IS NOT' else 'IS' end,
            upper(val_2)
        ) into res;
        return res;
    end if;

    op_symbol = case
        when op = 'eq'    then '='
        when op = 'neq'   then '!='
        when op = 'lt'    then '<'
        when op = 'lte'   then '<='
        when op = 'gt'    then '>'
        when op = 'gte'   then '>='
        when op = 'in'    then '= any'
        when op = 'like'   then 'LIKE'
        when op = 'ilike'  then 'ILIKE'
        when op = 'match'  then '~'
        when op = 'imatch' then '~*'
        else null
    end;

    if op_symbol is null then
        raise exception 'unsupported equality operator: %', op::text;
    end if;

    execute format(
        'select %L::%s %s (%L::%s)',
        val_1,
        type_::text,
        op_symbol,
        val_2,
        case when op = 'in' then type_::text || '[]' else type_::text end
    ) into res;

    return case when negate then not res else res end;
end;
$$;


--
-- Name: is_visible_through_filters(realtime.wal_column[], realtime.user_defined_filter[]); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.is_visible_through_filters(columns realtime.wal_column[], filters realtime.user_defined_filter[]) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
    select
        filters is null
        or array_length(filters, 1) is null
        or coalesce(
            count(col.name) = count(1)
            and sum(
                realtime.check_equality_op(
                    op:=f.op,
                    type_:=coalesce(col.type_oid::regtype, col.type_name::regtype),
                    val_1:=col.value #>> '{}',
                    val_2:=f.value,
                    negate:=coalesce(f.negate, false)
                )::int
            ) filter (where col.name is not null) = count(col.name),
            false
        )
    from
        unnest(filters) f
        left join unnest(columns) col
            on f.column_name = col.name;
$$;


--
-- Name: list_changes(name, name, integer, integer); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.list_changes(publication name, slot_name name, max_changes integer, max_record_bytes integer) RETURNS TABLE(wal jsonb, is_rls_enabled boolean, subscription_ids uuid[], errors text[], slot_changes_count bigint)
    LANGUAGE sql
    SET log_min_messages TO 'fatal'
    AS $$
  WITH pub AS (
    SELECT
      concat_ws(
        ',',
        CASE WHEN bool_or(pubinsert) THEN 'insert' ELSE NULL END,
        CASE WHEN bool_or(pubupdate) THEN 'update' ELSE NULL END,
        CASE WHEN bool_or(pubdelete) THEN 'delete' ELSE NULL END
      ) AS w2j_actions,
      coalesce(
        string_agg(
          realtime.quote_wal2json(format('%I.%I', schemaname, tablename)::regclass),
          ','
        ) filter (WHERE ppt.tablename IS NOT NULL),
        ''
      ) AS w2j_add_tables
    FROM pg_publication pp
    LEFT JOIN pg_publication_tables ppt ON pp.pubname = ppt.pubname
    WHERE pp.pubname = publication
    GROUP BY pp.pubname
    LIMIT 1
  ),
  -- MATERIALIZED ensures pg_logical_slot_get_changes is called exactly once
  w2j AS MATERIALIZED (
    SELECT x.*, pub.w2j_add_tables
    FROM pub,
         pg_logical_slot_get_changes(
           slot_name, null, max_changes,
           'include-pk', 'true',
           'include-transaction', 'false',
           'include-timestamp', 'true',
           'include-type-oids', 'true',
           'format-version', '2',
           'actions', pub.w2j_actions,
           'add-tables', pub.w2j_add_tables
         ) x
  ),
  slot_count AS (
    SELECT count(*)::bigint AS cnt
    FROM w2j
    WHERE w2j.w2j_add_tables <> ''
  ),
  rls_filtered AS (
    SELECT xyz.wal, xyz.is_rls_enabled, xyz.subscription_ids, xyz.errors
    FROM w2j,
         realtime.apply_rls(
           wal := w2j.data::jsonb,
           max_record_bytes := max_record_bytes
         ) xyz(wal, is_rls_enabled, subscription_ids, errors)
    WHERE w2j.w2j_add_tables <> ''
      AND xyz.subscription_ids[1] IS NOT NULL
  )
  SELECT rf.wal, rf.is_rls_enabled, rf.subscription_ids, rf.errors, sc.cnt
  FROM rls_filtered rf, slot_count sc

  UNION ALL

  SELECT null, null, null, null, sc.cnt
  FROM slot_count sc
  WHERE NOT EXISTS (SELECT 1 FROM rls_filtered)
$$;


--
-- Name: quote_wal2json(regclass); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.quote_wal2json(entity regclass) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
  SELECT
    realtime.wal2json_escape_identifier(nsp.nspname::text)
    || '.'
    || realtime.wal2json_escape_identifier(pc.relname::text)
  FROM pg_class pc
  JOIN pg_namespace nsp ON pc.relnamespace = nsp.oid
  WHERE pc.oid = entity
$$;


--
-- Name: send(jsonb, text, text, boolean); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.send(payload jsonb, event text, topic text, private boolean DEFAULT true) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  generated_id uuid;
  final_payload jsonb;
BEGIN
  BEGIN
    generated_id := gen_random_uuid();

    -- Check if payload has an 'id' key, if not, add the generated UUID
    IF payload ? 'id' THEN
      final_payload := payload;
    ELSE
      final_payload := jsonb_set(payload, '{id}', to_jsonb(generated_id));
    END IF;

    -- Set the topic configuration
    EXECUTE format('SET LOCAL realtime.topic TO %L', topic);

    INSERT INTO realtime.messages (id, payload, event, topic, private, extension)
    VALUES (generated_id, final_payload, event, topic, private, 'broadcast');
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING 'WarnSendingBroadcastMessage: %', SQLERRM;
  END;
END;
$$;


--
-- Name: send_binary(bytea, text, text, boolean); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.send_binary(payload bytea, event text, topic text, private boolean DEFAULT true) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  generated_id uuid;
BEGIN
  BEGIN
    generated_id := gen_random_uuid();

    EXECUTE format('SET LOCAL realtime.topic TO %L', topic);

    INSERT INTO realtime.messages (id, binary_payload, event, topic, private, extension)
    VALUES (generated_id, payload, event, topic, private, 'broadcast');
  EXCEPTION
    WHEN OTHERS THEN
      RAISE WARNING 'WarnSendingBroadcastMessage: %', SQLERRM;
  END;
END;
$$;


--
-- Name: subscription_check_filters(); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.subscription_check_filters() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
    col_names text[] = coalesce(
            array_agg(a.attname order by a.attnum),
            '{}'::text[]
        )
        from
            pg_catalog.pg_attribute a
        where
            a.attrelid = new.entity
            and a.attnum > 0
            and not a.attisdropped
            and pg_catalog.has_column_privilege(
                (new.claims ->> 'role'),
                a.attrelid,
                a.attnum,
                'SELECT'
            );
    filter realtime.user_defined_filter;
    col_type regtype;
    in_val jsonb;
    selected_col text;
begin
    for filter in select * from unnest(new.filters) loop
        if not filter.column_name = any(col_names) then
            raise exception 'invalid column for filter %', filter.column_name;
        end if;

        col_type = (
            select atttypid::regtype
            from pg_catalog.pg_attribute
            where attrelid = new.entity
                  and attname = filter.column_name
        );
        if col_type is null then
            raise exception 'failed to lookup type for column %', filter.column_name;
        end if;

        if filter.op = 'in'::realtime.equality_op then
            in_val = realtime.cast(filter.value, (col_type::text || '[]')::regtype);
            if coalesce(jsonb_array_length(in_val), 0) > 100 then
                raise exception 'too many values for `in` filter. Maximum 100';
            end if;
        elsif filter.op = 'is'::realtime.equality_op then
            -- `is` requires a keyword RHS rather than a typed literal
            if filter.value not in ('null', 'true', 'false', 'unknown') then
                raise exception 'invalid value for is filter: must be null, true, false, or unknown';
            end if;
            -- IS NULL works for any type, but IS TRUE/FALSE/UNKNOWN require a boolean
            -- operand. Reject the non-null keywords on non-boolean columns here so they
            -- don't abort apply_rls at WAL time.
            if filter.value <> 'null' and col_type <> 'boolean'::regtype then
                raise exception 'is % filter requires a boolean column, got %', filter.value, col_type::text;
            end if;
        elsif filter.op in ('like'::realtime.equality_op, 'ilike'::realtime.equality_op) then
            -- like/ilike apply the text pattern operator (~~); reject column types that
            -- have no such operator instead of failing at WAL time
            if not exists (
                select 1 from pg_catalog.pg_operator
                where oprname = '~~' and oprleft = col_type
            ) then
                raise exception 'operator % requires a text-compatible column type, got %', filter.op::text, col_type::text;
            end if;
        elsif filter.op in ('match'::realtime.equality_op, 'imatch'::realtime.equality_op) then
            -- match/imatch apply the regex operators ~ / ~*; reject column types that have
            -- no such operator (e.g. integer) instead of failing at WAL time, mirroring the
            -- like/ilike guard above.
            if not exists (
                select 1 from pg_catalog.pg_operator
                where oprname = case when filter.op = 'imatch'::realtime.equality_op then '~*' else '~' end
                  and oprleft = col_type
                  and oprright = col_type
                  and oprresult = 'boolean'::regtype
            ) then
                raise exception 'operator % requires a text-compatible column type, got %', filter.op::text, col_type::text;
            end if;
            -- validate the regex eagerly so a bad pattern is rejected here, not inside
            -- apply_rls where it would abort the WAL stream for the entity
            begin
                perform '' ~ filter.value;
            exception when others then
                raise exception 'invalid regular expression for % filter: %', filter.op::text, sqlerrm;
            end;
        else
            -- eq/neq/lt/lte/gt/gte: value must be coercable to the type
            perform realtime.cast(filter.value, col_type);
        end if;
    end loop;

    if new.selected_columns is not null then
        for selected_col in select * from unnest(new.selected_columns) loop
            if not selected_col = any(col_names) then
                raise exception 'invalid column for select %', selected_col;
            end if;
        end loop;
    end if;

    -- Apply consistent order to filters so the unique constraint can't be tricked by a
    -- different filter order. negate is part of the sort key.
    new.filters = coalesce(
        array_agg(f order by f.column_name, f.op, f.value, f.negate),
        '{}'
    ) from unnest(new.filters) f;

    new.selected_columns = (
        select array_agg(c order by c)
        from unnest(new.selected_columns) c
    );

    return new;
end;
$$;


--
-- Name: to_regrole(text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.to_regrole(role_name text) RETURNS regrole
    LANGUAGE sql IMMUTABLE
    AS $$ select role_name::regrole $$;


--
-- Name: topic(); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.topic() RETURNS text
    LANGUAGE sql STABLE
    AS $$
select nullif(current_setting('realtime.topic', true), '')::text;
$$;


--
-- Name: wal2json_escape_identifier(text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.wal2json_escape_identifier(name text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
  -- Prefix `\`, `,`, `.`, and any whitespace with `\`
  SELECT regexp_replace(name, '([\\,.[:space:]])', '\\\1', 'g')
$$;


--
-- Name: allow_any_operation(text[]); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.allow_any_operation(expected_operations text[]) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  WITH current_operation AS (
    SELECT storage.operation() AS raw_operation
  ),
  normalized AS (
    SELECT CASE
      WHEN raw_operation LIKE 'storage.%' THEN substr(raw_operation, 9)
      ELSE raw_operation
    END AS current_operation
    FROM current_operation
  )
  SELECT EXISTS (
    SELECT 1
    FROM normalized n
    CROSS JOIN LATERAL unnest(expected_operations) AS expected_operation
    WHERE expected_operation IS NOT NULL
      AND expected_operation <> ''
      AND n.current_operation = CASE
        WHEN expected_operation LIKE 'storage.%' THEN substr(expected_operation, 9)
        ELSE expected_operation
      END
  );
$$;


--
-- Name: allow_only_operation(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.allow_only_operation(expected_operation text) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  WITH current_operation AS (
    SELECT storage.operation() AS raw_operation
  ),
  normalized AS (
    SELECT
      CASE
        WHEN raw_operation LIKE 'storage.%' THEN substr(raw_operation, 9)
        ELSE raw_operation
      END AS current_operation,
      CASE
        WHEN expected_operation LIKE 'storage.%' THEN substr(expected_operation, 9)
        ELSE expected_operation
      END AS requested_operation
    FROM current_operation
  )
  SELECT CASE
    WHEN requested_operation IS NULL OR requested_operation = '' THEN FALSE
    ELSE COALESCE(current_operation = requested_operation, FALSE)
  END
  FROM normalized;
$$;


--
-- Name: can_insert_object(text, text, uuid, jsonb); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.can_insert_object(bucketid text, name text, owner uuid, metadata jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO "storage"."objects" ("bucket_id", "name", "owner", "metadata") VALUES (bucketid, name, owner, metadata);
  -- hack to rollback the successful insert
  RAISE sqlstate 'PT200' using
  message = 'ROLLBACK',
  detail = 'rollback successful insert';
END
$$;


--
-- Name: enforce_bucket_name_length(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.enforce_bucket_name_length() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    if length(new.name) > 100 then
        raise exception 'bucket name "%" is too long (% characters). Max is 100.', new.name, length(new.name);
    end if;
    return new;
end;
$$;


--
-- Name: extension(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.extension(name text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    _parts text[];
    _filename text;
BEGIN
    -- Split on "/" to get path segments
    SELECT string_to_array(name, '/') INTO _parts;
    -- Get the last path segment (the actual filename)
    SELECT _parts[array_length(_parts, 1)] INTO _filename;
    -- Extract extension: reverse, split on '.', then reverse again
    RETURN reverse(split_part(reverse(_filename), '.', 1));
END
$$;


--
-- Name: filename(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.filename(name text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
_parts text[];
BEGIN
	select string_to_array(name, '/') into _parts;
	return _parts[array_length(_parts,1)];
END
$$;


--
-- Name: foldername(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.foldername(name text) RETURNS text[]
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    _parts text[];
BEGIN
    -- Split on "/" to get path segments
    SELECT string_to_array(name, '/') INTO _parts;
    -- Return everything except the last segment
    RETURN _parts[1 : array_length(_parts,1) - 1];
END
$$;


--
-- Name: get_common_prefix(text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_common_prefix(p_key text, p_prefix text, p_delimiter text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
SELECT CASE
    WHEN position(p_delimiter IN substring(p_key FROM length(p_prefix) + 1)) > 0
    THEN left(p_key, length(p_prefix) + position(p_delimiter IN substring(p_key FROM length(p_prefix) + 1)))
    ELSE NULL
END;
$$;


--
-- Name: get_size_by_bucket(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_size_by_bucket() RETURNS TABLE(size bigint, bucket_id text)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    return query
        select sum((metadata->>'size')::bigint)::bigint as size, obj.bucket_id
        from "storage".objects as obj
        group by obj.bucket_id;
END
$$;


--
-- Name: list_multipart_uploads_with_delimiter(text, text, text, integer, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.list_multipart_uploads_with_delimiter(bucket_id text, prefix_param text, delimiter_param text, max_keys integer DEFAULT 100, next_key_token text DEFAULT ''::text, next_upload_token text DEFAULT ''::text) RETURNS TABLE(key text, id text, created_at timestamp with time zone)
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT DISTINCT ON(key COLLATE "C") * from (
            SELECT
                CASE
                    WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                        substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1)))
                    ELSE
                        key
                END AS key, id, created_at
            FROM
                storage.s3_multipart_uploads
            WHERE
                bucket_id = $5 AND
                key ILIKE $1 || ''%'' AND
                CASE
                    WHEN $4 != '''' AND $6 = '''' THEN
                        CASE
                            WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                                substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1))) COLLATE "C" > $4
                            ELSE
                                key COLLATE "C" > $4
                            END
                    ELSE
                        true
                END AND
                CASE
                    WHEN $6 != '''' THEN
                        id COLLATE "C" > $6
                    ELSE
                        true
                    END
            ORDER BY
                key COLLATE "C" ASC, created_at ASC) as e order by key COLLATE "C" LIMIT $3'
        USING prefix_param, delimiter_param, max_keys, next_key_token, bucket_id, next_upload_token;
END;
$_$;


--
-- Name: list_objects_with_delimiter(text, text, text, integer, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.list_objects_with_delimiter(_bucket_id text, prefix_param text, delimiter_param text, max_keys integer DEFAULT 100, start_after text DEFAULT ''::text, next_token text DEFAULT ''::text, sort_order text DEFAULT 'asc'::text) RETURNS TABLE(name text, id uuid, metadata jsonb, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone)
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    v_peek_name TEXT;
    v_current RECORD;
    v_common_prefix TEXT;

    -- Configuration
    v_is_asc BOOLEAN;
    v_prefix TEXT;
    v_start TEXT;
    v_upper_bound TEXT;
    v_file_batch_size INT;

    -- Seek state
    v_next_seek TEXT;
    v_count INT := 0;

    -- Dynamic SQL for batch query only
    v_batch_query TEXT;

BEGIN
    -- ========================================================================
    -- INITIALIZATION
    -- ========================================================================
    v_is_asc := lower(coalesce(sort_order, 'asc')) = 'asc';
    v_prefix := coalesce(prefix_param, '');
    v_start := CASE WHEN coalesce(next_token, '') <> '' THEN next_token ELSE coalesce(start_after, '') END;
    v_file_batch_size := LEAST(GREATEST(max_keys * 2, 100), 1000);

    -- Calculate upper bound for prefix filtering (bytewise, using COLLATE "C")
    IF v_prefix = '' THEN
        v_upper_bound := NULL;
    ELSIF right(v_prefix, 1) = delimiter_param THEN
        v_upper_bound := left(v_prefix, -1) || chr(ascii(delimiter_param) + 1);
    ELSE
        v_upper_bound := left(v_prefix, -1) || chr(ascii(right(v_prefix, 1)) + 1);
    END IF;

    -- Build batch query (dynamic SQL - called infrequently, amortized over many rows)
    IF v_is_asc THEN
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" >= $2 ' ||
                'AND o.name COLLATE "C" < $3 ORDER BY o.name COLLATE "C" ASC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" >= $2 ' ||
                'ORDER BY o.name COLLATE "C" ASC LIMIT $4';
        END IF;
    ELSE
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" < $2 ' ||
                'AND o.name COLLATE "C" >= $3 ORDER BY o.name COLLATE "C" DESC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" < $2 ' ||
                'ORDER BY o.name COLLATE "C" DESC LIMIT $4';
        END IF;
    END IF;

    -- ========================================================================
    -- SEEK INITIALIZATION: Determine starting position
    -- ========================================================================
    IF v_start = '' THEN
        IF v_is_asc THEN
            v_next_seek := v_prefix;
        ELSE
            -- DESC without cursor: find the last item in range
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_prefix AND o.name COLLATE "C" < v_upper_bound
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix <> '' THEN
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            END IF;

            IF v_next_seek IS NOT NULL THEN
                v_next_seek := v_next_seek || delimiter_param;
            ELSE
                RETURN;
            END IF;
        END IF;
    ELSE
        -- Cursor provided: determine if it refers to a folder or leaf
        IF EXISTS (
            SELECT 1 FROM storage.objects o
            WHERE o.bucket_id = _bucket_id
              AND o.name COLLATE "C" LIKE v_start || delimiter_param || '%'
            LIMIT 1
        ) THEN
            -- Cursor refers to a folder
            IF v_is_asc THEN
                v_next_seek := v_start || chr(ascii(delimiter_param) + 1);
            ELSE
                v_next_seek := v_start || delimiter_param;
            END IF;
        ELSE
            -- Cursor refers to a leaf object
            IF v_is_asc THEN
                v_next_seek := v_start || delimiter_param;
            ELSE
                v_next_seek := v_start;
            END IF;
        END IF;
    END IF;

    -- ========================================================================
    -- MAIN LOOP: Hybrid peek-then-batch algorithm
    -- Uses STATIC SQL for peek (hot path) and DYNAMIC SQL for batch
    -- ========================================================================
    LOOP
        EXIT WHEN v_count >= max_keys;

        -- STEP 1: PEEK using STATIC SQL (plan cached, very fast)
        IF v_is_asc THEN
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_next_seek AND o.name COLLATE "C" < v_upper_bound
                ORDER BY o.name COLLATE "C" ASC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_next_seek
                ORDER BY o.name COLLATE "C" ASC LIMIT 1;
            END IF;
        ELSE
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix <> '' THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            END IF;
        END IF;

        EXIT WHEN v_peek_name IS NULL;

        -- STEP 2: Check if this is a FOLDER or FILE
        v_common_prefix := storage.get_common_prefix(v_peek_name, v_prefix, delimiter_param);

        IF v_common_prefix IS NOT NULL THEN
            -- FOLDER: Emit and skip to next folder (no heap access needed)
            name := rtrim(v_common_prefix, delimiter_param);
            id := NULL;
            updated_at := NULL;
            created_at := NULL;
            last_accessed_at := NULL;
            metadata := NULL;
            RETURN NEXT;
            v_count := v_count + 1;

            -- Advance seek past the folder range
            IF v_is_asc THEN
                v_next_seek := left(v_common_prefix, -1) || chr(ascii(delimiter_param) + 1);
            ELSE
                v_next_seek := v_common_prefix;
            END IF;
        ELSE
            -- FILE: Batch fetch using DYNAMIC SQL (overhead amortized over many rows)
            -- For ASC: upper_bound is the exclusive upper limit (< condition)
            -- For DESC: prefix is the inclusive lower limit (>= condition)
            FOR v_current IN EXECUTE v_batch_query USING _bucket_id, v_next_seek,
                CASE WHEN v_is_asc THEN COALESCE(v_upper_bound, v_prefix) ELSE v_prefix END, v_file_batch_size
            LOOP
                v_common_prefix := storage.get_common_prefix(v_current.name, v_prefix, delimiter_param);

                IF v_common_prefix IS NOT NULL THEN
                    -- Hit a folder: exit batch, let peek handle it
                    v_next_seek := v_current.name;
                    EXIT;
                END IF;

                -- Emit file
                name := v_current.name;
                id := v_current.id;
                updated_at := v_current.updated_at;
                created_at := v_current.created_at;
                last_accessed_at := v_current.last_accessed_at;
                metadata := v_current.metadata;
                RETURN NEXT;
                v_count := v_count + 1;

                -- Advance seek past this file
                IF v_is_asc THEN
                    v_next_seek := v_current.name || delimiter_param;
                ELSE
                    v_next_seek := v_current.name;
                END IF;

                EXIT WHEN v_count >= max_keys;
            END LOOP;
        END IF;
    END LOOP;
END;
$_$;


--
-- Name: operation(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.operation() RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN current_setting('storage.operation', true);
END;
$$;


--
-- Name: protect_delete(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.protect_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check if storage.allow_delete_query is set to 'true'
    IF COALESCE(current_setting('storage.allow_delete_query', true), 'false') != 'true' THEN
        RAISE EXCEPTION 'Direct deletion from storage tables is not allowed. Use the Storage API instead.'
            USING HINT = 'This prevents accidental data loss from orphaned objects.',
                  ERRCODE = '42501';
    END IF;
    RETURN NULL;
END;
$$;


--
-- Name: search(text, text, integer, integer, integer, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search(prefix text, bucketname text, limits integer DEFAULT 100, levels integer DEFAULT 1, offsets integer DEFAULT 0, search text DEFAULT ''::text, sortcolumn text DEFAULT 'name'::text, sortorder text DEFAULT 'asc'::text) RETURNS TABLE(name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    v_peek_name TEXT;
    v_current RECORD;
    v_common_prefix TEXT;
    v_delimiter CONSTANT TEXT := '/';

    -- Configuration
    v_limit INT;
    v_prefix TEXT;
    v_prefix_lower TEXT;
    v_is_asc BOOLEAN;
    v_order_by TEXT;
    v_sort_order TEXT;
    v_upper_bound TEXT;
    v_file_batch_size INT;

    -- Dynamic SQL for batch query only
    v_batch_query TEXT;

    -- Seek state
    v_next_seek TEXT;
    v_count INT := 0;
    v_skipped INT := 0;
BEGIN
    -- ========================================================================
    -- INITIALIZATION
    -- ========================================================================
    v_limit := LEAST(coalesce(limits, 100), 1500);
    v_prefix := coalesce(prefix, '') || coalesce(search, '');
    v_prefix_lower := lower(v_prefix);
    v_is_asc := lower(coalesce(sortorder, 'asc')) = 'asc';
    v_file_batch_size := LEAST(GREATEST(v_limit * 2, 100), 1000);

    -- Validate sort column
    CASE lower(coalesce(sortcolumn, 'name'))
        WHEN 'name' THEN v_order_by := 'name';
        WHEN 'updated_at' THEN v_order_by := 'updated_at';
        WHEN 'created_at' THEN v_order_by := 'created_at';
        WHEN 'last_accessed_at' THEN v_order_by := 'last_accessed_at';
        ELSE v_order_by := 'name';
    END CASE;

    v_sort_order := CASE WHEN v_is_asc THEN 'asc' ELSE 'desc' END;

    -- ========================================================================
    -- NON-NAME SORTING: Use path_tokens approach (unchanged)
    -- ========================================================================
    IF v_order_by != 'name' THEN
        RETURN QUERY EXECUTE format(
            $sql$
            WITH folders AS (
                SELECT path_tokens[$1] AS folder
                FROM storage.objects
                WHERE objects.name ILIKE $2 || '%%'
                  AND bucket_id = $3
                  AND array_length(objects.path_tokens, 1) <> $1
                GROUP BY folder
                ORDER BY folder %s
            )
            (SELECT folder AS "name",
                   NULL::uuid AS id,
                   NULL::timestamptz AS updated_at,
                   NULL::timestamptz AS created_at,
                   NULL::timestamptz AS last_accessed_at,
                   NULL::jsonb AS metadata FROM folders)
            UNION ALL
            (SELECT path_tokens[$1] AS "name",
                   id, updated_at, created_at, last_accessed_at, metadata
             FROM storage.objects
             WHERE objects.name ILIKE $2 || '%%'
               AND bucket_id = $3
               AND array_length(objects.path_tokens, 1) = $1
             ORDER BY %I %s)
            LIMIT $4 OFFSET $5
            $sql$, v_sort_order, v_order_by, v_sort_order
        ) USING levels, v_prefix, bucketname, v_limit, offsets;
        RETURN;
    END IF;

    -- ========================================================================
    -- NAME SORTING: Hybrid skip-scan with batch optimization
    -- ========================================================================

    -- Calculate upper bound for prefix filtering
    IF v_prefix_lower = '' THEN
        v_upper_bound := NULL;
    ELSIF right(v_prefix_lower, 1) = v_delimiter THEN
        v_upper_bound := left(v_prefix_lower, -1) || chr(ascii(v_delimiter) + 1);
    ELSE
        v_upper_bound := left(v_prefix_lower, -1) || chr(ascii(right(v_prefix_lower, 1)) + 1);
    END IF;

    -- Build batch query (dynamic SQL - called infrequently, amortized over many rows)
    IF v_is_asc THEN
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" >= $2 ' ||
                'AND lower(o.name) COLLATE "C" < $3 ORDER BY lower(o.name) COLLATE "C" ASC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" >= $2 ' ||
                'ORDER BY lower(o.name) COLLATE "C" ASC LIMIT $4';
        END IF;
    ELSE
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" < $2 ' ||
                'AND lower(o.name) COLLATE "C" >= $3 ORDER BY lower(o.name) COLLATE "C" DESC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" < $2 ' ||
                'ORDER BY lower(o.name) COLLATE "C" DESC LIMIT $4';
        END IF;
    END IF;

    -- Initialize seek position
    IF v_is_asc THEN
        v_next_seek := v_prefix_lower;
    ELSE
        -- DESC: find the last item in range first (static SQL)
        IF v_upper_bound IS NOT NULL THEN
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_prefix_lower AND lower(o.name) COLLATE "C" < v_upper_bound
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        ELSIF v_prefix_lower <> '' THEN
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_prefix_lower
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        ELSE
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        END IF;

        IF v_peek_name IS NOT NULL THEN
            v_next_seek := lower(v_peek_name) || v_delimiter;
        ELSE
            RETURN;
        END IF;
    END IF;

    -- ========================================================================
    -- MAIN LOOP: Hybrid peek-then-batch algorithm
    -- Uses STATIC SQL for peek (hot path) and DYNAMIC SQL for batch
    -- ========================================================================
    LOOP
        EXIT WHEN v_count >= v_limit;

        -- STEP 1: PEEK using STATIC SQL (plan cached, very fast)
        IF v_is_asc THEN
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_next_seek AND lower(o.name) COLLATE "C" < v_upper_bound
                ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_next_seek
                ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1;
            END IF;
        ELSE
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek AND lower(o.name) COLLATE "C" >= v_prefix_lower
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix_lower <> '' THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek AND lower(o.name) COLLATE "C" >= v_prefix_lower
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            END IF;
        END IF;

        EXIT WHEN v_peek_name IS NULL;

        -- STEP 2: Check if this is a FOLDER or FILE
        v_common_prefix := storage.get_common_prefix(lower(v_peek_name), v_prefix_lower, v_delimiter);

        IF v_common_prefix IS NOT NULL THEN
            -- FOLDER: Handle offset, emit if needed, skip to next folder
            IF v_skipped < offsets THEN
                v_skipped := v_skipped + 1;
            ELSE
                name := split_part(rtrim(storage.get_common_prefix(v_peek_name, v_prefix, v_delimiter), v_delimiter), v_delimiter, levels);
                id := NULL;
                updated_at := NULL;
                created_at := NULL;
                last_accessed_at := NULL;
                metadata := NULL;
                RETURN NEXT;
                v_count := v_count + 1;
            END IF;

            -- Advance seek past the folder range
            IF v_is_asc THEN
                v_next_seek := lower(left(v_common_prefix, -1)) || chr(ascii(v_delimiter) + 1);
            ELSE
                v_next_seek := lower(v_common_prefix);
            END IF;
        ELSE
            -- FILE: Batch fetch using DYNAMIC SQL (overhead amortized over many rows)
            -- For ASC: upper_bound is the exclusive upper limit (< condition)
            -- For DESC: prefix_lower is the inclusive lower limit (>= condition)
            FOR v_current IN EXECUTE v_batch_query
                USING bucketname, v_next_seek,
                    CASE WHEN v_is_asc THEN COALESCE(v_upper_bound, v_prefix_lower) ELSE v_prefix_lower END, v_file_batch_size
            LOOP
                v_common_prefix := storage.get_common_prefix(lower(v_current.name), v_prefix_lower, v_delimiter);

                IF v_common_prefix IS NOT NULL THEN
                    -- Hit a folder: exit batch, let peek handle it
                    v_next_seek := lower(v_current.name);
                    EXIT;
                END IF;

                -- Handle offset skipping
                IF v_skipped < offsets THEN
                    v_skipped := v_skipped + 1;
                ELSE
                    -- Emit file
                    name := split_part(v_current.name, v_delimiter, levels);
                    id := v_current.id;
                    updated_at := v_current.updated_at;
                    created_at := v_current.created_at;
                    last_accessed_at := v_current.last_accessed_at;
                    metadata := v_current.metadata;
                    RETURN NEXT;
                    v_count := v_count + 1;
                END IF;

                -- Advance seek past this file
                IF v_is_asc THEN
                    v_next_seek := lower(v_current.name) || v_delimiter;
                ELSE
                    v_next_seek := lower(v_current.name);
                END IF;

                EXIT WHEN v_count >= v_limit;
            END LOOP;
        END IF;
    END LOOP;
END;
$_$;


--
-- Name: search_by_timestamp(text, text, integer, integer, text, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search_by_timestamp(p_prefix text, p_bucket_id text, p_limit integer, p_level integer, p_start_after text, p_sort_order text, p_sort_column text, p_sort_column_after text) RETURNS TABLE(key text, name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    v_cursor_op text;
    v_query text;
    v_prefix text;
BEGIN
    v_prefix := coalesce(p_prefix, '');

    IF p_sort_order = 'asc' THEN
        v_cursor_op := '>';
    ELSE
        v_cursor_op := '<';
    END IF;

    v_query := format($sql$
        WITH raw_objects AS (
            SELECT
                o.name AS obj_name,
                o.id AS obj_id,
                o.updated_at AS obj_updated_at,
                o.created_at AS obj_created_at,
                o.last_accessed_at AS obj_last_accessed_at,
                o.metadata AS obj_metadata,
                storage.get_common_prefix(o.name, $1, '/') AS common_prefix
            FROM storage.objects o
            WHERE o.bucket_id = $2
              AND o.name COLLATE "C" LIKE $1 || '%%'
        ),
        -- Aggregate common prefixes (folders)
        -- Both created_at and updated_at use MIN(obj_created_at) to match the old prefixes table behavior
        aggregated_prefixes AS (
            SELECT
                rtrim(common_prefix, '/') AS name,
                NULL::uuid AS id,
                MIN(obj_created_at) AS updated_at,
                MIN(obj_created_at) AS created_at,
                NULL::timestamptz AS last_accessed_at,
                NULL::jsonb AS metadata,
                TRUE AS is_prefix
            FROM raw_objects
            WHERE common_prefix IS NOT NULL
            GROUP BY common_prefix
        ),
        leaf_objects AS (
            SELECT
                obj_name AS name,
                obj_id AS id,
                obj_updated_at AS updated_at,
                obj_created_at AS created_at,
                obj_last_accessed_at AS last_accessed_at,
                obj_metadata AS metadata,
                FALSE AS is_prefix
            FROM raw_objects
            WHERE common_prefix IS NULL
        ),
        combined AS (
            SELECT * FROM aggregated_prefixes
            UNION ALL
            SELECT * FROM leaf_objects
        ),
        filtered AS (
            SELECT *
            FROM combined
            WHERE (
                $5 = ''
                OR ROW(
                    date_trunc('milliseconds', %I),
                    name COLLATE "C"
                ) %s ROW(
                    COALESCE(NULLIF($6, '')::timestamptz, 'epoch'::timestamptz),
                    $5
                )
            )
        )
        SELECT
            split_part(name, '/', $3) AS key,
            name,
            id,
            updated_at,
            created_at,
            last_accessed_at,
            metadata
        FROM filtered
        ORDER BY
            COALESCE(date_trunc('milliseconds', %I), 'epoch'::timestamptz) %s,
            name COLLATE "C" %s
        LIMIT $4
    $sql$,
        p_sort_column,
        v_cursor_op,
        p_sort_column,
        p_sort_order,
        p_sort_order
    );

    RETURN QUERY EXECUTE v_query
    USING v_prefix, p_bucket_id, p_level, p_limit, p_start_after, p_sort_column_after;
END;
$_$;


--
-- Name: search_v2(text, text, integer, integer, text, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search_v2(prefix text, bucket_name text, limits integer DEFAULT 100, levels integer DEFAULT 1, start_after text DEFAULT ''::text, sort_order text DEFAULT 'asc'::text, sort_column text DEFAULT 'name'::text, sort_column_after text DEFAULT ''::text) RETURNS TABLE(key text, name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_sort_col text;
    v_sort_ord text;
    v_limit int;
BEGIN
    -- Cap limit to maximum of 1500 records
    v_limit := LEAST(coalesce(limits, 100), 1500);

    -- Validate and normalize sort_order
    v_sort_ord := lower(coalesce(sort_order, 'asc'));
    IF v_sort_ord NOT IN ('asc', 'desc') THEN
        v_sort_ord := 'asc';
    END IF;

    -- Validate and normalize sort_column
    v_sort_col := lower(coalesce(sort_column, 'name'));
    IF v_sort_col NOT IN ('name', 'updated_at', 'created_at') THEN
        v_sort_col := 'name';
    END IF;

    -- Route to appropriate implementation
    IF v_sort_col = 'name' THEN
        -- Use list_objects_with_delimiter for name sorting (most efficient: O(k * log n))
        RETURN QUERY
        SELECT
            split_part(l.name, '/', levels) AS key,
            l.name AS name,
            l.id,
            l.updated_at,
            l.created_at,
            l.last_accessed_at,
            l.metadata
        FROM storage.list_objects_with_delimiter(
            bucket_name,
            coalesce(prefix, ''),
            '/',
            v_limit,
            start_after,
            '',
            v_sort_ord
        ) l;
    ELSE
        -- Use aggregation approach for timestamp sorting
        -- Not efficient for large datasets but supports correct pagination
        RETURN QUERY SELECT * FROM storage.search_by_timestamp(
            prefix, bucket_name, v_limit, levels, start_after,
            v_sort_ord, v_sort_col, sort_column_after
        );
    END IF;
END;
$$;


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW; 
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: audit_log_entries; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.audit_log_entries (
    instance_id uuid,
    id uuid NOT NULL,
    payload json,
    created_at timestamp with time zone,
    ip_address character varying(64) DEFAULT ''::character varying NOT NULL
);


--
-- Name: TABLE audit_log_entries; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.audit_log_entries IS 'Auth: Audit trail for user actions.';


--
-- Name: custom_oauth_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.custom_oauth_providers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    provider_type text NOT NULL,
    identifier text NOT NULL,
    name text NOT NULL,
    client_id text NOT NULL,
    client_secret text NOT NULL,
    acceptable_client_ids text[] DEFAULT '{}'::text[] NOT NULL,
    scopes text[] DEFAULT '{}'::text[] NOT NULL,
    pkce_enabled boolean DEFAULT true NOT NULL,
    attribute_mapping jsonb DEFAULT '{}'::jsonb NOT NULL,
    authorization_params jsonb DEFAULT '{}'::jsonb NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    email_optional boolean DEFAULT false NOT NULL,
    issuer text,
    discovery_url text,
    skip_nonce_check boolean DEFAULT false NOT NULL,
    cached_discovery jsonb,
    discovery_cached_at timestamp with time zone,
    authorization_url text,
    token_url text,
    userinfo_url text,
    jwks_uri text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    custom_claims_allowlist text[] DEFAULT '{}'::text[] NOT NULL,
    CONSTRAINT custom_oauth_providers_authorization_url_https CHECK (((authorization_url IS NULL) OR (authorization_url ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_authorization_url_length CHECK (((authorization_url IS NULL) OR (char_length(authorization_url) <= 2048))),
    CONSTRAINT custom_oauth_providers_client_id_length CHECK (((char_length(client_id) >= 1) AND (char_length(client_id) <= 512))),
    CONSTRAINT custom_oauth_providers_discovery_url_length CHECK (((discovery_url IS NULL) OR (char_length(discovery_url) <= 2048))),
    CONSTRAINT custom_oauth_providers_identifier_format CHECK ((identifier ~ '^[a-z0-9][a-z0-9:-]{0,48}[a-z0-9]$'::text)),
    CONSTRAINT custom_oauth_providers_issuer_length CHECK (((issuer IS NULL) OR ((char_length(issuer) >= 1) AND (char_length(issuer) <= 2048)))),
    CONSTRAINT custom_oauth_providers_jwks_uri_https CHECK (((jwks_uri IS NULL) OR (jwks_uri ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_jwks_uri_length CHECK (((jwks_uri IS NULL) OR (char_length(jwks_uri) <= 2048))),
    CONSTRAINT custom_oauth_providers_name_length CHECK (((char_length(name) >= 1) AND (char_length(name) <= 100))),
    CONSTRAINT custom_oauth_providers_oauth2_requires_endpoints CHECK (((provider_type <> 'oauth2'::text) OR ((authorization_url IS NOT NULL) AND (token_url IS NOT NULL) AND (userinfo_url IS NOT NULL)))),
    CONSTRAINT custom_oauth_providers_oidc_discovery_url_https CHECK (((provider_type <> 'oidc'::text) OR (discovery_url IS NULL) OR (discovery_url ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_oidc_issuer_https CHECK (((provider_type <> 'oidc'::text) OR (issuer IS NULL) OR (issuer ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_oidc_requires_issuer CHECK (((provider_type <> 'oidc'::text) OR (issuer IS NOT NULL))),
    CONSTRAINT custom_oauth_providers_provider_type_check CHECK ((provider_type = ANY (ARRAY['oauth2'::text, 'oidc'::text]))),
    CONSTRAINT custom_oauth_providers_token_url_https CHECK (((token_url IS NULL) OR (token_url ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_token_url_length CHECK (((token_url IS NULL) OR (char_length(token_url) <= 2048))),
    CONSTRAINT custom_oauth_providers_userinfo_url_https CHECK (((userinfo_url IS NULL) OR (userinfo_url ~~ 'https://%'::text))),
    CONSTRAINT custom_oauth_providers_userinfo_url_length CHECK (((userinfo_url IS NULL) OR (char_length(userinfo_url) <= 2048)))
);


--
-- Name: flow_state; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.flow_state (
    id uuid NOT NULL,
    user_id uuid,
    auth_code text,
    code_challenge_method auth.code_challenge_method,
    code_challenge text,
    provider_type text NOT NULL,
    provider_access_token text,
    provider_refresh_token text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    authentication_method text NOT NULL,
    auth_code_issued_at timestamp with time zone,
    invite_token text,
    referrer text,
    oauth_client_state_id uuid,
    linking_target_id uuid,
    email_optional boolean DEFAULT false NOT NULL
);


--
-- Name: TABLE flow_state; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.flow_state IS 'Stores metadata for all OAuth/SSO login flows';


--
-- Name: identities; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.identities (
    provider_id text NOT NULL,
    user_id uuid NOT NULL,
    identity_data jsonb NOT NULL,
    provider text NOT NULL,
    last_sign_in_at timestamp with time zone,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    email text GENERATED ALWAYS AS (lower((identity_data ->> 'email'::text))) STORED,
    id uuid DEFAULT gen_random_uuid() NOT NULL
);


--
-- Name: TABLE identities; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.identities IS 'Auth: Stores identities associated to a user.';


--
-- Name: COLUMN identities.email; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.identities.email IS 'Auth: Email is a generated column that references the optional email property in the identity_data';


--
-- Name: instances; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.instances (
    id uuid NOT NULL,
    uuid uuid,
    raw_base_config text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);


--
-- Name: TABLE instances; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.instances IS 'Auth: Manages users across multiple sites.';


--
-- Name: mfa_amr_claims; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_amr_claims (
    session_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    authentication_method text NOT NULL,
    id uuid NOT NULL
);


--
-- Name: TABLE mfa_amr_claims; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_amr_claims IS 'auth: stores authenticator method reference claims for multi factor authentication';


--
-- Name: mfa_challenges; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_challenges (
    id uuid NOT NULL,
    factor_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    verified_at timestamp with time zone,
    ip_address inet NOT NULL,
    otp_code text,
    web_authn_session_data jsonb
);


--
-- Name: TABLE mfa_challenges; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_challenges IS 'auth: stores metadata about challenge requests made';


--
-- Name: mfa_factors; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_factors (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    friendly_name text,
    factor_type auth.factor_type NOT NULL,
    status auth.factor_status NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    secret text,
    phone text,
    last_challenged_at timestamp with time zone,
    web_authn_credential jsonb,
    web_authn_aaguid uuid,
    last_webauthn_challenge_data jsonb
);


--
-- Name: TABLE mfa_factors; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_factors IS 'auth: stores metadata about factors';


--
-- Name: COLUMN mfa_factors.last_webauthn_challenge_data; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.mfa_factors.last_webauthn_challenge_data IS 'Stores the latest WebAuthn challenge data including attestation/assertion for customer verification';


--
-- Name: oauth_authorizations; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_authorizations (
    id uuid NOT NULL,
    authorization_id text NOT NULL,
    client_id uuid NOT NULL,
    user_id uuid,
    redirect_uri text NOT NULL,
    scope text NOT NULL,
    state text,
    resource text,
    code_challenge text,
    code_challenge_method auth.code_challenge_method,
    response_type auth.oauth_response_type DEFAULT 'code'::auth.oauth_response_type NOT NULL,
    status auth.oauth_authorization_status DEFAULT 'pending'::auth.oauth_authorization_status NOT NULL,
    authorization_code text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '00:03:00'::interval) NOT NULL,
    approved_at timestamp with time zone,
    nonce text,
    CONSTRAINT oauth_authorizations_authorization_code_length CHECK ((char_length(authorization_code) <= 255)),
    CONSTRAINT oauth_authorizations_code_challenge_length CHECK ((char_length(code_challenge) <= 128)),
    CONSTRAINT oauth_authorizations_expires_at_future CHECK ((expires_at > created_at)),
    CONSTRAINT oauth_authorizations_nonce_length CHECK ((char_length(nonce) <= 255)),
    CONSTRAINT oauth_authorizations_redirect_uri_length CHECK ((char_length(redirect_uri) <= 2048)),
    CONSTRAINT oauth_authorizations_resource_length CHECK ((char_length(resource) <= 2048)),
    CONSTRAINT oauth_authorizations_scope_length CHECK ((char_length(scope) <= 4096)),
    CONSTRAINT oauth_authorizations_state_length CHECK ((char_length(state) <= 4096))
);


--
-- Name: oauth_client_states; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_client_states (
    id uuid NOT NULL,
    provider_type text NOT NULL,
    code_verifier text,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: TABLE oauth_client_states; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.oauth_client_states IS 'Stores OAuth states for third-party provider authentication flows where Supabase acts as the OAuth client.';


--
-- Name: oauth_clients; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_clients (
    id uuid NOT NULL,
    client_secret_hash text,
    registration_type auth.oauth_registration_type NOT NULL,
    redirect_uris text NOT NULL,
    grant_types text NOT NULL,
    client_name text,
    client_uri text,
    logo_uri text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    client_type auth.oauth_client_type DEFAULT 'confidential'::auth.oauth_client_type NOT NULL,
    token_endpoint_auth_method text NOT NULL,
    CONSTRAINT oauth_clients_client_name_length CHECK ((char_length(client_name) <= 1024)),
    CONSTRAINT oauth_clients_client_uri_length CHECK ((char_length(client_uri) <= 2048)),
    CONSTRAINT oauth_clients_logo_uri_length CHECK ((char_length(logo_uri) <= 2048)),
    CONSTRAINT oauth_clients_token_endpoint_auth_method_check CHECK ((token_endpoint_auth_method = ANY (ARRAY['client_secret_basic'::text, 'client_secret_post'::text, 'none'::text])))
);


--
-- Name: oauth_consents; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_consents (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    client_id uuid NOT NULL,
    scopes text NOT NULL,
    granted_at timestamp with time zone DEFAULT now() NOT NULL,
    revoked_at timestamp with time zone,
    CONSTRAINT oauth_consents_revoked_after_granted CHECK (((revoked_at IS NULL) OR (revoked_at >= granted_at))),
    CONSTRAINT oauth_consents_scopes_length CHECK ((char_length(scopes) <= 2048)),
    CONSTRAINT oauth_consents_scopes_not_empty CHECK ((char_length(TRIM(BOTH FROM scopes)) > 0))
);


--
-- Name: one_time_tokens; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.one_time_tokens (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    token_type auth.one_time_token_type NOT NULL,
    token_hash text NOT NULL,
    relates_to text NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT one_time_tokens_token_hash_check CHECK ((char_length(token_hash) > 0))
);


--
-- Name: refresh_tokens; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.refresh_tokens (
    instance_id uuid,
    id bigint NOT NULL,
    token character varying(255),
    user_id character varying(255),
    revoked boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    parent character varying(255),
    session_id uuid
);


--
-- Name: TABLE refresh_tokens; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.refresh_tokens IS 'Auth: Store of tokens used to refresh JWT tokens once they expire.';


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.refresh_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.refresh_tokens_id_seq OWNED BY auth.refresh_tokens.id;


--
-- Name: saml_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.saml_providers (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    entity_id text NOT NULL,
    metadata_xml text NOT NULL,
    metadata_url text,
    attribute_mapping jsonb,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    name_id_format text,
    CONSTRAINT "entity_id not empty" CHECK ((char_length(entity_id) > 0)),
    CONSTRAINT "metadata_url not empty" CHECK (((metadata_url = NULL::text) OR (char_length(metadata_url) > 0))),
    CONSTRAINT "metadata_xml not empty" CHECK ((char_length(metadata_xml) > 0))
);


--
-- Name: TABLE saml_providers; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.saml_providers IS 'Auth: Manages SAML Identity Provider connections.';


--
-- Name: saml_relay_states; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.saml_relay_states (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    request_id text NOT NULL,
    for_email text,
    redirect_to text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    flow_state_id uuid,
    CONSTRAINT "request_id not empty" CHECK ((char_length(request_id) > 0))
);


--
-- Name: TABLE saml_relay_states; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.saml_relay_states IS 'Auth: Contains SAML Relay State information for each Service Provider initiated login.';


--
-- Name: schema_migrations; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: TABLE schema_migrations; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.schema_migrations IS 'Auth: Manages updates to the auth system.';


--
-- Name: sessions; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sessions (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    factor_id uuid,
    aal auth.aal_level,
    not_after timestamp with time zone,
    refreshed_at timestamp without time zone,
    user_agent text,
    ip inet,
    tag text,
    oauth_client_id uuid,
    refresh_token_hmac_key text,
    refresh_token_counter bigint,
    scopes text,
    CONSTRAINT sessions_scopes_length CHECK ((char_length(scopes) <= 4096))
);


--
-- Name: TABLE sessions; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sessions IS 'Auth: Stores session data associated to a user.';


--
-- Name: COLUMN sessions.not_after; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.not_after IS 'Auth: Not after is a nullable column that contains a timestamp after which the session should be regarded as expired.';


--
-- Name: COLUMN sessions.refresh_token_hmac_key; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.refresh_token_hmac_key IS 'Holds a HMAC-SHA256 key used to sign refresh tokens for this session.';


--
-- Name: COLUMN sessions.refresh_token_counter; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.refresh_token_counter IS 'Holds the ID (counter) of the last issued refresh token.';


--
-- Name: sso_domains; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sso_domains (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    domain text NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    CONSTRAINT "domain not empty" CHECK ((char_length(domain) > 0))
);


--
-- Name: TABLE sso_domains; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sso_domains IS 'Auth: Manages SSO email address domain mapping to an SSO Identity Provider.';


--
-- Name: sso_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sso_providers (
    id uuid NOT NULL,
    resource_id text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    disabled boolean,
    CONSTRAINT "resource_id not empty" CHECK (((resource_id = NULL::text) OR (char_length(resource_id) > 0)))
);


--
-- Name: TABLE sso_providers; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sso_providers IS 'Auth: Manages SSO identity provider information; see saml_providers for SAML.';


--
-- Name: COLUMN sso_providers.resource_id; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sso_providers.resource_id IS 'Auth: Uniquely identifies a SSO provider according to a user-chosen resource ID (case insensitive), useful in infrastructure as code.';


--
-- Name: users; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.users (
    instance_id uuid,
    id uuid NOT NULL,
    aud character varying(255),
    role character varying(255),
    email character varying(255),
    encrypted_password character varying(255),
    email_confirmed_at timestamp with time zone,
    invited_at timestamp with time zone,
    confirmation_token character varying(255),
    confirmation_sent_at timestamp with time zone,
    recovery_token character varying(255),
    recovery_sent_at timestamp with time zone,
    email_change_token_new character varying(255),
    email_change character varying(255),
    email_change_sent_at timestamp with time zone,
    last_sign_in_at timestamp with time zone,
    raw_app_meta_data jsonb,
    raw_user_meta_data jsonb,
    is_super_admin boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    phone text DEFAULT NULL::character varying,
    phone_confirmed_at timestamp with time zone,
    phone_change text DEFAULT ''::character varying,
    phone_change_token character varying(255) DEFAULT ''::character varying,
    phone_change_sent_at timestamp with time zone,
    confirmed_at timestamp with time zone GENERATED ALWAYS AS (LEAST(email_confirmed_at, phone_confirmed_at)) STORED,
    email_change_token_current character varying(255) DEFAULT ''::character varying,
    email_change_confirm_status smallint DEFAULT 0,
    banned_until timestamp with time zone,
    reauthentication_token character varying(255) DEFAULT ''::character varying,
    reauthentication_sent_at timestamp with time zone,
    is_sso_user boolean DEFAULT false NOT NULL,
    deleted_at timestamp with time zone,
    is_anonymous boolean DEFAULT false NOT NULL,
    CONSTRAINT users_email_change_confirm_status_check CHECK (((email_change_confirm_status >= 0) AND (email_change_confirm_status <= 2)))
);


--
-- Name: TABLE users; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.users IS 'Auth: Stores user login data within a secure schema.';


--
-- Name: COLUMN users.is_sso_user; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.users.is_sso_user IS 'Auth: Set this column to true when the account comes from SSO. These accounts can have duplicate emails.';


--
-- Name: webauthn_challenges; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.webauthn_challenges (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    challenge_type text NOT NULL,
    session_data jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    CONSTRAINT webauthn_challenges_challenge_type_check CHECK ((challenge_type = ANY (ARRAY['signup'::text, 'registration'::text, 'authentication'::text])))
);


--
-- Name: webauthn_credentials; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.webauthn_credentials (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    credential_id bytea NOT NULL,
    public_key bytea NOT NULL,
    attestation_type text DEFAULT ''::text NOT NULL,
    aaguid uuid,
    sign_count bigint DEFAULT 0 NOT NULL,
    transports jsonb DEFAULT '[]'::jsonb NOT NULL,
    backup_eligible boolean DEFAULT false NOT NULL,
    backed_up boolean DEFAULT false NOT NULL,
    friendly_name text DEFAULT ''::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    last_used_at timestamp with time zone
);


--
-- Name: Fintrack_project; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Fintrack_project" (
    id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: Fintrack_project_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public."Fintrack_project" ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public."Fintrack_project_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: chart_of_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chart_of_accounts (
    code character varying(10) NOT NULL,
    parent_code character varying(10),
    level smallint NOT NULL,
    account_name character varying(100) NOT NULL,
    account_type character varying(20) NOT NULL,
    normal_balance character varying(10) NOT NULL,
    is_header boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    display_order smallint DEFAULT 0 NOT NULL,
    notes text,
    is_custom boolean DEFAULT false NOT NULL,
    CONSTRAINT chart_of_accounts_account_type_check CHECK (((account_type)::text = ANY ((ARRAY['aset'::character varying, 'liabilitas'::character varying, 'ekuitas'::character varying, 'pendapatan'::character varying, 'beban'::character varying])::text[]))),
    CONSTRAINT chart_of_accounts_level_check CHECK ((level = ANY (ARRAY[1, 2, 3]))),
    CONSTRAINT chart_of_accounts_normal_balance_check CHECK (((normal_balance)::text = ANY ((ARRAY['debit'::character varying, 'credit'::character varying])::text[])))
);


--
-- Name: journal_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.journal_lines (
    id bigint NOT NULL,
    doc_number character varying(25) NOT NULL,
    line_order smallint DEFAULT 1 NOT NULL,
    account_code character varying(10) NOT NULL,
    debit_amount bigint DEFAULT 0 NOT NULL,
    credit_amount bigint DEFAULT 0 NOT NULL,
    CONSTRAINT journal_lines_credit_amount_check CHECK ((credit_amount >= 0)),
    CONSTRAINT journal_lines_debit_amount_check CHECK ((debit_amount >= 0)),
    CONSTRAINT one_side_only CHECK ((((debit_amount > 0) AND (credit_amount = 0)) OR ((debit_amount = 0) AND (credit_amount > 0))))
);


--
-- Name: transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transactions (
    doc_number character varying(25) NOT NULL,
    doc_type character varying(5) NOT NULL,
    transaction_date date NOT NULL,
    period_year smallint NOT NULL,
    period_month smallint NOT NULL,
    description text,
    status character varying(10) DEFAULT 'POSTED'::character varying NOT NULL,
    is_reversal boolean DEFAULT false NOT NULL,
    reversal_of_doc character varying(25),
    input_source character varying(20) DEFAULT 'telegram'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT transactions_doc_type_check CHECK (((doc_type)::text = ANY ((ARRAY['OB'::character varying, 'KK'::character varying, 'KM'::character varying, 'TR'::character varying, 'JU'::character varying, 'RV'::character varying])::text[]))),
    CONSTRAINT transactions_input_source_check CHECK (((input_source)::text = ANY ((ARRAY['telegram'::character varying, 'dashboard'::character varying, 'system'::character varying])::text[]))),
    CONSTRAINT transactions_status_check CHECK (((status)::text = ANY ((ARRAY['POSTED'::character varying, 'REVERSED'::character varying])::text[])))
);


--
-- Name: account_balances; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.account_balances WITH (security_invoker='true') AS
 SELECT coa.code,
    coa.account_name,
    coa.account_type,
    coa.normal_balance,
    COALESCE(sum(jl.debit_amount), (0)::numeric) AS total_debit,
    COALESCE(sum(jl.credit_amount), (0)::numeric) AS total_credit,
        CASE
            WHEN ((coa.normal_balance)::text = 'debit'::text) THEN (COALESCE(sum(jl.debit_amount), (0)::numeric) - COALESCE(sum(jl.credit_amount), (0)::numeric))
            ELSE (COALESCE(sum(jl.credit_amount), (0)::numeric) - COALESCE(sum(jl.debit_amount), (0)::numeric))
        END AS balance
   FROM ((public.chart_of_accounts coa
     LEFT JOIN public.journal_lines jl ON (((coa.code)::text = (jl.account_code)::text)))
     LEFT JOIN public.transactions t ON ((((jl.doc_number)::text = (t.doc_number)::text) AND ((t.status)::text = 'POSTED'::text))))
  WHERE ((coa.is_header = false) AND (coa.is_active = true))
  GROUP BY coa.code, coa.account_name, coa.account_type, coa.normal_balance;


--
-- Name: activity_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activity_log (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    action character varying(50) NOT NULL,
    meta jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: activity_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.activity_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: activity_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.activity_log_id_seq OWNED BY public.activity_log.id;


--
-- Name: audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_log (
    id bigint NOT NULL,
    table_name character varying(50) NOT NULL,
    record_id character varying(100) NOT NULL,
    action character varying(10) NOT NULL,
    old_data jsonb,
    new_data jsonb,
    changed_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT audit_log_action_check CHECK (((action)::text = ANY ((ARRAY['INSERT'::character varying, 'UPDATE'::character varying, 'DELETE'::character varying])::text[])))
);


--
-- Name: audit_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audit_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audit_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audit_log_id_seq OWNED BY public.audit_log.id;


--
-- Name: auth_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_tokens (
    token character varying(200) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    used_at timestamp with time zone,
    is_used boolean DEFAULT false NOT NULL
);


--
-- Name: bills; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bills (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    amount bigint NOT NULL,
    due_day smallint,
    due_date date,
    is_recurring boolean DEFAULT true NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    last_reminded_period character varying(7),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT bills_amount_check CHECK ((amount > 0)),
    CONSTRAINT bills_due_day_check CHECK (((due_day >= 1) AND (due_day <= 31))),
    CONSTRAINT bills_due_required CHECK (((due_day IS NOT NULL) OR (due_date IS NOT NULL)))
);


--
-- Name: bills_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bills_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bills_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bills_id_seq OWNED BY public.bills.id;


--
-- Name: bot_aliases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bot_aliases (
    alias character varying(50) NOT NULL,
    account_code character varying(10) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    deactivated_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by bigint
);


--
-- Name: bot_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bot_categories (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    emoji character varying(10),
    category_type character varying(10) NOT NULL,
    parent_id integer,
    display_order smallint DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT bot_categories_category_type_check CHECK (((category_type)::text = ANY ((ARRAY['expense'::character varying, 'income'::character varying])::text[])))
);


--
-- Name: bot_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bot_categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bot_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bot_categories_id_seq OWNED BY public.bot_categories.id;


--
-- Name: bot_category_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bot_category_accounts (
    category_id integer NOT NULL,
    account_code character varying(10) NOT NULL,
    display_order smallint DEFAULT 0 NOT NULL
);


--
-- Name: bot_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bot_settings (
    key character varying(50) NOT NULL,
    value text NOT NULL,
    notes text
);


--
-- Name: bot_state; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bot_state (
    user_id bigint NOT NULL,
    state character varying(50) DEFAULT 'IDLE'::character varying NOT NULL,
    state_data jsonb DEFAULT '{}'::jsonb NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: budgets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.budgets (
    account_code character varying(10) NOT NULL,
    monthly_limit bigint NOT NULL,
    last_alert_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT budgets_monthly_limit_check CHECK ((monthly_limit > 0))
);


--
-- Name: daily_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.daily_log (
    log_date date NOT NULL,
    user_id bigint,
    note text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: goals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.goals (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    target_amount bigint NOT NULL,
    account_code character varying(10),
    target_date date,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT goals_target_amount_check CHECK ((target_amount > 0))
);


--
-- Name: goals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.goals_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: goals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.goals_id_seq OWNED BY public.goals.id;


--
-- Name: journal_lines_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.journal_lines_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: journal_lines_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.journal_lines_id_seq OWNED BY public.journal_lines.id;


--
-- Name: monthly_summary; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.monthly_summary WITH (security_invoker='true') AS
 SELECT t.period_year,
    t.period_month,
    coa.account_type,
    COALESCE(sum(jl.debit_amount), (0)::numeric) AS total_debit,
    COALESCE(sum(jl.credit_amount), (0)::numeric) AS total_credit
   FROM ((public.transactions t
     JOIN public.journal_lines jl ON (((t.doc_number)::text = (jl.doc_number)::text)))
     JOIN public.chart_of_accounts coa ON (((jl.account_code)::text = (coa.code)::text)))
  WHERE (((t.status)::text = 'POSTED'::text) AND (coa.is_header = false))
  GROUP BY t.period_year, t.period_month, coa.account_type;


--
-- Name: periods; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.periods (
    year smallint NOT NULL,
    month smallint NOT NULL,
    is_locked boolean DEFAULT false NOT NULL,
    locked_at timestamp with time zone,
    CONSTRAINT periods_month_check CHECK (((month >= 1) AND (month <= 12)))
);


--
-- Name: receipts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.receipts (
    id bigint NOT NULL,
    telegram_file_id character varying(200) NOT NULL,
    telegram_chat_id bigint NOT NULL,
    image_path text,
    raw_ocr_text text,
    parsed_merchant character varying(100),
    parsed_amount bigint,
    parsed_date date,
    confidence_score smallint,
    note text,
    parse_source character varying(20) DEFAULT 'receipt'::character varying NOT NULL,
    ewallet_type character varying(20),
    status character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    doc_number character varying(25),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT receipts_confidence_score_check CHECK (((confidence_score >= 0) AND (confidence_score <= 100))),
    CONSTRAINT receipts_ewallet_type_check CHECK (((ewallet_type IS NULL) OR ((ewallet_type)::text = ANY ((ARRAY['gopay'::character varying, 'ovo'::character varying, 'dana'::character varying, 'seabank'::character varying, 'bca'::character varying])::text[])))),
    CONSTRAINT receipts_parse_source_check CHECK (((parse_source)::text = ANY ((ARRAY['receipt'::character varying, 'ewallet'::character varying])::text[]))),
    CONSTRAINT receipts_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'confirmed'::character varying, 'rejected'::character varying, 'manual'::character varying])::text[])))
);


--
-- Name: receipts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.receipts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: receipts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.receipts_id_seq OWNED BY public.receipts.id;


--
-- Name: recurring_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recurring_transactions (
    id integer NOT NULL,
    doc_type character varying(5) NOT NULL,
    description text,
    lines jsonb NOT NULL,
    frequency character varying(10) NOT NULL,
    next_run date NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT recurring_transactions_doc_type_check CHECK (((doc_type)::text = ANY ((ARRAY['OB'::character varying, 'KK'::character varying, 'KM'::character varying, 'TR'::character varying, 'JU'::character varying, 'RV'::character varying])::text[]))),
    CONSTRAINT recurring_transactions_frequency_check CHECK (((frequency)::text = ANY ((ARRAY['daily'::character varying, 'weekly'::character varying, 'monthly'::character varying])::text[])))
);


--
-- Name: recurring_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.recurring_transactions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: recurring_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.recurring_transactions_id_seq OWNED BY public.recurring_transactions.id;


--
-- Name: sequences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sequences (
    doc_type character varying(5) NOT NULL,
    year smallint NOT NULL,
    month smallint NOT NULL,
    last_seq integer DEFAULT 0 NOT NULL,
    CONSTRAINT sequences_doc_type_check CHECK (((doc_type)::text = ANY ((ARRAY['OB'::character varying, 'KK'::character varying, 'KM'::character varying, 'TR'::character varying, 'JU'::character varying, 'RV'::character varying])::text[]))),
    CONSTRAINT sequences_month_check CHECK (((month >= 1) AND (month <= 12)))
);


--
-- Name: tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tags (
    id integer NOT NULL,
    name character varying(30) NOT NULL,
    emoji character varying(10)
);


--
-- Name: tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tags_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tags_id_seq OWNED BY public.tags.id;


--
-- Name: transaction_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transaction_tags (
    doc_number character varying(25) NOT NULL,
    tag_id integer NOT NULL
);


--
-- Name: transfer_fee_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transfer_fee_rules (
    from_account character varying(10) NOT NULL,
    to_account character varying(10) NOT NULL,
    fee_amount bigint DEFAULT 0 NOT NULL,
    fee_account character varying(10),
    method_label character varying(50),
    CONSTRAINT transfer_fee_rules_fee_amount_check CHECK ((fee_amount >= 0))
);


--
-- Name: messages; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.messages (
    topic text NOT NULL,
    extension text NOT NULL,
    payload jsonb,
    event text,
    private boolean DEFAULT false,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    binary_payload bytea
)
PARTITION BY RANGE (inserted_at);


--
-- Name: schema_migrations; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: subscription; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.subscription (
    id bigint NOT NULL,
    subscription_id uuid NOT NULL,
    entity regclass NOT NULL,
    filters realtime.user_defined_filter[] DEFAULT '{}'::realtime.user_defined_filter[] NOT NULL,
    claims jsonb NOT NULL,
    claims_role regrole GENERATED ALWAYS AS (realtime.to_regrole((claims ->> 'role'::text))) STORED NOT NULL,
    created_at timestamp without time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    action_filter text DEFAULT '*'::text,
    selected_columns text[],
    CONSTRAINT subscription_action_filter_check CHECK ((action_filter = ANY (ARRAY['*'::text, 'INSERT'::text, 'UPDATE'::text, 'DELETE'::text])))
);


--
-- Name: subscription_id_seq; Type: SEQUENCE; Schema: realtime; Owner: -
--

ALTER TABLE realtime.subscription ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME realtime.subscription_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: buckets; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets (
    id text NOT NULL,
    name text NOT NULL,
    owner uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    public boolean DEFAULT false,
    avif_autodetection boolean DEFAULT false,
    file_size_limit bigint,
    allowed_mime_types text[],
    owner_id text,
    type storage.buckettype DEFAULT 'STANDARD'::storage.buckettype NOT NULL
);


--
-- Name: COLUMN buckets.owner; Type: COMMENT; Schema: storage; Owner: -
--

COMMENT ON COLUMN storage.buckets.owner IS 'Field is deprecated, use owner_id instead';


--
-- Name: buckets_analytics; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets_analytics (
    name text NOT NULL,
    type storage.buckettype DEFAULT 'ANALYTICS'::storage.buckettype NOT NULL,
    format text DEFAULT 'ICEBERG'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: buckets_vectors; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets_vectors (
    id text NOT NULL,
    type storage.buckettype DEFAULT 'VECTOR'::storage.buckettype NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: migrations; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.migrations (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    hash character varying(40) NOT NULL,
    executed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: objects; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.objects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bucket_id text,
    name text,
    owner uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    last_accessed_at timestamp with time zone DEFAULT now(),
    metadata jsonb,
    path_tokens text[] GENERATED ALWAYS AS (string_to_array(name, '/'::text)) STORED,
    version text,
    owner_id text,
    user_metadata jsonb
);


--
-- Name: COLUMN objects.owner; Type: COMMENT; Schema: storage; Owner: -
--

COMMENT ON COLUMN storage.objects.owner IS 'Field is deprecated, use owner_id instead';


--
-- Name: s3_multipart_uploads; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.s3_multipart_uploads (
    id text NOT NULL,
    in_progress_size bigint DEFAULT 0 NOT NULL,
    upload_signature text NOT NULL,
    bucket_id text NOT NULL,
    key text NOT NULL COLLATE pg_catalog."C",
    version text NOT NULL,
    owner_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    user_metadata jsonb,
    metadata jsonb
);


--
-- Name: s3_multipart_uploads_parts; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.s3_multipart_uploads_parts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    upload_id text NOT NULL,
    size bigint DEFAULT 0 NOT NULL,
    part_number integer NOT NULL,
    bucket_id text NOT NULL,
    key text NOT NULL COLLATE pg_catalog."C",
    etag text NOT NULL,
    owner_id text,
    version text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: vector_indexes; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.vector_indexes (
    id text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL COLLATE pg_catalog."C",
    bucket_id text NOT NULL,
    data_type text NOT NULL,
    dimension integer NOT NULL,
    distance_metric text NOT NULL,
    metadata_configuration jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: refresh_tokens id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens ALTER COLUMN id SET DEFAULT nextval('auth.refresh_tokens_id_seq'::regclass);


--
-- Name: activity_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_log ALTER COLUMN id SET DEFAULT nextval('public.activity_log_id_seq'::regclass);


--
-- Name: audit_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log ALTER COLUMN id SET DEFAULT nextval('public.audit_log_id_seq'::regclass);


--
-- Name: bills id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bills ALTER COLUMN id SET DEFAULT nextval('public.bills_id_seq'::regclass);


--
-- Name: bot_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bot_categories ALTER COLUMN id SET DEFAULT nextval('public.bot_categories_id_seq'::regclass);


--
-- Name: goals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goals ALTER COLUMN id SET DEFAULT nextval('public.goals_id_seq'::regclass);


--
-- Name: journal_lines id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_lines ALTER COLUMN id SET DEFAULT nextval('public.journal_lines_id_seq'::regclass);


--
-- Name: receipts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receipts ALTER COLUMN id SET DEFAULT nextval('public.receipts_id_seq'::regclass);


--
-- Name: recurring_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurring_transactions ALTER COLUMN id SET DEFAULT nextval('public.recurring_transactions_id_seq'::regclass);


--
-- Name: tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags ALTER COLUMN id SET DEFAULT nextval('public.tags_id_seq'::regclass);


--
-- Data for Name: audit_log_entries; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.audit_log_entries (instance_id, id, payload, created_at, ip_address) FROM stdin;
\.


--
-- Data for Name: custom_oauth_providers; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.custom_oauth_providers (id, provider_type, identifier, name, client_id, client_secret, acceptable_client_ids, scopes, pkce_enabled, attribute_mapping, authorization_params, enabled, email_optional, issuer, discovery_url, skip_nonce_check, cached_discovery, discovery_cached_at, authorization_url, token_url, userinfo_url, jwks_uri, created_at, updated_at, custom_claims_allowlist) FROM stdin;
\.


--
-- Data for Name: flow_state; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.flow_state (id, user_id, auth_code, code_challenge_method, code_challenge, provider_type, provider_access_token, provider_refresh_token, created_at, updated_at, authentication_method, auth_code_issued_at, invite_token, referrer, oauth_client_state_id, linking_target_id, email_optional) FROM stdin;
\.


--
-- Data for Name: identities; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at, id) FROM stdin;
\.


--
-- Data for Name: instances; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.instances (id, uuid, raw_base_config, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: mfa_amr_claims; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.mfa_amr_claims (session_id, created_at, updated_at, authentication_method, id) FROM stdin;
\.


--
-- Data for Name: mfa_challenges; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.mfa_challenges (id, factor_id, created_at, verified_at, ip_address, otp_code, web_authn_session_data) FROM stdin;
\.


--
-- Data for Name: mfa_factors; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at, secret, phone, last_challenged_at, web_authn_credential, web_authn_aaguid, last_webauthn_challenge_data) FROM stdin;
\.


--
-- Data for Name: oauth_authorizations; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.oauth_authorizations (id, authorization_id, client_id, user_id, redirect_uri, scope, state, resource, code_challenge, code_challenge_method, response_type, status, authorization_code, created_at, expires_at, approved_at, nonce) FROM stdin;
\.


--
-- Data for Name: oauth_client_states; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.oauth_client_states (id, provider_type, code_verifier, created_at) FROM stdin;
\.


--
-- Data for Name: oauth_clients; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.oauth_clients (id, client_secret_hash, registration_type, redirect_uris, grant_types, client_name, client_uri, logo_uri, created_at, updated_at, deleted_at, client_type, token_endpoint_auth_method) FROM stdin;
\.


--
-- Data for Name: oauth_consents; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.oauth_consents (id, user_id, client_id, scopes, granted_at, revoked_at) FROM stdin;
\.


--
-- Data for Name: one_time_tokens; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.one_time_tokens (id, user_id, token_type, token_hash, relates_to, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: refresh_tokens; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.refresh_tokens (instance_id, id, token, user_id, revoked, created_at, updated_at, parent, session_id) FROM stdin;
\.


--
-- Data for Name: saml_providers; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.saml_providers (id, sso_provider_id, entity_id, metadata_xml, metadata_url, attribute_mapping, created_at, updated_at, name_id_format) FROM stdin;
\.


--
-- Data for Name: saml_relay_states; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.saml_relay_states (id, sso_provider_id, request_id, for_email, redirect_to, created_at, updated_at, flow_state_id) FROM stdin;
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.schema_migrations (version) FROM stdin;
20171026211738
20171026211808
20171026211834
20180103212743
20180108183307
20180119214651
20180125194653
00
20210710035447
20210722035447
20210730183235
20210909172000
20210927181326
20211122151130
20211124214934
20211202183645
20220114185221
20220114185340
20220224000811
20220323170000
20220429102000
20220531120530
20220614074223
20220811173540
20221003041349
20221003041400
20221011041400
20221020193600
20221021073300
20221021082433
20221027105023
20221114143122
20221114143410
20221125140132
20221208132122
20221215195500
20221215195800
20221215195900
20230116124310
20230116124412
20230131181311
20230322519590
20230402418590
20230411005111
20230508135423
20230523124323
20230818113222
20230914180801
20231027141322
20231114161723
20231117164230
20240115144230
20240214120130
20240306115329
20240314092811
20240427152123
20240612123726
20240729123726
20240802193726
20240806073726
20241009103726
20250717082212
20250731150234
20250804100000
20250901200500
20250903112500
20250904133000
20250925093508
20251007112900
20251104100000
20251111201300
20251201000000
20260115000000
20260121000000
20260219120000
20260302000000
20260625000000
\.


--
-- Data for Name: sessions; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.sessions (id, user_id, created_at, updated_at, factor_id, aal, not_after, refreshed_at, user_agent, ip, tag, oauth_client_id, refresh_token_hmac_key, refresh_token_counter, scopes) FROM stdin;
\.


--
-- Data for Name: sso_domains; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.sso_domains (id, sso_provider_id, domain, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: sso_providers; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.sso_providers (id, resource_id, created_at, updated_at, disabled) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, invited_at, confirmation_token, confirmation_sent_at, recovery_token, recovery_sent_at, email_change_token_new, email_change, email_change_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, created_at, updated_at, phone, phone_confirmed_at, phone_change, phone_change_token, phone_change_sent_at, email_change_token_current, email_change_confirm_status, banned_until, reauthentication_token, reauthentication_sent_at, is_sso_user, deleted_at, is_anonymous) FROM stdin;
\.


--
-- Data for Name: webauthn_challenges; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.webauthn_challenges (id, user_id, challenge_type, session_data, created_at, expires_at) FROM stdin;
\.


--
-- Data for Name: webauthn_credentials; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.webauthn_credentials (id, user_id, credential_id, public_key, attestation_type, aaguid, sign_count, transports, backup_eligible, backed_up, friendly_name, created_at, updated_at, last_used_at) FROM stdin;
\.


--
-- Data for Name: Fintrack_project; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public."Fintrack_project" (id, created_at) FROM stdin;
\.


--
-- Data for Name: activity_log; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.activity_log (id, user_id, action, meta, created_at) FROM stdin;
1	7248273513	command:/getlink	{}	2026-07-08 20:52:30.964073+00
2	7248273513	command:/start	{}	2026-07-08 21:19:51.108422+00
3	7248273513	callback:menu:expense	{}	2026-07-08 21:19:59.310994+00
4	7248273513	callback:exp_cat:9	{}	2026-07-08 21:20:03.142334+00
5	7248273513	callback:act:cancel	{}	2026-07-08 21:20:07.054074+00
6	7248273513	command:/getlink	{}	2026-07-08 21:34:33.814349+00
7	7248273513	command:/getlink	{}	2026-07-08 21:38:10.182031+00
8	7248273513	command:/start	{}	2026-07-08 21:39:56.932852+00
9	7248273513	command:/getlink	{}	2026-07-09 03:38:21.256551+00
10	7248273513	command:/start	{}	2026-07-09 03:39:58.567722+00
11	7248273513	callback:act:bills	{}	2026-07-09 03:40:06.248631+00
12	7248273513	command:/getlink	{}	2026-07-09 04:22:49.934302+00
13	7248273513	callback:menu:expense	{}	2026-07-09 04:31:24.822002+00
14	7248273513	command:/start	{}	2026-07-09 04:31:31.320801+00
15	7248273513	callback:menu:expense	{}	2026-07-09 04:31:34.929446+00
16	7248273513	callback:exp_cat:1	{}	2026-07-09 04:31:39.00469+00
17	7248273513	callback:act:cancel	{}	2026-07-09 04:31:43.200813+00
18	7248273513	command:/start	{}	2026-07-09 04:32:05.809814+00
19	7248273513	command:/menu	{}	2026-07-09 04:32:10.287268+00
20	7248273513	callback:menu:expense	{}	2026-07-09 04:32:41.246862+00
21	7248273513	callback:exp_cat:1	{}	2026-07-09 04:32:55.677765+00
22	7248273513	callback:act:cancel	{}	2026-07-09 04:33:01.441831+00
23	7248273513	command:/start	{}	2026-07-09 04:46:47.116598+00
24	7248273513	callback:menu:expense	{}	2026-07-09 04:46:52.429229+00
25	7248273513	callback:exp_cat:9	{}	2026-07-09 04:46:55.458826+00
26	7248273513	callback:act:cancel	{}	2026-07-09 04:46:59.422479+00
27	7248273513	command:/getlink	{}	2026-07-09 05:55:04.795608+00
28	7248273513	command:/start	{}	2026-07-09 07:45:50.709153+00
29	7248273513	command:/getlink	{}	2026-07-09 07:45:56.569193+00
30	7248273513	callback:menu:expense	{}	2026-07-09 08:02:33.938965+00
31	7248273513	command:/getlink	{}	2026-07-09 08:02:37.330382+00
32	7248273513	command:/start	{}	2026-07-09 08:42:45.405272+00
33	7248273513	command:/getlink	{}	2026-07-09 08:42:52.398296+00
34	7248273513	command:/start	{}	2026-07-09 09:16:01.697302+00
35	7248273513	command:/getlink	{}	2026-07-09 09:16:08.308604+00
36	7248273513	command:/start	{}	2026-07-09 12:44:12.897069+00
37	7248273513	callback:act:saldo	{}	2026-07-09 12:44:24.992197+00
38	7248273513	callback:menu:expense	{}	2026-07-09 12:44:37.860305+00
39	7248273513	callback:act:cancel	{}	2026-07-09 12:44:52.812606+00
40	7248273513	callback:act:menu	{}	2026-07-09 12:44:57.248335+00
41	7248273513	callback:act:scan	{}	2026-07-09 12:45:03.523898+00
42	7248273513	photo	{}	2026-07-09 12:45:35.470488+00
43	7248273513	callback:rcp:save:1	{}	2026-07-09 12:46:16.007459+00
44	7248273513	callback:exp_src:1130	{}	2026-07-09 12:46:24.657106+00
45	7248273513	callback:exp_post	{}	2026-07-09 12:46:35.338437+00
46	7248273513	callback:act:recent	{}	2026-07-09 12:46:56.582704+00
47	7248273513	callback:detail:KK-2026-07-022	{}	2026-07-09 12:47:02.808515+00
48	7248273513	command:/start	{}	2026-07-09 12:47:13.813738+00
49	7248273513	command:/start	{}	2026-07-10 09:44:30.651103+00
50	7248273513	callback:act:saldo	{}	2026-07-10 09:44:38.480535+00
51	7248273513	callback:menu:expense	{}	2026-07-10 09:44:47.988208+00
52	7248273513	callback:act:cancel	{}	2026-07-10 09:44:52.875591+00
53	7248273513	callback:act:menu	{}	2026-07-10 09:44:59.211509+00
54	7248273513	callback:act:recurring	{}	2026-07-10 09:45:02.503659+00
55	7248273513	callback:menu:expense	{}	2026-07-10 09:45:11.717336+00
56	7248273513	callback:exp_cat:1	{}	2026-07-10 09:45:15.909349+00
57	7248273513	callback:exp_acc:5110	{}	2026-07-10 09:45:21.413518+00
58	7248273513	message	{}	2026-07-10 09:45:38.222209+00
59	7248273513	message	{}	2026-07-10 09:45:50.758883+00
60	7248273513	callback:exp_src:1130	{}	2026-07-10 09:45:55.9592+00
61	7248273513	callback:exp_post	{}	2026-07-10 09:46:00.721121+00
62	7248273513	callback:menu:expense	{}	2026-07-10 09:46:09.449816+00
63	7248273513	callback:exp_cat:1	{}	2026-07-10 09:46:14.02872+00
64	7248273513	callback:exp_acc:5120	{}	2026-07-10 09:46:19.495224+00
65	7248273513	message	{}	2026-07-10 09:46:28.503101+00
66	7248273513	message	{}	2026-07-10 09:46:36.13249+00
67	7248273513	callback:exp_src:1130	{}	2026-07-10 09:46:43.192823+00
68	7248273513	callback:exp_post	{}	2026-07-10 09:46:49.799407+00
69	7248273513	callback:act:menu	{}	2026-07-10 09:47:00.957587+00
70	7248273513	callback:menu:expense	{}	2026-07-10 14:32:09.340487+00
71	7248273513	callback:exp_cat:6	{}	2026-07-10 14:32:18.297979+00
72	7248273513	callback:exp_acc:5530	{}	2026-07-10 14:32:23.82336+00
73	7248273513	message	{}	2026-07-10 14:32:31.811678+00
74	7248273513	message	{}	2026-07-10 14:32:41.492938+00
75	7248273513	callback:exp_src:1120	{}	2026-07-10 14:32:47.291601+00
76	7248273513	callback:exp_post	{}	2026-07-10 14:32:53.414429+00
77	7248273513	command:/getlink	{}	2026-07-10 14:37:42.568947+00
78	7248273513	command:/start	{}	2026-07-10 19:31:58.231796+00
79	7248273513	callback:menu:expense	{}	2026-07-10 19:32:07.21493+00
80	7248273513	callback:exp_cat:6	{}	2026-07-10 19:32:14.033598+00
81	7248273513	callback:act:cancel	{}	2026-07-10 19:32:21.080221+00
82	7248273513	callback:act:menu	{}	2026-07-10 19:32:25.703924+00
83	7248273513	callback:menu:expense	{}	2026-07-10 19:32:29.597776+00
84	7248273513	callback:exp_cat:5	{}	2026-07-10 19:32:33.072058+00
85	7248273513	callback:act:cancel	{}	2026-07-10 19:32:39.066035+00
86	7248273513	callback:act:menu	{}	2026-07-10 19:32:44.686518+00
87	7248273513	callback:menu:expense	{}	2026-07-10 19:32:57.924214+00
88	7248273513	callback:exp_cat:6	{}	2026-07-10 19:33:11.958224+00
89	7248273513	callback:exp_acc:5540	{}	2026-07-10 19:33:28.161672+00
90	7248273513	message	{}	2026-07-10 19:33:58.474352+00
91	7248273513	message	{}	2026-07-10 19:34:10.79261+00
92	7248273513	callback:exp_src:1120	{}	2026-07-10 19:34:17.569042+00
93	7248273513	callback:exp_post	{}	2026-07-10 19:34:24.202599+00
94	7248273513	callback:act:saldo	{}	2026-07-10 19:34:43.748713+00
95	7248273513	command:/start	{}	2026-07-10 20:16:44.190216+00
96	7248273513	callback:menu:expense	{}	2026-07-10 20:16:58.359727+00
97	7248273513	callback:exp_cat:9	{}	2026-07-10 20:17:07.618898+00
98	7248273513	callback:exp_acc:9999	{}	2026-07-10 20:17:16.537461+00
99	7248273513	message	{}	2026-07-10 20:17:28.34649+00
100	7248273513	message	{}	2026-07-10 20:17:34.212982+00
101	7248273513	callback:exp_src:1120	{}	2026-07-10 20:17:51.255326+00
102	7248273513	callback:exp_post	{}	2026-07-10 20:18:05.229207+00
103	7248273513	callback:exp_post	{}	2026-07-10 20:18:12.06206+00
104	7248273513	callback:menu:income	{}	2026-07-10 20:18:16.454418+00
105	7248273513	callback:inc_cat:14	{}	2026-07-10 20:18:22.569085+00
106	7248273513	callback:inc_acc:4390	{}	2026-07-10 20:18:27.123394+00
107	7248273513	message	{}	2026-07-10 20:18:33.713952+00
108	7248273513	command:/skip	{}	2026-07-10 20:18:37.663097+00
109	7248273513	callback:inc_post	{}	2026-07-10 20:18:44.808678+00
110	7248273513	callback:menu:income	{}	2026-07-10 20:54:43.238255+00
111	7248273513	callback:inc_cat:14	{}	2026-07-10 20:54:50.706363+00
112	7248273513	callback:inc_acc:4390	{}	2026-07-10 20:54:55.726979+00
113	7248273513	message	{}	2026-07-10 20:55:02.513186+00
114	7248273513	command:/skip	{}	2026-07-10 20:55:13.389914+00
115	7248273513	callback:inc_post	{}	2026-07-10 20:55:24.056535+00
116	7248273513	command:/start	{}	2026-07-11 04:14:59.771928+00
117	7248273513	command:/getlink	{}	2026-07-11 04:15:15.509948+00
118	7248273513	command:/scan	{}	2026-07-11 09:57:00.550856+00
119	7248273513	photo	{}	2026-07-11 09:57:04.545887+00
120	7248273513	callback:rcp:cancel:2	{}	2026-07-11 09:57:16.38414+00
121	7248273513	command:/start	{}	2026-07-11 09:57:28.396424+00
122	7248273513	callback:menu:expense	{}	2026-07-11 09:57:47.187438+00
123	7248273513	callback:exp_cat:6	{}	2026-07-11 09:57:51.476771+00
124	7248273513	callback:exp_acc:5530	{}	2026-07-11 09:58:02.352624+00
125	7248273513	message	{}	2026-07-11 09:58:19.198658+00
126	7248273513	message	{}	2026-07-11 09:58:31.540114+00
127	7248273513	callback:exp_src:1130	{}	2026-07-11 09:58:36.892838+00
128	7248273513	command:/menu	{}	2026-07-11 10:45:13.639105+00
129	7248273513	callback:menu:expense	{}	2026-07-11 10:45:19.189502+00
130	7248273513	callback:exp_cat:6	{}	2026-07-11 10:45:23.266153+00
131	7248273513	callback:exp_acc:5530	{}	2026-07-11 10:45:27.781284+00
132	7248273513	message	{}	2026-07-11 10:45:44.818706+00
133	7248273513	message	{}	2026-07-11 10:45:57.711585+00
134	7248273513	callback:exp_src:1130	{}	2026-07-11 10:46:03.830147+00
135	7248273513	callback:exp_post	{}	2026-07-11 10:46:10.756322+00
136	7248273513	callback:act:saldo	{}	2026-07-11 10:46:31.548402+00
137	7248273513	callback:menu:expense	{}	2026-07-11 10:47:00.602891+00
138	7248273513	callback:exp_cat:1	{}	2026-07-11 10:47:04.843152+00
139	7248273513	callback:exp_acc:5130	{}	2026-07-11 10:47:27.089968+00
140	7248273513	message	{}	2026-07-11 10:47:35.035271+00
141	7248273513	message	{}	2026-07-11 10:47:43.742526+00
142	7248273513	callback:exp_src:1130	{}	2026-07-11 10:47:53.25907+00
143	7248273513	callback:exp_post	{}	2026-07-11 10:48:01.051497+00
144	7248273513	callback:menu:expense	{}	2026-07-11 10:48:24.781744+00
145	7248273513	callback:exp_cat:1	{}	2026-07-11 10:48:28.97472+00
146	7248273513	callback:exp_acc:5110	{}	2026-07-11 10:48:32.849625+00
147	7248273513	message	{}	2026-07-11 10:48:39.816982+00
148	7248273513	message	{}	2026-07-11 10:48:49.160546+00
149	7248273513	callback:exp_src:1130	{}	2026-07-11 10:48:55.14728+00
150	7248273513	callback:exp_post	{}	2026-07-11 10:49:00.339836+00
151	7248273513	callback:act:saldo	{}	2026-07-11 10:49:09.568497+00
152	7248273513	command:/menu	{}	2026-07-11 12:57:01.242957+00
153	7248273513	callback:menu:expense	{}	2026-07-11 12:57:05.340677+00
154	7248273513	callback:exp_cat:9	{}	2026-07-11 12:57:14.543047+00
155	7248273513	callback:exp_acc:9999	{}	2026-07-11 12:57:19.348015+00
156	7248273513	message	{}	2026-07-11 12:57:31.674936+00
157	7248273513	command:/skip	{}	2026-07-11 12:57:39.818927+00
158	7248273513	callback:exp_src:1130	{}	2026-07-11 12:57:45.933396+00
159	7248273513	callback:exp_post	{}	2026-07-11 12:57:51.444941+00
160	7248273513	callback:menu:expense	{}	2026-07-11 12:57:57.725357+00
161	7248273513	callback:exp_cat:7	{}	2026-07-11 12:58:11.638252+00
162	7248273513	callback:exp_acc:5710	{}	2026-07-11 12:58:17.883429+00
163	7248273513	message	{}	2026-07-11 12:58:42.499529+00
164	7248273513	command:/skip	{}	2026-07-11 12:58:50.267679+00
165	7248273513	callback:exp_src:1120	{}	2026-07-11 12:58:55.435817+00
166	7248273513	callback:exp_post	{}	2026-07-11 12:59:05.905127+00
167	7248273513	callback:menu:expense	{}	2026-07-11 12:59:23.429011+00
168	7248273513	callback:exp_cat:7	{}	2026-07-11 12:59:28.35837+00
169	7248273513	callback:exp_acc:5710	{}	2026-07-11 12:59:32.532879+00
170	7248273513	message	{}	2026-07-11 12:59:42.732356+00
171	7248273513	command:/skip	{}	2026-07-11 12:59:47.398691+00
172	7248273513	callback:exp_src:1120	{}	2026-07-11 12:59:56.157521+00
173	7248273513	callback:exp_post	{}	2026-07-11 13:00:08.082103+00
174	7248273513	callback:menu:transfer	{}	2026-07-11 13:00:16.063068+00
175	7248273513	callback:tr:imprest	{}	2026-07-11 13:00:19.868542+00
176	7248273513	callback:act:cancel	{}	2026-07-11 13:00:30.095674+00
177	7248273513	callback:tr:savings_in	{}	2026-07-11 13:00:35.494102+00
178	7248273513	message	{}	2026-07-11 13:00:56.279217+00
179	7248273513	callback:act:cancel	{}	2026-07-11 13:01:12.078942+00
180	7248273513	command:/nihil	{}	2026-07-15 07:32:58.603373+00
\.


--
-- Data for Name: audit_log; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.audit_log (id, table_name, record_id, action, old_data, new_data, changed_at) FROM stdin;
1	transactions	OB-2026-07-001	INSERT	\N	{"status": "POSTED", "doc_type": "OB", "created_at": "2026-07-01T08:37:27.825116+00:00", "doc_number": "OB-2026-07-001", "description": "Saldo awal (setup)", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-01"}	2026-07-01 08:37:27.825116+00
2	journal_lines	1	INSERT	\N	{"id": 1, "doc_number": "OB-2026-07-001", "line_order": 1, "account_code": "1120", "debit_amount": 2619552, "credit_amount": 0}	2026-07-01 08:37:27.825116+00
3	journal_lines	2	INSERT	\N	{"id": 2, "doc_number": "OB-2026-07-001", "line_order": 2, "account_code": "1130", "debit_amount": 1, "credit_amount": 0}	2026-07-01 08:37:27.825116+00
4	journal_lines	3	INSERT	\N	{"id": 3, "doc_number": "OB-2026-07-001", "line_order": 3, "account_code": "1110", "debit_amount": 1000, "credit_amount": 0}	2026-07-01 08:37:27.825116+00
5	journal_lines	4	INSERT	\N	{"id": 4, "doc_number": "OB-2026-07-001", "line_order": 4, "account_code": "3110", "debit_amount": 0, "credit_amount": 2620553}	2026-07-01 08:37:27.825116+00
6	transactions	KK-2026-07-001	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-01T08:38:35.402256+00:00", "doc_number": "KK-2026-07-001", "description": "Ke Abang", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-01"}	2026-07-01 08:38:35.402256+00
7	journal_lines	5	INSERT	\N	{"id": 5, "doc_number": "KK-2026-07-001", "line_order": 1, "account_code": "5710", "debit_amount": 500000, "credit_amount": 0}	2026-07-01 08:38:35.402256+00
8	journal_lines	6	INSERT	\N	{"id": 6, "doc_number": "KK-2026-07-001", "line_order": 2, "account_code": "1120", "debit_amount": 0, "credit_amount": 500000}	2026-07-01 08:38:35.402256+00
9	transactions	KK-2026-07-002	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-01T08:39:31.372366+00:00", "doc_number": "KK-2026-07-002", "description": "Beli rokok", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-01"}	2026-07-01 08:39:31.372366+00
10	journal_lines	7	INSERT	\N	{"id": 7, "doc_number": "KK-2026-07-002", "line_order": 1, "account_code": "9999", "debit_amount": 23500, "credit_amount": 0}	2026-07-01 08:39:31.372366+00
11	journal_lines	8	INSERT	\N	{"id": 8, "doc_number": "KK-2026-07-002", "line_order": 2, "account_code": "1120", "debit_amount": 0, "credit_amount": 23500}	2026-07-01 08:39:31.372366+00
12	transactions	KK-2026-07-003	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-01T08:40:26.621801+00:00", "doc_number": "KK-2026-07-003", "description": "Makan siang", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-01"}	2026-07-01 08:40:26.621801+00
13	journal_lines	9	INSERT	\N	{"id": 9, "doc_number": "KK-2026-07-003", "line_order": 1, "account_code": "5110", "debit_amount": 15000, "credit_amount": 0}	2026-07-01 08:40:26.621801+00
14	journal_lines	10	INSERT	\N	{"id": 10, "doc_number": "KK-2026-07-003", "line_order": 2, "account_code": "1120", "debit_amount": 0, "credit_amount": 15000}	2026-07-01 08:40:26.621801+00
15	transactions	KK-2026-07-004	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-01T08:41:15.244257+00:00", "doc_number": "KK-2026-07-004", "description": "Es dancow", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-01"}	2026-07-01 08:41:15.244257+00
16	journal_lines	11	INSERT	\N	{"id": 11, "doc_number": "KK-2026-07-004", "line_order": 1, "account_code": "5120", "debit_amount": 7000, "credit_amount": 0}	2026-07-01 08:41:15.244257+00
17	journal_lines	12	INSERT	\N	{"id": 12, "doc_number": "KK-2026-07-004", "line_order": 2, "account_code": "1120", "debit_amount": 0, "credit_amount": 7000}	2026-07-01 08:41:15.244257+00
18	transactions	KK-2026-07-005	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-01T08:41:54.448308+00:00", "doc_number": "KK-2026-07-005", "description": "Beli kuota by u", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-01"}	2026-07-01 08:41:54.448308+00
19	journal_lines	13	INSERT	\N	{"id": 13, "doc_number": "KK-2026-07-005", "line_order": 1, "account_code": "5310", "debit_amount": 50000, "credit_amount": 0}	2026-07-01 08:41:54.448308+00
20	journal_lines	14	INSERT	\N	{"id": 14, "doc_number": "KK-2026-07-005", "line_order": 2, "account_code": "1120", "debit_amount": 0, "credit_amount": 50000}	2026-07-01 08:41:54.448308+00
21	transactions	TR-2026-07-001	INSERT	\N	{"status": "POSTED", "doc_type": "TR", "created_at": "2026-07-01T08:42:18.842771+00:00", "doc_number": "TR-2026-07-001", "description": "Pengisian imprest kas kecil", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-01"}	2026-07-01 08:42:18.842771+00
22	journal_lines	15	INSERT	\N	{"id": 15, "doc_number": "TR-2026-07-001", "line_order": 1, "account_code": "1130", "debit_amount": 499999, "credit_amount": 0}	2026-07-01 08:42:18.842771+00
23	journal_lines	16	INSERT	\N	{"id": 16, "doc_number": "TR-2026-07-001", "line_order": 2, "account_code": "5820", "debit_amount": 2500, "credit_amount": 0}	2026-07-01 08:42:18.842771+00
24	journal_lines	17	INSERT	\N	{"id": 17, "doc_number": "TR-2026-07-001", "line_order": 3, "account_code": "1120", "debit_amount": 0, "credit_amount": 502499}	2026-07-01 08:42:18.842771+00
25	transactions	KK-2026-07-006	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-01T14:38:26.665865+00:00", "doc_number": "KK-2026-07-006", "description": "Ayam bakar madu", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-01"}	2026-07-01 14:38:26.665865+00
26	journal_lines	18	INSERT	\N	{"id": 18, "doc_number": "KK-2026-07-006", "line_order": 1, "account_code": "5110", "debit_amount": 19500, "credit_amount": 0}	2026-07-01 14:38:26.665865+00
27	journal_lines	19	INSERT	\N	{"id": 19, "doc_number": "KK-2026-07-006", "line_order": 2, "account_code": "1130", "debit_amount": 0, "credit_amount": 19500}	2026-07-01 14:38:26.665865+00
56	bot_aliases	gofood	INSERT	\N	{"alias": "gofood", "is_active": true, "created_at": "2026-07-03T11:14:55.841464+00:00", "updated_at": "2026-07-03T11:14:55.841464+00:00", "updated_by": null, "account_code": "5110", "deactivated_at": null}	2026-07-03 11:14:55.841464+00
28	transactions	KK-2026-07-007	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-02T07:18:27.984441+00:00", "doc_number": "KK-2026-07-007", "description": "Naspad", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-02"}	2026-07-02 07:18:27.984441+00
29	journal_lines	20	INSERT	\N	{"id": 20, "doc_number": "KK-2026-07-007", "line_order": 1, "account_code": "5110", "debit_amount": 15000, "credit_amount": 0}	2026-07-02 07:18:27.984441+00
30	journal_lines	21	INSERT	\N	{"id": 21, "doc_number": "KK-2026-07-007", "line_order": 2, "account_code": "1130", "debit_amount": 0, "credit_amount": 15000}	2026-07-02 07:18:27.984441+00
31	transactions	KK-2026-07-008	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-02T07:19:13.44476+00:00", "doc_number": "KK-2026-07-008", "description": "Es dancow", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-02"}	2026-07-02 07:19:13.44476+00
32	journal_lines	22	INSERT	\N	{"id": 22, "doc_number": "KK-2026-07-008", "line_order": 1, "account_code": "5120", "debit_amount": 10000, "credit_amount": 0}	2026-07-02 07:19:13.44476+00
33	journal_lines	23	INSERT	\N	{"id": 23, "doc_number": "KK-2026-07-008", "line_order": 2, "account_code": "1130", "debit_amount": 0, "credit_amount": 10000}	2026-07-02 07:19:13.44476+00
34	transactions	KK-2026-07-009	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-02T15:57:00.535477+00:00", "doc_number": "KK-2026-07-009", "description": "Rokok", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-02"}	2026-07-02 15:57:00.535477+00
35	journal_lines	24	INSERT	\N	{"id": 24, "doc_number": "KK-2026-07-009", "line_order": 1, "account_code": "5130", "debit_amount": 23000, "credit_amount": 0}	2026-07-02 15:57:00.535477+00
36	journal_lines	25	INSERT	\N	{"id": 25, "doc_number": "KK-2026-07-009", "line_order": 2, "account_code": "1130", "debit_amount": 0, "credit_amount": 23000}	2026-07-02 15:57:00.535477+00
37	transactions	KK-2026-07-010	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-02T15:58:00.69679+00:00", "doc_number": "KK-2026-07-010", "description": "Ayam madu", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-02"}	2026-07-02 15:58:00.69679+00
38	journal_lines	26	INSERT	\N	{"id": 26, "doc_number": "KK-2026-07-010", "line_order": 1, "account_code": "5110", "debit_amount": 19500, "credit_amount": 0}	2026-07-02 15:58:00.69679+00
39	journal_lines	27	INSERT	\N	{"id": 27, "doc_number": "KK-2026-07-010", "line_order": 2, "account_code": "1130", "debit_amount": 0, "credit_amount": 19500}	2026-07-02 15:58:00.69679+00
40	bot_settings	receipt_default_expense	INSERT	\N	{"key": "receipt_default_expense", "notes": "Akun beban default hasil OCR kalau merchant tidak dikenali (catch-all)", "value": "9999"}	2026-07-03 11:14:55.841464+00
41	bot_settings	receipt_min_confidence	INSERT	\N	{"key": "receipt_min_confidence", "notes": "Skor minimum (0-100) agar bot tawarkan simpan; di bawah ini minta input manual", "value": "50"}	2026-07-03 11:14:55.841464+00
42	bot_aliases	indomaret	INSERT	\N	{"alias": "indomaret", "is_active": true, "created_at": "2026-07-03T11:14:55.841464+00:00", "updated_at": "2026-07-03T11:14:55.841464+00:00", "updated_by": null, "account_code": "5130", "deactivated_at": null}	2026-07-03 11:14:55.841464+00
43	bot_aliases	alfamart	INSERT	\N	{"alias": "alfamart", "is_active": true, "created_at": "2026-07-03T11:14:55.841464+00:00", "updated_at": "2026-07-03T11:14:55.841464+00:00", "updated_by": null, "account_code": "5130", "deactivated_at": null}	2026-07-03 11:14:55.841464+00
44	bot_aliases	alfamidi	INSERT	\N	{"alias": "alfamidi", "is_active": true, "created_at": "2026-07-03T11:14:55.841464+00:00", "updated_at": "2026-07-03T11:14:55.841464+00:00", "updated_by": null, "account_code": "5130", "deactivated_at": null}	2026-07-03 11:14:55.841464+00
45	bot_aliases	superindo	INSERT	\N	{"alias": "superindo", "is_active": true, "created_at": "2026-07-03T11:14:55.841464+00:00", "updated_at": "2026-07-03T11:14:55.841464+00:00", "updated_by": null, "account_code": "5640", "deactivated_at": null}	2026-07-03 11:14:55.841464+00
46	bot_aliases	hypermart	INSERT	\N	{"alias": "hypermart", "is_active": true, "created_at": "2026-07-03T11:14:55.841464+00:00", "updated_at": "2026-07-03T11:14:55.841464+00:00", "updated_by": null, "account_code": "5640", "deactivated_at": null}	2026-07-03 11:14:55.841464+00
47	bot_aliases	transmart	INSERT	\N	{"alias": "transmart", "is_active": true, "created_at": "2026-07-03T11:14:55.841464+00:00", "updated_at": "2026-07-03T11:14:55.841464+00:00", "updated_by": null, "account_code": "5640", "deactivated_at": null}	2026-07-03 11:14:55.841464+00
48	bot_aliases	warung	INSERT	\N	{"alias": "warung", "is_active": true, "created_at": "2026-07-03T11:14:55.841464+00:00", "updated_at": "2026-07-03T11:14:55.841464+00:00", "updated_by": null, "account_code": "5110", "deactivated_at": null}	2026-07-03 11:14:55.841464+00
49	bot_aliases	resto	INSERT	\N	{"alias": "resto", "is_active": true, "created_at": "2026-07-03T11:14:55.841464+00:00", "updated_at": "2026-07-03T11:14:55.841464+00:00", "updated_by": null, "account_code": "5110", "deactivated_at": null}	2026-07-03 11:14:55.841464+00
50	bot_aliases	restoran	INSERT	\N	{"alias": "restoran", "is_active": true, "created_at": "2026-07-03T11:14:55.841464+00:00", "updated_at": "2026-07-03T11:14:55.841464+00:00", "updated_by": null, "account_code": "5110", "deactivated_at": null}	2026-07-03 11:14:55.841464+00
51	bot_aliases	kfc	INSERT	\N	{"alias": "kfc", "is_active": true, "created_at": "2026-07-03T11:14:55.841464+00:00", "updated_at": "2026-07-03T11:14:55.841464+00:00", "updated_by": null, "account_code": "5110", "deactivated_at": null}	2026-07-03 11:14:55.841464+00
52	bot_aliases	mcd	INSERT	\N	{"alias": "mcd", "is_active": true, "created_at": "2026-07-03T11:14:55.841464+00:00", "updated_at": "2026-07-03T11:14:55.841464+00:00", "updated_by": null, "account_code": "5110", "deactivated_at": null}	2026-07-03 11:14:55.841464+00
53	bot_aliases	mcdonald	INSERT	\N	{"alias": "mcdonald", "is_active": true, "created_at": "2026-07-03T11:14:55.841464+00:00", "updated_at": "2026-07-03T11:14:55.841464+00:00", "updated_by": null, "account_code": "5110", "deactivated_at": null}	2026-07-03 11:14:55.841464+00
54	bot_aliases	starbucks	INSERT	\N	{"alias": "starbucks", "is_active": true, "created_at": "2026-07-03T11:14:55.841464+00:00", "updated_at": "2026-07-03T11:14:55.841464+00:00", "updated_by": null, "account_code": "5120", "deactivated_at": null}	2026-07-03 11:14:55.841464+00
55	bot_aliases	gojek	INSERT	\N	{"alias": "gojek", "is_active": true, "created_at": "2026-07-03T11:14:55.841464+00:00", "updated_at": "2026-07-03T11:14:55.841464+00:00", "updated_by": null, "account_code": "5220", "deactivated_at": null}	2026-07-03 11:14:55.841464+00
57	bot_aliases	grab	INSERT	\N	{"alias": "grab", "is_active": true, "created_at": "2026-07-03T11:14:55.841464+00:00", "updated_at": "2026-07-03T11:14:55.841464+00:00", "updated_by": null, "account_code": "5220", "deactivated_at": null}	2026-07-03 11:14:55.841464+00
58	bot_aliases	grabfood	INSERT	\N	{"alias": "grabfood", "is_active": true, "created_at": "2026-07-03T11:14:55.841464+00:00", "updated_at": "2026-07-03T11:14:55.841464+00:00", "updated_by": null, "account_code": "5110", "deactivated_at": null}	2026-07-03 11:14:55.841464+00
59	bot_aliases	shopeefood	INSERT	\N	{"alias": "shopeefood", "is_active": true, "created_at": "2026-07-03T11:14:55.841464+00:00", "updated_at": "2026-07-03T11:14:55.841464+00:00", "updated_by": null, "account_code": "5110", "deactivated_at": null}	2026-07-03 11:14:55.841464+00
60	bot_aliases	pertamina	INSERT	\N	{"alias": "pertamina", "is_active": true, "created_at": "2026-07-03T11:14:55.841464+00:00", "updated_at": "2026-07-03T11:14:55.841464+00:00", "updated_by": null, "account_code": "5210", "deactivated_at": null}	2026-07-03 11:14:55.841464+00
61	bot_aliases	spbu	INSERT	\N	{"alias": "spbu", "is_active": true, "created_at": "2026-07-03T11:14:55.841464+00:00", "updated_at": "2026-07-03T11:14:55.841464+00:00", "updated_by": null, "account_code": "5210", "deactivated_at": null}	2026-07-03 11:14:55.841464+00
62	bot_aliases	shell	INSERT	\N	{"alias": "shell", "is_active": true, "created_at": "2026-07-03T11:14:55.841464+00:00", "updated_at": "2026-07-03T11:14:55.841464+00:00", "updated_by": null, "account_code": "5210", "deactivated_at": null}	2026-07-03 11:14:55.841464+00
63	bot_aliases	pln	INSERT	\N	{"alias": "pln", "is_active": true, "created_at": "2026-07-03T11:14:55.841464+00:00", "updated_at": "2026-07-03T11:14:55.841464+00:00", "updated_by": null, "account_code": "5620", "deactivated_at": null}	2026-07-03 11:14:55.841464+00
64	bot_aliases	pdam	INSERT	\N	{"alias": "pdam", "is_active": true, "created_at": "2026-07-03T11:14:55.841464+00:00", "updated_at": "2026-07-03T11:14:55.841464+00:00", "updated_by": null, "account_code": "5630", "deactivated_at": null}	2026-07-03 11:14:55.841464+00
65	bot_aliases	apotek	INSERT	\N	{"alias": "apotek", "is_active": true, "created_at": "2026-07-03T11:14:55.841464+00:00", "updated_at": "2026-07-03T11:14:55.841464+00:00", "updated_by": null, "account_code": "5410", "deactivated_at": null}	2026-07-03 11:14:55.841464+00
66	bot_aliases	kimia farma	INSERT	\N	{"alias": "kimia farma", "is_active": true, "created_at": "2026-07-03T11:14:55.841464+00:00", "updated_at": "2026-07-03T11:14:55.841464+00:00", "updated_by": null, "account_code": "5410", "deactivated_at": null}	2026-07-03 11:14:55.841464+00
67	bot_aliases	k24	INSERT	\N	{"alias": "k24", "is_active": true, "created_at": "2026-07-03T11:14:55.841464+00:00", "updated_at": "2026-07-03T11:14:55.841464+00:00", "updated_by": null, "account_code": "5410", "deactivated_at": null}	2026-07-03 11:14:55.841464+00
68	transactions	KK-2026-07-011	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-03T15:17:26.382494+00:00", "doc_number": "KK-2026-07-011", "description": "Naspad", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-03"}	2026-07-03 15:17:26.382494+00
69	journal_lines	28	INSERT	\N	{"id": 28, "doc_number": "KK-2026-07-011", "line_order": 1, "account_code": "5110", "debit_amount": 15000, "credit_amount": 0}	2026-07-03 15:17:26.382494+00
70	journal_lines	29	INSERT	\N	{"id": 29, "doc_number": "KK-2026-07-011", "line_order": 2, "account_code": "1130", "debit_amount": 0, "credit_amount": 15000}	2026-07-03 15:17:26.382494+00
71	transactions	KK-2026-07-012	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-03T15:18:25.359677+00:00", "doc_number": "KK-2026-07-012", "description": "Es dancow", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-03"}	2026-07-03 15:18:25.359677+00
72	journal_lines	30	INSERT	\N	{"id": 30, "doc_number": "KK-2026-07-012", "line_order": 1, "account_code": "5120", "debit_amount": 10000, "credit_amount": 0}	2026-07-03 15:18:25.359677+00
73	journal_lines	31	INSERT	\N	{"id": 31, "doc_number": "KK-2026-07-012", "line_order": 2, "account_code": "1130", "debit_amount": 0, "credit_amount": 10000}	2026-07-03 15:18:25.359677+00
74	transactions	KK-2026-07-013	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-04T13:24:51.184206+00:00", "doc_number": "KK-2026-07-013", "description": "Rokok", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-04"}	2026-07-04 13:24:51.184206+00
75	journal_lines	32	INSERT	\N	{"id": 32, "doc_number": "KK-2026-07-013", "line_order": 1, "account_code": "5130", "debit_amount": 23000, "credit_amount": 0}	2026-07-04 13:24:51.184206+00
76	journal_lines	33	INSERT	\N	{"id": 33, "doc_number": "KK-2026-07-013", "line_order": 2, "account_code": "1130", "debit_amount": 0, "credit_amount": 23000}	2026-07-04 13:24:51.184206+00
77	transactions	KK-2026-07-014	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-06T03:57:58.377991+00:00", "doc_number": "KK-2026-07-014", "description": "Rokok", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-06"}	2026-07-06 03:57:58.377991+00
78	journal_lines	34	INSERT	\N	{"id": 34, "doc_number": "KK-2026-07-014", "line_order": 1, "account_code": "5130", "debit_amount": 27, "credit_amount": 0}	2026-07-06 03:57:58.377991+00
79	journal_lines	35	INSERT	\N	{"id": 35, "doc_number": "KK-2026-07-014", "line_order": 2, "account_code": "1130", "debit_amount": 0, "credit_amount": 27}	2026-07-06 03:57:58.377991+00
80	transactions	KK-2026-07-015	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-07T16:57:07.352069+00:00", "doc_number": "KK-2026-07-015", "description": "Rokok", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-07"}	2026-07-07 16:57:07.352069+00
81	journal_lines	36	INSERT	\N	{"id": 36, "doc_number": "KK-2026-07-015", "line_order": 1, "account_code": "5130", "debit_amount": 23000, "credit_amount": 0}	2026-07-07 16:57:07.352069+00
82	journal_lines	37	INSERT	\N	{"id": 37, "doc_number": "KK-2026-07-015", "line_order": 2, "account_code": "1130", "debit_amount": 0, "credit_amount": 23000}	2026-07-07 16:57:07.352069+00
83	transactions	KK-2026-07-016	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-07T16:57:45.425028+00:00", "doc_number": "KK-2026-07-016", "description": "Naspad", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-07"}	2026-07-07 16:57:45.425028+00
84	journal_lines	38	INSERT	\N	{"id": 38, "doc_number": "KK-2026-07-016", "line_order": 1, "account_code": "5130", "debit_amount": 15000, "credit_amount": 0}	2026-07-07 16:57:45.425028+00
85	journal_lines	39	INSERT	\N	{"id": 39, "doc_number": "KK-2026-07-016", "line_order": 2, "account_code": "1130", "debit_amount": 0, "credit_amount": 15000}	2026-07-07 16:57:45.425028+00
86	transactions	KK-2026-07-017	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-07T16:58:57.905141+00:00", "doc_number": "KK-2026-07-017", "description": "Rokok", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-07"}	2026-07-07 16:58:57.905141+00
87	journal_lines	40	INSERT	\N	{"id": 40, "doc_number": "KK-2026-07-017", "line_order": 1, "account_code": "5130", "debit_amount": 26973, "credit_amount": 0}	2026-07-07 16:58:57.905141+00
88	journal_lines	41	INSERT	\N	{"id": 41, "doc_number": "KK-2026-07-017", "line_order": 2, "account_code": "1130", "debit_amount": 0, "credit_amount": 26973}	2026-07-07 16:58:57.905141+00
89	transactions	KK-2026-07-018	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-08T19:04:20.796326+00:00", "doc_number": "KK-2026-07-018", "description": "Naspad", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-09"}	2026-07-08 19:04:20.796326+00
90	journal_lines	42	INSERT	\N	{"id": 42, "doc_number": "KK-2026-07-018", "line_order": 1, "account_code": "5110", "debit_amount": 15000, "credit_amount": 0}	2026-07-08 19:04:20.796326+00
91	journal_lines	43	INSERT	\N	{"id": 43, "doc_number": "KK-2026-07-018", "line_order": 2, "account_code": "1130", "debit_amount": 0, "credit_amount": 15000}	2026-07-08 19:04:20.796326+00
92	transactions	KK-2026-07-019	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-08T19:07:07.481262+00:00", "doc_number": "KK-2026-07-019", "description": "Minuman", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-09"}	2026-07-08 19:07:07.481262+00
93	journal_lines	44	INSERT	\N	{"id": 44, "doc_number": "KK-2026-07-019", "line_order": 1, "account_code": "5120", "debit_amount": 10000, "credit_amount": 0}	2026-07-08 19:07:07.481262+00
94	journal_lines	45	INSERT	\N	{"id": 45, "doc_number": "KK-2026-07-019", "line_order": 2, "account_code": "1130", "debit_amount": 0, "credit_amount": 10000}	2026-07-08 19:07:07.481262+00
95	transactions	KK-2026-07-020	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-08T19:08:41.2619+00:00", "doc_number": "KK-2026-07-020", "description": "Rokok", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-09"}	2026-07-08 19:08:41.2619+00
96	journal_lines	46	INSERT	\N	{"id": 46, "doc_number": "KK-2026-07-020", "line_order": 1, "account_code": "5130", "debit_amount": 23000, "credit_amount": 0}	2026-07-08 19:08:41.2619+00
97	journal_lines	47	INSERT	\N	{"id": 47, "doc_number": "KK-2026-07-020", "line_order": 2, "account_code": "1130", "debit_amount": 0, "credit_amount": 23000}	2026-07-08 19:08:41.2619+00
98	transactions	KK-2026-07-021	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-08T19:11:37.726341+00:00", "doc_number": "KK-2026-07-021", "description": "Traktir suchy", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-09"}	2026-07-08 19:11:37.726341+00
99	journal_lines	48	INSERT	\N	{"id": 48, "doc_number": "KK-2026-07-021", "line_order": 1, "account_code": "5740", "debit_amount": 100000, "credit_amount": 0}	2026-07-08 19:11:37.726341+00
100	journal_lines	49	INSERT	\N	{"id": 49, "doc_number": "KK-2026-07-021", "line_order": 2, "account_code": "1130", "debit_amount": 0, "credit_amount": 100000}	2026-07-08 19:11:37.726341+00
101	bot_settings	currency_preference	INSERT	\N	{"key": "currency_preference", "notes": "Mata uang default tampilan (IDR/USD/SGD/dst)", "value": "IDR"}	2026-07-08 19:53:10.923861+00
102	bot_settings	timezone	INSERT	\N	{"key": "timezone", "notes": "Timezone untuk cron & laporan terjadwal", "value": "Asia/Jakarta"}	2026-07-08 19:53:10.923861+00
103	bot_settings	daily_report_enabled	INSERT	\N	{"key": "daily_report_enabled", "notes": "Aktif/nonaktifkan laporan harian jam 9 pagi", "value": "true"}	2026-07-08 19:53:10.923861+00
104	bot_settings	weekly_report_enabled	INSERT	\N	{"key": "weekly_report_enabled", "notes": "Aktif/nonaktifkan laporan mingguan (Minggu)", "value": "true"}	2026-07-08 19:53:10.923861+00
105	bot_settings	alert_sensitivity	INSERT	\N	{"key": "alert_sensitivity", "notes": "Sensitivitas deteksi anomali: strict/normal/relaxed", "value": "normal"}	2026-07-08 19:53:10.923861+00
106	bot_settings	rate_limit_per_minute	INSERT	\N	{"key": "rate_limit_per_minute", "notes": "Maks pesan bot per user per menit sebelum ditolak", "value": "20"}	2026-07-08 19:53:10.923861+00
107	bot_settings	budget_alert_throttle_mins	INSERT	\N	{"key": "budget_alert_throttle_mins", "notes": "Jarak minimum antar alert budget per kategori (menit)", "value": "120"}	2026-07-08 19:53:10.923861+00
108	transactions	KK-2026-07-022	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-09T12:46:37.296682+00:00", "doc_number": "KK-2026-07-022", "description": "Rincian Transaksi", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-09"}	2026-07-09 12:46:37.296682+00
109	journal_lines	50	INSERT	\N	{"id": 50, "doc_number": "KK-2026-07-022", "line_order": 1, "account_code": "9999", "debit_amount": 23000, "credit_amount": 0}	2026-07-09 12:46:37.296682+00
110	journal_lines	51	INSERT	\N	{"id": 51, "doc_number": "KK-2026-07-022", "line_order": 2, "account_code": "1130", "debit_amount": 0, "credit_amount": 23000}	2026-07-09 12:46:37.296682+00
111	transactions	KK-2026-07-023	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-10T09:46:02.142762+00:00", "doc_number": "KK-2026-07-023", "description": "Ayam bakar madu", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-10"}	2026-07-10 09:46:02.142762+00
112	journal_lines	52	INSERT	\N	{"id": 52, "doc_number": "KK-2026-07-023", "line_order": 1, "account_code": "5110", "debit_amount": 19500, "credit_amount": 0}	2026-07-10 09:46:02.142762+00
113	journal_lines	53	INSERT	\N	{"id": 53, "doc_number": "KK-2026-07-023", "line_order": 2, "account_code": "1130", "debit_amount": 0, "credit_amount": 19500}	2026-07-10 09:46:02.142762+00
114	transactions	KK-2026-07-024	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-10T09:46:51.321534+00:00", "doc_number": "KK-2026-07-024", "description": "Es dancow", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-10"}	2026-07-10 09:46:51.321534+00
115	journal_lines	54	INSERT	\N	{"id": 54, "doc_number": "KK-2026-07-024", "line_order": 1, "account_code": "5120", "debit_amount": 10000, "credit_amount": 0}	2026-07-10 09:46:51.321534+00
116	journal_lines	55	INSERT	\N	{"id": 55, "doc_number": "KK-2026-07-024", "line_order": 2, "account_code": "1130", "debit_amount": 0, "credit_amount": 10000}	2026-07-10 09:46:51.321534+00
117	transactions	KK-2026-07-025	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-10T14:32:54.817059+00:00", "doc_number": "KK-2026-07-025", "description": "Langganan Claude pro", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-10"}	2026-07-10 14:32:54.817059+00
118	journal_lines	56	INSERT	\N	{"id": 56, "doc_number": "KK-2026-07-025", "line_order": 1, "account_code": "5530", "debit_amount": 300000, "credit_amount": 0}	2026-07-10 14:32:54.817059+00
119	journal_lines	57	INSERT	\N	{"id": 57, "doc_number": "KK-2026-07-025", "line_order": 2, "account_code": "1120", "debit_amount": 0, "credit_amount": 300000}	2026-07-10 14:32:54.817059+00
120	transactions	KK-2026-07-026	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-10T19:34:25.227006+00:00", "doc_number": "KK-2026-07-026", "description": "Insole arch support", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-11"}	2026-07-10 19:34:25.227006+00
121	journal_lines	58	INSERT	\N	{"id": 58, "doc_number": "KK-2026-07-026", "line_order": 1, "account_code": "5540", "debit_amount": 63538, "credit_amount": 0}	2026-07-10 19:34:25.227006+00
122	journal_lines	59	INSERT	\N	{"id": 59, "doc_number": "KK-2026-07-026", "line_order": 2, "account_code": "1120", "debit_amount": 0, "credit_amount": 63538}	2026-07-10 19:34:25.227006+00
123	transactions	KK-2026-07-027	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-10T20:18:07.678321+00:00", "doc_number": "KK-2026-07-027", "description": "Skip", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-11"}	2026-07-10 20:18:07.678321+00
124	journal_lines	60	INSERT	\N	{"id": 60, "doc_number": "KK-2026-07-027", "line_order": 1, "account_code": "9999", "debit_amount": 175000, "credit_amount": 0}	2026-07-10 20:18:07.678321+00
125	journal_lines	61	INSERT	\N	{"id": 61, "doc_number": "KK-2026-07-027", "line_order": 2, "account_code": "1120", "debit_amount": 0, "credit_amount": 175000}	2026-07-10 20:18:07.678321+00
126	transactions	KM-2026-07-001	INSERT	\N	{"status": "POSTED", "doc_type": "KM", "created_at": "2026-07-10T20:18:45.740027+00:00", "doc_number": "KM-2026-07-001", "description": null, "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-11"}	2026-07-10 20:18:45.740027+00
127	journal_lines	62	INSERT	\N	{"id": 62, "doc_number": "KM-2026-07-001", "line_order": 1, "account_code": "1120", "debit_amount": 203000, "credit_amount": 0}	2026-07-10 20:18:45.740027+00
128	journal_lines	63	INSERT	\N	{"id": 63, "doc_number": "KM-2026-07-001", "line_order": 2, "account_code": "4390", "debit_amount": 0, "credit_amount": 203000}	2026-07-10 20:18:45.740027+00
129	transactions	KM-2026-07-002	INSERT	\N	{"status": "POSTED", "doc_type": "KM", "created_at": "2026-07-10T20:55:26.05947+00:00", "doc_number": "KM-2026-07-002", "description": null, "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-11"}	2026-07-10 20:55:26.05947+00
130	journal_lines	64	INSERT	\N	{"id": 64, "doc_number": "KM-2026-07-002", "line_order": 1, "account_code": "1120", "debit_amount": 29000, "credit_amount": 0}	2026-07-10 20:55:26.05947+00
131	journal_lines	65	INSERT	\N	{"id": 65, "doc_number": "KM-2026-07-002", "line_order": 2, "account_code": "4390", "debit_amount": 0, "credit_amount": 29000}	2026-07-10 20:55:26.05947+00
132	transactions	KK-2026-07-028	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-11T10:46:12.545505+00:00", "doc_number": "KK-2026-07-028", "description": "Domain website", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-11"}	2026-07-11 10:46:12.545505+00
133	journal_lines	66	INSERT	\N	{"id": 66, "doc_number": "KK-2026-07-028", "line_order": 1, "account_code": "5530", "debit_amount": 13049, "credit_amount": 0}	2026-07-11 10:46:12.545505+00
134	journal_lines	67	INSERT	\N	{"id": 67, "doc_number": "KK-2026-07-028", "line_order": 2, "account_code": "1130", "debit_amount": 0, "credit_amount": 13049}	2026-07-11 10:46:12.545505+00
135	transactions	KK-2026-07-029	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-11T10:48:02.904774+00:00", "doc_number": "KK-2026-07-029", "description": "Rokok", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-11"}	2026-07-11 10:48:02.904774+00
136	journal_lines	68	INSERT	\N	{"id": 68, "doc_number": "KK-2026-07-029", "line_order": 1, "account_code": "5130", "debit_amount": 27000, "credit_amount": 0}	2026-07-11 10:48:02.904774+00
137	journal_lines	69	INSERT	\N	{"id": 69, "doc_number": "KK-2026-07-029", "line_order": 2, "account_code": "1130", "debit_amount": 0, "credit_amount": 27000}	2026-07-11 10:48:02.904774+00
138	transactions	KK-2026-07-030	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-11T10:49:01.76179+00:00", "doc_number": "KK-2026-07-030", "description": "Ayam geprek", "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-11"}	2026-07-11 10:49:01.76179+00
139	journal_lines	70	INSERT	\N	{"id": 70, "doc_number": "KK-2026-07-030", "line_order": 1, "account_code": "5110", "debit_amount": 16000, "credit_amount": 0}	2026-07-11 10:49:01.76179+00
140	journal_lines	71	INSERT	\N	{"id": 71, "doc_number": "KK-2026-07-030", "line_order": 2, "account_code": "1130", "debit_amount": 0, "credit_amount": 16000}	2026-07-11 10:49:01.76179+00
141	transactions	KK-2026-07-031	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-11T12:57:52.817003+00:00", "doc_number": "KK-2026-07-031", "description": null, "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-11"}	2026-07-11 12:57:52.817003+00
142	journal_lines	72	INSERT	\N	{"id": 72, "doc_number": "KK-2026-07-031", "line_order": 1, "account_code": "9999", "debit_amount": 43451, "credit_amount": 0}	2026-07-11 12:57:52.817003+00
143	journal_lines	73	INSERT	\N	{"id": 73, "doc_number": "KK-2026-07-031", "line_order": 2, "account_code": "1130", "debit_amount": 0, "credit_amount": 43451}	2026-07-11 12:57:52.817003+00
144	transactions	KK-2026-07-032	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-11T12:59:07.006115+00:00", "doc_number": "KK-2026-07-032", "description": null, "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-11"}	2026-07-11 12:59:07.006115+00
145	journal_lines	74	INSERT	\N	{"id": 74, "doc_number": "KK-2026-07-032", "line_order": 1, "account_code": "5710", "debit_amount": 815, "credit_amount": 0}	2026-07-11 12:59:07.006115+00
146	journal_lines	75	INSERT	\N	{"id": 75, "doc_number": "KK-2026-07-032", "line_order": 2, "account_code": "1120", "debit_amount": 0, "credit_amount": 815}	2026-07-11 12:59:07.006115+00
147	transactions	KK-2026-07-033	INSERT	\N	{"status": "POSTED", "doc_type": "KK", "created_at": "2026-07-11T13:00:09.610418+00:00", "doc_number": "KK-2026-07-033", "description": null, "is_reversal": false, "period_year": 2026, "input_source": "telegram", "period_month": 7, "reversal_of_doc": null, "transaction_date": "2026-07-11"}	2026-07-11 13:00:09.610418+00
148	journal_lines	76	INSERT	\N	{"id": 76, "doc_number": "KK-2026-07-033", "line_order": 1, "account_code": "5710", "debit_amount": 814000, "credit_amount": 0}	2026-07-11 13:00:09.610418+00
149	journal_lines	77	INSERT	\N	{"id": 77, "doc_number": "KK-2026-07-033", "line_order": 2, "account_code": "1120", "debit_amount": 0, "credit_amount": 814000}	2026-07-11 13:00:09.610418+00
\.


--
-- Data for Name: auth_tokens; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.auth_tokens (token, created_at, expires_at, used_at, is_used) FROM stdin;
NzI0ODI3MzUxMzo4NjAyZTc2ZTkyMTk5OTc2OjE3ODE1NTAxNTk.-BFm-gmGr2MV4V4cNgsbEPrcFbIQ_FNemsIwP23TrTw	2026-06-15 18:02:39.962963+00	2026-06-15 19:02:39.413447+00	2026-06-15 18:02:49.054325+00	t
NzI0ODI3MzUxMzo1MTg1NTBiOTI5ZDZmZDQ3OjE3ODE1NzkxNTA.Og2eopG_WNlKjJcf_rMaOWqpoEbJsjY78cLgxXyXnlY	2026-06-16 02:05:50.820831+00	2026-06-16 03:05:50.281013+00	2026-06-16 02:05:59.392772+00	t
NzI0ODI3MzUxMzo4NTgxZTQ5YTZjZDNmMTJlOjE3ODE1ODIwNzQ.0y6AXINR7VXPknXwrg9VRbqZzUpaahv8CagRCUo9I3I	2026-06-16 02:54:34.701003+00	2026-06-16 03:54:34.170259+00	2026-06-16 02:54:39.665907+00	t
NzI0ODI3MzUxMzpmOWQ0NjQxNThlNjhiZDNlOjE3ODE2MDAyNjU.8U2SY6VxC44OfujLovxdU9wU3wC3Wdw7vwAHwYLCeo8	2026-06-16 07:57:45.139526+00	2026-06-16 08:57:45.017713+00	2026-06-16 07:58:20.569904+00	t
NzI0ODI3MzUxMzpjYWMyYzRhNTNjOWQwNjBjOjE3ODE2NjY4MDA.U2kEKTJ4aZ759viU-2zeBKowyxWMw_WuGv9-Yw00Ouo	2026-06-17 02:26:40.666736+00	2026-06-17 03:26:40.553931+00	2026-06-17 02:26:51.292747+00	t
NzI0ODI3MzUxMzpjNjM4ZWY3ZGY1MDAzOTc1OjE3ODE2NjY5MTg.8hbTFVoJyV9JD_BjKPDeyoh7cYqZ-PIYx391Lcknt_w	2026-06-17 02:28:38.398077+00	2026-06-17 03:28:38.273639+00	2026-06-17 02:28:44.227285+00	t
NzI0ODI3MzUxMzozOGExZWEyM2M0YmYyMTQzOjE3ODE3NTg1MzM.i17HwIufOb0elygDLVEZsPC2QjbZhVwYva-XZIUD0EI	2026-06-18 03:55:34.091078+00	2026-06-18 04:55:33.527545+00	2026-06-18 03:55:42.352623+00	t
NzI0ODI3MzUxMzo4ODkxN2U4ZTMyY2Q0N2YwOjE3ODI4OTkwNTQ.B2aCjIhcHvcr_09BBbSWybzJVfXmEjIzpdIxChKq7lg	2026-07-01 08:44:15.034325+00	2026-07-01 09:44:14.499763+00	2026-07-01 08:44:24.360917+00	t
NzI0ODI3MzUxMzo1YzViMWFlNzRlOTc4YjFhOjE3ODM1MDgyMzE.KopGf18hNmb2BIj6_U0Za-qzMEZ-qFR_HpzllkQ4O8E	2026-07-08 09:57:12.376713+00	2026-07-08 10:57:11.789342+00	2026-07-08 09:57:19.37455+00	t
NzI0ODI3MzUxMzphMDU4N2FmNTAyMTQ1YjlmOjE3ODM1MDkyMjY.kNtxvw_c_KkXvcglvjXADhjV-LSubvsPcXlZayffUnE	2026-07-08 10:13:46.975376+00	2026-07-08 11:13:46.432439+00	2026-07-08 10:13:54.5671+00	t
NzI0ODI3MzUxMzplOWZjNTVjODAyZDljZWY1OjE3ODM1NDA5NTc.47zboN7_rUTtHAZ4rIMIVqSpy9VRO24DPOkuiyLLGaU	2026-07-08 19:02:38.467692+00	2026-07-08 20:02:37.917189+00	2026-07-08 19:02:50.475684+00	t
NzI0ODI3MzUxMzo5YTc4OTg0NjE0MmEyOTQyOjE3ODM1NDc1NTE.SxND0wI3LS09c8dqwNBa_4-Iv9WL8S9G5O8feuWw7yw	2026-07-08 20:52:32.277618+00	2026-07-08 21:52:31.744397+00	2026-07-08 20:52:44.328821+00	t
NzI0ODI3MzUxMzpmMWFkOTMzMWE2ODEzMjczOjE3ODM1NTAwNzQ.ZBvK7UHXyIj1YWJHHIYf3TIJUirPw1y1kUcryvX86IM	2026-07-08 21:34:34.710209+00	2026-07-08 22:34:34.182734+00	2026-07-08 21:34:42.44894+00	t
NzI0ODI3MzUxMzpmMzk4OWZiMjAwZDcyZmZkOjE3ODM1NTAyOTA.Ko1Fgtss6GGmxnosYTZ98QJVrlDe_S_fjY6QgkdsTzY	2026-07-08 21:38:11.503798+00	2026-07-08 22:38:10.955756+00	2026-07-08 21:38:16.991649+00	t
NzI0ODI3MzUxMzo1OWVlOWVmMDg4YjU0MjM0OjE3ODM1NzE5MDI.3m1LHVJUCCYEkl0_aUvjh4-NCMQyN4lI8dJ7f7UhfFc	2026-07-09 03:38:22.199506+00	2026-07-09 04:38:22.078866+00	2026-07-09 03:38:30.568793+00	t
NzI0ODI3MzUxMzpiODBhYzc1ZWUyNmM1MWFkOjE3ODM1NzQ1NzE.FYoqYCJmyJ_fncxCGgP_tkfW4_IHRflsWgkcdiKQbeM	2026-07-09 04:22:51.304661+00	2026-07-09 05:22:51.19789+00	2026-07-09 04:22:56.692963+00	t
NzI0ODI3MzUxMzo3Yzg2NTc4MTk0OWY2ZGRjOjE3ODM1ODAxMDY.MVI24BZMcym58pmovErfGQ856RLXLUU_CGe4BddKwkQ	2026-07-09 05:55:07.410794+00	2026-07-09 06:55:06.885821+00	2026-07-09 05:55:15.772305+00	t
NzI0ODI3MzUxMzpiZDA1NDkzYjA1NmY0YTgyOjE3ODM1ODY3NTc.2jO5IWYQ-QL51e5lHqqcQFWT2NN5KctvIB2oisLLxlY	2026-07-09 07:45:57.300828+00	2026-07-09 08:45:57.194169+00	2026-07-09 07:46:07.465793+00	t
NzI0ODI3MzUxMzo3NGExMGFkMjA4OTcxOTI1OjE3ODM1ODc3NTc.iyy0emmzlQyEQ9P6bK7xFayB0Wyga57gEo_g1MQDdF4	2026-07-09 08:02:38.02349+00	2026-07-09 09:02:37.919891+00	2026-07-09 08:03:02.655536+00	t
NzI0ODI3MzUxMzo3MWQwYjIyNTljYzAzZDhkOjE3ODM1OTAxNzM.rox3-BMqdPSSUKyJ5zSkAJHFozkNCiZNr2a7MsFyVWY	2026-07-09 08:42:54.327934+00	2026-07-09 09:42:53.806116+00	2026-07-09 08:43:02.420782+00	t
NzI0ODI3MzUxMzo1Zjc3ZDgyNjgxZWQzNDkyOjE3ODM1OTIxNjg.7wm6QtlqRuYf3LJio1tu-bhL-4m7SKcjWBi5pxOfvF0	2026-07-09 09:16:09.002199+00	2026-07-09 10:16:08.897488+00	2026-07-09 09:16:12.724263+00	t
NzI0ODI3MzUxMzo0Y2MzNmNiZTY2N2EzZjc0OjE3ODM2OTc4NjQ.Ig-isVhnGJzNM3pKs7nM1aUheiSMwzAgJwvPvYv4DHc	2026-07-10 14:37:44.559424+00	2026-07-10 15:37:44.027745+00	2026-07-10 14:37:51.144783+00	t
NzI0ODI3MzUxMzpkMTc2Y2JhMDE4ZmVhNWFjOjE3ODM3NDY5MTY.goojr78RfAFilK2iOLmeqGoQc6q_qcXPEdRdRRpNVhE	2026-07-11 04:15:17.465988+00	2026-07-11 05:15:16.94342+00	2026-07-11 04:15:26.253381+00	t
\.


--
-- Data for Name: bills; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.bills (id, name, amount, due_day, due_date, is_recurring, is_active, last_reminded_period, created_at) FROM stdin;
\.


--
-- Data for Name: bot_aliases; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.bot_aliases (alias, account_code, created_at, is_active, deactivated_at, updated_at, updated_by) FROM stdin;
makan	5110	2026-06-15 17:20:44.361662+00	t	\N	2026-06-16 02:32:32.682765+00	\N
kopi	5120	2026-06-15 17:20:44.361662+00	t	\N	2026-06-16 02:32:32.682765+00	\N
jajan	5130	2026-06-15 17:20:44.361662+00	t	\N	2026-06-16 02:32:32.682765+00	\N
bensin	5210	2026-06-15 17:20:44.361662+00	t	\N	2026-06-16 02:32:32.682765+00	\N
ojek	5220	2026-06-15 17:20:44.361662+00	t	\N	2026-06-16 02:32:32.682765+00	\N
pulsa	5310	2026-06-15 17:20:44.361662+00	t	\N	2026-06-16 02:32:32.682765+00	\N
wifi	5320	2026-06-15 17:20:44.361662+00	t	\N	2026-06-16 02:32:32.682765+00	\N
kos	5610	2026-06-15 17:20:44.361662+00	t	\N	2026-06-16 02:32:32.682765+00	\N
listrik	5620	2026-06-15 17:20:44.361662+00	t	\N	2026-06-16 02:32:32.682765+00	\N
claude	5530	2026-06-15 17:20:44.361662+00	t	\N	2026-06-16 02:32:32.682765+00	\N
zakat	5720	2026-06-15 17:20:44.361662+00	t	\N	2026-06-16 02:32:32.682765+00	\N
keluarga	5710	2026-06-15 17:20:44.361662+00	t	\N	2026-06-16 02:32:32.682765+00	\N
indomaret	5130	2026-07-03 11:14:55.841464+00	t	\N	2026-07-03 11:14:55.841464+00	\N
alfamart	5130	2026-07-03 11:14:55.841464+00	t	\N	2026-07-03 11:14:55.841464+00	\N
alfamidi	5130	2026-07-03 11:14:55.841464+00	t	\N	2026-07-03 11:14:55.841464+00	\N
superindo	5640	2026-07-03 11:14:55.841464+00	t	\N	2026-07-03 11:14:55.841464+00	\N
hypermart	5640	2026-07-03 11:14:55.841464+00	t	\N	2026-07-03 11:14:55.841464+00	\N
transmart	5640	2026-07-03 11:14:55.841464+00	t	\N	2026-07-03 11:14:55.841464+00	\N
warung	5110	2026-07-03 11:14:55.841464+00	t	\N	2026-07-03 11:14:55.841464+00	\N
resto	5110	2026-07-03 11:14:55.841464+00	t	\N	2026-07-03 11:14:55.841464+00	\N
restoran	5110	2026-07-03 11:14:55.841464+00	t	\N	2026-07-03 11:14:55.841464+00	\N
kfc	5110	2026-07-03 11:14:55.841464+00	t	\N	2026-07-03 11:14:55.841464+00	\N
mcd	5110	2026-07-03 11:14:55.841464+00	t	\N	2026-07-03 11:14:55.841464+00	\N
mcdonald	5110	2026-07-03 11:14:55.841464+00	t	\N	2026-07-03 11:14:55.841464+00	\N
starbucks	5120	2026-07-03 11:14:55.841464+00	t	\N	2026-07-03 11:14:55.841464+00	\N
gojek	5220	2026-07-03 11:14:55.841464+00	t	\N	2026-07-03 11:14:55.841464+00	\N
gofood	5110	2026-07-03 11:14:55.841464+00	t	\N	2026-07-03 11:14:55.841464+00	\N
grab	5220	2026-07-03 11:14:55.841464+00	t	\N	2026-07-03 11:14:55.841464+00	\N
grabfood	5110	2026-07-03 11:14:55.841464+00	t	\N	2026-07-03 11:14:55.841464+00	\N
shopeefood	5110	2026-07-03 11:14:55.841464+00	t	\N	2026-07-03 11:14:55.841464+00	\N
pertamina	5210	2026-07-03 11:14:55.841464+00	t	\N	2026-07-03 11:14:55.841464+00	\N
spbu	5210	2026-07-03 11:14:55.841464+00	t	\N	2026-07-03 11:14:55.841464+00	\N
shell	5210	2026-07-03 11:14:55.841464+00	t	\N	2026-07-03 11:14:55.841464+00	\N
pln	5620	2026-07-03 11:14:55.841464+00	t	\N	2026-07-03 11:14:55.841464+00	\N
pdam	5630	2026-07-03 11:14:55.841464+00	t	\N	2026-07-03 11:14:55.841464+00	\N
apotek	5410	2026-07-03 11:14:55.841464+00	t	\N	2026-07-03 11:14:55.841464+00	\N
kimia farma	5410	2026-07-03 11:14:55.841464+00	t	\N	2026-07-03 11:14:55.841464+00	\N
k24	5410	2026-07-03 11:14:55.841464+00	t	\N	2026-07-03 11:14:55.841464+00	\N
\.


--
-- Data for Name: bot_categories; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.bot_categories (id, name, emoji, category_type, parent_id, display_order, is_active) FROM stdin;
1	Konsumsi	🍔	expense	\N	1	t
2	Transport	🚌	expense	\N	2	t
3	Komunikasi	📱	expense	\N	3	t
4	Tempat Tinggal	🏠	expense	\N	4	t
5	Kesehatan	🏥	expense	\N	5	t
6	Pengembangan	📚	expense	\N	6	t
7	Sosial & Keluarga	👨‍👩‍👧	expense	\N	7	t
8	Finansial	💳	expense	\N	8	t
9	Lain-lain	📦	expense	\N	9	t
10	Honor/Upah	💼	income	\N	1	t
11	Gaji	💵	income	\N	2	t
12	Bunga/Investasi	📈	income	\N	3	t
13	Dividen	💰	income	\N	4	t
14	Lain-lain Pendapatan	📦	income	\N	5	t
\.


--
-- Data for Name: bot_category_accounts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.bot_category_accounts (category_id, account_code, display_order) FROM stdin;
1	5110	1
1	5120	2
1	5130	3
2	5210	1
2	5220	2
2	5230	3
2	5240	4
2	5250	5
3	5310	1
3	5320	2
4	5610	1
4	5620	2
4	5630	3
4	5640	4
5	5410	1
5	5420	2
5	5430	3
6	5510	1
6	5520	2
6	5530	3
6	5540	4
7	5710	1
7	5720	2
7	5730	3
7	5740	4
8	5810	1
8	5820	2
8	5830	3
9	5910	1
9	5920	2
9	5930	3
9	5990	4
9	9999	5
10	4110	1
11	4120	1
12	4310	1
13	4320	1
14	4330	1
14	4390	2
\.


--
-- Data for Name: bot_settings; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.bot_settings (key, value, notes) FROM stdin;
kas_kecil_account	1130	Akun kas kecil imprest (SeaBank)
auth_token_expiry_mins	60	Expiry magic link dashboard (menit)
session_days	30	Durasi session browser (hari)
state_timeout_mins	30	Timeout bot conversation state (menit)
owner_telegram_id		Telegram ID pemilik — diisi saat setup (atau pakai env OWNER_TELEGRAM_ID)
default_expense_source	1130	Akun sumber default pengeluaran (SeaBank)
default_income_dest	1120	Akun tujuan default pemasukan (BNI)
kas_kecil_source	1120	Sumber pengisian kas kecil (BNI)
savings_account	1140	Akun tabungan TBD
kas_kecil_target	500000	Target balance kas kecil = Rp 500.000
bi_fast_fee	2500	Fee BI-Fast default = Rp 2.500
receipt_default_expense	9999	Akun beban default hasil OCR kalau merchant tidak dikenali (catch-all)
receipt_min_confidence	50	Skor minimum (0-100) agar bot tawarkan simpan; di bawah ini minta input manual
currency_preference	IDR	Mata uang default tampilan (IDR/USD/SGD/dst)
timezone	Asia/Jakarta	Timezone untuk cron & laporan terjadwal
daily_report_enabled	true	Aktif/nonaktifkan laporan harian jam 9 pagi
weekly_report_enabled	true	Aktif/nonaktifkan laporan mingguan (Minggu)
alert_sensitivity	normal	Sensitivitas deteksi anomali: strict/normal/relaxed
rate_limit_per_minute	20	Maks pesan bot per user per menit sebelum ditolak
budget_alert_throttle_mins	120	Jarak minimum antar alert budget per kategori (menit)
\.


--
-- Data for Name: bot_state; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.bot_state (user_id, state, state_data, updated_at) FROM stdin;
7248273513	IDLE	{}	2026-07-15 07:32:59.413736+00
\.


--
-- Data for Name: budgets; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.budgets (account_code, monthly_limit, last_alert_at, created_at) FROM stdin;
\.


--
-- Data for Name: chart_of_accounts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.chart_of_accounts (code, parent_code, level, account_name, account_type, normal_balance, is_header, is_active, display_order, notes, is_custom) FROM stdin;
1000	\N	1	ASET	aset	debit	t	t	0	Header kelas	f
1100	1000	2	Kas & Setara Kas	aset	debit	t	t	0	Header kelompok	f
1110	1100	3	Kas Tunai	aset	debit	f	t	0	Aktif — uang tunai di tangan	f
1120	1100	3	Bank BNI (Kas Besar)	aset	debit	f	t	0	Aktif — rekening utama, income masuk sini	f
1130	1100	3	SeaBank (Kas Kecil Imprest)	aset	debit	f	t	0	Aktif — target Rp 500.000, pengeluaran harian	f
1140	1100	3	Bank Tabungan [TBD]	aset	debit	f	t	0	Aktif — ganti nama saat bank dipilih	f
1150	1100	3	Kas Kecil Usaha	aset	debit	f	t	0	DORMANT — template bisnis	f
1200	1000	2	Investasi JK Pendek	aset	debit	t	t	0	Header	f
1210	1200	3	Deposito	aset	debit	f	t	0	Aktif	f
1220	1200	3	Reksa Dana Pasar Uang	aset	debit	f	t	0	Aktif	f
1230	1200	3	Reksa Dana Campuran/Saham	aset	debit	f	t	0	Aktif	f
1240	1200	3	Saham	aset	debit	f	t	0	Aktif	f
1250	1200	3	SBN / Obligasi Negara	aset	debit	f	t	0	Aktif	f
1300	1000	2	Piutang	aset	debit	t	t	0	Header	f
1310	1300	3	Piutang Personal	aset	debit	f	t	0	Aktif	f
1320	1300	3	Piutang Usaha	aset	debit	f	t	0	DORMANT	f
1330	1300	3	Uang Muka Pembelian	aset	debit	f	t	0	DORMANT	f
1390	1300	3	Cadangan Kerugian Piutang	aset	credit	f	t	0	DORMANT — contra asset	f
1400	1000	2	Persediaan	aset	debit	t	t	0	Header	f
1410	1400	3	Persediaan Barang Dagang	aset	debit	f	t	0	DORMANT	f
1420	1400	3	Bahan Baku & Penolong	aset	debit	f	t	0	DORMANT	f
1500	1000	2	Biaya Dibayar Dimuka	aset	debit	t	t	0	Header	f
1510	1500	3	Sewa Dibayar Dimuka	aset	debit	f	t	0	Aktif	f
1520	1500	3	Asuransi Dibayar Dimuka	aset	debit	f	t	0	DORMANT	f
1590	1500	3	Lainnya Dibayar Dimuka	aset	debit	f	t	0	DORMANT	f
1700	1000	2	Investasi JK Panjang	aset	debit	t	t	0	Header	f
1710	1700	3	Saham Jangka Panjang	aset	debit	f	t	0	Aktif	f
1720	1700	3	Emas / Logam Mulia	aset	debit	f	t	0	Aktif	f
1730	1700	3	Reksa Dana Jangka Panjang	aset	debit	f	t	0	Aktif	f
1800	1000	2	Aset Tetap	aset	debit	t	t	0	Header	f
1810	1800	3	Kendaraan (Motor/Mobil)	aset	debit	f	t	0	Aktif	f
1820	1800	3	Peralatan Elektronik (Laptop, HP)	aset	debit	f	t	0	Aktif	f
1830	1800	3	Perabotan & Perlengkapan	aset	debit	f	t	0	Aktif	f
1840	1800	3	Mesin & Peralatan Usaha	aset	debit	f	t	0	DORMANT	f
1850	1800	3	Bangunan	aset	debit	f	t	0	DORMANT	f
1900	1000	2	Akumulasi Penyusutan	aset	credit	t	t	0	Header — contra asset	f
1910	1900	3	Akum. Peny. Kendaraan	aset	credit	f	t	0	Saldo=0 personal	f
1920	1900	3	Akum. Peny. Peralatan Elektronik	aset	credit	f	t	0	Saldo=0 personal	f
1930	1900	3	Akum. Peny. Perabotan	aset	credit	f	t	0	Saldo=0 personal	f
2000	\N	1	LIABILITAS	liabilitas	credit	t	t	0	Header kelas	f
2100	2000	2	Utang Jangka Pendek	liabilitas	credit	t	t	0	Header	f
2110	2100	3	Utang Usaha	liabilitas	credit	f	t	0	DORMANT	f
2120	2100	3	Kartu Kredit	liabilitas	credit	f	t	0	Saldo=0, template	f
2130	2100	3	SpayLater / Paylater	liabilitas	credit	f	t	0	Aktif — saldo=0 saat ini	f
2140	2100	3	Utang Personal / Informal	liabilitas	credit	f	t	0	Aktif	f
2200	2000	2	Biaya Masih Harus Dibayar	liabilitas	credit	t	t	0	Header	f
2210	2200	3	Utang Gaji	liabilitas	credit	f	t	0	DORMANT	f
2220	2200	3	Utang PPN	liabilitas	credit	f	t	0	DORMANT	f
2400	2000	2	Utang JK Panjang	liabilitas	credit	t	t	0	Header	f
2410	2400	3	KTA / Pinjaman Bank	liabilitas	credit	f	t	0	DORMANT	f
2420	2400	3	Kredit Kendaraan	liabilitas	credit	f	t	0	DORMANT	f
2430	2400	3	KPR	liabilitas	credit	f	t	0	DORMANT	f
3000	\N	1	EKUITAS	ekuitas	credit	t	t	0	Header kelas	f
3100	3000	2	Modal	ekuitas	credit	t	t	0	Header	f
3110	3100	3	Saldo Awal / Modal Awal	ekuitas	credit	f	t	0	Set oleh /setup wizard	f
3200	3000	2	Laba Ditahan	ekuitas	credit	t	t	0	Header	f
3210	3200	3	Laba Ditahan Tahun Lalu	ekuitas	credit	f	t	0	Diisi closing tahunan	f
3220	3200	3	Laba/Rugi Tahun Berjalan	ekuitas	credit	f	t	0	Calculated dari L/R	f
3300	3000	2	Prive / Distribusi	ekuitas	debit	t	t	0	Header — debit normal	f
3310	3300	3	Prive (Pengambilan Pribadi)	ekuitas	debit	f	t	0	Tarik uang untuk non-bisnis	f
4000	\N	1	PENDAPATAN	pendapatan	credit	t	t	0	Header kelas	f
4100	4000	2	Pendapatan Operasional	pendapatan	credit	t	t	0	Header	f
4110	4100	3	Honor / Upah Proyek	pendapatan	credit	f	t	0	Aktif	f
4120	4100	3	Gaji Tetap	pendapatan	credit	f	t	0	Aktif	f
4300	4000	2	Pendapatan Lain-lain	pendapatan	credit	t	t	0	Header	f
4310	4300	3	Bunga Tabungan / Deposito	pendapatan	credit	f	t	0	Aktif	f
4320	4300	3	Dividen Diterima	pendapatan	credit	f	t	0	Aktif	f
4330	4300	3	Keuntungan Penjualan Aset	pendapatan	credit	f	t	0	Aktif	f
4390	4300	3	Pendapatan Lain-lain	pendapatan	credit	f	t	0	Aktif	f
5000	\N	1	BEBAN PERSONAL	beban	debit	t	t	0	Header kelas	f
5100	5000	2	Beban Konsumsi	beban	debit	t	t	0	Header	f
5110	5100	3	Makan Harian	beban	debit	f	t	0	Aktif	f
5120	5100	3	Kopi & Minuman	beban	debit	f	t	0	Aktif	f
5130	5100	3	Jajan / Snack	beban	debit	f	t	0	Aktif	f
5200	5000	2	Beban Transportasi	beban	debit	t	t	0	Header	f
5210	5200	3	BBM / Bensin	beban	debit	f	t	0	Aktif	f
5220	5200	3	Ojek Online	beban	debit	f	t	0	Aktif	f
5230	5200	3	Angkutan Umum	beban	debit	f	t	0	Aktif	f
5240	5200	3	Parkir & Tol	beban	debit	f	t	0	Aktif	f
5250	5200	3	Servis & Perawatan Kendaraan	beban	debit	f	t	0	Aktif	f
5300	5000	2	Beban Komunikasi	beban	debit	t	t	0	Header	f
5310	5300	3	Pulsa & Data Internet HP	beban	debit	f	t	0	Aktif	f
5320	5300	3	Internet Rumah / WiFi	beban	debit	f	t	0	Aktif	f
5400	5000	2	Beban Kesehatan	beban	debit	t	t	0	Header	f
5410	5400	3	Obat-obatan	beban	debit	f	t	0	Aktif	f
5420	5400	3	Dokter / Klinik / RS	beban	debit	f	t	0	Aktif	f
5430	5400	3	Vitamin & Suplemen	beban	debit	f	t	0	Aktif	f
5500	5000	2	Beban Pengembangan Diri	beban	debit	t	t	0	Header	f
5510	5500	3	Buku & Referensi	beban	debit	f	t	0	Aktif	f
5520	5500	3	Kursus / Pelatihan	beban	debit	f	t	0	Aktif	f
5530	5500	3	Langganan Digital (Claude, dll)	beban	debit	f	t	0	Aktif	f
5540	5500	3	Alat Kerja & Perlengkapan	beban	debit	f	t	0	Aktif	f
5600	5000	2	Beban Tempat Tinggal	beban	debit	t	t	0	Header	f
5610	5600	3	Kos / Kontrakan	beban	debit	f	t	0	Aktif	f
5620	5600	3	Listrik	beban	debit	f	t	0	Aktif	f
5630	5600	3	Air	beban	debit	f	t	0	Aktif	f
5640	5600	3	Kebutuhan Rumah Tangga	beban	debit	f	t	0	Aktif	f
5700	5000	2	Beban Sosial & Keluarga	beban	debit	t	t	0	Header	f
5710	5700	3	Kiriman ke Keluarga (Ortu/Adik)	beban	debit	f	t	0	Aktif — BUKAN internal transfer!	f
5720	5700	3	Zakat / Sedekah / Infaq	beban	debit	f	t	0	Aktif	f
5730	5700	3	Hadiah & Kado	beban	debit	f	t	0	Aktif	f
5740	5700	3	Acara Sosial (Kondangan, dll)	beban	debit	f	t	0	Aktif	f
5800	5000	2	Beban Finansial	beban	debit	t	t	0	Header	f
5810	5800	3	Bunga Pinjaman / Cicilan	beban	debit	f	t	0	Aktif	f
5820	5800	3	Biaya Admin & Transfer Bank	beban	debit	f	t	0	Aktif — termasuk fee BI-Fast	f
5830	5800	3	Bunga Paylater / SpayLater	beban	debit	f	t	0	Aktif	f
5900	5000	2	Beban Lain-lain Personal	beban	debit	t	t	0	Header	f
5910	5900	3	Pakaian & Penampilan	beban	debit	f	t	0	Aktif	f
5920	5900	3	Rekreasi & Hiburan	beban	debit	f	t	0	Aktif	f
5930	5900	3	Olahraga (Sepeda, Badminton)	beban	debit	f	t	0	Aktif	f
5990	5900	3	Beban Tidak Terduga	beban	debit	f	t	0	Aktif	f
6000	\N	1	BEBAN USAHA	beban	debit	t	t	0	Header kelas — aktif saat mulai bisnis	f
6100	6000	2	HPP	beban	debit	t	t	0	Header	f
6110	6100	3	HPP Barang Dagang	beban	debit	f	t	0	DORMANT	f
6200	6000	2	Beban Gaji & SDM	beban	debit	t	t	0	Header	f
6210	6200	3	Gaji Karyawan	beban	debit	f	t	0	DORMANT	f
6220	6200	3	Tunjangan + BPJS	beban	debit	f	t	0	DORMANT	f
6300	6000	2	Beban Pemasaran	beban	debit	t	t	0	Header	f
6310	6300	3	Iklan & Promosi	beban	debit	f	t	0	DORMANT	f
6400	6000	2	Beban Operasional Usaha	beban	debit	t	t	0	Header	f
6410	6400	3	Sewa Tempat Usaha	beban	debit	f	t	0	DORMANT	f
6420	6400	3	Listrik & Internet (Usaha)	beban	debit	f	t	0	DORMANT	f
6500	6000	2	Beban Penyusutan	beban	debit	t	t	0	Header	f
6510	6500	3	Penyusutan Kendaraan	beban	debit	f	t	0	Aktif saat bisnis	f
6520	6500	3	Penyusutan Peralatan	beban	debit	f	t	0	Aktif saat bisnis	f
6700	6000	2	Beban Lain-lain Usaha	beban	debit	t	t	0	Header	f
6710	6700	3	Kerugian Penjualan Aset	beban	debit	f	t	0	DORMANT	f
9999	\N	3	Beban Tidak Terkategorikan	beban	debit	f	t	0	CATCH-ALL — semua yang tidak masuk kategori	f
\.


--
-- Data for Name: daily_log; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.daily_log (log_date, user_id, note, created_at, updated_at) FROM stdin;
2026-06-19	7248273513	Tidak ada transaksi	2026-06-19 16:04:00.805939+00	2026-06-19 16:03:59.623461+00
2026-06-20	7248273513	Tidak ada transaksi	2026-06-20 16:43:41.922991+00	2026-06-20 16:43:40.490963+00
2026-06-21	7248273513	Tidak ada transaksi	2026-06-21 15:10:38.975078+00	2026-06-21 15:10:37.640237+00
2026-06-22	7248273513	Tidak ada transaksi	2026-06-22 16:25:54.925975+00	2026-06-22 16:25:53.52405+00
2026-06-23	7248273513	Tidak ada transaksi	2026-06-23 14:35:19.058596+00	2026-06-23 14:35:17.614099+00
2026-06-24	7248273513	Tidak ada transaksi	2026-06-24 16:15:59.892816+00	2026-06-24 16:15:58.506281+00
2026-06-28	7248273513	Tidak ada transaksi	2026-06-28 16:40:14.172786+00	2026-06-28 16:40:12.829033+00
2026-06-29	7248273513	Tidak ada transaksi	2026-06-29 16:35:14.957637+00	2026-06-29 16:35:13.439348+00
2026-07-15	7248273513	Tidak ada transaksi	2026-07-15 07:33:00.192809+00	2026-07-15 07:33:00.076619+00
\.


--
-- Data for Name: goals; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.goals (id, name, target_amount, account_code, target_date, is_active, created_at) FROM stdin;
\.


--
-- Data for Name: journal_lines; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.journal_lines (id, doc_number, line_order, account_code, debit_amount, credit_amount) FROM stdin;
1	OB-2026-07-001	1	1120	2619552	0
2	OB-2026-07-001	2	1130	1	0
3	OB-2026-07-001	3	1110	1000	0
4	OB-2026-07-001	4	3110	0	2620553
5	KK-2026-07-001	1	5710	500000	0
6	KK-2026-07-001	2	1120	0	500000
7	KK-2026-07-002	1	9999	23500	0
8	KK-2026-07-002	2	1120	0	23500
9	KK-2026-07-003	1	5110	15000	0
10	KK-2026-07-003	2	1120	0	15000
11	KK-2026-07-004	1	5120	7000	0
12	KK-2026-07-004	2	1120	0	7000
13	KK-2026-07-005	1	5310	50000	0
14	KK-2026-07-005	2	1120	0	50000
15	TR-2026-07-001	1	1130	499999	0
16	TR-2026-07-001	2	5820	2500	0
17	TR-2026-07-001	3	1120	0	502499
18	KK-2026-07-006	1	5110	19500	0
19	KK-2026-07-006	2	1130	0	19500
20	KK-2026-07-007	1	5110	15000	0
21	KK-2026-07-007	2	1130	0	15000
22	KK-2026-07-008	1	5120	10000	0
23	KK-2026-07-008	2	1130	0	10000
24	KK-2026-07-009	1	5130	23000	0
25	KK-2026-07-009	2	1130	0	23000
26	KK-2026-07-010	1	5110	19500	0
27	KK-2026-07-010	2	1130	0	19500
28	KK-2026-07-011	1	5110	15000	0
29	KK-2026-07-011	2	1130	0	15000
30	KK-2026-07-012	1	5120	10000	0
31	KK-2026-07-012	2	1130	0	10000
32	KK-2026-07-013	1	5130	23000	0
33	KK-2026-07-013	2	1130	0	23000
34	KK-2026-07-014	1	5130	27	0
35	KK-2026-07-014	2	1130	0	27
36	KK-2026-07-015	1	5130	23000	0
37	KK-2026-07-015	2	1130	0	23000
38	KK-2026-07-016	1	5130	15000	0
39	KK-2026-07-016	2	1130	0	15000
40	KK-2026-07-017	1	5130	26973	0
41	KK-2026-07-017	2	1130	0	26973
42	KK-2026-07-018	1	5110	15000	0
43	KK-2026-07-018	2	1130	0	15000
44	KK-2026-07-019	1	5120	10000	0
45	KK-2026-07-019	2	1130	0	10000
46	KK-2026-07-020	1	5130	23000	0
47	KK-2026-07-020	2	1130	0	23000
48	KK-2026-07-021	1	5740	100000	0
49	KK-2026-07-021	2	1130	0	100000
50	KK-2026-07-022	1	9999	23000	0
51	KK-2026-07-022	2	1130	0	23000
52	KK-2026-07-023	1	5110	19500	0
53	KK-2026-07-023	2	1130	0	19500
54	KK-2026-07-024	1	5120	10000	0
55	KK-2026-07-024	2	1130	0	10000
56	KK-2026-07-025	1	5530	300000	0
57	KK-2026-07-025	2	1120	0	300000
58	KK-2026-07-026	1	5540	63538	0
59	KK-2026-07-026	2	1120	0	63538
60	KK-2026-07-027	1	9999	175000	0
61	KK-2026-07-027	2	1120	0	175000
62	KM-2026-07-001	1	1120	203000	0
63	KM-2026-07-001	2	4390	0	203000
64	KM-2026-07-002	1	1120	29000	0
65	KM-2026-07-002	2	4390	0	29000
66	KK-2026-07-028	1	5530	13049	0
67	KK-2026-07-028	2	1130	0	13049
68	KK-2026-07-029	1	5130	27000	0
69	KK-2026-07-029	2	1130	0	27000
70	KK-2026-07-030	1	5110	16000	0
71	KK-2026-07-030	2	1130	0	16000
72	KK-2026-07-031	1	9999	43451	0
73	KK-2026-07-031	2	1130	0	43451
74	KK-2026-07-032	1	5710	815	0
75	KK-2026-07-032	2	1120	0	815
76	KK-2026-07-033	1	5710	814000	0
77	KK-2026-07-033	2	1120	0	814000
\.


--
-- Data for Name: periods; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.periods (year, month, is_locked, locked_at) FROM stdin;
2026	6	f	\N
2026	7	f	\N
2026	8	f	\N
2026	9	f	\N
2026	10	f	\N
2026	11	f	\N
2026	12	f	\N
2027	1	f	\N
2027	2	f	\N
2027	3	f	\N
2027	4	f	\N
2027	5	f	\N
2027	6	f	\N
2027	7	f	\N
2027	8	f	\N
2027	9	f	\N
2027	10	f	\N
2027	11	f	\N
2027	12	f	\N
2028	1	f	\N
2028	2	f	\N
2028	3	f	\N
2028	4	f	\N
2028	5	f	\N
2028	6	f	\N
2028	7	f	\N
2028	8	f	\N
2028	9	f	\N
2028	10	f	\N
2028	11	f	\N
2028	12	f	\N
2029	1	f	\N
2029	2	f	\N
2029	3	f	\N
2029	4	f	\N
2029	5	f	\N
2029	6	f	\N
2029	7	f	\N
2029	8	f	\N
2029	9	f	\N
2029	10	f	\N
2029	11	f	\N
2029	12	f	\N
2030	1	f	\N
2030	2	f	\N
2030	3	f	\N
2030	4	f	\N
2030	5	f	\N
2030	6	f	\N
2030	7	f	\N
2030	8	f	\N
2030	9	f	\N
2030	10	f	\N
2030	11	f	\N
2030	12	f	\N
\.


--
-- Data for Name: receipts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.receipts (id, telegram_file_id, telegram_chat_id, image_path, raw_ocr_text, parsed_merchant, parsed_amount, parsed_date, confidence_score, note, parse_source, ewallet_type, status, doc_number, created_at) FROM stdin;
1	AgACAgUAAxkBAAIBmWpPl-0TZk1hzAp3Ez_aqpjr6V_0AAKXD2sbGJiAVkvdIQHqfyOyAQADAgADeQADPAQ	7248273513	\N	19.45\t\r\nRincian Transaksi\t\r\nRp 23.000\t\r\nDari\tRafi Adiyatma\t\r\nSeaBank: 901689957839\t\r\nKe\twarung sembako teh elis,\t\r\nBEKASI\t\r\nNama Acquirer\tGoPay\t\r\nMetode Pembayaran\tSeaBank\t\r\nJumlah\tRp 23.000\t\r\nNo. Transaksi\t2026070943507176903008838\t\r\nNo. Referensi\t01190002Y899 9\t\r\nTerminal ID\tA02\t\r\nWaktu Transaksi\t09 Jul 2026, 19:31\t\r\nButuh Bantuan?\t\r\n	Rincian Transaksi	23000	2026-07-09	100	\N	receipt	\N	confirmed	KK-2026-07-022	2026-07-09 12:45:39.699376+00
2	AgACAgUAAxkBAAIB4mpSE27NWCR5qqZAtqd7Ir26AAE-MQACZw5rG4MRkVakUrKLVUjk4gEAAwIAA3kAAzwE	7248273513	\N	16.56 g\t\r\nRincian Transaksi\t\r\nRp 13.049\t\r\nDari\tRafi Adiyatma\t\r\nSeaBank: 901689957839\t\r\nKe\tDomainesia\t\r\nYOGYAKARTA\t\r\nNama Acquirer\tGoPay\t\r\nMetode Pembayaran\t. SeaBank\t\r\nJumlah\tRp 13.049\t\r\nNo. Transaksi\t2026071143507221818724838\t\r\nNo. Referensi\t01150003KL5N 9\t\r\nTerminal ID\tA01\t\r\nWaktu Transaksi\t11 Jul 2026, 16:41\t\r\nButuh Bantuan?\t\r\n	Rincian Transaksi	13049	2026-07-11	100	\N	receipt	\N	rejected	\N	2026-07-11 09:57:07.352324+00
\.


--
-- Data for Name: recurring_transactions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.recurring_transactions (id, doc_type, description, lines, frequency, next_run, is_active, created_at) FROM stdin;
\.


--
-- Data for Name: sequences; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.sequences (doc_type, year, month, last_seq) FROM stdin;
OB	2026	7	1
TR	2026	7	1
KM	2026	7	2
KK	2026	7	33
\.


--
-- Data for Name: tags; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tags (id, name, emoji) FROM stdin;
\.


--
-- Data for Name: transaction_tags; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.transaction_tags (doc_number, tag_id) FROM stdin;
\.


--
-- Data for Name: transactions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.transactions (doc_number, doc_type, transaction_date, period_year, period_month, description, status, is_reversal, reversal_of_doc, input_source, created_at) FROM stdin;
OB-2026-07-001	OB	2026-07-01	2026	7	Saldo awal (setup)	POSTED	f	\N	telegram	2026-07-01 08:37:27.825116+00
KK-2026-07-001	KK	2026-07-01	2026	7	Ke Abang	POSTED	f	\N	telegram	2026-07-01 08:38:35.402256+00
KK-2026-07-002	KK	2026-07-01	2026	7	Beli rokok	POSTED	f	\N	telegram	2026-07-01 08:39:31.372366+00
KK-2026-07-003	KK	2026-07-01	2026	7	Makan siang	POSTED	f	\N	telegram	2026-07-01 08:40:26.621801+00
KK-2026-07-004	KK	2026-07-01	2026	7	Es dancow	POSTED	f	\N	telegram	2026-07-01 08:41:15.244257+00
KK-2026-07-005	KK	2026-07-01	2026	7	Beli kuota by u	POSTED	f	\N	telegram	2026-07-01 08:41:54.448308+00
TR-2026-07-001	TR	2026-07-01	2026	7	Pengisian imprest kas kecil	POSTED	f	\N	telegram	2026-07-01 08:42:18.842771+00
KK-2026-07-006	KK	2026-07-01	2026	7	Ayam bakar madu	POSTED	f	\N	telegram	2026-07-01 14:38:26.665865+00
KK-2026-07-007	KK	2026-07-02	2026	7	Naspad	POSTED	f	\N	telegram	2026-07-02 07:18:27.984441+00
KK-2026-07-008	KK	2026-07-02	2026	7	Es dancow	POSTED	f	\N	telegram	2026-07-02 07:19:13.44476+00
KK-2026-07-009	KK	2026-07-02	2026	7	Rokok	POSTED	f	\N	telegram	2026-07-02 15:57:00.535477+00
KK-2026-07-010	KK	2026-07-02	2026	7	Ayam madu	POSTED	f	\N	telegram	2026-07-02 15:58:00.69679+00
KK-2026-07-011	KK	2026-07-03	2026	7	Naspad	POSTED	f	\N	telegram	2026-07-03 15:17:26.382494+00
KK-2026-07-012	KK	2026-07-03	2026	7	Es dancow	POSTED	f	\N	telegram	2026-07-03 15:18:25.359677+00
KK-2026-07-013	KK	2026-07-04	2026	7	Rokok	POSTED	f	\N	telegram	2026-07-04 13:24:51.184206+00
KK-2026-07-014	KK	2026-07-06	2026	7	Rokok	POSTED	f	\N	telegram	2026-07-06 03:57:58.377991+00
KK-2026-07-015	KK	2026-07-07	2026	7	Rokok	POSTED	f	\N	telegram	2026-07-07 16:57:07.352069+00
KK-2026-07-016	KK	2026-07-07	2026	7	Naspad	POSTED	f	\N	telegram	2026-07-07 16:57:45.425028+00
KK-2026-07-017	KK	2026-07-07	2026	7	Rokok	POSTED	f	\N	telegram	2026-07-07 16:58:57.905141+00
KK-2026-07-018	KK	2026-07-09	2026	7	Naspad	POSTED	f	\N	telegram	2026-07-08 19:04:20.796326+00
KK-2026-07-019	KK	2026-07-09	2026	7	Minuman	POSTED	f	\N	telegram	2026-07-08 19:07:07.481262+00
KK-2026-07-020	KK	2026-07-09	2026	7	Rokok	POSTED	f	\N	telegram	2026-07-08 19:08:41.2619+00
KK-2026-07-021	KK	2026-07-09	2026	7	Traktir suchy	POSTED	f	\N	telegram	2026-07-08 19:11:37.726341+00
KK-2026-07-022	KK	2026-07-09	2026	7	Rincian Transaksi	POSTED	f	\N	telegram	2026-07-09 12:46:37.296682+00
KK-2026-07-023	KK	2026-07-10	2026	7	Ayam bakar madu	POSTED	f	\N	telegram	2026-07-10 09:46:02.142762+00
KK-2026-07-024	KK	2026-07-10	2026	7	Es dancow	POSTED	f	\N	telegram	2026-07-10 09:46:51.321534+00
KK-2026-07-025	KK	2026-07-10	2026	7	Langganan Claude pro	POSTED	f	\N	telegram	2026-07-10 14:32:54.817059+00
KK-2026-07-026	KK	2026-07-11	2026	7	Insole arch support	POSTED	f	\N	telegram	2026-07-10 19:34:25.227006+00
KK-2026-07-027	KK	2026-07-11	2026	7	Skip	POSTED	f	\N	telegram	2026-07-10 20:18:07.678321+00
KM-2026-07-001	KM	2026-07-11	2026	7	\N	POSTED	f	\N	telegram	2026-07-10 20:18:45.740027+00
KM-2026-07-002	KM	2026-07-11	2026	7	\N	POSTED	f	\N	telegram	2026-07-10 20:55:26.05947+00
KK-2026-07-028	KK	2026-07-11	2026	7	Domain website	POSTED	f	\N	telegram	2026-07-11 10:46:12.545505+00
KK-2026-07-029	KK	2026-07-11	2026	7	Rokok	POSTED	f	\N	telegram	2026-07-11 10:48:02.904774+00
KK-2026-07-030	KK	2026-07-11	2026	7	Ayam geprek	POSTED	f	\N	telegram	2026-07-11 10:49:01.76179+00
KK-2026-07-031	KK	2026-07-11	2026	7	\N	POSTED	f	\N	telegram	2026-07-11 12:57:52.817003+00
KK-2026-07-032	KK	2026-07-11	2026	7	\N	POSTED	f	\N	telegram	2026-07-11 12:59:07.006115+00
KK-2026-07-033	KK	2026-07-11	2026	7	\N	POSTED	f	\N	telegram	2026-07-11 13:00:09.610418+00
\.


--
-- Data for Name: transfer_fee_rules; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.transfer_fee_rules (from_account, to_account, fee_amount, fee_account, method_label) FROM stdin;
1120	1120	0	\N	Sesama BNI (gratis)
1130	1130	0	\N	Sesama SeaBank (gratis)
1120	1130	2500	5820	BI-Fast BNI->SeaBank
1130	1120	0	\N	Gratis SeaBank (kuota 100x/bln)
1120	1140	2500	5820	BI-Fast BNI->Tabungan
1140	1120	0	\N	Transfer balik (asumsi gratis)
1110	1120	0	\N	Setor Tunai
1110	1130	0	\N	Setor Tunai
1120	1110	0	\N	Tarik Tunai BNI
1130	1110	0	\N	Tarik Tunai SeaBank
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY realtime.schema_migrations (version, inserted_at) FROM stdin;
20211116024918	2026-06-15 15:18:03
20211116045059	2026-06-15 15:18:03
20211116050929	2026-06-15 15:18:03
20211116051442	2026-06-15 15:18:03
20211116212300	2026-06-15 15:18:03
20211116213355	2026-06-15 15:18:03
20211116213934	2026-06-15 15:18:03
20211116214523	2026-06-15 15:18:03
20211122062447	2026-06-15 15:18:03
20211124070109	2026-06-15 15:18:03
20211202204204	2026-06-15 15:18:03
20211202204605	2026-06-15 15:18:03
20211210212804	2026-06-15 15:18:03
20211228014915	2026-06-15 15:18:03
20220107221237	2026-06-15 15:18:03
20220228202821	2026-06-15 15:18:03
20220312004840	2026-06-15 15:18:03
20220603231003	2026-06-15 15:18:04
20220603232444	2026-06-15 15:18:04
20220615214548	2026-06-15 15:18:04
20220712093339	2026-06-15 15:18:04
20220908172859	2026-06-15 15:18:04
20220916233421	2026-06-15 15:18:04
20230119133233	2026-06-15 15:18:04
20230128025114	2026-06-15 15:18:04
20230128025212	2026-06-15 15:18:04
20230227211149	2026-06-15 15:18:04
20230228184745	2026-06-15 15:18:04
20230308225145	2026-06-15 15:18:04
20230328144023	2026-06-15 15:18:04
20231018144023	2026-06-15 15:18:04
20231204144023	2026-06-15 15:18:04
20231204144024	2026-06-15 15:18:04
20231204144025	2026-06-15 15:18:04
20240108234812	2026-06-15 15:18:04
20240109165339	2026-06-15 15:18:04
20240227174441	2026-06-15 15:18:04
20240311171622	2026-06-15 15:18:04
20240321100241	2026-06-15 15:18:04
20240401105812	2026-06-15 15:18:04
20240418121054	2026-06-15 15:18:04
20240523004032	2026-06-15 15:18:04
20240618124746	2026-06-15 15:18:04
20240801235015	2026-06-15 15:18:04
20240805133720	2026-06-15 15:18:04
20240827160934	2026-06-15 15:18:04
20240919163303	2026-06-15 15:18:04
20240919163305	2026-06-15 15:18:04
20241019105805	2026-06-15 15:18:04
20241030150047	2026-06-15 15:18:04
20241108114728	2026-06-15 15:18:04
20241121104152	2026-06-15 15:18:04
20241130184212	2026-06-15 15:18:04
20241220035512	2026-06-15 15:18:04
20241220123912	2026-06-15 15:18:04
20241224161212	2026-06-15 15:18:04
20250107150512	2026-06-15 15:18:04
20250110162412	2026-06-15 15:18:04
20250123174212	2026-06-15 15:18:04
20250128220012	2026-06-15 15:18:04
20250506224012	2026-06-15 15:18:04
20250523164012	2026-06-15 15:18:04
20250714121412	2026-06-15 15:18:04
20250905041441	2026-06-15 15:18:04
20251103001201	2026-06-15 15:18:04
20251120212548	2026-06-15 15:18:04
20251120215549	2026-06-15 15:18:04
20260218120000	2026-06-15 15:18:04
20260326120000	2026-06-15 15:18:04
20260514120000	2026-06-15 15:18:04
20260527120000	2026-06-15 15:18:04
20260528120000	2026-06-15 15:18:04
20260603120000	2026-06-15 16:56:06
20260605120000	2026-06-16 00:52:37
20260606110000	2026-06-16 00:52:37
20260616120000	2026-06-25 12:07:23
20260624120000	2026-06-25 12:07:23
20260626120000	2026-07-02 11:56:21
20260706120000	2026-07-07 12:19:41
20260707120000	2026-07-15 10:18:28
20260709120000	2026-07-15 10:18:28
\.


--
-- Data for Name: subscription; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY realtime.subscription (id, subscription_id, entity, filters, claims, created_at, action_filter, selected_columns) FROM stdin;
\.


--
-- Data for Name: buckets; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.buckets (id, name, owner, created_at, updated_at, public, avif_autodetection, file_size_limit, allowed_mime_types, owner_id, type) FROM stdin;
\.


--
-- Data for Name: buckets_analytics; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.buckets_analytics (name, type, format, created_at, updated_at, id, deleted_at) FROM stdin;
\.


--
-- Data for Name: buckets_vectors; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.buckets_vectors (id, type, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: migrations; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.migrations (id, name, hash, executed_at) FROM stdin;
0	create-migrations-table	e18db593bcde2aca2a408c4d1100f6abba2195df	2026-06-15 15:18:08.539136
1	initialmigration	6ab16121fbaa08bbd11b712d05f358f9b555d777	2026-06-15 15:18:08.580651
2	storage-schema	f6a1fa2c93cbcd16d4e487b362e45fca157a8dbd	2026-06-15 15:18:08.58697
3	pathtoken-column	2cb1b0004b817b29d5b0a971af16bafeede4b70d	2026-06-15 15:18:08.612305
4	add-migrations-rls	427c5b63fe1c5937495d9c635c263ee7a5905058	2026-06-15 15:18:08.624587
5	add-size-functions	79e081a1455b63666c1294a440f8ad4b1e6a7f84	2026-06-15 15:18:08.628978
6	change-column-name-in-get-size	ded78e2f1b5d7e616117897e6443a925965b30d2	2026-06-15 15:18:08.633827
7	add-rls-to-buckets	e7e7f86adbc51049f341dfe8d30256c1abca17aa	2026-06-15 15:18:08.638825
8	add-public-to-buckets	fd670db39ed65f9d08b01db09d6202503ca2bab3	2026-06-15 15:18:08.643233
9	fix-search-function	af597a1b590c70519b464a4ab3be54490712796b	2026-06-15 15:18:08.648132
10	search-files-search-function	b595f05e92f7e91211af1bbfe9c6a13bb3391e16	2026-06-15 15:18:08.652681
11	add-trigger-to-auto-update-updated_at-column	7425bdb14366d1739fa8a18c83100636d74dcaa2	2026-06-15 15:18:08.658301
12	add-automatic-avif-detection-flag	8e92e1266eb29518b6a4c5313ab8f29dd0d08df9	2026-06-15 15:18:08.663226
13	add-bucket-custom-limits	cce962054138135cd9a8c4bcd531598684b25e7d	2026-06-15 15:18:08.667881
14	use-bytes-for-max-size	941c41b346f9802b411f06f30e972ad4744dad27	2026-06-15 15:18:08.672931
15	add-can-insert-object-function	934146bc38ead475f4ef4b555c524ee5d66799e5	2026-06-15 15:18:08.707586
16	add-version	76debf38d3fd07dcfc747ca49096457d95b1221b	2026-06-15 15:18:08.713084
17	drop-owner-foreign-key	f1cbb288f1b7a4c1eb8c38504b80ae2a0153d101	2026-06-15 15:18:08.717837
18	add_owner_id_column_deprecate_owner	e7a511b379110b08e2f214be852c35414749fe66	2026-06-15 15:18:08.722648
19	alter-default-value-objects-id	02e5e22a78626187e00d173dc45f58fa66a4f043	2026-06-15 15:18:08.72852
20	list-objects-with-delimiter	cd694ae708e51ba82bf012bba00caf4f3b6393b7	2026-06-15 15:18:08.733448
21	s3-multipart-uploads	8c804d4a566c40cd1e4cc5b3725a664a9303657f	2026-06-15 15:18:08.740092
22	s3-multipart-uploads-big-ints	9737dc258d2397953c9953d9b86920b8be0cdb73	2026-06-15 15:18:08.752
23	optimize-search-function	9d7e604cddc4b56a5422dc68c9313f4a1b6f132c	2026-06-15 15:18:08.762382
24	operation-function	8312e37c2bf9e76bbe841aa5fda889206d2bf8aa	2026-06-15 15:18:08.767131
25	custom-metadata	d974c6057c3db1c1f847afa0e291e6165693b990	2026-06-15 15:18:08.77185
26	objects-prefixes	215cabcb7f78121892a5a2037a09fedf9a1ae322	2026-06-15 15:18:08.776561
27	search-v2	859ba38092ac96eb3964d83bf53ccc0b141663a6	2026-06-15 15:18:08.780834
28	object-bucket-name-sorting	c73a2b5b5d4041e39705814fd3a1b95502d38ce4	2026-06-15 15:18:08.785093
29	create-prefixes	ad2c1207f76703d11a9f9007f821620017a66c21	2026-06-15 15:18:08.789319
30	update-object-levels	2be814ff05c8252fdfdc7cfb4b7f5c7e17f0bed6	2026-06-15 15:18:08.793555
31	objects-level-index	b40367c14c3440ec75f19bbce2d71e914ddd3da0	2026-06-15 15:18:08.798094
32	backward-compatible-index-on-objects	e0c37182b0f7aee3efd823298fb3c76f1042c0f7	2026-06-15 15:18:08.80236
33	backward-compatible-index-on-prefixes	b480e99ed951e0900f033ec4eb34b5bdcb4e3d49	2026-06-15 15:18:08.806543
34	optimize-search-function-v1	ca80a3dc7bfef894df17108785ce29a7fc8ee456	2026-06-15 15:18:08.810689
35	add-insert-trigger-prefixes	458fe0ffd07ec53f5e3ce9df51bfdf4861929ccc	2026-06-15 15:18:08.814902
36	optimise-existing-functions	6ae5fca6af5c55abe95369cd4f93985d1814ca8f	2026-06-15 15:18:08.819311
37	add-bucket-name-length-trigger	3944135b4e3e8b22d6d4cbb568fe3b0b51df15c1	2026-06-15 15:18:08.823713
38	iceberg-catalog-flag-on-buckets	02716b81ceec9705aed84aa1501657095b32e5c5	2026-06-15 15:18:08.82869
39	add-search-v2-sort-support	6706c5f2928846abee18461279799ad12b279b78	2026-06-15 15:18:08.840112
40	fix-prefix-race-conditions-optimized	7ad69982ae2d372b21f48fc4829ae9752c518f6b	2026-06-15 15:18:08.846024
41	add-object-level-update-trigger	07fcf1a22165849b7a029deed059ffcde08d1ae0	2026-06-15 15:18:08.851998
42	rollback-prefix-triggers	771479077764adc09e2ea2043eb627503c034cd4	2026-06-15 15:18:08.856229
43	fix-object-level	84b35d6caca9d937478ad8a797491f38b8c2979f	2026-06-15 15:18:08.860561
44	vector-bucket-type	99c20c0ffd52bb1ff1f32fb992f3b351e3ef8fb3	2026-06-15 15:18:08.864771
45	vector-buckets	049e27196d77a7cb76497a85afae669d8b230953	2026-06-15 15:18:08.869984
46	buckets-objects-grants	fedeb96d60fefd8e02ab3ded9fbde05632f84aed	2026-06-15 15:18:08.880247
47	iceberg-table-metadata	649df56855c24d8b36dd4cc1aeb8251aa9ad42c2	2026-06-15 15:18:08.885179
48	iceberg-catalog-ids	e0e8b460c609b9999ccd0df9ad14294613eed939	2026-06-15 15:18:08.889675
49	buckets-objects-grants-postgres	072b1195d0d5a2f888af6b2302a1938dd94b8b3d	2026-06-15 15:18:08.906135
50	search-v2-optimised	6323ac4f850aa14e7387eb32102869578b5bd478	2026-06-15 15:18:08.91112
51	index-backward-compatible-search	2ee395d433f76e38bcd3856debaf6e0e5b674011	2026-06-15 15:18:08.984999
52	drop-not-used-indexes-and-functions	5cc44c8696749ac11dd0dc37f2a3802075f3a171	2026-06-15 15:18:08.987127
53	drop-index-lower-name	d0cb18777d9e2a98ebe0bc5cc7a42e57ebe41854	2026-06-15 15:18:08.996514
54	drop-index-object-level	6289e048b1472da17c31a7eba1ded625a6457e67	2026-06-15 15:18:08.999614
55	prevent-direct-deletes	262a4798d5e0f2e7c8970232e03ce8be695d5819	2026-06-15 15:18:09.001729
56	fix-optimized-search-function	b823ed1e418101032fa01374edc9a436e54e3ed4	2026-06-15 15:18:09.007614
57	s3-multipart-uploads-metadata	f127886e00d1b374fadbc7c6b31e09336aad5287	2026-06-15 15:18:09.013355
58	operation-ergonomics	00ca5d483b3fe0d522133d9002ccc5df98365120	2026-06-15 15:18:09.018097
59	drop-unused-functions	38456f13e39691c2bbb4b5151d0d1cdbabd4a8c4	2026-06-15 15:18:09.023025
60	optimize-existing-functions-again	db35e1c91a9201e59f4fef8d972c2f277d68b157	2026-06-15 15:18:09.027686
\.


--
-- Data for Name: objects; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.objects (id, bucket_id, name, owner, created_at, updated_at, last_accessed_at, metadata, version, owner_id, user_metadata) FROM stdin;
\.


--
-- Data for Name: s3_multipart_uploads; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.s3_multipart_uploads (id, in_progress_size, upload_signature, bucket_id, key, version, owner_id, created_at, user_metadata, metadata) FROM stdin;
\.


--
-- Data for Name: s3_multipart_uploads_parts; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.s3_multipart_uploads_parts (id, upload_id, size, part_number, bucket_id, key, etag, owner_id, version, created_at) FROM stdin;
\.


--
-- Data for Name: vector_indexes; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.vector_indexes (id, name, bucket_id, data_type, dimension, distance_metric, metadata_configuration, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: secrets; Type: TABLE DATA; Schema: vault; Owner: -
--

COPY vault.secrets (id, name, description, secret, key_id, nonce, created_at, updated_at) FROM stdin;
\.


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE SET; Schema: auth; Owner: -
--

SELECT pg_catalog.setval('auth.refresh_tokens_id_seq', 1, false);


--
-- Name: Fintrack_project_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public."Fintrack_project_id_seq"', 1, false);


--
-- Name: activity_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.activity_log_id_seq', 180, true);


--
-- Name: audit_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.audit_log_id_seq', 149, true);


--
-- Name: bills_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.bills_id_seq', 1, false);


--
-- Name: bot_categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.bot_categories_id_seq', 14, true);


--
-- Name: goals_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.goals_id_seq', 1, false);


--
-- Name: journal_lines_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.journal_lines_id_seq', 77, true);


--
-- Name: receipts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.receipts_id_seq', 2, true);


--
-- Name: recurring_transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.recurring_transactions_id_seq', 1, false);


--
-- Name: tags_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tags_id_seq', 1, false);


--
-- Name: subscription_id_seq; Type: SEQUENCE SET; Schema: realtime; Owner: -
--

SELECT pg_catalog.setval('realtime.subscription_id_seq', 1, false);


--
-- Name: mfa_amr_claims amr_id_pk; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT amr_id_pk PRIMARY KEY (id);


--
-- Name: audit_log_entries audit_log_entries_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.audit_log_entries
    ADD CONSTRAINT audit_log_entries_pkey PRIMARY KEY (id);


--
-- Name: custom_oauth_providers custom_oauth_providers_identifier_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.custom_oauth_providers
    ADD CONSTRAINT custom_oauth_providers_identifier_key UNIQUE (identifier);


--
-- Name: custom_oauth_providers custom_oauth_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.custom_oauth_providers
    ADD CONSTRAINT custom_oauth_providers_pkey PRIMARY KEY (id);


--
-- Name: flow_state flow_state_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.flow_state
    ADD CONSTRAINT flow_state_pkey PRIMARY KEY (id);


--
-- Name: identities identities_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_pkey PRIMARY KEY (id);


--
-- Name: identities identities_provider_id_provider_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_provider_id_provider_unique UNIQUE (provider_id, provider);


--
-- Name: instances instances_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.instances
    ADD CONSTRAINT instances_pkey PRIMARY KEY (id);


--
-- Name: mfa_amr_claims mfa_amr_claims_session_id_authentication_method_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT mfa_amr_claims_session_id_authentication_method_pkey UNIQUE (session_id, authentication_method);


--
-- Name: mfa_challenges mfa_challenges_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_challenges
    ADD CONSTRAINT mfa_challenges_pkey PRIMARY KEY (id);


--
-- Name: mfa_factors mfa_factors_last_challenged_at_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_last_challenged_at_key UNIQUE (last_challenged_at);


--
-- Name: mfa_factors mfa_factors_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_pkey PRIMARY KEY (id);


--
-- Name: oauth_authorizations oauth_authorizations_authorization_code_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_authorization_code_key UNIQUE (authorization_code);


--
-- Name: oauth_authorizations oauth_authorizations_authorization_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_authorization_id_key UNIQUE (authorization_id);


--
-- Name: oauth_authorizations oauth_authorizations_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_pkey PRIMARY KEY (id);


--
-- Name: oauth_client_states oauth_client_states_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_client_states
    ADD CONSTRAINT oauth_client_states_pkey PRIMARY KEY (id);


--
-- Name: oauth_clients oauth_clients_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_clients
    ADD CONSTRAINT oauth_clients_pkey PRIMARY KEY (id);


--
-- Name: oauth_consents oauth_consents_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_pkey PRIMARY KEY (id);


--
-- Name: oauth_consents oauth_consents_user_client_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_user_client_unique UNIQUE (user_id, client_id);


--
-- Name: one_time_tokens one_time_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.one_time_tokens
    ADD CONSTRAINT one_time_tokens_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_token_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_token_unique UNIQUE (token);


--
-- Name: saml_providers saml_providers_entity_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_entity_id_key UNIQUE (entity_id);


--
-- Name: saml_providers saml_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_pkey PRIMARY KEY (id);


--
-- Name: saml_relay_states saml_relay_states_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: sso_domains sso_domains_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_domains
    ADD CONSTRAINT sso_domains_pkey PRIMARY KEY (id);


--
-- Name: sso_providers sso_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_providers
    ADD CONSTRAINT sso_providers_pkey PRIMARY KEY (id);


--
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: webauthn_challenges webauthn_challenges_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.webauthn_challenges
    ADD CONSTRAINT webauthn_challenges_pkey PRIMARY KEY (id);


--
-- Name: webauthn_credentials webauthn_credentials_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.webauthn_credentials
    ADD CONSTRAINT webauthn_credentials_pkey PRIMARY KEY (id);


--
-- Name: Fintrack_project Fintrack_project_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Fintrack_project"
    ADD CONSTRAINT "Fintrack_project_pkey" PRIMARY KEY (id);


--
-- Name: activity_log activity_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_log
    ADD CONSTRAINT activity_log_pkey PRIMARY KEY (id);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: auth_tokens auth_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_tokens
    ADD CONSTRAINT auth_tokens_pkey PRIMARY KEY (token);


--
-- Name: bills bills_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bills
    ADD CONSTRAINT bills_pkey PRIMARY KEY (id);


--
-- Name: bot_aliases bot_aliases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bot_aliases
    ADD CONSTRAINT bot_aliases_pkey PRIMARY KEY (alias);


--
-- Name: bot_categories bot_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bot_categories
    ADD CONSTRAINT bot_categories_pkey PRIMARY KEY (id);


--
-- Name: bot_category_accounts bot_category_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bot_category_accounts
    ADD CONSTRAINT bot_category_accounts_pkey PRIMARY KEY (category_id, account_code);


--
-- Name: bot_settings bot_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bot_settings
    ADD CONSTRAINT bot_settings_pkey PRIMARY KEY (key);


--
-- Name: bot_state bot_state_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bot_state
    ADD CONSTRAINT bot_state_pkey PRIMARY KEY (user_id);


--
-- Name: budgets budgets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budgets
    ADD CONSTRAINT budgets_pkey PRIMARY KEY (account_code);


--
-- Name: chart_of_accounts chart_of_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chart_of_accounts
    ADD CONSTRAINT chart_of_accounts_pkey PRIMARY KEY (code);


--
-- Name: daily_log daily_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_log
    ADD CONSTRAINT daily_log_pkey PRIMARY KEY (log_date);


--
-- Name: goals goals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goals
    ADD CONSTRAINT goals_pkey PRIMARY KEY (id);


--
-- Name: journal_lines journal_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_lines
    ADD CONSTRAINT journal_lines_pkey PRIMARY KEY (id);


--
-- Name: periods periods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.periods
    ADD CONSTRAINT periods_pkey PRIMARY KEY (year, month);


--
-- Name: receipts receipts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receipts
    ADD CONSTRAINT receipts_pkey PRIMARY KEY (id);


--
-- Name: recurring_transactions recurring_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurring_transactions
    ADD CONSTRAINT recurring_transactions_pkey PRIMARY KEY (id);


--
-- Name: sequences sequences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sequences
    ADD CONSTRAINT sequences_pkey PRIMARY KEY (doc_type, year, month);


--
-- Name: tags tags_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_name_key UNIQUE (name);


--
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- Name: transaction_tags transaction_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_tags
    ADD CONSTRAINT transaction_tags_pkey PRIMARY KEY (doc_number, tag_id);


--
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (doc_number);


--
-- Name: transfer_fee_rules transfer_fee_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transfer_fee_rules
    ADD CONSTRAINT transfer_fee_rules_pkey PRIMARY KEY (from_account, to_account);


--
-- Name: messages messages_payload_exclusive; Type: CHECK CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE realtime.messages
    ADD CONSTRAINT messages_payload_exclusive CHECK (((payload IS NULL) OR (binary_payload IS NULL))) NOT VALID;


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id, inserted_at);


--
-- Name: subscription pk_subscription; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.subscription
    ADD CONSTRAINT pk_subscription PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: buckets_analytics buckets_analytics_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets_analytics
    ADD CONSTRAINT buckets_analytics_pkey PRIMARY KEY (id);


--
-- Name: buckets buckets_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets
    ADD CONSTRAINT buckets_pkey PRIMARY KEY (id);


--
-- Name: buckets_vectors buckets_vectors_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets_vectors
    ADD CONSTRAINT buckets_vectors_pkey PRIMARY KEY (id);


--
-- Name: migrations migrations_name_key; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.migrations
    ADD CONSTRAINT migrations_name_key UNIQUE (name);


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (id);


--
-- Name: objects objects_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.objects
    ADD CONSTRAINT objects_pkey PRIMARY KEY (id);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_pkey PRIMARY KEY (id);


--
-- Name: s3_multipart_uploads s3_multipart_uploads_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads
    ADD CONSTRAINT s3_multipart_uploads_pkey PRIMARY KEY (id);


--
-- Name: vector_indexes vector_indexes_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.vector_indexes
    ADD CONSTRAINT vector_indexes_pkey PRIMARY KEY (id);


--
-- Name: audit_logs_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX audit_logs_instance_id_idx ON auth.audit_log_entries USING btree (instance_id);


--
-- Name: confirmation_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX confirmation_token_idx ON auth.users USING btree (confirmation_token) WHERE ((confirmation_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: custom_oauth_providers_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX custom_oauth_providers_created_at_idx ON auth.custom_oauth_providers USING btree (created_at);


--
-- Name: custom_oauth_providers_enabled_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX custom_oauth_providers_enabled_idx ON auth.custom_oauth_providers USING btree (enabled);


--
-- Name: custom_oauth_providers_identifier_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX custom_oauth_providers_identifier_idx ON auth.custom_oauth_providers USING btree (identifier);


--
-- Name: custom_oauth_providers_provider_type_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX custom_oauth_providers_provider_type_idx ON auth.custom_oauth_providers USING btree (provider_type);


--
-- Name: email_change_token_current_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX email_change_token_current_idx ON auth.users USING btree (email_change_token_current) WHERE ((email_change_token_current)::text !~ '^[0-9 ]*$'::text);


--
-- Name: email_change_token_new_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX email_change_token_new_idx ON auth.users USING btree (email_change_token_new) WHERE ((email_change_token_new)::text !~ '^[0-9 ]*$'::text);


--
-- Name: factor_id_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX factor_id_created_at_idx ON auth.mfa_factors USING btree (user_id, created_at);


--
-- Name: flow_state_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX flow_state_created_at_idx ON auth.flow_state USING btree (created_at DESC);


--
-- Name: identities_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX identities_email_idx ON auth.identities USING btree (email text_pattern_ops);


--
-- Name: INDEX identities_email_idx; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON INDEX auth.identities_email_idx IS 'Auth: Ensures indexed queries on the email column';


--
-- Name: identities_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX identities_user_id_idx ON auth.identities USING btree (user_id);


--
-- Name: idx_auth_code; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_auth_code ON auth.flow_state USING btree (auth_code);


--
-- Name: idx_oauth_client_states_created_at; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_oauth_client_states_created_at ON auth.oauth_client_states USING btree (created_at);


--
-- Name: idx_user_id_auth_method; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_user_id_auth_method ON auth.flow_state USING btree (user_id, authentication_method);


--
-- Name: idx_users_created_at_desc; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_users_created_at_desc ON auth.users USING btree (created_at DESC);


--
-- Name: idx_users_email; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_users_email ON auth.users USING btree (email);


--
-- Name: idx_users_last_sign_in_at_desc; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_users_last_sign_in_at_desc ON auth.users USING btree (last_sign_in_at DESC);


--
-- Name: idx_users_name; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_users_name ON auth.users USING btree (((raw_user_meta_data ->> 'name'::text))) WHERE ((raw_user_meta_data ->> 'name'::text) IS NOT NULL);


--
-- Name: mfa_challenge_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX mfa_challenge_created_at_idx ON auth.mfa_challenges USING btree (created_at DESC);


--
-- Name: mfa_factors_user_friendly_name_unique; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX mfa_factors_user_friendly_name_unique ON auth.mfa_factors USING btree (friendly_name, user_id) WHERE (TRIM(BOTH FROM friendly_name) <> ''::text);


--
-- Name: mfa_factors_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX mfa_factors_user_id_idx ON auth.mfa_factors USING btree (user_id);


--
-- Name: oauth_auth_pending_exp_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_auth_pending_exp_idx ON auth.oauth_authorizations USING btree (expires_at) WHERE (status = 'pending'::auth.oauth_authorization_status);


--
-- Name: oauth_clients_deleted_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_clients_deleted_at_idx ON auth.oauth_clients USING btree (deleted_at);


--
-- Name: oauth_consents_active_client_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_active_client_idx ON auth.oauth_consents USING btree (client_id) WHERE (revoked_at IS NULL);


--
-- Name: oauth_consents_active_user_client_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_active_user_client_idx ON auth.oauth_consents USING btree (user_id, client_id) WHERE (revoked_at IS NULL);


--
-- Name: oauth_consents_user_order_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_user_order_idx ON auth.oauth_consents USING btree (user_id, granted_at DESC);


--
-- Name: one_time_tokens_relates_to_hash_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX one_time_tokens_relates_to_hash_idx ON auth.one_time_tokens USING hash (relates_to);


--
-- Name: one_time_tokens_token_hash_hash_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX one_time_tokens_token_hash_hash_idx ON auth.one_time_tokens USING hash (token_hash);


--
-- Name: one_time_tokens_user_id_token_type_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX one_time_tokens_user_id_token_type_key ON auth.one_time_tokens USING btree (user_id, token_type);


--
-- Name: reauthentication_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX reauthentication_token_idx ON auth.users USING btree (reauthentication_token) WHERE ((reauthentication_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: recovery_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX recovery_token_idx ON auth.users USING btree (recovery_token) WHERE ((recovery_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: refresh_tokens_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_instance_id_idx ON auth.refresh_tokens USING btree (instance_id);


--
-- Name: refresh_tokens_instance_id_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_instance_id_user_id_idx ON auth.refresh_tokens USING btree (instance_id, user_id);


--
-- Name: refresh_tokens_parent_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_parent_idx ON auth.refresh_tokens USING btree (parent);


--
-- Name: refresh_tokens_session_id_revoked_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_session_id_revoked_idx ON auth.refresh_tokens USING btree (session_id, revoked);


--
-- Name: refresh_tokens_updated_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_updated_at_idx ON auth.refresh_tokens USING btree (updated_at DESC);


--
-- Name: saml_providers_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_providers_sso_provider_id_idx ON auth.saml_providers USING btree (sso_provider_id);


--
-- Name: saml_relay_states_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_created_at_idx ON auth.saml_relay_states USING btree (created_at DESC);


--
-- Name: saml_relay_states_for_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_for_email_idx ON auth.saml_relay_states USING btree (for_email);


--
-- Name: saml_relay_states_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_sso_provider_id_idx ON auth.saml_relay_states USING btree (sso_provider_id);


--
-- Name: sessions_not_after_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_not_after_idx ON auth.sessions USING btree (not_after DESC);


--
-- Name: sessions_oauth_client_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_oauth_client_id_idx ON auth.sessions USING btree (oauth_client_id);


--
-- Name: sessions_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_user_id_idx ON auth.sessions USING btree (user_id);


--
-- Name: sso_domains_domain_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX sso_domains_domain_idx ON auth.sso_domains USING btree (lower(domain));


--
-- Name: sso_domains_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sso_domains_sso_provider_id_idx ON auth.sso_domains USING btree (sso_provider_id);


--
-- Name: sso_providers_resource_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX sso_providers_resource_id_idx ON auth.sso_providers USING btree (lower(resource_id));


--
-- Name: sso_providers_resource_id_pattern_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sso_providers_resource_id_pattern_idx ON auth.sso_providers USING btree (resource_id text_pattern_ops);


--
-- Name: unique_phone_factor_per_user; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX unique_phone_factor_per_user ON auth.mfa_factors USING btree (user_id, phone);


--
-- Name: user_id_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX user_id_created_at_idx ON auth.sessions USING btree (user_id, created_at);


--
-- Name: users_email_partial_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX users_email_partial_key ON auth.users USING btree (email) WHERE (is_sso_user = false);


--
-- Name: INDEX users_email_partial_key; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON INDEX auth.users_email_partial_key IS 'Auth: A partial unique index that applies only when is_sso_user is false';


--
-- Name: users_instance_id_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_instance_id_email_idx ON auth.users USING btree (instance_id, lower((email)::text));


--
-- Name: users_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_instance_id_idx ON auth.users USING btree (instance_id);


--
-- Name: users_is_anonymous_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_is_anonymous_idx ON auth.users USING btree (is_anonymous);


--
-- Name: webauthn_challenges_expires_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX webauthn_challenges_expires_at_idx ON auth.webauthn_challenges USING btree (expires_at);


--
-- Name: webauthn_challenges_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX webauthn_challenges_user_id_idx ON auth.webauthn_challenges USING btree (user_id);


--
-- Name: webauthn_credentials_credential_id_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX webauthn_credentials_credential_id_key ON auth.webauthn_credentials USING btree (credential_id);


--
-- Name: webauthn_credentials_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX webauthn_credentials_user_id_idx ON auth.webauthn_credentials USING btree (user_id);


--
-- Name: idx_activity_user_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_activity_user_time ON public.activity_log USING btree (user_id, created_at DESC);


--
-- Name: idx_audit_table; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_table ON public.audit_log USING btree (table_name, record_id);


--
-- Name: idx_auth_expires; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_auth_expires ON public.auth_tokens USING btree (expires_at);


--
-- Name: idx_bills_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bills_active ON public.bills USING btree (is_active);


--
-- Name: idx_goals_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_goals_active ON public.goals USING btree (is_active);


--
-- Name: idx_jl_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_jl_account ON public.journal_lines USING btree (account_code);


--
-- Name: idx_jl_doc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_jl_doc ON public.journal_lines USING btree (doc_number);


--
-- Name: idx_receipts_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receipts_created ON public.receipts USING btree (created_at DESC);


--
-- Name: idx_receipts_doc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receipts_doc ON public.receipts USING btree (doc_number);


--
-- Name: idx_receipts_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receipts_status ON public.receipts USING btree (status);


--
-- Name: idx_recurring_due; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_recurring_due ON public.recurring_transactions USING btree (next_run) WHERE is_active;


--
-- Name: idx_transaction_tags_tag; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transaction_tags_tag ON public.transaction_tags USING btree (tag_id);


--
-- Name: idx_tx_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tx_created ON public.transactions USING btree (created_at DESC);


--
-- Name: idx_tx_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tx_date ON public.transactions USING btree (transaction_date);


--
-- Name: idx_tx_period; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tx_period ON public.transactions USING btree (period_year, period_month);


--
-- Name: ix_realtime_subscription_entity; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX ix_realtime_subscription_entity ON realtime.subscription USING btree (entity);


--
-- Name: messages_inserted_at_topic_index; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX messages_inserted_at_topic_index ON ONLY realtime.messages USING btree (inserted_at DESC, topic) WHERE ((extension = 'broadcast'::text) AND (private IS TRUE));


--
-- Name: subscription_subscription_id_entity_filters_action_filter_selec; Type: INDEX; Schema: realtime; Owner: -
--

CREATE UNIQUE INDEX subscription_subscription_id_entity_filters_action_filter_selec ON realtime.subscription USING btree (subscription_id, entity, filters, action_filter, COALESCE(selected_columns, '{}'::text[]));


--
-- Name: bname; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX bname ON storage.buckets USING btree (name);


--
-- Name: bucketid_objname; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX bucketid_objname ON storage.objects USING btree (bucket_id, name);


--
-- Name: buckets_analytics_unique_name_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX buckets_analytics_unique_name_idx ON storage.buckets_analytics USING btree (name) WHERE (deleted_at IS NULL);


--
-- Name: idx_multipart_uploads_list; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_multipart_uploads_list ON storage.s3_multipart_uploads USING btree (bucket_id, key, created_at);


--
-- Name: idx_objects_bucket_id_name; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_objects_bucket_id_name ON storage.objects USING btree (bucket_id, name COLLATE "C");


--
-- Name: idx_objects_bucket_id_name_lower; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_objects_bucket_id_name_lower ON storage.objects USING btree (bucket_id, lower(name) COLLATE "C");


--
-- Name: name_prefix_search; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX name_prefix_search ON storage.objects USING btree (name text_pattern_ops);


--
-- Name: vector_indexes_name_bucket_id_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX vector_indexes_name_bucket_id_idx ON storage.vector_indexes USING btree (name, bucket_id);


--
-- Name: bills trg_audit_bills; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_bills AFTER INSERT OR DELETE OR UPDATE ON public.bills FOR EACH ROW EXECUTE FUNCTION public.fn_audit_config('id');


--
-- Name: bot_aliases trg_audit_bot_aliases; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_bot_aliases AFTER INSERT OR DELETE OR UPDATE ON public.bot_aliases FOR EACH ROW EXECUTE FUNCTION public.fn_audit_config('alias');


--
-- Name: bot_settings trg_audit_bot_settings; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_bot_settings AFTER INSERT OR DELETE OR UPDATE ON public.bot_settings FOR EACH ROW EXECUTE FUNCTION public.fn_audit_config('key');


--
-- Name: budgets trg_audit_budgets; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_budgets AFTER INSERT OR DELETE OR UPDATE ON public.budgets FOR EACH ROW EXECUTE FUNCTION public.fn_audit_config('account_code');


--
-- Name: goals trg_audit_goals; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_goals AFTER INSERT OR DELETE OR UPDATE ON public.goals FOR EACH ROW EXECUTE FUNCTION public.fn_audit_config('id');


--
-- Name: journal_lines trg_audit_journal_lines; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_journal_lines AFTER INSERT OR UPDATE ON public.journal_lines FOR EACH ROW EXECUTE FUNCTION public.fn_audit();


--
-- Name: recurring_transactions trg_audit_recurring; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_recurring AFTER INSERT OR DELETE OR UPDATE ON public.recurring_transactions FOR EACH ROW EXECUTE FUNCTION public.fn_audit_config('id');


--
-- Name: tags trg_audit_tags; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_tags AFTER INSERT OR DELETE OR UPDATE ON public.tags FOR EACH ROW EXECUTE FUNCTION public.fn_audit_config('id');


--
-- Name: transactions trg_audit_transactions; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_transactions AFTER INSERT OR UPDATE ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.fn_audit();


--
-- Name: transfer_fee_rules trg_audit_transfer_fee_rules; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_transfer_fee_rules AFTER INSERT OR DELETE OR UPDATE ON public.transfer_fee_rules FOR EACH ROW EXECUTE FUNCTION public.fn_audit_config('from_account', 'to_account');


--
-- Name: journal_lines trg_nodelete_journal_lines; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_nodelete_journal_lines BEFORE DELETE ON public.journal_lines FOR EACH ROW EXECUTE FUNCTION public.fn_no_delete();


--
-- Name: transactions trg_nodelete_transactions; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_nodelete_transactions BEFORE DELETE ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.fn_no_delete();


--
-- Name: subscription tr_check_filters; Type: TRIGGER; Schema: realtime; Owner: -
--

CREATE TRIGGER tr_check_filters BEFORE INSERT OR UPDATE ON realtime.subscription FOR EACH ROW EXECUTE FUNCTION realtime.subscription_check_filters();


--
-- Name: buckets enforce_bucket_name_length_trigger; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER enforce_bucket_name_length_trigger BEFORE INSERT OR UPDATE OF name ON storage.buckets FOR EACH ROW EXECUTE FUNCTION storage.enforce_bucket_name_length();


--
-- Name: buckets protect_buckets_delete; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER protect_buckets_delete BEFORE DELETE ON storage.buckets FOR EACH STATEMENT EXECUTE FUNCTION storage.protect_delete();


--
-- Name: objects protect_objects_delete; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER protect_objects_delete BEFORE DELETE ON storage.objects FOR EACH STATEMENT EXECUTE FUNCTION storage.protect_delete();


--
-- Name: objects update_objects_updated_at; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER update_objects_updated_at BEFORE UPDATE ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.update_updated_at_column();


--
-- Name: identities identities_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: mfa_amr_claims mfa_amr_claims_session_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT mfa_amr_claims_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id) ON DELETE CASCADE;


--
-- Name: mfa_challenges mfa_challenges_auth_factor_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_challenges
    ADD CONSTRAINT mfa_challenges_auth_factor_id_fkey FOREIGN KEY (factor_id) REFERENCES auth.mfa_factors(id) ON DELETE CASCADE;


--
-- Name: mfa_factors mfa_factors_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: oauth_authorizations oauth_authorizations_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_authorizations oauth_authorizations_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: oauth_consents oauth_consents_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_consents oauth_consents_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: one_time_tokens one_time_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.one_time_tokens
    ADD CONSTRAINT one_time_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: refresh_tokens refresh_tokens_session_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id) ON DELETE CASCADE;


--
-- Name: saml_providers saml_providers_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: saml_relay_states saml_relay_states_flow_state_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_flow_state_id_fkey FOREIGN KEY (flow_state_id) REFERENCES auth.flow_state(id) ON DELETE CASCADE;


--
-- Name: saml_relay_states saml_relay_states_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_oauth_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_oauth_client_id_fkey FOREIGN KEY (oauth_client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: sso_domains sso_domains_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_domains
    ADD CONSTRAINT sso_domains_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: webauthn_challenges webauthn_challenges_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.webauthn_challenges
    ADD CONSTRAINT webauthn_challenges_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: webauthn_credentials webauthn_credentials_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.webauthn_credentials
    ADD CONSTRAINT webauthn_credentials_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: bot_aliases bot_aliases_account_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bot_aliases
    ADD CONSTRAINT bot_aliases_account_code_fkey FOREIGN KEY (account_code) REFERENCES public.chart_of_accounts(code);


--
-- Name: bot_categories bot_categories_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bot_categories
    ADD CONSTRAINT bot_categories_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.bot_categories(id);


--
-- Name: bot_category_accounts bot_category_accounts_account_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bot_category_accounts
    ADD CONSTRAINT bot_category_accounts_account_code_fkey FOREIGN KEY (account_code) REFERENCES public.chart_of_accounts(code);


--
-- Name: bot_category_accounts bot_category_accounts_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bot_category_accounts
    ADD CONSTRAINT bot_category_accounts_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.bot_categories(id);


--
-- Name: budgets budgets_account_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budgets
    ADD CONSTRAINT budgets_account_code_fkey FOREIGN KEY (account_code) REFERENCES public.chart_of_accounts(code);


--
-- Name: chart_of_accounts chart_of_accounts_parent_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chart_of_accounts
    ADD CONSTRAINT chart_of_accounts_parent_code_fkey FOREIGN KEY (parent_code) REFERENCES public.chart_of_accounts(code);


--
-- Name: goals goals_account_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goals
    ADD CONSTRAINT goals_account_code_fkey FOREIGN KEY (account_code) REFERENCES public.chart_of_accounts(code);


--
-- Name: journal_lines journal_lines_account_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_lines
    ADD CONSTRAINT journal_lines_account_code_fkey FOREIGN KEY (account_code) REFERENCES public.chart_of_accounts(code);


--
-- Name: journal_lines journal_lines_doc_number_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_lines
    ADD CONSTRAINT journal_lines_doc_number_fkey FOREIGN KEY (doc_number) REFERENCES public.transactions(doc_number);


--
-- Name: receipts receipts_doc_number_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receipts
    ADD CONSTRAINT receipts_doc_number_fkey FOREIGN KEY (doc_number) REFERENCES public.transactions(doc_number);


--
-- Name: transaction_tags transaction_tags_doc_number_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_tags
    ADD CONSTRAINT transaction_tags_doc_number_fkey FOREIGN KEY (doc_number) REFERENCES public.transactions(doc_number);


--
-- Name: transaction_tags transaction_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transaction_tags
    ADD CONSTRAINT transaction_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.tags(id);


--
-- Name: transactions transactions_period_year_period_month_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_period_year_period_month_fkey FOREIGN KEY (period_year, period_month) REFERENCES public.periods(year, month);


--
-- Name: transactions transactions_reversal_of_doc_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_reversal_of_doc_fkey FOREIGN KEY (reversal_of_doc) REFERENCES public.transactions(doc_number);


--
-- Name: transfer_fee_rules transfer_fee_rules_fee_account_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transfer_fee_rules
    ADD CONSTRAINT transfer_fee_rules_fee_account_fkey FOREIGN KEY (fee_account) REFERENCES public.chart_of_accounts(code);


--
-- Name: transfer_fee_rules transfer_fee_rules_from_account_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transfer_fee_rules
    ADD CONSTRAINT transfer_fee_rules_from_account_fkey FOREIGN KEY (from_account) REFERENCES public.chart_of_accounts(code);


--
-- Name: transfer_fee_rules transfer_fee_rules_to_account_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transfer_fee_rules
    ADD CONSTRAINT transfer_fee_rules_to_account_fkey FOREIGN KEY (to_account) REFERENCES public.chart_of_accounts(code);


--
-- Name: objects objects_bucketId_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.objects
    ADD CONSTRAINT "objects_bucketId_fkey" FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads s3_multipart_uploads_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads
    ADD CONSTRAINT s3_multipart_uploads_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_upload_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_upload_id_fkey FOREIGN KEY (upload_id) REFERENCES storage.s3_multipart_uploads(id) ON DELETE CASCADE;


--
-- Name: vector_indexes vector_indexes_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.vector_indexes
    ADD CONSTRAINT vector_indexes_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets_vectors(id);


--
-- Name: audit_log_entries; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.audit_log_entries ENABLE ROW LEVEL SECURITY;

--
-- Name: flow_state; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.flow_state ENABLE ROW LEVEL SECURITY;

--
-- Name: identities; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.identities ENABLE ROW LEVEL SECURITY;

--
-- Name: instances; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.instances ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_amr_claims; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_amr_claims ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_challenges; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_challenges ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_factors; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_factors ENABLE ROW LEVEL SECURITY;

--
-- Name: one_time_tokens; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.one_time_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: refresh_tokens; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.refresh_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: saml_providers; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.saml_providers ENABLE ROW LEVEL SECURITY;

--
-- Name: saml_relay_states; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.saml_relay_states ENABLE ROW LEVEL SECURITY;

--
-- Name: schema_migrations; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.schema_migrations ENABLE ROW LEVEL SECURITY;

--
-- Name: sessions; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: sso_domains; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sso_domains ENABLE ROW LEVEL SECURITY;

--
-- Name: sso_providers; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sso_providers ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;

--
-- Name: Fintrack_project; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public."Fintrack_project" ENABLE ROW LEVEL SECURITY;

--
-- Name: activity_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.activity_log ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

--
-- Name: auth_tokens; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.auth_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: bills; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.bills ENABLE ROW LEVEL SECURITY;

--
-- Name: bot_aliases; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.bot_aliases ENABLE ROW LEVEL SECURITY;

--
-- Name: bot_categories; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.bot_categories ENABLE ROW LEVEL SECURITY;

--
-- Name: bot_category_accounts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.bot_category_accounts ENABLE ROW LEVEL SECURITY;

--
-- Name: bot_settings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.bot_settings ENABLE ROW LEVEL SECURITY;

--
-- Name: bot_state; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.bot_state ENABLE ROW LEVEL SECURITY;

--
-- Name: budgets; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;

--
-- Name: chart_of_accounts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.chart_of_accounts ENABLE ROW LEVEL SECURITY;

--
-- Name: daily_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.daily_log ENABLE ROW LEVEL SECURITY;

--
-- Name: goals; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.goals ENABLE ROW LEVEL SECURITY;

--
-- Name: journal_lines; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.journal_lines ENABLE ROW LEVEL SECURITY;

--
-- Name: periods; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.periods ENABLE ROW LEVEL SECURITY;

--
-- Name: receipts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.receipts ENABLE ROW LEVEL SECURITY;

--
-- Name: recurring_transactions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.recurring_transactions ENABLE ROW LEVEL SECURITY;

--
-- Name: sequences; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sequences ENABLE ROW LEVEL SECURITY;

--
-- Name: tags; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;

--
-- Name: transaction_tags; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.transaction_tags ENABLE ROW LEVEL SECURITY;

--
-- Name: transactions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

--
-- Name: transfer_fee_rules; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.transfer_fee_rules ENABLE ROW LEVEL SECURITY;

--
-- Name: messages; Type: ROW SECURITY; Schema: realtime; Owner: -
--

ALTER TABLE realtime.messages ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets_analytics; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets_analytics ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets_vectors; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets_vectors ENABLE ROW LEVEL SECURITY;

--
-- Name: migrations; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.migrations ENABLE ROW LEVEL SECURITY;

--
-- Name: objects; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

--
-- Name: s3_multipart_uploads; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.s3_multipart_uploads ENABLE ROW LEVEL SECURITY;

--
-- Name: s3_multipart_uploads_parts; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.s3_multipart_uploads_parts ENABLE ROW LEVEL SECURITY;

--
-- Name: vector_indexes; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.vector_indexes ENABLE ROW LEVEL SECURITY;

--
-- Name: supabase_realtime; Type: PUBLICATION; Schema: -; Owner: -
--

CREATE PUBLICATION supabase_realtime WITH (publish = 'insert, update, delete, truncate');


--
-- Name: supabase_realtime Fintrack_project; Type: PUBLICATION TABLE; Schema: public; Owner: -
--

ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public."Fintrack_project";


--
-- Name: issue_graphql_placeholder; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_graphql_placeholder ON sql_drop
         WHEN TAG IN ('DROP EXTENSION')
   EXECUTE FUNCTION extensions.set_graphql_placeholder();


--
-- Name: issue_pg_cron_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_cron_access ON ddl_command_end
         WHEN TAG IN ('CREATE EXTENSION')
   EXECUTE FUNCTION extensions.grant_pg_cron_access();


--
-- Name: issue_pg_graphql_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_graphql_access ON ddl_command_end
         WHEN TAG IN ('CREATE EXTENSION')
   EXECUTE FUNCTION extensions.grant_pg_graphql_access();


--
-- Name: issue_pg_net_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_net_access ON ddl_command_end
         WHEN TAG IN ('CREATE EXTENSION')
   EXECUTE FUNCTION extensions.grant_pg_net_access();


--
-- Name: pgrst_ddl_watch; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER pgrst_ddl_watch ON ddl_command_end
   EXECUTE FUNCTION extensions.pgrst_ddl_watch();


--
-- Name: pgrst_drop_watch; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER pgrst_drop_watch ON sql_drop
   EXECUTE FUNCTION extensions.pgrst_drop_watch();


--
-- PostgreSQL database dump complete
--

\unrestrict LcVA9j8nqAbqvctzBzRLJ13lMsdqUgA7wu6l7x9bBoyPDlI5QWwUAixttHnuuEU

