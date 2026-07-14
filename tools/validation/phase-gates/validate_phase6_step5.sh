#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
predecessor_commit="3e15c8cbb7b666537be6a7ec832800e8f4ca9af0"
canonical_origin="git@github.com:Iron-Signal-Systems/iron-signal-platform.git"
static_only=false

if [[ "${1:-}" == "--static-only" ]]; then
    static_only=true
elif [[ $# -gt 0 ]]; then
    printf 'Usage: %s [--static-only]\n' "$0" >&2
    exit 2
fi

pass_count=0
fail_count=0

pass() {
    pass_count=$((pass_count + 1))
    printf 'PASS: %s\n' "$1"
}

fail() {
    fail_count=$((fail_count + 1))
    printf 'FAIL: %s\n' "$1" >&2
}

require_file() {
    if [[ -f "$1" ]]; then
        pass "$2"
    else
        fail "$2"
    fi
}

require_executable() {
    if [[ -x "$1" ]]; then
        pass "$2"
    else
        fail "$2"
    fi
}

require_text() {
    if grep -Fq -- "$2" "$1"; then
        pass "$3"
    else
        fail "$3"
    fi
}

run_check() {
    local description="$1"
    shift
    if "$@"; then
        pass "$description"
    else
        fail "$description"
    fi
}

finish() {
    printf '\nPASS checks: %d\n' "$pass_count"
    printf 'FAIL checks: %d\n' "$fail_count"

    if (( fail_count > 0 )); then
        printf 'Phase 6 Step 5 validation FAILED.\n' >&2
        exit 1
    fi

    if $static_only; then
        printf 'Phase 6 Step 5 static validation PASSED completely.\n'
    else
        printf 'Phase 6 Step 5 complete validation PASSED completely.\n'
    fi
}

cd "$repo_root"

for command_name in \
    git bash go gofmt grep find sort cmp mktemp python3 systemd-analyze \
    systemd-sysusers
 do
    if command -v "$command_name" >/dev/null 2>&1; then
        pass "Required command available: $command_name"
    else
        fail "Required command available: $command_name"
    fi
done

[[ "$(git branch --show-current)" == "dev" ]] \
    && pass "Authoritative branch is dev" \
    || fail "Authoritative branch is dev"

[[ "$(git remote get-url origin)" == "$canonical_origin" ]] \
    && pass "Canonical Iron Signal Systems origin configured" \
    || fail "Canonical Iron Signal Systems origin configured"

run_check \
    "Accepted Step 4 commit is an ancestor of the candidate" \
    git merge-base --is-ancestor "$predecessor_commit" HEAD

scratch="$(mktemp -d "${TMPDIR:-/tmp}/issp-phase6-step5-gate.XXXXXX")"
cleanup() {
    rm -rf -- "$scratch"
}
trap cleanup EXIT

if git clone -q --no-hardlinks "$repo_root" "$scratch/predecessor"; then
    (
        cd "$scratch/predecessor"
        git remote set-url origin "$canonical_origin"
        git checkout -q -B dev "$predecessor_commit"
    )

    predecessor_args=(--static-only)
    $static_only || predecessor_args=()

    if (
        cd "$scratch/predecessor"
        bash tools/validation/phase-gates/validate_phase6_step4.sh \
            "${predecessor_args[@]}" >"$scratch/predecessor.log" 2>&1
    ); then
        pass "Accepted Step 4 predecessor revalidates in isolated dev clone"
    else
        cat "$scratch/predecessor.log" >&2
        fail "Accepted Step 4 predecessor revalidates in isolated dev clone"
    fi
else
    fail "Accepted Step 4 predecessor clone created"
fi

frozen_paths=(
    sql/schema
    sql/deployment
    test-framework/sql
    tools/validation/phase-gates/validate_phase6_step1.sh
    tools/validation/phase-gates/validate_phase6_step2.sh
    tools/validation/phase-gates/validate_phase6_step3.sh
    tools/validation/phase-gates/validate_phase6_step4.sh
    go/platform/go.mod
    go/platform/go.sum
    go/platform/TOOLCHAIN
    go/platform/cmd
    go/platform/deployment
    go/platform/internal/config
    go/platform/internal/observability
    go/platform/internal/processhost
    go/platform/internal/transport
    go/platform/internal/workers
    go/platform/scripts/build.sh
    go/platform/scripts/test-runtime.sh
    go/platform/scripts/test-process-host.sh
    go/platform/scripts/test-process-host-runtime.sh
)
for frozen_path in "${frozen_paths[@]}"; do
    if git diff --quiet "$predecessor_commit" -- "$frozen_path"; then
        pass "Accepted predecessor path unchanged: $frozen_path"
    else
        fail "Accepted predecessor path unchanged: $frozen_path"
    fi
done

step4_record="docs/architecture/backend-services/phase-6-step-4-process-host-integration-and-hostile-runtime-validation.md"
require_text "$step4_record" \
    "Status:** Accepted implementation checkpoint." \
    "Step 4 record identifies accepted checkpoint status"
require_text "$step4_record" \
    "$predecessor_commit" \
    "Step 4 record names the exact accepted commit"
require_text "$step4_record" \
    "71 PASS and 0 FAIL" \
    "Step 4 record preserves the final complete result"

record="docs/architecture/backend-services/phase-6-step-5-controlled-foundation-api-adapter.md"
require_file "$record" "Step 5 controlled adapter record exists"
require_text "$record" \
    "Status:** Implementation candidate." \
    "Step 5 record identifies implementation-candidate status"
require_text "$record" \
    "decision.bind_authorization_policy(uuid)" \
    "Step 5 record names the exact protected routine"
require_text "$record" \
    "three-second operation deadline" \
    "Step 5 record requires the bounded operation deadline"
require_text "$record" \
    "Phase 6 Step 6 may implement the Authenticated Request" \
    "Step 5 record identifies the next step"

required_files=(
    go/platform/internal/foundation/authorization_policy.go
    go/platform/internal/foundation/authorization_policy_test.go
    go/platform/internal/foundation/authorization_policy_integration_test.go
    go/platform/testdata/phase6-step5/authorization-policy-binding-fixtures.sql
    go/platform/scripts/test-foundation-adapter.sh
    go/platform/scripts/test-foundation-adapter-runtime.sh
    tools/validation/phase-gates/validate_phase6_step5.sh
)
for required_path in "${required_files[@]}"; do
    require_file "$required_path" "Step 5 artifact exists: $required_path"
done

for executable_path in \
    go/platform/scripts/test-foundation-adapter.sh \
    go/platform/scripts/test-foundation-adapter-runtime.sh \
    tools/validation/phase-gates/validate_phase6_step5.sh
 do
    require_executable "$executable_path" "Executable: $executable_path"
done

adapter="go/platform/internal/foundation/authorization_policy.go"
require_text \
    go/platform/internal/database/pool.go \
    'SELECT decision.bind_authorization_policy($1::uuid)' \
    "Adapter uses the exact parameterized protected routine statement"
require_text "$adapter" \
    "defaultAuthorizationPolicyTimeout = 3 * time.Second" \
    "Adapter uses the exact three-second deadline"
require_text "$adapter" \
    "identity != database.FoundationAPI" \
    "Adapter enforces the Foundation API identity"
require_text "$adapter" \
    "context.WithTimeout" \
    "Adapter applies bounded context cancellation"
require_text "$adapter" \
    "DecisionID DecisionID" \
    "Adapter result preserves the Decision Record reference"
require_text "$adapter" \
    "ReasonCode PolicyBindingReasonCode" \
    "Adapter result preserves the typed reason code"

for reason_code in \
    AUTHORIZATION_POLICY_SELECTED \
    AUTHORIZATION_POLICY_NOT_FOUND \
    AUTHORIZATION_POLICY_AMBIGUOUS \
    AUTHORIZATION_POLICY_CONTEXT_MISMATCH \
    AUTHORIZATION_DECISION_ALREADY_FINALIZED \
    AUTHORIZATION_POLICY_ALREADY_BOUND
 do
    require_text "$adapter" "$reason_code" \
        "Adapter preserves reason code: $reason_code"
done

if python3 - <<'PY'
from pathlib import Path
import re

adapter = Path("go/platform/internal/foundation/authorization_policy.go")
database = Path("go/platform/internal/database/pool.go")
text = adapter.read_text(encoding="utf-8")
database_text = database.read_text(encoding="utf-8")

if database_text.count('"SELECT decision.bind_authorization_policy($1::uuid)"') != 1:
    raise SystemExit(1)

for forbidden in (
    "decision_records",
    "authorization_policy_versions",
    "evaluation_records",
    "supporting_records",
):
    if forbidden in text:
        raise SystemExit(1)

if re.search(
    r"\b(INSERT|UPDATE|DELETE|MERGE|ALTER|CREATE|DROP|GRANT|REVOKE|TRUNCATE|COPY|CALL)\b",
    text,
):
    raise SystemExit(1)
PY
then
    pass "Operation-specific database boundary contains one fixed routine statement and adapter contains no direct table or mutating SQL"
else
    fail "Operation-specific database boundary contains one fixed routine statement and adapter contains no direct table or mutating SQL"
fi

if python3 - <<'PY'
from pathlib import Path

allowed = {
    Path("go/platform/internal/database/pool.go"),
    Path("go/platform/internal/foundation/authorization_policy.go"),
}
for path in Path("go/platform").rglob("*.go"):
    if path.name.endswith("_test.go"):
        continue
    text = path.read_text(encoding="utf-8")
    if "decision.bind_authorization_policy" in text and path not in allowed:
        print(path)
        raise SystemExit(1)
PY
then
    pass "Protected routine reference is confined to the operation-specific database boundary and typed adapter"
else
    fail "Protected routine reference is confined to the operation-specific database boundary and typed adapter"
fi

require_text go/platform/internal/database/pool.go \
    "type Pool struct" \
    "Database package owns the private pool wrapper"
require_text go/platform/internal/database/pool.go \
    "inner    *pgxpool.Pool" \
    "Underlying pgx pool remains private"
require_text go/platform/internal/database/pool.go \
    "BindAuthorizationPolicy" \
    "Database package exposes the operation-specific binding boundary"

if grep -R -E '"github.com/jackc/pgx/v5' go/platform/internal --include='*.go' \
    | grep -v '^go/platform/internal/database/' >/dev/null 2>&1
then
    fail "pgx imports remain confined to internal/database"
else
    pass "pgx imports remain confined to internal/database"
fi

if grep -E '^func \(p \*Pool\) (Exec|Query|QueryRow|Begin|BeginTx|CopyFrom|SendBatch|Raw|Inner|QueryScalarText)\b' \
    go/platform/internal/database/pool.go >/dev/null 2>&1 || \
    grep -E 'statement string|query string|sql string|args \.\.\.any' \
    go/platform/internal/database/pool.go >/dev/null 2>&1
then
    fail "Database wrapper exposes no caller-selected SQL or general pgx primitive"
else
    pass "Database wrapper exposes no caller-selected SQL or general pgx primitive"
fi

if grep -R -E 'HandleFunc\(|Handle\(' \
    go/platform/internal \
    --include='*.go' |
    grep -v '_test.go' |
    grep -Ev '"/healthz"|"/readyz"' >/dev/null 2>&1
then
    fail "Administrative HTTP surface remains exactly health and readiness"
else
    pass "Administrative HTTP surface remains exactly health and readiness"
fi

if find go/platform/internal/workers \
    -type f \
    ! -name doc.go \
    -print -quit |
    grep -q .
then
    fail "Durable worker implementation remains absent"
else
    pass "Durable worker implementation remains absent"
fi

run_check \
    "Repository diff is whitespace-clean" \
    git diff --check

if (
    cd go/platform
    bash scripts/check.sh
) >"$scratch/go-check.log" 2>&1
then
    pass "Production Go Step 5 checks pass"
else
    cat "$scratch/go-check.log" >&2
    fail "Production Go Step 5 checks pass"
fi

if (
    cd go/platform
    bash scripts/test-process-host.sh
) >"$scratch/process-host.log" 2>&1
then
    pass "Accepted process-host static and race validation remains valid"
else
    cat "$scratch/process-host.log" >&2
    fail "Accepted process-host static and race validation remains valid"
fi

if (
    cd go/platform
    bash scripts/test-foundation-adapter.sh
) >"$scratch/foundation-adapter.log" 2>&1
then
    pass "Controlled Foundation adapter static and race validation passes"
else
    cat "$scratch/foundation-adapter.log" >&2
    fail "Controlled Foundation adapter static and race validation passes"
fi

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
    require_text "$doc" \
        "Phase 6 Step 5" \
        "Documentation synchronized for Step 5: $doc"
done

current_status_docs=(
    README.md
    docs/README.md
    docs/architecture/README.md
    docs/architecture/backend-services/README.md
    go/README.md
    go/platform/README.md
    tools/validation/README.md
    tools/validation/phase-gates/README.md
)
if grep -F \
    "Step 3 remains the newest accepted" \
    "${current_status_docs[@]}" >/dev/null 2>&1
then
    fail "Stale Step 3 newest-accepted status is absent"
else
    pass "Stale Step 3 newest-accepted status is absent"
fi

if grep -E \
    'Step 4.*(candidate|must.*revalidated)|acceptance-hardening correction' \
    "${current_status_docs[@]}" >/dev/null 2>&1
then
    fail "Stale Step 4 candidate status is absent from current indexes"
else
    pass "Stale Step 4 candidate status is absent from current indexes"
fi

if $static_only; then
    pass "Static-only mode skips disposable runtime execution"
else
    if (
        cd go/platform
        bash scripts/test-runtime.sh
    ) >"$scratch/step3-runtime.log" 2>&1
    then
        pass "Accepted database runtime behavior remains valid"
    else
        cat "$scratch/step3-runtime.log" >&2
        fail "Accepted database runtime behavior remains valid"
    fi

    if (
        cd go/platform
        bash scripts/test-process-host-runtime.sh
    ) >"$scratch/step4-runtime.log" 2>&1
    then
        pass "Accepted process-host hostile runtime behavior remains valid"
    else
        cat "$scratch/step4-runtime.log" >&2
        fail "Accepted process-host hostile runtime behavior remains valid"
    fi

    if (
        cd go/platform
        bash scripts/test-foundation-adapter-runtime.sh
    ) >"$scratch/step5-runtime.log" 2>&1
    then
        pass "Step 5 controlled adapter runtime validation passes"
    else
        cat "$scratch/step5-runtime.log" >&2
        fail "Step 5 controlled adapter runtime validation passes"
    fi
fi

finish
