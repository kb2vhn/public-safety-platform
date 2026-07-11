# Authentication Assertion Verification and Consumption Model

> **Layer:** Platform Foundation  
> **Status:** Normative Phase 1 implementation contract  
> **Applies to:** Authentication Assertion receipt, verification, rejection,
> expiration, revocation, exact-context consumption, and concurrency behavior  
> **Does not define:** A production Go verifier, complete session lifecycle,
> authorization policy evaluation, approval enforcement, or Authorization
> Lease issuance

## 1. Purpose

This document defines the Phase 1 contract for Authentication Assertions in
the Platform Foundation.

An Authentication Assertion is an externally issued claim that an identity
successfully completed an authentication process through a configured Trust
Provider.

An Authentication Assertion is:

- An authentication input
- Bound to a specific purpose and request context
- Valid only for a limited period
- Subject to local trust and lifecycle checks
- Consumable at most once
- Insufficient by itself to authorize a Protected Operation

The purpose of Phase 1 is to make the existing Authentication Assertion gate
complete enough that later session and authorization work can rely on a
well-defined, database-enforced boundary.

## 2. Phase 1 Objective

Phase 1 must establish and test the following properties:

1. A received assertion cannot be consumed before controlled verification.
2. Verification cannot succeed when required local Foundation state is
   invalid.
3. Failed verification can be recorded as an attributable rejection.
4. Expired assertions can be transitioned to an explicit terminal state.
5. Revocation preserves any valid prior verification history.
6. Consumption requires exact context equality.
7. A consumed assertion cannot be replayed.
8. Concurrent consumers cannot both succeed.
9. Terminal states cannot return to a usable state.
10. PostgreSQL time is authoritative for all state transitions.
11. Function execution remains unavailable to `PUBLIC`.
12. Authentication remains distinct from authorization.

## 3. Scope

Phase 1 includes:

- The Authentication Assertion state machine
- Controlled verification transition requirements
- Local Trust Provider checks
- Local identity checks
- Local device checks when a device is bound
- Local Platform Service checks when a service is bound
- Local session checks for `SESSION_STEP_UP`
- Controlled rejection
- Controlled expiration
- Existing revocation behavior
- Exact-context consumption
- Single-use enforcement
- Real multi-connection concurrency testing
- Catalog and privilege assertions for the controlled functions
- Documentation and test-framework updates

Phase 1 does not include:

- Production Go verifier design
- Parsing JWT, SAML, X.509, WebAuthn, or other provider formats in PostgreSQL
- Complete provider credential and signing-key inventory
- Session creation
- Session renewal, locking, revocation, termination, or inactivity handling
- Organizational Access Eligibility evaluation
- Authority Grant evaluation
- Independent approval evaluation
- Authorization Policy selection
- Authorization Lease issuance
- Protected-operation execution
- Final production ownership and login-role topology
- Off-host integrity anchoring
- Deployment secrets or key management

Those concerns belong to later phases.

## 4. Trust Boundary

Authentication Assertion verification is divided into two distinct
responsibilities.

### 4.1 External verification responsibility

A future controlled verifier will perform provider-specific work such as:

- Parsing the provider assertion
- Validating its syntax
- Validating its signature or message authentication code
- Validating issuer-specific mandatory claims
- Validating the provider's cryptographic credential
- Validating provider-specific nonce, challenge, or replay material
- Normalizing the result into the Foundation Authentication Assertion record
- Supplying an attributable verifier reference
- Supplying a stable verification-method identifier

PostgreSQL does not claim that it performed those cryptographic or
provider-specific checks unless a later architecture decision explicitly
implements them in PostgreSQL.

### 4.2 PostgreSQL responsibility

Before accepting the transition to `VERIFIED`, PostgreSQL must independently
prove the local conditions that it owns:

- The assertion exists.
- The assertion is currently `RECEIVED`.
- The assertion has been issued.
- The assertion has not expired.
- The Trust Provider exists.
- The Trust Provider is `ACTIVE`.
- The Trust Provider is within its local validity period.
- The Trust Provider environment matches the assertion environment.
- No effective Trust Provider revocation blocks the assertion.
- The identity exists.
- The identity is in a locally usable state.
- The identity is within its local validity period.
- A bound device, when present, is locally trusted and usable.
- No effective device revocation blocks a bound device.
- A bound Platform Service, when present, is locally active and valid.
- A `SESSION_STEP_UP` assertion references an existing locally usable session.
- The referenced step-up session belongs to the same identity.
- The referenced step-up session matches any bound device, Trust Provider,
  and Platform Service context.
- The verifier reference is nonempty.
- The verification-method identifier is nonempty.

PostgreSQL must fail closed when any required local condition is not
established.

## 5. Authentication Assertion Purposes

Phase 1 recognizes two purposes.

### 5.1 `SESSION_ESTABLISHMENT`

A `SESSION_ESTABLISHMENT` assertion:

- Must not reference an existing session
- May later be consumed by a controlled session-establishment workflow
- Does not itself create a session during Phase 1
- Does not itself grant access to a Protected Operation

### 5.2 `SESSION_STEP_UP`

A `SESSION_STEP_UP` assertion:

- Must reference an existing session
- Must be bound to the same identity as that session
- Must match the session's applicable device, Trust Provider, and Platform
  Service context
- May later be consumed by a controlled step-up workflow
- Does not independently modify the session during Phase 1

Atomic session establishment and complete step-up behavior are deferred to the
session-lifecycle phase.

## 6. State Model

The allowed Authentication Assertion states are:

```text
RECEIVED
VERIFIED
CONSUMED
REJECTED
EXPIRED
REVOKED
```

### 6.1 State meanings

`RECEIVED`

- The assertion has been recorded.
- Provider-specific verification has not yet been accepted.
- The assertion is not consumable.

`VERIFIED`

- Provider-specific verification has completed successfully.
- PostgreSQL has independently accepted all required local verification
  conditions.
- The assertion may be consumed once while still valid and context-matching.

`CONSUMED`

- The assertion was successfully used once.
- The assertion is terminal.
- The assertion cannot be replayed, revoked, rejected, expired, or verified
  again.

`REJECTED`

- Verification failed or the assertion was unacceptable before verification.
- A nonempty attributable rejection reason is recorded.
- The assertion is terminal.

`EXPIRED`

- The assertion was not consumed before its expiration.
- Prior complete verification metadata may be retained.
- The assertion is terminal.

`REVOKED`

- The assertion was invalidated before consumption.
- Prior complete verification metadata may be retained.
- A nonempty revocation reason is recorded.
- The assertion is terminal.

## 7. Allowed Transitions

The only allowed transitions are:

```text
RECEIVED → VERIFIED
RECEIVED → REJECTED
RECEIVED → EXPIRED
RECEIVED → REVOKED

VERIFIED → CONSUMED
VERIFIED → EXPIRED
VERIFIED → REVOKED
```

No other transition is valid.

In particular:

```text
CONSUMED → anything       prohibited
REJECTED → anything       prohibited
EXPIRED  → anything       prohibited
REVOKED  → anything       prohibited
VERIFIED → REJECTED       prohibited
RECEIVED → CONSUMED       prohibited
```

State transitions must be expressed as conditional updates whose predicates
include the expected prior state.

## 8. Authoritative Time

Every controlled transition must capture exactly one PostgreSQL
`statement_timestamp()` value and use that value consistently throughout the
transition.

The same value must be used for:

- Current-state validity checks
- Provider validity checks
- Identity validity checks
- Device validity checks
- Service validity checks
- Session validity checks
- Revocation-effectivity checks
- The state-transition timestamp

Application-host time is not authoritative.

`clock_timestamp()` may remain appropriate for passive receipt or recording
defaults, but it must not be mixed with a separately captured transition time
in a way that can violate chronology constraints.

## 9. Local Trust Provider Requirements

Controlled verification must require:

```text
trust.trust_providers.status = 'ACTIVE'
valid_from <= evaluated_at
valid_until IS NULL OR evaluated_at < valid_until
environment_key = authentication_assertions.environment_key
```

Verification must also fail when an effective, unexpired Trust Provider
revocation exists:

```text
object_type = 'TRUST_PROVIDER'
trust_provider_id = assertion.trust_provider_id
effective_at <= evaluated_at
expires_at IS NULL OR evaluated_at < expires_at
```

The absence of a current revocation record does not replace the requirement
for an `ACTIVE` Trust Provider state.

## 10. Local Identity Requirements

Controlled verification must require that the assertion's identity:

- Exists
- Is locally active
- Is within its validity interval
- Is not in a lifecycle state that prohibits authentication use

The exact accepted identity states must be explicit in SQL and tests.

A broad condition such as `status <> 'REVOKED'` is not sufficient.

Phase 1 must use an allowlist of accepted states.

## 11. Local Device Requirements

When `device_id` is present, controlled verification must require that the
device:

- Exists
- Is in the `TRUSTED` state
- Has a `trusted_from` value at or before the evaluated time
- Has no expired trust interval
- Has no effective, unexpired device revocation

When `device_id` is absent, the assertion may be verified only if the
Foundation contract permits that purpose and provider to operate without a
device binding.

Phase 1 does not add a provider-purpose policy table. Therefore, the current
nullable device design remains accepted, but tests must prove that a supplied
device cannot be ignored.

## 12. Local Platform Service Requirements

When `service_id` is present, controlled verification must require that the
Platform Service:

- Exists
- Is `ACTIVE`
- Is within its local validity interval

A supplied service binding is part of the exact assertion context and cannot
be substituted during consumption.

## 13. Local Step-Up Session Requirements

For `SESSION_STEP_UP`, controlled verification must require that the referenced
session:

- Exists
- Is `ACTIVE`
- Has been authenticated
- Has not expired
- Is not inactive according to an already represented and enforceable timeout
- Belongs to the assertion identity
- Matches the assertion device using null-safe equality
- Matches the assertion Trust Provider using null-safe equality
- Matches the assertion Platform Service using null-safe equality

Phase 1 must not silently treat a locked, expired, revoked, or terminated
session as usable.

## 14. Controlled Verification

The controlled verification function must:

1. Validate nonempty verifier attribution.
2. Validate a nonempty stable verification-method identifier.
3. Capture one authoritative evaluation time.
4. Lock or conditionally update only a `RECEIVED` assertion.
5. Evaluate all required local conditions.
6. Transition exactly one eligible row to `VERIFIED`.
7. Record:
   - `verified_at`
   - `verified_by_reference`
   - `verification_method`
8. Return `true` only when the transition occurred.
9. Return `false`, or raise a documented failure, when the assertion is not
   eligible.
10. Remain unavailable to `PUBLIC`.

The function must not accept caller-supplied timestamps.

A future deployment phase will determine the exact database role permitted to
execute this function.

## 15. Controlled Rejection

Phase 1 must add a controlled rejection function.

The function must:

- Accept an Authentication Assertion identifier
- Require a nonempty rejection reason
- Capture one authoritative evaluation time
- Transition only `RECEIVED → REJECTED`
- Record `rejected_at`
- Record the normalized rejection reason
- Preserve the original assertion record
- Return whether the transition occurred
- Remain unavailable to `PUBLIC`

A `VERIFIED` assertion cannot later be reclassified as `REJECTED`.

When a verified assertion must no longer be usable, it is revoked or expired.

## 16. Controlled Expiration

Phase 1 must add a controlled expiration function.

The function must:

- Accept an Authentication Assertion identifier
- Capture one authoritative evaluation time
- Require `evaluated_at >= expires_at`
- Transition only:
  - `RECEIVED → EXPIRED`
  - `VERIFIED → EXPIRED`
- Preserve complete prior verification metadata
- Record `expired_at`
- Return whether the transition occurred
- Remain unavailable to `PUBLIC`

The function must not expire a consumed or otherwise terminal assertion.

Phase 1 may also add a set-based expiration function for maintenance use, but
the single-record controlled behavior must remain testable independently.

## 17. Controlled Revocation

The current controlled revocation behavior remains part of Phase 1.

Revocation must:

- Require a nonempty reason
- Capture one authoritative evaluation time
- Transition only unconsumed `RECEIVED` or `VERIFIED` assertions
- Preserve complete prior verification metadata
- Record `revoked_at`
- Record the normalized revocation reason
- Remain unavailable to `PUBLIC`

Revocation must not alter a `CONSUMED`, `REJECTED`, `EXPIRED`, or already
`REVOKED` assertion.

## 18. Exact-Context Consumption

Consumption must match all represented assertion context exactly:

- External assertion identifier
- Assertion purpose
- Trust Provider
- Identity
- Device, using null-safe equality
- Session, using null-safe equality
- Platform Service, using null-safe equality
- Audience
- Environment

Consumption must also require:

- `status = 'VERIFIED'`
- `issued_at <= evaluated_at`
- `evaluated_at < expires_at`

The successful update must:

- Transition the assertion to `CONSUMED`
- Record `consumed_at`
- Return the internal Authentication Assertion identifier

When no eligible row is updated, the function must fail with a stable
authorization-related SQLSTATE and must not disclose whether the mismatch was
caused by:

- Missing assertion
- Wrong context
- Wrong state
- Expiration
- Revocation
- Prior consumption

This prevents the function from becoming an assertion-enumeration oracle.

## 19. Single-Use Concurrency Requirement

A sequential replay test is not enough.

Phase 1 must include a test that opens at least two independent PostgreSQL
connections and causes both to attempt consumption of the same verified
assertion.

The required result is:

```text
successful consumers: 1
denied consumers:     1
final assertion state: CONSUMED
consumed_at values:    exactly 1
```

The test must fail if:

- Both consumers succeed
- Neither consumer succeeds
- The assertion remains `VERIFIED`
- The assertion enters an unexpected state
- More than one success-side effect is recorded

The concurrency test must be part of the normal Foundation test command, not a
manual-only procedure.

## 20. Concurrency Test Harness

The current SQL test manifest runs files sequentially through one `psql`
connection at a time.

Phase 1 therefore requires a small Bash-based concurrency layer within the
existing self-contained SQL test framework.

The preferred structure is:

```text
sql/test-framework/sql/tests/
├── foundation-tests.manifest
├── foundation-concurrency-tests.manifest
├── foundation/
└── concurrency/
    └── 100_authentication_assertion_single_use.sh
```

The main runner must:

1. Complete its existing dependency preflight before modifying anything.
2. Apply all migrations.
3. Install the SQL test framework.
4. Run the sequential SQL tests.
5. Read the concurrency-test manifest.
6. Validate and deduplicate concurrency-test paths.
7. Execute each concurrency test against the same disposable database.
8. Include concurrency outcomes in `sql_test.results`.
9. Fail the overall run when a concurrency assertion fails.
10. Preserve the failed disposable database by default.

The concurrency test must use only dependencies already present on the
minimal Arch development host unless the runner's complete dependency
preflight is updated to report any additional requirements before database or
file creation.

## 21. Privilege Boundary

During Phase 1:

- `PUBLIC` must have no execution privilege on controlled Authentication
  Assertion functions.
- Direct `PUBLIC` table access must remain absent.
- Tests must verify those conditions.
- The functions must retain fixed, controlled `search_path` settings.
- The functions must not depend on `public`, `$user`, or `pg_temp`.

Phase 1 documents the logical executor boundaries but does not create the
final production login and ownership topology.

The deployment-security phase will establish:

- Non-login object owners
- Migration roles
- Runtime roles
- Authentication-verifier roles
- Session-control roles
- Audit and validation readers
- Exact function grants

## 22. Required SQL Changes

Phase 1 is expected to update the existing pre-stable migration:

```text
sql/schema/migrations/foundation/
070_postgresql_authentication_assertion_gate.sql
```

Expected changes include:

- Stronger local verification predicates
- Trust Provider validity and revocation checks
- Identity validity checks
- Bound-device trust and revocation checks
- Bound-service validity checks
- Step-up session validity and context checks
- Controlled rejection function
- Controlled expiration function
- Updated comments
- Explicit `PUBLIC` revocation for every controlled function

No new production Go code is part of this change.

Migration `060_sessions.sql` should be changed only when a missing structural
constraint is proven necessary for the Phase 1 assertion boundary.

## 23. Required Sequential Tests

The Phase 1 behavior tests must prove at least:

1. `RECEIVED` cannot be consumed.
2. Valid local context permits `RECEIVED → VERIFIED`.
3. Empty verifier attribution is rejected.
4. Empty verification method is rejected.
5. A pending Trust Provider blocks verification.
6. A suspended Trust Provider blocks verification.
7. An expired Trust Provider blocks verification.
8. A mismatched Trust Provider environment blocks verification.
9. An effective Trust Provider revocation blocks verification.
10. An inactive identity blocks verification.
11. An out-of-validity identity blocks verification.
12. A supplied untrusted device blocks verification.
13. An effective device revocation blocks verification.
14. An inactive bound Platform Service blocks verification.
15. A step-up assertion with a non-active session blocks verification.
16. A step-up assertion with identity mismatch blocks verification.
17. A step-up assertion with device mismatch blocks verification.
18. A step-up assertion with Trust Provider mismatch blocks verification.
19. A step-up assertion with Platform Service mismatch blocks verification.
20. A valid assertion verifies successfully.
21. Wrong audience is denied at consumption.
22. Wrong environment is denied at consumption.
23. Wrong identity is denied at consumption.
24. Wrong device is denied at consumption.
25. Wrong session is denied at consumption.
26. Wrong Platform Service is denied at consumption.
27. Exact context consumes successfully.
28. Sequential replay is denied.
29. Rejection records reason and chronology.
30. Rejected assertion cannot verify or consume.
31. Expiration before `expires_at` is denied.
32. Eligible received assertion can expire.
33. Eligible verified assertion can expire while retaining verification
    metadata.
34. Revocation retains prior verification metadata.
35. Terminal assertions cannot transition again.
36. Controlled functions remain unavailable to `PUBLIC`.

## 24. Required Concurrency Test

The required Phase 1 concurrency test is:

```text
Authentication Assertion single-use race
```

Setup:

1. Create valid Trust Provider, identity, optional device, Platform Service,
   and assertion fixtures.
2. Verify one assertion.
3. Hold both worker connections behind a shared test barrier.
4. Release both workers to call the consumption function.
5. Record each worker outcome.
6. Assert exactly one success and exactly one expected denial.
7. Assert the final row is `CONSUMED`.
8. Assert exactly one `consumed_at` value exists.
9. Assert no unexpected database error occurred.

The barrier must make both workers eligible before either consumption attempt
is allowed to complete.

## 25. Documentation Changes

Phase 1 must update:

- This document
- `docs/architecture/foundation/README.md`
- `docs/architecture/foundation/authorization-evaluation-contract.md` when
  necessary
- `docs/architecture/foundation/sql-migration-map.md`
- The root `README.md` implementation-status section
- The SQL test-framework README
- The test-framework installation document when runner behavior changes

Documentation must distinguish:

- Provider-specific cryptographic verification
- PostgreSQL local-state verification
- Authentication Assertion verification
- Authentication Assertion consumption
- Session establishment
- Authorization evaluation

These are separate operations.

## 26. Acceptance Gate

Phase 1 is complete only when all of the following are true:

- The architecture contract is committed.
- Migration `070` installs cleanly in an empty database.
- The full 31-migration Foundation manifest installs successfully.
- All prior tests continue to pass.
- New rejection and expiration tests pass.
- New local-state verification tests pass.
- Exact-context tests pass.
- Sequential replay denial passes.
- The two-connection concurrency test passes.
- Exactly one concurrent consumer succeeds.
- No controlled Authentication Assertion function is executable by `PUBLIC`.
- No unexpected warning is introduced.
- The test runner exits with status `0`.
- The summary contains zero failed assertions.
- Documentation accurately states what is and is not implemented.

A successful Phase 1 run must not be interpreted as proof of:

- Complete session security
- Complete authorization
- Production deployment security
- Production verifier correctness
- Production Go readiness

It proves only the Authentication Assertion boundary implemented and tested by
this phase.

## 27. Handoff to the Session Phase

After Phase 1 is accepted, the next session-focused phase may safely implement:

- Atomic session establishment from a consumed
  `SESSION_ESTABLISHMENT` assertion
- Atomic step-up completion from a consumed `SESSION_STEP_UP` assertion
- Session activity recording
- Inactivity enforcement
- Lock and unlock
- Revocation
- Termination
- Expiration
- Session concurrency tests

That phase must not weaken or bypass the exact-context and single-use
guarantees established here.

