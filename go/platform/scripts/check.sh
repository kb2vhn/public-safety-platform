#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
module_root="$(cd -- "$script_dir/.." && pwd -P)"
required_go="$(tr -d '[:space:]' <"$module_root/TOOLCHAIN")"
module_path="github.com/Iron-Signal-Systems/iron-signal-platform/go/platform"
pass_count=0

pass() {
    pass_count=$((pass_count + 1))
    printf 'PASS: %s\n' "$1"
}

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

for command_name in go git sha256sum cmp mktemp grep find; do
    command -v "$command_name" >/dev/null 2>&1 || fail "Required command available: $command_name"
    pass "Required command available: $command_name"
done

actual_go="$(GOTOOLCHAIN=local go env GOVERSION)"
[[ "$actual_go" == "$required_go" ]] || fail "Exact Go toolchain = $required_go"
pass "Exact Go toolchain = $required_go"

cd "$module_root"
export GOTOOLCHAIN=local
export GOFLAGS='-mod=readonly'

unformatted="$(gofmt -l .)"
[[ -z "$unformatted" ]] || {
    printf '%s\n' "$unformatted" >&2
    fail "Production Go source is gofmt-clean"
}
pass "Production Go source is gofmt-clean"

go vet ./...
pass "go vet ./..."

go test ./...
pass "go test ./..."

module_inventory="$(go list -m all)"
[[ "$module_inventory" == "$module_path" ]] || {
    printf '%s\n' "$module_inventory" >&2
    fail "Module graph contains only the production module"
}
pass "Module graph contains only the production module"

go mod verify
pass "Go module checksums verify"

[[ ! -e go.sum ]] || fail "No go.sum is needed without third-party modules"
pass "No go.sum is needed without third-party modules"

[[ ! -e ../go.work && ! -e ../go.work.sum ]] || fail "A go.work file is not introduced for one module"
pass "A go.work file is not introduced for one module"

scratch="$(mktemp -d "${TMPDIR:-/tmp}/issp-go-check.XXXXXX")"
cleanup() {
    rm -rf -- "$scratch"
}
trap cleanup EXIT

cp -R . "$scratch/module"
(
    cd "$scratch/module"
    GOTOOLCHAIN=local go mod tidy
)
cmp -s go.mod "$scratch/module/go.mod" || fail "go.mod is tidy"
[[ ! -e "$scratch/module/go.sum" ]] || fail "Tidying does not create go.sum"
pass "go.mod is tidy and produces no dependency checksum file"

"$script_dir/build.sh" "$scratch/build-a" >/dev/null
"$script_dir/build.sh" "$scratch/build-b" >/dev/null

for artifact in foundation-api integration-delivery-worker monitoring-delivery-worker; do
    cmp -s "$scratch/build-a/bin/$artifact" "$scratch/build-b/bin/$artifact" \
        || fail "Reproducible binary: $artifact"
    pass "Reproducible binary: $artifact"
done

cmp -s "$scratch/build-a/build-manifest.json" "$scratch/build-b/build-manifest.json" \
    || fail "Reproducible build manifest"
pass "Reproducible build manifest"

for artifact in foundation-api integration-delivery-worker monitoring-delivery-worker; do
    set +e
    output="$("$scratch/build-a/bin/$artifact" 2>&1)"
    rc=$?
    set -e

    [[ "$rc" -eq 78 ]] || fail "$artifact exits fail-closed with status 78"
    grep -Fq 'runtime bootstrap is not implemented' <<<"$output" \
        || fail "$artifact identifies the unimplemented runtime boundary"
    pass "$artifact exits fail-closed with explicit skeleton status"
done

printf '\nGo baseline checks: %d PASS, 0 FAIL\n' "$pass_count"
