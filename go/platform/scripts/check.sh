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

for command_name in go gofmt git sha256sum cmp mktemp grep find sort cp env; do
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

go mod verify
pass "Go module checksums verify"

[[ -f go.sum ]] || fail "Dependency checksum file exists"
pass "Dependency checksum file exists"

[[ ! -e ../go.work && ! -e ../go.work.sum ]] || fail "A go.work file is not introduced for one module"
pass "A go.work file is not introduced for one module"

expected_modules="$(cat <<'MODULES'
github.com/davecgh/go-spew v1.1.1
github.com/Iron-Signal-Systems/iron-signal-platform/go/platform
github.com/jackc/pgpassfile v1.0.0
github.com/jackc/pgservicefile v0.0.0-20240606120523-5a60cdf6a761
github.com/jackc/pgx/v5 v5.10.0
github.com/jackc/puddle/v2 v2.2.2
github.com/kr/pretty v0.3.0
github.com/pmezard/go-difflib v1.0.0
github.com/stretchr/objx v0.1.0
github.com/stretchr/testify v1.11.1
golang.org/x/mod v0.27.0
golang.org/x/sync v0.17.0
golang.org/x/text v0.29.0
golang.org/x/tools v0.36.0
gopkg.in/check.v1 v1.0.0-20201130134442-10cb98267c6c
gopkg.in/yaml.v3 v3.0.1
MODULES
)"
actual_modules="$(go list -m all | sort)"
[[ "$actual_modules" == "$(printf '%s\n' "$expected_modules" | sort)" ]] || {
    printf 'Expected modules:\n%s\nActual modules:\n%s\n' "$expected_modules" "$actual_modules" >&2
    fail "Module graph equals the accepted Step 3 inventory"
}
pass "Module graph equals the accepted Step 3 inventory"

scratch="$(mktemp -d "${TMPDIR:-/tmp}/issp-go-check.XXXXXX")"
cleanup() {
    rm -rf -- "$scratch"
}
trap cleanup EXIT

cp -R . "$scratch/module"
(
    cd "$scratch/module"
    GOTOOLCHAIN=local GOFLAGS='' go mod tidy
)
cmp -s go.mod "$scratch/module/go.mod" || fail "go.mod is tidy"
cmp -s go.sum "$scratch/module/go.sum" || fail "go.sum is tidy"
pass "go.mod and go.sum are tidy"

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
    output="$(env -u ISSP_ADMIN_LISTEN_ADDRESS -u ISSP_DATABASE_DSN_FILE "$scratch/build-a/bin/$artifact" 2>&1)"
    rc=$?
    set -e
    [[ "$rc" -eq 78 ]] || fail "$artifact exits fail-closed with status 78 without configuration"
    grep -Fq 'configuration rejected' <<<"$output" \
        || fail "$artifact reports configuration rejection"
    if grep -Eiq 'postgres(ql)?://|password=' <<<"$output"; then
        fail "$artifact no-configuration output contains no credential material"
    fi
    pass "$artifact exits fail-closed without disclosing credential material"
done

if grep -R -E '"github.com/jackc/pgx/v5' internal --include='*.go' \
    | grep -v '^internal/database/' >/dev/null 2>&1; then
    fail "pgx imports remain confined to internal/database"
fi
pass "pgx imports remain confined to internal/database"

if grep -R -F 'go/experiments' . --include='*.go' >/dev/null 2>&1; then
    fail "Production source imports no experiment package"
fi
pass "Production source imports no experiment package"

printf '\nGo Phase 6 Step 7 checks: %d PASS, 0 FAIL\n' "$pass_count"
