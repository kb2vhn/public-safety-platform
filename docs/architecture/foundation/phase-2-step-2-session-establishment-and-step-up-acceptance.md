# Phase 2 Step 2 Session Establishment and Step-Up Acceptance

> **Layer:** Platform Foundation
>
> **Phase:** 2 — Session Establishment, Step-Up, and Lifecycle Enforcement
>
> **Accepted step:** Step 2 — Session Schema and Atomic Establishment/Step-Up Workflows
>
> **Acceptance date:** 2026-07-12
>
> **Status:** Accepted for the Phase 2 Step 2 scope defined below
>
> **Authoritative contract:**
> [Session Establishment, Step-Up, and Lifecycle Model](session-establishment-step-up-and-lifecycle-model.md)
>
> **Accepted dependency:**
> [Phase 1 Authentication Assertion Acceptance](phase-1-authentication-assertion-acceptance.md)

## 1. Acceptance Decision

Phase 2 Step 2 is accepted.

This decision means the implemented PostgreSQL session-establishment and
step-up boundary, together with the normal Foundation clean-install and
regression path, satisfied the Phase 2 Step 2 acceptance gate on 2026-07-12.

This is an incremental Phase 2 acceptance boundary. It does not accept Phase 2
as complete and does not declare the Platform Foundation, session subsystem,
authorization system, Go runtime, or deployment environment production-ready.

## 2. Accepted Scope

The accepted Phase 2 Step 2 scope includes:

- Strengthened session lifecycle state shape in `060_sessions.sql`,
- Explicit session absolute expiration,
- Optional inactivity timeout,
- Session activity and step-up chronology constraints,
- Complete mutually exclusive current-state timestamp constraints,
- Session-event types for creation, activity, step-up, lock, unlock,
  expiration, revocation, and termination,
- Authentication Assertion linkage for session establishment,
- Authentication Assertion linkage for the latest completed step-up,
- One-establishment-assertion-to-one-session enforcement,
- One-step-up-assertion-to-one-evidence-record enforcement,
- Current local identity revalidation before session establishment,
- Current local Trust Provider revalidation before session establishment,
- Current Trust Provider revocation revalidation,
- Current bound-device trust and revocation revalidation,
- Current bound-Platform-Service revalidation,
- Optional selected-organization status and validity revalidation,
- Atomic exact-context consumption of one `SESSION_ESTABLISHMENT`
  Authentication Assertion,
- Atomic creation of one `ACTIVE` session derived from the consumed assertion,
- Same-transaction creation of one timestamp-aligned `CREATED` session event,
- Atomic exact-context consumption of one `SESSION_STEP_UP`
  Authentication Assertion,
- Same-transaction recording of fresh step-up evidence,
- Same-transaction creation of one timestamp-aligned
  `STEP_UP_COMPLETED` session event,
- Preservation of immutable session bindings and absolute expiration during
  step-up,
- Sequential replay denial for establishment and step-up assertions,
- Fixed trusted controlled-function `search_path` settings,
- Removal of controlled-function execution from `PUBLIC`,
- Complete Phase 0 and Phase 1 regression execution through the normal
  Foundation test command.

## 3. Implementation Evidence

Principal production migrations:

```text
sql/schema/migrations/foundation/
├── 060_sessions.sql
├── 070_postgresql_authentication_assertion_gate.sql
└── 072_postgresql_session_control.sql
```

Principal Phase 2 Step 2 sequential test:

```text
test-framework/sql/tests/foundation/
└── 110_session_establishment_and_step_up_behavior.sql
```

Preserved Phase 1 sequential and concurrency regression evidence:

```text
test-framework/sql/tests/foundation/
├── 090_authentication_assertion_behavior.sql
└── 100_authentication_assertion_phase1_behavior.sql

test-framework/sql/tests/concurrency/
└── 100_authentication_assertion_single_use.sh
```

Test orchestration:

```text
test-framework/sql/schema/scripts/test_foundation.sh
test-framework/sql/tests/foundation-tests.manifest
test-framework/sql/tests/foundation-concurrency-tests.manifest
```

## 4. Accepted Test Run

The normal Foundation test command was:

```bash
./test-framework/sql/schema/scripts/test_foundation.sh
```

Accepted run evidence:

```text
Run ID: foundation_20260712_055135_174373
Completed: 2026-07-12T05:51:39-04:00
PostgreSQL server_version_num: 180004
Overall result: PASS
Runner exit status: 0
Manifest migrations: 32
Registered migrations: 32
Sequential test files: 11
Concurrency test files: 1
PASS: 147
FAIL: 0
WARN: 3
```

The successful disposable database was dropped by the runner after the result
inventory and summary were written.

## 5. Session Establishment Evidence

The accepted run demonstrated that:

1. A nonpositive absolute lifetime is rejected.
2. An unavailable selected organization is denied.
3. A failed selected-organization check does not consume the assertion.
4. A valid exact-context establishment consumes one verified
   `SESSION_ESTABLISHMENT` assertion.
5. The same transaction creates one `ACTIVE` session.
6. The session identity, device, Trust Provider, and Platform Service bindings
   match the consumed assertion.
7. The selected organization is retained only as selected context.
8. The database computes authentication, expiration, and initial activity
   timestamps.
9. The created session retains the establishment assertion identifier.
10. Exactly one timestamp-aligned `CREATED` event is written.
11. A consumed establishment assertion cannot create a second session.

## 6. Step-Up Evidence

The accepted run demonstrated that:

1. A valid exact-context `SESSION_STEP_UP` assertion verifies against the
   active target session.
2. Step-up consumes the assertion through the accepted Phase 1 boundary.
3. The same transaction records `last_step_up_at`.
4. The same transaction records the latest step-up assertion identifier.
5. Exactly one timestamp-aligned `STEP_UP_COMPLETED` event is written.
6. Step-up preserves the session identity.
7. Step-up preserves the selected organization.
8. Step-up preserves the device binding.
9. Step-up preserves the Trust Provider binding.
10. Step-up preserves the Platform Service binding.
11. Step-up preserves the correlation identifier.
12. Step-up preserves the original authentication time.
13. Step-up does not extend the absolute expiration.
14. Step-up does not modify the existing activity timestamp.
15. A consumed step-up assertion cannot complete a second step-up.

## 7. Phase 1 Regression Preservation

The complete accepted Phase 1 suite remained in the normal test path.

The accepted Step 2 run preserved:

- Controlled local Authentication Assertion verification,
- Exact-context consumption,
- Rejection, expiration, and revocation behavior,
- Verification-history preservation,
- Terminal-state enforcement,
- Sequential replay denial,
- Generic mismatch denial,
- Two-connection concurrent single-use enforcement.

The Phase 1 concurrency result remained:

```text
ready=2
success=1
denied=1
unexpected=0
final_status=CONSUMED
consumed_at=1
```

No Phase 1 invariant was removed or weakened by Step 2.

## 8. Acceptance-Gate Results

| Gate | Result |
|---|---|
| Normative Phase 2 session contract present | PASS |
| Accepted Phase 1 boundary remains identifiable | PASS |
| Strengthened migration `060` installs in an empty database | PASS |
| Migration `072` is ordered after `070` and before `075` | PASS |
| Full 32-migration Foundation manifest installs | PASS |
| Manifest and migration registry both contain 32 migrations | PASS |
| Prior Phase 0 tests continue to pass | PASS |
| Complete Phase 1 sequential tests continue to pass | PASS |
| Phase 1 concurrent single-use test continues to pass | PASS |
| Invalid establishment lifetime is rejected | PASS |
| Invalid organization context does not consume the assertion | PASS |
| Valid establishment consumes exactly one assertion | PASS |
| Valid establishment creates exactly one active session | PASS |
| Session bindings are derived from the assertion | PASS |
| Establishment records one matching event | PASS |
| Sequential establishment replay is denied | PASS |
| Valid step-up consumes exactly one assertion | PASS |
| Step-up records fresh evidence | PASS |
| Step-up preserves immutable session context | PASS |
| Step-up does not extend absolute expiration | PASS |
| Step-up records one matching event | PASS |
| Sequential step-up replay is denied | PASS |
| Controlled session functions are unavailable to `PUBLIC` | PASS |
| Controlled functions use fixed trusted search paths | PASS |
| Normal runner exits with status `0` | PASS |
| Summary contains zero failed assertions | PASS |
| No unexpected warning category was introduced | PASS |

## 9. Known Warnings

The accepted run retained three previously understood warnings.

### 9.1 Missing Stored Migration Checksums

All 32 migration files had SHA-256 values calculated by the test runner, but
the migrations still register `NULL` checksum values.

Stored checksum population and enforcement remain required before stable or
production migration enforcement.

### 9.2 Direct `PUBLIC USAGE` on Foundation-Defined Types

`PUBLIC` cannot reach the affected types because `PUBLIC` has no `USAGE` on
the containing Foundation schemas.

Direct type grants nevertheless remain a defense-in-depth review item.

### 9.3 Applied-Migration Registry Immutability

The registry is documented as append-only and has no direct non-owner write
grant, but an enabled database trigger does not yet prevent owner-level
`UPDATE` or `DELETE`.

This remains unresolved Foundation hardening work.

## 10. Explicit Non-Claims

Phase 2 Step 2 acceptance does not prove or provide:

- Controlled session activity checkpoints,
- Controlled lock behavior,
- Controlled administrative unlock behavior,
- Controlled session expiration behavior,
- Controlled session revocation behavior,
- Controlled session termination behavior,
- Session lifecycle concurrency proofs,
- Session-establishment concurrency proof,
- Step-up concurrency proof,
- Incompatible terminal-transition concurrency proof,
- Production bearer-token security,
- Production JWT, PASETO, cookie, or refresh-token handling,
- Production Go session services,
- Complete authorization evaluation,
- Access Eligibility evaluation,
- Organization participation evaluation,
- Authority Grant evaluation,
- Approval independence enforcement,
- Deterministic Authorization Policy selection,
- Authorization Lease issuance or renewal,
- Protected-operation authorization,
- Final database ownership and login-role topology,
- Least-privileged production grants,
- Complete append-only enforcement,
- Off-host logging or integrity anchoring,
- Backup protection and restoration validation,
- Break-glass access,
- Trusted rebuild or compromise recovery,
- Production readiness.

## 11. Handoff to Phase 2 Step 3

Phase 2 Step 3 may build on these accepted invariants:

- An active session is created only through the controlled establishment
  workflow.
- Session establishment atomically consumes one exact-context verified
  Authentication Assertion.
- Session identity, device, Trust Provider, and Platform Service bindings are
  derived from the consumed assertion.
- The selected organization remains context rather than proof of authority.
- Step-up atomically consumes one exact-context verified Authentication
  Assertion bound to the active session.
- Step-up records fresh evidence without granting permanent elevation.
- Establishment and step-up events commit or roll back with their corresponding
  session mutations.
- PostgreSQL statement time is authoritative.
- Controlled functions remain unavailable to `PUBLIC`.
- Phase 1 assertion single-use and terminal-state guarantees remain binding.

Step 3 should extend migration `072_postgresql_session_control.sql` with:

- Controlled activity recording,
- Controlled lock,
- Controlled administrative unlock,
- Controlled expiration,
- Controlled revocation,
- Controlled termination,
- Same-transaction event consistency.

Step 3 must not weaken the accepted establishment, step-up, or Phase 1
Authentication Assertion boundaries.

## 12. Revalidation Triggers

This Step 2 acceptance must be rerun before it is relied upon after any change
to:

- Migration `060`,
- Migration `070`,
- Migration `072`,
- Session-table state or chronology constraints,
- Session-event constraints,
- Authentication Assertion linkage,
- Controlled session-establishment behavior,
- Controlled step-up behavior,
- Bound identity, device, Trust Provider, Platform Service, organization, or
  environment columns used by the accepted workflows,
- Phase 1 or Step 2 sequential tests,
- The Phase 1 concurrency test or its barrier,
- The Foundation test runner,
- Either Foundation test manifest,
- The Foundation migration manifest,
- PostgreSQL major-version requirements,
- Runtime grants or ownership affecting controlled assertion or session
  functions.

A passing historical result does not replace a fresh run after a relevant
change.
