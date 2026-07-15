#!/usr/bin/env bash
set -Eeuo pipefail

static_only=false
case "${1:-}" in
    "") ;;
    --static-only) static_only=true ;;
    *) printf 'Usage: %s [--static-only]\n' "$0" >&2; exit 2 ;;
esac

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[[ -n "$repo_root" ]] || { printf 'FAIL: Repository is a Git work tree\n' >&2; exit 1; }
cd "$repo_root"

predecessor_commit="1aefa613a80c1f5cdaf7807702b1b747d7e77ec5"
canonical_origin="git@github.com:Iron-Signal-Systems/iron-signal-platform.git"
pass_count=0
fail_count=0
scratch="$(mktemp -d "${TMPDIR:-/tmp}/issp-phase6-step6-gate.XXXXXX")"
trap 'rm -rf -- "$scratch"' EXIT

pass() { pass_count=$((pass_count + 1)); printf 'PASS: %s\n' "$1"; }
fail() { fail_count=$((fail_count + 1)); printf 'FAIL: %s\n' "$1" >&2; }
require_command() { command -v "$1" >/dev/null 2>&1 && pass "Required command available: $1" || fail "Required command available: $1"; }
require_file() { [[ -f "$1" ]] && pass "$2" || fail "$2"; }
require_executable() { [[ -x "$1" ]] && pass "$2" || fail "$2"; }
require_text() { grep -Fq -- "$2" "$1" && pass "$3" || fail "$3"; }
run_check() { local label="$1"; shift; if "$@"; then pass "$label"; else fail "$label"; fi; }
finish() {
    printf '\nPASS checks: %d\nFAIL checks: %d\n' "$pass_count" "$fail_count"
    if (( fail_count == 0 )); then
        if $static_only; then
            printf 'Phase 6 Step 6 static validation PASSED completely.\n'
        else
            printf 'Phase 6 Step 6 complete validation PASSED completely.\n'
        fi
        exit 0
    fi
    printf 'Phase 6 Step 6 validation FAILED.\n'
    exit 1
}

for command_name in git bash go gofmt grep find sort cmp mktemp python3 systemd-analyze systemd-sysusers; do
    require_command "$command_name"
done

[[ "$(git branch --show-current)" == dev ]] && pass "Authoritative branch is dev" || fail "Authoritative branch is dev"
[[ "$(git remote get-url origin 2>/dev/null || true)" == "$canonical_origin" ]] && pass "Canonical Iron Signal Systems origin configured" || fail "Canonical Iron Signal Systems origin configured"
git merge-base --is-ancestor "$predecessor_commit" HEAD && pass "Accepted Step 5 commit is an ancestor of the candidate" || fail "Accepted Step 5 commit is an ancestor of the candidate"

if git clone -q --no-hardlinks "$repo_root" "$scratch/predecessor"; then
    (
        cd "$scratch/predecessor"
        git remote set-url origin "$canonical_origin"
        git checkout -q -B dev "$predecessor_commit"
    )
    predecessor_args=()
    $static_only && predecessor_args=(--static-only)
    if (
        cd "$scratch/predecessor"
        bash tools/validation/phase-gates/validate_phase6_step5.sh "${predecessor_args[@]}"
    ) >"$scratch/predecessor.log" 2>&1; then
        pass "Accepted Step 5 predecessor revalidates in isolated dev clone"
    else
        cat "$scratch/predecessor.log" >&2
        fail "Accepted Step 5 predecessor revalidates in isolated dev clone"
    fi
else
    fail "Accepted Step 5 predecessor revalidates in isolated dev clone"
fi

frozen_paths=(
    sql/schema
    sql/deployment
    test-framework/sql
    go/platform/go.mod
    go/platform/go.sum
    go/platform/TOOLCHAIN
    go/platform/internal/database
    go/platform/internal/foundation
    go/platform/internal/processhost
    go/platform/internal/workers
    go/platform/scripts/build.sh
    go/platform/scripts/test-foundation-adapter.sh
    go/platform/scripts/test-foundation-adapter-runtime.sh
    tools/validation/phase-gates/validate_phase6_step1.sh
    tools/validation/phase-gates/validate_phase6_step2.sh
    tools/validation/phase-gates/validate_phase6_step3.sh
    tools/validation/phase-gates/validate_phase6_step4.sh
    tools/validation/phase-gates/validate_phase6_step5.sh
)
for frozen_path in "${frozen_paths[@]}"; do
    if git diff --quiet "$predecessor_commit" -- "$frozen_path"; then
        pass "Accepted predecessor path unchanged: $frozen_path"
    else
        fail "Accepted predecessor path unchanged: $frozen_path"
    fi
done

step5_record="docs/architecture/backend-services/phase-6-step-5-controlled-foundation-api-adapter.md"
require_text "$step5_record" "Status:** Accepted implementation checkpoint." "Step 5 record identifies accepted checkpoint status"
require_text "$step5_record" "$predecessor_commit" "Step 5 record names the exact accepted commit"
require_text "$step5_record" "96 PASS and 0 FAIL" "Step 5 record preserves the final complete result"

record="docs/architecture/backend-services/phase-6-step-6-authenticated-request-and-transport-boundary.md"
require_file "$record" "Step 6 authenticated transport record exists"
require_text "$record" "Status:** Implementation candidate." "Step 6 record identifies implementation-candidate status"
require_text "$record" "ISSP-HANDOFF-V1" "Step 6 record freezes canonical signature version"
require_text "$record" "30-second age window" "Step 6 record freezes handoff freshness"
require_text "$record" "1,024 entries" "Step 6 record freezes replay capacity"
require_text "$record" "Phase 6 Step 7 may implement" "Step 6 record identifies the next step"

required_files=(
    go/platform/internal/authentication/handoff.go
    go/platform/internal/authentication/handoff_test.go
    go/platform/internal/transport/business.go
    go/platform/internal/transport/business_test.go
    go/platform/scripts/test-authenticated-transport.sh
    go/platform/scripts/test-authenticated-transport-runtime.sh
    tools/validation/phase-gates/validate_phase6_step6.sh
)
for required_path in "${required_files[@]}"; do
    require_file "$required_path" "Step 6 artifact exists: $required_path"
done
for executable_path in go/platform/scripts/test-authenticated-transport.sh go/platform/scripts/test-authenticated-transport-runtime.sh tools/validation/phase-gates/validate_phase6_step6.sh; do
    require_executable "$executable_path" "Executable: $executable_path"
done

require_text go/platform/internal/authentication/handoff.go "hmac.New(sha256.New" "Authentication handoff uses HMAC-SHA-256"
require_text go/platform/internal/authentication/handoff.go "hmac.Equal" "Authentication handoff uses constant-time comparison"
require_text go/platform/internal/authentication/handoff.go "MaximumHandoffAge    = 30 * time.Second" "Authentication handoff age is bounded"
require_text go/platform/internal/authentication/handoff.go "MaximumReplayEntries = 1024" "Authentication replay state is bounded"
require_text go/platform/internal/transport/business.go 'AuthorizationPolicyBindingPath = "/v1/foundation/authorization-policy-bindings"' "Business transport exposes the exact Step 6 route"
require_text go/platform/internal/transport/business.go "maximumBusinessRequestBody     = 1024" "Business request body is bounded"
require_text go/platform/internal/transport/business.go "businessRequestTimeout         = 4 * time.Second" "Business request lifetime is bounded"
require_text go/platform/internal/transport/business.go "handler.binder.BindAuthorizationPolicy(requestContext, decisionID)" "Transport invokes only the accepted Step 5 adapter"
require_text go/platform/internal/transport/business.go "X-Forwarded-For" "Transport rejects proxy-derived identity headers"

foundation_unit="go/platform/deployment/systemd/iron-signal-foundation-api.service"
require_text "$foundation_unit" "LoadCredentialEncrypted=transport-hmac-key:/etc/iron-signal-platform/credentials/foundation-api.transport-hmac-key.cred" "Foundation unit uses a distinct encrypted handoff credential"
require_text "$foundation_unit" "Environment=ISSP_BUSINESS_LISTEN_ADDRESS=127.0.0.1:18080" "Foundation unit binds the business listener to loopback"
require_text "$foundation_unit" 'Environment=ISSP_TRANSPORT_HMAC_KEY_FILE=%d/transport-hmac-key' "Foundation unit uses the service credential directory"
require_text "$foundation_unit" "Environment=ISSP_TRANSPORT_MAX_CONCURRENT_REQUESTS=8" "Foundation unit bounds business concurrency"

for worker_unit in go/platform/deployment/systemd/iron-signal-integration-delivery-worker.service go/platform/deployment/systemd/iron-signal-monitoring-delivery-worker.service; do
    if grep -E 'ISSP_BUSINESS_LISTEN_ADDRESS|ISSP_TRANSPORT_HMAC_KEY_FILE|transport-hmac-key' "$worker_unit" >/dev/null 2>&1; then
        fail "Worker unit receives no business transport authority: $worker_unit"
    else
        pass "Worker unit receives no business transport authority: $worker_unit"
    fi
done

if [[ "$(grep -R -F '"/v1/foundation/authorization-policy-bindings"' go/platform/internal --include='*.go' | grep -v '_test.go' | wc -l)" -eq 2 ]]; then
    pass "Production source contains one route constant and one canonical authentication path"
else
    fail "Production source contains one route constant and one canonical authentication path"
fi

if grep -R -E 'decision\.bind_authorization_policy|\b(SELECT|INSERT|UPDATE|DELETE|CALL)\b' go/platform/internal/authentication go/platform/internal/transport --include='*.go' | grep -v '_test.go' >/dev/null 2>&1; then
    fail "Authentication and transport packages contain no SQL or protected routine reference"
else
    pass "Authentication and transport packages contain no SQL or protected routine reference"
fi

if python3 - <<'PY_REQUEST_BOUNDARY'
from pathlib import Path
import re

source = Path(
    "go/platform/internal/transport/business.go"
).read_text(encoding="utf-8")

match = re.search(
    r"func decodeBindingRequest\(body \[\]byte\).*?\n}\n",
    source,
    flags=re.DOTALL,
)

if match is None:
    raise SystemExit(1)

request_decoder = match.group(0)

if 'json:"decision_id"' not in request_decoder:
    raise SystemExit(1)

forbidden = re.compile(
    r'json:"(?:role|organization|purpose|scope|permission|'
    r'policy|result|reason)(?:_|")'
)

if forbidden.search(request_decoder):
    raise SystemExit(1)
PY_REQUEST_BOUNDARY
then
    pass "Business request accepts no caller-selected authorization field"
else
    fail "Business request accepts no caller-selected authorization field"
fi

if git diff --name-only "$predecessor_commit" -- go/platform/go.mod go/platform/go.sum | grep -q .; then
    fail "Step 6 adds no Go module dependency"
else
    pass "Step 6 adds no Go module dependency"
fi

if git diff --name-only "$predecessor_commit" -- sql/schema sql/deployment | grep -q .; then
    fail "Step 6 adds no Foundation or deployment migration"
else
    pass "Step 6 adds no Foundation or deployment migration"
fi

if find go/platform/internal/workers -type f ! -name doc.go -print -quit | grep -q .; then
    fail "Durable worker implementation remains absent"
else
    pass "Durable worker implementation remains absent"
fi

run_check "Repository diff is whitespace-clean" git diff --check

if (cd go/platform && bash scripts/check.sh) >"$scratch/go-check.log" 2>&1; then pass "Production Go checks pass"; else cat "$scratch/go-check.log" >&2; fail "Production Go checks pass"; fi
if (cd go/platform && bash scripts/test-process-host.sh) >"$scratch/process-host.log" 2>&1; then pass "Accepted process-host static and race validation remains valid"; else cat "$scratch/process-host.log" >&2; fail "Accepted process-host static and race validation remains valid"; fi
if (cd go/platform && bash scripts/test-foundation-adapter.sh) >"$scratch/foundation-adapter.log" 2>&1; then pass "Accepted controlled adapter static and race validation remains valid"; else cat "$scratch/foundation-adapter.log" >&2; fail "Accepted controlled adapter static and race validation remains valid"; fi
if (cd go/platform && bash scripts/test-authenticated-transport.sh) >"$scratch/authenticated-transport.log" 2>&1; then pass "Authenticated transport static and race validation passes"; else cat "$scratch/authenticated-transport.log" >&2; fail "Authenticated transport static and race validation passes"; fi

synchronized_docs=(
    README.md
    docs/README.md
    docs/architecture/README.md
    docs/architecture/backend-services/README.md
    docs/architecture/backend-services/production-go-service-boundary-and-runtime-model.md
    docs/architecture/foundation/README.md
    go/README.md
    go/platform/README.md
    go/platform/DEPENDENCIES.md
    tools/validation/README.md
    tools/validation/phase-gates/README.md
)
for doc in "${synchronized_docs[@]}"; do
    require_text "$doc" "Phase 6 Step 6" "Documentation synchronized for Step 6: $doc"
done

if grep -E 'Step 5.*(implementation candidate|active implementation)' "${synchronized_docs[@]}" >/dev/null 2>&1; then
    fail "Stale Step 5 candidate status is absent from current indexes"
else
    pass "Stale Step 5 candidate status is absent from current indexes"
fi

if $static_only; then
    pass "Static-only mode skips disposable authenticated transport execution"
else
    if (cd go/platform && bash scripts/test-authenticated-transport-runtime.sh) >"$scratch/step6-runtime.log" 2>&1; then
        pass "Step 6 authenticated transport runtime validation passes"
    else
        cat "$scratch/step6-runtime.log" >&2
        fail "Step 6 authenticated transport runtime validation passes"
    fi
fi

finish
