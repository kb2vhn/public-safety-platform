#!/usr/bin/env bash
#
# Iron Signal Platform deployment migration runner
#
# Applies the reserved 900-999 deployment manifest to one database. PostgreSQL
# roles are cluster-global, so use this runner only through a controlled
# deployment path. Tests use a disposable PostgreSQL cluster.

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

usage() {
    printf 'usage: %s <database-name>\n' "$0" >&2
    exit 64
}

die() {
    local exit_code="$1"
    shift
    printf 'ERROR: %s\n' "$*" >&2
    exit "$exit_code"
}

trim_manifest_line() {
    local line="$1"

    printf '%s' "$line" \
        | sed 's/\r$//' \
        | sed 's/[[:space:]]*#.*$//' \
        | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

quote_sql_literal() {
    local value="$1"
    printf '%s' "${value//\'/\'\'}"
}

[[ $# -eq 1 ]] || usage

database_name="$1"

required_commands=(awk basename grep psql sed sha256sum)
for command_name in "${required_commands[@]}"; do
    command -v "$command_name" >/dev/null 2>&1 \
        || die 69 "Required command is missing: $command_name"
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
deployment_root="$(cd -- "$script_dir/.." && pwd -P)"
manifest="$deployment_root/manifests/deployment.manifest"

[[ -f "$manifest" ]] \
    || die 66 "Deployment manifest not found: $manifest"

declare -a migration_paths=()
declare -A seen_migrations=()

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    relative_path="$(trim_manifest_line "$raw_line")"
    [[ -z "$relative_path" ]] && continue

    if [[ ! "$relative_path" =~ ^migrations/9[0-9]{2}_[a-z0-9_]+\.sql$ ]]; then
        die 65 "Invalid deployment manifest path: $relative_path"
    fi

    if [[ -n "${seen_migrations[$relative_path]:-}" ]]; then
        die 65 "Duplicate deployment manifest entry: $relative_path"
    fi

    migration_file="$deployment_root/$relative_path"
    [[ -f "$migration_file" ]] \
        || die 66 "Deployment migration file not found: $migration_file"

    seen_migrations["$relative_path"]=1
    migration_paths+=("$relative_path")
done <"$manifest"

[[ "${#migration_paths[@]}" -gt 0 ]] \
    || die 65 "Deployment manifest contains no migration files"

printf 'Deployment migration preflight: checking PostgreSQL connection and authority...\n'

preflight_result="$(
    psql \
        -X \
        --no-psqlrc \
        --set=ON_ERROR_STOP=1 \
        --tuples-only \
        --no-align \
        --dbname="$database_name" \
        --command="
            SELECT
                current_setting('server_version_num') || '|' ||
                current_user || '|' ||
                CASE WHEN role_record.rolsuper THEN '1' ELSE '0' END || '|' ||
                (
                    SELECT count(*)::text
                    FROM foundation_meta.applied_migrations
                )
            FROM pg_roles AS role_record
            WHERE role_record.rolname = current_user;
        "
)" || die 69 "Could not connect to database: $database_name"

IFS='|' read -r \
    server_version_num \
    connected_role \
    connected_role_is_superuser \
    foundation_migration_count \
    <<<"$preflight_result"

[[ "$server_version_num" =~ ^[0-9]+$ ]] \
    || die 65 "Could not interpret server_version_num: $server_version_num"

(( server_version_num >= 180000 )) \
    || die 69 "PostgreSQL 18 or newer is required; server_version_num=$server_version_num"

[[ "$connected_role_is_superuser" == "1" ]] \
    || die 77 "Deployment role bootstrap requires a PostgreSQL superuser; connected role=$connected_role"

[[ "$foundation_migration_count" == "34" ]] \
    || die 65 "Expected 34 registered Foundation migrations; found $foundation_migration_count"

printf 'Deployment migration preflight: PASS (database=%s, role=%s, server_version_num=%s)\n' \
    "$database_name" \
    "$connected_role" \
    "$server_version_num"

export PGAPPNAME="iron-signal-platform-deployment-migration"

applied_count=0
skipped_count=0

for relative_path in "${migration_paths[@]}"; do
    migration_file="$deployment_root/$relative_path"
    migration_id="$(basename -- "$relative_path" .sql)"
    migration_checksum="$(sha256sum "$migration_file" | awk '{print $1}')"

    quoted_migration_id="$(quote_sql_literal "$migration_id")"

    registry_exists="$(
        psql \
            -X \
            --no-psqlrc \
            --set=ON_ERROR_STOP=1 \
            --tuples-only \
            --no-align \
            --dbname="$database_name" \
            --command="
                SELECT CASE
                    WHEN to_regclass(
                        'deployment_meta.applied_deployment_migrations'
                    ) IS NULL THEN '0'
                    ELSE '1'
                END;
            "
    )"

    existing_metadata=""

    if [[ "$registry_exists" == "1" ]]; then
        existing_metadata="$(
            psql \
                -X \
                --no-psqlrc \
                --set=ON_ERROR_STOP=1 \
                --tuples-only \
                --no-align \
                --dbname="$database_name" \
                --command="
                    SELECT
                        migration_checksum || '|' || relative_path
                    FROM deployment_meta.applied_deployment_migrations
                    WHERE migration_id = '${quoted_migration_id}';
                "
        )"
    fi

    if [[ -n "$existing_metadata" ]]; then
        IFS='|' read -r \
            existing_checksum \
            existing_relative_path \
            <<<"$existing_metadata"

        if [[ "$existing_checksum" != "$migration_checksum" \
              || "$existing_relative_path" != "$relative_path" ]]; then
            die 65 \
                "Deployment migration $migration_id is registered with different metadata"
        fi

        printf 'SKIP: %s already registered with the exact SHA-256 checksum\n' \
            "$relative_path"
        skipped_count=$((skipped_count + 1))
        continue
    fi

    printf 'Applying %s\n' "$relative_path"

    psql \
        -X \
        --no-psqlrc \
        --set=ON_ERROR_STOP=1 \
        --set=VERBOSITY=verbose \
        --set=SHOW_CONTEXT=errors \
        --set=deployment_migration_checksum="$migration_checksum" \
        --set=deployment_migration_relative_path="$relative_path" \
        --dbname="$database_name" \
        --file="$migration_file"

    applied_count=$((applied_count + 1))
done

expected_count="${#migration_paths[@]}"
registered_count="$(
    psql \
        -X \
        --no-psqlrc \
        --set=ON_ERROR_STOP=1 \
        --tuples-only \
        --no-align \
        --dbname="$database_name" \
        --command='SELECT count(*) FROM deployment_meta.applied_deployment_migrations;'
)"

[[ "$registered_count" == "$expected_count" ]] \
    || die 65 \
        "Deployment registry count mismatch: manifest=$expected_count registered=$registered_count"

printf '\nDeployment migrations completed successfully.\n'
printf 'Manifest migrations: %s\n' "$expected_count"
printf 'Applied this run: %s\n' "$applied_count"
printf 'Skipped exact registrations: %s\n' "$skipped_count"
printf 'Registered deployment migrations: %s\n' "$registered_count"
