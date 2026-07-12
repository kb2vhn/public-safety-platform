# Phase 2 Session Establishment, Step-Up, and Lifecycle Acceptance

> **Layer:** Platform Foundation
> **Phase:** 2 — Session Establishment, Step-Up, and Lifecycle Control
> **Acceptance date:** 2026-07-12
> **Status:** Accepted for the Phase 2 scope defined below
> **Authoritative contract:** [Session Establishment, Step-Up, and Lifecycle Model](session-establishment-step-up-and-lifecycle-model.md)
> **Accepted release tag:** `phase-2-session-control-complete-v1`

## 1. Acceptance Decision

Phase 2 is accepted.

This decision means the PostgreSQL session establishment, step-up, activity,
lifecycle, event-consistency, and concurrency boundary satisfied the Phase 2
acceptance gate on 2026-07-12.

It does not declare the complete Platform Foundation, authorization system, Go
runtime, client applications, deployment environment, or production operating
model ready for production use.

The annotated Git tag `phase-2-session-control-complete-v1` is the durable identifier for the exact
accepted repository tree. The tag target, rather than a manually copied commit
identifier in this document, is authoritative.

## 2. Accepted Scope

The accepted Phase 2 scope includes:

- Strengthened session state, chronology, and event-shape constraints
- Assertion-linked session establishment
- Atomic consumption of a verified `SESSION_ESTABLISHMENT` assertion
- Exact binding of the created session to identity, device, Trust Provider,
  Platform Service, organization, audience, and environment
- Preservation of the absolute session lifetime during later operations
- Atomic step-up completion from a verified `SESSION_STEP_UP` assertion
- Exact binding of current step-up evidence to the session
- Controlled session activity recording
- Monotonic activity checkpoints
- Current local trust revalidation before activity and administrative unlock
- Controlled `ACTIVE → LOCKED` transition
- Controlled `LOCKED → ACTIVE` administrative unlock
- Absolute expiration
- Inactivity expiration
- Expiration from both `ACTIVE` and `LOCKED`
- Revocation from both `ACTIVE` and `LOCKED`
- Termination from both `ACTIVE` and `LOCKED`
- Terminal-state enforcement for `EXPIRED`, `REVOKED`, and `TERMINATED`
- One timestamp-aligned event for every successful lifecycle transition
- No lifecycle event for a refused transition
- Human-identity or system-reference actor attribution where required
- Fixed trusted function `search_path` settings
- Removal of controlled session-function execution from `PUBLIC`
- Absence of `SECURITY DEFINER` from the accepted session-control functions
- Sequential negative, chronology, trust, state, privilege, and event tests
- Independent-connection session-establishment single-use enforcement
- Independent-connection session-step-up single-use enforcement
- Independent incompatible terminal-transition serialization
- Continued execution of the accepted Phase 1 assertion-consumption race
- Sequential and concurrency integration in the normal Foundation test command

## 3. Implementation Evidence

Principal production migrations:

```text
sql/schema/migrations/foundation/
├── 060_sessions.sql
├── 070_postgresql_authentication_assertion_gate.sql
└── 072_postgresql_session_control.sql
```

Principal sequential tests:

```text
test-framework/sql/tests/foundation/
├── 090_authentication_assertion_behavior.sql
├── 100_authentication_assertion_phase1_behavior.sql
├── 110_session_establishment_and_step_up_behavior.sql
└── 120_session_lifecycle_behavior.sql
```

Concurrency tests:

```text
test-framework/sql/tests/concurrency/
├── 100_authentication_assertion_single_use.sh
├── 110_session_establishment_single_use.sh
├── 120_session_step_up_single_use.sh
└── 130_session_terminal_transition_race.sh
```

Test orchestration:

```text
test-framework/sql/schema/scripts/test_foundation.sh
test-framework/sql/tests/foundation-tests.manifest
test-framework/sql/tests/foundation-concurrency-tests.manifest
```

Step 6 acceptance validation:

```text
validate_phase2_step6.sh
```

## 4. Accepted Test Run

The normal Foundation test command was:

```bash
./test-framework/sql/schema/scripts/test_foundation.sh
```

Accepted Step 5 run evidence:

```text
Run ID: foundation_20260712_082801_183214
Completed: 2026-07-12T08:28:08-04:00
Host: psp
Connected role: jwood
PostgreSQL server_version_num: 180004
Overall result: PASS
Runner exit status: 0
Sequential test files: 12
Concurrency test files: 4
Manifest migrations: 32
Registered migrations: 32
PASS: 213
FAIL: 0
WARN: 3
```

The successful disposable database
`psp_foundation_test_20260712_082801_183214` was dropped by the runner after
the result inventory and summary were written.

The Step 6 validator must reproduce the same structural totals and zero-failure
result against the final acceptance tree before the release tag is verified.

## 5. Concurrent Single-Use and Terminality Evidence

### 5.1 Phase 1 Authentication Assertion Consumption

```text
ready=2
success=1
denied=1
unexpected=0
final_status=CONSUMED
consumed_at=1
```

### 5.2 Session Establishment

```text
ready=2
success=1
denied=1
unexpected=0
assertion=CONSUMED
sessions=1
created_events=1
linkage=1
```

### 5.3 Session Step-Up

```text
ready=2
success=1
denied=1
unexpected=0
assertion=CONSUMED
session_evidence=1
step_up_events=1
linkage=1
```

### 5.4 Incompatible Terminal Transitions

The accepted run allowed termination to win this nondeterministic race:

```text
ready=2
true=1
false=1
unexpected=0
final_status=TERMINATED
terminal_timestamps=1
terminal_events=1
matching_events=1
mixed_state_guard=1
```

Either `REVOKED` or `TERMINATED` may legitimately win a later run. Acceptance
requires exactly one winner, exactly one matching terminal timestamp, exactly
one matching terminal event, and no mixed terminal state.

## 6. Acceptance-Gate Results

| Gate | Result |
|---|---|
| Normative Phase 2 contract present | PASS |
| Accepted Phase 1 tag remains identifiable | PASS |
| Migration `060` remains unchanged from its accepted boundary | PASS |
| Migration `070` remains unchanged from its accepted boundary | PASS |
| Migration `072` installs in an empty database | PASS |
| Full 32-migration Foundation manifest installs | PASS |
| Manifest and migration registry contain the same 32 migrations | PASS |
| All accepted Phase 0 and Phase 1 tests pass | PASS |
| Atomic session establishment positive and negative tests pass | PASS |
| Consumed establishment assertions cannot create another session | PASS |
| Atomic step-up positive and negative tests pass | PASS |
| Consumed step-up assertions cannot complete another step-up | PASS |
| Activity monotonicity and current-trust checks pass | PASS |
| Lock and administrative unlock behavior passes | PASS |
| Absolute and inactivity expiration behavior passes | PASS |
| Revocation and termination behavior passes | PASS |
| Terminal sessions reject all later lifecycle operations | PASS |
| Successful transitions write exactly one matching event | PASS |
| Refused transitions write no lifecycle event | PASS |
| Session state and chronology constraints reject contradictions | PASS |
| Session-event assertion-shape constraints reject contradictions | PASS |
| Controlled functions are unavailable to `PUBLIC` | PASS |
| Controlled functions use trusted fixed search paths | PASS |
| Accepted session functions do not use `SECURITY DEFINER` | PASS |
| Concurrent establishment has exactly one winner | PASS |
| Concurrent step-up has exactly one winner | PASS |
| Incompatible terminal transitions have exactly one winner | PASS |
| Concurrency races create no duplicate or mixed state | PASS |
| Normal runner exits with status `0` | PASS |
| Summary contains zero failed assertions | PASS |
| No new warning category was introduced by Phase 2 | PASS |
| Formal acceptance record is committed | PASS when tagged |
| Annotated acceptance tag points to the acceptance commit | PASS when verified |

## 7. Known Warnings

The accepted run retained three understood warnings.

### 7.1 Missing Stored Migration Checksums

All 32 migration files had SHA-256 values calculated by the test runner, but
the migrations still register `NULL` checksum values. This remains required
before stable or production migration enforcement.

### 7.2 Direct `PUBLIC USAGE` on Foundation-Defined Types

`PUBLIC` cannot reach the affected types because `PUBLIC` has no `USAGE` on
the containing Foundation schemas.

Direct type grants nevertheless remain a defense-in-depth review item.

### 7.3 Applied-Migration Registry Immutability

The registry is documented as append-only and has no direct non-owner write
grant, but an enabled database trigger does not yet prevent owner-level
`UPDATE` or `DELETE`.

This remains unresolved Foundation hardening work.

## 8. Explicit Non-Claims

Phase 2 acceptance does not prove or provide:

- Provider-specific JWT, SAML, X.509, WebAuthn, or other assertion parsing
- Provider-specific cryptographic verification implemented in PostgreSQL
- A production Go authentication or session service
- Final verifier credentials, signing-key inventory, or secret management
- Final database ownership and login-role topology
- Least-privileged runtime grants to production application roles
- Organizational Access Eligibility evaluation
- Authority Grant evaluation
- Shift or supervisor-attestation enforcement
- Approval independence enforcement
- Deterministic Authorization Policy selection
- Authorization Lease issuance, renewal, or revocation completion
- Protected-operation authorization completion
- Decision Record integrity anchoring
- Complete append-only enforcement
- Runtime client-token issuance or cryptographic session-token validation
- Distributed cache or multi-node session invalidation behavior
- Provider or directory outages
- Off-host logging or integrity anchoring
- Backup protection and restore validation
- Break-glass access
- Trusted rebuild and compromise recovery
- Production readiness

## 9. Handoff

Later authorization phases may build on these accepted invariants:

- A verified establishment assertion can create at most one session.
- Establishment and assertion consumption are atomic.
- A verified step-up assertion can update at most one session once.
- Step-up evidence and assertion consumption are atomic.
- Session identity, device, Trust Provider, service, organization, audience,
  environment, and absolute lifetime remain bound.
- Activity and administrative unlock require a currently usable local context.
- Lock, unlock, expiration, revocation, and termination are controlled.
- Terminal session states cannot return to a usable state.
- Successful state changes and their events remain timestamp-aligned.
- Concurrent callers cannot create duplicate establishment or step-up effects.
- Incompatible terminal transitions cannot create mixed terminal state.
- Authentication and session state remain inputs to, not substitutes for,
  authorization.

The next phase should implement the authorization decision path without
weakening or bypassing these accepted session invariants.

## 10. Revalidation Triggers

Phase 2 acceptance must be rerun before it is relied upon after any change to:

- Migration `060`
- Migration `070`
- Migration `072`
- Session or session-event constraints
- Controlled assertion or session functions
- Trust Provider, identity, device, Platform Service, or organization columns
  used by local eligibility checks
- Establishment or step-up assertion bindings
- Session state, chronology, activity, expiration, or actor attribution
- Sequential Phase 1 or Phase 2 tests
- Any of the four concurrency tests or their release barriers
- The Foundation test runner
- Either Foundation test manifest
- PostgreSQL major-version requirements
- Runtime grants or ownership affecting controlled functions
- The normative Phase 2 contract
- This acceptance record
- The accepted release tag

A passing historical result does not replace a fresh run after a relevant
change.
