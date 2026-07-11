-- Schema, table, sequence, and routine PUBLIC privilege tests.

SELECT sql_test.begin_file('020_schema_security.sql');

SELECT sql_test.assert_false(
    'PUBLIC cannot create objects in the public schema',
    has_schema_privilege('public', 'public', 'CREATE')
);

SELECT sql_test.assert_no_rows(
    'PUBLIC has no privileges on active registered Foundation schemas',
    $query$
        SELECT
            registry.schema_name,
            has_schema_privilege('public', registry.schema_name, 'USAGE') AS public_usage,
            has_schema_privilege('public', registry.schema_name, 'CREATE') AS public_create
        FROM foundation_meta.schema_registry registry
        WHERE registry.active
          AND (
              has_schema_privilege('public', registry.schema_name, 'USAGE')
              OR has_schema_privilege('public', registry.schema_name, 'CREATE')
          )
    $query$
);

SELECT sql_test.assert_no_rows(
    'PUBLIC has no privileges on Foundation tables or views',
    $query$
        SELECT
            namespace_record.nspname AS schema_name,
            class_record.relname AS relation_name,
            privilege_record.privilege_name
        FROM pg_class class_record
        JOIN pg_namespace namespace_record
          ON namespace_record.oid = class_record.relnamespace
        JOIN foundation_meta.schema_registry registry
          ON registry.schema_name = namespace_record.nspname
         AND registry.active
        CROSS JOIN (
            VALUES
                ('SELECT'),
                ('INSERT'),
                ('UPDATE'),
                ('DELETE'),
                ('TRUNCATE'),
                ('REFERENCES'),
                ('TRIGGER'),
                ('MAINTAIN')
        ) AS privilege_record(privilege_name)
        WHERE class_record.relkind IN ('r', 'p', 'v', 'm', 'f')
          AND has_table_privilege(
              'public',
              class_record.oid,
              privilege_record.privilege_name
          )
    $query$
);

SELECT sql_test.assert_no_rows(
    'PUBLIC has no privileges on Foundation sequences',
    $query$
        SELECT
            namespace_record.nspname AS schema_name,
            class_record.relname AS sequence_name,
            privilege_record.privilege_name
        FROM pg_class class_record
        JOIN pg_namespace namespace_record
          ON namespace_record.oid = class_record.relnamespace
        JOIN foundation_meta.schema_registry registry
          ON registry.schema_name = namespace_record.nspname
         AND registry.active
        CROSS JOIN (
            VALUES ('USAGE'), ('SELECT'), ('UPDATE')
        ) AS privilege_record(privilege_name)
        WHERE class_record.relkind = 'S'
          AND has_sequence_privilege(
              'public',
              class_record.oid,
              privilege_record.privilege_name
          )
    $query$
);

SELECT sql_test.assert_no_rows(
    'PUBLIC cannot execute Foundation routines',
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
        WHERE namespace_record.nspname <> 'extensions'
          AND has_function_privilege(
            'public',
            procedure_record.oid,
            'EXECUTE'
        )
    $query$
);


SELECT sql_test.warn_if_rows(
    'Foundation-defined types avoid direct PUBLIC USAGE grants',
    $query$
        SELECT
            namespace_record.nspname AS schema_name,
            type_record.typname AS type_name
        FROM pg_type type_record
        JOIN pg_namespace namespace_record
          ON namespace_record.oid = type_record.typnamespace
        JOIN foundation_meta.schema_registry registry
          ON registry.schema_name = namespace_record.nspname
         AND registry.active
        WHERE namespace_record.nspname <> 'extensions'
          AND type_record.typtype IN ('c', 'd', 'e', 'r', 'm')
          AND has_type_privilege('public', type_record.oid, 'USAGE')
    $query$,
    'PUBLIC cannot reach these types without schema USAGE, but direct type grants should still be reviewed as defense in depth'
);
