#!/usr/bin/env bash
#
# Iron Signal Platform
# Foundation database review and repository-parity report
#
# This script does not alter the target database.

set -Eeuo pipefail
IFS=$'\n\t'

usage() {
    printf 'usage: %s <database-name>\n' "$0" >&2
    exit 64
}

[[ $# -eq 1 ]] || usage

database_name="$1"

command -v psql >/dev/null 2>&1 || {
    printf 'ERROR: psql is required.\n' >&2
    exit 69
}

script_dir="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
    pwd
)"

repository_root="$(
    cd -- "$script_dir/../.."
    pwd
)"

manifest="$repository_root/sql/schema/manifests/foundation.manifest"

[[ -r "$manifest" ]] || {
    printf 'ERROR: Foundation manifest is not readable: %s\n' "$manifest" >&2
    exit 66
}

expected_ids_file="$(mktemp)"
actual_ids_file="$(mktemp)"
missing_ids_file="$(mktemp)"
unexpected_ids_file="$(mktemp)"

cleanup() {
    rm -f \
        "$expected_ids_file" \
        "$actual_ids_file" \
        "$missing_ids_file" \
        "$unexpected_ids_file"
}
trap cleanup EXIT

# ISSP_FOUNDATION_REPOSITORY_DATABASE_PARITY_V1
awk '
    /^[[:space:]]*(#|$)/ {
        next
    }

    {
        value = $0
        sub(/\r$/, "", value)

        part_count = split(value, parts, "/")
        filename = parts[part_count]
        sub(/\.sql$/, "", filename)

        print filename
    }
' "$manifest" \
    | LC_ALL=C sort \
    >"$expected_ids_file"

[[ -s "$expected_ids_file" ]] || {
    printf 'ERROR: Foundation manifest contains no migration entries: %s\n' \
        "$manifest" >&2
    exit 65
}

psql \
    --no-psqlrc \
    --set=ON_ERROR_STOP=1 \
    --tuples-only \
    --no-align \
    --dbname="$database_name" \
    --command='
        SELECT migration_id
        FROM foundation_meta.applied_migrations
        ORDER BY migration_id;
    ' \
    | sed '/^[[:space:]]*$/d' \
    | LC_ALL=C sort \
    >"$actual_ids_file"

comm -23 \
    "$expected_ids_file" \
    "$actual_ids_file" \
    >"$missing_ids_file"

comm -13 \
    "$expected_ids_file" \
    "$actual_ids_file" \
    >"$unexpected_ids_file"

expected_count="$(
    wc -l <"$expected_ids_file" \
        | tr -d '[:space:]'
)"

actual_count="$(
    wc -l <"$actual_ids_file" \
        | tr -d '[:space:]'
)"

migration_parity_status="PASS"

if [[ -s "$missing_ids_file" || -s "$unexpected_ids_file" ]]; then
    migration_parity_status="FAIL"
fi

printf '\n=== Repository and Database Migration Parity ===\n'
printf 'Repository manifest: %s\n' "$manifest"
printf 'Target database: %s\n' "$database_name"
printf 'Manifest migrations: %s\n' "$expected_count"
printf 'Registered migrations: %s\n' "$actual_count"
printf 'Migration identifier parity: %s\n' "$migration_parity_status"

if [[ -s "$missing_ids_file" ]]; then
    printf '\nMigrations present in the repository manifest but missing from the database:\n'
    sed 's/^/  - /' "$missing_ids_file"
fi

if [[ -s "$unexpected_ids_file" ]]; then
    printf '\nMigrations registered in the database but absent from the repository manifest:\n'
    sed 's/^/  - /' "$unexpected_ids_file"
fi

psql \
    --no-psqlrc \
    --set=ON_ERROR_STOP=1 \
    --set=expected_foundation_migrations="$expected_count" \
    --dbname="$database_name" <<'SQL'
\pset pager off

\echo
\echo '=== Foundation Review Summary ==='

WITH current_review_summary AS (
    SELECT
        'Applied Foundation migrations'::text AS check_name,
        count(*)::text AS observed_value,
        :'expected_foundation_migrations'::text AS expected_value,
        CASE
            WHEN count(*) = :'expected_foundation_migrations'::bigint
                THEN 'PASS'
            ELSE 'FAIL'
        END::text AS review_status
    FROM foundation_meta.applied_migrations

    UNION ALL

    SELECT
        summary.check_name,
        summary.observed_value,
        summary.expected_value,
        summary.review_status
    FROM security_validation.foundation_review_summary AS summary
    WHERE summary.check_name <> 'Applied Foundation migrations'
)
SELECT *
FROM current_review_summary
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

SELECT
    'TABLE_OR_VIEW' AS object_category,
    count(*) AS grant_count
FROM security_validation.public_table_privileges

UNION ALL

SELECT
    'SEQUENCE',
    count(*)
FROM security_validation.public_sequence_privileges

UNION ALL

SELECT
    'ROUTINE',
    count(*)
FROM security_validation.public_routine_privileges

ORDER BY object_category;
SQL

if [[ "$migration_parity_status" != "PASS" ]]; then
    printf '\nFoundation migration parity validation FAILED.\n' >&2
    exit 1
fi

printf '\nFoundation migration parity validation PASSED.\n'
