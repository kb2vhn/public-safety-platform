#!/usr/bin/env bash
#
# Public Safety Platform
# Domain-neutral terminology and schema migration
#
# This script updates the Platform Foundation so its terminology remains
# usable for public safety, municipal, school, finance, public works, and
# future module families.
#
# Run from the repository root:
#
#   chmod +x foundation-domain-neutrality-update.sh
#   ./foundation-domain-neutrality-update.sh
#
# Options:
#   --no-tests      Apply and validate source changes without running PostgreSQL.
#   --help          Show usage.
#
# The script:
#   - checks all dependencies before changing files,
#   - requires a clean dev branch,
#   - fetches and fast-forwards to the latest origin/dev,
#   - creates a timestamped tracked-source backup,
#   - performs every change in a temporary detached Git worktree,
#   - renames SQL migrations and architecture documents with git mv,
#   - updates SQL identifiers, manifests, tests, links, and documentation,
#   - adds a normative terminology/domain-neutrality document,
#   - excludes generated test-results from terminology enforcement,
#   - rejects obsolete or ambiguous structural terms in source files,
#   - produces a retained-terminology audit,
#   - checks Bash syntax and Git whitespace,
#   - runs the complete Foundation SQL suite unless --no-tests is supplied,
#   - applies the completed patch to the real checkout only after validation.
#

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

run_tests=1

usage() {
    cat <<'USAGE'
Usage:
  ./foundation-domain-neutrality-update.sh [options]

Options:
  --no-tests
      Do not run the PostgreSQL Foundation test framework after the source
      migration. Source validation still runs.

  -h, --help
      Show this help text.

Run this script from the public-safety-platform repository root on branch dev. The worktree must be clean.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-tests)
            run_tests=0
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
    printf 'Bash 4 or newer is required. Current version: %s\n' "$BASH_VERSION" >&2
    printf 'Arch package: bash\n' >&2
    exit 69
fi

declare -A COMMAND_PACKAGE_MAP=(
    [awk]="gawk"
    [basename]="coreutils"
    [bash]="bash"
    [createdb]="postgresql-libs"
    [date]="coreutils"
    [dirname]="coreutils"
    [dropdb]="postgresql-libs"
    [git]="git"
    [grep]="grep"
    [ln]="coreutils"
    [mkdir]="coreutils"
    [mktemp]="coreutils"
    [psql]="postgresql-libs"
    [python3]="python"
    [rm]="coreutils"
    [sed]="sed"
    [sha256sum]="coreutils"
    [tar]="tar"
    [tee]="coreutils"
)

preflight_dependencies() {
    local -a required_commands=(
        bash
        basename
        date
        git
        mktemp
        python3
        rm
        tar
    )

    if [[ "$run_tests" -eq 1 ]]; then
        required_commands+=(
            awk
            basename
            createdb
            dirname
            dropdb
            grep
            ln
            mkdir
            mktemp
            psql
            rm
            sed
            sha256sum
            tee
        )
    fi

    local -a missing_commands=()
    local -a missing_packages=()
    local -A seen_packages=()
    local command_name
    local package_name
    local package_line=""

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

    if [[ "${#missing_commands[@]}" -eq 0 ]]; then
        printf 'Dependency preflight: PASS\n'
        return 0
    fi

    printf 'Dependency preflight: FAIL\n\n' >&2
    printf 'Missing required commands:\n' >&2

    for command_name in "${missing_commands[@]}"; do
        printf '  %-12s Arch package: %s\n' \
            "$command_name" \
            "${COMMAND_PACKAGE_MAP[$command_name]}" >&2
    done

    printf -v package_line '%s ' "${missing_packages[@]}"
    package_line="${package_line% }"

    printf '\nInstall all missing packages with:\n\n' >&2
    printf '  sudo pacman -S --needed %s\n' "$package_line" >&2
    printf '\nWhen operating as root without sudo:\n\n' >&2
    printf '  pacman -S --needed %s\n' "$package_line" >&2
    printf '\nNo repository files were modified.\n' >&2
    exit 69
}

preflight_postgresql() {
    local maintenance_database="${PGMAINTENANCE_DB:-postgres}"
    local result
    local version_number
    local connected_role
    local can_create_database

    if [[ "$run_tests" -ne 1 ]]; then
        return 0
    fi

    printf 'PostgreSQL preflight: checking connection, version, and CREATEDB privilege...\n'

    if ! result="$(
        psql \
            -X \
            --no-psqlrc \
            --set=ON_ERROR_STOP=1 \
            --tuples-only \
            --no-align \
            --dbname="$maintenance_database" \
            --command="
                SELECT
                    current_setting('server_version_num')
                    || '|'
                    || current_user
                    || '|'
                    || CASE
                        WHEN role_record.rolsuper
                          OR role_record.rolcreatedb
                        THEN '1'
                        ELSE '0'
                       END
                FROM pg_roles AS role_record
                WHERE role_record.rolname = current_user;
            "
    )"; then
        printf 'PostgreSQL preflight: FAIL\n' >&2
        printf 'Could not connect to maintenance database: %s\n' \
            "$maintenance_database" >&2
        printf 'Check PGHOST, PGPORT, PGUSER, PGPASSWORD, and PGSSLMODE.\n' >&2
        printf 'No repository files were modified.\n' >&2
        exit 69
    fi

    IFS='|' read -r version_number connected_role can_create_database \
        <<<"$result"

    if [[ ! "$version_number" =~ ^[0-9]+$ ]]; then
        printf 'PostgreSQL preflight: FAIL\n' >&2
        printf 'Could not interpret server_version_num: %s\n' \
            "$version_number" >&2
        printf 'No repository files were modified.\n' >&2
        exit 69
    fi

    if (( version_number < 180000 )); then
        printf 'PostgreSQL preflight: FAIL\n' >&2
        printf 'PostgreSQL 18 or newer is required; server_version_num=%s\n' \
            "$version_number" >&2
        printf 'No repository files were modified.\n' >&2
        exit 69
    fi

    if [[ "$can_create_database" != "1" ]]; then
        printf 'PostgreSQL preflight: FAIL\n' >&2
        printf 'Connected role %s lacks CREATEDB or SUPERUSER.\n' \
            "$connected_role" >&2
        printf 'No repository files were modified.\n' >&2
        exit 77
    fi

    printf 'PostgreSQL preflight: PASS (role=%s, server_version_num=%s)\n' \
        "$connected_role" \
        "$version_number"
}

preflight_dependencies

source_repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    printf 'Run this script from inside the Git repository.\n' >&2
    exit 64
}

cd "$source_repo_root"

branch_name="$(git branch --show-current)"
if [[ "$branch_name" != "dev" ]]; then
    printf 'Refusing to update branch %s. Switch to dev first.\n' "$branch_name" >&2
    exit 65
fi

origin_url="$(git config --get remote.origin.url 2>/dev/null || true)"
if [[ -z "$origin_url" ]] ||
   [[ "$origin_url" != *"kb2vhn/public-safety-platform"* ]]; then
    printf 'Unexpected or missing origin repository: %s\n' \
        "${origin_url:-[not configured]}" >&2
    exit 65
fi

script_basename="$(basename -- "$0")"

dirty_lines="$(
    git status --porcelain |
    while IFS= read -r line; do
        path_part="${line:3}"
        if [[ "$path_part" == "$script_basename" ]]; then
            continue
        fi
        printf '%s\n' "$line"
    done
)"

if [[ -n "$dirty_lines" ]]; then
    printf 'Refusing to update a dirty worktree:\n\n%s\n\n' "$dirty_lines" >&2
    printf 'Restore, commit, or stash the current changes first.\n' >&2
    printf 'No repository files were modified.\n' >&2
    exit 65
fi

printf 'Refreshing origin/dev...\n'
git fetch --prune origin dev

if ! git merge --ff-only origin/dev; then
    printf 'Could not fast-forward dev to origin/dev.\n' >&2
    printf 'Resolve the branch divergence before running this migration.\n' >&2
    printf 'No Foundation source files were modified.\n' >&2
    exit 65
fi

# Verify the pull did not introduce local changes.
dirty_lines="$(
    git status --porcelain |
    while IFS= read -r line; do
        path_part="${line:3}"
        if [[ "$path_part" == "$script_basename" ]]; then
            continue
        fi
        printf '%s\n' "$line"
    done
)"

if [[ -n "$dirty_lines" ]]; then
    printf 'Worktree is not clean after refreshing origin/dev:\n\n%s\n' \
        "$dirty_lines" >&2
    printf 'No Foundation source files were modified.\n' >&2
    exit 65
fi

required_paths=(
    "README.md"
    "docs/architecture/foundation/README.md"
    "docs/architecture/foundation/authorization-evaluation-contract.md"
    "docs/architecture/foundation/organization-and-jurisdiction-model.md"
    "docs/architecture/foundation/trust-and-decision-engine-model.md"
    "docs/architecture/provider-neutral-observability.md"
    "sql/schema/manifests/foundation.manifest"
    "sql/schema/migrations/foundation/030_organizations_and_jurisdictions.sql"
    "sql/schema/migrations/foundation/055_authority_purpose_and_authorization_policy.sql"
    "sql/schema/migrations/foundation/070_postgresql_trust_gate.sql"
    "sql/schema/migrations/foundation/075_controlled_authorization_api.sql"
    "sql/schema/migrations/foundation/096_monitoring_subscriptions_and_provider_delivery_state.sql"
    "sql/schema/migrations/foundation/097_provider_integration_outbox.sql"
    "sql/test-framework/sql/tests/foundation/080_foundation_baseline_integrity.sql"
    "sql/test-framework/sql/schema/scripts/test_foundation.sh"
)

for required_path in "${required_paths[@]}"; do
    if [[ ! -e "$required_path" ]]; then
        printf 'Expected latest-dev path not found: %s\n' "$required_path" >&2
        printf 'The migration was built for the current published dev baseline.\n' >&2
        printf 'No repository files were modified.\n' >&2
        exit 66
    fi
done

preflight_postgresql

timestamp="$(date +%Y%m%d_%H%M%S)"
backup_archive="/tmp/public-safety-platform-domain-neutrality-${timestamp}.tar.gz"
audit_file="/tmp/public-safety-platform-terminology-audit-${timestamp}.txt"
patch_file="/tmp/public-safety-platform-domain-neutrality-${timestamp}.patch"
temporary_parent="$(mktemp -d "${TMPDIR:-/tmp}/psp-domain-neutrality-worktree.XXXXXX")"
temporary_worktree="${temporary_parent}/worktree"
worktree_registered=0

cleanup_atomic_update() {
    local exit_status=$?

    trap - EXIT INT TERM
    set +e

    if [[ "$worktree_registered" -eq 1 ]]; then
        git -C "$source_repo_root" worktree remove --force \
            "$temporary_worktree" >/dev/null 2>&1
    fi

    rm -rf -- "$temporary_parent"

    if [[ "$exit_status" -ne 0 ]]; then
        printf '\nDomain-neutral update did not modify the real checkout.\n' >&2
        printf 'Tracked-source backup: %s\n' "$backup_archive" >&2
        if [[ -f "$audit_file" ]]; then
            printf 'Terminology audit: %s\n' "$audit_file" >&2
        fi
    fi

    exit "$exit_status"
}

trap cleanup_atomic_update EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

printf 'Creating tracked-source backup: %s\n' "$backup_archive"
git ls-files -z -- \
    README.md \
    docs \
    sql \
    ':(exclude)sql/test-framework/sql/test-results/**' |
    tar --null --files-from=- -czf "$backup_archive"

printf 'Creating temporary validation worktree: %s\n' "$temporary_worktree"
git worktree add --detach "$temporary_worktree" HEAD >/dev/null
worktree_registered=1

repo_root="$temporary_worktree"
cd "$repo_root"

export PSP_DOMAIN_NEUTRALITY_REPO_ROOT="$repo_root"
export PSP_DOMAIN_NEUTRALITY_AUDIT_FILE="$audit_file"

python3 <<'PYTHON'
from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path

root = Path(os.environ["PSP_DOMAIN_NEUTRALITY_REPO_ROOT"])
audit_path = Path(os.environ["PSP_DOMAIN_NEUTRALITY_AUDIT_FILE"])


class UpdateError(RuntimeError):
    pass


def run_git(*args: str) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=root,
        check=True,
        text=True,
        capture_output=True,
    )
    return result.stdout


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write(path: Path, content: str) -> None:
    if not content.endswith("\n"):
        content += "\n"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def rename_tracked(old_relative: str, new_relative: str) -> None:
    old_path = root / old_relative
    new_path = root / new_relative

    if old_path.exists() and new_path.exists():
        raise UpdateError(
            f"Both old and new paths exist: {old_relative}, {new_relative}"
        )

    if new_path.exists():
        print(f"Already renamed: {new_relative}")
        return

    if not old_path.exists():
        raise UpdateError(f"Expected path not found: {old_relative}")

    new_path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["git", "mv", old_relative, new_relative],
        cwd=root,
        check=True,
    )
    print(f"Renamed: {old_relative} -> {new_relative}")


def replace_section(
    text: str,
    heading: str,
    replacement: str,
    heading_level_pattern: str = r"#{1,6}",
) -> str:
    pattern = re.compile(
        rf"(?ms)^{re.escape(heading)}\n.*?(?=^{heading_level_pattern}\s|\Z)"
    )
    if pattern.search(text):
        return pattern.sub(replacement.rstrip() + "\n\n", text, count=1)
    return text


def insert_before_first_heading(
    text: str,
    candidates: list[str],
    block: str,
) -> str:
    for candidate in candidates:
        marker = f"{candidate}\n"
        if marker in text:
            return text.replace(
                marker,
                block.rstrip() + "\n\n" + marker,
                1,
            )
    return text.rstrip() + "\n\n" + block.rstrip() + "\n"


rename_map = {
    "sql/schema/migrations/foundation/030_organizations_and_jurisdictions.sql":
        "sql/schema/migrations/foundation/030_organizations_and_governed_scopes.sql",
    "sql/schema/migrations/foundation/070_postgresql_trust_gate.sql":
        "sql/schema/migrations/foundation/070_postgresql_authentication_assertion_gate.sql",
    "sql/schema/migrations/foundation/096_monitoring_subscriptions_and_provider_delivery_state.sql":
        "sql/schema/migrations/foundation/096_monitoring_subscriptions_and_delivery_state.sql",
    "sql/schema/migrations/foundation/097_provider_integration_outbox.sql":
        "sql/schema/migrations/foundation/097_external_integration_outbox.sql",
    "docs/architecture/foundation/organization-and-jurisdiction-model.md":
        "docs/architecture/foundation/organization-and-governed-scope-model.md",
    "docs/architecture/foundation/trust-and-decision-engine-model.md":
        "docs/architecture/foundation/authentication-and-authorization-evaluation-model.md",
    "docs/architecture/provider-neutral-observability.md":
        "docs/architecture/external-system-independent-observability.md",
}

for old_name, new_name in rename_map.items():
    rename_tracked(old_name, new_name)

tracked_paths = run_git("ls-files").splitlines()

text_suffixes = {
    ".md",
    ".txt",
    ".sql",
    ".sh",
    ".manifest",
    ".go",
    ".mod",
    ".sum",
    ".yaml",
    ".yml",
}

text_files: list[Path] = []
for relative in tracked_paths:
    path = root / relative
    if not path.is_file():
        continue
    if path.name == "README.md" or path.suffix.lower() in text_suffixes:
        try:
            path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        text_files.append(path)

replacement_pairs = [
    # Paths, migration identifiers, and document names.
    (
        "030_organizations_and_jurisdictions",
        "030_organizations_and_governed_scopes",
    ),
    (
        "030_organizations_and_jurisdictions.sql",
        "030_organizations_and_governed_scopes.sql",
    ),
    (
        "organization-and-jurisdiction-model.md",
        "organization-and-governed-scope-model.md",
    ),
    (
        "070_postgresql_trust_gate",
        "070_postgresql_authentication_assertion_gate",
    ),
    (
        "070_postgresql_trust_gate.sql",
        "070_postgresql_authentication_assertion_gate.sql",
    ),
    (
        "096_monitoring_subscriptions_and_provider_delivery_state",
        "096_monitoring_subscriptions_and_delivery_state",
    ),
    (
        "096_monitoring_subscriptions_and_provider_delivery_state.sql",
        "096_monitoring_subscriptions_and_delivery_state.sql",
    ),
    (
        "097_provider_integration_outbox",
        "097_external_integration_outbox",
    ),
    (
        "097_provider_integration_outbox.sql",
        "097_external_integration_outbox.sql",
    ),
    (
        "trust-and-decision-engine-model.md",
        "authentication-and-authorization-evaluation-model.md",
    ),
    (
        "provider-neutral-observability.md",
        "external-system-independent-observability.md",
    ),

    # Governed-scope SQL identifiers.
    ("jurisdiction_authority_id", "governed_scope_authority_id"),
    ("jurisdiction_authorities", "governed_scope_authorities"),
    ("jurisdiction_id", "governed_scope_id"),
    ("jurisdiction_key", "governed_scope_key"),
    ("jurisdiction_type", "governed_scope_type"),
    ("organization.jurisdictions", "organization.governed_scopes"),
    ("jurisdictions_", "governed_scopes_"),
    ("jurisdiction_authority_", "governed_scope_authority_"),

    # Authentication assertion terminology.
    ("assert_trust_assertion_available", "consume_authentication_assertion"),
    ("trust_assertion_id", "authentication_assertion_id"),
    ("trust_assertions", "authentication_assertions"),
    ("Trust Assertions", "Authentication Assertions"),
    ("Trust Assertion", "Authentication Assertion"),
    ("trust assertions", "authentication assertions"),
    ("trust assertion", "authentication assertion"),
    ("Provider Evidence", "Received Authentication Assertion"),
    ("provider evidence", "received authentication assertion"),
    ("provider assertion nonce", "source authentication assertion nonce"),
    (
        "provider-specific verification layer",
        "trust-provider-specific authentication verification component",
    ),
    (
        "Provider-specific signature verification",
        "Trust-provider-specific signature verification",
    ),
    (
        "provider-specific signature verification",
        "trust-provider-specific signature verification",
    ),
    ("verification evidence", "verification material"),
    ("provider expiration", "source assertion expiration"),

    # External-system integration terminology.
    ("provider_contract_id", "integration_contract_id"),
    ("provider_contracts", "integration_contracts"),
    ("provider_name", "external_system_name"),
    ("Provider integration outbox", "External integration outbox"),
    ("provider integration outbox", "external integration outbox"),
    ("provider delivery state", "delivery state"),
    ("Provider delivery state", "Delivery state"),
    ("Provider-Neutral", "External-System-Independent"),
    ("provider-neutral", "external-system-independent"),
    ("Platform Provider Streaming Service", "Platform Event Export Service"),
    ("Future Provider Adapters", "Future External-System Adapters"),
    ("Future Providers", "Future Destinations"),
    (
        "Provider adapters and workers",
        "External-system adapters and delivery workers",
    ),
    (
        "provider adapters and workers",
        "external-system adapters and delivery workers",
    ),

    # Evaluation terminology.
    (
        "Trust and Decision Engine",
        "Authentication and Authorization Evaluation",
    ),
    ("Go Decision Evaluation", "Go Authorization Evaluation"),
    ("Decision Engine", "Authorization Evaluation Process"),
    ("decision engine", "authorization evaluation process"),
    ("Justification Chain", "Decision Explanation Chain"),
    ("justification chain", "decision explanation chain"),
    ("engine_name", "evaluator_name"),
    ("engine_version", "evaluator_version"),
    ("Engine versions", "Evaluator versions"),
    ("engine versions", "evaluator versions"),

    # Shared module terminology.
    ("Operational Resources", "Shared Resources"),
    ("operational resources", "shared resources"),

    # Natural-language governed scope, after structural replacements.
    ("Organizations and jurisdictions", "Organizations and governed scopes"),
    ("organizations and jurisdictions", "organizations and governed scopes"),
    ("Organization and Jurisdiction", "Organization and Governed Scope"),
    ("organization and jurisdiction", "organization and governed scope"),
    ("Jurisdiction Authority", "Governed Scope Authority"),
    ("jurisdiction authority", "governed scope authority"),
    ("Jurisdictions", "Governed Scopes"),
    ("jurisdictions", "governed scopes"),
    ("Jurisdiction", "Governed Scope"),
    ("jurisdiction", "governed scope"),
]

# Longest first prevents shorter tokens from blocking a longer rewrite.
replacement_pairs.sort(key=lambda pair: len(pair[0]), reverse=True)

for path in text_files:
    original = read(path)
    updated = original

    for old, new in replacement_pairs:
        updated = updated.replace(old, new)

    if updated != original:
        write(path, updated)
        print(f"Updated terminology: {path.relative_to(root)}")

# Targeted SQL names where "provider" has a different, qualified meaning.
monitoring_sql = (
    root
    / "sql/schema/migrations/foundation/"
      "096_monitoring_subscriptions_and_delivery_state.sql"
)
monitoring_text = read(monitoring_sql)
monitoring_text = monitoring_text.replace("provider_type", "destination_type")
monitoring_text = monitoring_text.replace(
    "provider_reference",
    "destination_reference",
)
monitoring_text = monitoring_text.replace(
    "Monitoring subscriptions and provider delivery state",
    "Monitoring subscriptions and delivery state",
)
monitoring_text = monitoring_text.replace(
    "monitoring subscriptions and provider delivery state",
    "monitoring subscriptions and delivery state",
)
write(monitoring_sql, monitoring_text)

integration_sql = (
    root
    / "sql/schema/migrations/foundation/097_external_integration_outbox.sql"
)
integration_text = read(integration_sql)
integration_text = integration_text.replace(
    "CREATE TABLE integration.integration_contracts",
    "CREATE TABLE integration.integration_contracts",
)
write(integration_sql, integration_text)

# Clarify the authentication assertion migration without implementing Phase 1.
assertion_sql = (
    root
    / "sql/schema/migrations/foundation/"
      "070_postgresql_authentication_assertion_gate.sql"
)
assertion_text = read(assertion_sql)
assertion_text = assertion_text.replace(
    "-- Title: PostgreSQL Trust Gate",
    "-- Title: PostgreSQL Authentication Assertion Gate",
)
assertion_text = assertion_text.replace(
    "-- PostgreSQL Trust Gate",
    "-- PostgreSQL Authentication Assertion Gate",
)
assertion_text = assertion_text.replace(
    "Store provider-issued Authentication Assertions",
    "Store externally issued Authentication Assertions received from configured trust providers",
)
assertion_text = assertion_text.replace(
    "A later -- trust-provider-specific authentication verification component",
    "A later -- trust-provider-specific authentication verification component",
)
assertion_text = assertion_text.replace(
    "Provider-issued, audience-bound, environment-bound, time-bound, single-use Authentication Assertions.",
    "Externally issued, audience-bound, environment-bound, time-bound Authentication Assertions received from configured trust providers.",
)
assertion_text = assertion_text.replace(
    "Provider signature bytes retained for verification material and later review.",
    "Signature bytes supplied with the Authentication Assertion and retained for controlled verification and authorized audit review.",
)
assertion_text = assertion_text.replace(
    "PostgreSQL trust gate",
    "PostgreSQL authentication assertion gate",
)
write(assertion_sql, assertion_text)

# Add explicit comments to the governed-scope migration.
scope_sql = (
    root
    / "sql/schema/migrations/foundation/"
      "030_organizations_and_governed_scopes.sql"
)
scope_text = read(scope_sql)
comment_marker = "-- Domain-neutral governed-scope definitions"
if comment_marker not in scope_text:
    registration_marker = "SELECT foundation_meta.register_migration("
    if registration_marker not in scope_text:
        raise UpdateError(
            "Migration 030 registration marker was not found"
        )

    comments = """\
-- Domain-neutral governed-scope definitions
COMMENT ON TABLE organization.governed_scopes IS
    'A domain-neutral legal, administrative, geographic, organizational, contractual, data, or service boundary used by policy and authority evaluation. Modules specialize governed_scope_type.';

COMMENT ON COLUMN organization.governed_scopes.governed_scope_type IS
    'A governed type key. JURISDICTION may be used by a module, but it is not the universal Foundation meaning.';

COMMENT ON TABLE organization.governed_scope_authorities IS
    'Effective-dated organizational authority within one governed scope and purpose.';
"""
    scope_text = scope_text.replace(
        registration_marker,
        comments + "\n" + registration_marker,
        1,
    )
write(scope_sql, scope_text)

# Rewrite key normative documents rather than leaving mechanical prose.
terminology_document = """\
# Foundation Terminology and Domain Neutrality

> **Document status:** Normative Platform Foundation architecture.
>
> **Purpose:** Preserve terms that remain clear across public safety, municipal government, schools, finance, public works, utilities, human resources, permitting, records, and future module families.

## Five-Year Clarity Rule

A Foundation term must remain understandable to a maintainer who did not participate in its original design.

A term is acceptable only when:

1. Its meaning is defined in this document or a linked normative model.
2. It identifies one concept rather than several unrelated concepts.
3. Its database name does not imply a domain restriction that the Foundation does not have.
4. Its security meaning does not depend on informal team knowledge.
5. A module can specialize it without changing the Foundation meaning.

When a shorter term is ambiguous, the Foundation uses the longer explicit term.

## Domain-Neutral Foundation Rule

Public safety is the initial module family and a demanding source of requirements.

It does not define the limits of the Platform Foundation.

A concept belongs in the Foundation only when it:

- Establishes a shared trust, identity, authorization, accountability, governance, resilience, observability, or integration boundary;
- Is reusable across unrelated module families; or
- Provides a neutral extension point that modules specialize.

Domain records such as dispatch incidents, criminal cases, evidence custody, permits, invoices, student records, work orders, payroll records, or utility accounts belong to modules.

## Canonical Terms

### Platform Foundation

The shared domain-neutral layer that supplies cross-module security, governance, operational integrity, and integration capabilities.

### Module

A bounded set of domain functionality with explicit data ownership and controlled dependencies on Foundation capabilities.

### Module Family

A related group of modules, such as public safety, municipal administration, education, finance, public works, or utilities.

### Shared Resource

A reusable record representing a person, asset, facility, vehicle, equipment item, location, qualification, schedule, or another capability used by more than one module.

A Shared Resource is not automatically an authorization subject or a protected resource target.

### Organization

A stable legal, administrative, contractual, or operational entity.

An Organization is not inferred from a hostname, email domain, deployment, or database role.

### Organizational Unit

An internal subdivision of one Organization.

### Platform Service

A logical software capability governed by the Platform Foundation.

It does not mean a municipal public service, an operating-system daemon, or an external vendor unless a document explicitly says so.

### Deployment

A concrete running instance or environment of one Platform Service.

### Governed Scope

A stable, typed boundary used to constrain policy, authority, eligibility, approval, data handling, or a protected operation.

A Governed Scope may represent:

- A legal authority boundary;
- A geographic service area;
- A school district or campus;
- A department or facility;
- A taxing, utility, or regulatory district;
- A data-residency boundary;
- A contractual boundary;
- Another module-defined boundary.

`JURISDICTION` is a permitted module-defined `governed_scope_type`. It is not the universal Foundation field name.

### Protected Resource Target

The exact record, resource, bounded collection, or operation target affected by an authorization decision.

The word “resource” by itself is insufficient when it could mean a Shared Resource, compute resource, database object, or protected target.

### Governed Purpose

A versioned reason category recognized by authorization policy.

Free-form explanatory text may supplement a Governed Purpose but does not replace it.

### Governed Operation

A stable operation key recognized by authorization policy and implemented by a controlled operation.

### Authentication Assertion

An externally issued set of authentication claims received from a configured Trust Provider.

Its lifecycle state determines whether it is merely received, verified, rejected, expired, revoked, or consumed.

The presence of an Authentication Assertion does not grant authorization.

### Trust Provider

A configured authority that issues or validates identity, device, certificate, or authentication claims under an explicit trust configuration.

The word “provider” must not be used alone when Trust Provider is intended.

### Authorization Evaluation Process

The complete governed process that evaluates request context, applicable policy, identity, device, organization, eligibility, session, purpose, operation, governed scope, classification, authority, separation of duties, approval, lease state, and database-boundary requirements.

This term describes a process. It does not require one monolithic software component.

### Authority Definition

A governed capability recognized by the platform.

### Authority Grant

An effective-dated, revocable assignment of one Authority Definition to an identity within explicit scope.

### Access Eligibility

A current organizational or service condition that makes an identity eligible for authorization evaluation.

Eligibility is not authority.

### Approval

An attributable policy input recorded by an authorized and, when required, independent actor.

Approval is not authority.

### Authorization Lease

A short-lived, revocable, scope-bound authorization capability issued after a successful authorization evaluation.

### Protected Operation

A narrowly defined operation that may change or disclose protected state only through a controlled database or service path.

### Decision Record

The attributable record of one authorization or other material platform decision, including its exact context, policy versions, stage results, reason codes, and final result.

### Decision Explanation Chain

The ordered evaluation and supporting-record structure that explains why a Decision Record reached its final result.

### Data Classification

A governed data-handling category.

The word “classification” alone is allowed only when the surrounding context unambiguously refers to Data Classification.

### Assurance Artifact

A controlled document, test result, assessment output, attestation, log extract, or other artifact used to demonstrate control implementation or effectiveness.

Do not use the unqualified word “evidence” when Assurance Artifact is intended.

### Decision Supporting Record

A versioned record referenced by an authorization evaluation to support one stage result.

### External Monitoring System

A system such as a metrics collector, log platform, SIEM, or alerting platform that consumes canonical telemetry.

### Delivery Destination

One configured endpoint or external system to which canonical telemetry or integration events are delivered.

### Integration Contract

A versioned contract defining how one external system exchanges records or events with the platform.

### External-System Adapter

A replaceable component that translates between canonical platform records and an Integration Contract.

## Prohibited or Restricted Terms

### Provider Evidence

Prohibited.

Use **Authentication Assertion** for externally issued authentication claims.

Use **Assurance Artifact** for control-assurance material.

Use **Decision Supporting Record** for a record used by an evaluation.

### Trust Assertion

Prohibited because it can imply that the assertion is trusted merely because it exists.

Use **Authentication Assertion** and state its lifecycle status explicitly.

### Jurisdiction as a Foundation Field

Prohibited.

Use **Governed Scope**.

A module may use `JURISDICTION` as a governed scope type.

### Provider Without Qualification

Avoid.

Use the exact category:

- Trust Provider
- External Monitoring System
- Delivery Destination
- Integration Contract
- External-System Adapter
- Identity provider only when discussing an external identity protocol role

### Decision Engine

Avoid because it can mean either a conceptual process or a specific monolithic component.

Use **Authorization Evaluation Process** for the process.

Name a concrete software component by its actual service or package name.

### Operational Validation

Avoid unless the exact conditions being validated are listed.

Use the specific stage or rule name.

### Scope

Avoid when the type of scope matters.

Use Governed Scope, organization scope, service scope, approval scope, authority scope, classification scope, or protected target scope.

### Resource

Avoid when the kind of resource matters.

Use Shared Resource, compute resource, storage resource, database object, or Protected Resource Target.

### Evidence

Avoid when the category matters, especially because an Evidence and Property module may use “evidence” in a legal or custodial sense.

Use Authentication Assertion, Assurance Artifact, Decision Supporting Record, diagnostic record, source record, or another explicit category.

## SQL Naming Rules

Foundation SQL uses:

```text
governed_scope_id
governed_scope_key
governed_scope_type
organization.governed_scopes
organization.governed_scope_authorities

authentication_assertion_id
access_control.authentication_assertions
access_control.consume_authentication_assertion

integration_contract_id
integration.integration_contracts
external_system_name

destination_type
destination_reference

evaluator_name
evaluator_version
```

Names that encode one module’s vocabulary are not used as universal Foundation identifiers.

## Change Review Rule

Every Foundation review must ask:

1. Would this term make sense in a public-safety module?
2. Would it also make sense in a school, finance, permitting, public-works, utility, or human-resources module?
3. Does the term identify one security meaning?
4. Is a generic word hiding an authorization-critical distinction?
5. Could a new maintainer understand the term without oral history?

A “no” or uncertain answer requires the term to be clarified before the stage is accepted.
"""

organization_document = """\
# Platform Organization and Governed Scope Model

> **Document status:** Normative Platform Foundation architecture.

## Purpose

Define organizations, organizational units, explicit relationships, governed scopes, ownership roles, and authority boundaries without assuming one operational domain.

## Organization

An Organization is an independently identifiable legal, administrative, contractual, or operational entity with a stable identifier.

Names may change without changing identity.

Examples include:

- Municipality
- County
- School district
- School
- Department
- Public authority
- Utility
- Emergency-services organization
- Contracted service organization
- Regional consortium

## Organizational Unit

An Organizational Unit is an internal subdivision of one Organization.

Examples include a department, bureau, office, school, campus, division, team, station, or program.

A parent Organizational Unit must belong to the same Organization.

## Organizational Roles

The Foundation distinguishes roles such as:

- Platform Operator
- Service Owner
- Participating Organization
- Employing Organization
- Identity Authority
- Technical Authority
- Personnel Authority
- Access Sponsor
- Supervisory Authority
- Data Owner
- Data Custodian
- Governed Scope Authority

No role is inferred from another.

Hosting a service does not imply ownership of the service, data, identities, or governed scopes.

## Organization Relationships

Relationships are explicit, typed, effective-dated, and historically preserved.

Examples include:

```text
OPERATES_PLATFORM_FOR
OWNS_SERVICE_FOR
PARTICIPATES_IN_SERVICE
PROVIDES_TECHNICAL_SERVICES_FOR
PROVIDES_PERSONNEL_ADMINISTRATION_FOR
HOLDS_DATA_CUSTODY_FOR
OWNS_DATA_FOR
SUPERVISES_ASSIGNMENTS_FOR
DELEGATES_AUTHORITY_TO
```

A relationship does not create authority beyond its exact type and scope.

## Governed Scope

A Governed Scope is a stable, typed boundary used by policy, authority, eligibility, approval, classification, or a protected operation.

It is separate from Organization.

Governed Scopes may overlap and may be hierarchical when the scope type permits hierarchy.

Examples include:

- Legal authority boundary
- Geographic service area
- Response area
- School district
- Campus
- Department
- Facility
- Taxing district
- Utility district
- Regulatory area
- Data-residency area
- Contractual service boundary

A public-safety or municipal module may define `JURISDICTION` as one `governed_scope_type`.

The Foundation does not assume that every Governed Scope is legal, geographic, or governmental.

## Governed Scope Authority

Governed Scope Authority associates one Organization with authority inside one Governed Scope for one explicit purpose and effective period.

Examples of purpose categories include:

- Service administration
- Record creation
- Data ownership
- Data custody
- Financial approval
- Permitting
- Inspection
- Student administration
- Emergency response
- Mutual assistance

Authority for one purpose does not imply authority for another.

## Scope Intersection

Effective authority remains inside the intersection of all applicable constraints, including:

- Requested Governed Scope
- Organization participation
- Access Eligibility
- Authority Grant
- Approval
- Data Classification
- Protected Resource Target
- Session
- Policy
- Time

An empty intersection results in denial.

## Historical Preservation

Renames, mergers, splits, transfers, boundary changes, and dissolution do not rewrite historical context.

A historical Decision Record references the exact Organization and Governed Scope records and versions used at evaluation time.

## Architectural Invariants

1. Organizations use stable identifiers.
2. Organization names are not identity.
3. Organizational Units cannot cross Organization boundaries.
4. Platform Operator, Service Owner, Data Owner, and Data Custodian remain distinct.
5. Governed Scope is separate from Organization.
6. Overlapping Governed Scopes are supported.
7. `JURISDICTION` is a module-defined Governed Scope type, not a universal Foundation field.
8. Relationships and authorities are effective-dated and historically preserved.
9. Hosting does not imply ownership or authority.
10. PostgreSQL independently verifies Organization and Governed Scope claims used by protected operations.
"""

authentication_document = """\
# Platform Authentication and Authorization Evaluation Model

> **Document status:** Normative Platform Foundation architecture.

## Purpose

Define how the Foundation receives authentication claims, validates identity and device context, evaluates bounded authority, and records the complete basis for each material result.

## Distinct Security Questions

The Foundation answers separate questions:

```text
Was an Authentication Assertion received?
Was it verified under the configured Trust Provider?
Is the device trusted?
Which identity was authenticated?
Is the Organization participating?
Is the identity currently eligible?
Is the session active?
Is the Governed Purpose permitted?
Is the Governed Operation permitted?
Does the requested Governed Scope match?
Is the Data Classification compatible?
Is an Authority Grant active?
Is separation of duties satisfied?
Are required approvals satisfied?
Is the Authorization Lease valid for this exact operation?
May the protected operation proceed?
```

A successful answer to one question does not imply success for another.

## Authentication Assertions

An Authentication Assertion is an externally issued set of authentication claims received from a configured Trust Provider.

Lifecycle state determines whether it is:

```text
RECEIVED
VERIFIED
CONSUMED
REJECTED
EXPIRED
REVOKED
```

Only a verified, current, context-matching assertion may be consumed.

An Authentication Assertion is an input to authorization. It does not grant authorization.

## Assurance Is Not Authorization

A valid certificate, successful MFA result, verified Authentication Assertion, trusted device, or active session increases confidence in identity context.

None independently proves:

- Organizational participation
- Access Eligibility
- Authority
- Governed Purpose
- Governed Operation
- Governed Scope
- Approval
- Data Classification compatibility
- Authorization Lease validity
- Permission to perform the protected operation

## Authorization Evaluation Process

The Authorization Evaluation Process is the governed sequence of stage evaluations.

It is not required to exist as one monolithic service.

A typical flow is:

```text
Request
    ↓
Authentication Assertion Verification
    ↓
Device and Identity Resolution
    ↓
Session Validation
    ↓
Organization Participation and Access Eligibility
    ↓
Governed Purpose, Operation, Scope, Target, and Classification
    ↓
Authority and Separation of Duties
    ↓
Independent Approval
    ↓
Authorization Policy Evaluation
    ↓
Authorization Lease
    ↓
Controlled PostgreSQL Operation
    ↓
Decision Record and Decision Explanation Chain
```

## Evaluation States

Every governed stage returns exactly one result:

```text
PASS
FAIL
NOT_REQUIRED
NOT_EVALUATED
```

- `PASS` requires authoritative supporting records.
- `FAIL` records the examined state, required state, and stable reason code.
- `NOT_REQUIRED` references the exact policy rule making the stage unnecessary.
- `NOT_EVALUATED` records why evaluation did not occur.

A required `FAIL` or `NOT_EVALUATED` denies the request.

## Application Responsibilities

The future application layer may:

- Validate transport security and configured certificate chains
- Validate external authentication protocols
- Perform revocation checks
- Resolve device and identity candidates
- Gather exact authoritative record identifiers
- Evaluate application workflow conditions
- Request an Authorization Lease
- Coordinate approval workflows
- Record application-stage evaluations

It must not create database authority by supplying unverified:

- Role names
- Boolean authorization flags
- Identity identifiers
- Device identifiers
- Client timestamps
- Free-form scope
- Unversioned policy names

## PostgreSQL Responsibilities

PostgreSQL independently verifies the minimum conditions required by a controlled protected operation, including applicable:

- Authentication Assertion state, context, lifetime, and replay state
- Device and certificate state
- Identity state
- Organization participation
- Access Eligibility
- Session state
- Governed Purpose
- Governed Operation
- Governed Scope
- Data Classification
- Authority Grant
- Separation of duties
- Approval
- Policy version
- Authorization Lease scope, time, revocation, and use state

## No Unrestricted Operational Identity

Except for the unavoidable infrastructure-superuser boundary, no application, user, administrator, or accumulated role set independently controls all of:

- Identity lifecycle
- Device trust
- Organization administration
- Policy activation
- Approval
- Authority granting
- Protected data access
- Decision Record administration
- Audit review
- Operational execution

## Architectural Invariants

1. Received Authentication Assertions are not treated as verified merely because they exist.
2. Authentication establishes identity context, not authority.
3. Certificates and MFA do not grant access by themselves.
4. Every required stage has a persistent result.
5. PostgreSQL independently verifies selected application-supplied claims.
6. Required `NOT_EVALUATED` fails closed.
7. Accumulated authority and incompatible grants are evaluated.
8. Every final material result is reconstructable from persistent records.
"""

observability_document = """\
# Architecture Decision: External-System-Independent Observability

> **Decision status:** Accepted Foundation direction.

## Decision

The Platform Foundation maintains canonical health, metric, performance, integration, and operational event records independently of any external monitoring system or vendor.

A future Observability Subscription Service may translate canonical telemetry for configured Delivery Destinations such as:

- Zabbix
- OpenMetrics-compatible collectors
- Syslog receivers
- Webhooks
- SIEM platforms
- Other external monitoring systems

## Defined Terms

- **External Monitoring System:** A system that consumes canonical telemetry.
- **Delivery Destination:** One configured endpoint that receives telemetry.
- **External-System Adapter:** A replaceable translator between canonical telemetry and one destination protocol.
- **Integration Contract:** The versioned delivery contract used by an adapter.

The unqualified word “provider” is not used for these concepts.

## Reasons

- External monitoring systems may change.
- Self-hosted and commercial systems must be treated consistently.
- Failure of an external system must not affect core operations.
- Generic infrastructure alerts often lack ownership and operational context.
- Workloads, versions, owners, query fingerprints, and user impact must remain attributable.
- Monitoring data follows Data Classification, retention, and access policy.
- An external-system-specific schema must not become canonical.

## Consequences

- External-System Adapters use versioned Integration Contracts.
- Telemetry volume and cardinality are bounded.
- Delivery state is tracked per Delivery Destination and payload.
- Delivery retries use backpressure and defined limits.
- Canonical health records remain available when a destination is unavailable.
- External monitoring systems remain replaceable consumers rather than sources of truth.
"""

write(
    root / "docs/architecture/foundation/"
           "foundation-terminology-and-domain-neutrality.md",
    terminology_document,
)
write(
    root / "docs/architecture/foundation/"
           "organization-and-governed-scope-model.md",
    organization_document,
)
write(
    root / "docs/architecture/foundation/"
           "authentication-and-authorization-evaluation-model.md",
    authentication_document,
)
write(
    root / "docs/architecture/"
           "external-system-independent-observability.md",
    observability_document,
)

# Root README: add or replace the long-term domain-neutral scope statement.
root_readme = root / "README.md"
root_text = read(root_readme)
platform_scope_section = """\
## Platform Scope and Long-Term Direction

The repository began with public safety as its first operational focus.

Public safety remains the planned first module family, but it does not define the limits of the Platform Foundation.

The Platform Foundation is domain-neutral. It provides shared trust, identity, authorization, approval, Decision Record, governance, compliance, resilience, observability, integration, and resource-control capabilities for unrelated module families.

Future module families may include:

- Public safety
- Municipal administration
- Finance and budgeting
- Human resources
- Permitting and licensing
- Code enforcement
- Property and asset management
- Fleet and public works
- Utility operations and billing
- School and educational administration
- Other local-government or institutional services

Domain-specific records and workflows belong in their modules.

The Foundation contains only broadly reusable concepts or neutral extension points. A legal or geographic authority boundary, for example, is represented by a Governed Scope whose module-defined type may be `JURISDICTION`; it is not imposed as a universal Foundation concept.

The long-term objective is to let small municipalities, schools, and similar organizations add or replace operational modules without rebuilding the security and governance foundation for every application.
"""

root_text = replace_section(
    root_text,
    "## Platform Scope and Long-Term Direction",
    platform_scope_section,
)
if "## Platform Scope and Long-Term Direction" not in root_text:
    root_text = insert_before_first_heading(
        root_text,
        [
            "## Project Direction",
            "## Current Development Stage",
            "# Architectural Philosophy",
            "# Platform Architecture",
        ],
        platform_scope_section,
    )

# Generalize fixed public-safety module migration ranges.
root_text = re.sub(
    r"(?m)^\s*100-199\s+Shared Resources\s*$"
    r"(?:\n\s*200-299\s+CAD\s*$"
    r"\n\s*300-399\s+RMS\s*$"
    r"\n\s*400-499\s+Evidence\s*/\s*Property\s*$"
    r"\n\s*500-599\s+Personnel Management Extensions\s*$"
    r"\n\s*600-699\s+Fleet Management Extensions\s*$"
    r"\n\s*700-799\s+Fire\s*/\s*EMS Specific\s*$"
    r"\n\s*800-899\s+Future Modules\s*$)?",
    "    100-199  Shared resources and cross-module capabilities\n"
    "    200-899  Module-owned migrations allocated by an approved module-range decision",
    root_text,
)

root_range_rows_pattern = re.compile(
    r"(?m)^\| `100[–-]199` \|.*\|\n"
    r"^\| `200[–-]299` \|.*\|\n"
    r"^\| `300[–-]399` \|.*\|\n"
    r"^\| `400[–-]499` \|.*\|\n"
    r"^\| `500[–-]599` \|.*\|\n"
    r"^\| `600[–-]699` \|.*\|\n"
    r"^\| `700[–-]799` \|.*\|\n"
    r"^\| `800[–-]899` \|.*\|"
)
root_text = root_range_rows_pattern.sub(
    "| `100–199` | Shared resources and cross-module capabilities |\n"
    "| `200–899` | Module-owned migrations allocated by an approved module-range decision |",
    root_text,
    count=1,
)
write(root_readme, root_text)

# Migration map: replace the module-specific range allocation.
migration_map_path = (
    root / "docs/architecture/foundation/sql-migration-map.md"
)
migration_map = read(migration_map_path)
range_rows_pattern = re.compile(
    r"(?m)^\| `100[–-]199` \|.*\|\n"
    r"^\| `200[–-]299` \|.*\|\n"
    r"^\| `300[–-]399` \|.*\|\n"
    r"^\| `400[–-]499` \|.*\|\n"
    r"^\| `500[–-]599` \|.*\|\n"
    r"^\| `600[–-]699` \|.*\|\n"
    r"^\| `700[–-]799` \|.*\|\n"
    r"^\| `800[–-]899` \|.*\|"
)
replacement_rows = (
    "| `100–199` | Shared resources and cross-module capabilities |\n"
    "| `200–899` | Module-owned migrations allocated by an approved module-range decision |"
)
migration_map = range_rows_pattern.sub(
    replacement_rows,
    migration_map,
    count=1,
)
write(migration_map_path, migration_map)

# Foundation index: link the terminology contract and use the renamed files.
foundation_index_path = (
    root / "docs/architecture/foundation/README.md"
)
foundation_index = read(foundation_index_path)

terminology_link = (
    "- [Foundation Terminology and Domain Neutrality]"
    "(foundation-terminology-and-domain-neutrality.md)"
)
if terminology_link not in foundation_index:
    anchor = "### Boundaries, Trust, and Database Enforcement"
    if anchor in foundation_index:
        foundation_index = foundation_index.replace(
            anchor,
            anchor + "\n\n" + terminology_link,
            1,
        )
    else:
        foundation_index += "\n\n" + terminology_link + "\n"

authorization_contract_link = (
    "- [Authorization Evaluation Contract]"
    "(authorization-evaluation-contract.md)"
)
if authorization_contract_link not in foundation_index:
    anchor = "### Approval and Authorization"
    if anchor in foundation_index:
        foundation_index = foundation_index.replace(
            anchor,
            anchor + "\n\n" + authorization_contract_link,
            1,
        )
    else:
        foundation_index += "\n\n" + authorization_contract_link + "\n"

domain_rule = (
    "16. Domain-specific concepts belong in modules; the Foundation uses "
    "neutral shared concepts and extension points."
)
if domain_rule not in foundation_index:
    principles_match = re.search(
        r"(?ms)(## Non-Negotiable Principles\n.*?)(?=\n## )",
        foundation_index,
    )
    if principles_match:
        principles = principles_match.group(1).rstrip() + "\n" + domain_rule
        foundation_index = (
            foundation_index[: principles_match.start(1)]
            + principles
            + foundation_index[principles_match.end(1):]
        )

write(foundation_index_path, foundation_index)

# Authorization contract: eliminate ambiguous authentication wording and
# ensure the domain-neutral scope term is explicit.
contract_path = (
    root
    / "docs/architecture/foundation/authorization-evaluation-contract.md"
)
contract = read(contract_path)
contract = contract.replace(
    "An Authentication Assertion is evidence, not authorization.",
    "An Authentication Assertion supplies authentication claims; it does not grant authorization.",
)
contract = contract.replace(
    "Client-supplied time may be recorded as evidence",
    "Client-supplied time may be recorded as supporting context",
)
contract = contract.replace(
    "Provider credentials",
    "Credentials used to access external systems or trust services",
)
contract = contract.replace(
    "Non-authoritative provider evidence snapshots",
    "Non-authoritative source authentication-assertion snapshots",
)
contract = contract.replace(
    "The complete conceptual path is:\n\n```text\nReceived Authentication Assertion",
    "The complete conceptual path is:\n\n```text\nReceived Authentication Assertion",
)
write(contract_path, contract)

# Observability model: qualify integration terms.
obs_model_path = (
    root
    / "docs/architecture/foundation/"
      "observability-health-and-operational-telemetry-model.md"
)
if obs_model_path.exists():
    obs_model = read(obs_model_path)
    targeted_obs_replacements = [
        (
            "Monitoring systems such as",
            "External monitoring systems such as",
        ),
        (
            "future providers consume this telemetry",
            "future external monitoring systems consume this telemetry",
        ),
        (
            "Future Provider Adapters",
            "Future External-System Adapters",
        ),
        (
            "Provider and integration telemetry",
            "External-system integration telemetry",
        ),
        ("Provider identity", "External system identity"),
        (
            "subscribed providers",
            "configured Delivery Destinations",
        ),
        (
            "provider failure",
            "external monitoring system failure",
        ),
        (
            "provider replacement",
            "external monitoring system replacement",
        ),
        (
            "Provider agreement",
            "External-system agreement",
        ),
        (
            "Duplicate provider payloads",
            "Duplicate delivery payloads",
        ),
        (
            "Monitoring providers are replaceable consumers",
            "External monitoring systems are replaceable consumers",
        ),
        (
            "Provider failure cannot block core operations",
            "External monitoring system failure cannot block core operations",
        ),
    ]
    for old, new in targeted_obs_replacements:
        obs_model = obs_model.replace(old, new)
    write(obs_model_path, obs_model)

# Extend the existing Phase -1 behavioral test with the renamed model.
baseline_test_path = (
    root
    / "sql/test-framework/sql/tests/foundation/"
      "080_foundation_baseline_integrity.sql"
)
baseline_test = read(baseline_test_path)
test_marker = "-- Domain-neutral governed-scope behavior"
if test_marker not in baseline_test:
    baseline_test += """\

-- Domain-neutral governed-scope behavior

INSERT INTO organization.governed_scopes (
    governed_scope_id,
    governed_scope_key,
    display_name,
    governed_scope_type,
    status,
    valid_from,
    created_by_reference
)
VALUES (
    '30000000-0000-0000-0000-000000000004',
    'sql_test.governed_scope',
    'SQL Test Governed Scope',
    'TEST_BOUNDARY',
    'ACTIVE',
    statement_timestamp() - interval '1 day',
    'sql-test'
);

INSERT INTO organization.governed_scope_authorities (
    governed_scope_authority_id,
    organization_id,
    governed_scope_id,
    authority_purpose,
    priority,
    valid_from,
    status,
    created_by_reference
)
VALUES (
    '30000000-0000-0000-0000-000000000005',
    '30000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000004',
    'SQL_TEST',
    100,
    statement_timestamp() - interval '1 day',
    'ACTIVE',
    'sql-test'
);

SELECT sql_test.assert_equal_bigint(
    'Governed scope authority is represented without a domain-specific boundary field',
    (
        SELECT count(*)
        FROM organization.governed_scope_authorities
        WHERE organization_id =
            '30000000-0000-0000-0000-000000000001'
          AND governed_scope_id =
            '30000000-0000-0000-0000-000000000004'
          AND authority_purpose = 'SQL_TEST'
    ),
    1
);
"""
write(baseline_test_path, baseline_test)

# Validate that SQL migration identifiers remain within PostgreSQL's
# unquoted-identifier limit when they are actual object names.
identifier_pattern = re.compile(
    r"(?ix)\b(?:"
    r"constraint|index|table|view|function|schema"
    r")\s+(?:[a-z_][a-z0-9_]*\.)?([a-z_][a-z0-9_]*)"
)
long_identifiers: list[str] = []

for sql_path in (
    root / "sql/schema/migrations/foundation"
).glob("*.sql"):
    sql_text = read(sql_path)
    for identifier in identifier_pattern.findall(sql_text):
        if len(identifier.encode("utf-8")) > 63:
            long_identifiers.append(
                f"{sql_path.relative_to(root)}: {identifier}"
            )

if long_identifiers:
    raise UpdateError(
        "Generated SQL identifiers exceed PostgreSQL's 63-byte limit:\n"
        + "\n".join(long_identifiers)
    )

# Structural vocabulary that must no longer exist anywhere in tracked text.
forbidden_tokens = [
    "030_organizations_and_jurisdictions",
    "030_organizations_and_jurisdictions.sql",
    "organization-and-jurisdiction-model.md",
    "organization.jurisdictions",
    "organization.jurisdiction_authorities",
    "jurisdiction_id",
    "jurisdiction_key",
    "jurisdiction_type",
    "jurisdiction_authority",
    "070_postgresql_trust_gate",
    "070_postgresql_trust_gate.sql",
    "trust_assertions",
    "trust_assertion_id",
    "assert_trust_assertion_available",
    "Trust Assertion",
    "trust assertion",
    "Provider Evidence",
    "provider evidence",
    "096_monitoring_subscriptions_and_provider_delivery_state",
    "097_provider_integration_outbox",
    "provider_contracts",
    "provider_contract_id",
    "provider_name",
    "provider-neutral-observability.md",
    "Platform Provider Streaming Service",
    "Decision Engine",
    "Justification Chain",
]

violations: list[str] = []

final_paths = run_git(
    "ls-files",
    "--cached",
    "--others",
    "--exclude-standard",
    "--",
    "README.md",
    "docs",
    "sql",
).splitlines()

final_paths = sorted({
    relative
    for relative in final_paths
    if not relative.startswith("sql/test-framework/sql/test-results/")
})

for relative in final_paths:
    if relative == (
        "docs/architecture/foundation/"
        "foundation-terminology-and-domain-neutrality.md"
    ):
        continue

    path = root / relative
    if not path.is_file():
        continue
    try:
        content = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue

    for token in forbidden_tokens:
        if token in content:
            for line_number, line in enumerate(content.splitlines(), 1):
                if token in line:
                    violations.append(
                        f"{relative}:{line_number}: forbidden token "
                        f"{token!r}: {line.strip()}"
                    )

# Lowercase/title-case natural-language governed scope must also be gone.
# The uppercase module type JURISDICTION is deliberately permitted.
natural_pattern = re.compile(r"\b[jJ]urisdictions?\b")
for relative in final_paths:
    if relative == (
        "docs/architecture/foundation/"
        "foundation-terminology-and-domain-neutrality.md"
    ):
        continue

    path = root / relative
    if not path.is_file():
        continue
    try:
        content = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue

    for line_number, line in enumerate(content.splitlines(), 1):
        line_without_allowed_type = line.replace("`JURISDICTION`", "")
        line_without_allowed_type = line_without_allowed_type.replace(
            "'JURISDICTION'",
            "",
        )
        if natural_pattern.search(line_without_allowed_type):
            violations.append(
                f"{relative}:{line_number}: use Governed Scope or the "
                f"explicit module type `JURISDICTION`: {line.strip()}"
            )

if violations:
    raise UpdateError(
        "Obsolete or ambiguous structural terminology remains:\n"
        + "\n".join(violations)
    )

# Verify every resulting text file has no trailing whitespace.
whitespace_violations: list[str] = []
for relative in final_paths:
    path = root / relative
    try:
        content = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue

    for line_number, line in enumerate(content.splitlines(), 1):
        if line.rstrip() != line:
            whitespace_violations.append(
                f"{relative}:{line_number}: trailing whitespace"
            )

if whitespace_violations:
    raise UpdateError(
        "Trailing whitespace was introduced:\n"
        + "\n".join(whitespace_violations)
    )

# Produce a reviewable audit of retained generic words. This is not a failure:
# the glossary gives them explicit meanings, and the report exposes contexts
# worth human review before commit.
audit_patterns = {
    "unqualified provider wording": re.compile(r"(?i)\bprovider\b"),
    "generic evidence wording": re.compile(r"(?i)\bevidence\b"),
    "untyped scope_reference": re.compile(r"\bscope_reference\b"),
    "generic resource wording": re.compile(r"(?i)\bresource\b"),
}

audit_lines = [
    "Public Safety Platform terminology audit",
    "========================================",
    "",
    "These retained terms require contextual review. Their presence is not",
    "automatically wrong; the normative glossary defines the approved meanings.",
    "",
]

for label, pattern in audit_patterns.items():
    audit_lines.append(label)
    audit_lines.append("-" * len(label))
    match_count = 0

    for relative in final_paths:
        path = root / relative
        if not path.is_file():
            continue
        try:
            content = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue

        for line_number, line in enumerate(content.splitlines(), 1):
            if pattern.search(line):
                audit_lines.append(
                    f"{relative}:{line_number}: {line.strip()}"
                )
                match_count += 1
                if match_count >= 150:
                    audit_lines.append(
                        "[output limited to first 150 matches]"
                    )
                    break
        if match_count >= 150:
            break

    if match_count == 0:
        audit_lines.append("[no matches]")
    audit_lines.append("")

write(audit_path, "\n".join(audit_lines))

print("Domain-neutral terminology and schema update completed.")
print(f"Terminology audit: {audit_path}")
PYTHON

printf '\nRunning source validation in the temporary worktree...\n'

bash -n sql/test-framework/sql/schema/scripts/test_foundation.sh

git add -A -- README.md docs sql
git reset -q -- sql/test-framework/sql/test-results 2>/dev/null || true

git diff --cached --check

printf '\nChecking renamed paths and manifest entries...\n'

expected_new_paths=(
    "docs/architecture/foundation/foundation-terminology-and-domain-neutrality.md"
    "docs/architecture/foundation/organization-and-governed-scope-model.md"
    "docs/architecture/foundation/authentication-and-authorization-evaluation-model.md"
    "docs/architecture/external-system-independent-observability.md"
    "sql/schema/migrations/foundation/030_organizations_and_governed_scopes.sql"
    "sql/schema/migrations/foundation/070_postgresql_authentication_assertion_gate.sql"
    "sql/schema/migrations/foundation/096_monitoring_subscriptions_and_delivery_state.sql"
    "sql/schema/migrations/foundation/097_external_integration_outbox.sql"
)

for expected_new_path in "${expected_new_paths[@]}"; do
    if [[ ! -f "$expected_new_path" ]]; then
        printf 'Expected updated path not found: %s\n' "$expected_new_path" >&2
        exit 66
    fi
done

printf '\nTemporary-worktree changed files:\n'
git status --short -- \
    README.md \
    docs \
    sql \
    ':(exclude)sql/test-framework/sql/test-results/**'

printf '\nTemporary-worktree diff summary:\n'
git diff --cached --stat

if [[ "$run_tests" -eq 1 ]]; then
    printf '\nRunning the complete Foundation SQL test framework in the temporary worktree...\n\n'
    ./sql/test-framework/sql/schema/scripts/test_foundation.sh
else
    printf '\nPostgreSQL tests were skipped by request.\n'
    printf 'Run them before committing with:\n\n'
    printf '  ./sql/test-framework/sql/schema/scripts/test_foundation.sh\n'
fi

# The tests may create generated result files. They are intentionally excluded
# from the source patch.
git reset -q -- sql/test-framework/sql/test-results 2>/dev/null || true
git add -A -- README.md docs sql
git reset -q -- sql/test-framework/sql/test-results 2>/dev/null || true
git diff --cached --check

git diff \
    --cached \
    --binary \
    --full-index \
    HEAD \
    -- \
    README.md \
    docs \
    sql \
    ':(exclude)sql/test-framework/sql/test-results/**' \
    >"$patch_file"

if [[ ! -s "$patch_file" ]]; then
    printf 'The generated source patch is empty.\n' >&2
    exit 65
fi

printf '\nApplying the validated patch to the real checkout...\n'
cd "$source_repo_root"

git apply --check "$patch_file"
git apply "$patch_file"

printf '\nDomain-neutral Foundation update complete.\n'
printf 'Source baseline: latest origin/dev at %s\n' \
    "$(git rev-parse --short HEAD)"
printf 'Tracked-source backup: %s\n' "$backup_archive"
printf 'Validated patch: %s\n' "$patch_file"
printf 'Terminology audit: %s\n' "$audit_file"

printf '\nReal-checkout changed files:\n'
git status --short -- \
    README.md \
    docs \
    sql \
    ':(exclude)sql/test-framework/sql/test-results/**'

printf '\nReview before committing:\n\n'
printf '  git diff --check\n'
printf '  git diff -- README.md docs sql\n'
printf '  git status\n'

