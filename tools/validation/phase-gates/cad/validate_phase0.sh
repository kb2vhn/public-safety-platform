#!/usr/bin/env bash
#
# Iron Signal Platform CAD Phase 0 static documentation and registry gate.

set -uo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"

if [[ -z "$repo_root" ]]; then
    echo "FAIL: Repository is a Git work tree" >&2
    exit 1
fi

cd "$repo_root"

if ! command -v python3 >/dev/null 2>&1; then
    echo "FAIL: python3 is available" >&2
    exit 1
fi

python3 - "$repo_root" <<'PY'
from __future__ import annotations

import re
import sys
from urllib.parse import unquote
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:
    print("FAIL: Python PyYAML is available", file=sys.stderr)
    print("Install the distribution package that provides the Python yaml module.", file=sys.stderr)
    raise SystemExit(1)

repo = Path(sys.argv[1])
pass_count = 0
fail_count = 0

def passed(label: str) -> None:
    global pass_count
    print(f"PASS: {label}")
    pass_count += 1

def failed(label: str, detail: str | None = None) -> None:
    global fail_count
    if detail:
        print(f"FAIL: {label}: {detail}", file=sys.stderr)
    else:
        print(f"FAIL: {label}", file=sys.stderr)
    fail_count += 1

def check(condition: bool, label: str, detail: str | None = None) -> None:
    if condition:
        passed(label)
    else:
        failed(label, detail)

required_files = [
    "modules/CAD/README.md",
    "modules/CAD/docs/README.md",
    "modules/CAD/docs/architecture/README.md",
    "modules/CAD/docs/architecture/cad-phased-implementation-plan.md",
    "modules/CAD/docs/architecture/cad-testing-and-acceptance-model.md",
    "modules/CAD/docs/architecture/cad-testing-identifiers-and-authoritative-registries-model.md",
    "modules/CAD/docs/architecture/cad-test-campaign-accounting-model.md",
    "modules/CAD/docs/architecture/cad-test-oracle-and-side-effect-verification-model.md",
    "modules/CAD/docs/architecture/cad-test-execution-tiers-and-gate-cadence.md",
    "modules/CAD/docs/architecture/cad-test-evidence-retention-and-integrity-model.md",
    "modules/CAD/docs/architecture/cad-acceptance-record-model.md",
    "modules/CAD/docs/requirements/README.md",
    "modules/CAD/docs/requirements/dispatcher-capability-catalog.md",
    "modules/CAD/docs/requirements/cad-requirements-traceability-model.md",
    "modules/CAD/docs/acceptance/README.md",
    "modules/CAD/docs/acceptance/cad-phase-acceptance-record-template.md",
    "modules/CAD/requirements/README.md",
    "modules/CAD/requirements/cad-requirements.yaml",
    "modules/CAD/testing/README.md",
    "modules/CAD/testing/cad-controlled-operations.yaml",
    "modules/CAD/testing/cad-enforcement-points.yaml",
    "modules/CAD/testing/cad-hostile-classes.yaml",
    "modules/CAD/testing/test-oracles.yaml",
    "tools/validation/phase-gates/cad/README.md",
    "tools/validation/phase-gates/cad/validate_phase0.sh",
]

print("== Required files ==")
for rel in required_files:
    check((repo / rel).is_file(), f"File exists: {rel}")

yaml_paths = [
    "modules/CAD/requirements/cad-requirements.yaml",
    "modules/CAD/testing/cad-controlled-operations.yaml",
    "modules/CAD/testing/cad-enforcement-points.yaml",
    "modules/CAD/testing/cad-hostile-classes.yaml",
    "modules/CAD/testing/test-oracles.yaml",
]

registries: dict[str, dict[str, Any]] = {}

expected_registry_ids = {
    "modules/CAD/requirements/cad-requirements.yaml": "CAD-REG-REQUIREMENTS",
    "modules/CAD/testing/cad-controlled-operations.yaml": "CAD-REG-CONTROLLED-OPERATIONS",
    "modules/CAD/testing/cad-enforcement-points.yaml": "CAD-REG-ENFORCEMENT-POINTS",
    "modules/CAD/testing/cad-hostile-classes.yaml": "CAD-REG-HOSTILE-CLASSES",
    "modules/CAD/testing/test-oracles.yaml": "CAD-REG-TEST-ORACLES",
}

registry_ids: list[str] = []

print()
print("== YAML parsing and registry metadata ==")
for rel in yaml_paths:
    path = repo / rel
    try:
        with path.open("r", encoding="utf-8") as handle:
            data = yaml.safe_load(handle)
        check(isinstance(data, dict), f"YAML mapping: {rel}")
        if not isinstance(data, dict):
            continue
        registries[rel] = data
        check(str(data.get("schema_version")) == "1.0", f"Schema version 1.0: {rel}")
        check(data.get("module") == "CAD", f"CAD module identity: {rel}")
        check(data.get("owner") == "Iron Signal Systems", f"Owner identity: {rel}")
        check(data.get("status") == "DESIGN_ONLY", f"Design-only registry status: {rel}")
        registry_id = str(data.get("registry_id", ""))
        registry_ids.append(registry_id)
        check(
            registry_id == expected_registry_ids[rel],
            f"Expected registry identifier: {rel}",
            registry_id,
        )
        authority = data.get("authority")
        check(
            isinstance(authority, str) and (repo / authority).is_file(),
            f"Registry authority resolves: {rel}",
            str(authority),
        )
    except Exception as exc:
        failed(f"YAML parses: {rel}", str(exc))

requirements_rel = "modules/CAD/requirements/cad-requirements.yaml"
operations_rel = "modules/CAD/testing/cad-controlled-operations.yaml"
enforcement_rel = "modules/CAD/testing/cad-enforcement-points.yaml"
hostile_rel = "modules/CAD/testing/cad-hostile-classes.yaml"
oracles_rel = "modules/CAD/testing/test-oracles.yaml"

requirements = registries.get(requirements_rel, {}).get("requirements", [])
operations = registries.get(operations_rel, {}).get("entries", [])
enforcement_points = registries.get(enforcement_rel, {}).get("entries", [])
hostile_classes = registries.get(hostile_rel, {}).get("entries", [])
oracles = registries.get(oracles_rel, {}).get("entries", [])

print()
print("== Registry inventories ==")
check(isinstance(requirements, list), "Requirements registry has a list")
check(isinstance(operations, list), "Controlled-operations registry has a list")
check(isinstance(enforcement_points, list), "Enforcement-points registry has a list")
check(isinstance(hostile_classes, list), "Hostile-classes registry has a list")
check(isinstance(oracles, list), "Test-oracles registry has a list")

check(len(requirements) == 104, "Requirement inventory count = 104", str(len(requirements)))
check(len(operations) == 19, "Controlled-operation seed count = 19", str(len(operations)))
check(len(enforcement_points) == 16, "Enforcement-point seed count = 16", str(len(enforcement_points)))
check(len(hostile_classes) == 20, "Hostile-class seed count = 20", str(len(hostile_classes)))
check(len(oracles) == 4, "Test-oracle seed count = 4", str(len(oracles)))

def ids(entries: list[dict[str, Any]]) -> list[str]:
    return [str(entry.get("id", "")) for entry in entries if isinstance(entry, dict)]

requirement_ids = ids(requirements)
operation_ids = ids(operations)
enforcement_ids = ids(enforcement_points)
hostile_ids = ids(hostile_classes)
oracle_ids = ids(oracles)

print()
print("== Identifier uniqueness and namespaces ==")
all_ids = registry_ids + requirement_ids + operation_ids + enforcement_ids + hostile_ids + oracle_ids
check(len(registry_ids) == len(set(registry_ids)), "Registry identifiers are unique")
check(all(item.startswith("CAD-REG-") for item in registry_ids),
      "Registry identifiers use CAD-REG-")
check(len(all_ids) == len(set(all_ids)), "Identifiers are globally unique")
check(all(re.fullmatch(r"CAD-DSP-\d{3}", item) for item in requirement_ids),
      "Requirement identifiers use CAD-DSP-NNN")
check(all(item.startswith("CAD-OP-") for item in operation_ids),
      "Controlled-operation identifiers use CAD-OP-")
check(all(item.startswith("CAD-EP-") for item in enforcement_ids),
      "Enforcement-point identifiers use CAD-EP-")
check(all(item.startswith("CAD-HC-") for item in hostile_ids),
      "Hostile-class identifiers use CAD-HC-")
check(all(item.startswith("CAD-ORACLE-") for item in oracle_ids),
      "Oracle identifiers use CAD-ORACLE-")

print()
print("== Requirement catalog synchronization ==")
catalog_path = repo / "modules/CAD/docs/requirements/dispatcher-capability-catalog.md"
catalog_text = catalog_path.read_text(encoding="utf-8")
catalog_pairs = re.findall(r"\|\s*(CAD-DSP-\d+)\s*\|\s*(.*?)\s*\|", catalog_text)
catalog = {rid: statement for rid, statement in catalog_pairs}
check(len(catalog_pairs) == 104, "Catalog requirement row count = 104", str(len(catalog_pairs)))
check(len(catalog) == 104, "Catalog identifiers are unique")

registry_map = {
    str(entry.get("id")): str(entry.get("normative_text"))
    for entry in requirements
    if isinstance(entry, dict)
}
check(set(catalog) == set(registry_map), "Catalog and registry identifier sets match")
text_mismatches = [
    rid for rid, statement in catalog.items()
    if registry_map.get(rid) != statement
]
check(not text_mismatches, "Catalog and registry normative text matches",
      ", ".join(text_mismatches[:10]) if text_mismatches else None)
check(
    all(
        str(entry.get("title", "")).strip()
        == str(entry.get("normative_text", "")).strip().removesuffix(".")
        for entry in requirements
        if isinstance(entry, dict)
    ),
    "Requirement seed titles are complete and deterministic",
)

print()
print("== Honest lifecycle status ==")
check(all(entry.get("status") == "ACTIVE" for entry in requirements),
      "All seeded requirements are active design requirements")
check(all(entry.get("implementation_status") == "NOT_IMPLEMENTED" for entry in requirements),
      "All seeded requirements remain not implemented")
check(all(entry.get("test_status") == "NOT_TESTED" for entry in requirements),
      "All seeded requirements remain not tested")
check(all(entry.get("acceptance_status") == "NOT_EVALUATED" for entry in requirements),
      "All seeded requirements remain not evaluated")
check(all(entry.get("status") == "PROPOSED" for entry in operations),
      "All controlled operations remain proposed")
check(all(entry.get("implementation_status") == "NOT_IMPLEMENTED" for entry in operations),
      "All controlled operations remain not implemented")
check(all(entry.get("status") == "PROPOSED" for entry in enforcement_points),
      "All enforcement points remain proposed")
check(all(entry.get("status") == "PROPOSED" for entry in hostile_classes),
      "All hostile classes remain proposed")
check(all(entry.get("status") == "PROPOSED" for entry in oracles),
      "All test oracles remain proposed")
check(all(entry.get("implementation_status") == "NOT_IMPLEMENTED" for entry in oracles),
      "All test oracles remain not implemented")

print()
print("== Cross-registry references ==")
requirement_set = set(requirement_ids)
operation_set = set(operation_ids)
enforcement_set = set(enforcement_ids)

unknown_operation_sources: list[str] = []
unknown_operation_eps: list[str] = []
for operation in operations:
    oid = str(operation.get("id"))
    for source in operation.get("sources", []):
        if source not in requirement_set:
            unknown_operation_sources.append(f"{oid}->{source}")
    for ep in operation.get("enforcement_points", []):
        if ep not in enforcement_set:
            unknown_operation_eps.append(f"{oid}->{ep}")

check(not unknown_operation_sources, "Controlled-operation requirement references resolve",
      ", ".join(unknown_operation_sources[:10]) if unknown_operation_sources else None)
check(not unknown_operation_eps, "Controlled-operation enforcement-point references resolve",
      ", ".join(unknown_operation_eps[:10]) if unknown_operation_eps else None)

unknown_oracle_ops = [
    f"{entry.get('id')}->{entry.get('operation_id')}"
    for entry in oracles
    if entry.get("operation_id") not in operation_set
]
check(not unknown_oracle_ops, "Oracle controlled-operation references resolve",
      ", ".join(unknown_oracle_ops[:10]) if unknown_oracle_ops else None)

outcome_classes = set(registries.get(oracles_rel, {}).get("outcome_classes", []))
unknown_outcomes: list[str] = []
for oracle in oracles:
    for outcome in oracle.get("expected_outcomes", []):
        if outcome not in outcome_classes:
            unknown_outcomes.append(f"{oracle.get('id')}->{outcome}")
check(not unknown_outcomes, "Oracle outcome classes resolve",
      ", ".join(unknown_outcomes[:10]) if unknown_outcomes else None)
check(
    all("invariants" not in entry for entry in oracles if isinstance(entry, dict)),
    "Oracle seed does not use unresolved invariant identifiers",
)
check(
    all(
        isinstance(entry.get("provisional_invariant_statements"), list)
        and bool(entry.get("provisional_invariant_statements"))
        for entry in oracles
        if isinstance(entry, dict)
    ),
    "Oracle seed labels provisional invariant statements explicitly",
)

print()
print("== Documentation synchronization ==")
doc_checks = {
    "modules/CAD/README.md": [
        "## Current Assurance Metadata",
        "modules/CAD/requirements/cad-requirements.yaml",
        "modules/CAD/testing/test-oracles.yaml",
    ],
    "modules/CAD/docs/README.md": [
        "## Machine-Readable Assurance Registries",
        "CAD Test Campaign Accounting Model",
        "CAD Acceptance Record Model",
    ],
    "modules/CAD/docs/architecture/README.md": [
        "## Delivery, Assurance, and Acceptance",
        "CAD Testing Identifiers and Authoritative Registries Model",
        "CAD Test Evidence Retention and Integrity Model",
    ],
    "modules/CAD/docs/architecture/cad-testing-and-acceptance-model.md": [
        "## Authoritative Supporting Contracts",
        "The accounting model owns how attempts receive count credit.",
        "No subordinate document may reduce a minimum",
    ],
    "modules/CAD/docs/architecture/cad-phased-implementation-plan.md": [
        "stable assurance identifiers",
        "YAML registries parse",
        "Requirements and testing registries parse",
    ],
    "modules/CAD/docs/requirements/cad-requirements-traceability-model.md": [
        "The authoritative requirement register is:",
        "CAD-DSP-       Existing dispatcher capability requirement",
        "Phase 0 traceability may be accepted",
    ],
    "modules/CAD/docs/acceptance/README.md": [
        "No CAD implementation phase has been accepted",
        "CAD Phase Acceptance Record Template",
        "Automatic Blocking Conditions",
    ],
}
for rel, required_strings in doc_checks.items():
    content = (repo / rel).read_text(encoding="utf-8")
    for required in required_strings:
        check(required in content, f"Documentation contains required text: {rel}: {required}")

print()
print("== Local Markdown file targets ==")
link_pattern = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
external_scheme = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")

for rel in required_files:
    if not rel.endswith(".md"):
        continue

    path = repo / rel
    content = path.read_text(encoding="utf-8")
    unresolved: list[str] = []

    for raw_target in link_pattern.findall(content):
        raw_target = raw_target.strip()

        if raw_target.startswith("<") and ">" in raw_target:
            target = raw_target[1:raw_target.index(">")]
        else:
            target = raw_target.split(maxsplit=1)[0]

        target = unquote(target)
        target = target.split("#", 1)[0].split("?", 1)[0]

        if not target:
            continue
        if target.startswith("//") or external_scheme.match(target):
            continue

        if target.startswith("/"):
            resolved = (repo / target.lstrip("/")).resolve()
        else:
            resolved = (path.parent / target).resolve()

        try:
            resolved.relative_to(repo.resolve())
        except ValueError:
            unresolved.append(raw_target)
            continue

        if not resolved.exists():
            unresolved.append(raw_target)

    check(
        not unresolved,
        f"Local Markdown file targets resolve: {rel}",
        ", ".join(unresolved[:10]) if unresolved else None,
    )

print()
print("== Boundary and non-claim ==")
prohibited_paths = [
    "sql/schema/manifests/cad.manifest",
    "sql/schema/migrations/cad",
    "go/services/cad",
]
for rel in prohibited_paths:
    check(not (repo / rel).exists(), f"No executable CAD path established: {rel}")

search_files = [
    repo / "modules/CAD/README.md",
    repo / "modules/CAD/docs/README.md",
    repo / "modules/CAD/docs/acceptance/README.md",
]
for path in search_files:
    content = path.read_text(encoding="utf-8").lower()
    check("not ready for production use" in content or
          "no cad implementation phase has been accepted" in content or
          "design and assurance metadata only" in content,
          f"Nonproduction status is explicit: {path.relative_to(repo)}")

print()
print("== Final result ==")
print(f"PASS checks: {pass_count}")
print(f"FAIL checks: {fail_count}")

if fail_count:
    print()
    print("CAD Phase 0 static validation FAILED.", file=sys.stderr)
    raise SystemExit(1)

print()
print("CAD Phase 0 static validation PASSED.")
print("This proves documentation and registry consistency only.")
print("It does not prove executable CAD implementation or production readiness.")
PY
