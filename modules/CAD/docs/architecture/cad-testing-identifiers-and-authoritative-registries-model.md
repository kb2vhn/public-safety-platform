# CAD Testing Identifiers and Authoritative Registries Model

> **Owner:** Iron Signal Systems
>
> **Module:** Computer Aided Dispatch
>
> **Document status:** Normative CAD assurance architecture
>
> **Implementation status:** Design and register scaffold only
>
> **Production status:** Not accepted for production use

## Purpose

Establish stable identifiers and machine-readable registries before CAD
implementation creates large test inventories, campaign results, or acceptance
records.

The registries defined here are authoritative metadata. They do not create
runtime authority, database authority, operational permission, or an
implementation claim.

## Governing Principles

1. Every material assurance object receives one stable identifier.
2. An identifier is never silently reused for a different meaning.
3. Human-readable documents explain the architecture.
4. Machine-readable registries identify the exact objects that gates, tests,
   reports, and acceptance records consume.
5. Generated documentation must identify its source registry and generation
   version.
6. A registry entry marked `PROPOSED` or `DESIGN_ONLY` is not implemented,
   tested, or accepted.
7. Cross-file references must resolve at static validation time.
8. A gate must fail when two authoritative sources claim ownership of the same
   identifier or rule.

## Authoritative Paths

The initial authoritative paths are:

```text
modules/CAD/requirements/cad-requirements.yaml
modules/CAD/testing/cad-controlled-operations.yaml
modules/CAD/testing/cad-enforcement-points.yaml
modules/CAD/testing/cad-hostile-classes.yaml
modules/CAD/testing/test-oracles.yaml
```

Future executable phases may add registries for:

```text
modules/CAD/testing/cad-tests.yaml
modules/CAD/testing/cad-campaigns.yaml
modules/CAD/testing/cad-failure-classes.yaml
modules/CAD/testing/cad-evidence-manifests.yaml
modules/CAD/testing/cad-exceptions.yaml
```

A later accepted decision may relocate a registry, but the move must preserve
history and update every authoritative reference in the same change.

## Identifier Namespaces

| Prefix | Meaning |
|---|---|
| `CAD-DSP-` | Dispatcher capability requirement retained from the initial human-facing catalog |
| `CAD-REG-` | Machine-readable assurance registry |
| `CAD-REQ-` | General CAD requirement |
| `CAD-INV-` | Invariant |
| `CAD-HAZ-` | Operational or safety hazard |
| `CAD-THR-` | Threat or abuse case |
| `CAD-STD-` | External standard, profile, or clause mapping |
| `CAD-OP-` | Controlled CAD operation or exchange |
| `CAD-EP-` | Prevention or enforcement point |
| `CAD-HC-` | Hostile behavior class |
| `CAD-FAIL-` | Failure or fault class |
| `CAD-TEST-` | Deterministic or bounded test case |
| `CAD-CMP-` | Repeated campaign definition or run |
| `CAD-ORACLE-` | Authoritative test-oracle definition |
| `CAD-EVID-` | Evidence artifact or manifest |
| `CAD-DEF-` | Defect or discovered mechanism |
| `CAD-EXC-` | Exception |
| `CAD-ACC-` | Acceptance decision or record |

The existing `CAD-DSP-` identifiers remain valid requirement identifiers. They
must not be renumbered merely to fit `CAD-REQ-`.

## Identifier Format

Identifiers must:

- Use uppercase ASCII letters, digits, and hyphens.
- Begin with an approved namespace.
- Be unique across the CAD module.
- Remain stable after publication.
- Avoid embedding mutable implementation details such as table names, package
  paths, release numbers, or vendor names.
- Use a readable semantic suffix for new controlled operations, enforcement
  points, hostile classes, and oracles.
- Use a stable numeric suffix where the existing catalog already uses one.

Examples:

```text
CAD-DSP-067
CAD-REG-REQUIREMENTS
CAD-OP-UNIT-ASSIGN
CAD-EP-PG-CONTROLLED-API
CAD-HC-STALE-AUTHORIZATION
CAD-ORACLE-UNIT-ASSIGN-REJECT
CAD-ACC-PHASE-0
```

## Lifecycle States

Registry objects use the following lifecycle states:

```text
PROPOSED
ACTIVE
IMPLEMENTED
TESTED
ACCEPTED
ACCEPTED_WITH_EXCEPTION
DEFERRED
REJECTED
SUPERSEDED
RETIRED
```

Additional implementation or acceptance fields may use:

```text
DESIGN_ONLY
NOT_IMPLEMENTED
NOT_TESTED
NOT_APPLICABLE
FAILED
BLOCKED
```

Lifecycle rules:

- `ACTIVE` means the requirement or design object governs work in scope.
- `IMPLEMENTED` requires an exact executable artifact.
- `TESTED` requires retained evidence from the applicable test tier.
- `ACCEPTED` requires an acceptance record bound to an exact release and
  environment.
- `SUPERSEDED` requires a replacement identifier and preserved lineage.
- `RETIRED` prohibits new use but does not erase historic evidence.

## Minimum Registry Metadata

Every registry must identify:

- Registry identifier.
- Schema version.
- Module.
- Owner.
- Document or architecture authority.
- Registry status.
- Last reviewed date or source revision when accepted.
- Entries.
- Cross-registry references.
- Validation rules.

Every entry must identify:

- Stable identifier.
- Title or semantic name.
- Lifecycle status.
- Implementation status.
- Source.
- Owner.
- Applicability.
- Related identifiers.
- Supersession lineage.
- Notes needed to prevent ambiguous interpretation.

An empty mapping is explicit. Missing required keys are invalid.

## Cross-Registry Reference Rules

A registry reference must:

1. Resolve to exactly one entry.
2. Target an allowed object type.
3. Not target a retired object for new work.
4. Not target a superseded object unless historic evidence is being described.
5. Preserve the exact identifier case.
6. Be included in impact analysis when the target changes.

A requirement may map to several operations, enforcement points, and tests.
A test may map to several requirements when it intentionally proves one shared
invariant. Broad many-to-many mapping without an explicit reason is prohibited.

## Canonical Ownership

| Object | Canonical owner |
|---|---|
| Requirement text and status | Requirements registry |
| Controlled-operation identity and impact | Controlled-operations registry |
| Enforcement-point identity and boundary | Enforcement-points registry |
| Hostile-class definition | Hostile-classes registry |
| Expected outcome and side-effect contract | Test-oracles registry |
| Test implementation path and tier | Future tests registry |
| Campaign count and applicability | Future campaigns registry |
| Accepted result | Acceptance record and evidence manifest |

Markdown documents must not redefine a registry-owned field with a conflicting
value.

## Static Validation Requirements

The CAD static gate must eventually prove:

- Every registry parses.
- Schema versions are supported.
- Identifiers are unique.
- Prefixes match object type.
- Required fields are present.
- References resolve.
- No active object points only to a retired object.
- No superseded object lacks lineage.
- No accepted object lacks evidence and acceptance references.
- No high-impact operation lacks enforcement-point and hostile-class
  applicability review.
- No oracle references an unknown state selector or outcome class.
- No acceptance record references a registry revision that differs from the
  retained evidence manifest.
- Generated documentation is reproducible from the retained registry revision.

## Change Control

A material registry change requires:

1. Preserving the prior entry or revision.
2. Recording the reason.
3. Identifying affected requirements, operations, tests, campaigns, evidence,
   standards mappings, and acceptance records.
4. Re-running affected static and executable gates.
5. Updating generated views.
6. Reassessing existing exceptions.
7. Recording supersession rather than silently changing historic meaning.

Changing a title for clarity may retain the identifier when semantics do not
change. Changing normative meaning requires a new identifier or explicit
versioned supersession.

## Phase 0 Acceptance Rule

This model may be accepted as Phase 0 documentation only when:

- The authoritative paths exist.
- Every seeded file parses.
- Every seeded identifier is unique.
- All seeded objects are honestly marked as design-only, proposed, or not
  implemented.
- Documentation indexes link to this model and the registries.
- No executable or production claim is created.
- A retained Phase 0 acceptance record identifies the exact commit and static
  validation result.
