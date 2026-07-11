-- SECURITY DEFINER function hardening tests.

SELECT sql_test.begin_file('030_function_security.sql');

SELECT sql_test.assert_no_rows(
    'Every Foundation SECURITY DEFINER routine has an explicit search_path',
    $query$
        SELECT
            namespace_record.nspname AS schema_name,
            procedure_record.proname AS routine_name,
            pg_get_function_identity_arguments(procedure_record.oid) AS arguments
        FROM pg_proc procedure_record
        JOIN pg_namespace namespace_record
          ON namespace_record.oid = procedure_record.pronamespace
        JOIN foundation_meta.schema_registry registry
          ON registry.schema_name = namespace_record.nspname
         AND registry.active
        WHERE procedure_record.prosecdef
          AND NOT EXISTS (
              SELECT 1
              FROM unnest(
                  COALESCE(procedure_record.proconfig, ARRAY[]::text[])
              ) AS configuration(setting)
              WHERE configuration.setting LIKE 'search_path=%'
          )
    $query$
);

SELECT sql_test.assert_no_rows(
    'Foundation SECURITY DEFINER search paths start with pg_catalog',
    $query$
        SELECT
            namespace_record.nspname AS schema_name,
            procedure_record.proname AS routine_name,
            configuration.setting AS search_path_setting
        FROM pg_proc procedure_record
        JOIN pg_namespace namespace_record
          ON namespace_record.oid = procedure_record.pronamespace
        JOIN foundation_meta.schema_registry registry
          ON registry.schema_name = namespace_record.nspname
         AND registry.active
        CROSS JOIN LATERAL unnest(
            COALESCE(procedure_record.proconfig, ARRAY[]::text[])
        ) AS configuration(setting)
        WHERE procedure_record.prosecdef
          AND configuration.setting LIKE 'search_path=%'
          AND btrim(
              split_part(
                  substring(configuration.setting FROM length('search_path=') + 1),
                  ',',
                  1
              )
          ) <> 'pg_catalog'
    $query$
);


SELECT sql_test.assert_no_rows(
    'Foundation SECURITY DEFINER search paths reference existing schemas',
    $query$
        SELECT
            namespace_record.nspname AS function_schema,
            procedure_record.proname AS routine_name,
            btrim(path_entry.entry) AS missing_search_path_schema
        FROM pg_proc procedure_record
        JOIN pg_namespace namespace_record
          ON namespace_record.oid = procedure_record.pronamespace
        JOIN foundation_meta.schema_registry registry
          ON registry.schema_name = namespace_record.nspname
         AND registry.active
        CROSS JOIN LATERAL unnest(
            COALESCE(procedure_record.proconfig, ARRAY[]::text[])
        ) AS configuration(setting)
        CROSS JOIN LATERAL regexp_split_to_table(
            substring(configuration.setting FROM length('search_path=') + 1),
            ','
        ) AS path_entry(entry)
        WHERE procedure_record.prosecdef
          AND configuration.setting LIKE 'search_path=%'
          AND btrim(path_entry.entry) <> 'pg_catalog'
          AND to_regnamespace(btrim(path_entry.entry)) IS NULL
    $query$
);

SELECT sql_test.assert_no_rows(
    'Foundation SECURITY DEFINER search paths exclude public, pg_temp, and $user',
    $query$
        SELECT
            namespace_record.nspname AS schema_name,
            procedure_record.proname AS routine_name,
            configuration.setting AS search_path_setting
        FROM pg_proc procedure_record
        JOIN pg_namespace namespace_record
          ON namespace_record.oid = procedure_record.pronamespace
        JOIN foundation_meta.schema_registry registry
          ON registry.schema_name = namespace_record.nspname
         AND registry.active
        CROSS JOIN LATERAL unnest(
            COALESCE(procedure_record.proconfig, ARRAY[]::text[])
        ) AS configuration(setting)
        WHERE procedure_record.prosecdef
          AND configuration.setting LIKE 'search_path=%'
          AND lower(configuration.setting) ~ '(^|[=,[:space:]])(public|pg_temp|[$]user)([,[:space:]]|$)'
    $query$
);

SELECT sql_test.assert_no_rows(
    'Foundation routines do not use untrusted procedural languages',
    $query$
        SELECT
            namespace_record.nspname AS schema_name,
            procedure_record.proname AS routine_name,
            language_record.lanname AS language_name
        FROM pg_proc procedure_record
        JOIN pg_namespace namespace_record
          ON namespace_record.oid = procedure_record.pronamespace
        JOIN foundation_meta.schema_registry registry
          ON registry.schema_name = namespace_record.nspname
         AND registry.active
        JOIN pg_language language_record
          ON language_record.oid = procedure_record.prolang
        WHERE NOT language_record.lanpltrusted
          AND language_record.lanname NOT IN ('internal', 'c')
    $query$
);
