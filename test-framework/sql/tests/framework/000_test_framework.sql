-- ============================================================================
-- Iron Signal Platform SQL test framework
--
-- Test-only objects. This file must never be included in a production migration
-- manifest. The disposable test database is dropped after a successful run.
-- ============================================================================

BEGIN;

CREATE SCHEMA sql_test;

COMMENT ON SCHEMA sql_test IS
    'Test-only assertion framework for disposable Foundation validation databases.';

CREATE TABLE sql_test.results (
    result_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    test_file text NOT NULL,
    test_name text NOT NULL,
    status text NOT NULL,
    details text,
    recorded_at timestamp with time zone NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT results_status_ck CHECK (status IN ('PASS', 'FAIL', 'WARN')),
    CONSTRAINT results_test_file_nonempty_ck CHECK (btrim(test_file) <> ''),
    CONSTRAINT results_test_name_nonempty_ck CHECK (btrim(test_name) <> '')
);

CREATE TABLE sql_test.expected_migrations (
    manifest_position integer PRIMARY KEY,
    migration_id text NOT NULL UNIQUE,
    relative_path text NOT NULL UNIQUE,
    file_sha256 text NOT NULL,
    CONSTRAINT expected_migrations_position_ck CHECK (manifest_position > 0),
    CONSTRAINT expected_migrations_id_ck CHECK (
        migration_id ~ '^[0-9]{3}(_[a-z0-9]+)*$'
    ),
    CONSTRAINT expected_migrations_path_ck CHECK (
        relative_path ~ '^migrations/foundation/[0-9]{3}_[a-z0-9_]+[.]sql$'
    ),
    CONSTRAINT expected_migrations_sha256_ck CHECK (
        file_sha256 ~ '^[0-9a-f]{64}$'
    )
);

CREATE FUNCTION sql_test.begin_file(p_test_file text)
RETURNS void
LANGUAGE plpgsql
AS $function$
BEGIN
    IF p_test_file IS NULL OR btrim(p_test_file) = '' THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_parameter_value',
            MESSAGE = 'Test file name must not be empty';
    END IF;

    PERFORM set_config('sql_test.current_file', p_test_file, false);
    RAISE NOTICE 'TEST FILE | %', p_test_file;
END;
$function$;

CREATE FUNCTION sql_test.record_result(
    p_test_name text,
    p_status text,
    p_details text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE
    v_test_file text;
BEGIN
    v_test_file := COALESCE(
        NULLIF(current_setting('sql_test.current_file', true), ''),
        'unassigned'
    );

    IF p_test_name IS NULL OR btrim(p_test_name) = '' THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_parameter_value',
            MESSAGE = 'Test name must not be empty';
    END IF;

    IF p_status NOT IN ('PASS', 'FAIL', 'WARN') THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_parameter_value',
            MESSAGE = 'Invalid SQL test result status';
    END IF;

    INSERT INTO sql_test.results (
        test_file,
        test_name,
        status,
        details
    )
    VALUES (
        v_test_file,
        p_test_name,
        p_status,
        p_details
    );

    IF p_details IS NULL THEN
        RAISE NOTICE '% | %', p_status, p_test_name;
    ELSE
        RAISE NOTICE '% | % | %', p_status, p_test_name, p_details;
    END IF;
END;
$function$;

CREATE FUNCTION sql_test.pass(
    p_test_name text,
    p_details text DEFAULT NULL
)
RETURNS void
LANGUAGE sql
AS $function$
    SELECT sql_test.record_result(p_test_name, 'PASS', p_details);
$function$;

CREATE FUNCTION sql_test.fail(
    p_test_name text,
    p_details text DEFAULT NULL
)
RETURNS void
LANGUAGE sql
AS $function$
    SELECT sql_test.record_result(p_test_name, 'FAIL', p_details);
$function$;

CREATE FUNCTION sql_test.warn(
    p_test_name text,
    p_details text DEFAULT NULL
)
RETURNS void
LANGUAGE sql
AS $function$
    SELECT sql_test.record_result(p_test_name, 'WARN', p_details);
$function$;

CREATE FUNCTION sql_test.assert_true(
    p_test_name text,
    p_condition boolean,
    p_details text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS $function$
BEGIN
    IF p_condition IS TRUE THEN
        PERFORM sql_test.pass(p_test_name, p_details);
    ELSE
        PERFORM sql_test.fail(
            p_test_name,
            COALESCE(p_details, 'Condition was false or null')
        );
    END IF;
END;
$function$;

CREATE FUNCTION sql_test.assert_false(
    p_test_name text,
    p_condition boolean,
    p_details text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS $function$
BEGIN
    IF p_condition IS FALSE THEN
        PERFORM sql_test.pass(p_test_name, p_details);
    ELSE
        PERFORM sql_test.fail(
            p_test_name,
            COALESCE(p_details, 'Condition was true or null')
        );
    END IF;
END;
$function$;

CREATE FUNCTION sql_test.assert_equal_bigint(
    p_test_name text,
    p_actual bigint,
    p_expected bigint
)
RETURNS void
LANGUAGE plpgsql
AS $function$
BEGIN
    IF p_actual IS NOT DISTINCT FROM p_expected THEN
        PERFORM sql_test.pass(
            p_test_name,
            format('actual=%s expected=%s', p_actual, p_expected)
        );
    ELSE
        PERFORM sql_test.fail(
            p_test_name,
            format('actual=%s expected=%s', p_actual, p_expected)
        );
    END IF;
END;
$function$;

CREATE FUNCTION sql_test.assert_schema_exists(
    p_test_name text,
    p_schema_name name
)
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE
    v_exists boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM pg_namespace
        WHERE nspname = p_schema_name
    )
    INTO v_exists;

    PERFORM sql_test.assert_true(
        p_test_name,
        v_exists,
        format('schema=%I', p_schema_name)
    );
END;
$function$;

CREATE FUNCTION sql_test.assert_relation_exists(
    p_test_name text,
    p_qualified_relation text
)
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE
    v_relation regclass;
BEGIN
    v_relation := to_regclass(p_qualified_relation);

    PERFORM sql_test.assert_true(
        p_test_name,
        v_relation IS NOT NULL,
        format('relation=%s', p_qualified_relation)
    );
END;
$function$;

CREATE FUNCTION sql_test.assert_no_rows(
    p_test_name text,
    p_query text
)
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE
    v_exists boolean;
    v_sample text;
BEGIN
    EXECUTE format('SELECT EXISTS (%s)', p_query)
    INTO v_exists;

    IF NOT v_exists THEN
        PERFORM sql_test.pass(p_test_name);
        RETURN;
    END IF;

    EXECUTE format(
        'SELECT row_to_json(sample_row)::text FROM (%s) AS sample_row LIMIT 1',
        p_query
    )
    INTO v_sample;

    PERFORM sql_test.fail(
        p_test_name,
        format('Unexpected row: %s', COALESCE(v_sample, '<unavailable>'))
    );
END;
$function$;

CREATE FUNCTION sql_test.assert_query_returns_rows(
    p_test_name text,
    p_query text
)
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE
    v_exists boolean;
BEGIN
    EXECUTE format('SELECT EXISTS (%s)', p_query)
    INTO v_exists;

    PERFORM sql_test.assert_true(
        p_test_name,
        v_exists,
        'Expected at least one row'
    );
END;
$function$;

CREATE FUNCTION sql_test.warn_if_rows(
    p_test_name text,
    p_query text,
    p_details text
)
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE
    v_count bigint;
BEGIN
    EXECUTE format('SELECT count(*) FROM (%s) AS warning_rows', p_query)
    INTO v_count;

    IF v_count = 0 THEN
        PERFORM sql_test.pass(p_test_name);
    ELSE
        PERFORM sql_test.warn(
            p_test_name,
            format('%s; matching_rows=%s', p_details, v_count)
        );
    END IF;
END;
$function$;

CREATE FUNCTION sql_test.assert_raises(
    p_test_name text,
    p_statement text,
    p_expected_sqlstate text
)
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE
    v_actual_sqlstate text;
    v_message text;
BEGIN
    BEGIN
        EXECUTE p_statement;
        PERFORM sql_test.fail(
            p_test_name,
            format('Statement succeeded; expected SQLSTATE %s', p_expected_sqlstate)
        );
    EXCEPTION
        WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS
                v_actual_sqlstate = RETURNED_SQLSTATE,
                v_message = MESSAGE_TEXT;

            IF v_actual_sqlstate = p_expected_sqlstate THEN
                PERFORM sql_test.pass(
                    p_test_name,
                    format('SQLSTATE=%s message=%s', v_actual_sqlstate, v_message)
                );
            ELSE
                PERFORM sql_test.fail(
                    p_test_name,
                    format(
                        'actual_sqlstate=%s expected_sqlstate=%s message=%s',
                        v_actual_sqlstate,
                        p_expected_sqlstate,
                        v_message
                    )
                );
            END IF;
    END;
END;
$function$;

CREATE VIEW sql_test.result_summary AS
SELECT
    status,
    count(*)::bigint AS result_count
FROM sql_test.results
GROUP BY status;

CREATE FUNCTION sql_test.finish()
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE
    v_passes bigint;
    v_failures bigint;
    v_warnings bigint;
BEGIN
    SELECT count(*) FILTER (WHERE status = 'PASS'),
           count(*) FILTER (WHERE status = 'FAIL'),
           count(*) FILTER (WHERE status = 'WARN')
    INTO v_passes, v_failures, v_warnings
    FROM sql_test.results;

    RAISE NOTICE 'SUMMARY | passes=% failures=% warnings=%',
        v_passes, v_failures, v_warnings;

    IF v_failures > 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0001',
            MESSAGE = format(
                'Foundation SQL tests failed: %s failure(s), %s warning(s), %s pass(es)',
                v_failures,
                v_warnings,
                v_passes
            );
    END IF;
END;
$function$;

COMMIT;
