-- Human-readable inventory written to the timestamped test log.

SELECT sql_test.begin_file('070_inventory_report.sql');
SELECT sql_test.pass(
    'Foundation inventory report generated',
    'See the tables below in the full test log'
);

\pset border 2
\pset pager off

\echo ''
\echo '=== Foundation migration summary ==='
SELECT migration_id, migration_name, migration_layer, applied_at
FROM security_validation.migration_summary
ORDER BY migration_id;

\echo ''
\echo '=== Foundation table counts ==='
SELECT schemaname, table_count
FROM security_validation.foundation_table_counts
ORDER BY schemaname;

\echo ''
\echo '=== SECURITY DEFINER routine inventory ==='
SELECT schema_name, function_name, owner_name, proconfig
FROM security_validation.security_definer_functions
ORDER BY schema_name, function_name;

\echo ''
\echo '=== PUBLIC schema privilege inventory ==='
SELECT schema_name, public_usage, public_create
FROM security_validation.public_schema_privileges
ORDER BY schema_name;
