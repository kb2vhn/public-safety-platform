#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

STATIC_ONLY=0
PASS_COUNT=0
FAIL_COUNT=0

usage() {
    cat <<'EOF'
Usage: tools/validation/phase-gates/validate_phase4_step2.sh [--static-only]

Default:
  Validate the Phase 4 Step 2 structural extension, run the complete
  Foundation correctness suite through the resource-aware wrapper, and verify
  that correctness and resource observations remain separate.

Options:
  --static-only  Run repository, SQL, test, telemetry-contract, and
                 documentation checks without PostgreSQL.
  -h, --help     Show this help text.
EOF
}

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    printf 'PASS: %s\n' "$*"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf 'FAIL: %s\n' "$*" >&2
}

section() {
    printf '\n== %s ==\n' "$*"
}

while (( $# > 0 )); do
    case "$1" in
        --static-only)
            STATIC_ONLY=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n\n' "$1" >&2
            usage >&2
            exit 64
            ;;
    esac
done

if (( BASH_VERSINFO[0] < 4 )); then
    printf 'Bash 4 or newer is required.\n' >&2
    printf 'Arch package: bash\n' >&2
    printf 'Install with: sudo pacman -S --needed bash\n' >&2
    exit 69
fi

declare -A COMMAND_PACKAGE_MAP=(
    [awk]="gawk"
    [basename]="coreutils"
    [bash]="bash"
    [cat]="coreutils"
    [createdb]="postgresql-libs"
    [date]="coreutils"
    [dirname]="coreutils"
    [dropdb]="postgresql-libs"
    [git]="git"
    [grep]="grep"
    [ln]="coreutils"
    [mkdir]="coreutils"
    [mktemp]="coreutils"
    [nproc]="coreutils"
    [psql]="postgresql-libs"
    [python3]="python"
    [rm]="coreutils"
    [sed]="sed"
    [sha256sum]="coreutils"
    [sleep]="coreutils"
    [tail]="coreutils"
    [tee]="coreutils"
    [uname]="coreutils"
    [/usr/bin/time]="time"
)

required_commands=(
    awk
    basename
    bash
    cat
    createdb
    date
    dirname
    dropdb
    git
    grep
    ln
    mkdir
    mktemp
    nproc
    psql
    python3
    rm
    sed
    sha256sum
    sleep
    tail
    tee
    uname
)

missing_commands=()
missing_packages=()
declare -A seen_packages=()

for command_name in "${required_commands[@]}"; do
    if command -v "$command_name" >/dev/null 2>&1; then
        continue
    fi

    missing_commands+=("$command_name")
    package_name="${COMMAND_PACKAGE_MAP[$command_name]}"

    if [[ -z "${seen_packages[$package_name]:-}" ]]; then
        missing_packages+=("$package_name")
        seen_packages["$package_name"]=1
    fi
done

if [[ ! -x /usr/bin/time ]]; then
    missing_commands+=('/usr/bin/time')
    if [[ -z "${seen_packages[time]:-}" ]]; then
        missing_packages+=('time')
        seen_packages[time]=1
    fi
fi

section "Dependency preflight"

if (( ${#missing_commands[@]} > 0 )); then
    printf 'Missing required commands:\n' >&2

    for command_name in "${missing_commands[@]}"; do
        printf '  %-18s Arch package: %s\n' \
            "$command_name" \
            "${COMMAND_PACKAGE_MAP[$command_name]}" >&2
    done

    printf '\nInstall all missing packages with:\n\n' >&2
    printf '  sudo pacman -S --needed' >&2
    printf ' %s' "${missing_packages[@]}" >&2
    printf '\n\nWhen operating as root without sudo:\n\n' >&2
    printf '  pacman -S --needed' >&2
    printf ' %s' "${missing_packages[@]}" >&2
    printf '\n\nNo repository file, result file, or database was modified.\n' >&2
    exit 69
fi

pass "All required Phase 4 Step 2 commands are available"

if ! repository_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    printf 'Run this validator from inside the repository.\n' >&2
    exit 66
fi

cd "$repository_root"

phase3_tag="phase-3-authorization-control-complete-v1"
phase3_commit="853d26e37f1471aeeaeea4e7690e1a0605a22870"
phase3_acceptance_record="docs/architecture/foundation/phase-3-authorization-decision-and-controlled-lease-acceptance.md"
phase3_acceptance_sha256="5d69bcb8bd6e1b4c97784803419d0a3029e0aea460010931eae1998742550765"
phase4_contract="docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md"
resource_contract="docs/architecture/foundation/resource-telemetry-and-performance-regression-testing-model.md"
migration="sql/schema/migrations/foundation/083_postgresql_approval_independence_and_separation_of_duties.sql"
test_file="test-framework/sql/tests/foundation/170_approval_independence_and_separation_of_duties_structure.sql"
normal_runner="test-framework/sql/schema/scripts/test_foundation.sh"
resource_runner="test-framework/sql/schema/scripts/test_foundation_with_resources.sh"
previous_validator="tools/validation/phase-gates/validate_phase4_step1.sh"
validator_file="tools/validation/phase-gates/validate_phase4_step2.sh"

step2_files=(
    "README.md"
    "docs/README.md"
    "docs/architecture/README.md"
    "docs/goals/performance-and-efficiency-goals.md"
    "docs/architecture/foundation/README.md"
    "docs/architecture/foundation/approval-framework.md"
    "docs/architecture/foundation/authority-and-authorization-model.md"
    "docs/architecture/foundation/authorization-evaluation-contract.md"
    "$phase4_contract"
    "$resource_contract"
    "docs/architecture/foundation/performance-efficiency-and-resource-governance-model.md"
    "docs/architecture/foundation/observability-health-and-operational-telemetry-model.md"
    "docs/architecture/foundation/sql-migration-map.md"
    "sql/schema/manifests/foundation.manifest"
    "$migration"
    "test-framework/sql/tests/README.md"
    "test-framework/sql/tests/foundation-tests.manifest"
    "$test_file"
    "$resource_runner"
    "tools/validation/README.md"
    "tools/validation/phase-gates/README.md"
    "$validator_file"
)

required_files=(
    "${step2_files[@]}"
    "$phase3_acceptance_record"
    "$normal_runner"
    "$previous_validator"
    "test-framework/sql/tests/foundation-concurrency-tests.manifest"
)

section "Repository identity"

printf 'Repository root: %s\n' "$repository_root"
printf 'Host: %s\n' "$(uname -n)"
printf 'Operating system: %s\n' "$(uname -s)"
printf 'Current branch: %s\n' "$(git branch --show-current)"
printf 'Current commit: %s\n' "$(git rev-parse --short=12 HEAD)"

if [[ "$(git branch --show-current)" == "dev" ]]; then
    pass "Current branch is dev"
else
    fail "Current branch must be dev"
fi

if [[ -z "$(git diff --name-only --diff-filter=U)" ]]; then
    pass "No unresolved Git conflicts"
else
    fail "Repository contains unresolved Git conflicts"
fi

section "Accepted Phase 3 boundary"

if [[ "$(git cat-file -t "refs/tags/${phase3_tag}" 2>/dev/null || true)" == "tag" ]]; then
    pass "Phase 3 acceptance tag is annotated"
else
    fail "Phase 3 acceptance tag is missing or not annotated"
fi

if [[ "$(git rev-parse "${phase3_tag}^{}" 2>/dev/null || true)" == "$phase3_commit" ]]; then
    pass "Phase 3 acceptance tag points to the accepted implementation commit"
else
    fail "Phase 3 acceptance tag points to the wrong commit"
fi

if git merge-base --is-ancestor "$phase3_commit" HEAD; then
    pass "Current Phase 4 Step 2 commit descends from accepted Phase 3"
else
    fail "Current HEAD does not descend from accepted Phase 3"
fi

if python3 - "$phase3_commit" <<'PY_BOUNDARY'
from pathlib import Path
import subprocess
import sys

accepted = sys.argv[1]

expected = sorted([
    'sql/schema/manifests/foundation.manifest',
    'sql/schema/migrations/foundation/'
    '083_postgresql_approval_independence_and_separation_of_duties.sql',
    'test-framework/sql/schema/scripts/'
    'test_foundation_with_resources.sh',
    'test-framework/sql/tests/README.md',
    'test-framework/sql/tests/foundation-tests.manifest',
    'test-framework/sql/tests/foundation/'
    '170_approval_independence_and_separation_of_duties_structure.sql',
])

completed = subprocess.run(
    [
        'git',
        'diff',
        '--name-only',
        accepted,
        '--',
        'sql/schema',
        'test-framework/sql',
    ],
    check=True,
    text=True,
    capture_output=True,
)

actual = sorted(
    line.strip()
    for line in completed.stdout.splitlines()
    if line.strip()
)

if actual != expected:
    print('ACCEPTED BOUNDARY FAIL:', file=sys.stderr)
    print(f'expected={expected}', file=sys.stderr)
    print(f'actual={actual}', file=sys.stderr)
    raise SystemExit(1)

print('ACCEPTED BOUNDARY PASS: only approved Phase 4 Step 2 SQL/test paths differ')
PY_BOUNDARY
then
    pass "Accepted Phase 3 SQL and test boundary is preserved"
else
    fail "Unexpected SQL or test content differs from accepted Phase 3"
fi

tag_message="$(git cat-file -p "refs/tags/${phase3_tag}" 2>/dev/null || true)"

for marker in \
    "33 migrations" \
    "16 sequential tests" \
    "9 concurrency tests" \
    "408 PASS" \
    "0 FAIL" \
    "3 understood WARN"
do
    if grep -Fq "$marker" <<<"$tag_message"; then
        pass "Acceptance tag message contains: $marker"
    else
        fail "Acceptance tag message is missing: $marker"
    fi
done

if [[ -f "$phase3_acceptance_record" ]]; then
    actual_acceptance_hash="$(
        sha256sum "$phase3_acceptance_record" | awk '{print $1}'
    )"

    if [[ "$actual_acceptance_hash" == "$phase3_acceptance_sha256" ]]; then
        pass "Formal Phase 3 acceptance record is unchanged"
    else
        fail "Formal Phase 3 acceptance record hash changed"
    fi
else
    fail "Formal Phase 3 acceptance record is missing"
fi

section "Required files"

for path in "${required_files[@]}"; do
    if [[ -f "$path" ]]; then
        pass "Required file exists: $path"
    else
        fail "Required file is missing: $path"
    fi
done

if (( FAIL_COUNT > 0 )); then
    printf '\nPhase 4 Step 2 validation stopped before database execution.\n' >&2
    exit 1
fi

section "Exact Phase 4 Step 2 file boundaries"

if python3 <<'PY_HASHES'
from pathlib import Path
import hashlib
import sys

checks = {
    'README.md': '0b48da313e63d459eba794c97bf95cc47f32a7148607e838644f485db123e9dc',
    'docs/README.md': '13d87cb11a84cca986e45e320241fbdc9d2d08c25a162a761efc72f6d0135303',
    'docs/architecture/README.md': '0a82d024a95fd0888399afce72a787e2cd1aa8c440e222be9001fc1dc7becb76',
    'docs/goals/performance-and-efficiency-goals.md': '22bc9f855b6e8408f9adb69d998fdfc8f02ce533b80ad64312bf1c4dc6fa5950',
    'docs/architecture/foundation/README.md': '407d77352060b68ad74e3bc8dff1fbe96e47bd31ec52ffe749445395b77ba0cd',
    'docs/architecture/foundation/approval-framework.md': '7d9888499b600ece9750ffd1bc68e5d0342ceae1cfb7322861c929b8fbc118c0',
    'docs/architecture/foundation/authority-and-authorization-model.md': 'a186b68e8ad5fbdf9e1b7fd850776309ceec6e7f513146418e205ae982ce5550',
    'docs/architecture/foundation/authorization-evaluation-contract.md': '155b6380bbb2479656d99e3ad154f8d98d3f5ae09147e55e78486df5f3391d3c',
    'docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md': 'f50182de1287a3f9e6cd9bfe4440b981e6d2325ee35766156bdad4a235303a26',
    'docs/architecture/foundation/resource-telemetry-and-performance-regression-testing-model.md': '52ee1061a533ae815ade8b7b5584f87aa4eedc023d3ea5b7f38f77eeb0b830fa',
    'docs/architecture/foundation/performance-efficiency-and-resource-governance-model.md': '52d2b55fb59a2d36b56d769c6f1bf9aec3aab3c905daf04f138d2d75d7403efb',
    'docs/architecture/foundation/observability-health-and-operational-telemetry-model.md': '6192b3f905dd8985269567120ed1bf3d654c4a45e5b15e43079fea305f824508',
    'docs/architecture/foundation/sql-migration-map.md': 'f58a6d7524378f2e7b8c7ce2945bb9a34c4d8dcd0149dea42040207a1d2fb59c',
    'sql/schema/manifests/foundation.manifest': '9a34d6a06078086ce8e0eef9b665f0d998432a5cb652fdd576f9237bb528b8bf',
    'sql/schema/migrations/foundation/083_postgresql_approval_independence_and_separation_of_duties.sql': '4818b1c6698f36b1139a4a892f219c0507c802cb7b745c56e17ebc5430094dfa',
    'test-framework/sql/tests/README.md': '594740161974729a4c1d987d31bde5666882c5aa144ff33081824e22823560e1',
    'test-framework/sql/tests/foundation-tests.manifest': '952d29dd22612e6c2660449d5257329e0687f5a67c5d45c18dc9ca1335921fa0',
    'test-framework/sql/tests/foundation/170_approval_independence_and_separation_of_duties_structure.sql': 'f205e0e91ce2010356057307b0aa765de3733f9409af25f1d837e62acf985251',
    'test-framework/sql/schema/scripts/test_foundation_with_resources.sh': 'c10179c4fd18567ec7eb1e9c958a8235edf954eac951f5f24aeb8482f45c1456',
    'tools/validation/README.md': 'd8892fc0f772ce8c57b363950c2e4ab0e47080218b87e404b09237345d56eda9',
    'tools/validation/phase-gates/README.md': '580ded603cbfd01f5cbfbd2be69b590f784f64beb0fa602adebfcd90669faa80',
}

failures = []

for raw_path, expected in checks.items():
    path = Path(raw_path)
    actual = hashlib.sha256(path.read_bytes()).hexdigest()

    if actual == expected:
        print(f'EXACT FILE PASS: {path}')
    else:
        failures.append(
            f'{path} sha256={actual} expected={expected}'
        )

if failures:
    for failure in failures:
        print(f'EXACT FILE FAIL: {failure}', file=sys.stderr)
    raise SystemExit(1)
PY_HASHES
then
    PASS_COUNT=$((PASS_COUNT + 21))
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

section "Manifest and functional-test boundaries"

if python3 <<'PY_MANIFESTS'
from pathlib import Path
import re
import sys


def entries(path: Path) -> list[str]:
    result = []

    for raw in path.read_text(encoding='utf-8').splitlines():
        line = re.sub(r'\s*#.*$', '', raw).strip()
        if line:
            result.append(line)

    return result


migration_manifest = entries(
    Path('sql/schema/manifests/foundation.manifest')
)
test_manifest = entries(
    Path('test-framework/sql/tests/foundation-tests.manifest')
)
concurrency_manifest = entries(
    Path(
        'test-framework/sql/tests/'
        'foundation-concurrency-tests.manifest'
    )
)

expected_migration = (
    'migrations/foundation/'
    '083_postgresql_approval_independence_and_separation_of_duties.sql'
)
expected_test = (
    'foundation/'
    '170_approval_independence_and_separation_of_duties_structure.sql'
)

failures = []

if len(migration_manifest) != 34:
    failures.append(
        f'manifest migrations={len(migration_manifest)} expected=34'
    )

if len(test_manifest) != 17:
    failures.append(
        f'sequential tests={len(test_manifest)} expected=17'
    )

if len(concurrency_manifest) != 9:
    failures.append(
        f'concurrency tests={len(concurrency_manifest)} expected=9'
    )

if migration_manifest.count(expected_migration) != 1:
    failures.append('migration 083 is missing or duplicated')
else:
    position = migration_manifest.index(expected_migration)
    before = migration_manifest[position - 1]
    after = migration_manifest[position + 1]

    if not before.endswith(
        '082_data_classification_and_governance.sql'
    ):
        failures.append('migration 083 does not follow migration 082')

    if not after.endswith(
        '084_lifecycle_and_historical_lineage.sql'
    ):
        failures.append('migration 083 does not precede migration 084')

if test_manifest.count(expected_test) != 1:
    failures.append('structural test 170 is missing or duplicated')
elif test_manifest[-1] != expected_test:
    failures.append('structural test 170 is not the final sequential test')

if failures:
    for failure in failures:
        print(f'MANIFEST CHECK FAIL: {failure}', file=sys.stderr)
    raise SystemExit(1)

print('MANIFEST CHECK PASS: migrations = 34')
print('MANIFEST CHECK PASS: sequential tests = 17')
print('MANIFEST CHECK PASS: concurrency tests = 9')
print('MANIFEST CHECK PASS: migration 083 and test 170 are final and ordered')
PY_MANIFESTS
then
    PASS_COUNT=$((PASS_COUNT + 4))
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

section "Migration, functional-test, and telemetry boundaries"

if python3 <<'PY_STRUCTURE'
from pathlib import Path
import re
import sys

migration = Path(
    'sql/schema/migrations/foundation/'
    '083_postgresql_approval_independence_and_separation_of_duties.sql'
).read_text(encoding='utf-8')

test = Path(
    'test-framework/sql/tests/foundation/'
    '170_approval_independence_and_separation_of_duties_structure.sql'
).read_text(encoding='utf-8')

wrapper = Path(
    'test-framework/sql/schema/scripts/'
    'test_foundation_with_resources.sh'
).read_text(encoding='utf-8')

checks = [
    (
        'Migration dependency 081',
        '081_postgresql_authorization_decision_and_lease_issuance'
        in migration,
    ),
    (
        'Migration dependency 082',
        '082_data_classification_and_governance' in migration,
    ),
    (
        'Directly affected identity structure',
        'directly_affected_identity_id' in migration,
    ),
    (
        'Approval-chain structure',
        'approval_chain_id' in migration,
    ),
    (
        'Approval Request dependency structure',
        'CREATE TABLE approval.approval_request_dependencies'
        in migration,
    ),
    (
        'Generated effective actor',
        'effective_actor_identity_id uuid' in migration
        and 'GENERATED ALWAYS AS (acting_identity_id) STORED'
        in migration,
    ),
    (
        'Acting session and Authority Grant binding',
        'acting_session_id uuid' in migration
        and 'authority_grant_id uuid' in migration,
    ),
    (
        'Typed duty catalog',
        'CREATE TABLE approval.approval_duty_definitions'
        in migration,
    ),
    (
        'Nine governed duty keys',
        sum(
            migration.count(f"('{key}'")
            for key in [
                'REQUEST',
                'APPROVE',
                'GRANT_AUTHORITY',
                'EXECUTE',
                'FINALIZE_APPROVAL',
                'ADMINISTER_POLICY',
                'AUDIT',
                'ACCEPT_RISK',
                'AUTHORIZE_EXCEPTION',
            ]
        ) == 9,
    ),
    (
        'Prohibited duty combinations',
        'approval_policy_prohibited_duty_combinations'
        in migration,
    ),
    (
        'Incompatible-authority modes',
        all(
            marker in migration
            for marker in [
                'JOINT_EXERCISE',
                'CONCURRENT_HOLDING',
                'CHAIN_PARTICIPATION',
            ]
        ),
    ),
    (
        'Persisted stage evaluation',
        'CREATE TABLE approval.approval_stage_evaluations'
        in migration
        and 'CREATE TABLE approval.approval_stage_evaluation_actions'
        in migration,
    ),
    (
        'No controlled function is claimed in Step 2',
        'CREATE FUNCTION' not in migration
        and 'CREATE OR REPLACE FUNCTION' not in migration,
    ),
    (
        'No SECURITY DEFINER in migration 083',
        'SECURITY DEFINER' not in migration,
    ),
    (
        'Migration 083 is registered',
        "p_migration_id =>\n"
        "        '083_postgresql_approval_independence_and_separation_of_duties'"
        in migration,
    ),
    (
        'Structural test contains 37 functional assertions',
        len(
            re.findall(
                r'SELECT\s+sql_test\.assert_',
                test,
                flags=re.IGNORECASE,
            )
        ) == 37,
    ),
    (
        'Structural test names migration 083',
        '083_postgresql_approval_independence_and_separation_of_duties'
        in test,
    ),
    (
        'Wrapper invokes the normal correctness runner',
        'test_foundation.sh' in wrapper
        and '--keep-database' in wrapper,
    ),
    (
        'Wrapper uses GNU time',
        '/usr/bin/time' in wrapper
        and '--verbose' in wrapper,
    ),
    (
        'Wrapper emits text and JSON resource reports',
        '-resources.txt' in wrapper
        and '-resources.json' in wrapper,
    ),
    (
        'Wrapper records separate correctness status',
        'Correctness result: PASS' in wrapper
        and 'Correctness result: FAIL' in wrapper,
    ),
    (
        'Wrapper records resource observation status',
        'Resource observation: RECORDED' in wrapper,
    ),
    (
        'Wrapper does not evaluate thresholds',
        'Performance thresholds: NOT_EVALUATED' in wrapper
        and "'performance_threshold_status': 'NOT_EVALUATED'"
        in wrapper,
    ),
    (
        'Wrapper records environment fingerprint',
        "'environment': {" in wrapper
        and "'logical_cpus':" in wrapper
        and "'installed_memory_kib':" in wrapper,
    ),
    (
        'Wrapper records process resource fields',
        "'maximum_resident_set_kib':" in wrapper
        and "'effective_cpu_percent':" in wrapper
        and "'filesystem_outputs':" in wrapper,
    ),
    (
        'Wrapper records PostgreSQL resource fields',
        "'database_size_bytes':" in wrapper
        and "'observed_cluster_wal_bytes':" in wrapper
        and "'temporary_bytes':" in wrapper
        and "'deadlocks':" in wrapper,
    ),
    (
        'Wrapper preserves correctness exit status',
        'exit "$runner_status"' in wrapper,
    ),
]

failures = []

for label, condition in checks:
    if condition:
        print(f'STRUCTURE CHECK PASS: {label}')
    else:
        failures.append(label)

if failures:
    for failure in failures:
        print(
            f'STRUCTURE CHECK FAIL: {failure}',
            file=sys.stderr,
        )
    raise SystemExit(1)
PY_STRUCTURE
then
    PASS_COUNT=$((PASS_COUNT + 27))
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

section "Documentation contract"

if python3 <<'PY_DOCUMENTATION'
from pathlib import Path
import re
import sys

checks = [
    (
        Path('README.md'),
        'Phase 4 Step 2',
    ),
    (
        Path('docs/README.md'),
        'Resource observation: RECORDED',
    ),
    (
        Path('docs/architecture/README.md'),
        'Correctness and resource observations remain distinct',
    ),
    (
        Path('docs/goals/performance-and-efficiency-goals.md'),
        'Test Baseline Translation',
    ),
    (
        Path('docs/architecture/foundation/README.md'),
        '445 PASS',
    ),
    (
        Path('docs/architecture/foundation/approval-framework.md'),
        'Phase 4 Step 2 structural extension',
    ),
    (
        Path(
            'docs/architecture/foundation/'
            'authority-and-authorization-model.md'
        ),
        'Migration `083`',
    ),
    (
        Path(
            'docs/architecture/foundation/'
            'authorization-evaluation-contract.md'
        ),
        'Phase 4 Step 2 Resource Observation',
    ),
    (
        Path(
            'docs/architecture/foundation/'
            'approval-independence-and-separation-of-duties-model.md'
        ),
        'Step 2 Acceptance Criteria',
    ),
    (
        Path(
            'docs/architecture/foundation/'
            'resource-telemetry-and-performance-regression-testing-model.md'
        ),
        'Performance thresholds: NOT_EVALUATED',
    ),
    (
        Path(
            'docs/architecture/foundation/'
            'performance-efficiency-and-resource-governance-model.md'
        ),
        'Resource-Aware Foundation Test Runs',
    ),
    (
        Path(
            'docs/architecture/foundation/'
            'observability-health-and-operational-telemetry-model.md'
        ),
        'Test Resource Observations',
    ),
    (
        Path(
            'docs/architecture/foundation/sql-migration-map.md'
        ),
        'Step 2 Structural Extension',
    ),
    (
        Path('test-framework/sql/tests/README.md'),
        'test_foundation_with_resources.sh',
    ),
    (
        Path('tools/validation/README.md'),
        'validate_phase4_step2.sh',
    ),
    (
        Path('tools/validation/phase-gates/README.md'),
        'validate_phase4_step2.sh',
    ),
]

failures = []

for path, marker in checks:
    text = path.read_text(encoding='utf-8')

    if marker in text:
        print(f'DOCUMENTATION CHECK PASS: {path}')
    else:
        failures.append(f'{path} missing marker: {marker}')

for path in [
    Path('README.md'),
    Path('docs/README.md'),
    Path('docs/architecture/README.md'),
    Path('docs/architecture/foundation/README.md'),
    Path(
        'docs/architecture/foundation/'
        'approval-independence-and-separation-of-duties-model.md'
    ),
    Path('test-framework/sql/tests/README.md'),
    Path('tools/validation/README.md'),
]:
    text = path.read_text(encoding='utf-8')

    stale = [
        'Phase 4 Step 1 — approval-independence and',
        'Step 1 changes no SQL',
        'Current checkpoint: Phase 3 Step 6',
    ]

    for marker in stale:
        if marker in text:
            failures.append(f'{path} retains stale marker: {marker}')

    if 'github.com/kb2vhn/iron-signal-platform' in text:
        failures.append(
            f'{path} contains retired personal repository URL'
        )

if failures:
    for failure in failures:
        print(
            f'DOCUMENTATION CHECK FAIL: {failure}',
            file=sys.stderr,
        )
    raise SystemExit(1)
PY_DOCUMENTATION
then
    PASS_COUNT=$((PASS_COUNT + 16))
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

section "Shell and file hygiene"

if bash -n "$normal_runner"; then
    pass "Normal Foundation correctness runner shell syntax is valid"
else
    fail "Normal Foundation correctness runner shell syntax is invalid"
fi

if bash -n "$resource_runner"; then
    pass "Resource-aware Foundation runner shell syntax is valid"
else
    fail "Resource-aware Foundation runner shell syntax is invalid"
fi

if bash -n "$previous_validator"; then
    pass "Phase 4 Step 1 validator shell syntax is valid"
else
    fail "Phase 4 Step 1 validator shell syntax is invalid"
fi

if bash -n "$validator_file"; then
    pass "Phase 4 Step 2 validator shell syntax is valid"
else
    fail "Phase 4 Step 2 validator shell syntax is invalid"
fi

if [[ -x "$resource_runner" ]]; then
    pass "Resource-aware Foundation runner is executable"
else
    fail "Resource-aware Foundation runner is not executable"
fi

if [[ -x "$validator_file" ]]; then
    pass "Phase 4 Step 2 validator is executable"
else
    fail "Phase 4 Step 2 validator is not executable"
fi

if python3 - "${step2_files[@]}" <<'PY_HYGIENE'
from pathlib import Path
import sys

failures = []

for raw in sys.argv[1:]:
    path = Path(raw)
    data = path.read_bytes()

    try:
        text = data.decode('utf-8')
    except UnicodeDecodeError as exc:
        failures.append(f'{path} invalid UTF-8: {exc}')
        continue

    if b'\r\n' in data:
        failures.append(f'{path} has CRLF line endings')

    if not data.endswith(b'\n'):
        failures.append(f'{path} lacks one EOF newline')
    elif data.endswith(b'\n\n'):
        failures.append(f'{path} has an extra blank line at EOF')

    for number, line in enumerate(text.splitlines(), 1):
        if line.endswith((' ', '\t')):
            failures.append(f'{path}:{number} trailing whitespace')

        if line.startswith(
            ('<<<<<<<', '=======', '>>>>>>>')
        ):
            failures.append(f'{path}:{number} conflict marker')

if failures:
    for failure in failures:
        print(f'FILE HYGIENE FAIL: {failure}', file=sys.stderr)
    raise SystemExit(1)

print('FILE HYGIENE PASS: Phase 4 Step 2 files are clean UTF-8 text')
PY_HYGIENE
then
    pass "All Phase 4 Step 2-owned files pass direct hygiene checks"
else
    fail "A Phase 4 Step 2 file failed direct hygiene checks"
fi

if git diff --check -- "${step2_files[@]}" >/dev/null; then
    pass "Phase 4 Step 2 project files pass git diff --check"
else
    fail "Phase 4 Step 2 project files fail git diff --check"
fi

section "Static result"

printf 'PASS checks: %d\n' "$PASS_COUNT"
printf 'FAIL checks: %d\n' "$FAIL_COUNT"

if (( FAIL_COUNT > 0 )); then
    printf '\nPhase 4 Step 2 static validation FAILED.\n' >&2
    printf 'No PostgreSQL test was started.\n' >&2
    exit 1
fi

printf '\nPhase 4 Step 2 static validation PASSED.\n'

if (( STATIC_ONLY == 1 )); then
    printf 'PostgreSQL and resource execution were skipped by --static-only.\n'
    exit 0
fi

section "Complete Foundation correctness and resource suite"

"$resource_runner" \
    --label "phase4-step2-${HOSTNAME:-unknown}"

summary="test-framework/sql/test-results/latest-summary.txt"
resources="test-framework/sql/test-results/latest-resources.json"

if [[ ! -f "$summary" ]]; then
    printf 'Resource-aware runner did not create %s\n' "$summary" >&2
    exit 1
fi

if [[ ! -f "$resources" ]]; then
    printf 'Resource-aware runner did not create %s\n' "$resources" >&2
    exit 1
fi

if python3 - "$summary" <<'PY_SUMMARY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding='utf-8')
failures = []

checks = {
    'Overall result': r'(?m)^Overall result:[ \t]+PASS[ \t]*$',
    'Runner exit status': (
        r'(?m)^Runner exit status:[ \t]+0[ \t]*$'
    ),
    'Sequential test files': (
        r'(?m)^Sequential test files:[ \t]+17[ \t]*$'
    ),
    'Concurrency test files': (
        r'(?m)^Concurrency test files:[ \t]+9[ \t]*$'
    ),
}

for label, pattern in checks.items():
    if re.search(pattern, text) is None:
        failures.append(f'incorrect {label}')

result_section = re.search(
    r'Result[ ]totals(?P<section>.*?)Failed[ ]assertions',
    text,
    re.DOTALL,
)

if result_section is None:
    failures.append('missing Result totals')
else:
    expected = {'PASS': 445, 'WARN': 3, 'FAIL': 0}

    for result, expected_count in expected.items():
        match = re.search(
            rf'\|[ \t]*{result}[ \t]*\|[ \t]*(\d+)[ \t]*\|',
            result_section.group('section'),
        )

        actual = (
            0
            if match is None and result == 'FAIL'
            else (
                None
                if match is None
                else int(match.group(1))
            )
        )

        if actual != expected_count:
            failures.append(
                f'{result}={actual} expected={expected_count}'
            )

migration_section = re.search(
    r'Migration[ ]totals(?P<section>.*)',
    text,
    re.DOTALL,
)

if migration_section is None:
    failures.append('missing Migration totals')
else:
    match = re.search(
        r'\|[ \t]*(\d+)[ \t]*\|[ \t]*(\d+)[ \t]*\|',
        migration_section.group('section'),
    )

    if (
        match is None
        or (
            int(match.group(1)),
            int(match.group(2)),
        ) != (34, 34)
    ):
        failures.append(
            'manifest or registered migration count is not 34'
        )

if failures:
    for failure in failures:
        print(
            f'SUMMARY CHECK FAIL: {failure}',
            file=sys.stderr,
        )
    raise SystemExit(1)

for line in [
    'Overall result = PASS',
    'Runner exit status = 0',
    'Sequential test files = 17',
    'Concurrency test files = 9',
    'PASS = 445',
    'FAIL = 0',
    'WARN = 3',
    'Manifest migrations = 34',
    'Registered migrations = 34',
]:
    print(f'SUMMARY CHECK PASS: {line}')
PY_SUMMARY
then
    PASS_COUNT=$((PASS_COUNT + 9))
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

if python3 - "$summary" "$resources" <<'PY_RESOURCES'
from pathlib import Path
import json
import re
import sys

summary_text = Path(sys.argv[1]).read_text(encoding='utf-8')
resource_path = Path(sys.argv[2])
record = json.loads(resource_path.read_text(encoding='utf-8'))

run_match = re.search(
    r'(?m)^Run ID:[ \t]+(.+?)[ \t]*$',
    summary_text,
)

failures = []

if run_match is None:
    failures.append('summary Run ID is missing')
else:
    summary_run_id = run_match.group(1)

    if record.get('run_id') != summary_run_id:
        failures.append(
            'resource Run ID does not match correctness summary'
        )

correctness = record.get('correctness', {})
observation = record.get('resource_observation', {})
environment = record.get('environment', {})
timing = record.get('timing', {})
process_tree = record.get('process_tree', {})
postgresql = record.get('postgresql', {})

if correctness.get('overall_result') != 'PASS':
    failures.append('resource record correctness result is not PASS')

if correctness.get('runner_exit_status') != 0:
    failures.append('resource record runner exit status is not zero')

if observation.get('status') != 'RECORDED':
    failures.append('resource observation status is not RECORDED')

if (
    observation.get('performance_threshold_status')
    != 'NOT_EVALUATED'
):
    failures.append(
        'performance threshold status is not NOT_EVALUATED'
    )

if not environment.get('host'):
    failures.append('environment host is missing')

if not environment.get('kernel'):
    failures.append('environment kernel is missing')

if (environment.get('logical_cpus') or 0) < 1:
    failures.append('logical CPU count is invalid')

if (environment.get('installed_memory_kib') or 0) <= 0:
    failures.append('installed memory is invalid')

if (environment.get('postgresql_version_num') or 0) < 180000:
    failures.append('PostgreSQL version number is invalid')

if not environment.get('postgresql_role'):
    failures.append('PostgreSQL role is missing')

if (
    timing.get('correctness_runner_elapsed_seconds') or 0
) <= 0:
    failures.append('correctness runner elapsed time is not positive')

for field in [
    'resource_collection_elapsed_seconds',
    'migration_and_database_setup_seconds',
    'sequential_tests_seconds',
    'concurrency_tests_seconds',
    'result_finalization_seconds',
]:
    value = timing.get(field)
    if value is None or value < 0:
        failures.append(f'timing field is invalid: {field}')

cpu_total = (
    (process_tree.get('user_cpu_seconds') or 0)
    + (process_tree.get('system_cpu_seconds') or 0)
)

if cpu_total <= 0:
    failures.append('observed CPU time is not positive')

if (
    process_tree.get('maximum_resident_set_kib') or 0
) <= 0:
    failures.append('peak resident memory is not positive')

for field in [
    'major_page_faults',
    'minor_page_faults',
    'filesystem_inputs',
    'filesystem_outputs',
    'voluntary_context_switches',
    'involuntary_context_switches',
]:
    value = process_tree.get(field)
    if value is None or value < 0:
        failures.append(
            f'process resource field is invalid: {field}'
        )

if not postgresql.get(
    'database_retained_during_observation'
):
    failures.append(
        'database was not retained during resource observation'
    )

if (postgresql.get('database_size_bytes') or 0) <= 0:
    failures.append('database size is not positive')

if (
    postgresql.get('observed_cluster_wal_bytes') is None
    or postgresql.get('observed_cluster_wal_bytes') < 0
):
    failures.append('observed WAL value is invalid')

for field in [
    'xact_commit',
    'xact_rollback',
    'blocks_read',
    'blocks_hit',
    'temporary_files',
    'temporary_bytes',
    'deadlocks',
    'tuples_returned',
    'tuples_fetched',
    'tuples_inserted',
    'tuples_updated',
    'tuples_deleted',
]:
    value = postgresql.get(field)
    if value is None or value < 0:
        failures.append(
            f'PostgreSQL resource field is invalid: {field}'
        )

if postgresql.get('deadlocks') != 0:
    failures.append('resource observation contains a deadlock')

if failures:
    for failure in failures:
        print(
            f'RESOURCE CHECK FAIL: {failure}',
            file=sys.stderr,
        )
    raise SystemExit(1)

for line in [
    'Run ID matches correctness summary',
    'Correctness result = PASS',
    'Runner exit status = 0',
    'Resource observation = RECORDED',
    'Performance thresholds = NOT_EVALUATED',
    'Environment fingerprint is complete',
    'Timing fields are present',
    'CPU and memory fields are positive',
    'I/O counters are nonnegative',
    'PostgreSQL fields are present',
    'Database size and WAL fields are valid',
    'Deadlocks = 0',
]:
    print(f'RESOURCE CHECK PASS: {line}')
PY_RESOURCES
then
    PASS_COUNT=$((PASS_COUNT + 12))
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

section "Final result"

printf 'PASS checks: %d\n' "$PASS_COUNT"
printf 'FAIL checks: %d\n' "$FAIL_COUNT"

if (( FAIL_COUNT > 0 )); then
    printf '\nPhase 4 Step 2 validation FAILED.\n' >&2
    printf 'Correctness summary: %s\n' "$summary" >&2
    printf 'Resource observation: %s\n' "$resources" >&2
    exit 1
fi

printf '\nPhase 4 Step 2 validation PASSED completely.\n'
printf 'Approval-independence structure and baseline resource telemetry are ready for Phase 4 Step 3 controlled Approval Action work.\n'
