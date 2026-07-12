#!/usr/bin/env bash
#
# validate_test_framework_move.sh
#
# Read-only validation for the Public Safety Platform repository after moving:
#
#   sql/test-framework/  ->  test-framework/
#
# Default behavior performs static repository, path, manifest, documentation,
# executable-mode, and shell-syntax checks without creating files or databases.
#
# Use --run-tests only after the static checks pass. That option invokes the
# authoritative Foundation test runner.
#

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

readonly SCRIPT_NAME="${0##*/}"
readonly OLD_FRAMEWORK_PATH="sql""/test-framework"
readonly NEW_FRAMEWORK_PATH="test-framework"

RUN_TESTS=0
PASS_COUNT=0
INFO_COUNT=0
FAIL_COUNT=0
LAST_MANIFEST_COUNT=0

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [--run-tests]

Validates the completed top-level test-framework move.

Options:
  --run-tests   After all static checks pass, run:
                  ./test-framework/sql/schema/scripts/test_foundation.sh
  -h, --help    Show this help text.

The default validation is read-only and does not create files or databases.
EOF
}

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    printf 'PASS: %s\n' "$*"
}

info() {
    INFO_COUNT=$((INFO_COUNT + 1))
    printf 'INFO: %s\n' "$*"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf 'FAIL: %s\n' "$*" >&2
}

section() {
    printf '\n== %s ==\n' "$*"
}

require_file() {
    local path="$1"

    if [[ -f "$path" ]]; then
        pass "Required file exists: ${path}"
    else
        fail "Required file is missing: ${path}"
    fi
}

require_directory() {
    local path="$1"

    if [[ -d "$path" ]]; then
        pass "Required directory exists: ${path}"
    else
        fail "Required directory is missing: ${path}"
    fi
}

require_tracked_path() {
    local path="$1"

    if git ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
        pass "Path is tracked by Git: ${path}"
    else
        fail "Path is not tracked by Git: ${path}"
    fi
}

require_text() {
    local file="$1"
    local expected="$2"
    local description="$3"

    if [[ ! -f "$file" ]]; then
        fail "Cannot inspect missing file: ${file}"
        return
    fi

    if grep -Fq -- "$expected" "$file"; then
        pass "${description}: ${file}"
    else
        fail "${description}: ${file}"
        printf '      Expected text: %s\n' "$expected" >&2
    fi
}

trim_manifest_line() {
    local line="$1"

    printf '%s' "$line" \
        | sed 's/\r$//' \
        | sed 's/[[:space:]]*#.*$//' \
        | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

check_git_executable_mode() {
    local path="$1"
    local mode=""

    mode="$(
        git ls-files --stage -- "$path" \
            | awk 'NR == 1 { print $1 }'
    )"

    if [[ "$mode" == "100755" ]]; then
        pass "Git executable mode is correct: ${path}"
    else
        fail "Git executable mode must be 100755: ${path} (found ${mode:-untracked})"
    fi
}

validate_manifest() {
    local manifest="$1"
    local base_directory="$2"
    local allowed_regex="$3"
    local expected_extension="$4"
    local require_executable="$5"
    local label="$6"

    local raw_line=""
    local relative_path=""
    local full_path=""
    local entry_count=0
    local local_failures=0

    LAST_MANIFEST_COUNT=0
    declare -A seen_entries=()

    if [[ ! -f "$manifest" ]]; then
        fail "${label} manifest is missing: ${manifest}"
        return
    fi

    if [[ ! -d "$base_directory" ]]; then
        fail "${label} base directory is missing: ${base_directory}"
        return
    fi

    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
        relative_path="$(trim_manifest_line "$raw_line")"
        [[ -z "$relative_path" ]] && continue

        entry_count=$((entry_count + 1))

        if [[ "$relative_path" == /* ]] \
            || [[ "$relative_path" == *'..'* ]] \
            || [[ "$relative_path" == *'\'* ]]; then
            fail "${label} manifest contains an unsafe path: ${relative_path}"
            local_failures=$((local_failures + 1))
            continue
        fi

        if [[ ! "$relative_path" =~ $allowed_regex ]]; then
            fail "${label} manifest path has an invalid form: ${relative_path}"
            local_failures=$((local_failures + 1))
        fi

        if [[ "${relative_path##*.}" != "$expected_extension" ]]; then
            fail "${label} manifest entry has the wrong extension: ${relative_path}"
            local_failures=$((local_failures + 1))
        fi

        if [[ -n "${seen_entries[$relative_path]:-}" ]]; then
            fail "${label} manifest contains a duplicate entry: ${relative_path}"
            local_failures=$((local_failures + 1))
        else
            seen_entries["$relative_path"]=1
        fi

        full_path="${base_directory}/${relative_path}"

        if [[ ! -f "$full_path" ]]; then
            fail "${label} manifest references a missing file: ${full_path}"
            local_failures=$((local_failures + 1))
            continue
        fi

        if [[ "$require_executable" == "1" && ! -x "$full_path" ]]; then
            fail "${label} manifest references a non-executable file: ${full_path}"
            local_failures=$((local_failures + 1))
        fi
    done <"$manifest"

    LAST_MANIFEST_COUNT="$entry_count"

    if (( entry_count == 0 )); then
        fail "${label} manifest contains no entries: ${manifest}"
        return
    fi

    if (( local_failures == 0 )); then
        pass "${label} manifest is valid (${entry_count} entries): ${manifest}"
    fi
}

check_unlisted_files() {
    local manifest="$1"
    local base_directory="$2"
    local search_directory="$3"
    local glob_pattern="$4"
    local label="$5"

    local manifest_entries=""
    local discovered_files=""
    local unlisted_files=""
    local local_entry=""

    if [[ ! -f "$manifest" ]]; then
        fail "Cannot check unlisted ${label} files because the manifest is missing: ${manifest}"
        return
    fi

    if [[ ! -d "$search_directory" ]]; then
        fail "Cannot check unlisted ${label} files because the directory is missing: ${search_directory}"
        return
    fi

    manifest_entries="$(
        while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
            local_entry="$(trim_manifest_line "$raw_line")"
            [[ -n "$local_entry" ]] && printf '%s\n' "$local_entry"
        done <"$manifest" \
            | sort -u
    )"

    discovered_files="$(
        find "$search_directory" -maxdepth 1 -type f -name "$glob_pattern" -print \
            | sed "s#^${base_directory}/##" \
            | sort -u
    )"

    unlisted_files="$(
        comm -23 \
            <(printf '%s\n' "$discovered_files" | sed '/^$/d') \
            <(printf '%s\n' "$manifest_entries" | sed '/^$/d')
    )"

    if [[ -z "$unlisted_files" ]]; then
        pass "Every ${label} file is listed in its manifest"
    else
        fail "The following ${label} files are not listed in their manifest:"
        while IFS= read -r path; do
            [[ -n "$path" ]] && printf '      %s\n' "$path" >&2
        done <<<"$unlisted_files"
    fi
}

while (( $# > 0 )); do
    case "$1" in
        --run-tests)
            RUN_TESTS=1
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
    printf 'Bash 4 or newer is required; found %s\n' "$BASH_VERSION" >&2
    printf 'Arch package: bash\n' >&2
    exit 69
fi

declare -A COMMAND_PACKAGE_MAP=(
    [awk]="gawk"
    [bash]="bash"
    [comm]="coreutils"
    [dirname]="coreutils"
    [find]="findutils"
    [git]="git"
    [grep]="grep"
    [sed]="sed"
    [sort]="coreutils"
)

required_commands=(
    awk
    bash
    comm
    dirname
    find
    git
    grep
    sed
    sort
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

if (( ${#missing_commands[@]} > 0 )); then
    printf 'Dependency preflight: FAIL\n\n' >&2
    printf 'Missing required commands:\n' >&2

    for command_name in "${missing_commands[@]}"; do
        printf '  %-10s Arch package: %s\n' \
            "$command_name" \
            "${COMMAND_PACKAGE_MAP[$command_name]}" >&2
    done

    printf '\nInstall all missing packages with:\n\n' >&2
    printf '  sudo pacman -S --needed' >&2
    printf ' %s' "${missing_packages[@]}" >&2
    printf '\n\nNo repository files were changed.\n' >&2
    exit 69
fi

printf 'Dependency preflight: PASS\n'

if ! repository_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    printf 'Not inside a Git working tree.\n' >&2
    exit 66
fi

cd "$repository_root"

section "Repository identity and Git state"

printf 'Repository root: %s\n' "$repository_root"
printf 'Current branch: %s\n' "$(git branch --show-current 2>/dev/null || printf 'detached')"
printf 'Current commit: %s\n' "$(git rev-parse --short=12 HEAD)"

if [[ -n "$(git diff --name-only --diff-filter=U)" ]]; then
    fail "Unresolved Git merge conflicts exist"
    git diff --name-only --diff-filter=U | sed 's/^/      /' >&2
else
    pass "No unresolved Git merge conflicts"
fi

if git diff --check >/dev/null; then
    pass "Tracked working-tree changes pass git diff --check"
else
    fail "git diff --check reported whitespace or conflict-marker problems"
    git diff --check >&2 || true
fi

if [[ -z "$(git status --short --untracked-files=no)" ]]; then
    pass "No tracked working-tree changes"
else
    info "Tracked working tree is not clean; validation will continue"
    git status --short --untracked-files=no | sed 's/^/      /'
fi

untracked_count="$(
    git status --short \
        | awk '$1 == "??" { count++ } END { print count + 0 }'
)"
if (( untracked_count > 0 )); then
    info "Untracked files present: ${untracked_count}"
fi

section "Top-level layout"

if [[ -e "$OLD_FRAMEWORK_PATH" ]]; then
    fail "Old framework path still exists in the working tree: ${OLD_FRAMEWORK_PATH}"
else
    pass "Old framework path is absent from the working tree: ${OLD_FRAMEWORK_PATH}"
fi

if git ls-files -- "$OLD_FRAMEWORK_PATH" | grep -q .; then
    fail "Git still tracks one or more files beneath: ${OLD_FRAMEWORK_PATH}"
    git ls-files -- "$OLD_FRAMEWORK_PATH" \
        | sed 's/^/      /' >&2
else
    pass "Git tracks no files beneath the old framework path"
fi

require_directory "$NEW_FRAMEWORK_PATH"
require_directory "sql/schema"
require_directory "test-framework/sql/schema/scripts"
require_directory "test-framework/sql/tests"
require_directory "test-framework/sql/tests/framework"
require_directory "test-framework/sql/tests/foundation"
require_directory "test-framework/sql/tests/concurrency"
require_directory "test-framework/sql/test-results"

required_files=(
    "README.md"
    "sql/schema/manifests/foundation.manifest"
    "test-framework/INSTALL.txt"
    "test-framework/Makefile"
    "test-framework/sql/schema/scripts/test_foundation.sh"
    "test-framework/sql/tests/README.md"
    "test-framework/sql/tests/foundation-tests.manifest"
    "test-framework/sql/tests/foundation-concurrency-tests.manifest"
    "test-framework/sql/tests/framework/000_test_framework.sql"
    "test-framework/sql/test-results/.gitignore"
)

for path in "${required_files[@]}"; do
    require_file "$path"
done

require_tracked_path "test-framework/INSTALL.txt"
require_tracked_path "test-framework/Makefile"
require_tracked_path "test-framework/sql/schema/scripts/test_foundation.sh"
require_tracked_path "test-framework/sql/tests/foundation-tests.manifest"
require_tracked_path "test-framework/sql/tests/foundation-concurrency-tests.manifest"

section "Stale path references"

stale_references="$(
    git grep -n -I -F -- "$OLD_FRAMEWORK_PATH" -- . 2>/dev/null || true
)"

if [[ -z "$stale_references" ]]; then
    pass "No tracked file still references ${OLD_FRAMEWORK_PATH}"
else
    fail "Tracked files still reference ${OLD_FRAMEWORK_PATH}:"
    printf '%s\n' "$stale_references" | sed 's/^/      /' >&2
fi

section "Authoritative runner path resolution"

runner="test-framework/sql/schema/scripts/test_foundation.sh"

if [[ -f "$runner" ]]; then
    require_text \
        "$runner" \
        'test_sql_root="$(cd -- "${script_dir}/../.." && pwd -P)"' \
        "Runner resolves test-framework/sql"

    require_text \
        "$runner" \
        'test_framework_root="$(cd -- "${test_sql_root}/.." && pwd -P)"' \
        "Runner resolves top-level test-framework"

    require_text \
        "$runner" \
        'repository_root="$(cd -- "${test_framework_root}/.." && pwd -P)"' \
        "Runner resolves repository root from top-level test-framework"

    require_text \
        "$runner" \
        'foundation_schema_root="${repository_root}/sql/schema"' \
        "Runner resolves live Foundation SQL separately"

    require_text \
        "$runner" \
        'concurrency_manifest="${test_root}/foundation-concurrency-tests.manifest"' \
        "Runner loads the concurrency manifest"

    require_text \
        "$runner" \
        'log "Running Foundation concurrency tests"' \
        "Runner executes the concurrency test phase"

    require_text \
        "$runner" \
        'PSP_TEST_DATABASE="$test_database"' \
        "Runner passes the disposable database to concurrency tests"
fi

section "Shell syntax and executable modes"

if [[ -d "test-framework" ]]; then
    while IFS= read -r shell_file; do
        if bash -n "$shell_file"; then
            pass "Shell syntax is valid: ${shell_file}"
        else
            fail "Shell syntax is invalid: ${shell_file}"
        fi
    done < <(find test-framework -type f -name '*.sh' -print | sort)
else
    fail "Cannot run shell syntax checks because test-framework/ is missing"
fi

check_git_executable_mode "$runner"

if [[ -d "test-framework/sql/tests/concurrency" ]]; then
    while IFS= read -r concurrency_script; do
        check_git_executable_mode "$concurrency_script"
    done < <(find test-framework/sql/tests/concurrency -maxdepth 1 -type f -name '*.sh' -print | sort)
else
    fail "Cannot check concurrency executable modes because the directory is missing"
fi

section "Manifest integrity"

foundation_manifest="sql/schema/manifests/foundation.manifest"
sequential_manifest="test-framework/sql/tests/foundation-tests.manifest"
concurrency_manifest="test-framework/sql/tests/foundation-concurrency-tests.manifest"
test_root="test-framework/sql/tests"

# IMPORTANT:
# Foundation manifest entries already begin with "migrations/".
# Therefore, resolve them from sql/schema, not sql/schema/migrations.
validate_manifest \
    "$foundation_manifest" \
    "sql/schema" \
    '^migrations/foundation/[0-9]{3}_[a-z0-9_]+\.sql$' \
    'sql' \
    '0' \
    'Foundation migration'
foundation_count="$LAST_MANIFEST_COUNT"

validate_manifest \
    "$sequential_manifest" \
    "$test_root" \
    '^foundation/[0-9]{3}_[a-z0-9_]+\.sql$' \
    'sql' \
    '0' \
    'Sequential test'
sequential_count="$LAST_MANIFEST_COUNT"

validate_manifest \
    "$concurrency_manifest" \
    "$test_root" \
    '^concurrency/[0-9]{3}_[a-z0-9_]+\.sh$' \
    'sh' \
    '1' \
    'Concurrency test'
concurrency_count="$LAST_MANIFEST_COUNT"

if [[ "$foundation_count" =~ ^[0-9]+$ ]] && (( foundation_count >= 32 )); then
    pass "Foundation manifest contains at least the Phase 2 Step 2 migration set (${foundation_count})"
else
    fail "Foundation manifest contains fewer than 32 migrations (${foundation_count:-unknown})"
fi

if [[ "$sequential_count" =~ ^[0-9]+$ ]] && (( sequential_count >= 11 )); then
    pass "Sequential manifest contains at least the Phase 2 Step 2 test set (${sequential_count})"
else
    fail "Sequential manifest contains fewer than 11 tests (${sequential_count:-unknown})"
fi

if [[ "$concurrency_count" =~ ^[0-9]+$ ]] && (( concurrency_count >= 1 )); then
    pass "Concurrency manifest contains at least one test (${concurrency_count})"
else
    fail "Concurrency manifest contains no tests (${concurrency_count:-unknown})"
fi

require_text \
    "$foundation_manifest" \
    'migrations/foundation/072_postgresql_session_control.sql' \
    "Foundation manifest includes Phase 2 Step 2 migration 072"

require_text \
    "$sequential_manifest" \
    'foundation/100_authentication_assertion_phase1_behavior.sql' \
    "Sequential manifest preserves the complete Phase 1 behavior test"

require_text \
    "$sequential_manifest" \
    'foundation/110_session_establishment_and_step_up_behavior.sql' \
    "Sequential manifest includes the Phase 2 Step 2 behavior test"

require_text \
    "$concurrency_manifest" \
    'concurrency/100_authentication_assertion_single_use.sh' \
    "Concurrency manifest preserves the accepted Phase 1 race test"

check_unlisted_files \
    "$sequential_manifest" \
    "$test_root" \
    "$test_root/foundation" \
    '*.sql' \
    "sequential Foundation test"

check_unlisted_files \
    "$concurrency_manifest" \
    "$test_root" \
    "$test_root/concurrency" \
    '*.sh' \
    "concurrency test"

section "Documentation and convenience commands"

require_text \
    "README.md" \
    'test-framework/' \
    "Root README names the top-level test framework"

require_text \
    "README.md" \
    './test-framework/sql/schema/scripts/test_foundation.sh' \
    "Root README uses the new runner command"

require_text \
    "README.md" \
    'test-framework/sql/test-results/latest.log' \
    "Root README uses the new result path"

require_text \
    "test-framework/INSTALL.txt" \
    'test-framework/' \
    "INSTALL.txt names the top-level framework directory"

require_text \
    "test-framework/INSTALL.txt" \
    './test-framework/sql/schema/scripts/test_foundation.sh' \
    "INSTALL.txt uses the new repository-root command"

require_text \
    "test-framework/sql/tests/README.md" \
    '`test-framework/`' \
    "Test README names the top-level framework directory"

require_text \
    "test-framework/sql/tests/README.md" \
    './test-framework/sql/schema/scripts/test_foundation.sh' \
    "Test README uses the new repository-root command"

require_text \
    "test-framework/Makefile" \
    './sql/schema/scripts/test_foundation.sh' \
    "Makefile invokes the runner relative to test-framework"

section "Final static result"

printf 'PASS checks: %d\n' "$PASS_COUNT"
printf 'INFO checks: %d\n' "$INFO_COUNT"
printf 'FAIL checks: %d\n' "$FAIL_COUNT"

if (( FAIL_COUNT > 0 )); then
    printf '\nStatic validation FAILED. Correct every FAIL item before running the database tests.\n' >&2
    exit 1
fi

printf '\nStatic validation PASSED.\n'

if (( RUN_TESTS == 0 )); then
    printf 'Database tests were not run. Use --run-tests after reviewing the static result.\n'
    exit 0
fi

section "Full Foundation database test"

printf 'Executing: ./%s\n' "$runner"

if "./$runner"; then
    pass "Full Foundation database test completed successfully"
else
    test_exit_status=$?
    fail "Full Foundation database test failed with exit status ${test_exit_status}"
    exit "$test_exit_status"
fi

printf '\nFull validation PASSED.\n'

