#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <database-name>" >&2
  exit 64
fi

db="$1"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
manifest="$root/db/manifests/foundation.manifest"

while IFS= read -r rel; do
  [[ -z "$rel" ]] && continue
  echo "Applying $rel"
  psql --set=ON_ERROR_STOP=1 --dbname="$db" --file="$root/db/$rel"
done < "$manifest"
