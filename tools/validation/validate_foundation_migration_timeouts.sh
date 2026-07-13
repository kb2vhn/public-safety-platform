#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repository_root="$(cd -- "${script_dir}/../.." && pwd -P)"
cd "$repository_root"

required_commands=(bash git python3)
declare -A command_packages=(
  [bash]='bash'
  [git]='git'
  [python3]='python'
)
missing_commands=()
missing_packages=()
declare -A seen_packages=()

for command_name in "${required_commands[@]}"; do
  if command -v "$command_name" >/dev/null 2>&1; then
    continue
  fi

  missing_commands+=("$command_name")
  package_name="${command_packages[$command_name]}"
  if [[ -z "${seen_packages[$package_name]:-}" ]]; then
    missing_packages+=("$package_name")
    seen_packages["$package_name"]=1
  fi
done

if (( ${#missing_commands[@]} > 0 )); then
  printf 'Dependency preflight: FAIL\n\n' >&2
  printf 'Missing required commands:\n' >&2
  for command_name in "${missing_commands[@]}"; do
    printf '  %-12s Arch package: %s\n' \
      "$command_name" "${command_packages[$command_name]}" >&2
  done

  printf '\nInstall all missing packages with:\n\n  sudo pacman -S --needed' >&2
  printf ' %s' "${missing_packages[@]}" >&2
  printf '\n\nWhen operating as root without sudo:\n\n  pacman -S --needed' >&2
  printf ' %s' "${missing_packages[@]}" >&2
  printf '\n\nNo repository file was modified.\n' >&2
  exit 69
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'Run this validator from inside the iron-signal-platform repository.\n' >&2
  exit 66
fi

printf 'Foundation migration timeout validation\n'
printf 'Repository: %s\n' "$repository_root"
printf 'Branch: %s\n' "$(git branch --show-current 2>/dev/null || true)"
printf 'Commit: %s\n\n' "$(git rev-parse --short=12 HEAD 2>/dev/null || true)"

python3 - <<'PY'
from __future__ import annotations

from pathlib import Path
import re
import sys

repository_root = Path.cwd()
manifest_path = repository_root / "sql/schema/manifests/foundation.manifest"
standard_path = (
    repository_root
    / "docs/architecture/foundation/"
      "foundation-migration-timeout-and-execution-performance-standard.md"
)

required_document_markers = (
    "MIG-TIMEOUT-001",
    "SET LOCAL lock_timeout = '5s';",
    "SET LOCAL statement_timeout = '1min';",
    "SET LOCAL idle_in_transaction_session_timeout = '1min';",
    "Over 10 seconds",
)

if not manifest_path.is_file():
    print(f"FAIL: missing manifest: {manifest_path}", file=sys.stderr)
    raise SystemExit(1)

if not standard_path.is_file():
    print(f"FAIL: missing standard: {standard_path}", file=sys.stderr)
    raise SystemExit(1)

standard_text = standard_path.read_text(encoding="utf-8")
for marker in required_document_markers:
    if marker not in standard_text:
        print(
            f"FAIL: standard is missing required marker: {marker}",
            file=sys.stderr,
        )
        raise SystemExit(1)

entries: list[str] = []
for raw_line in manifest_path.read_text(encoding="utf-8").splitlines():
    line = re.sub(r"\s*#.*$", "", raw_line).strip()
    if line:
        entries.append(line)

if not entries:
    print("FAIL: Foundation manifest contains no migrations", file=sys.stderr)
    raise SystemExit(1)

if len(entries) != len(set(entries)):
    print("FAIL: Foundation manifest contains duplicate entries", file=sys.stderr)
    raise SystemExit(1)

expected_header = re.compile(
    r"(?m)^BEGIN;[ \t]*\n"
    r"(?:[ \t]*\n)*"
    r"SET LOCAL lock_timeout = '5s';[ \t]*\n"
    r"SET LOCAL statement_timeout = '1min';[ \t]*\n"
    r"SET LOCAL idle_in_transaction_session_timeout = '1min';[ \t]*(?:\n|$)"
)

canonical_patterns = {
    "lock_timeout": re.compile(
        r"(?m)^SET LOCAL lock_timeout = '5s';[ \t]*$"
    ),
    "statement_timeout": re.compile(
        r"(?m)^SET LOCAL statement_timeout = '1min';[ \t]*$"
    ),
    "idle_in_transaction_session_timeout": re.compile(
        r"(?m)^SET LOCAL idle_in_transaction_session_timeout = '1min';[ \t]*$"
    ),
}

any_declaration_patterns = {
    setting: re.compile(
        rf"(?mi)^\s*SET(?:\s+LOCAL)?\s+{re.escape(setting)}\s*=.*?;\s*$"
    )
    for setting in canonical_patterns
}

failures: list[str] = []
passes = 0

for entry in entries:
    if not entry.startswith("migrations/foundation/"):
        failures.append(f"{entry}: entry is outside migrations/foundation")
        continue

    path = repository_root / "sql/schema" / entry
    if not path.is_file():
        failures.append(f"{entry}: file is missing")
        continue

    text = path.read_text(encoding="utf-8")

    for setting, declaration_pattern in any_declaration_patterns.items():
        declarations = declaration_pattern.findall(text)
        if len(declarations) != 1:
            failures.append(
                f"{entry}: expected exactly one {setting} declaration, "
                f"found {len(declarations)}"
            )

    for setting, canonical_pattern in canonical_patterns.items():
        canonical_count = len(canonical_pattern.findall(text))
        if canonical_count != 1:
            failures.append(
                f"{entry}: canonical {setting} declaration count is "
                f"{canonical_count}, expected 1"
            )

    header_match = expected_header.search(text)
    if header_match is None:
        failures.append(
            f"{entry}: required BEGIN/5s/1min/1min header sequence is missing"
        )
    else:
        prefix = text[: header_match.start()]
        # Comments and whitespace may precede BEGIN. No executable SQL may.
        stripped_prefix = re.sub(r"(?ms)/\*.*?\*/", "", prefix)
        stripped_prefix = re.sub(r"(?m)--.*$", "", stripped_prefix).strip()
        if stripped_prefix:
            failures.append(
                f"{entry}: executable content appears before the timeout header"
            )

    if not any(f.startswith(f"{entry}:") for f in failures):
        print(f"PASS: {entry}")
        passes += 1

if failures:
    print("", file=sys.stderr)
    for failure in failures:
        print(f"FAIL: {failure}", file=sys.stderr)
    print(
        f"\nFoundation migration timeout validation FAILED: "
        f"{len(failures)} finding(s).",
        file=sys.stderr,
    )
    raise SystemExit(1)

print()
print(f"Manifest migrations validated: {len(entries)}")
print(f"Migration files passed: {passes}")
print("Required contract: lock=5s, statement=1min, idle-in-transaction=1min")
print("Foundation migration timeout validation PASSED.")
PY
