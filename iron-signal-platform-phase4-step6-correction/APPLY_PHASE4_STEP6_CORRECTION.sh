#!/usr/bin/env bash
#
# Iron Signal Platform
# Phase 4 Step 6 runtime and ISSP naming correction
#
# Run from the repository root with:
#   bash ./iron-signal-platform-phase4-step6-correction/APPLY_PHASE4_STEP6_CORRECTION.sh
#
# Strict mode applies only to this child Bash process.

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

die() {
    printf '\nERROR: %s\n' "$*" >&2
    exit 1
}

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" \
    || die "Run this script from inside the Iron Signal Platform repository."

cd "$repo_root"

[[ "$(git branch --show-current)" == "dev" ]] \
    || die "Current branch must be dev."

expected_origin="git@github.com:Iron-Signal-Systems/iron-signal-platform.git"
actual_origin="$(git remote get-url origin 2>/dev/null || true)"

[[ "$actual_origin" == "$expected_origin" ]] \
    || die "Origin must be $expected_origin (found: ${actual_origin:-missing})."

git diff --quiet \
    || die "Tracked working-tree changes already exist."

git diff --cached --quiet \
    || die "Staged changes already exist."

step6_test="test-framework/sql/tests/foundation/210_approval_stage_satisfaction_and_finalization.sql"
runner="test-framework/sql/schema/scripts/test_foundation.sh"
resource_runner="test-framework/sql/schema/scripts/test_foundation_with_resources.sh"

for path in "$step6_test" "$runner" "$resource_runner"; do
    [[ -f "$path" ]] || die "Missing required file: $path"
done

python3 - "$step6_test" "$runner" "$resource_runner" <<'PY'
from pathlib import Path
import sys

step6_test = Path(sys.argv[1])
runner = Path(sys.argv[2])
resource_runner = Path(sys.argv[3])

# PostgreSQL does not expose PUBLIC as an ordinary pg_roles entry.
# Existing accepted Foundation tests use lowercase 'public' with the
# privilege inquiry functions.
text = step6_test.read_text(encoding="utf-8")
old_count = text.count("'PUBLIC'")
if old_count != 6:
    raise SystemExit(
        "Expected exactly six uppercase PUBLIC privilege principals in "
        f"{step6_test}; found {old_count}."
    )

text = text.replace("'PUBLIC'", "'public'")
step6_test.write_text(text, encoding="utf-8", newline="\n")

if step6_test.read_text(encoding="utf-8").count("'PUBLIC'") != 0:
    raise SystemExit("Uppercase PUBLIC privilege principals remain.")

# Complete the PSP -> ISSP test-infrastructure rename.
runner_text = runner.read_text(encoding="utf-8")
if "psp_foundation_test_" not in runner_text:
    raise SystemExit(
        f"Expected the old psp_foundation_test_ prefix in {runner}."
    )

runner_text = runner_text.replace(
    "psp_foundation_test_",
    "issp_foundation_test_",
)
runner_text = runner_text.replace(
    "psp-foundation-expected",
    "issp-foundation-expected",
)
runner.write_text(runner_text, encoding="utf-8", newline="\n")

resource_text = resource_runner.read_text(encoding="utf-8")
if "psp_foundation_test_" not in resource_text:
    raise SystemExit(
        f"Expected the old psp_foundation_test_ prefix in {resource_runner}."
    )

resource_text = resource_text.replace(
    "psp_foundation_test_",
    "issp_foundation_test_",
)
resource_text = resource_text.replace(
    "psp-foundation-time",
    "issp-foundation-time",
)
resource_runner.write_text(resource_text, encoding="utf-8", newline="\n")

for path in (runner, resource_runner):
    final = path.read_text(encoding="utf-8")
    remaining = [
        token
        for token in (
            "psp_foundation_test_",
            "psp-foundation-expected",
            "psp-foundation-time",
        )
        if token in final
    ]
    if remaining:
        raise SystemExit(
            f"{path}: old PSP tokens remain: {', '.join(remaining)}"
        )

print("Updated Step 6 PUBLIC privilege checks: 6")
print("Renamed disposable database prefix: issp_foundation_test_")
print("Renamed temporary test files from psp-* to issp-*")
PY

chmod +x "$runner" "$resource_runner"

bash -n "$runner"
bash -n "$resource_runner"

git diff --check

changed_files="$(git diff --name-only)"
expected_files="$step6_test
$runner
$resource_runner"

if [[ "$changed_files" != "$expected_files" ]]; then
    printf '\nUnexpected changed-file set:\n%s\n' "$changed_files" >&2
    exit 1
fi

printf '\nPhase 4 Step 6 correction applied successfully.\n'
printf 'Changed files:\n%s\n' "$changed_files"
printf '\nThe package did not commit or push anything.\n'
