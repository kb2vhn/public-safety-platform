#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
module_root="$(cd -- "$script_dir/.." && pwd -P)"
required_go="$(tr -d '[:space:]' <"$module_root/TOOLCHAIN")"
pass_count=0
pass() { pass_count=$((pass_count + 1)); printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

for command_name in go gofmt grep find sort python3 bash; do
    command -v "$command_name" >/dev/null 2>&1 || fail "Required command available: $command_name"
    pass "Required command available: $command_name"
done
actual_go="$(GOTOOLCHAIN=local go env GOVERSION)"
[[ "$actual_go" == "$required_go" ]] || fail "Exact Go toolchain = $required_go"
pass "Exact Go toolchain = $required_go"

cd "$module_root"
export GOTOOLCHAIN=local
export GOFLAGS='-mod=readonly'

required_files=(
    internal/authentication/handoff.go
    internal/authentication/handoff_test.go
    internal/transport/business.go
    internal/transport/business_test.go
    scripts/test-authenticated-transport-runtime.sh
)
for required_file in "${required_files[@]}"; do
    [[ -f "$required_file" ]] || fail "Step 6 artifact exists: $required_file"
    pass "Step 6 artifact exists: $required_file"
done
bash -n scripts/test-authenticated-transport-runtime.sh
pass "Authenticated transport runtime script Bash syntax"

unformatted="$(gofmt -l internal/authentication internal/config internal/bootstrap internal/transport)"
[[ -z "$unformatted" ]] || { printf '%s\n' "$unformatted" >&2; fail "Step 6 Go source is gofmt-clean"; }
pass "Step 6 Go source is gofmt-clean"

go test -race ./internal/authentication ./internal/config ./internal/bootstrap ./internal/transport
pass "Authentication, configuration, bootstrap, and transport race tests"

for required_text in \
    'hmac.New(sha256.New' \
    'MaximumHandoffAge    = 30 * time.Second' \
    'MaximumReplayEntries = 1024' \
    'hmac.Equal' \
    'ISSP-HANDOFF-V1'
do
    grep -Fq -- "$required_text" internal/authentication/handoff.go \
        || fail "Authentication verifier contains: $required_text"
    pass "Authentication verifier contains: $required_text"
done

for required_text in \
    'AuthorizationPolicyBindingPath = "/v1/foundation/authorization-policy-bindings"' \
    'maximumBusinessRequestBody     = 1024' \
    'businessRequestTimeout         = 4 * time.Second' \
    'MaxHeaderBytes:    8 * 1024' \
    'handler.binder.BindAuthorizationPolicy(requestContext, decisionID)'
do
    grep -Fq -- "$required_text" internal/transport/business.go \
        || fail "Business transport contains: $required_text"
    pass "Business transport contains: $required_text"
done

if grep -R -E 'Authorization|role|permission|scope|organization' internal/transport/business.go \
    | grep -E 'Header|json:"' >/dev/null 2>&1; then
    fail "Transport accepts no caller-selected authorization field"
fi
pass "Transport accepts no caller-selected authorization field"

if grep -R -E 'Forwarded|X-Forwarded-For|X-Real-IP' internal/transport/business.go >/dev/null 2>&1; then
    pass "Transport explicitly rejects proxy identity headers"
else
    fail "Transport explicitly rejects proxy identity headers"
fi

if grep -R -E 'decision\.bind_authorization_policy|SELECT |INSERT |UPDATE |DELETE ' \
    internal/authentication internal/transport --include='*.go' | grep -v '_test.go' >/dev/null 2>&1; then
    fail "Authentication and transport packages contain no SQL"
fi
pass "Authentication and transport packages contain no SQL"

for test_name in \
    TestVerifierAcceptsValidHandoffAndRejectsReplay \
    TestVerifierAllowsExactlyOneConcurrentReplayWinner \
    TestBusinessHandlerReturnsAuthenticatedPolicyBindingResult \
    TestBusinessHandlerRejectsReplayAndSpoofedProxyHeaders \
    TestBusinessHandlerBoundsConcurrencyWithoutQueueing \
    TestBusinessHandlerMapsOperationErrorsWithoutDisclosure
 do
    grep -R -Fq -- "$test_name" internal/authentication internal/transport \
        || fail "Step 6 test exists: $test_name"
    pass "Step 6 test exists: $test_name"
done

printf '\nPhase 6 Step 6 authenticated transport checks: %d PASS, 0 FAIL\n' "$pass_count"
