#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 1 ]]; then
  echo "usage: $0 <database-name>" >&2
  exit 64
fi
psql --set=ON_ERROR_STOP=1 --dbname="$1" <<'SQL'
SELECT * FROM security_validation.migration_summary;
SELECT * FROM security_validation.public_schema_privileges ORDER BY schema_name;
SELECT * FROM security_validation.security_definer_functions ORDER BY schema_name,function_name;
SELECT * FROM security_validation.foundation_table_counts ORDER BY schemaname;
SQL
