# Phase 3 Authorization Decision and Controlled Lease Acceptance

> **Layer:** Platform Foundation
>
> **Phase:** 3 — Authorization Decision and Controlled Lease Issuance
>
> **Acceptance date:** 2026-07-12
>
> **Status:** Accepted for the Phase 3 scope defined below
>
> **Authoritative contract:**
> [Authorization Decision and Lease Issuance Model](authorization-decision-and-lease-issuance-model.md)
>
> **Accepted release tag:** `phase-3-authorization-control-complete-v1`

## 1. Acceptance Decision

Phase 3 is accepted.

This decision means the PostgreSQL authorization-policy selection,
Decision Record finalization, controlled Authorization Lease issuance,
exact-context use, fail-closed revalidation, and independent-connection
concurrency boundary satisfied the Phase 3 acceptance gate on
2026-07-12.

It does not declare the complete Platform Foundation, approval system,
Go runtime, deployment environment, client applications, or production
operating model ready for production use.

## 2. Authoritative Accepted Tree

The annotated Git tag is the durable identifier for the exact accepted
implementation tree:

```text
phase-3-authorization-control-complete-v1
```

The tag dereferences to:

```text
853d26e37f1471aeeaeea4e7690e1a0605a22870
```

The tag target is authoritative. This acceptance record is an
administrative documentation commit created after the tag. It must
descend from the tag and must not alter the accepted SQL or test tree.

## 3. Accepted Scope

The accepted Phase 3 scope includes:

- Typed, deterministic Authorization Policy Version applicability
- Missing-policy and ambiguous-policy fail-closed behavior
- Controlled policy binding to persisted Decision Record context
- Exact policy-stage requirement linkage
- Persistent `PASS`, `FAIL`, `NOT_REQUIRED`, and `NOT_EVALUATED`
  evaluation results
- Required-stage closure before `ALLOW`
- Exact policy-rule support for `NOT_REQUIRED`
- Required supporting-record enforcement
- Finalization-once Decision Records
- Rejection of caller-controlled final results
- Controlled Authorization Lease issuance only from a finalized,
  eligible `ALLOW`
- One issuing or renewing Decision Record per lease
- Exact decision-to-lease context binding
- Policy-, request-, session-, evidence-, and authority-bounded
  lifetime
- Verifier-only lease-secret persistence
- Exact-context lease verification
- Reusable, single-use, and limited-use accounting
- Same-transaction attributable lease-use events
- Materialized expiration
- Reason-coded revocation
- Current session, identity, device, Trust Provider, Platform Service,
  policy, evidence, and authority revalidation
- Denial without counter mutation or use-event creation
- Independent-connection finalization, issuance, consumption, and
  terminal-transition proofs
- Continued preservation of every accepted Phase 1 and Phase 2
  invariant
- Fixed trusted function `search_path` settings
- Removal of controlled-function execution from `PUBLIC`
- No `SECURITY DEFINER` in the accepted Phase 3 controlled routines

## 4. Implementation Evidence

Principal production migration:

```text
sql/schema/migrations/foundation/
└── 081_postgresql_authorization_decision_and_lease_issuance.sql
```

Principal sequential tests:

```text
test-framework/sql/tests/foundation/
├── 130_authorization_decision_and_lease_structure.sql
├── 140_authorization_policy_selection_and_decision_finalization.sql
├── 150_authorization_lease_issuance_and_use.sql
└── 160_authorization_lease_fail_closed_behavior.sql
```

Phase 3 concurrency tests:

```text
test-framework/sql/tests/concurrency/
├── 140_authorization_decision_finalization_race.sh
├── 150_authorization_lease_issuance_race.sh
├── 160_authorization_lease_single_use_race.sh
├── 170_authorization_lease_limited_use_race.sh
└── 180_authorization_lease_terminal_transition_race.sh
```

Test orchestration:

```text
test-framework/sql/schema/scripts/test_foundation.sh
test-framework/sql/tests/foundation-tests.manifest
test-framework/sql/tests/foundation-concurrency-tests.manifest
```

Final Phase 3 implementation gate:

```text
tools/validation/phase-gates/validate_phase3_step6.sh
```

## 5. Accepted Test Run

The accepted normal Foundation test path completed with:

```text
Run ID: foundation_20260712_153451_205538
Completed: 2026-07-12T15:34:59-04:00
Host: psp
Connected role: jwood
PostgreSQL server_version_num: 180004
Overall result: PASS
Runner exit status: 0
Sequential test files: 16
Concurrency test files: 9
Manifest migrations: 33
Registered migrations: 33
PASS: 408
FAIL: 0
WARN: 3
```

The successful disposable database
`psp_foundation_test_20260712_153451_205538` was dropped by the runner
after the result inventory and summary were written.

The final Step 6 phase gate completed with:

```text
PASS checks: 99
FAIL checks: 0
```

## 6. Independent-Connection Evidence

The complete suite retained the four accepted Phase 1 and Phase 2
concurrency tests and added five Phase 3 races.

### 6.1 Decision Record Finalization

Two independent workers attempted to finalize the same draft Decision
Record. Exactly one transition succeeded. The final record had one
terminal result, one finalization timestamp, one selected policy, and
complete required-stage closure.

### 6.2 Authorization Lease Issuance

Two independent workers attempted to issue a lease from the same
eligible finalized Decision Record. Exactly one lease was created and
linked. The stored secret remained a verifier, not plaintext.

### 6.3 Single-Use Lease Consumption

Two independent workers attempted to consume the same single-use
Authorization Lease. Exactly one protected operation succeeded, exactly
one use event was written, and the lease became `CONSUMED`.

### 6.4 Final Limited-Use Slot

Two independent workers attempted to consume the final remaining use of
one limited-use lease. Exactly one worker received the final slot.
Counters, use numbers, Decision Records, and use events remained
contiguous and non-duplicated.

### 6.5 Expiration Versus Revocation

Two independent workers raced expiration and revocation against the
same lease.

Accepted result:

```text
ready=2
true=1
false=1
unexpected=0
final_status=EXPIRED
terminal_timestamps=1
state_shape=1
reason_shape=1
use_count=0
events=0
decision_link=1
```

Either `EXPIRED` or `REVOKED` may legitimately win a later run.
Acceptance requires exactly one successful terminal transition, one
matching terminal timestamp, a valid reason shape, and no mixed state.

## 7. Acceptance-Gate Results

| Gate | Result |
|---|---|
| Normative Phase 3 contract present | PASS |
| Accepted Phase 1 tag remains identifiable | PASS |
| Accepted Phase 2 tag remains identifiable | PASS |
| Migration `081` installs in an empty database | PASS |
| Full 33-migration Foundation manifest installs | PASS |
| Manifest and registry both contain 33 migrations | PASS |
| All accepted Phase 1 and Phase 2 tests pass | PASS |
| Deterministic policy selection passes | PASS |
| Missing and ambiguous policy deny | PASS |
| Required-stage closure passes | PASS |
| Invalid `NOT_REQUIRED` is rejected | PASS |
| Decision Records finalize once | PASS |
| Caller-controlled final results are rejected | PASS |
| Only eligible finalized `ALLOW` decisions issue leases | PASS |
| One decision issues at most one lease | PASS |
| Lease context and lifetime bounds pass | PASS |
| Plaintext lease secrets are not persisted | PASS |
| Reusable, single-use, and limited-use behavior passes | PASS |
| Failed use attempts mutate no counters or events | PASS |
| Stale session, trust, policy, evidence, and authority deny | PASS |
| Concurrent finalization has one winner | PASS |
| Concurrent issuance has one winner | PASS |
| Concurrent single-use consumption has one winner | PASS |
| Concurrent final limited-use slot has one winner | PASS |
| Concurrent terminal transitions have one winner | PASS |
| Controlled routines are unavailable to `PUBLIC` | PASS |
| Accepted Phase 3 routines avoid `SECURITY DEFINER` | PASS |
| Normal runner exits with status `0` | PASS |
| Summary contains zero failed assertions | PASS |
| No new warning category was introduced | PASS |
| Annotated Phase 3 tag identifies the accepted tree | PASS |

## 8. Known Warnings

The accepted run retained three understood warnings.

### 8.1 Missing Stored Migration Checksums

All 33 migration files had SHA-256 values calculated by the test runner,
but the migrations still register `NULL` checksum values. Stored
checksum population and enforcement remain required before stable or
production migration handling.

### 8.2 Direct `PUBLIC USAGE` on Foundation-Defined Types

`PUBLIC` cannot reach the affected types because `PUBLIC` has no
`USAGE` on the containing Foundation schemas. Direct type grants remain
a defense-in-depth review item.

### 8.3 Applied-Migration Registry Immutability

The registry is documented as append-only and has no direct non-owner
write grant, but an enabled database trigger does not yet prevent
owner-level `UPDATE` or `DELETE`. This remains unresolved Foundation
hardening work.

## 9. Explicit Non-Claims

Phase 3 acceptance does not prove or provide:

- Complete approval independence or self-approval prevention
- Complete incompatible-authority and separation-of-duties evaluation
- Final production ownership and login-role topology
- Least-privileged runtime function grants
- Complete append-only mutation protection
- Stored migration-checksum enforcement
- Decision Record cryptographic integrity anchoring
- Production Go authorization services
- Production lease-secret delivery
- External policy-engine integration
- Distributed or multi-region invalidation
- Off-host integrity anchoring and protected export
- Backup protection and restore validation
- Break-glass procedures
- Trusted rebuild and compromise recovery
- Production readiness

## 10. Handoff

Later Foundation work may build on these accepted invariants:

- Exactly one policy version governs one authorization decision.
- Missing or ambiguous policy fails closed.
- Required decision stages cannot be bypassed.
- A Decision Record finalizes once.
- Only a finalized eligible `ALLOW` can issue a lease.
- One issuing decision creates at most one lease.
- Lease authority is exact, short-lived, revocable, and context-bound.
- Possession of a lease secret is not sufficient.
- Failed use attempts create no successful-use side effects.
- Concurrent callers cannot duplicate finalization, issuance,
  consumption, or terminal transitions.
- Authentication, session state, approval evidence, authority evidence,
  and policy remain inputs to authorization rather than substitutes for
  it.

The next Foundation phase should freeze its own contract before
implementation. The leading remaining authorization work is approval
independence, self-approval prevention, incompatible-authority and
separation-of-duties enforcement, and stronger historical integrity.

## 11. Revalidation Triggers

Phase 3 acceptance must be rerun before it is relied upon after any
change to:

- Migrations `055`, `060`, `065`, `070`, `072`, `075`, `080`, or `081`
- Authority, policy, approval, session, Decision Record, or lease
  structures
- Policy-selection precedence
- Decision-stage definitions or closure rules
- Finalization behavior
- Lease issuance, verification, consumption, expiration, or revocation
- Decision or lease privileges and ownership
- Either Foundation test manifest
- Any accepted Phase 1, Phase 2, or Phase 3 sequential test
- Any of the nine concurrency tests or their release barriers
- The Foundation test runner
- PostgreSQL major-version requirements
- The normative Phase 3 contract
- This acceptance record
- The accepted release tag

A passing historical result does not replace a fresh run after a
relevant change.
