-- Generic PostgreSQL catalog integrity checks for Foundation schemas.

SELECT sql_test.begin_file('050_catalog_integrity.sql');

SELECT sql_test.assert_no_rows(
    'All Foundation constraints are validated',
    $query$
        SELECT
            namespace_record.nspname AS schema_name,
            class_record.relname AS table_name,
            constraint_record.conname AS constraint_name
        FROM pg_constraint constraint_record
        JOIN pg_class class_record
          ON class_record.oid = constraint_record.conrelid
        JOIN pg_namespace namespace_record
          ON namespace_record.oid = class_record.relnamespace
        JOIN foundation_meta.schema_registry registry
          ON registry.schema_name = namespace_record.nspname
         AND registry.active
        WHERE NOT constraint_record.convalidated
    $query$
);

SELECT sql_test.assert_no_rows(
    'All Foundation indexes are valid and ready',
    $query$
        SELECT
            namespace_record.nspname AS schema_name,
            table_record.relname AS table_name,
            index_record.relname AS index_name,
            index_catalog.indisvalid,
            index_catalog.indisready
        FROM pg_index index_catalog
        JOIN pg_class table_record
          ON table_record.oid = index_catalog.indrelid
        JOIN pg_class index_record
          ON index_record.oid = index_catalog.indexrelid
        JOIN pg_namespace namespace_record
          ON namespace_record.oid = table_record.relnamespace
        JOIN foundation_meta.schema_registry registry
          ON registry.schema_name = namespace_record.nspname
         AND registry.active
        WHERE NOT index_catalog.indisvalid
           OR NOT index_catalog.indisready
    $query$
);

SELECT sql_test.assert_no_rows(
    'Foundation foreign keys reference existing relations',
    $query$
        SELECT
            namespace_record.nspname AS schema_name,
            class_record.relname AS table_name,
            constraint_record.conname AS constraint_name
        FROM pg_constraint constraint_record
        JOIN pg_class class_record
          ON class_record.oid = constraint_record.conrelid
        JOIN pg_namespace namespace_record
          ON namespace_record.oid = class_record.relnamespace
        JOIN foundation_meta.schema_registry registry
          ON registry.schema_name = namespace_record.nspname
         AND registry.active
        WHERE constraint_record.contype = 'f'
          AND constraint_record.confrelid = 0
    $query$
);

SELECT sql_test.warn_if_rows(
    'Foundation regular tables define primary keys',
    $query$
        SELECT
            namespace_record.nspname AS schema_name,
            class_record.relname AS table_name
        FROM pg_class class_record
        JOIN pg_namespace namespace_record
          ON namespace_record.oid = class_record.relnamespace
        JOIN foundation_meta.schema_registry registry
          ON registry.schema_name = namespace_record.nspname
         AND registry.active
        WHERE class_record.relkind IN ('r', 'p')
          AND NOT EXISTS (
              SELECT 1
              FROM pg_constraint constraint_record
              WHERE constraint_record.conrelid = class_record.oid
                AND constraint_record.contype = 'p'
          )
    $query$,
    'One or more regular Foundation tables do not define a primary key; review whether this is intentional'
);

SELECT sql_test.warn_if_rows(
    'Foundation timestamp columns are time-zone aware',
    $query$
        SELECT
            columns.table_schema,
            columns.table_name,
            columns.column_name
        FROM information_schema.columns columns
        JOIN foundation_meta.schema_registry registry
          ON registry.schema_name = columns.table_schema
         AND registry.active
        WHERE columns.data_type = 'timestamp without time zone'
    $query$,
    'Timestamp without time zone columns exist in Foundation schemas; review each use for intentional local-time semantics'
);
