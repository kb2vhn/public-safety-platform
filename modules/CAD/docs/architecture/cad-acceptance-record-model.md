# CAD Acceptance Record Model

> **Owner:** Iron Signal Systems
>
> **Module:** Computer Aided Dispatch
>
> **Document status:** Normative CAD assurance architecture
>
> **Implementation status:** Acceptance contract only
>
> **Production status:** No CAD phase is accepted by this document

## Purpose

Define the authoritative structure, decision rules, independence requirements,
and blocking conditions for CAD phase, release, pilot, and production acceptance
records.

An acceptance record summarizes retained evidence. It does not replace that
evidence.

## Acceptance Types

```text
DOCUMENTATION_PHASE
IMPLEMENTATION_PHASE
RELEASE_CANDIDATE
FORMAL_PHASE
PREPRODUCTION
PILOT_ENTRY
PRODUCTION_RELEASE
TOPOLOGY_CHANGE
RENEWAL
EMERGENCY_EXCEPTION
```

The type must match the claim. A documentation-only acceptance must not be
presented as executable or production acceptance.

## Decision States

```text
NOT_EVALUATED
BLOCKED
FAILED
ACCEPTED
ACCEPTED_WITH_EXCEPTION
SUPERSEDED
WITHDRAWN
```

`ACCEPTED_WITH_EXCEPTION` requires an exception identifier, owner, consequence,
compensating controls, expiration or review condition, and acceptance authority.

## Mandatory Acceptance Sections

Every record must include:

1. Acceptance identity and type.
2. Phase, step, release, or topology boundary.
3. Exact claim and explicit exclusions.
4. Source commit, tag, and repository state.
5. Artifact, registry, and evidence-manifest digests.
6. Environment and topology fingerprint.
7. Migration, manifest, build, and executable inventory.
8. Test inventory by tier.
9. Requirement coverage.
10. Invariant coverage.
11. Hazard and threat coverage.
12. Controlled-operation coverage.
13. Enforcement-point coverage.
14. Hostile-class coverage.
15. Concurrency, retry, idempotency, and replay results.
16. Unexpected-success, unintended-side-effect, and unknown-outcome counts.
17. Accessibility status.
18. Degraded-operation and recovery status.
19. Resource observations.
20. Performance-threshold status.
21. Availability and HA status.
22. Backup, restore, rebuild, maintenance, and rollback status.
23. Standards-conformance status.
24. Release-integrity and supply-chain status.
25. Findings, defects, and newly discovered mechanisms.
26. Exceptions and expiration conditions.
27. Evidence locations, retention classes, and digests.
28. Implementers, reviewers, custodians, and acceptance authorities.
29. Decision and rationale.
30. Next authorized boundary.

A section may state `NOT_APPLICABLE`, but it may not be omitted when the template
requires it.

## Independence

For high-impact executable or production acceptance:

- The implementation author must not be the sole acceptance authority.
- The oracle author should not be the sole reviewer of that oracle.
- The evidence custodian must not silently alter results.
- An exception owner must not be the sole exception approver.
- The acceptance record must identify any role overlap.
- Unavoidable overlap in a small team requires explicit disclosure and a later
  independent review before production claim.

Documentation-only Phase 0 may be self-reviewed during early development, but
the record must say so and must not imply independent assurance.

## Automatic Blockers

Acceptance is blocked or failed when any applicable condition exists:

```text
unexpected_successes > 0
unintended_side_effects > 0
unknown_outcomes > 0
unclassified_failures > 0
required_evidence_missing > 0
required_telemetry_gaps > 0
attempt_budget_violations > 0
nested_retry_violations > 0
required_coverage_incomplete = true
registry_reference_failure = true
oracle_disagreement_unresolved = true
split_brain_events > 0
lost_acknowledged_commits > 0
automatic_failback_events > 0
authority_oscillation_events > 0
expired_exceptions > 0
unresolved_critical_findings > 0
unresolved_high_impact_findings_without_accepted_disposition > 0
```

A later rerun may establish a new acceptance record. It must not erase the
failed record.

## Correctness Summary

Every executable acceptance record must include a machine-readable block:

```yaml
correctness:
  pass: 0
  fail: 0
  warn: 0
  unexpected_successes: 0
  unintended_side_effects: 0
  unknown_outcomes: 0
  unclassified_failures: 0

campaigns:
  configured: 0
  generated: 0
  submitted: 0
  attempted: 0
  completed: 0
  credited_pass: 0
  excluded: 0
  invalidated: 0
  technical_retries: 0
  retry_exhaustions: 0
  attempt_budget_violations: 0
  nested_retry_violations: 0

evidence:
  required: 0
  present: 0
  missing: 0
  corrupt: 0
  telemetry_gaps: 0
```

Documentation-only Phase 0 may use zero executable counts and must explicitly
state `NOT_APPLICABLE`.

## Coverage Summary

Coverage must be reported separately for:

- Requirements.
- Invariants.
- Hazards and threats.
- Standards clauses.
- Controlled operations.
- Enforcement points.
- Hostile classes.
- Positive paths.
- Concurrency.
- Failures and recovery.
- Accessibility.
- Performance and availability.
- Evidence completeness.

A combined percentage is prohibited.

## Warnings

Warnings are accepted only when:

- The condition is understood.
- Consequence is documented.
- It is not a hidden correctness failure.
- It is not required missing evidence.
- It has an owner.
- It has a disposition.
- It does not violate a maximum threshold.
- The acceptance authority explicitly acknowledges it.

## Exceptions

Every exception must identify:

```text
exception identifier
affected requirements and controls
reason
consequence
scope
compensating controls
owner
reviewer
acceptance authority
start
expiration or review condition
evidence
remediation
closure criteria
```

An expired exception blocks acceptance.

## Signatures and Integrity

The record must be bound to:

- Exact source commit and tag.
- Exact artifact digests.
- Exact registry digests.
- Exact evidence-manifest digest.
- Exact environment fingerprint.
- Exact decision text.

Formal release records should use the platform's accepted artifact-signing or
equivalent integrity mechanism.

## Template

The authoritative human-readable template is:

```text
modules/CAD/docs/acceptance/cad-phase-acceptance-record-template.md
```

A future executable phase may add a machine-readable acceptance schema.

## Supersession and Withdrawal

A superseding record must:

- Reference the prior record.
- State what changed.
- Preserve the prior decision.
- Identify affected deployments and evidence.
- Reevaluate exceptions.
- State whether the prior acceptance remains valid for any release.

Acceptance must be withdrawn when later evidence proves the accepted claim was
materially false or unsafe.

## Acceptance

A CAD acceptance record is valid only when:

- Its type and claim are exact.
- Required sections are complete.
- Automatic blockers are absent.
- Evidence is retained and verified.
- Role independence is disclosed.
- The decision is bound to exact artifacts and environment.
- The next authorized boundary is stated.
