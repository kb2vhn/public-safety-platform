#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

STATIC_ONLY=0
PASS_COUNT=0
FAIL_COUNT=0

usage() {
    cat <<'EOF'
Usage: tools/validation/phase-gates/validate_phase4_step3.sh [--static-only]

Default:
  Validate Phase 4 Step 3 controlled Approval Action recording, run the
  complete Foundation correctness suite through the resource-aware wrapper,
  and verify that correctness and resource observations remain separate.

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
    awk basename bash cat createdb date dirname dropdb git grep ln mkdir
    mktemp nproc psql python3 rm sed sha256sum sleep tail tee uname
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

pass "All required Phase 4 Step 3 commands are available"

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
structural_test="test-framework/sql/tests/foundation/170_approval_independence_and_separation_of_duties_structure.sql"
behavior_test="test-framework/sql/tests/foundation/180_controlled_approval_action_recording.sql"
normal_runner="test-framework/sql/schema/scripts/test_foundation.sh"
resource_runner="test-framework/sql/schema/scripts/test_foundation_with_resources.sh"
previous_validator="tools/validation/phase-gates/validate_phase4_step2.sh"
validator_file="tools/validation/phase-gates/validate_phase4_step3.sh"

step3_files=(
    "README.md"
    "docs/README.md"
    "docs/architecture/README.md"
    "docs/architecture/foundation/README.md"
    "docs/architecture/foundation/approval-framework.md"
    "docs/architecture/foundation/authority-and-authorization-model.md"
    "docs/architecture/foundation/authorization-evaluation-contract.md"
    "docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md"
    "docs/architecture/foundation/resource-telemetry-and-performance-regression-testing-model.md"
    "docs/architecture/foundation/sql-migration-map.md"
    "sql/schema/manifests/foundation.manifest"
    "sql/schema/migrations/foundation/083_postgresql_approval_independence_and_separation_of_duties.sql"
    "test-framework/sql/tests/README.md"
    "test-framework/sql/tests/foundation-tests.manifest"
    "test-framework/sql/tests/foundation/170_approval_independence_and_separation_of_duties_structure.sql"
    "test-framework/sql/tests/foundation/180_controlled_approval_action_recording.sql"
    "test-framework/sql/schema/scripts/test_foundation_with_resources.sh"
    "tools/validation/README.md"
    "tools/validation/phase-gates/README.md"
    "tools/validation/phase-gates/validate_phase4_step3.sh"
)

required_files=(
    "${step3_files[@]}"
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
    pass "Current Phase 4 Step 3 commit descends from accepted Phase 3"
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
    'test-framework/sql/tests/foundation/'
    '180_controlled_approval_action_recording.sql',
])

completed = subprocess.run(
    [
        'git', 'diff', '--name-only', accepted, '--',
        'sql/schema', 'test-framework/sql',
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

print('ACCEPTED BOUNDARY PASS: only approved Phase 4 Step 3 SQL/test paths differ')
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
    printf '\nPhase 4 Step 3 validation stopped before database execution.\n' >&2
    exit 1
fi

section "Exact Phase 4 Step 3 file boundaries"

if python3 <<'PY_HASHES'
from pathlib import Path
import hashlib
import sys

checks = {
    'README.md': '9ef5662a08bc21b07a28dc76cb6ce9257a4ded7380f016c3caa2c5ff43ec26c8',
    'docs/README.md': '2bcc33e2ab00ab5875e2d898c8a243c460fef15e3fc253cb33bce247bbb637ae',
    'docs/architecture/README.md': '154e44eb507506448bc8043d7f08204784d0c4fda6496ad2cb5027f8212dce81',
    'docs/architecture/foundation/README.md': '93383a8eedd87be9437d48ed0a16e0ae902f2b2b779adcb2ae13de4b55bae38f',
    'docs/architecture/foundation/approval-framework.md': '49581f64fe5e1639a9a55e9b4bc28976bcaee62e0720324063b75f9838c32deb',
    'docs/architecture/foundation/authority-and-authorization-model.md': 'ff9fb3e4f4bb1b9bd6031848d06f97118c00f0eb40078e16a5757d47378c9e73',
    'docs/architecture/foundation/authorization-evaluation-contract.md': '5c84c5d753ba4cb9ea3e65be990483d211f34bceef934f781f3ead5e3d64d4af',
    'docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md': '8536aa4d56c38c38a83b991ee08467ae76c0ab0257254bfeb322e66e13ecfed9',
    'docs/architecture/foundation/resource-telemetry-and-performance-regression-testing-model.md': 'aa9fd612f208c4ac676fb3e275eae50e02b35ae606eab75a843ec5bc201d1c67',
    'docs/architecture/foundation/sql-migration-map.md': 'dc2a23387af7ea36494db61f339242b345c3cdc48172b7470dda6cd2e00a3b5c',
    'sql/schema/manifests/foundation.manifest': '9a34d6a06078086ce8e0eef9b665f0d998432a5cb652fdd576f9237bb528b8bf',
    'sql/schema/migrations/foundation/083_postgresql_approval_independence_and_separation_of_duties.sql': '10c46cf6fc507cec505eb6309592e88d8af3bc2b27e28706fdfdb649f2c09fb7',
    'test-framework/sql/tests/README.md': 'ef6913ca9285f79f13b133280fdb2638fd66ae4b19c0f52c3acd1ae5e7d4a36d',
    'test-framework/sql/tests/foundation-tests.manifest': 'a97a42df60dbdf758d0099089151f1f97658474911c2f7d413f973c6e37009ee',
    'test-framework/sql/tests/foundation/170_approval_independence_and_separation_of_duties_structure.sql': 'f205e0e91ce2010356057307b0aa765de3733f9409af25f1d837e62acf985251',
    'test-framework/sql/tests/foundation/180_controlled_approval_action_recording.sql': '07d58e5c762cafd06c3c392bd6959e2628ca2f39dd459f50227a80c2e401edcf',
    'test-framework/sql/schema/scripts/test_foundation_with_resources.sh': 'c10179c4fd18567ec7eb1e9c958a8235edf954eac951f5f24aeb8482f45c1456',
    'tools/validation/README.md': '378958fb890ed447ef91d5d9d80a62f786d79399c26fee6061782ae57c8dfba3',
    'tools/validation/phase-gates/README.md': '9e7274261eb48b5f5f227766c3b9ba97b02a1dbe8b7b66d35619a9a3fb2a1d9a',
}

failures = []
for raw_path, expected in checks.items():
    path = Path(raw_path)
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    if actual == expected:
        print(f'EXACT FILE PASS: {path}')
    else:
        failures.append(f'{path} sha256={actual} expected={expected}')

if failures:
    for failure in failures:
        print(f'EXACT FILE FAIL: {failure}', file=sys.stderr)
    raise SystemExit(1)
PY_HASHES
then
    PASS_COUNT=$((PASS_COUNT + 19))
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

migration_manifest = entries(Path('sql/schema/manifests/foundation.manifest'))
test_manifest = entries(Path('test-framework/sql/tests/foundation-tests.manifest'))
concurrency_manifest = entries(Path('test-framework/sql/tests/foundation-concurrency-tests.manifest'))

expected_migration = (
    'migrations/foundation/'
    '083_postgresql_approval_independence_and_separation_of_duties.sql'
)
structural_test = (
    'foundation/'
    '170_approval_independence_and_separation_of_duties_structure.sql'
)
behavior_test = 'foundation/180_controlled_approval_action_recording.sql'
failures = []

if len(migration_manifest) != 34:
    failures.append(f'manifest migrations={len(migration_manifest)} expected=34')
if len(test_manifest) != 18:
    failures.append(f'sequential tests={len(test_manifest)} expected=18')
if len(concurrency_manifest) != 9:
    failures.append(f'concurrency tests={len(concurrency_manifest)} expected=9')

if migration_manifest.count(expected_migration) != 1:
    failures.append('migration 083 is missing or duplicated')
else:
    position = migration_manifest.index(expected_migration)
    if not migration_manifest[position - 1].endswith(
        '082_data_classification_and_governance.sql'
    ):
        failures.append('migration 083 does not follow migration 082')
    if not migration_manifest[position + 1].endswith(
        '084_lifecycle_and_historical_lineage.sql'
    ):
        failures.append('migration 083 does not precede migration 084')

if test_manifest[-2:] != [structural_test, behavior_test]:
    failures.append('tests 170 and 180 are not final and ordered')

if failures:
    for failure in failures:
        print(f'MANIFEST CHECK FAIL: {failure}', file=sys.stderr)
    raise SystemExit(1)

print('MANIFEST CHECK PASS: migrations = 34')
print('MANIFEST CHECK PASS: sequential tests = 18')
print('MANIFEST CHECK PASS: concurrency tests = 9')
print('MANIFEST CHECK PASS: migration 083 and tests 170/180 are ordered')
print('MANIFEST CHECK PASS: accepted concurrency manifest is unchanged')
PY_MANIFESTS
then
    PASS_COUNT=$((PASS_COUNT + 5))
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

section "Controlled action, functional-test, and telemetry boundaries"

if python3 <<'PY_STRUCTURE'
from pathlib import Path
import re
import sys

migration = Path(
    'sql/schema/migrations/foundation/'
    '083_postgresql_approval_independence_and_separation_of_duties.sql'
).read_text(encoding='utf-8')
structural = Path(
    'test-framework/sql/tests/foundation/'
    '170_approval_independence_and_separation_of_duties_structure.sql'
).read_text(encoding='utf-8')
behavior = Path(
    'test-framework/sql/tests/foundation/'
    '180_controlled_approval_action_recording.sql'
).read_text(encoding='utf-8')
wrapper = Path(
    'test-framework/sql/schema/scripts/'
    'test_foundation_with_resources.sh'
).read_text(encoding='utf-8')

checks = [
    ('Migration dependency 081', '081_postgresql_authorization_decision_and_lease_issuance' in migration),
    ('Migration dependency 082', '082_data_classification_and_governance' in migration),
    ('Controlled function exists', 'CREATE FUNCTION approval.record_approval_action(' in migration),
    ('Controlled function returns typed outcome', "'RECORDED'::text" in migration and "'APPROVAL_ACTION_RECORDED'::text" in migration),
    ('Controlled function captures statement time', 'v_now timestamptz := statement_timestamp()' in migration),
    ('Request row is locked', 'FROM approval.approval_requests AS request_record' in migration and 'FOR UPDATE;' in migration),
    ('Pending request is required', "v_request.status <> 'PENDING'" in migration),
    ('Request expiration is enforced', 'APPROVAL_REQUEST_EXPIRED' in migration),
    ('Active policy validity is enforced', 'APPROVAL_POLICY_NOT_ACTIVE' in migration),
    ('Exact policy stage is enforced', 'APPROVAL_STAGE_NOT_FOUND' in migration),
    ('Active actor validity is enforced', 'APPROVER_NOT_ELIGIBLE' in migration),
    ('Acting session is required', 'APPROVER_SESSION_REQUIRED' in migration),
    ('Session identity is bound', 'v_session.identity_id <> p_acting_identity_id' in migration),
    ('Session organization is bound', 'v_session.organization_id IS DISTINCT FROM' in migration),
    ('Session service is bound', 'v_session.service_id IS DISTINCT FROM v_request.service_id' in migration),
    ('Local session trust predicate is used', 'session_context_is_locally_usable' in migration),
    ('Typed Authority Definition is required', 'v_stage.required_authority_definition_id IS NULL' in migration),
    ('Authority Grant identity is bound', 'v_authority_grant.identity_id <> p_acting_identity_id' in migration),
    ('Authority Definition is bound', 'v_authority_grant.authority_definition_id <>' in migration),
    ('Authority Grant effective state is checked', "v_authority_grant.status <> 'ACTIVE'" in migration),
    ('Authority Grant service is checked', 'v_authority_grant.service_id = v_request.service_id' in migration),
    ('Authority Grant purpose is checked', 'v_authority_grant.purpose_definition_id =' in migration),
    ('Authority Grant operation is checked', 'v_authority_grant.operation_definition_id =' in migration),
    ('Authority Grant organization is checked', 'v_authority_grant.organization_id IS NOT DISTINCT FROM' in migration),
    ('Deprecated scope reference is denied', 'v_authority_grant.scope_reference IS NOT NULL' in migration),
    ('Governed Scope is checked', 'v_authority_grant.governed_scope_id IS NOT DISTINCT FROM' in migration),
    ('Protected target is checked', 'v_authority_grant.protected_target_reference' in migration),
    ('Typed prior action is required for lineage actions', 'APPROVAL_ACTION_PRIOR_REQUIRED' in migration),
    ('Primary actions reject prior links', 'APPROVAL_ACTION_PRIOR_NOT_ALLOWED' in migration),
    ('Prior request stage and actor are checked', all(marker in migration for marker in ['v_prior_action.approval_request_id <>', 'v_prior_action.approval_policy_stage_id <>', 'v_prior_action.effective_actor_identity_id <>'])),
    ('Withdrawal requires prior APPROVE', 'APPROVAL_WITHDRAWAL_NOT_ALLOWED' in migration),
    ('Prior action cannot be consumed twice', 'later_action.prior_approval_action_id' in migration),
    ('Approval Action mutation guard exists', 'CREATE FUNCTION approval.prevent_approval_action_record_mutation()' in migration),
    ('Approval Action append-only trigger exists', 'approval_actions_append_only_guard' in migration),
    ('Approval Action duty append-only trigger exists', 'approval_action_duties_append_only_guard' in migration),
    ('Controlled function is invoker rights', 'SECURITY DEFINER' not in migration),
    ('Controlled function has fixed search path', 'SET search_path = pg_catalog, approval, access_control' in migration),
    ('Controlled function is revoked from PUBLIC', 'REVOKE ALL ON FUNCTION approval.record_approval_action(' in migration),
    ('Structural test retains 37 assertions', len(re.findall(r'SELECT\s+sql_test\.assert_', structural, flags=re.I)) == 37),
    ('Behavior test contains 55 assertions', len(re.findall(r'SELECT\s+sql_test\.assert_', behavior, flags=re.I)) == 55),
    ('Behavior test covers successful APPROVE', 'Valid controlled APPROVE action returns RECORDED' in behavior),
    ('Behavior test covers context substitution', 'session-to-identity substitution' in behavior and 'Authority Grant for another identity' in behavior),
    ('Behavior test covers typed lineage', 'Valid withdrawal creates a new Approval Action Record' in behavior and 'Valid correction creates a new attributable' in behavior and 'Valid supersession creates a new attributable' in behavior),
    ('Behavior test covers mutation denial', 'Approval Action Records reject UPDATE' in behavior and 'Approval Action Records reject DELETE' in behavior),
    ('Step 3 does not claim duty enforcement', 'does not yet claim duty-combination enforcement' in behavior),
    ('Resource wrapper invokes normal correctness runner', 'test_foundation.sh' in wrapper and '--keep-database' in wrapper),
    ('Resource wrapper emits text and JSON', '-resources.txt' in wrapper and '-resources.json' in wrapper),
    ('Resource thresholds remain unevaluated', 'Performance thresholds: NOT_EVALUATED' in wrapper and "'performance_threshold_status': 'NOT_EVALUATED'" in wrapper),
    ('Resource wrapper preserves correctness status', 'exit "$runner_status"' in wrapper),
]

failures = []
for label, condition in checks:
    if condition:
        print(f'STRUCTURE CHECK PASS: {label}')
    else:
        failures.append(label)

if failures:
    for failure in failures:
        print(f'STRUCTURE CHECK FAIL: {failure}', file=sys.stderr)
    raise SystemExit(1)
PY_STRUCTURE
then
    PASS_COUNT=$((PASS_COUNT + 49))
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

section "Documentation contract"

if python3 <<'PY_DOCUMENTATION'
from pathlib import Path
import sys

checks = [
    (Path('README.md'), 'Phase 4 Step 3'),
    (Path('README.md'), '500 PASS'),
    (Path('README.md'), 'Build software that is secure, understandable, observable, and dependable enough that I would trust my own local community to rely on it during an emergency.'),
    (Path('README.md'), 'Built on purpose. Backed by discipline. Engineered to endure.'),
    (Path('README.md'), 'README Preservation Rule'),
    (Path('docs/README.md'), 'Active Phase 4 Step 3'),
    (Path('docs/architecture/README.md'), 'controlled Approval Action write boundary'),
    (Path('docs/architecture/foundation/README.md'), 'Current Phase 4 Boundary'),
    (Path('docs/architecture/foundation/README.md'), '180_controlled_approval_action_recording.sql'),
    (Path('docs/architecture/foundation/approval-framework.md'), 'approval.record_approval_action'),
    (Path('docs/architecture/foundation/authority-and-authorization-model.md'), 'controlled current'),
    (Path('docs/architecture/foundation/authorization-evaluation-contract.md'), 'Phase 4 Step 3 Controlled Approval Action Recording'),
    (Path('docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md'), 'Step 3 Acceptance Criteria'),
    (Path('docs/architecture/foundation/resource-telemetry-and-performance-regression-testing-model.md'), 'Phase 4 Step 3 Integration'),
    (Path('docs/architecture/foundation/sql-migration-map.md'), 'Phase 4 Step 3 Controlled Approval Action Recording'),
    (Path('test-framework/sql/tests/README.md'), 'Current checkpoint:** Phase 4 Step 3'),
    (Path('tools/validation/README.md'), 'validate_phase4_step3.sh'),
    (Path('tools/validation/phase-gates/README.md'), 'validate_phase4_step3.sh'),
]

required_readme_sections = [
    '## Project Mission',
    '## Platform Scope and Long-Term Direction',
    '## Initial Operational Direction',
    '## Current Development Stage',
    '## Staged Development Approach',
    '## Core Principles',
    '## Platform Layers',
    '## Platform Foundation Scope',
    '## Current Implementation Boundaries',
    '## Migration Ranges',
    '## Repository Layout',
    '## Documentation',
    '## SQL Foundation',
    '## SQL Test Framework',
    '## Definition of Progress',
    '## Production Readiness',
    '## Final Goal',
]

failures=[]
for path, marker in checks:
    document=path.read_text(encoding='utf-8')
    if marker in document:
        print(f'DOCUMENTATION CHECK PASS: {path}')
    else:
        failures.append(f'{path} missing marker: {marker}')

readme_text = Path('README.md').read_text(encoding='utf-8')
for marker in required_readme_sections:
    if marker in readme_text:
        print(f'README PRESERVATION PASS: {marker}')
    else:
        failures.append(f'README.md missing preserved section: {marker}')

readme_word_count = len(readme_text.split())
if readme_word_count >= 2400:
    print(f'README PRESERVATION PASS: substantive word count = {readme_word_count}')
else:
    failures.append(
        f'README.md is too short: words={readme_word_count} minimum=2400'
    )

active_paths=[
    Path('README.md'), Path('docs/README.md'), Path('docs/architecture/README.md'),
    Path('docs/architecture/foundation/README.md'),
    Path('test-framework/sql/tests/README.md'),
    Path('tools/validation/README.md'),
]
for path in active_paths:
    text=path.read_text(encoding='utf-8')
    for marker in ['Current checkpoint:** Phase 4 Step 2', 'Run the active Phase 4 Step 2 gate:', 'Active Phase 4 Step 2']:
        if marker in text:
            failures.append(f'{path} retains stale active marker: {marker}')
    if 'github.com/kb2vhn/iron-signal-platform' in text:
        failures.append(f'{path} contains retired personal repository URL')

if failures:
    for failure in failures:
        print(f'DOCUMENTATION CHECK FAIL: {failure}', file=sys.stderr)
    raise SystemExit(1)
PY_DOCUMENTATION
then
    PASS_COUNT=$((PASS_COUNT + 36))
else
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

section "Shell and file hygiene"

if bash -n "$normal_runner"; then pass "Normal Foundation correctness runner shell syntax is valid"; else fail "Normal Foundation correctness runner shell syntax is invalid"; fi
if bash -n "$resource_runner"; then pass "Resource-aware Foundation runner shell syntax is valid"; else fail "Resource-aware Foundation runner shell syntax is invalid"; fi
if bash -n "$previous_validator"; then pass "Phase 4 Step 2 validator shell syntax is valid"; else fail "Phase 4 Step 2 validator shell syntax is invalid"; fi
if bash -n "$validator_file"; then pass "Phase 4 Step 3 validator shell syntax is valid"; else fail "Phase 4 Step 3 validator shell syntax is invalid"; fi
if [[ -x "$resource_runner" ]]; then pass "Resource-aware Foundation runner is executable"; else fail "Resource-aware Foundation runner is not executable"; fi
if [[ -x "$validator_file" ]]; then pass "Phase 4 Step 3 validator is executable"; else fail "Phase 4 Step 3 validator is not executable"; fi

if python3 - "${step3_files[@]}" <<'PY_HYGIENE'
from pathlib import Path
import sys
failures=[]
for raw in sys.argv[1:]:
    path=Path(raw)
    data=path.read_bytes()
    try:
        text=data.decode('utf-8')
    except UnicodeDecodeError as exc:
        failures.append(f'{path} invalid UTF-8: {exc}')
        continue
    if b'\r\n' in data:
        failures.append(f'{path} has CRLF line endings')
    if not data.endswith(b'\n'):
        failures.append(f'{path} lacks one EOF newline')
    elif data.endswith(b'\n\n'):
        failures.append(f'{path} has an extra blank line at EOF')
    for number,line in enumerate(text.splitlines(),1):
        if line.endswith((' ','\t')):
            failures.append(f'{path}:{number} trailing whitespace')
        if line.startswith(('<<<<<<<','=======','>>>>>>>')):
            failures.append(f'{path}:{number} conflict marker')
if failures:
    for failure in failures:
        print(f'FILE HYGIENE FAIL: {failure}', file=sys.stderr)
    raise SystemExit(1)
print('FILE HYGIENE PASS: Phase 4 Step 3 files are clean UTF-8 text')
PY_HYGIENE
then
    pass "All Phase 4 Step 3-owned files pass direct hygiene checks"
else
    fail "A Phase 4 Step 3 file failed direct hygiene checks"
fi

if git diff --check -- "${step3_files[@]}" >/dev/null; then
    pass "Phase 4 Step 3 project files pass git diff --check"
else
    fail "Phase 4 Step 3 project files fail git diff --check"
fi

section "Static result"
printf 'PASS checks: %d\n' "$PASS_COUNT"
printf 'FAIL checks: %d\n' "$FAIL_COUNT"

if (( FAIL_COUNT > 0 )); then
    printf '\nPhase 4 Step 3 static validation FAILED.\n' >&2
    printf 'No PostgreSQL test was started.\n' >&2
    exit 1
fi

printf '\nPhase 4 Step 3 static validation PASSED.\n'

if (( STATIC_ONLY == 1 )); then
    printf 'PostgreSQL and resource execution were skipped by --static-only.\n'
    exit 0
fi

section "Complete Foundation correctness and resource suite"

"$resource_runner" --label "phase4-step3-${HOSTNAME:-unknown}"

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
text=Path(sys.argv[1]).read_text(encoding='utf-8')
failures=[]
checks={
    'Overall result': r'(?m)^Overall result:[ \t]+PASS[ \t]*$',
    'Runner exit status': r'(?m)^Runner exit status:[ \t]+0[ \t]*$',
    'Sequential test files': r'(?m)^Sequential test files:[ \t]+18[ \t]*$',
    'Concurrency test files': r'(?m)^Concurrency test files:[ \t]+9[ \t]*$',
}
for label,pattern in checks.items():
    if re.search(pattern,text) is None:
        failures.append(f'incorrect {label}')
result_section=re.search(r'Result[ ]totals(?P<section>.*?)Failed[ ]assertions',text,re.DOTALL)
if result_section is None:
    failures.append('missing Result totals')
else:
    expected={'PASS':500,'WARN':3,'FAIL':0}
    for result,expected_count in expected.items():
        match=re.search(rf'\|[ \t]*{result}[ \t]*\|[ \t]*(\d+)[ \t]*\|',result_section.group('section'))
        actual=0 if match is None and result=='FAIL' else (None if match is None else int(match.group(1)))
        if actual != expected_count:
            failures.append(f'{result}={actual} expected={expected_count}')
migration_section=re.search(r'Migration[ ]totals(?P<section>.*)',text,re.DOTALL)
if migration_section is None:
    failures.append('missing Migration totals')
else:
    match=re.search(r'\|[ \t]*(\d+)[ \t]*\|[ \t]*(\d+)[ \t]*\|',migration_section.group('section'))
    if match is None or (int(match.group(1)),int(match.group(2))) != (34,34):
        failures.append('manifest or registered migration count is not 34')
if failures:
    for failure in failures:
        print(f'SUMMARY CHECK FAIL: {failure}',file=sys.stderr)
    raise SystemExit(1)
for line in [
    'Overall result = PASS','Runner exit status = 0','Sequential test files = 18',
    'Concurrency test files = 9','PASS = 500','FAIL = 0','WARN = 3',
    'Manifest migrations = 34','Registered migrations = 34',
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
import json,re,sys
summary_text=Path(sys.argv[1]).read_text(encoding='utf-8')
record=json.loads(Path(sys.argv[2]).read_text(encoding='utf-8'))
run_match=re.search(r'(?m)^Run ID:[ \t]+(.+?)[ \t]*$',summary_text)
failures=[]
if run_match is None:
    failures.append('summary Run ID is missing')
elif record.get('run_id') != run_match.group(1):
    failures.append('resource Run ID does not match correctness summary')
correctness=record.get('correctness',{})
observation=record.get('resource_observation',{})
environment=record.get('environment',{})
timing=record.get('timing',{})
process_tree=record.get('process_tree',{})
postgresql=record.get('postgresql',{})
if correctness.get('overall_result')!='PASS': failures.append('resource record correctness result is not PASS')
if correctness.get('runner_exit_status')!=0: failures.append('resource record runner exit status is not zero')
if observation.get('status')!='RECORDED': failures.append('resource observation status is not RECORDED')
if observation.get('performance_threshold_status')!='NOT_EVALUATED': failures.append('performance threshold status is not NOT_EVALUATED')
if not environment.get('host'): failures.append('environment host is missing')
if not environment.get('kernel'): failures.append('environment kernel is missing')
if (environment.get('logical_cpus') or 0)<1: failures.append('logical CPU count is invalid')
if (environment.get('installed_memory_kib') or 0)<=0: failures.append('installed memory is invalid')
if (environment.get('postgresql_version_num') or 0)<180000: failures.append('PostgreSQL version number is invalid')
if not environment.get('postgresql_role'): failures.append('PostgreSQL role is missing')
if (timing.get('correctness_runner_elapsed_seconds') or 0)<=0: failures.append('correctness runner elapsed time is not positive')
for field in ['resource_collection_elapsed_seconds','migration_and_database_setup_seconds','sequential_tests_seconds','concurrency_tests_seconds','result_finalization_seconds']:
    value=timing.get(field)
    if value is None or value<0: failures.append(f'timing field is invalid: {field}')
cpu_total=(process_tree.get('user_cpu_seconds') or 0)+(process_tree.get('system_cpu_seconds') or 0)
if cpu_total<=0: failures.append('observed CPU time is not positive')
if (process_tree.get('maximum_resident_set_kib') or 0)<=0: failures.append('peak resident memory is not positive')
for field in ['major_page_faults','minor_page_faults','filesystem_inputs','filesystem_outputs','voluntary_context_switches','involuntary_context_switches']:
    value=process_tree.get(field)
    if value is None or value<0: failures.append(f'process resource field is invalid: {field}')
if not postgresql.get('database_retained_during_observation'): failures.append('database was not retained during resource observation')
if (postgresql.get('database_size_bytes') or 0)<=0: failures.append('database size is not positive')
if postgresql.get('observed_cluster_wal_bytes') is None or postgresql.get('observed_cluster_wal_bytes')<0: failures.append('observed WAL value is invalid')
for field in ['xact_commit','xact_rollback','blocks_read','blocks_hit','temporary_files','temporary_bytes','deadlocks','tuples_returned','tuples_fetched','tuples_inserted','tuples_updated','tuples_deleted']:
    value=postgresql.get(field)
    if value is None or value<0: failures.append(f'PostgreSQL resource field is invalid: {field}')
if postgresql.get('deadlocks')!=0: failures.append('resource observation contains a deadlock')
if failures:
    for failure in failures:
        print(f'RESOURCE CHECK FAIL: {failure}',file=sys.stderr)
    raise SystemExit(1)
for line in [
    'Run ID matches correctness summary','Correctness result = PASS','Runner exit status = 0',
    'Resource observation = RECORDED','Performance thresholds = NOT_EVALUATED',
    'Environment fingerprint is complete','Timing fields are present',
    'CPU and memory fields are positive','I/O counters are nonnegative',
    'PostgreSQL fields are present','Database size and WAL fields are valid','Deadlocks = 0',
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
    printf '\nPhase 4 Step 3 validation FAILED.\n' >&2
    printf 'Correctness summary: %s\n' "$summary" >&2
    printf 'Resource observation: %s\n' "$resources" >&2
    exit 1
fi

printf '\nPhase 4 Step 3 validation PASSED completely.\n'
printf 'Controlled Approval Action recording is ready for Phase 4 Step 4 independence enforcement.\n'
