#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
module_root="$(cd -- "$script_dir/.." && pwd -P)"
required_go="$(tr -d '[:space:]' <"$module_root/TOOLCHAIN")"

pass_count=0
pass() { pass_count=$((pass_count + 1)); printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

for command_name in go gofmt grep find sort cmp mktemp; do
    command -v "$command_name" >/dev/null 2>&1 \
        || fail "Required adversarial-test command available: $command_name"
    pass "Required adversarial-test command available: $command_name"
done

actual_go="$(GOTOOLCHAIN=local go env GOVERSION)"
[[ "$actual_go" == "$required_go" ]] \
    || fail "Exact Go toolchain = $required_go"
pass "Exact Go toolchain = $required_go"

cd "$module_root"
export GOTOOLCHAIN=local
export GOFLAGS='-mod=readonly'

step8_test_files=(
    internal/authentication/handoff_step8_hostile_test.go
    internal/foundation/authorization_policy_step8_integration_test.go
    internal/transport/business_step8_hostile_test.go
    internal/workers/delivery_step8_hostile_test.go
    internal/workers/delivery_step8_integration_test.go
)
for test_file in "${step8_test_files[@]}"; do
    [[ -f "$test_file" ]] || fail "Step 8 adversarial test exists: $test_file"
    pass "Step 8 adversarial test exists: $test_file"
done

format_log="$(mktemp "${TMPDIR:-/tmp}/issp-step8-gofmt.XXXXXX")"
trap 'rm -f -- "$format_log"' EXIT

gofmt -d "${step8_test_files[@]}" >"$format_log"
[[ ! -s "$format_log" ]] || { cat "$format_log" >&2; fail "Step 8 Go tests are gofmt-clean"; }
pass "Step 8 Go tests are gofmt-clean"

packages=(
    ./internal/authentication
    ./internal/foundation
    ./internal/transport
    ./internal/workers
)

go test -count=3 "${packages[@]}"
pass "Adapter, authentication, transport, and worker tests pass three consecutive campaigns"

go test -race -count=2 "${packages[@]}"
pass "Adapter, authentication, transport, and worker tests pass two race campaigns"

go test -run '^TestPhase6Step8' -count=2 \
    ./internal/authentication \
    ./internal/transport \
    ./internal/workers
pass "Step 8 hostile tests repeat without nondeterministic failure"

if grep -R -E 't\.Skip\(' \
    internal/authentication/handoff_step8_hostile_test.go \
    internal/transport/business_step8_hostile_test.go \
    internal/workers/delivery_step8_hostile_test.go >/dev/null 2>&1; then
    fail "Step 8 non-integration hostile tests contain no skip path"
fi
pass "Step 8 non-integration hostile tests contain no skip path"

printf '\nPhase 6 Step 8 adversarial Go campaign: %d PASS, 0 FAIL\n' "$pass_count"
