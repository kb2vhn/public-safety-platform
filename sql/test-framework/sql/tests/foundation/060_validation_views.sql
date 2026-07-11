-- Verify migration 099 validation views exist, are queryable, and agree with catalogs.

SELECT sql_test.begin_file('060_validation_views.sql');

SELECT sql_test.assert_relation_exists(
    'Migration summary validation view exists',
    'security_validation.migration_summary'
);

SELECT sql_test.assert_relation_exists(
    'PUBLIC schema privilege validation view exists',
    'security_validation.public_schema_privileges'
);

SELECT sql_test.assert_relation_exists(
    'SECURITY DEFINER validation view exists',
    'security_validation.security_definer_functions'
);

SELECT sql_test.assert_relation_exists(
    'Foundation table count validation view exists',
    'security_validation.foundation_table_counts'
);

SELECT sql_test.assert_equal_bigint(
    'Migration summary view contains every migration registry row',
    (SELECT count(*) FROM security_validation.migration_summary),
    (SELECT count(*) FROM foundation_meta.applied_migrations)
);

SELECT sql_test.assert_no_rows(
    'Migration 099 reports no PUBLIC Foundation schema privileges',
    $query$
        SELECT schema_name, public_usage, public_create
        FROM security_validation.public_schema_privileges
        WHERE public_usage OR public_create
    $query$
);

SELECT sql_test.assert_no_rows(
    'Migration 099 SECURITY DEFINER inventory has no missing search paths',
    $query$
        SELECT schema_name, function_name, owner_name
        FROM security_validation.security_definer_functions
        WHERE proconfig IS NULL
           OR NOT EXISTS (
               SELECT 1
               FROM unnest(proconfig) AS configuration(setting)
               WHERE configuration.setting LIKE 'search_path=%'
           )
    $query$
);

SELECT sql_test.assert_no_rows(
    'Migration 099 table counts agree with pg_tables',
    $query$
        WITH direct_counts AS (
            SELECT
                tables.schemaname,
                count(*)::bigint AS table_count
            FROM pg_tables tables
            JOIN foundation_meta.schema_registry registry
              ON registry.schema_name = tables.schemaname
             AND registry.active
            WHERE tables.schemaname <> 'security_validation'
            GROUP BY tables.schemaname
        )
        SELECT
            COALESCE(validation_counts.schemaname, direct_counts.schemaname) AS schema_name,
            validation_counts.table_count AS validation_count,
            direct_counts.table_count AS direct_count
        FROM security_validation.foundation_table_counts validation_counts
        FULL JOIN direct_counts
          ON direct_counts.schemaname = validation_counts.schemaname
        WHERE validation_counts.table_count IS DISTINCT FROM direct_counts.table_count
    $query$
);
