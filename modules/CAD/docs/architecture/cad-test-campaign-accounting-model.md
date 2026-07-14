# CAD Test Campaign Accounting Model

> **Owner:** Iron Signal Systems
>
> **Module:** Computer Aided Dispatch
>
> **Document status:** Normative CAD assurance architecture
>
> **Implementation status:** Accounting contract only
>
> **Production status:** Not accepted for production use

## Purpose

Define exactly how CAD hostile, concurrency, retry, fuzz, stress, failure, and
recovery campaigns count work and receive acceptance credit.

Large numbers are not meaningful unless every count has one unambiguous
definition.

## Scope

This model governs:

- Candidate hostile campaigns.
- Formal hostile campaigns.
- Cache, queue, spool, outbox, replay, and reconciliation misuse campaigns.
- Retry-storm campaigns.
- Concurrent and reordered campaigns.
- Randomized mixed stress, attack, fault, and recovery campaigns.
- Bounded batches used for side-effect verification.
- Campaign invalidation, stop, preservation, and rerun rules.

It does not replace the minimum counts in the
[CAD Testing and Acceptance Model](cad-testing-and-acceptance-model.md).

## Accounting Terms

### Configured

The number of primary test actions the controller was instructed to generate.

Configuration records do not prove generation or execution.

### Generated

A primary action becomes generated when the controller has created:

- A unique attempt identifier.
- A campaign identifier.
- A retained seed or deterministic case identifier.
- A controlled-operation identifier.
- A primary hostile class or exploration reason.
- An intended enforcement point.
- Expected outcome and oracle identifier.
- Required context and payload metadata.

A malformed controller record is not generated credit.

### Submitted

A generated action becomes submitted when the controller hands it to the
intended client, service, worker, adapter, database connection, or fault
injection boundary.

A locally constructed action that never reaches its intended boundary is not
submitted credit.

### Attempted

A submitted action becomes attempted when the intended enforcement point or
execution boundary records authoritative receipt.

Examples include:

- Go transport decoder receives the request.
- PostgreSQL records function invocation by the test role.
- Worker claims the queued record.
- Workstation component reads the replay entry.
- Adapter simulator receives the outbound message.

Client-side timeout alone does not prove that a lower layer attempted the
operation.

### Completed

An attempted action becomes completed only when the controller can classify:

- The operation result.
- The authoritative state result.
- Permitted and prohibited side effects.
- Retry disposition.
- External-delivery disposition when applicable.
- Evidence completeness.

Unknown, uncorrelated, or telemetry-blind outcomes are not completed credit.

### Credited

A completed action receives acceptance credit only when:

- The intended hostile class was actually present.
- The intended enforcement point was actually exercised.
- The required oracle completed.
- Side-effect verification completed.
- The attempt was not excluded or invalidated.
- The campaign remained valid.
- The result matched an accepted outcome class.

A completed correctness failure remains completed for accounting, but it does
not count toward a passing minimum.

### Excluded

An action may be excluded only for an accepted, machine-readable reason such as:

- Controller defect before target receipt.
- Test-environment failure unrelated to the system under test.
- Duplicate scheduling caused solely by the test harness.
- Approved warm-up or calibration action.
- Explicit health probe outside the campaign population.

Exclusions must remain visible. Excluded actions may not be silently removed
from denominators.

### Invalidated

An action or campaign is invalidated when its evidence cannot support the
claimed result, including:

- Wrong target or enforcement point.
- Missing or corrupted seed.
- Oracle defect.
- Registry revision mismatch.
- Telemetry gap that prevents authoritative classification.
- Unapproved environment change.
- Unrecorded operator intervention.
- Generator defect that changes the intended hostile semantics.
- Cross-campaign contamination.

Invalidated work receives no acceptance credit.

## Attempt Identity

Every primary generated action must receive one immutable identifier:

```text
CAD-CMP-<campaign>-ATTEMPT-<sequence-or-uuid>
```

All lower-layer invocations, retries, transactions, queue claims, external
deliveries, and evidence records must correlate back to that primary attempt.

One primary attempt may create several execution attempts because of bounded
retry. Those executions remain children of the original primary attempt.

## Retry Accounting

A technical retry:

- Does not become a new hostile attempt.
- Does increment execution-attempt and technical-retry counters.
- Must retain the same primary attempt identifier.
- Must receive a new transaction or execution identifier.
- Must obey the accepted total attempt budget.
- Must reread and revalidate current state.
- Must not receive additional hostile-count credit.

If retry changes the operation, target, hostile condition, or enforcement
point, the controller must create a new primary attempt.

Required counters include:

```text
primary_attempts
execution_attempts
technical_retries
retry_exhaustions
nested_retry_violations
attempt_budget_violations
```

## Hostile-Class Credit

Each primary attempt must identify exactly one **primary hostile class** for
minimum-count credit.

It may identify zero or more secondary hostile tags for analysis.

This rule prevents one highly combined payload from receiving full minimum
credit for many unrelated hostile classes.

A combined-mechanism campaign may intentionally analyze interactions, but its
minimum-count credit remains assigned to one primary class unless an accepted
campaign definition establishes separate independent observation for each
class.

## Enforcement-Point Credit

Credit is enforcement-point specific.

A full-stack request does not automatically receive credit for every layer it
passes through. It receives credit only for the enforcement point that the
campaign intentionally targets and proves was exercised.

Separate required proof includes:

- Direct Go credit when Go owns and exercises the check.
- Direct PostgreSQL credit when the database boundary is invoked independently.
- Full-stack credit when the complete service path is exercised.
- Queue or worker credit when the queued boundary is actually reached.
- Workstation credit when the local component is the intended boundary.
- Integration credit when the provider or adapter boundary is exercised.

Instrumentation may show that other layers also acted, but that is supporting
evidence rather than automatic minimum-count credit.

## Applicability

Every operation, hostile class, and enforcement-point combination must be
classified:

```text
REQUIRED
CONDITIONAL
NOT_APPLICABLE
DEFERRED
```

`NOT_APPLICABLE` requires:

- A written technical reason.
- The governing architecture reference.
- The reviewer.
- The acceptance phase or decision.
- Reconsideration when the operation or boundary changes.

The implementation author alone may not approve `NOT_APPLICABLE` for a
high-impact operation.

## High-Impact Classification

A controlled operation is high impact when failure or abuse can materially
affect one or more of:

- Life-safety awareness.
- Incident identity or lifecycle.
- Unit assignment, availability, or status.
- Responder-safety information.
- Authorization, approval, or supervisory control.
- Material operational history.
- External dispatch or notification.
- Bulk disclosure or sensitive access.
- Degraded-operation authority.
- Recovery, reconciliation, or authoritative state.
- Audit integrity.
- High-availability authority or fencing.

The controlled-operations registry owns the classification. A lower impact
classification requires documented consequence analysis and independent
review.

## Bounded-Batch Side-Effect Verification

Per-attempt verification is preferred.

Bounded-batch verification is allowed only when:

- The batch size is explicitly limited.
- Every attempt remains individually identifiable.
- Pre-batch and post-batch authoritative state are captured.
- The oracle can identify the exact attempt or smallest reproducible subset
  responsible for any difference.
- No external effect is hidden by aggregation.
- A failed batch is reduced to a minimal reproducer where practical.
- The batch never crosses incompatible operations, tenants, organizations,
  environments, or authority contexts.

A batch receives no credit when state drift cannot be attributed exactly.

## Required Campaign Matrix

Each campaign definition must enumerate:

```text
controlled operation
primary hostile class
enforcement point
applicability
impact classification
candidate minimum
formal minimum
configured count
completed count
credited pass count
correctness-failure count
technical-retry count
excluded count
invalidated count
oracle
environment
registry revision
evidence manifest
reviewer
```

The matrix must report zero-count required combinations explicitly.

## Campaign Validity

A campaign is valid only when:

- Required operation, hostile-class, and enforcement-point combinations were
  exercised.
- No single generator family improperly dominates the campaign.
- Normal CAD work is present where mixed operation is required.
- Quiet recovery periods are preserved where required.
- Seeds, versions, and environment fingerprints are complete.
- Every action and injected fault is accounted for.
- Operator interventions are recorded.
- Telemetry is sufficient for classification.
- The workload and environment remain inside the accepted campaign definition.

A large invalid campaign remains invalid regardless of duration or count.

## Immediate Stop Conditions

The controller must stop, isolate, or quarantine the affected boundary and
preserve evidence upon:

- Unexpected authorization or manufactured authority.
- Unauthorized committed state.
- Lost acknowledged commit.
- Split-brain or fencing ambiguity.
- Hidden partial commit.
- Data corruption.
- Unsafe fail-open behavior.
- Unbounded resource growth threatening the environment.
- Inability to correlate an authoritative state change to an exact attempt.
- Oracle disagreement.
- Evidence corruption.
- Telemetry loss preventing classification.
- Generator behavior outside the accepted threat model.
- Loss of test-environment isolation.

Stopping for safety is a failed or invalid run, not a pass.

## Pass and Failure Rules

A required matrix cell passes only when:

- Credited passing attempts meet or exceed its accepted minimum.
- Unexpected-success count is zero.
- Unintended-side-effect count is zero.
- Unclassified-outcome count is zero.
- Attempt-budget violations are zero.
- Nested-retry violations are zero.
- Required evidence is complete.
- No unresolved oracle disagreement exists.

Correctness failures must remain visible even after a later rerun passes.

## Example

```yaml
campaign_requirement:
  id: CAD-CMP-UNIT-ASSIGN-STALE-AUTH-PG
  operation_id: CAD-OP-UNIT-ASSIGN
  primary_hostile_class_id: CAD-HC-STALE-AUTHORIZATION
  enforcement_point_id: CAD-EP-PG-CURRENT-STATE
  applicability: REQUIRED
  impact: HIGH
  candidate_minimum_completed: 1000
  formal_minimum_completed: 10000
  hostile_credit: ONE_PRIMARY_CLASS_PER_ATTEMPT
  retry_credit: CHILD_EXECUTIONS_OF_PRIMARY_ATTEMPT
  oracle_id: CAD-ORACLE-UNIT-ASSIGN-REJECT
  side_effect_verification: PER_ATTEMPT
```

## Acceptance

This accounting model is accepted only when campaign software and reports use
these definitions without hidden alternative counting rules.
