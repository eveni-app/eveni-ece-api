SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: hstore; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS hstore WITH SCHEMA public;


--
-- Name: EXTENSION hstore; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION hstore IS 'data type for storing sets of (key, value) pairs';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: logidze_capture_exception(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.logidze_capture_exception(error_data jsonb) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
  -- version: 1
BEGIN
  -- Feel free to change this function to change Logidze behavior on exception.
  --
  -- Return `false` to raise exception or `true` to commit record changes.
  --
  -- `error_data` contains:
  --   - returned_sqlstate
  --   - message_text
  --   - pg_exception_detail
  --   - pg_exception_hint
  --   - pg_exception_context
  --   - schema_name
  --   - table_name
  -- Learn more about available keys:
  -- https://www.postgresql.org/docs/9.6/plpgsql-control-structures.html#PLPGSQL-EXCEPTION-DIAGNOSTICS-VALUES
  --

  return false;
END;
$$;


--
-- Name: logidze_compact_history(jsonb, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.logidze_compact_history(log_data jsonb, cutoff integer DEFAULT 1) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
  -- version: 1
  DECLARE
    merged jsonb;
  BEGIN
    LOOP
      merged := jsonb_build_object(
        'ts',
        log_data#>'{h,1,ts}',
        'v',
        log_data#>'{h,1,v}',
        'c',
        (log_data#>'{h,0,c}') || (log_data#>'{h,1,c}')
      );

      IF (log_data#>'{h,1}' ? 'm') THEN
        merged := jsonb_set(merged, ARRAY['m'], log_data#>'{h,1,m}');
      END IF;

      log_data := jsonb_set(
        log_data,
        '{h}',
        jsonb_set(
          log_data->'h',
          '{1}',
          merged
        ) - 0
      );

      cutoff := cutoff - 1;

      EXIT WHEN cutoff <= 0;
    END LOOP;

    return log_data;
  END;
$$;


--
-- Name: logidze_filter_keys(jsonb, text[], boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.logidze_filter_keys(obj jsonb, keys text[], include_columns boolean DEFAULT false) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
  -- version: 1
  DECLARE
    res jsonb;
    key text;
  BEGIN
    res := '{}';

    IF include_columns THEN
      FOREACH key IN ARRAY keys
      LOOP
        IF obj ? key THEN
          res = jsonb_insert(res, ARRAY[key], obj->key);
        END IF;
      END LOOP;
    ELSE
      res = obj;
      FOREACH key IN ARRAY keys
      LOOP
        res = res - key;
      END LOOP;
    END IF;

    RETURN res;
  END;
$$;


--
-- Name: logidze_logger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.logidze_logger() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
  -- version: 5
  DECLARE
    changes jsonb;
    version jsonb;
    full_snapshot boolean;
    log_data jsonb;
    new_v integer;
    size integer;
    history_limit integer;
    debounce_time integer;
    current_version integer;
    k text;
    iterator integer;
    item record;
    columns text[];
    include_columns boolean;
    detached_log_data jsonb;
    -- We use `detached_loggable_type` for:
    -- 1. Checking if current implementation is `--detached` (`log_data` is stored in a separated table)
    -- 2. If implementation is `--detached` then we use detached_loggable_type to determine
    --    to which table current `log_data` record belongs
    detached_loggable_type text;
    log_data_table_name text;
    log_data_is_empty boolean;
    log_data_ts_key_data text;
    ts timestamp with time zone;
    ts_column text;
    err_sqlstate text;
    err_message text;
    err_detail text;
    err_hint text;
    err_context text;
    err_table_name text;
    err_schema_name text;
    err_jsonb jsonb;
    err_captured boolean;
  BEGIN
    ts_column := NULLIF(TG_ARGV[1], 'null');
    columns := NULLIF(TG_ARGV[2], 'null');
    include_columns := NULLIF(TG_ARGV[3], 'null');
    detached_loggable_type := NULLIF(TG_ARGV[5], 'null');
    log_data_table_name := NULLIF(TG_ARGV[6], 'null');

    -- getting previous log_data if it exists for detached `log_data` storage variant
    IF detached_loggable_type IS NOT NULL
    THEN
      EXECUTE format(
        'SELECT ldtn.log_data ' ||
        'FROM %I ldtn ' ||
        'WHERE ldtn.loggable_type = $1 ' ||
          'AND ldtn.loggable_id = $2 '  ||
        'LIMIT 1',
        log_data_table_name
      ) USING detached_loggable_type, NEW.id INTO detached_log_data;
    END IF;

    IF detached_loggable_type IS NULL
    THEN
        log_data_is_empty = NEW.log_data is NULL OR NEW.log_data = '{}'::jsonb;
    ELSE
        log_data_is_empty = detached_log_data IS NULL OR detached_log_data = '{}'::jsonb;
    END IF;

    IF log_data_is_empty
    THEN
      IF columns IS NOT NULL THEN
        log_data = logidze_snapshot(to_jsonb(NEW.*), ts_column, columns, include_columns);
      ELSE
        log_data = logidze_snapshot(to_jsonb(NEW.*), ts_column);
      END IF;

      IF log_data#>>'{h, -1, c}' != '{}' THEN
        IF detached_loggable_type IS NULL
        THEN
          NEW.log_data := log_data;
        ELSE
          EXECUTE format(
            'INSERT INTO %I(log_data, loggable_type, loggable_id) ' ||
            'VALUES ($1, $2, $3);',
            log_data_table_name
          ) USING log_data, detached_loggable_type, NEW.id;
        END IF;
      END IF;

    ELSE

      IF TG_OP = 'UPDATE' AND (to_jsonb(NEW.*) = to_jsonb(OLD.*)) THEN
        RETURN NEW; -- pass
      END IF;

      history_limit := NULLIF(TG_ARGV[0], 'null');
      debounce_time := NULLIF(TG_ARGV[4], 'null');

      IF detached_loggable_type IS NULL
      THEN
          log_data := NEW.log_data;
      ELSE
          log_data := detached_log_data;
      END IF;

      current_version := (log_data->>'v')::int;

      IF ts_column IS NULL THEN
        ts := statement_timestamp();
      ELSEIF TG_OP = 'UPDATE' THEN
        ts := (to_jsonb(NEW.*) ->> ts_column)::timestamp with time zone;
        IF ts IS NULL OR ts = (to_jsonb(OLD.*) ->> ts_column)::timestamp with time zone THEN
          ts := statement_timestamp();
        END IF;
      ELSEIF TG_OP = 'INSERT' THEN
        ts := (to_jsonb(NEW.*) ->> ts_column)::timestamp with time zone;

        IF detached_loggable_type IS NULL
        THEN
          log_data_ts_key_data = NEW.log_data #>> '{h,-1,ts}';
        ELSE
          log_data_ts_key_data = detached_log_data #>> '{h,-1,ts}';
        END IF;

        IF ts IS NULL OR (extract(epoch from ts) * 1000)::bigint = log_data_ts_key_data::bigint THEN
            ts := statement_timestamp();
        END IF;
      END IF;

      full_snapshot := (coalesce(current_setting('logidze.full_snapshot', true), '') = 'on') OR (TG_OP = 'INSERT');

      IF current_version < (log_data#>>'{h,-1,v}')::int THEN
        iterator := 0;
        FOR item in SELECT * FROM jsonb_array_elements(log_data->'h')
        LOOP
          IF (item.value->>'v')::int > current_version THEN
            log_data := jsonb_set(
              log_data,
              '{h}',
              (log_data->'h') - iterator
            );
          END IF;
          iterator := iterator + 1;
        END LOOP;
      END IF;

      changes := '{}';

      IF full_snapshot THEN
        BEGIN
          changes = hstore_to_jsonb_loose(hstore(NEW.*));
        EXCEPTION
          WHEN NUMERIC_VALUE_OUT_OF_RANGE THEN
            changes = row_to_json(NEW.*)::jsonb;
            FOR k IN (SELECT key FROM jsonb_each(changes))
            LOOP
              IF jsonb_typeof(changes->k) = 'object' THEN
                changes = jsonb_set(changes, ARRAY[k], to_jsonb(changes->>k));
              END IF;
            END LOOP;
        END;
      ELSE
        BEGIN
          changes = hstore_to_jsonb_loose(
                hstore(NEW.*) - hstore(OLD.*)
            );
        EXCEPTION
          WHEN NUMERIC_VALUE_OUT_OF_RANGE THEN
            changes = (SELECT
              COALESCE(json_object_agg(key, value), '{}')::jsonb
              FROM
              jsonb_each(row_to_json(NEW.*)::jsonb)
              WHERE NOT jsonb_build_object(key, value) <@ row_to_json(OLD.*)::jsonb);
            FOR k IN (SELECT key FROM jsonb_each(changes))
            LOOP
              IF jsonb_typeof(changes->k) = 'object' THEN
                changes = jsonb_set(changes, ARRAY[k], to_jsonb(changes->>k));
              END IF;
            END LOOP;
        END;
      END IF;

      -- We store `log_data` in a separate table for the `detached` mode
      -- So we remove `log_data` only when we store historic data in the record's origin table
      IF detached_loggable_type IS NULL
      THEN
          changes = changes - 'log_data';
      END IF;

      IF columns IS NOT NULL THEN
        changes = logidze_filter_keys(changes, columns, include_columns);
      END IF;

      IF changes = '{}' THEN
        RETURN NEW; -- pass
      END IF;

      new_v := (log_data#>>'{h,-1,v}')::int + 1;

      size := jsonb_array_length(log_data->'h');
      version := logidze_version(new_v, changes, ts);

      IF (
        debounce_time IS NOT NULL AND
        (version->>'ts')::bigint - (log_data#>'{h,-1,ts}')::text::bigint <= debounce_time
      ) THEN
        -- merge new version with the previous one
        new_v := (log_data#>>'{h,-1,v}')::int;
        version := logidze_version(new_v, (log_data#>'{h,-1,c}')::jsonb || changes, ts);
        -- remove the previous version from log
        log_data := jsonb_set(
          log_data,
          '{h}',
          (log_data->'h') - (size - 1)
        );
      END IF;

      log_data := jsonb_set(
        log_data,
        ARRAY['h', size::text],
        version,
        true
      );

      log_data := jsonb_set(
        log_data,
        '{v}',
        to_jsonb(new_v)
      );

      IF history_limit IS NOT NULL AND history_limit <= size THEN
        log_data := logidze_compact_history(log_data, size - history_limit + 1);
      END IF;

      IF detached_loggable_type IS NULL
      THEN
        NEW.log_data := log_data;
      ELSE
        detached_log_data = log_data;
        EXECUTE format(
          'UPDATE %I ' ||
          'SET log_data = $1 ' ||
          'WHERE %I.loggable_type = $2 ' ||
          'AND %I.loggable_id = $3',
          log_data_table_name,
          log_data_table_name,
          log_data_table_name
        ) USING detached_log_data, detached_loggable_type, NEW.id;
      END IF;
    END IF;

    RETURN NEW; -- result
  EXCEPTION
    WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS err_sqlstate = RETURNED_SQLSTATE,
                              err_message = MESSAGE_TEXT,
                              err_detail = PG_EXCEPTION_DETAIL,
                              err_hint = PG_EXCEPTION_HINT,
                              err_context = PG_EXCEPTION_CONTEXT,
                              err_schema_name = SCHEMA_NAME,
                              err_table_name = TABLE_NAME;
      err_jsonb := jsonb_build_object(
        'returned_sqlstate', err_sqlstate,
        'message_text', err_message,
        'pg_exception_detail', err_detail,
        'pg_exception_hint', err_hint,
        'pg_exception_context', err_context,
        'schema_name', err_schema_name,
        'table_name', err_table_name
      );
      err_captured = logidze_capture_exception(err_jsonb);
      IF err_captured THEN
        return NEW;
      ELSE
        RAISE;
      END IF;
  END;
$_$;


--
-- Name: logidze_logger_after(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.logidze_logger_after() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
  -- version: 5


  DECLARE
    changes jsonb;
    version jsonb;
    full_snapshot boolean;
    log_data jsonb;
    new_v integer;
    size integer;
    history_limit integer;
    debounce_time integer;
    current_version integer;
    k text;
    iterator integer;
    item record;
    columns text[];
    include_columns boolean;
    detached_log_data jsonb;
    -- We use `detached_loggable_type` for:
    -- 1. Checking if current implementation is `--detached` (`log_data` is stored in a separated table)
    -- 2. If implementation is `--detached` then we use detached_loggable_type to determine
    --    to which table current `log_data` record belongs
    detached_loggable_type text;
    log_data_table_name text;
    log_data_is_empty boolean;
    log_data_ts_key_data text;
    ts timestamp with time zone;
    ts_column text;
    err_sqlstate text;
    err_message text;
    err_detail text;
    err_hint text;
    err_context text;
    err_table_name text;
    err_schema_name text;
    err_jsonb jsonb;
    err_captured boolean;
  BEGIN
    ts_column := NULLIF(TG_ARGV[1], 'null');
    columns := NULLIF(TG_ARGV[2], 'null');
    include_columns := NULLIF(TG_ARGV[3], 'null');
    detached_loggable_type := NULLIF(TG_ARGV[5], 'null');
    log_data_table_name := NULLIF(TG_ARGV[6], 'null');

    -- getting previous log_data if it exists for detached `log_data` storage variant
    IF detached_loggable_type IS NOT NULL
    THEN
      EXECUTE format(
        'SELECT ldtn.log_data ' ||
        'FROM %I ldtn ' ||
        'WHERE ldtn.loggable_type = $1 ' ||
          'AND ldtn.loggable_id = $2 '  ||
        'LIMIT 1',
        log_data_table_name
      ) USING detached_loggable_type, NEW.id INTO detached_log_data;
    END IF;

    IF detached_loggable_type IS NULL
    THEN
        log_data_is_empty = NEW.log_data is NULL OR NEW.log_data = '{}'::jsonb;
    ELSE
        log_data_is_empty = detached_log_data IS NULL OR detached_log_data = '{}'::jsonb;
    END IF;

    IF log_data_is_empty
    THEN
      IF columns IS NOT NULL THEN
        log_data = logidze_snapshot(to_jsonb(NEW.*), ts_column, columns, include_columns);
      ELSE
        log_data = logidze_snapshot(to_jsonb(NEW.*), ts_column);
      END IF;

      IF log_data#>>'{h, -1, c}' != '{}' THEN
        IF detached_loggable_type IS NULL
        THEN
          NEW.log_data := log_data;
        ELSE
          EXECUTE format(
            'INSERT INTO %I(log_data, loggable_type, loggable_id) ' ||
            'VALUES ($1, $2, $3);',
            log_data_table_name
          ) USING log_data, detached_loggable_type, NEW.id;
        END IF;
      END IF;

    ELSE

      IF TG_OP = 'UPDATE' AND (to_jsonb(NEW.*) = to_jsonb(OLD.*)) THEN
        RETURN NULL;
      END IF;

      history_limit := NULLIF(TG_ARGV[0], 'null');
      debounce_time := NULLIF(TG_ARGV[4], 'null');

      IF detached_loggable_type IS NULL
      THEN
          log_data := NEW.log_data;
      ELSE
          log_data := detached_log_data;
      END IF;

      current_version := (log_data->>'v')::int;

      IF ts_column IS NULL THEN
        ts := statement_timestamp();
      ELSEIF TG_OP = 'UPDATE' THEN
        ts := (to_jsonb(NEW.*) ->> ts_column)::timestamp with time zone;
        IF ts IS NULL OR ts = (to_jsonb(OLD.*) ->> ts_column)::timestamp with time zone THEN
          ts := statement_timestamp();
        END IF;
      ELSEIF TG_OP = 'INSERT' THEN
        ts := (to_jsonb(NEW.*) ->> ts_column)::timestamp with time zone;

        IF detached_loggable_type IS NULL
        THEN
          log_data_ts_key_data = NEW.log_data #>> '{h,-1,ts}';
        ELSE
          log_data_ts_key_data = detached_log_data #>> '{h,-1,ts}';
        END IF;

        IF ts IS NULL OR (extract(epoch from ts) * 1000)::bigint = log_data_ts_key_data::bigint THEN
            ts := statement_timestamp();
        END IF;
      END IF;

      full_snapshot := (coalesce(current_setting('logidze.full_snapshot', true), '') = 'on') OR (TG_OP = 'INSERT');

      IF current_version < (log_data#>>'{h,-1,v}')::int THEN
        iterator := 0;
        FOR item in SELECT * FROM jsonb_array_elements(log_data->'h')
        LOOP
          IF (item.value->>'v')::int > current_version THEN
            log_data := jsonb_set(
              log_data,
              '{h}',
              (log_data->'h') - iterator
            );
          END IF;
          iterator := iterator + 1;
        END LOOP;
      END IF;

      changes := '{}';

      IF full_snapshot THEN
        BEGIN
          changes = hstore_to_jsonb_loose(hstore(NEW.*));
        EXCEPTION
          WHEN NUMERIC_VALUE_OUT_OF_RANGE THEN
            changes = row_to_json(NEW.*)::jsonb;
            FOR k IN (SELECT key FROM jsonb_each(changes))
            LOOP
              IF jsonb_typeof(changes->k) = 'object' THEN
                changes = jsonb_set(changes, ARRAY[k], to_jsonb(changes->>k));
              END IF;
            END LOOP;
        END;
      ELSE
        BEGIN
          changes = hstore_to_jsonb_loose(
                hstore(NEW.*) - hstore(OLD.*)
            );
        EXCEPTION
          WHEN NUMERIC_VALUE_OUT_OF_RANGE THEN
            changes = (SELECT
              COALESCE(json_object_agg(key, value), '{}')::jsonb
              FROM
              jsonb_each(row_to_json(NEW.*)::jsonb)
              WHERE NOT jsonb_build_object(key, value) <@ row_to_json(OLD.*)::jsonb);
            FOR k IN (SELECT key FROM jsonb_each(changes))
            LOOP
              IF jsonb_typeof(changes->k) = 'object' THEN
                changes = jsonb_set(changes, ARRAY[k], to_jsonb(changes->>k));
              END IF;
            END LOOP;
        END;
      END IF;

      -- We store `log_data` in a separate table for the `detached` mode
      -- So we remove `log_data` only when we store historic data in the record's origin table
      IF detached_loggable_type IS NULL
      THEN
          changes = changes - 'log_data';
      END IF;

      IF columns IS NOT NULL THEN
        changes = logidze_filter_keys(changes, columns, include_columns);
      END IF;

      IF changes = '{}' THEN
        RETURN NULL;
      END IF;

      new_v := (log_data#>>'{h,-1,v}')::int + 1;

      size := jsonb_array_length(log_data->'h');
      version := logidze_version(new_v, changes, ts);

      IF (
        debounce_time IS NOT NULL AND
        (version->>'ts')::bigint - (log_data#>'{h,-1,ts}')::text::bigint <= debounce_time
      ) THEN
        -- merge new version with the previous one
        new_v := (log_data#>>'{h,-1,v}')::int;
        version := logidze_version(new_v, (log_data#>'{h,-1,c}')::jsonb || changes, ts);
        -- remove the previous version from log
        log_data := jsonb_set(
          log_data,
          '{h}',
          (log_data->'h') - (size - 1)
        );
      END IF;

      log_data := jsonb_set(
        log_data,
        ARRAY['h', size::text],
        version,
        true
      );

      log_data := jsonb_set(
        log_data,
        '{v}',
        to_jsonb(new_v)
      );

      IF history_limit IS NOT NULL AND history_limit <= size THEN
        log_data := logidze_compact_history(log_data, size - history_limit + 1);
      END IF;

      IF detached_loggable_type IS NULL
      THEN
        NEW.log_data := log_data;
      ELSE
        detached_log_data = log_data;
        EXECUTE format(
          'UPDATE %I ' ||
          'SET log_data = $1 ' ||
          'WHERE %I.loggable_type = $2 ' ||
          'AND %I.loggable_id = $3',
          log_data_table_name,
          log_data_table_name,
          log_data_table_name
        ) USING detached_log_data, detached_loggable_type, NEW.id;
      END IF;
    END IF;

    IF detached_loggable_type IS NULL
    THEN
      EXECUTE format('UPDATE %I.%I SET "log_data" = $1 WHERE ctid = %L', TG_TABLE_SCHEMA, TG_TABLE_NAME, NEW.CTID) USING NEW.log_data;
    END IF;

    RETURN NULL;

  EXCEPTION
    WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS err_sqlstate = RETURNED_SQLSTATE,
                              err_message = MESSAGE_TEXT,
                              err_detail = PG_EXCEPTION_DETAIL,
                              err_hint = PG_EXCEPTION_HINT,
                              err_context = PG_EXCEPTION_CONTEXT,
                              err_schema_name = SCHEMA_NAME,
                              err_table_name = TABLE_NAME;
      err_jsonb := jsonb_build_object(
        'returned_sqlstate', err_sqlstate,
        'message_text', err_message,
        'pg_exception_detail', err_detail,
        'pg_exception_hint', err_hint,
        'pg_exception_context', err_context,
        'schema_name', err_schema_name,
        'table_name', err_table_name
      );
      err_captured = logidze_capture_exception(err_jsonb);
      IF err_captured THEN
        return NEW;
      ELSE
        RAISE;
      END IF;
  END;
$_$;


--
-- Name: logidze_snapshot(jsonb, text, text[], boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.logidze_snapshot(item jsonb, ts_column text DEFAULT NULL::text, columns text[] DEFAULT NULL::text[], include_columns boolean DEFAULT false) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
  -- version: 3
  DECLARE
    ts timestamp with time zone;
    k text;
  BEGIN
    item = item - 'log_data';
    IF ts_column IS NULL THEN
      ts := statement_timestamp();
    ELSE
      ts := coalesce((item->>ts_column)::timestamp with time zone, statement_timestamp());
    END IF;

    IF columns IS NOT NULL THEN
      item := logidze_filter_keys(item, columns, include_columns);
    END IF;

    FOR k IN (SELECT key FROM jsonb_each(item))
    LOOP
      IF jsonb_typeof(item->k) = 'object' THEN
         item := jsonb_set(item, ARRAY[k], to_jsonb(item->>k));
      END IF;
    END LOOP;

    return json_build_object(
      'v', 1,
      'h', jsonb_build_array(
              logidze_version(1, item, ts)
            )
      );
  END;
$$;


--
-- Name: logidze_version(bigint, jsonb, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.logidze_version(v bigint, data jsonb, ts timestamp with time zone) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
  -- version: 2
  DECLARE
    buf jsonb;
  BEGIN
    data = data - 'log_data';
    buf := jsonb_build_object(
              'ts',
              (extract(epoch from ts) * 1000)::bigint,
              'v',
              v,
              'c',
              data
              );
    IF coalesce(current_setting('logidze.meta', true), '') <> '' THEN
      buf := jsonb_insert(buf, '{m}', current_setting('logidze.meta')::jsonb);
    END IF;
    RETURN buf;
  END;
$$;


--
-- Name: prevent_hard_deletes(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_hard_deletes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      BEGIN
        RAISE EXCEPTION
          'Prohibido por NOM-024-SSA3-2012: El borrado físico de registros médicos viola la '
          'retención obligatoria de 5 años establecida en NOM-004-SSA3-2012. '
          'Utilice borrado lógico actualizando discarded_at en lugar de DELETE.'
          USING ERRCODE = 'P0001';
        RETURN NULL;
      END;
      $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: cie10_diagnoses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cie10_diagnoses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying NOT NULL,
    description text NOT NULL,
    category character varying,
    chapter character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: clinical_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.clinical_histories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    patient_id uuid NOT NULL,
    hereditary_history jsonb DEFAULT '{}'::jsonb NOT NULL,
    pathological_history jsonb DEFAULT '{}'::jsonb NOT NULL,
    non_pathological_history jsonb DEFAULT '{}'::jsonb NOT NULL,
    gynecological_history jsonb DEFAULT '{}'::jsonb NOT NULL,
    log_data jsonb,
    discarded_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: clues_establishments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.clues_establishments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clues_code character varying NOT NULL,
    name character varying NOT NULL,
    state_code character varying,
    municipality character varying,
    institution_type character varying,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: digital_signatures; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.digital_signatures (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    signable_type character varying NOT NULL,
    signable_id uuid NOT NULL,
    doctor_id uuid NOT NULL,
    signature_payload text NOT NULL,
    certificate_serial text,
    signed_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: doctors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.doctors (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    professional_license character varying NOT NULL,
    specialty character varying,
    public_certificate text,
    discarded_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: informed_consents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.informed_consents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    patient_id uuid NOT NULL,
    doctor_id uuid NOT NULL,
    procedure_name character varying NOT NULL,
    risks text NOT NULL,
    benefits text NOT NULL,
    patient_accepted boolean DEFAULT false NOT NULL,
    accepted_at timestamp(6) without time zone,
    log_data jsonb,
    discarded_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: medications_catalogs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.medications_catalogs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    cve_code character varying NOT NULL,
    name character varying NOT NULL,
    active_ingredient character varying,
    route_of_administration character varying,
    presentation character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: patients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.patients (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    curp character varying NOT NULL,
    first_name character varying NOT NULL,
    last_name character varying NOT NULL,
    dob date NOT NULL,
    sex integer DEFAULT 0 NOT NULL,
    email character varying,
    phone character varying,
    discarded_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: prescriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.prescriptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    progress_note_id uuid NOT NULL,
    medications jsonb DEFAULT '[]'::jsonb NOT NULL,
    instructions text,
    log_data jsonb,
    discarded_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: progress_notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.progress_notes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    patient_id uuid NOT NULL,
    doctor_id uuid NOT NULL,
    vital_signs jsonb DEFAULT '{}'::jsonb NOT NULL,
    evolution text,
    diagnoses jsonb DEFAULT '[]'::jsonb NOT NULL,
    prognosis text,
    treatment_plan text,
    note_type character varying DEFAULT 'evolution'::character varying NOT NULL,
    log_data jsonb,
    discarded_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email character varying DEFAULT ''::character varying NOT NULL,
    encrypted_password character varying DEFAULT ''::character varying NOT NULL,
    reset_password_token character varying,
    reset_password_sent_at timestamp(6) without time zone,
    remember_created_at timestamp(6) without time zone,
    jti character varying DEFAULT ''::character varying NOT NULL,
    role integer DEFAULT 0 NOT NULL,
    discarded_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: cie10_diagnoses cie10_diagnoses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cie10_diagnoses
    ADD CONSTRAINT cie10_diagnoses_pkey PRIMARY KEY (id);


--
-- Name: clinical_histories clinical_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clinical_histories
    ADD CONSTRAINT clinical_histories_pkey PRIMARY KEY (id);


--
-- Name: clues_establishments clues_establishments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clues_establishments
    ADD CONSTRAINT clues_establishments_pkey PRIMARY KEY (id);


--
-- Name: digital_signatures digital_signatures_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.digital_signatures
    ADD CONSTRAINT digital_signatures_pkey PRIMARY KEY (id);


--
-- Name: doctors doctors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.doctors
    ADD CONSTRAINT doctors_pkey PRIMARY KEY (id);


--
-- Name: informed_consents informed_consents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.informed_consents
    ADD CONSTRAINT informed_consents_pkey PRIMARY KEY (id);


--
-- Name: medications_catalogs medications_catalogs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.medications_catalogs
    ADD CONSTRAINT medications_catalogs_pkey PRIMARY KEY (id);


--
-- Name: patients patients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_pkey PRIMARY KEY (id);


--
-- Name: prescriptions prescriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.prescriptions
    ADD CONSTRAINT prescriptions_pkey PRIMARY KEY (id);


--
-- Name: progress_notes progress_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.progress_notes
    ADD CONSTRAINT progress_notes_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: index_cie10_diagnoses_on_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cie10_diagnoses_on_category ON public.cie10_diagnoses USING btree (category);


--
-- Name: index_cie10_diagnoses_on_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cie10_diagnoses_on_code ON public.cie10_diagnoses USING btree (code);


--
-- Name: index_clinical_histories_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clinical_histories_on_discarded_at ON public.clinical_histories USING btree (discarded_at);


--
-- Name: index_clinical_histories_on_patient_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clinical_histories_on_patient_id ON public.clinical_histories USING btree (patient_id);


--
-- Name: index_clues_establishments_on_clues_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_clues_establishments_on_clues_code ON public.clues_establishments USING btree (clues_code);


--
-- Name: index_clues_establishments_on_state_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clues_establishments_on_state_code ON public.clues_establishments USING btree (state_code);


--
-- Name: index_digital_signatures_on_doctor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_digital_signatures_on_doctor_id ON public.digital_signatures USING btree (doctor_id);


--
-- Name: index_digital_signatures_on_signable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_digital_signatures_on_signable ON public.digital_signatures USING btree (signable_type, signable_id);


--
-- Name: index_digital_signatures_on_signed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_digital_signatures_on_signed_at ON public.digital_signatures USING btree (signed_at);


--
-- Name: index_doctors_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_doctors_on_discarded_at ON public.doctors USING btree (discarded_at);


--
-- Name: index_doctors_on_professional_license; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_doctors_on_professional_license ON public.doctors USING btree (professional_license);


--
-- Name: index_doctors_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_doctors_on_user_id ON public.doctors USING btree (user_id);


--
-- Name: index_informed_consents_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_informed_consents_on_discarded_at ON public.informed_consents USING btree (discarded_at);


--
-- Name: index_informed_consents_on_doctor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_informed_consents_on_doctor_id ON public.informed_consents USING btree (doctor_id);


--
-- Name: index_informed_consents_on_patient_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_informed_consents_on_patient_id ON public.informed_consents USING btree (patient_id);


--
-- Name: index_medications_catalogs_on_cve_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_medications_catalogs_on_cve_code ON public.medications_catalogs USING btree (cve_code);


--
-- Name: index_medications_catalogs_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_medications_catalogs_on_name ON public.medications_catalogs USING btree (name);


--
-- Name: index_patients_on_curp; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_patients_on_curp ON public.patients USING btree (curp);


--
-- Name: index_patients_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_patients_on_discarded_at ON public.patients USING btree (discarded_at);


--
-- Name: index_prescriptions_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_prescriptions_on_discarded_at ON public.prescriptions USING btree (discarded_at);


--
-- Name: index_prescriptions_on_progress_note_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_prescriptions_on_progress_note_id ON public.prescriptions USING btree (progress_note_id);


--
-- Name: index_progress_notes_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_progress_notes_on_discarded_at ON public.progress_notes USING btree (discarded_at);


--
-- Name: index_progress_notes_on_doctor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_progress_notes_on_doctor_id ON public.progress_notes USING btree (doctor_id);


--
-- Name: index_progress_notes_on_note_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_progress_notes_on_note_type ON public.progress_notes USING btree (note_type);


--
-- Name: index_progress_notes_on_patient_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_progress_notes_on_patient_id ON public.progress_notes USING btree (patient_id);


--
-- Name: index_users_on_discarded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_discarded_at ON public.users USING btree (discarded_at);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_jti ON public.users USING btree (jti);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: clinical_histories logidze_on_clinical_histories; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER logidze_on_clinical_histories BEFORE INSERT OR UPDATE ON public.clinical_histories FOR EACH ROW WHEN ((COALESCE(current_setting('logidze.disabled'::text, true), ''::text) <> 'on'::text)) EXECUTE FUNCTION public.logidze_logger('null', 'updated_at');


--
-- Name: informed_consents logidze_on_informed_consents; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER logidze_on_informed_consents BEFORE INSERT OR UPDATE ON public.informed_consents FOR EACH ROW WHEN ((COALESCE(current_setting('logidze.disabled'::text, true), ''::text) <> 'on'::text)) EXECUTE FUNCTION public.logidze_logger('null', 'updated_at');


--
-- Name: prescriptions logidze_on_prescriptions; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER logidze_on_prescriptions BEFORE INSERT OR UPDATE ON public.prescriptions FOR EACH ROW WHEN ((COALESCE(current_setting('logidze.disabled'::text, true), ''::text) <> 'on'::text)) EXECUTE FUNCTION public.logidze_logger('null', 'updated_at');


--
-- Name: progress_notes logidze_on_progress_notes; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER logidze_on_progress_notes BEFORE INSERT OR UPDATE ON public.progress_notes FOR EACH ROW WHEN ((COALESCE(current_setting('logidze.disabled'::text, true), ''::text) <> 'on'::text)) EXECUTE FUNCTION public.logidze_logger('null', 'updated_at');


--
-- Name: clinical_histories prevent_hard_deletes_on_clinical_histories; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER prevent_hard_deletes_on_clinical_histories BEFORE DELETE ON public.clinical_histories FOR EACH ROW EXECUTE FUNCTION public.prevent_hard_deletes();


--
-- Name: informed_consents prevent_hard_deletes_on_informed_consents; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER prevent_hard_deletes_on_informed_consents BEFORE DELETE ON public.informed_consents FOR EACH ROW EXECUTE FUNCTION public.prevent_hard_deletes();


--
-- Name: prescriptions prevent_hard_deletes_on_prescriptions; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER prevent_hard_deletes_on_prescriptions BEFORE DELETE ON public.prescriptions FOR EACH ROW EXECUTE FUNCTION public.prevent_hard_deletes();


--
-- Name: progress_notes prevent_hard_deletes_on_progress_notes; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER prevent_hard_deletes_on_progress_notes BEFORE DELETE ON public.progress_notes FOR EACH ROW EXECUTE FUNCTION public.prevent_hard_deletes();


--
-- Name: informed_consents fk_rails_0ba32f3c4a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.informed_consents
    ADD CONSTRAINT fk_rails_0ba32f3c4a FOREIGN KEY (doctor_id) REFERENCES public.doctors(id);


--
-- Name: progress_notes fk_rails_1fa2f7c6e0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.progress_notes
    ADD CONSTRAINT fk_rails_1fa2f7c6e0 FOREIGN KEY (doctor_id) REFERENCES public.doctors(id);


--
-- Name: progress_notes fk_rails_394fe4c14c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.progress_notes
    ADD CONSTRAINT fk_rails_394fe4c14c FOREIGN KEY (patient_id) REFERENCES public.patients(id);


--
-- Name: clinical_histories fk_rails_3f17f6d8a8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clinical_histories
    ADD CONSTRAINT fk_rails_3f17f6d8a8 FOREIGN KEY (patient_id) REFERENCES public.patients(id);


--
-- Name: digital_signatures fk_rails_7f3c8778c1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.digital_signatures
    ADD CONSTRAINT fk_rails_7f3c8778c1 FOREIGN KEY (doctor_id) REFERENCES public.doctors(id);


--
-- Name: doctors fk_rails_899b01ef33; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.doctors
    ADD CONSTRAINT fk_rails_899b01ef33 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: informed_consents fk_rails_d380ff56d5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.informed_consents
    ADD CONSTRAINT fk_rails_d380ff56d5 FOREIGN KEY (patient_id) REFERENCES public.patients(id);


--
-- Name: prescriptions fk_rails_db940e830f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.prescriptions
    ADD CONSTRAINT fk_rails_db940e830f FOREIGN KEY (progress_note_id) REFERENCES public.progress_notes(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260306021330'),
('20260306021234'),
('20260306021232'),
('20260306021230'),
('20260306015803'),
('20260306014837'),
('20260306014836'),
('20260306014207'),
('20260306014206'),
('20260306014204'),
('20260306014203'),
('20260306014202'),
('20260306014201'),
('20260306014200'),
('20260306014158'),
('20260306014031'),
('20260306014015'),
('20260306013758'),
('20260306013405');

