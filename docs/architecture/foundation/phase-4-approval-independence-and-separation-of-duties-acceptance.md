# Phase 4 Approval Independence and Separation of Duties Acceptance

> **Layer:** Platform Foundation
>
> **Phase:** 4 — Approval Independence and Separation of Duties
>
> **Acceptance date:** 2026-07-13
>
> **Status:** Accepted for the Phase 4 scope defined below
>
> **Authoritative contract:** [Approval Independence and Separation of Duties Model](approval-independence-and-separation-of-duties-model.md)
>
> **Accepted release tag:** `phase-4-approval-independence-and-separation-of-duties-complete-v1`
>
> **Accepted implementation commit:** `bd7eb3a8ae8180283cd6ba0ca2a07e07912ae1b5`

## 1. Acceptance Decision

Phase 4 is accepted.

This decision means the PostgreSQL approval-independence,
separation-of-duties, stage-satisfaction, finalization, continuity, and
independent-connection concurrency boundary satisfied the Phase 4 acceptance
criteria on 2026-07-13.

It does not declare the complete Platform Foundation, production Go services,
deployment environment, operational modules, user interfaces, or production
operating model ready for production use.

## 2. Authoritative Accepted Tree

The annotated Git tag is the durable identifier for the exact accepted
implementation tree:

```text
phase-4-approval-independence-and-separation-of-duties-complete-v1
```

The tag dereferences to:

```text
bd7eb3a8ae8180283cd6ba0ca2a07e07912ae1b5
```

The tag target is authoritative. This acceptance record is an administrative
documentation commit created after the tag target. It must descend from the
tag and must not alter the accepted SQL or executable test tree.

## 3. Accepted Scope

The accepted Phase 4 scope includes:

- Typed Approval Request requester and directly affected identity context
- Explicit Approval Request dependencies and approval-chain identifiers
- Controlled Approval Action recording
- Exact request, policy, stage, identity, organization, session, Authority
  Grant, target, scope, and time binding
- Typed withdrawal, correction, and supersession lineage
- Append-oriented Approval Action and duty-link protection
- Requester and directly affected identity approval restrictions
- Effective-actor uniqueness
- Distinct-organization enforcement
- Authority Grant origin independence
- Explicit circular and reciprocal approval protection
- Direct and delegated Authority Grant lineage with bounded delegation
- `JOINT_EXERCISE`, `CONCURRENT_HOLDING`, and `CHAIN_PARTICIPATION`
  incompatible-authority enforcement
- Immutable `APPROVE` duty recording
- Policy-defined prohibited-duty evaluation
- Fail-closed handling for an unavailable governed duty scope
- Current Approval Action derivation
- Persisted policy-stage satisfaction and blocking-denial outcomes
- Finalization-once Approval Requests
- Caller-result mismatch rejection
- Exact Decision Record stage linkage
- Fail-closed later-use approval continuity for approval-backed Authorization
  Leases
- Preservation of approval-unrelated Decision Records and leases
- Stable request-chain serialization without one global approval lock
- Authority Grant current-state reads protected from concurrent mutation
- Independent-connection concurrency proofs for every accepted Phase 4 race
  family
- Continued preservation of every accepted Phase 1, Phase 2, and Phase 3
  invariant

## 4. Implementation Evidence

Principal production migration:

```text
sql/schema/migrations/foundation/
└── 083_postgresql_approval_independence_and_separation_of_duties.sql
```

Principal sequential tests:

```text
test-framework/sql/tests/foundation/
├── 170_approval_independence_and_separation_of_duties_structure.sql
├── 180_controlled_approval_action_recording.sql
├── 190_approval_independence_enforcement.sql
├── 200_incompatible_authority_and_duty_conflict_enforcement.sql
└── 210_approval_stage_satisfaction_and_finalization.sql
```

Phase 4 concurrency tests:

```text
test-framework/sql/tests/concurrency/
├── 190_approval_duplicate_actor_race.sh
├── 200_approval_stage_finalized_evaluation_race.sh
├── 210_approval_request_finalization_race.sh
├── 220_approval_last_approval_finalization_race.sh
├── 230_approval_withdrawal_finalization_race.sh
├── 240_approval_authority_revocation_race.sh
└── 250_approval_reciprocal_approval_race.sh
```

Test orchestration:

```text
test-framework/sql/schema/scripts/test_foundation.sh
test-framework/sql/schema/scripts/test_foundation_with_resources.sh
test-framework/sql/tests/foundation-tests.manifest
test-framework/sql/tests/foundation-concurrency-tests.manifest
```

Final implementation gate:

```text
tools/validation/phase-gates/validate_phase4_step7.sh
```

Formal acceptance gate:

```text
tools/validation/phase-gates/validate_phase4_step8.sh
```

## 5. Accepted Test and Gate Results

The accepted Foundation boundary completed with:

```text
34 manifest migrations
34 registered migrations
21 sequential test files
16 concurrency test files
734 PASS
0 FAIL
3 understood WARN
Correctness result: PASS
Resource observation: RECORDED
Performance thresholds: NOT_EVALUATED
```

The final Step 7 implementation gate completed with:

```text
PASS checks: 159
FAIL checks: 0
```

That result records 159 phase-gate PASS checks and 0 phase-gate FAIL checks.

The resource JSON run identifier matched the correctness summary. Performance
thresholds remained observation-only and were not promoted into correctness
failures.

## 6. Independent-Connection Evidence

### 6.1 Duplicate Effective Actor

Concurrent attempts by the same effective actor cannot create two current
counted approvals for the same request and stage. Exactly one valid serial
outcome is permitted.

### 6.2 Finalized Stage Evaluation

Concurrent stage-evaluation attempts persist exactly one finalized evaluation
for the same Approval Request and policy stage.

### 6.3 Approval Request Finalization

Concurrent finalization attempts produce exactly one terminal transition and
one finalization record.

### 6.4 Last Approval Versus Finalization

A final approval racing request finalization produces only a valid serial
outcome. Finalization cannot consume a partially observed approval state.

### 6.5 Withdrawal Versus Finalization

Withdrawal and finalization cannot create a mixed state. Exactly one valid
transition order governs the final result.

### 6.6 Authority Grant Revocation Versus Approval

Approval recording and Authority Grant suspension or revocation have one valid
serial order. A non-current grant cannot contribute a later counted approval.

### 6.7 Reciprocal Approval

Concurrent reciprocal approvals across explicitly linked requests permit at
most one successful side when reciprocal participation is prohibited.

## 7. Acceptance-Gate Results

| Gate | Result |
|---|---|
| Normative Phase 4 contract present | PASS |
| Accepted Phase 1, Phase 2, and Phase 3 boundaries preserved | PASS |
| Full 34-migration Foundation manifest installs | PASS |
| Manifest and registry both contain 34 migrations | PASS |
| 21 sequential tests complete | PASS |
| 16 concurrency tests complete | PASS |
| Controlled Approval Action recording | PASS |
| Approval independence enforcement | PASS |
| Delegated Authority Grant lineage | PASS |
| Incompatible-authority enforcement | PASS |
| Prohibited-duty enforcement | PASS |
| Stage satisfaction and blocking denial | PASS |
| Approval Request finalization once | PASS |
| Decision Record stage linkage | PASS |
| Later-use approval continuity | PASS |
| Duplicate effective-actor race | PASS |
| Finalized stage-evaluation race | PASS |
| Approval Request finalization race | PASS |
| Last approval versus finalization race | PASS |
| Withdrawal versus finalization race | PASS |
| Authority Grant revocation versus approval race | PASS |
| Reciprocal approval race | PASS |
| Migration timeout contract | PASS |
| Correctness runner exits with status zero | PASS |
| Summary contains zero failed assertions | PASS |
| Resource observation is recorded | PASS |
| No new warning category is introduced | PASS |
| Annotated Phase 4 tag identifies the accepted tree | PASS |

## 8. Known Warnings

The accepted run retained three understood warnings.

### 8.1 Missing Stored Migration Checksums

All migration files have SHA-256 values calculated by the test runner, but the
migrations still register `NULL` checksum values. Stored checksum population
and enforcement remain required before stable or production migration
handling.

### 8.2 Direct `PUBLIC USAGE` on Foundation-Defined Types

`PUBLIC` cannot reach the affected types because `PUBLIC` has no `USAGE` on
the containing Foundation schemas. Direct type grants remain a
defense-in-depth review item.

### 8.3 Applied-Migration Registry Immutability

The registry is documented as append-only and has no direct non-owner write
grant, but an enabled database trigger does not yet prevent owner-level
`UPDATE` or `DELETE`. This remains unresolved Foundation hardening work.

## 9. Explicit Non-Claims

Phase 4 acceptance does not prove or provide:

- Production readiness
- Final production ownership and login-role topology
- Least-privileged runtime grants
- Complete append-only mutation protection
- Stored migration-checksum enforcement
- Decision Record cryptographic integrity anchoring
- Production Go approval or authorization services
- Production notification, escalation, or user-interface workflows
- Module-specific business workflow
- Legal conflict-of-interest determinations
- Off-host integrity anchoring and protected export
- Backup protection and restore validation
- Break-glass procedures
- Trusted rebuild and compromise recovery
- Distributed or multi-region approval coordination

## 10. Revalidation Triggers

Phase 4 must be revalidated after any change to:

- Approval Policy Version or stage structure
- Approval Request context or lifecycle
- Approval Action Record structure or action types
- Effective actor semantics
- Requester or directly affected identity semantics
- Authority Grant applicability, status, or delegation lineage
- Incompatible Authority Sets
- Separation-of-duties duties or prohibited combinations
- Approval stage satisfaction
- Approval Request finalization
- Withdrawal, correction, or supersession semantics
- Decision Record approval-stage linkage
- Authorization Decision or Authorization Lease reliance on approvals
- Migrations `050`, `055`, `080`, `081`, or `083`
- Foundation sequential or concurrency manifests
- Approval-related locking or serialization
- The accepted Phase 4 tag or this acceptance record
- The normative Phase 4 contract

## 11. Handoff

Later Foundation work may build on these accepted invariants:

- An approval is a bounded policy input, not raw authority.
- Counted approvals are current, eligible, applicable, independent, and
  context-bound.
- One effective actor cannot manufacture multiple independent approvals.
- Prohibited authority and duty combinations fail closed.
- Approval stages are satisfied through controlled evaluation, not raw row
  counts.
- Approval Requests finalize once.
- Decision Records retain exact approval-stage linkage.
- Approval-backed later authority fails closed when approval continuity is
  lost.
- Concurrent callers cannot duplicate counted approvals, stage finalization,
  request finalization, or reciprocal participation.
- Downstream services and modules consume governed Foundation decisions and do
  not become independent authority sources.

The next Foundation work should freeze its own contract before implementation.
