# Phase 1 Authentication Assertion Acceptance

> **Layer:** Platform Foundation  
> **Phase:** 1 — Authentication Assertion Verification and Consumption  
> **Acceptance date:** 2026-07-11  
> **Status:** Accepted for the Phase 1 scope defined below  
> **Authoritative contract:** [Authentication Assertion Verification and Consumption Model](authentication-assertion-verification-and-consumption-model.md)

## 1. Acceptance Decision

Phase 1 is accepted.

This decision means the implemented PostgreSQL Authentication Assertion
boundary and its normal Foundation test path satisfied the Phase 1 acceptance
gate on 2026-07-11.

It does not declare the Platform Foundation, session subsystem, authorization
system, Go runtime, or deployment environment production-ready.

## 2. Accepted Scope

The accepted Phase 1 scope includes:

- Authentication Assertion states:
  - `RECEIVED`
  - `VERIFIED`
  - `CONSUMED`
  - `REJECTED`
  - `EXPIRED`
  - `REVOKED`
- Controlled `RECEIVED → VERIFIED` transition
- Local Trust Provider status, validity, environment, and revocation checks
- Local identity status and validity checks
- Bound-device trust, validity, and revocation checks
- Bound-Platform-Service status and validity checks
- Exact local session checks for `SESSION_STEP_UP`
- Nonempty verifier attribution and verification-method requirements
- Controlled rejection
- Controlled expiration
- Controlled revocation with prior verification-history preservation
- Exact-context consumption
- Generic denial for missing, mismatched, invalid, expired, revoked, or
  previously consumed assertions
- Sequential replay denial
- Two-connection concurrent single-use enforcement
- Terminal-state enforcement
- Fixed trusted function `search_path` settings
- Removal of controlled-function execution from `PUBLIC`
- Sequential and concurrency integration in the normal Foundation test command

## 3. Implementation Evidence

Principal production migration:

```text
sql/schema/migrations/foundation/
└── 070_postgresql_authentication_assertion_gate.sql
```

Principal sequential tests:

```text
test-framework/sql/tests/foundation/
├── 090_authentication_assertion_behavior.sql
└── 100_authentication_assertion_phase1_behavior.sql
```

Concurrency test:

```text
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
Run ID: foundation_20260711_174057_147582
Completed: 2026-07-11T17:41:00-04:00
PostgreSQL server_version_num: 180004
Overall result: PASS
Runner exit status: 0
Sequential test files: 10
Concurrency test files: 1
Manifest migrations: 31
Registered migrations: 31
PASS: 135
FAIL: 0
WARN: 3
```

The successful disposable database was dropped by the runner after the result
inventory and summary were written.

## 5. Concurrent Single-Use Evidence

Two independent PostgreSQL worker connections were made eligible behind a
controlled release barrier and attempted to consume the same verified
Authentication Assertion.

Accepted result:

```text
ready=2
success=1
denied=1
unexpected=0
final_status=CONSUMED
consumed_at=1
```

The six recorded concurrency assertions proved:

1. Both workers reached the release barrier.
2. Exactly one worker succeeded.
3. Exactly one worker received the expected denial.
4. No unexpected worker or controller error occurred.
5. The final assertion state was `CONSUMED`.
6. Exactly one terminal consumption timestamp existed.

## 6. Acceptance-Gate Results

| Gate | Result |
|---|---|
| Architecture contract present | PASS |
| Migration `070` installs in an empty database | PASS |
| Full 31-migration Foundation manifest installs | PASS |
| Prior Phase 0 tests continue to pass | PASS |
| Local Trust Provider checks tested | PASS |
| Local identity checks tested | PASS |
| Bound-device checks tested | PASS |
| Bound-Platform-Service checks tested | PASS |
| Step-up-session checks tested | PASS |
| Rejection behavior tested | PASS |
| Expiration behavior tested | PASS |
| Revocation-history preservation tested | PASS |
| Exact-context consumption tested | PASS |
| Sequential replay denied | PASS |
| Concurrent double consumption denied | PASS |
| Terminal states cannot become usable | PASS |
| Controlled functions unavailable to `PUBLIC` | PASS |
| Controlled functions use trusted fixed search paths | PASS |
| Normal runner exits with status `0` | PASS |
| Summary contains zero failed assertions | PASS |
| No new warning category introduced by Phase 1 | PASS |

## 7. Known Warnings

The accepted run retained three previously understood warnings.

### 7.1 Missing Stored Migration Checksums

All 31 migration files had SHA-256 values calculated by the test runner, but
the migrations still register `NULL` checksum values.

This remains required before stable or production migration enforcement.

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

Phase 1 acceptance does not prove or provide:

- Provider-specific JWT, SAML, X.509, WebAuthn, or other assertion parsing
- Provider-specific cryptographic verification implemented in PostgreSQL
- A production Go verifier
- Final verifier credentials, signing-key inventory, or secret management
- Final database ownership and login-role topology
- Least-privileged runtime function grants
- Atomic session establishment
- Complete session activity, inactivity, lock, unlock, expiration,
  revocation, termination, or concurrency behavior
- Organizational Access Eligibility evaluation
- Authority Grant evaluation
- Approval independence enforcement
- Deterministic Authorization Policy selection
- Authorization Lease issuance or renewal
- Protected-operation authorization completion
- Decision Record integrity anchoring
- Complete append-only enforcement
- Off-host logging or integrity anchoring
- Backup protection and restore validation
- Break-glass access
- Trusted rebuild and compromise recovery
- Production readiness

## 9. Handoff

The next session-focused phase may build on these accepted invariants:

- Only a controlled, locally eligible assertion becomes `VERIFIED`.
- An assertion is bound to its exact represented context.
- A verified assertion can be consumed at most once.
- Concurrent consumers cannot both succeed.
- Terminal assertions cannot return to a usable state.
- Provider-specific verification and PostgreSQL local verification remain
  distinct responsibilities.
- Authentication remains an input to, not a substitute for, authorization.

The next phase should implement atomic session establishment and step-up
completion without weakening or bypassing the accepted assertion boundary.

## 10. Revalidation Triggers

Phase 1 acceptance must be rerun before it is relied upon after any change to:

- Migration `070`
- Authentication Assertion table constraints
- Controlled assertion functions
- Trust Provider, identity, device, Platform Service, or session columns used
  by local verification
- Sequential Authentication Assertion tests
- The concurrency test or its barrier
- The Foundation test runner
- Either Foundation test manifest
- PostgreSQL major-version requirements
- Runtime grants or ownership affecting controlled assertion functions

A passing historical result does not replace a fresh run after a relevant
change.
