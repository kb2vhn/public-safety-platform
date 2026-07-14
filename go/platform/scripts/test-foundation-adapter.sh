#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
module_root="$(cd -- "$script_dir/.." && pwd -P)"
required_go="$(tr -d '[:space:]' <"$module_root/TOOLCHAIN")"

pass_count=0
pass() {
    pass_count=$((pass_count + 1))
    printf 'PASS: %s\n' "$1"
}
fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

for command_name in go gofmt grep find sort python3 bash; do
    command -v "$command_name" >/dev/null 2>&1 \
        || fail "Required command available: $command_name"
    pass "Required command available: $command_name"
done

actual_go="$(GOTOOLCHAIN=local go env GOVERSION)"
[[ "$actual_go" == "$required_go" ]] \
    || fail "Exact Go toolchain = $required_go"
pass "Exact Go toolchain = $required_go"

cd "$module_root"
export GOTOOLCHAIN=local
export GOFLAGS='-mod=readonly'

required_files=(
    internal/database/pool.go
    internal/foundation/authorization_policy.go
    internal/foundation/authorization_policy_test.go
    internal/foundation/authorization_policy_integration_test.go
    testdata/phase6-step5/authorization-policy-binding-fixtures.sql
    scripts/test-foundation-adapter-runtime.sh
)
for required_file in "${required_files[@]}"; do
    [[ -f "$required_file" ]] \
        || fail "Step 5 artifact exists: $required_file"
    pass "Step 5 artifact exists: $required_file"
done

bash -n scripts/test-foundation-adapter-runtime.sh
pass "Foundation adapter runtime script Bash syntax"

unformatted="$(gofmt -l internal/database internal/foundation)"
[[ -z "$unformatted" ]] || {
    printf '%s\n' "$unformatted" >&2
    fail "Step 5 Go source is gofmt-clean"
}
pass "Step 5 Go source is gofmt-clean"

go test -race ./internal/database ./internal/foundation
pass "Database and Foundation adapter race tests"

adapter_file="internal/foundation/authorization_policy.go"
database_file="internal/database/pool.go"
query='"SELECT decision.bind_authorization_policy($1::uuid)"'
[[ "$(grep -Foc -- "$query" "$database_file")" -eq 1 ]] \
    || fail "Database boundary contains one exact parameterized controlled routine statement"
pass "Database boundary contains one exact parameterized controlled routine statement"

if grep -R -F 'decision.bind_authorization_policy' internal \
    --include='*.go' \
    | grep -v '^internal/database/pool.go:' \
    | grep -v '^internal/foundation/authorization_policy.go:' \
    | grep -v '_test.go:' >/dev/null 2>&1; then
    fail "Controlled routine reference is confined to the operation-specific database boundary and typed adapter"
fi
pass "Controlled routine reference is confined to the operation-specific database boundary and typed adapter"

for reason_code in \
    AUTHORIZATION_POLICY_SELECTED \
    AUTHORIZATION_POLICY_NOT_FOUND \
    AUTHORIZATION_POLICY_AMBIGUOUS \
    AUTHORIZATION_POLICY_CONTEXT_MISMATCH \
    AUTHORIZATION_DECISION_ALREADY_FINALIZED \
    AUTHORIZATION_POLICY_ALREADY_BOUND
do
    grep -Fq -- "$reason_code" "$adapter_file" \
        || fail "Adapter preserves reason code: $reason_code"
    pass "Adapter preserves reason code: $reason_code"
done

for required_text in \
    'defaultAuthorizationPolicyTimeout = 3 * time.Second' \
    'identity != database.FoundationAPI' \
    'context.WithTimeout' \
    'DecisionID DecisionID' \
    'ReasonCode PolicyBindingReasonCode'
do
    grep -Fq -- "$required_text" "$adapter_file" \
        || fail "Adapter contains: $required_text"
    pass "Adapter contains: $required_text"
done

if grep -Eq '\b(INSERT|UPDATE|DELETE|MERGE|ALTER|CREATE|DROP|GRANT|REVOKE|TRUNCATE|COPY|CALL)\b' \
    "$adapter_file"; then
    fail "Adapter contains no mutating SQL verb"
fi
pass "Adapter contains no mutating SQL verb"

if grep -Eiq 'decision_records|authorization_policy_versions|evaluation_records|supporting_records' \
    "$adapter_file"; then
    fail "Adapter contains no protected table reference"
fi
pass "Adapter contains no protected table reference"

if grep -Fq 'BindAuthorizationPolicy' internal/foundation/authorization_policy.go \
    && grep -Fq 'BindAuthorizationPolicy' internal/database/pool.go; then
    pass "Foundation adapter uses the operation-specific database boundary"
else
    fail "Foundation adapter uses the operation-specific database boundary"
fi

if grep -R -E 'QueryScalarText|statement string|query string|sql string|args \.\.\.any' \
    internal/database --include='*.go' | grep -v '_test.go' >/dev/null 2>&1; then
    fail "Database package exposes no caller-selected SQL boundary"
fi
pass "Database package exposes no caller-selected SQL boundary"

if grep -R -E '"github.com/jackc/pgx/v5' internal --include='*.go' \
    | grep -v '^internal/database/' >/dev/null 2>&1; then
    fail "pgx imports remain confined to internal/database"
fi
pass "pgx imports remain confined to internal/database"

if grep -R -E 'HandleFunc\(|Handle\(' internal/foundation --include='*.go' \
    | grep -v '_test.go' >/dev/null 2>&1; then
    fail "Foundation adapter introduces no transport handler"
fi
pass "Foundation adapter introduces no transport handler"

for test_name in \
    TestParseDecisionIDNormalizesCanonicalUUID \
    TestAuthorizationPolicyAdapterUsesNarrowBoundaryAndPreservesReference \
    TestAuthorizationPolicyAdapterAcceptsExactReasonCodeInventory \
    TestAuthorizationPolicyAdapterRejectsUnexpectedReasonCode \
    TestAuthorizationPolicyAdapterRejectsWrongIdentity \
    TestAuthorizationPolicyAdapterHonorsCancellationAndTimeout \
    TestIntegrationAuthorizationPolicyBinding
do
    grep -R -Fq -- "$test_name" internal/foundation \
        || fail "Foundation adapter test exists: $test_name"
    pass "Foundation adapter test exists: $test_name"
done

printf '\nPhase 6 Step 5 adapter checks: %d PASS, 0 FAIL\n' "$pass_count"
