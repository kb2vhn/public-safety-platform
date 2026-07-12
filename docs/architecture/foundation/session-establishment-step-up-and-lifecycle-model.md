# Session Establishment, Step-Up, and Lifecycle Model

> **Layer:** Platform Foundation
>
> **Phase:** 2 — Session Establishment, Step-Up, and Lifecycle Enforcement
>
> **Status:** Normative Phase 2 contract; Step 2 accepted; Step 3 implementation candidate; clean-install and regression validation required
>
> **Depends on:**
> [Authentication Assertion Verification and Consumption Model](authentication-assertion-verification-and-consumption-model.md)
> and the accepted Phase 1 boundary tagged
> `phase-1-authentication-assertion-complete-v1`
>
> **Applies to:** Session creation, step-up completion, activity checkpoints,
> lock, unlock, expiration, revocation, termination, event recording, and
> session concurrency behavior
>
> **Does not define:** Production bearer tokens, cookies, refresh tokens,
> production Go services, deterministic Authorization Policy selection,
> Authority Grant evaluation, Access Eligibility evaluation, approval
> enforcement, Authorization Lease issuance, or protected-operation execution

## 1. Purpose

A session represents bounded continuity of an authenticated identity context.

A session is not durable authority. It does not independently authorize a
Protected Operation, prove current organizational eligibility, satisfy an
approval requirement, issue an Authorization Lease, or replace current checks
of identity, device, Trust Provider, Platform Service, policy, revocation, and
authoritative time.

Phase 2 makes the session boundary dependable enough that later authorization
work can rely on database-enforced session creation and lifecycle behavior.

## 2. Phase 2 Objective

Phase 2 must establish and test the following properties:

1. A session can be created only by a controlled workflow.
2. Session creation atomically consumes one valid, exact-context,
   `VERIFIED` `SESSION_ESTABLISHMENT` Authentication Assertion.
3. The session identity, device, Trust Provider, and Platform Service bindings
   are copied from the consumed assertion and cannot be substituted by the
   caller.
4. A failed session insert or event insert rolls back assertion consumption.
5. One establishment assertion can create at most one session, including under
   concurrent attempts.
6. Step-up completion atomically consumes one valid, exact-context,
   `VERIFIED` `SESSION_STEP_UP` assertion.
7. Step-up cannot change the session identity, device, Trust Provider,
   Platform Service, organization, or correlation context.
8. Step-up records fresh authentication evidence without creating a generic
   authorization or permanent elevation flag.
9. Activity can be recorded only for an active and currently usable session.
10. Locked sessions cannot record activity or satisfy normal session-use
    checks.
11. Expired, revoked, and terminated sessions are terminal.
12. Lock, unlock, expiration, revocation, and termination are controlled,
    attributable transitions.
13. Every successful material session transition records a corresponding
    session event in the same transaction and with the same authoritative
    timestamp.
14. PostgreSQL statement time is authoritative.
15. Concurrent lifecycle operations cannot create impossible mixed states,
    duplicate terminal transitions, duplicate assertion use, or orphan events.
16. Controlled functions remain unavailable to `PUBLIC`.
17. Phase 2 does not weaken the accepted Phase 1 Authentication Assertion
    invariants.
18. Authentication remains distinct from authorization.

## 3. Accepted Phase 1 Dependency

Phase 2 relies on the following accepted Phase 1 invariants:

- Only a controlled, locally eligible assertion becomes `VERIFIED`.
- Assertions are purpose-bound and exact-context-bound.
- Only `VERIFIED` assertions are consumable.
- Assertion consumption is atomic and single-use.
- Concurrent consumers cannot both succeed.
- Rejected, expired, revoked, and consumed assertions are terminal.
- Assertion consumption uses a generic denial and does not expose the specific
  mismatch condition.
- PostgreSQL statement time is authoritative for assertion transitions.

Phase 2 must call the accepted assertion consumption API rather than re-create,
bypass, weaken, or partially duplicate its single-use transition.

Any Phase 2 change to migration `070`, the assertion table, or the controlled
assertion functions triggers full Phase 1 revalidation.

## 4. Scope

Phase 2 includes:

- Strengthened session-table state and chronology constraints,
- Explicit session expiration timestamp,
- Authentication Assertion linkage for establishment and step-up,
- Controlled atomic session establishment,
- Controlled atomic step-up completion,
- Controlled activity checkpoint recording,
- Controlled lock,
- Controlled administrative unlock,
- Controlled expiration,
- Controlled revocation,
- Controlled termination,
- Attributable append-oriented session events,
- Stable function behavior and trusted `search_path` settings,
- Positive, negative, terminal-state, chronology, and privilege tests,
- Real multi-connection session concurrency tests,
- Documentation and acceptance evidence.

## 5. Explicit Non-Scope

Phase 2 does not include:

- Production JWT, PASETO, opaque-token, cookie, or refresh-token issuance,
- Session-token signing or verification,
- Browser cookie policy,
- Mobile token storage,
- Machine-certificate issuance,
- MFA protocol implementation,
- Trust-Provider-specific parsing or cryptographic verification,
- Deterministic Authorization Policy selection,
- Access Eligibility evaluation,
- Organization participation evaluation,
- Authority Grant evaluation,
- Separation-of-duties evaluation,
- Approval evaluation,
- Authorization Lease issuance or renewal,
- Protected-operation authorization,
- Production Go code,
- Final runtime role grants,
- Final non-login ownership topology,
- Off-host integrity anchoring,
- Backup, restore, break-glass, or compromise-recovery controls.

Those concerns remain later phases.

## 6. Session Meaning

A session is a server-side record of authenticated continuity.

It binds:

- One identity,
- One optional selected organization context,
- One optional device,
- One Trust Provider when represented by the establishing assertion,
- One optional Platform Service,
- One authentication time,
- One absolute expiration,
- One optional inactivity timeout,
- One correlation identifier,
- One establishment Authentication Assertion,
- Optional later step-up Authentication Assertions,
- One current lifecycle state.

A session identifier is not, by itself, a bearer credential. Phase 2 does not
claim that possession of a session UUID proves control of the authenticated
client.

## 7. Session States

The Phase 2 states are:

```text
ACTIVE
LOCKED
EXPIRED
REVOKED
TERMINATED
```

### 7.1 `ACTIVE`

- The session may satisfy the session-continuity portion of a later
  authorization evaluation.
- It must still be within absolute and inactivity limits.
- It remains subject to current identity, device, Trust Provider, Platform
  Service, revocation, policy, and authorization checks.

### 7.2 `LOCKED`

- The session is temporarily unusable.
- It cannot record normal activity.
- It cannot complete a normal step-up workflow during Phase 2 because the
  accepted Phase 1 `SESSION_STEP_UP` verification contract requires an active
  session.
- Unlock is therefore an attributable administrative control path in Phase 2.
- A user may instead terminate the locked session and establish a new session
  through a new Authentication Assertion.

### 7.3 `EXPIRED`

- The absolute lifetime or inactivity lifetime elapsed.
- The state is terminal.
- The session cannot be unlocked, reactivated, stepped up, revoked,
  terminated, or used again.

### 7.4 `REVOKED`

- A security or trust action invalidated the session.
- The state is terminal.
- Revocation is distinct from a normal logout or shutdown.

### 7.5 `TERMINATED`

- The session ended through a normal controlled lifecycle action, such as
  logout or service-requested closure.
- The state is terminal.

## 8. Allowed State Transitions

The only allowed transitions are:

```text
new record → ACTIVE
ACTIVE     → LOCKED
ACTIVE     → EXPIRED
ACTIVE     → REVOKED
ACTIVE     → TERMINATED
LOCKED     → ACTIVE
LOCKED     → EXPIRED
LOCKED     → REVOKED
LOCKED     → TERMINATED
```

No transition is permitted from:

```text
EXPIRED
REVOKED
TERMINATED
```

A successful transition must update exactly one expected prior state.

## 9. Authoritative Time

Every controlled session operation must capture exactly one:

```sql
statement_timestamp()
```

That value is the operation's `evaluated_at` value.

The same value must be used for:

- Session validity,
- Absolute expiration,
- Inactivity expiration,
- Current local identity checks,
- Current local device checks,
- Current local Trust Provider checks,
- Current local Platform Service checks,
- Organization validity checks when an organization is selected,
- Assertion consumption within the operation,
- Session state timestamps,
- Session event timestamps.

Application-host time and caller-supplied transition timestamps are not
authoritative.

## 10. Effective-Time Semantics

Validity periods are half-open:

```text
valid_from <= evaluated_at
evaluated_at < valid_until
```

An omitted `valid_until` means no configured upper bound. It does not mean
that revocation, terminal state, or policy checks are unnecessary.

A session is within its absolute lifetime only when:

```text
authenticated_at <= evaluated_at
evaluated_at < expires_at
```

A session with inactivity enforcement is within its inactivity lifetime only
when:

```text
COALESCE(last_activity_at, authenticated_at) + inactivity_timeout
    > evaluated_at
```

Equality with the deadline is expired.

## 11. Session Row Invariants

The session table must enforce complete current-state consistency.

### 11.1 Required chronology

- `expires_at > authenticated_at`
- `last_activity_at IS NULL OR last_activity_at >= authenticated_at`
- `last_activity_at IS NULL OR last_activity_at < expires_at`
- `last_step_up_at IS NULL OR last_step_up_at >= authenticated_at`
- `last_step_up_at IS NULL OR last_step_up_at < expires_at`
- `locked_at IS NULL OR locked_at >= authenticated_at`
- `expired_at IS NULL OR expired_at >= authenticated_at`
- `revoked_at IS NULL OR revoked_at >= authenticated_at`
- `terminated_at IS NULL OR terminated_at >= authenticated_at`

### 11.2 Complete state shape

`ACTIVE` requires:

- `locked_at IS NULL`
- `expired_at IS NULL`
- `revoked_at IS NULL`
- `terminated_at IS NULL`

`LOCKED` requires:

- `locked_at IS NOT NULL`
- `expired_at IS NULL`
- `revoked_at IS NULL`
- `terminated_at IS NULL`

`EXPIRED` requires:

- `expired_at IS NOT NULL`
- `locked_at IS NULL`
- `revoked_at IS NULL`
- `terminated_at IS NULL`

`REVOKED` requires:

- `revoked_at IS NOT NULL`
- `locked_at IS NULL`
- `expired_at IS NULL`
- `terminated_at IS NULL`

`TERMINATED` requires:

- `terminated_at IS NOT NULL`
- `locked_at IS NULL`
- `expired_at IS NULL`
- `revoked_at IS NULL`

A row must not retain mutually contradictory current-state timestamps.
Historical lock and unlock information belongs in session events.

## 12. Session Lifetime Inputs

Phase 2 session establishment accepts policy-resolved duration inputs rather
than caller-supplied authentication or expiration timestamps.

The controlled establishment workflow must require:

```text
absolute_lifetime > interval '0 seconds'
```

When inactivity enforcement is requested:

```text
inactivity_timeout > interval '0 seconds'
inactivity_timeout <= absolute_lifetime
```

The database computes:

```text
authenticated_at = evaluated_at
expires_at       = evaluated_at + absolute_lifetime
last_activity_at = evaluated_at
```

Phase 2 does not claim to select the applicable Authorization Policy Version
or deployment policy. Until deterministic policy selection and final runtime
roles exist, these duration inputs are pre-production controlled inputs.

## 13. Establishment Assertion Linkage

Each session must retain the internal identifier of the Authentication
Assertion that established it.

Required properties:

- The establishment assertion identifier is non-null.
- One establishment assertion may be linked to at most one session.
- The linked assertion purpose is `SESSION_ESTABLISHMENT`.
- The assertion is `CONSUMED` by the same transaction that creates the
  session.
- The session identity, device, Trust Provider, and Platform Service bindings
  match the consumed assertion exactly.
- The created session event references the same assertion.

A foreign key proves record identity. The controlled function and tests prove
purpose, state, exact context, and atomicity.

## 14. Atomic Session Establishment

The controlled session-establishment workflow must:

1. Validate input formatting and positive duration values.
2. Capture one authoritative evaluation time.
3. Locate and lock the exact expected `VERIFIED`
   `SESSION_ESTABLISHMENT` assertion.
4. Revalidate current locally owned state required for session creation.
5. Validate a selected organization when one is supplied.
6. Atomically consume the assertion through the accepted Phase 1 consumption
   boundary.
7. Insert one `ACTIVE` session whose identity, device, Trust Provider, and
   Platform Service fields are derived from the consumed assertion.
8. Set authentication, expiration, activity, and correlation values.
9. Insert one `CREATED` session event with the same evaluation time.
10. Return the created `session_id` only after all required writes succeed.
11. Roll back assertion consumption if session creation or event creation
    fails.
12. Remain unavailable to `PUBLIC`.

The operation must not accept an independently supplied session identity,
device, Trust Provider, or Platform Service value and then trust that value
without exact comparison to the assertion.

## 15. Selected Organization Context

An Authentication Assertion does not currently bind an organization.

Phase 2 may accept an optional selected organization for the session, but it
must be treated only as selected context.

When supplied, the organization must:

- Exist,
- Be `ACTIVE`,
- Be within its local validity period.

A selected organization does not prove:

- Employment,
- Membership,
- Service participation,
- Access Eligibility,
- Authority,
- Governed Scope authority,
- Permission to perform a Protected Operation.

Those checks remain authorization responsibilities.

## 16. Current Local State at Establishment

A previously verified assertion must not silently bypass a security change
that occurs before session creation.

Immediately before completing establishment, the controlled workflow must
revalidate the locally owned state required for a new session:

- Identity exists, is `ACTIVE`, and is within validity.
- Trust Provider exists, is `ACTIVE`, matches the assertion environment, and
  is within validity.
- No effective Trust Provider revocation blocks the operation.
- A bound device exists, is `TRUSTED`, is within trust validity, and has no
  effective device revocation.
- A bound Platform Service exists, is `ACTIVE`, and is within validity.
- A selected organization, when supplied, is `ACTIVE` and within validity.

Failure after assertion locking must roll back without consuming the
assertion.

## 17. Step-Up Meaning

A step-up records recent additional authentication evidence for an existing
session.

Phase 2 step-up does not:

- Grant a role,
- Grant an Authority Grant,
- Approve an operation,
- Issue an Authorization Lease,
- Create a permanent elevated session class,
- Change the session identity or device,
- Change the selected organization,
- Extend the session's absolute expiration,
- Reset a revoked, expired, terminated, or locked session.

Phase 2 records:

- `last_step_up_at`,
- The latest step-up Authentication Assertion identifier,
- A `STEP_UP_COMPLETED` session event referencing that assertion.

Later policy may evaluate step-up freshness from `last_step_up_at` and the
supporting event history.

## 18. Atomic Step-Up Completion

The controlled step-up workflow must:

1. Capture one authoritative evaluation time.
2. Lock the target session.
3. Require the session to be `ACTIVE`.
4. Require the session to be within absolute and inactivity limits.
5. Revalidate current bound identity, device, Trust Provider, and Platform
   Service state.
6. Require one exact-context `VERIFIED` `SESSION_STEP_UP` assertion.
7. Require the assertion session identifier to equal the target session.
8. Require exact identity, device, Trust Provider, Platform Service, audience,
   and environment context.
9. Atomically consume the assertion through the accepted Phase 1 boundary.
10. Update `last_step_up_at` and the latest step-up assertion identifier.
11. Insert one `STEP_UP_COMPLETED` event with the same timestamp.
12. Leave identity, organization, device, Trust Provider, Platform Service,
    correlation identifier, authenticated time, and absolute expiration
    unchanged.
13. Roll back assertion consumption if the session update or event insert
    fails.
14. Remain unavailable to `PUBLIC`.

## 19. Activity Checkpoints

Phase 2 records bounded activity checkpoints, not one database event for every
application request.

The controlled activity workflow must:

- Capture one authoritative evaluation time,
- Lock or conditionally update one session,
- Require `status = 'ACTIVE'`,
- Require the session to remain within absolute and inactivity limits before
  the checkpoint,
- Require the new activity time to be monotonic,
- Revalidate current bound local trust state before extending activity,
- Set `last_activity_at = evaluated_at`,
- Insert one `ACTIVITY_RECORDED` event with the same timestamp,
- Return whether the checkpoint occurred,
- Remain unavailable to `PUBLIC`.

A locked or terminal session cannot have activity extended.

## 20. Lock

The controlled lock workflow must:

- Require a nonempty stable reason code,
- Accept attributable actor context when available,
- Capture one authoritative evaluation time,
- Transition only `ACTIVE → LOCKED`,
- Set `locked_at = evaluated_at`,
- Preserve authentication, activity, step-up, and correlation history,
- Insert one `LOCKED` event with the same timestamp and reason,
- Return whether the transition occurred,
- Remain unavailable to `PUBLIC`.

Locking does not pause absolute expiration.

## 21. Administrative Unlock

Because accepted Phase 1 step-up verification requires an active session,
Phase 2 does not claim a user-authentication unlock workflow for a locked
session.

The Phase 2 administrative unlock workflow must:

- Require a nonempty stable reason code,
- Require attributable administrative actor context before production grants
  are created,
- Capture one authoritative evaluation time,
- Transition only `LOCKED → ACTIVE`,
- Require the session not to have reached absolute expiration,
- Revalidate current identity, device, Trust Provider, Platform Service, and
  organization state,
- Clear `locked_at`,
- Set `last_activity_at = evaluated_at`,
- Preserve prior lock history in session events,
- Insert one `UNLOCKED` event with the same timestamp and reason,
- Return whether the transition occurred,
- Remain unavailable to `PUBLIC`.

Unlock does not extend absolute expiration and does not create step-up
evidence.

A locked session that no longer satisfies current trust or time requirements
must be expired, revoked, terminated, or replaced by a new session.

## 22. Expiration

The controlled expiration workflow must:

- Capture one authoritative evaluation time,
- Transition only an `ACTIVE` or `LOCKED` session,
- Require either absolute expiration or inactivity expiration,
- Transition to `EXPIRED`,
- Set `expired_at = evaluated_at`,
- Clear `locked_at` when expiring a locked session,
- Preserve authentication, activity, step-up, and assertion linkage history,
- Record whether the cause was `ABSOLUTE_TIMEOUT` or `INACTIVITY_TIMEOUT`,
- Insert one `EXPIRED` event with the same timestamp and cause,
- Return whether the transition occurred,
- Remain unavailable to `PUBLIC`.

A terminal session cannot be expired again.

## 23. Revocation

The controlled revocation workflow must:

- Require a nonempty stable reason code,
- Accept attributable actor context,
- Capture one authoritative evaluation time,
- Transition only `ACTIVE` or `LOCKED` to `REVOKED`,
- Set `revoked_at = evaluated_at`,
- Clear `locked_at` when revoking a locked session,
- Preserve authentication, activity, step-up, and assertion linkage history,
- Insert one `REVOKED` event with the same timestamp and reason,
- Return whether the transition occurred,
- Remain unavailable to `PUBLIC`.

A terminal session cannot be revoked again.

## 24. Termination

The controlled termination workflow must:

- Require a nonempty stable reason code,
- Accept attributable actor context when available,
- Capture one authoritative evaluation time,
- Transition only `ACTIVE` or `LOCKED` to `TERMINATED`,
- Set `terminated_at = evaluated_at`,
- Clear `locked_at` when terminating a locked session,
- Preserve authentication, activity, step-up, and assertion linkage history,
- Insert one `TERMINATED` event with the same timestamp and reason,
- Return whether the transition occurred,
- Remain unavailable to `PUBLIC`.

A terminal session cannot be terminated again.

## 25. Session Events

Session events are append-oriented history for material session changes.

Initial event types remain:

```text
CREATED
ACTIVITY_RECORDED
STEP_UP_COMPLETED
LOCKED
UNLOCKED
EXPIRED
REVOKED
TERMINATED
```

Required properties:

- Every event references one session.
- `CREATED` references the establishment Authentication Assertion.
- `STEP_UP_COMPLETED` references the consumed step-up assertion.
- State-changing events retain stable reason codes where applicable.
- Human actors use `acting_identity_id` when known.
- System or service attribution must not be silently represented as a human
  identity.
- Event timestamps are generated by PostgreSQL.
- The event and corresponding session mutation commit or roll back together.
- Direct runtime writes to `session_events` are not a substitute for controlled
  session functions.

Complete owner-level append-only trigger enforcement remains Foundation
hardening work unless Phase 2 explicitly adds and tests it.

## 26. Current Local Trust Revalidation

Session continuity does not freeze external trust state.

The controlled establishment, step-up, activity, and administrative unlock
workflows must revalidate the locally owned state they depend upon.

At minimum:

- Identity must remain locally usable.
- A bound device must remain trusted, valid, and not effectively revoked.
- The Trust Provider must remain active, valid, environment-matching, and not
  effectively revoked.
- A bound Platform Service must remain active and valid.
- A selected organization must remain active and valid when the operation
  depends on it.

A session row does not override a later identity disablement, device
revocation, Trust Provider suspension, service retirement, or organization
suspension.

Later protected-operation authorization must still perform its own required
current-state checks.

## 27. Generic Denial Boundary

Session establishment and step-up consume externally presented Authentication
Assertions and must not become enumeration or mismatch oracles.

When no eligible exact-context operation can complete, the external database
error must use a stable authorization-related SQLSTATE and a generic message.

The caller must not learn whether failure was caused by:

- Missing assertion,
- Wrong assertion purpose,
- Wrong identity,
- Wrong device,
- Wrong Trust Provider,
- Wrong Platform Service,
- Wrong session,
- Wrong audience,
- Wrong environment,
- Assertion state,
- Assertion expiration,
- Assertion prior consumption,
- Session state,
- Session expiration,
- Session inactivity,
- Current local trust failure.

Administrative lifecycle functions may return `false` for an ineligible
expected-state transition because the caller already operates on a known
session. Final production grants must restrict those functions to appropriate
control roles.

## 28. Input Validation

Invalid caller parameters are distinct from an unavailable session operation.

Examples of invalid parameters include:

- Empty reason code,
- Malformed reason code,
- Nonpositive absolute lifetime,
- Nonpositive inactivity timeout,
- Inactivity timeout longer than the absolute lifetime,
- Empty required actor reference,
- Malformed environment or audience values where the function accepts them.

Invalid parameters use a stable parameter-related SQLSTATE.

## 29. Privilege Boundary

During Phase 2:

- `PUBLIC` has no execution privilege on controlled session functions.
- `PUBLIC` has no direct table access to sessions or session events.
- Controlled functions use fixed trusted `search_path` settings beginning with
  `pg_catalog`.
- Controlled functions do not depend on `public`, `$user`, or `pg_temp`.
- Phase 2 tests verify those properties.

Phase 2 does not create the final production login and ownership topology.

The deployment-security phase will establish:

- Non-login object owners,
- Migration roles,
- Authentication-verifier roles,
- Session-establishment roles,
- Session-lifecycle roles,
- Runtime authorization roles,
- Audit and validation readers,
- Exact controlled-function grants.

## 30. Migration Strategy

Phase 2 should preserve migration responsibility and avoid weakening the
accepted Phase 1 file.

### 30.1 Strengthen migration `060`

Migration `060_sessions.sql` should own session and session-event structure,
including:

- Complete state constraints,
- `expired_at`,
- Step-up timestamp structure,
- Strong chronology constraints,
- Event attribution structure,
- Required indexes.

### 30.2 Add migration `072`

A new migration should be added after `070` and before `075`:

```text
072_postgresql_session_control.sql
```

Migration `072` should own assertion-dependent session controls, including:

- Establishment assertion linkage,
- Step-up assertion linkage,
- Foreign keys to Authentication Assertions,
- Atomic session establishment,
- Atomic step-up completion,
- Activity, lock, unlock, expiration, revocation, and termination functions,
- Function comments and `PUBLIC` revocations.

This ordering keeps session structure in `060`, keeps the accepted assertion
boundary in `070`, and places cross-boundary session workflows only after the
assertion table and consumption API exist.

Migration `070` should not be changed unless Phase 2 proves that the accepted
boundary cannot support a sound session workflow.

## 31. Proposed Controlled APIs

Exact signatures will be finalized during implementation, but Phase 2 expects
controlled operations equivalent to:

```text
establish_session_from_authentication_assertion(...)
complete_session_step_up(...)
record_session_activity(...)
lock_session(...)
unlock_session(...)
expire_session(...)
revoke_session(...)
terminate_session(...)
```

API names, parameters, and return types must remain explicit, stable,
domain-neutral, and testable.

No API accepts a caller-supplied state-transition timestamp.

## 32. Sequential Test Requirements

Phase 2 sequential tests must prove at least:

1. Direct creation cannot bypass the intended controlled path under the tested
   runtime privilege model.
2. A `RECEIVED` establishment assertion cannot create a session.
3. A wrong-purpose assertion cannot create a session.
4. An expired assertion cannot create a session.
5. A consumed assertion cannot create a second session.
6. Establishment rejects exact-context mismatch for every assertion-bound
   field.
7. Establishment revalidates current identity state.
8. Establishment revalidates current Trust Provider state.
9. Establishment revalidates Trust Provider revocation.
10. Establishment revalidates bound-device trust.
11. Establishment revalidates device revocation.
12. Establishment revalidates bound-Platform-Service state.
13. Establishment validates selected organization state when supplied.
14. Invalid lifetime inputs are rejected.
15. Valid establishment consumes the assertion and creates exactly one active
    session.
16. Session bindings equal the consumed assertion context.
17. The created session records the establishment assertion.
18. A `CREATED` event is written with matching timestamp and assertion.
19. Failure after assertion selection does not leave the assertion consumed.
20. Step-up requires an active, usable session.
21. Step-up rejects every exact-context mismatch.
22. Step-up cannot alter identity, organization, device, Trust Provider,
    Platform Service, correlation identifier, or absolute expiration.
23. Step-up records `last_step_up_at` and the assertion identifier.
24. Step-up writes one `STEP_UP_COMPLETED` event.
25. Step-up replay is denied.
26. Activity records only on an active, nonexpired, noninactive session.
27. Activity is denied for locked and terminal sessions.
28. Activity timestamps are monotonic.
29. Lock transitions only `ACTIVE → LOCKED`.
30. Locked sessions are unusable.
31. Unlock transitions only `LOCKED → ACTIVE`.
32. Unlock does not extend absolute expiration.
33. Unlock revalidates current local state.
34. Absolute expiration transitions to `EXPIRED`.
35. Inactivity expiration transitions to `EXPIRED`.
36. Expiration before either deadline is denied.
37. Revocation transitions active and locked sessions to `REVOKED`.
38. Termination transitions active and locked sessions to `TERMINATED`.
39. Terminal sessions cannot transition again.
40. Every successful lifecycle transition writes exactly one matching event.
41. Failed transitions write no event.
42. Session state constraints reject contradictory timestamps.
43. Controlled functions are unavailable to `PUBLIC`.
44. Controlled functions have fixed trusted search paths.
45. All prior Phase 0 and Phase 1 tests continue to pass.

## 33. Concurrency Test Requirements

Sequential tests are insufficient for single-use and lifecycle races.

Phase 2 must add real independent-connection tests to the normal Foundation
test command.

### 33.1 Session establishment race

Two workers attempt to establish a session from the same verified
`SESSION_ESTABLISHMENT` assertion.

Required result:

```text
ready workers:                    2
successful establishments:       1
expected denials:                 1
unexpected outcomes:             0
sessions linked to assertion:     1
CREATED events for assertion:     1
final assertion state:            CONSUMED
```

### 33.2 Step-up race

Two workers attempt to complete step-up with the same verified
`SESSION_STEP_UP` assertion.

Required result:

```text
ready workers:                    2
successful step-ups:              1
expected denials:                 1
unexpected outcomes:             0
STEP_UP_COMPLETED events:          1
final assertion state:            CONSUMED
```

### 33.3 Terminal transition race

Two workers attempt incompatible terminal transitions, such as revoke and
terminate, against the same active session.

Required result:

```text
successful terminal transitions: 1
unsuccessful transitions:         1
terminal events:                  1
final terminal state count:       1
contradictory timestamps:         0
```

The exact final terminal state may depend on lock acquisition order, but the
row must never contain both terminal states or both terminal events as
successful state changes.

## 34. Test Harness Requirements

The existing normal command remains:

```bash
./test-framework/sql/schema/scripts/test_foundation.sh
```

Phase 2 tests must integrate with the existing sequential and concurrency
manifests.

Any additional external command must be added to the runner's complete
all-at-once dependency preflight with:

- The missing command,
- The Arch package name,
- One combined `pacman` install command,
- Exit before files, directories, logs, temporary objects, or databases are
  created.

Phase 2 should prefer existing Bash and PostgreSQL capabilities and avoid new
dependencies unless required for a sound test.

## 35. Documentation Changes

Phase 2 must keep the following aligned:

- This contract,
- `README.md`,
- `docs/architecture/README.md`,
- `docs/architecture/foundation/README.md`,
- `authorization-evaluation-contract.md`,
- `authentication-assertion-verification-and-consumption-model.md` when the
  handoff changes,
- `sql-migration-map.md`,
- Test-framework operation documentation,
- The final Phase 2 acceptance record.

Documentation must distinguish:

- Authentication Assertion verification,
- Authentication Assertion consumption,
- Session establishment,
- Step-up completion,
- Session continuity,
- Current trust state,
- Authorization evaluation,
- Protected-operation execution.

## 36. Phase 2 Implementation Sequence

Phase 2 is divided into six controlled steps.

```text
[1] Contract and repository alignment
        ↓
[2] Session schema and atomic establishment/step-up workflows
        ↓
[3] Controlled activity and lifecycle APIs
        ↓
[4] Expanded sequential behavior tests
        ↓
[5] Multi-connection concurrency proofs
        ↓
[6] Documentation, clean run, and Phase 2 acceptance
```

### Step 1 — Contract and repository alignment

- Commit this normative model.
- Correct documentation-path drift.
- Record the accepted Phase 1 dependency.
- Define migration and test strategy.

### Step 2 — Schema and atomic assertion workflows

Accepted on 2026-07-12 under the [Phase 2 Step 2 Session Establishment and Step-Up Acceptance](phase-2-step-2-session-establishment-and-step-up-acceptance.md).

- Strengthen `060_sessions.sql`.
- Add `072_postgresql_session_control.sql`.
- Implement atomic establishment.
- Implement atomic step-up completion.

### Step 3 — Controlled lifecycle APIs

Implementation candidate in migration `072`; clean-install and regression validation are required before Step 4 begins.

- Activity,
- Lock,
- Administrative unlock,
- Expiration,
- Revocation,
- Termination,
- Event consistency.

### Step 4 — Sequential tests

- Positive behavior,
- Negative behavior,
- Chronology,
- Terminality,
- Privileges,
- Search paths,
- Phase 1 regression.

### Step 5 — Concurrency tests

- Establishment single-use race,
- Step-up single-use race,
- Incompatible terminal-transition race.

### Step 6 — Acceptance

- Clean manifest installation,
- Structural validation,
- Complete normal test run,
- Zero failed assertions,
- Documentation alignment,
- Formal acceptance record and tag.

## 37. Acceptance Gate

Phase 2 is complete only when all of the following are true:

- This contract is committed.
- The accepted Phase 1 tag remains identifiable.
- Migration `060` installs cleanly with strengthened state constraints.
- Migration `072` is in the authoritative manifest after `070` and before
  `075`.
- The full Foundation manifest installs into an empty PostgreSQL 18 database.
- All prior Phase 0 and Phase 1 assertions pass.
- Atomic session establishment passes positive and negative tests.
- Atomic step-up completion passes positive and negative tests.
- Activity and lifecycle functions pass state, time, chronology, and event
  tests.
- Establishment concurrency permits exactly one session.
- Step-up concurrency permits exactly one completion.
- Terminal-transition concurrency cannot produce contradictory state.
- Controlled functions are unavailable to `PUBLIC`.
- Controlled functions use fixed trusted search paths.
- No unexpected warning category is introduced.
- The test runner exits with status `0`.
- The summary contains zero failed assertions.
- Documentation accurately states what Phase 2 does and does not prove.

## 38. Phase 2 Non-Claims

A passing Phase 2 result will not prove:

- Production session-token security,
- Production Go correctness,
- Complete authorization,
- Access Eligibility,
- Organization participation,
- Authority Grant applicability,
- Approval independence,
- Authorization Policy selection,
- Authorization Lease issuance,
- Protected-operation security,
- Production ownership and runtime grants,
- Host compromise containment,
- Off-host logging,
- Protected backup and restore,
- Break-glass access,
- Trusted rebuild or compromise recovery,
- Production readiness.

It will prove only the database session boundary implemented and tested by
Phase 2.

## 39. Revalidation Triggers

Phase 2 acceptance must be rerun after any change to:

- Migration `060`,
- Migration `070`,
- Migration `072`,
- Session-table constraints,
- Session-event constraints,
- Authentication Assertion linkage,
- Controlled session functions,
- Bound identity, device, Trust Provider, Platform Service, or organization
  columns used by session controls,
- Phase 2 sequential tests,
- Phase 2 concurrency tests or barriers,
- The Foundation test runner,
- Either test manifest,
- The Foundation migration manifest,
- PostgreSQL major-version requirements,
- Runtime grants or ownership affecting controlled session operations.

A historical passing result never replaces a fresh run after a relevant
change.
