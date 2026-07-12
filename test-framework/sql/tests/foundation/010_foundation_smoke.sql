-- Foundation installation, manifest, and schema registry smoke tests.

SELECT sql_test.begin_file('010_foundation_smoke.sql');

SELECT sql_test.assert_true(
    'PostgreSQL 18 or newer is in use',
    current_setting('server_version_num')::integer >= 180000,
    format('server_version_num=%s', current_setting('server_version_num'))
);

SELECT sql_test.assert_relation_exists(
    'Applied migration registry exists',
    'foundation_meta.applied_migrations'
);

SELECT sql_test.assert_relation_exists(
    'Foundation schema registry exists',
    'foundation_meta.schema_registry'
);

SELECT sql_test.assert_true(
    'Migration registration function exists',
    to_regprocedure(
        'foundation_meta.register_migration(text,text,text,text,text)'
    ) IS NOT NULL
);

SELECT sql_test.assert_true(
    'pgcrypto is installed in the extensions schema',
    EXISTS (
        SELECT 1
        FROM pg_extension extension_record
        JOIN pg_namespace namespace_record
          ON namespace_record.oid = extension_record.extnamespace
        WHERE extension_record.extname = 'pgcrypto'
          AND namespace_record.nspname = 'extensions'
    )
);

SELECT sql_test.assert_equal_bigint(
    'Manifest and migration registry contain the same number of migrations',
    (SELECT count(*) FROM foundation_meta.applied_migrations),
    (SELECT count(*) FROM sql_test.expected_migrations)
);

SELECT sql_test.assert_no_rows(
    'Every manifest migration is registered',
    $query$
        SELECT expected.migration_id
        FROM sql_test.expected_migrations expected
        LEFT JOIN foundation_meta.applied_migrations applied
          ON applied.migration_id = expected.migration_id
        WHERE applied.migration_id IS NULL
    $query$
);

SELECT sql_test.assert_no_rows(
    'No unexpected migrations are registered',
    $query$
        SELECT applied.migration_id
        FROM foundation_meta.applied_migrations applied
        LEFT JOIN sql_test.expected_migrations expected
          ON expected.migration_id = applied.migration_id
        WHERE expected.migration_id IS NULL
    $query$
);

SELECT sql_test.assert_no_rows(
    'Registered migration checksums match files when a checksum is present',
    $query$
        SELECT
            applied.migration_id,
            applied.migration_checksum,
            expected.file_sha256
        FROM foundation_meta.applied_migrations applied
        JOIN sql_test.expected_migrations expected
          ON expected.migration_id = applied.migration_id
        WHERE applied.migration_checksum IS NOT NULL
          AND applied.migration_checksum <> expected.file_sha256
    $query$
);

SELECT sql_test.warn_if_rows(
    'Migration registry contains file checksums',
    $query$
        SELECT migration_id
        FROM foundation_meta.applied_migrations
        WHERE migration_checksum IS NULL
    $query$,
    'Current migrations register NULL checksums; file hashes were calculated by the test runner but are not yet stored by migrations'
);

SELECT sql_test.assert_no_rows(
    'Every active schema registry entry exists in PostgreSQL',
    $query$
        SELECT registry.schema_name
        FROM foundation_meta.schema_registry registry
        LEFT JOIN pg_namespace namespace_record
          ON namespace_record.nspname = registry.schema_name
        WHERE registry.active
          AND namespace_record.oid IS NULL
    $query$
);

SELECT sql_test.assert_no_rows(
    'Every schema registry migration reference is registered',
    $query$
        SELECT registry.schema_name, registry.created_by_migration_id
        FROM foundation_meta.schema_registry registry
        LEFT JOIN foundation_meta.applied_migrations applied
          ON applied.migration_id = registry.created_by_migration_id
        WHERE applied.migration_id IS NULL
    $query$
);

SELECT sql_test.assert_no_rows(
    'Foundation migrations created no regular tables in public',
    $query$
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_type = 'BASE TABLE'
    $query$
);
