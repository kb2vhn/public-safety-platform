# CAD Testing and Acceptance Model

> **Document status:** Normative CAD architecture
>
> **Implementation status:** Test design only

## Architecture Ownership

This document coordinates complete CAD phase acceptance.

Detailed human-interaction and accessibility evaluation is governed by the
[CAD User-Interface Architecture](user-interface/README.md). Detailed local
appliance and workstation-component resource measurement is governed by the
[CAD Operational Workstation Architecture](operational-workstation/README.md).

Correctness, accessibility, and resource observations must remain separately
reported even when one phase gate gathers all three.

## Purpose

Define how CAD changes are designed, built, tested, observed, and accepted.

Passing tests prove only the asserted behavior. They do not establish complete
production readiness.

## Definition of Progress

A material CAD change should normally include:

1. Governing architecture.
2. Stable terminology and invariants.
3. A controlled SQL, service, adapter, or interface change.
4. Authoritative manifest or build registration.
5. Clean installation or reproducible build.
6. Structural and catalog validation.
7. Privilege and security-boundary validation.
8. Positive behavior tests.
9. Negative and hostile-condition tests.
10. Independent-connection concurrency tests when state can race.
11. Idempotency and replay tests when delivery can repeat.
12. Accessibility tests for human-facing behavior.
13. Degraded-operation and recovery tests where material.
14. Resource observation when an executable path changes.
15. Updated documentation and exact counts.
16. Static and full phase-gate validation.
17. A retained acceptance record.

## Test Categories

### Static Repository Validation

Validate:

- Required files.
- Naming.
- Manifests.
- Migration ranges.
- Documentation links.
- Exact status language.
- No forbidden placeholders or secrets.
- File hygiene.
- Generated-file policy.
- Phase counts.
- Required reason codes and operation identifiers.

### Clean Installation

Build a uniquely named disposable database and apply the authoritative
Foundation, shared-resource, and CAD manifests in dependency order.

A CAD test must not depend on a manually prepared database.

### Structural and Catalog Tests

Validate:

- Schemas.
- Tables.
- Types.
- Constraints.
- Indexes.
- Functions.
- Triggers.
- Ownership.
- Privileges.
- Security-definer properties.
- Search paths.
- Row-level security where applicable.
- Migration registry.
- Manifest registration.

### Positive Behavior

Prove authorized and valid workflows succeed with exact committed effects.

### Negative and Hostile Behavior

Prove invalid, stale, replayed, unauthorized, malformed, out-of-scope, or
inconsistent requests fail closed without unintended side effects.

### Concurrency

Use real independent database connections or service clients.

Expected race tests include:

- Concurrent incident-number allocation.
- Concurrent unit assignment.
- Assignment racing unit unavailability.
- Concurrent alert acknowledgment.
- Concurrent incident transfer.
- Closure racing a new operational event.
- Correction racing another correction.
- Recommendation expiration during commit.
- Duplicate inbound delivery.
- Offline reconciliation conflict.

### State-Machine Tests

Prove:

- Allowed transitions.
- Denied transitions.
- Terminal behavior.
- Reopening behavior.
- Correction and supersession.
- No impossible current projection.

### Integration Contract Tests

Use provider simulators or controlled test doubles to prove:

- Authentication.
- Contract version handling.
- Duplicate detection.
- Idempotency.
- Timeout.
- Retry.
- Replay.
- Ordering.
- Partial failure.
- Queue recovery.
- Replacement-adapter compatibility.


### Foundation Approval and Authorization Integration

CAD tests that use Foundation approval or authorization must prove:

- Approval Action recording, stage satisfaction, Approval Request finalization, Authorization Decision, Authorization Lease, and CAD commit remain distinct.
- Withdrawn, corrected, superseded, expired, suspended, or revoked state fails closed at later use.
- Authority Grant revocation invalidates the affected path.
- Duplicate-actor, duplicate-action, finalization, withdrawal, revocation, and reciprocal-approval races preserve the Phase 4 Step 7 contract.
- Serialization and deadlock results remain retryable technical outcomes rather than policy denials.
- A local cache or queue cannot manufacture Approval Action Records, Approval Request finalization, Authorization Decisions, Authorization Leases, Decision Records, or committed CAD state.

### Accessibility Tests

Human-facing CAD acceptance requires applicable:

- Automated checks.
- Keyboard-only testing.
- Focus testing.
- Screen-reader testing.
- High-contrast and forced-color testing.
- Zoom and magnification testing.
- Non-color meaning.
- Multi-modal alert testing.
- Map alternative testing.
- Timer and queue testing.
- Degraded-operation testing.
- Representative operational user evaluation.

A clean automated scan is not accessibility acceptance.

### Resource Observation

Record correctness separately from:

- Total and phase duration.
- CPU.
- Memory.
- Disk and filesystem activity.
- PostgreSQL transactions and block activity.
- Temporary files.
- Locks and deadlocks.
- WAL generation.
- Database size.
- Query and operation latency.
- Queue depth.
- Message retries.
- Host and PostgreSQL fingerprint.

Resource observations begin as observation-only data.

Performance thresholds become pass or fail criteria only after representative,
same-environment runs establish governed budgets.

## Test Data

Tests must use synthetic data.

Real caller, patient, criminal-justice, protected-person, personnel, or premise
data must not be copied into disposable test environments without explicit
authorization and protection.

## Result Artifacts

A CAD test run should eventually retain:

- Complete log.
- Compact correctness summary.
- Machine-readable result.
- Resource observation text.
- Resource observation JSON.
- Environment fingerprint.
- Failed database or service state when needed for investigation.
- Phase-gate result.
- Acceptance record reference.

## Acceptance

A CAD phase is accepted only when:

- Its exact scope is stated.
- Required tests pass.
- Warnings are understood and documented.
- Resource observation status is explicit.
- Accessibility status is explicit.
- Unimplemented controls are listed.
- Counts are synchronized.
- The next boundary is stated.
- The acceptance record is retained.
