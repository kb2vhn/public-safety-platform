#!/usr/bin/env bash
#
# repair_test_framework_documentation_paths.sh
#
# Safely replaces the obsolete literal path:
#
#   sql/test-framework
#
# with:
#
#   test-framework
#
# in tracked Markdown and text documentation only.
#
# Default behavior is a read-only check. Pass --apply to make the replacements.
#

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

readonly SCRIPT_NAME="${0##*/}"
readonly OLD_PATH="sql""/test-framework"
readonly NEW_PATH="test-framework"

APPLY=0

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [--apply]

Options:
  --apply       Replace ${OLD_PATH} with ${NEW_PATH} in tracked .md and .txt files.
  -h, --help    Show this help text.

Without --apply, the script only lists every stale reference and exits.
EOF
}

while (( $# > 0 )); do
    case "$1" in
        --apply)
            APPLY=1
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

declare -A COMMAND_PACKAGE_MAP=(
    [git]="git"
    [grep]="grep"
    [python3]="python"
)

required_commands=(git grep python3)
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

printf 'Repository root: %s\n' "$repository_root"
printf 'Current branch: %s\n' "$(git branch --show-current 2>/dev/null || printf 'detached')"
printf 'Current commit: %s\n' "$(git rev-parse --short=12 HEAD)"

if [[ ! -d "test-framework" ]]; then
    printf 'Top-level test-framework directory is missing.\n' >&2
    exit 66
fi

if [[ -e "$OLD_PATH" ]]; then
    printf 'Old path still exists as a directory or file: %s\n' "$OLD_PATH" >&2
    printf 'This script only repairs documentation references; it will not move files.\n' >&2
    exit 65
fi

if [[ -n "$(git diff --name-only --diff-filter=U)" ]]; then
    printf 'Unresolved Git conflicts exist. No files were changed.\n' >&2
    git diff --name-only --diff-filter=U | sed 's/^/  /' >&2
    exit 65
fi

mapfile -t stale_files < <(
    git grep -l -I -F -- "$OLD_PATH" -- '*.md' '*.txt' 2>/dev/null || true
)

all_stale_references="$(
    git grep -n -I -F -- "$OLD_PATH" -- . 2>/dev/null || true
)"

if [[ -z "$all_stale_references" ]]; then
    printf 'No tracked file references %s.\n' "$OLD_PATH"
    exit 0
fi

printf '\nStale references currently present:\n\n'
printf '%s\n' "$all_stale_references"

unexpected_files="$(
    git grep -l -I -F -- "$OLD_PATH" -- . 2>/dev/null \
        | grep -Ev '\.(md|txt)$' \
        || true
)"

if [[ -n "$unexpected_files" ]]; then
    printf '\nRefusing to continue because stale references exist outside .md or .txt files:\n' >&2
    printf '%s\n' "$unexpected_files" | sed 's/^/  /' >&2
    printf '\nNo repository files were changed.\n' >&2
    exit 65
fi

if (( ${#stale_files[@]} == 0 )); then
    printf '\nNo eligible documentation files were found. No files were changed.\n' >&2
    exit 65
fi

printf '\nEligible documentation files: %d\n' "${#stale_files[@]}"
printf '  %s\n' "${stale_files[@]}"

if (( APPLY == 0 )); then
    printf '\nRead-only check complete. Run with --apply to make the exact literal replacement.\n'
    exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
    printf '\nTracked changes already exist. Commit, stash, or discard them before --apply.\n' >&2
    printf 'Untracked files do not block this repair.\n\n' >&2
    git status --short --untracked-files=no >&2
    exit 65
fi

export PSP_OLD_TEST_FRAMEWORK_PATH="$OLD_PATH"
export PSP_NEW_TEST_FRAMEWORK_PATH="$NEW_PATH"

python3 - "${stale_files[@]}" <<'PY'
import os
import stat
import sys
import tempfile
from pathlib import Path

old = os.environ["PSP_OLD_TEST_FRAMEWORK_PATH"].encode("utf-8")
new = os.environ["PSP_NEW_TEST_FRAMEWORK_PATH"].encode("utf-8")
paths = [Path(value) for value in sys.argv[1:]]

planned = []
for path in paths:
    original = path.read_bytes()
    occurrences = original.count(old)

    if occurrences == 0:
        continue

    updated = original.replace(old, new)
    planned.append((path, original, updated, occurrences))

if not planned:
    print("No replacements were required.")
    raise SystemExit(0)

# All files are read successfully before the first write.
for path, original, updated, occurrences in planned:
    file_stat = path.stat()
    directory = path.parent

    with tempfile.NamedTemporaryFile(
        mode="wb",
        dir=directory,
        prefix=f".{path.name}.",
        suffix=".tmp",
        delete=False,
    ) as temporary:
        temporary.write(updated)
        temporary.flush()
        os.fsync(temporary.fileno())
        temporary_path = Path(temporary.name)

    os.chmod(temporary_path, stat.S_IMODE(file_stat.st_mode))
    os.replace(temporary_path, path)
    print(f"UPDATED: {path} ({occurrences} replacement(s))")
PY

remaining="$(
    git grep -n -I -F -- "$OLD_PATH" -- . 2>/dev/null || true
)"

if [[ -n "$remaining" ]]; then
    printf '\nRepair did not remove every stale reference:\n' >&2
    printf '%s\n' "$remaining" | sed 's/^/  /' >&2
    exit 1
fi

if ! git diff --check; then
    printf '\ngit diff --check failed after the repair.\n' >&2
    exit 1
fi

printf '\nAll tracked stale path references were replaced.\n'
printf '\nFiles changed:\n'
git diff --name-only | sed 's/^/  /'

printf '\nChange summary:\n'
git diff --stat

printf '\nReview the changes with:\n\n'
printf '  git diff -- README.md docs test-framework/INSTALL.txt test-framework/sql/tests/README.md\n'
printf '\nThen rerun:\n\n'
printf '  ./validate_test_framework_move.sh\n'
