#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
module_root="$(cd -- "$script_dir/.." && pwd -P)"
output_root="${1:-$module_root/dist}"
required_go="$(tr -d '[:space:]' <"$module_root/TOOLCHAIN")"
module_path="github.com/Iron-Signal-Systems/iron-signal-platform/go/platform"

for command_name in go git sha256sum awk; do
    command -v "$command_name" >/dev/null 2>&1 || {
        printf 'ERROR: required command is unavailable: %s\n' "$command_name" >&2
        exit 1
    }
done

actual_go="$(GOTOOLCHAIN=local go env GOVERSION)"
if [[ "$actual_go" != "$required_go" ]]; then
    printf 'ERROR: required Go toolchain is %s; found %s\n' "$required_go" "$actual_go" >&2
    exit 1
fi

rm -rf -- "$output_root"
mkdir -p -- "$output_root/bin"

export GOTOOLCHAIN=local
export CGO_ENABLED=0
export GOFLAGS='-mod=readonly'

build_flags=(
    -trimpath
    -buildvcs=false
    -ldflags=-buildid=
)

cd "$module_root"

go build "${build_flags[@]}" -o "$output_root/bin/foundation-api" ./cmd/foundation-api
go build "${build_flags[@]}" -o "$output_root/bin/integration-delivery-worker" ./cmd/integration-delivery-worker
go build "${build_flags[@]}" -o "$output_root/bin/monitoring-delivery-worker" ./cmd/monitoring-delivery-worker

foundation_sha="$(sha256sum "$output_root/bin/foundation-api" | awk '{print $1}')"
integration_sha="$(sha256sum "$output_root/bin/integration-delivery-worker" | awk '{print $1}')"
monitoring_sha="$(sha256sum "$output_root/bin/monitoring-delivery-worker" | awk '{print $1}')"

source_commit="$(git -C "$module_root" rev-parse HEAD 2>/dev/null || printf 'uncommitted')"
if [[ -n "$(git -C "$module_root" status --porcelain=v1 --untracked-files=all 2>/dev/null || true)" ]]; then
    source_dirty=true
else
    source_dirty=false
fi

goos="$(go env GOOS)"
goarch="$(go env GOARCH)"

cat >"$output_root/build-manifest.json" <<JSON
{
  "schema_version": 1,
  "module": "$module_path",
  "go_version": "$actual_go",
  "goos": "$goos",
  "goarch": "$goarch",
  "cgo_enabled": false,
  "source_commit": "$source_commit",
  "source_dirty": $source_dirty,
  "build_flags": ["-trimpath", "-buildvcs=false", "-ldflags=-buildid="],
  "artifacts": [
    {"name": "foundation-api", "sha256": "$foundation_sha"},
    {"name": "integration-delivery-worker", "sha256": "$integration_sha"},
    {"name": "monitoring-delivery-worker", "sha256": "$monitoring_sha"}
  ]
}
JSON

printf 'Built three bounded production executables.\n'
printf 'Manifest: %s\n' "$output_root/build-manifest.json"
