#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
predecessor_commit="45f5449d57eda0ea8a5f2e3128f6903251599810"
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
        printf 'Phase 6 Step 4 validation FAILED.\n' >&2
        exit 1
    fi

    if $static_only; then
        printf 'Phase 6 Step 4 static validation PASSED completely.\n'
    else
        printf 'Phase 6 Step 4 complete validation PASSED completely.\n'
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

run_check \
    "Accepted Step 3 commit is an ancestor of the candidate" \
    git merge-base --is-ancestor "$predecessor_commit" HEAD

scratch="$(mktemp -d "${TMPDIR:-/tmp}/issp-phase6-step4-gate.XXXXXX")"
cleanup() {
    rm -rf -- "$scratch"
}
trap cleanup EXIT

canonical_origin="git@github.com:Iron-Signal-Systems/iron-signal-platform.git"

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
        bash tools/validation/phase-gates/validate_phase6_step3.sh \
            "${predecessor_args[@]}" >"$scratch/predecessor.log" 2>&1
    ); then
        pass "Accepted Step 3 predecessor revalidates in isolated dev clone"
    else
        cat "$scratch/predecessor.log" >&2
        fail "Accepted Step 3 predecessor revalidates in isolated dev clone"
    fi
else
    fail "Accepted Step 3 predecessor clone created"
fi

frozen_paths=(
    sql/schema
    sql/deployment
    test-framework/sql
    tools/validation/phase-gates/validate_phase6_step1.sh
    tools/validation/phase-gates/validate_phase6_step2.sh
    tools/validation/phase-gates/validate_phase6_step3.sh
)
for frozen_path in "${frozen_paths[@]}"; do
    if git diff --quiet "$predecessor_commit" -- "$frozen_path"; then
        pass "Accepted predecessor path unchanged: $frozen_path"
    else
        fail "Accepted predecessor path unchanged: $frozen_path"
    fi
done

record="docs/architecture/backend-services/phase-6-step-4-process-host-integration-and-hostile-runtime-validation.md"
require_file "$record" "Step 4 process-host record exists"
require_text "$record" \
    "Status:** Acceptance-hardening implementation candidate." \
    "Step 4 record identifies acceptance-hardening status"
require_text "$record" \
    "Type=notify" \
    "Step 4 record requires notify service type"
require_text "$record" \
    "LoadCredentialEncrypted=" \
    "Step 4 record requires encrypted systemd credentials"
require_text "$record" \
    "Socket activation is not introduced in Step 4." \
    "Step 4 record explicitly rejects socket activation"
require_text "$record" \
    "Phase 6 Step 5 may implement the Controlled Foundation" \
    "Step 4 record identifies the corrected next step"

required_files=(
    go/platform/internal/processhost/notify.go
    go/platform/internal/processhost/notify_test.go
    go/platform/internal/transport/hostile_test.go
    go/platform/deployment/README.md
    go/platform/deployment/systemd/iron-signal-foundation-api.service
    go/platform/deployment/systemd/iron-signal-integration-delivery-worker.service
    go/platform/deployment/systemd/iron-signal-monitoring-delivery-worker.service
    go/platform/deployment/sysusers.d/iron-signal-platform.conf
    go/platform/scripts/test-process-host.sh
    go/platform/scripts/test-process-host-runtime.sh
)
for required_path in "${required_files[@]}"; do
    require_file "$required_path" "Step 4 artifact exists: $required_path"
done

mapfile -t socket_units < <(
    find go/platform/deployment -type f -name '*.socket' -print
)
[[ ${#socket_units[@]} -eq 0 ]] \
    && pass "No socket-activation unit exists" \
    || fail "No socket-activation unit exists"

mapfile -t service_units < <(
    find go/platform/deployment/systemd \
        -maxdepth 1 \
        -type f \
        -name '*.service' \
        -printf '%f\n' |
        sort
)
[[ ${#service_units[@]} -eq 3 ]] \
    && pass "Exact three service units exist" \
    || fail "Exact three service units exist"

require_text \
    go/platform/internal/bootstrap/run.go \
    '"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/processhost"' \
    "Bootstrap imports only the bounded process-host package"
require_text \
    go/platform/internal/bootstrap/run.go \
    "host.Ready()" \
    "Bootstrap sends readiness after database compatibility"
require_text \
    go/platform/internal/bootstrap/run.go \
    "host.RunWatchdog" \
    "Bootstrap runs bounded watchdog behavior"
require_text \
    go/platform/internal/bootstrap/run.go \
    "host.Stopping()" \
    "Bootstrap sends stopping notification"
require_text \
    go/platform/internal/bootstrap/run.go \
    "state.SetReady(false)" \
    "Bootstrap leaves readiness before shutdown"
require_text \
    go/platform/internal/transport/hostile_test.go \
    "TestAdministrativeShutdownIsBoundedWithInflightRequest" \
    "Bounded in-flight administrative shutdown test exists"
require_text \
    go/platform/internal/transport/hostile_test.go \
    "TestServeReportsUnexpectedListenerClosure" \
    "Unexpected post-start listener failure test exists"
require_text \
    go/platform/scripts/test-process-host-runtime.sh \
    "Database-unavailable startup emits no readiness notification" \
    "Hostile runtime proves database failure emits no readiness"
require_text \
    go/platform/scripts/test-process-host-runtime.sh \
    "SIGTERM during database startup exits cleanly without readiness" \
    "Hostile runtime proves startup cancellation behavior"
require_text \
    go/platform/scripts/test-process-host-runtime.sh \
    "SIGINT plus repeated termination exits cleanly" \
    "Hostile runtime proves SIGINT and repeated termination behavior"

if python3 - <<'PY'
from pathlib import Path
import re
import sys

root = Path("go/platform")
for path in root.rglob("*.go"):
    if path.name.endswith("_test.go"):
        continue

    text = path.read_text(encoding="utf-8")
    for verb in (
        "INSERT", "UPDATE", "DELETE", "MERGE", "ALTER", "CREATE",
        "DROP", "GRANT", "REVOKE", "TRUNCATE", "COPY", "CALL",
    ):
        if re.search(rf"\b{verb}\b", text, flags=re.IGNORECASE):
            print(
                f"{path}: protected or mutating SQL verb token: {verb}",
                file=sys.stderr,
            )
            raise SystemExit(1)
PY
then
    pass "Production Go source contains no mutating or protected SQL verb"
else
    fail "Production Go source contains no mutating or protected SQL verb"
fi

if grep -R -E \
    'HandleFunc\(|Handle\(' \
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
    pass "Production Go Step 4 checks pass"
else
    cat "$scratch/go-check.log" >&2
    fail "Production Go Step 4 checks pass"
fi

if (
    cd go/platform
    bash scripts/test-process-host.sh
) >"$scratch/process-host.log" 2>&1
then
    pass "Process-host static and race validation passes"
else
    cat "$scratch/process-host.log" >&2
    fail "Process-host static and race validation passes"
fi

synchronized_docs=(
    README.md
    docs/README.md
    docs/architecture/README.md
    docs/architecture/backend-services/README.md
    docs/architecture/foundation/README.md
    go/README.md
    go/platform/README.md
    tools/validation/README.md
    tools/validation/phase-gates/README.md
)
for doc in "${synchronized_docs[@]}"; do
    require_text \
        "$doc" \
        "Phase 6 Step 4" \
        "Documentation synchronized for Step 4: $doc"
done

step4_evidence_record="docs/architecture/backend-services/phase-6-step-4-process-host-integration-and-hostile-runtime-validation.md"

if grep -Fq \
    "## 13. Hostile Runtime Validation and Evidence Matrix" \
    "$step4_evidence_record"
then
    pass "Step 4 record contains the validation evidence matrix"
else
    fail "Step 4 record contains the validation evidence matrix"
fi
require_text \
    "$record" \
    "pre-hardening candidate passed 59 static checks and 60 complete checks" \
    "Step 4 record preserves pre-hardening validation evidence"

if [[ -e "et -o pipefail" ]]; then
    fail "Accidental review-capture file remains absent"
else
    pass "Accidental review-capture file remains absent"
fi

if grep -R -F --include='*.md' \
    "No Step 4 implementation or acceptance is claimed yet" \
    README.md docs go tools/validation >/dev/null 2>&1
then
    fail "Stale no-implementation claim is absent"
else
    pass "Stale no-implementation claim is absent"
fi

if grep -R -F --include='*.md' \
    "validation contract candidate" \
    README.md docs go tools/validation >/dev/null 2>&1
then
    fail "Stale contract-candidate status is absent"
else
    pass "Stale contract-candidate status is absent"
fi

if $static_only; then
    pass "Static-only mode skips disposable hostile runtime execution"
else
    if (
        cd go/platform
        bash scripts/test-runtime.sh
    ) >"$scratch/step3-runtime.log" 2>&1
    then
        pass "Accepted Step 3 runtime behavior remains valid"
    else
        cat "$scratch/step3-runtime.log" >&2
        fail "Accepted Step 3 runtime behavior remains valid"
    fi

    if (
        cd go/platform
        bash scripts/test-process-host-runtime.sh
    ) >"$scratch/step4-runtime.log" 2>&1
    then
        pass "Step 4 hostile process-host runtime validation passes"
    else
        cat "$scratch/step4-runtime.log" >&2
        fail "Step 4 hostile process-host runtime validation passes"
    fi
fi

finish
