# CAD Test-Oracle and Side-Effect Verification Model

> **Owner:** Iron Signal Systems
>
> **Module:** Computer Aided Dispatch
>
> **Document status:** Normative CAD assurance architecture
>
> **Implementation status:** Oracle contract and seed registry only
>
> **Production status:** Not accepted for production use

## Purpose

Define how a CAD test determines the expected result and proves the exact
authoritative effects, permitted evidence effects, prohibited effects, and
external effects of an operation.

An API status, exception, denial reason, database row count, or process exit
code is never sufficient by itself.

## Oracle Independence

The expected result must not be calculated solely by the same implementation
logic being tested.

An oracle may use:

- A separately reviewed declarative state-transition contract.
- A small reference model.
- Precondition and invariant assertions.
- Canonical before-and-after state comparison.
- An independently maintained standards fixture.
- A controlled provider simulator.
- A human-reviewed expected result for a retained regression case.

A test that calls the production authorization or transition function to decide
what that same function should return is circular and insufficient.

## Oracle Layers

Every material controlled operation must define applicable oracle layers:

1. **Request oracle** — validates the generated test case and intended hostile
   condition.
2. **Result oracle** — classifies the returned or observed operation result.
3. **Authoritative-state oracle** — verifies canonical state after the attempt.
4. **Invariant oracle** — verifies global and operation-specific invariants.
5. **Permitted-evidence oracle** — identifies audit, denial, security, or
   telemetry effects that are allowed or required.
6. **Prohibited-side-effect oracle** — proves unauthorized or impossible
   effects are absent.
7. **External-effect oracle** — verifies delivery, acknowledgment, provider, and
   replay state when applicable.
8. **Recovery oracle** — verifies retry, restart, failover, reconciliation, and
   queue drainage when applicable.
9. **Human-facing oracle** — verifies accurate and accessible presentation when
   applicable.

Not every operation uses every layer, but omitted layers require an
applicability decision.

## Outcome Classes

The result oracle must use an explicit outcome class:

```text
COMMITTED
REJECTED_POLICY
REJECTED_AUTHENTICATION
REJECTED_AUTHORIZATION
REJECTED_VALIDATION
REJECTED_CONFLICT
REJECTED_STATE
QUEUED_NONAUTHORITATIVE
PENDING_AUTHORITATIVE_VALIDATION
RETRYABLE_SERIALIZATION
RETRYABLE_DEADLOCK
RETRYABLE_TIMEOUT
CANCELLED
CONNECTION_LOST_UNCERTAIN
FAILED_TECHNICAL
EXPIRED
QUARANTINED
RECONCILED
UNKNOWN
```

`UNKNOWN` is never a passing formal result.

A technical outcome must not be relabeled as a policy or authorization denial.

## Authoritative State Selectors

Oracles should reference semantic state selectors rather than unstable
implementation paths whenever possible.

Examples:

```text
incident.current
incident.timeline
incident.lifecycle
unit.current_status
unit.current_assignment
alert.current
alert.history
authorization.current_context
approval.current_state
outbox.pending
delivery.current
reconciliation.current
audit.security_denials
```

A later executable phase maps each selector to exact queries, APIs, or retained
views. The mapping must be independently reviewed and versioned.

## Before-and-After Capture

For every operation where state may change, the oracle must capture enough
before state to prove:

- Expected state changed exactly once.
- Unrelated protected state did not change.
- Original material history remains preserved.
- Current projections remain consistent with history.
- No cross-organization, cross-scope, cross-incident, cross-unit, cross-user, or
  cross-workstation effect occurred.
- Outbox, queue, delivery, and reconciliation state matches the operation
  result.

Capture may use canonical records, stable views, transactionally consistent
snapshots, or cryptographic digests over canonical serialization.

## Canonical Comparison

Canonical comparison must define:

- Field ordering.
- Null representation.
- Time normalization.
- Identifier normalization.
- Numeric precision.
- Collection ordering.
- Excluded nondeterministic fields.
- Redaction behavior.
- Canonical serialization version.
- Digest algorithm.

SHA-256 is the minimum digest algorithm for retained comparison artifacts unless
a later accepted security decision requires a stronger algorithm.

A digest does not replace retained human-readable failure detail.

## Nondeterministic Values

Generated identifiers, timestamps, retry timings, and ordering may vary.

An oracle must classify each field as:

```text
EXACT
RANGE
SET_MEMBERSHIP
MONOTONIC
RELATIONAL
PRESENT
ABSENT
IGNORED_WITH_REASON
```

`IGNORED_WITH_REASON` requires a documented reason. Security-, authority-,
scope-, lifecycle-, sequence-, and lineage-relevant fields may not be ignored
merely to make a test pass.

## Permitted Effects

A rejected hostile request may legitimately create controlled evidence such as:

- A security denial record.
- A rate-limit observation.
- A quarantine record.
- A failed-attempt metric.
- A test-correlation event.
- An alert to the test security monitor.

Each permitted effect must identify:

- Exact type.
- Required or optional status.
- Allowed cardinality.
- Allowed target and scope.
- Sensitive-data rules.
- Retention class.

An audit record claiming a prohibited operation succeeded is not a permitted
denial effect.

## Prohibited Effects

Applicable prohibited effects include:

- Protected row insertion, update, or deletion.
- Impossible current projection.
- Fabricated approval, Authorization Decision, Authorization Lease, Decision
  Record, or Decision Supporting Record.
- Unauthorized incident, unit, assignment, alert, timer, premise, warning, or
  timeline change.
- Unauthorized outbox or delivery creation.
- External message transmission.
- Promotion of cache, queue, spool, retry, or provider state into authoritative
  CAD commitment.
- Cross-boundary or cross-context state change.
- Privilege, ownership, role, session, policy, or security-boundary mutation.
- Hidden partial transaction.
- Lost or duplicated acknowledged commit.
- Erasure of the hostile input or its disposition when preservation is
  required.

## External Effects

When external communication is possible, the oracle must independently verify:

- Whether CAD committed.
- Whether an outbox entry was created.
- Whether a worker claimed it.
- Whether an adapter transmitted it.
- Whether the provider received it.
- Whether the provider acknowledged it.
- Whether duplicate or reordered events occurred.
- Whether CAD reconciled the result.
- Whether provider success was incorrectly converted into CAD authority.

Transport success is not a CAD commit oracle.

## Oracle Disagreement

Oracle disagreement includes:

- Result says rejected while authoritative state changed.
- Database state says committed while client reports failed or unknown.
- Timeline and current projection disagree.
- Audit and operation outcome disagree.
- Delivery exists without an authorized outbox record.
- Two independent state selectors disagree.
- Reference model and invariant checks disagree.

Upon disagreement:

1. Stop or isolate the affected campaign boundary.
2. Preserve complete evidence.
3. Mark the attempt failed or unknown.
4. Do not choose the more convenient oracle.
5. Investigate implementation, oracle, and evidence paths independently.
6. Add the resolved case to permanent regression.

## Oracle Registry

The authoritative seed registry is:

```text
modules/CAD/testing/test-oracles.yaml
```

Each oracle record must identify:

- Identifier.
- Controlled operation.
- Intended outcome.
- Preconditions.
- Before-state selectors.
- Expected changes.
- Expected unchanged state.
- Expected absent effects.
- Permitted evidence effects.
- External checks.
- Invariant identifiers, or explicitly provisional invariant statements before an invariant registry exists.
- Comparison method.
- Nondeterministic-field rules.
- Required evidence.
- Applicable tiers.
- Owner and reviewer.
- Lifecycle status.

## Example

```yaml
oracle:
  id: CAD-ORACLE-UNIT-ASSIGN-REJECT
  operation_id: CAD-OP-UNIT-ASSIGN
  expected_outcomes:
    - REJECTED_AUTHORIZATION
    - REJECTED_STATE
  before_state:
    - unit.current_assignment
    - incident.current
  expected_unchanged:
    - unit.current_assignment
    - incident.current
    - outbox.pending
  expected_absent:
    - assignment.committed
    - delivery.created
  permitted_evidence:
    - security.authorization_denial
  provisional_invariant_statements:
    - One authoritative assignment exists when single assignment is required.
  comparison:
    method: canonical_state_digest
    digest: sha256
```

The example is a design seed. Exact state selectors and mappings require an
accepted executable phase. Provisional invariant statements do not satisfy final
traceability and must be replaced by registered `CAD-INV-*` references before
executable acceptance.

## Acceptance

An operation cannot receive formal hostile-campaign acceptance until its oracle:

- Is active and versioned.
- Has an independent reviewer.
- Resolves every referenced state selector.
- Proves permitted and prohibited effects.
- Handles technical uncertainty explicitly.
- Produces retained evidence.
- Has no unresolved disagreement.
