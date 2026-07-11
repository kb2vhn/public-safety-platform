-- Migration registration API behavior and negative tests.

SELECT sql_test.begin_file('040_migration_registry_behavior.sql');

SELECT sql_test.assert_raises(
    'Migration registration rejects malformed identifiers',
    $statement$
        SELECT foundation_meta.register_migration(
            'bad migration id',
            'Test migration',
            'FOUNDATION',
            NULL,
            NULL
        )
    $statement$,
    '22023'
);

SELECT sql_test.assert_raises(
    'Migration registration rejects an empty migration name',
    $statement$
        SELECT foundation_meta.register_migration(
            '999_sql_test_probe',
            '   ',
            'FOUNDATION',
            NULL,
            NULL
        )
    $statement$,
    '22023'
);

SELECT sql_test.assert_raises(
    'Migration registration rejects an empty migration layer',
    $statement$
        SELECT foundation_meta.register_migration(
            '999_sql_test_probe',
            'Test migration',
            '   ',
            NULL,
            NULL
        )
    $statement$,
    '22023'
);

SELECT sql_test.assert_raises(
    'Migration registration rejects malformed SHA-256 values',
    $statement$
        SELECT foundation_meta.register_migration(
            '999_sql_test_probe',
            'Test migration',
            'FOUNDATION',
            'NOT-A-SHA256',
            NULL
        )
    $statement$,
    '22023'
);

SELECT sql_test.assert_raises(
    'Migration registration rejects identifier reuse with changed metadata',
    $statement$
        SELECT foundation_meta.register_migration(
            '000_platform_initialization',
            'Changed migration name',
            'FOUNDATION',
            NULL,
            NULL
        )
    $statement$,
    '23000'
);

DO $test$
DECLARE
    v_record foundation_meta.applied_migrations%ROWTYPE;
    v_before bigint;
    v_after bigint;
BEGIN
    SELECT *
    INTO STRICT v_record
    FROM foundation_meta.applied_migrations
    WHERE migration_id = '000_platform_initialization';

    SELECT count(*) INTO v_before
    FROM foundation_meta.applied_migrations;

    PERFORM foundation_meta.register_migration(
        v_record.migration_id,
        v_record.migration_name,
        v_record.migration_layer,
        v_record.migration_checksum,
        v_record.notes
    );

    SELECT count(*) INTO v_after
    FROM foundation_meta.applied_migrations;

    PERFORM sql_test.assert_equal_bigint(
        'Exact migration re-registration is idempotent',
        v_after,
        v_before
    );
END;
$test$;

SELECT sql_test.warn_if_rows(
    'Applied migration registry has database-level immutable-write protection',
    $query$
        SELECT 1
        WHERE NOT EXISTS (
            SELECT 1
            FROM pg_trigger trigger_record
            JOIN pg_class class_record
              ON class_record.oid = trigger_record.tgrelid
            JOIN pg_namespace namespace_record
              ON namespace_record.oid = class_record.relnamespace
            WHERE namespace_record.nspname = 'foundation_meta'
              AND class_record.relname = 'applied_migrations'
              AND NOT trigger_record.tgisinternal
              AND trigger_record.tgenabled <> 'D'
        )
    $query$,
    'The registry is documented as append-only but no enabled user trigger currently enforces immutability'
);
