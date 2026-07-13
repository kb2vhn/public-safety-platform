# CAD Requirements and Evidence Traceability Model

> **Owner:** Iron Signal Systems
>
> **Module:** Computer Aided Dispatch
>
> **Document status:** Normative CAD requirements architecture
>
> **Implementation status:** Register contract only

## Purpose

Ensure every accepted CAD claim can be traced from its operational need and
architecture through implementation, testing, evidence, review, and release.

Large test counts do not compensate for an unmapped requirement.

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
CAD-REQ-
CAD-INV-
CAD-HAZ-
CAD-THR-
CAD-OP-
CAD-STD-
CAD-TEST-
CAD-HOSTILE-
CAD-FAIL-
CAD-EVID-
CAD-EXC-
CAD-ACC-
```

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
- Status.
- Related requirements.
- Invariants.
- Hazards and threats.
- Standards mappings.
- Controlled operations.
- Enforcement points.
- Tests.
- Evidence.
- Reviewer.
- Acceptance state.
- Exceptions.
- Supersession lineage.

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

## Machine-Readable Authority

The authoritative register should become machine-readable before executable CAD
phases produce large test inventories.

Recommended future path:

```text
modules/CAD/requirements/cad-requirements.yaml
```

Human-readable Markdown may be generated from that register.

## Gate Rules

The traceability gate must fail for:

- Requirement without invariant.
- High-impact invariant without threat or hazard evaluation.
- Controlled operation without enforcement-point inventory.
- Mandatory standard clause without implementation and evidence mapping.
- High-impact operation without hostile tests.
- Race-sensitive operation without concurrency tests.
- Human-facing behavior without accessibility status.
- Production-critical path without performance and availability budgets.
- Test without mapped requirement, threat, failure class, or exploration reason.
- Evidence reference that does not exist or does not match the accepted run.
- Expired exception.
- Duplicate identifier.
- Superseded requirement still presented as current.
- Accepted release containing an unaccepted mandatory requirement.

## Evidence Binding

Evidence must identify:

- Run and campaign.
- Source and artifact digests.
- Schema inventory.
- Configuration.
- Environment.
- Workload.
- Seed and corpus.
- Result.
- Telemetry completeness.
- Reviewer.
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
5. Update test and evidence mappings.
6. Re-run affected regression.
7. Reevaluate standards claims and exceptions.
8. Update acceptance lineage.

## Acceptance

Traceability is accepted only when every mandatory requirement in scope has a
complete, current, evidence-bound chain and no expired or hidden exception.
