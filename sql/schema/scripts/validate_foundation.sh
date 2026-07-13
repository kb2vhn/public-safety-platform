#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: $0 <database-name>" >&2
    exit 64
fi

database_name="$1"

psql \
    --no-psqlrc \
    --set=ON_ERROR_STOP=1 \
    --dbname="$database_name" <<'SQL'
\pset pager off

\echo
\echo '=== Foundation Review Summary ==='
SELECT *
FROM security_validation.foundation_review_summary
ORDER BY
    CASE review_status
        WHEN 'FAIL' THEN 1
        WHEN 'REVIEW_REQUIRED' THEN 2
        WHEN 'INFO' THEN 3
        WHEN 'PASS' THEN 4
        ELSE 5
    END,
    check_name;

\echo
\echo '=== Extension Inventory ==='
SELECT *
FROM security_validation.extension_inventory
ORDER BY extension_name;

\echo
\echo '=== Registered Schema PUBLIC Privileges ==='
SELECT *
FROM security_validation.public_schema_privileges
ORDER BY schema_name;

\echo
\echo '=== Schema Ownership Summary ==='
SELECT
    owner_name,
    owner_can_login,
    owner_is_superuser,
    count(*) AS schema_count
FROM security_validation.foundation_schema_ownership
GROUP BY
    owner_name,
    owner_can_login,
    owner_is_superuser
ORDER BY owner_name;

\echo
\echo '=== Relation Ownership Summary ==='
SELECT
    owner_name,
    owner_can_login,
    owner_is_superuser,
    object_type,
    count(*) AS object_count
FROM security_validation.foundation_relation_ownership
GROUP BY
    owner_name,
    owner_can_login,
    owner_is_superuser,
    object_type
ORDER BY
    owner_name,
    object_type;

\echo
\echo '=== Function Security Posture ==='
SELECT
    schema_name,
    function_name,
    argument_types,
    owner_name,
    security_definer,
    fixed_search_path_present,
    search_path_setting
FROM security_validation.function_security_posture
ORDER BY
    schema_name,
    function_name,
    argument_types;

\echo
\echo '=== Tables Without Primary Keys ==='
SELECT *
FROM security_validation.tables_without_primary_keys
ORDER BY
    schema_name,
    table_name;

\echo
\echo '=== Append-Only Review ==='
SELECT
    schema_name,
    table_name,
    table_exists,
    non_owner_write_grant_present,
    before_update_or_delete_trigger_present,
    row_security_enabled,
    force_row_security,
    review_status
FROM security_validation.append_only_posture
ORDER BY
    CASE review_status
        WHEN 'FAIL' THEN 1
        WHEN 'CONTROL_PATH_REVIEW_REQUIRED' THEN 2
        WHEN 'GUARD_PRESENT_REVIEW_REQUIRED' THEN 3
        ELSE 4
    END,
    schema_name,
    table_name;

\echo
\echo '=== Row-Level Security Summary ==='
SELECT
    row_security_enabled,
    force_row_security,
    count(*) AS table_count,
    sum(policy_count) AS policy_count
FROM security_validation.row_security_posture
GROUP BY
    row_security_enabled,
    force_row_security
ORDER BY
    row_security_enabled DESC,
    force_row_security DESC;

\echo
\echo '=== Migration Checksum Review ==='
SELECT
    migration_id,
    migration_name,
    checksum_present,
    review_status
FROM security_validation.migration_integrity_status
WHERE review_status <> 'PASS'
ORDER BY migration_id;

\echo
\echo '=== PUBLIC Object Grants ==='
SELECT 'TABLE_OR_VIEW' AS object_category, count(*) AS grant_count
FROM security_validation.public_table_privileges
UNION ALL
SELECT 'SEQUENCE', count(*)
FROM security_validation.public_sequence_privileges
UNION ALL
SELECT 'ROUTINE', count(*)
FROM security_validation.public_routine_privileges
ORDER BY object_category;
SQL

