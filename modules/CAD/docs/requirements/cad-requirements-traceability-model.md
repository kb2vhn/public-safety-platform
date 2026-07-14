# CAD Requirements and Evidence Traceability Model

> **Owner:** Iron Signal Systems
>
> **Module:** Computer Aided Dispatch
>
> **Document status:** Normative CAD requirements architecture
>
> **Implementation status:** Register and traceability contract only

## Purpose

Ensure every accepted CAD claim can be traced from its operational need and
architecture through implementation, testing, evidence, review, and release.

Large test counts do not compensate for an unmapped requirement.

This document is governed with the
[CAD Testing Identifiers and Authoritative Registries Model](../architecture/cad-testing-identifiers-and-authoritative-registries-model.md).

## Required Traceability Chain

```text
operational need
→ source requirement
→ architecture statement
→ hazard, threat, or abuse case
→ invariant
→ applicable standard and clause
→ governed data
→ controlled operation or exchange
→ enforcement points
→ implementation objects
→ positive tests
→ denial and adversarial tests
→ concurrency tests
→ degraded and recovery tests
→ accessibility tests
→ performance and availability budgets
→ evidence artifacts and digests
→ implementer
→ reviewer
→ acceptance decision
→ exception or remediation
→ exact release and environment
```

## Stable Identifiers

At minimum, maintain stable identifiers for:

```text
CAD-DSP-       Existing dispatcher capability requirement
CAD-REG-       Machine-readable assurance registry
CAD-REQ-       General CAD requirement
CAD-INV-       Invariant
CAD-HAZ-       Hazard
CAD-THR-       Threat or abuse case
CAD-STD-       Standard or clause mapping
CAD-OP-        Controlled operation or exchange
CAD-EP-        Prevention or enforcement point
CAD-HC-        Hostile behavior class
CAD-FAIL-      Failure or fault class
CAD-TEST-      Test case
CAD-CMP-       Campaign definition or run
CAD-ORACLE-    Test oracle
CAD-EVID-      Evidence artifact or manifest
CAD-DEF-       Defect or discovered mechanism
CAD-EXC-       Exception
CAD-ACC-       Acceptance record or decision
```

The existing `CAD-DSP-` identifiers are valid requirement identifiers and must
not be renumbered merely to fit `CAD-REQ-`.

Identifiers must not be silently reused after retirement.

## Requirement Record

Each requirement must include:

- Identifier.
- Title.
- Normative text.
- Rationale.
- Source.
- Owner.
- Priority and consequence.
- Applicability.
- Requirement status.
- Implementation status.
- Test status.
- Acceptance status.
- Related requirements.
- Invariants.
- Hazards and threats.
- Standards mappings.
- Controlled operations.
- Enforcement points.
- Tests.
- Evidence.
- Reviewer.
- Exceptions.
- Supersession lineage.

Empty mappings are explicit unfinished traceability. They are not evidence that
a mapping is unnecessary.

## Controlled Status

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

`IMPLEMENTED` does not mean tested. `TESTED` does not mean accepted.

Additional fields may use:

```text
DESIGN_ONLY
NOT_IMPLEMENTED
NOT_TESTED
NOT_EVALUATED
NOT_APPLICABLE
BLOCKED
FAILED
```

## Machine-Readable Authority

The authoritative requirement register is:

```text
modules/CAD/requirements/cad-requirements.yaml
```

The initial register mirrors the current `CAD-DSP-*` records from:

```text
modules/CAD/docs/requirements/dispatcher-capability-catalog.md
```

Human-readable Markdown may be generated from the register after a reproducible
generator is accepted.

Until then, a static synchronization check must compare the catalog and
register.

The current register does not claim that any requirement is implemented,
tested, accepted, or production-ready.

## Related Authoritative Registries

```text
modules/CAD/testing/cad-controlled-operations.yaml
modules/CAD/testing/cad-enforcement-points.yaml
modules/CAD/testing/cad-hostile-classes.yaml
modules/CAD/testing/test-oracles.yaml
```

Future executable phases may add test, campaign, failure, evidence, defect,
exception, and machine-readable acceptance registries.

## Gate Rules

The traceability gate must fail for:

- YAML parse failure.
- Unsupported schema version.
- Duplicate identifier.
- Invalid identifier namespace.
- Catalog identifier missing from the requirements register.
- Contradictory requirement text or status.
- Unresolved cross-registry reference.
- Requirement without invariant when implementation acceptance is claimed.
- High-impact invariant without threat or hazard evaluation.
- Controlled operation without enforcement-point inventory.
- Mandatory standard clause without implementation and evidence mapping.
- High-impact operation without hostile tests.
- Race-sensitive operation without concurrency tests.
- Human-facing behavior without accessibility status.
- Production-critical path without performance and availability budgets.
- Test without mapped requirement, threat, failure class, or documented
  exploration reason.
- Evidence reference that does not exist or does not match the accepted run.
- Expired exception.
- Superseded requirement still presented as current.
- Accepted release containing an unaccepted mandatory requirement.
- Accepted object that remains marked `NOT_IMPLEMENTED` or `NOT_TESTED`.

Phase 0 may contain empty future mappings when every affected record remains
honestly marked as not implemented, not tested, and not evaluated.

## Evidence Binding

Evidence must identify:

- Run and campaign.
- Source and artifact digests.
- Registry digests.
- Schema inventory.
- Configuration.
- Environment.
- Workload.
- Seed and corpus.
- Result.
- Telemetry completeness.
- Reviewer.
- Retention class.
- Retention location and digest.

A link to a mutable log location without identity or digest is insufficient for
formal acceptance.

## Coverage Reporting

Coverage reports must state separately:

- Requirement coverage.
- Invariant coverage.
- Threat and hazard coverage.
- Enforcement-point coverage.
- Standards-clause coverage.
- Positive-path coverage.
- Hostile-class coverage.
- Concurrency coverage.
- Failure and recovery coverage.
- Accessibility coverage.
- Performance and availability coverage.
- Evidence completeness.

A single combined percentage is prohibited because it can conceal a completely
untested high-impact category.

## Change and Supersession

When a requirement changes:

1. Preserve the old record.
2. Create or identify the superseding record.
3. Perform impact analysis.
4. Update architecture and implementation mappings.
5. Update controlled-operation, enforcement-point, hostile-class, and oracle
   mappings.
6. Update test and evidence mappings.
7. Re-run affected regression.
8. Reevaluate standards claims and exceptions.
9. Update acceptance lineage.

## Phase 0 Acceptance

Phase 0 traceability may be accepted when:

- The machine-readable requirement register exists and parses.
- Every current `CAD-DSP-*` identifier appears exactly once.
- All entries remain `NOT_IMPLEMENTED`, `NOT_TESTED`, and `NOT_EVALUATED`.
- Seeded cross-registry identifiers are unique.
- Documentation and register source paths agree.
- No executable or production claim is created.
- The exact static-gate result is retained.

## Executable Acceptance

Traceability for an executable phase is accepted only when every mandatory
requirement in scope has a complete, current, evidence-bound chain and no
expired or hidden exception.
