#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: $0 <database-name>" >&2
    exit 64
fi

database_name="$1"

schema_root="$(
    cd "$(dirname "${BASH_SOURCE[0]}")/.."
    pwd
)"

manifest_file="$schema_root/manifests/foundation.manifest"

if [[ ! -f "$manifest_file" ]]; then
    echo "manifest not found: $manifest_file" >&2
    exit 66
fi

while IFS= read -r relative_path; do
    [[ -z "$relative_path" ]] && continue
    [[ "$relative_path" =~ ^[[:space:]]*# ]] && continue

    sql_file="$schema_root/$relative_path"

    if [[ ! -f "$sql_file" ]]; then
        echo "migration not found: $sql_file" >&2
        exit 66
    fi

    echo "Applying $relative_path"

    psql \
        --set=ON_ERROR_STOP=1 \
        --dbname="$database_name" \
        --file="$sql_file"
done < "$manifest_file"

echo "Foundation migrations completed successfully."
