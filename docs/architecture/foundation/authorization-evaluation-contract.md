# Authorization Evaluation Contract

> **Document status:** Normative Platform Foundation architecture.
>
> **Program:** Central Authorization Completion Program.
>
> **Accepted implementation boundary:** Phase 3 — Authorization Decision
> and Controlled Lease Issuance.
>
> **Implementation status:** This document defines the wider authorization
> contract that migrations `050–081` and their behavioral tests must implement.
> The Phase 1 Authentication Assertion and Phase 2 session-control boundaries
> are implemented, accepted, and tagged. Phase 3 decision finalization and
> controlled lease issuance are also implemented, accepted, and tagged. The
> wider
> authorization contract remains incomplete. Structural presence does not
> imply complete enforcement.

## Primary Rule

Authentication establishes an identity context.

Authorization determines whether a specific Protected Operation may occur
within an exact organization, service, purpose, operation, Protected Resource
Target, Governed Scope, Data Classification, device, session, policy, and
time context.

## Governing Principles

1. Every important decision must have an explanation.
2. An Authentication Assertion is an authentication input, not authorization.
3. A session represents identity continuity, not durable authority.
4. An approval is an attributable policy input, not a standalone capability.
5. An Authorization Lease is short-lived, revocable, and context-bound.
6. Possession of a lease secret is insufficient when operation context does
   not match.
7. PostgreSQL independently verifies the minimum database-boundary conditions
   required for a Protected Operation.
8. Required stages fail closed on `FAIL` or `NOT_EVALUATED`.
9. `NOT_REQUIRED` is valid only when the applicable policy explicitly makes a
   stage unnecessary.
10. Client clocks are never authoritative for authorization validity.
11. A policy denial is an expected decision result, not automatically a
    database error.
12. An unexpected integrity, serialization, or infrastructure failure is a
    system error and is not silently converted into a policy denial.
13. Material authorization history is append-oriented.
14. Authorization-critical fields use explicit typed columns and parameters.
15. Supplemental JSON must not replace required typed context.
16. No runtime identity receives direct unrestricted access to protected
    tables.
17. No single credential, device, session, role, approval, network location,
    or lease secret grants unrestricted platform authority.

## Decision Classes

Initial decision classes are:

```text
SESSION_ESTABLISHMENT
SESSION_STEP_UP
LEASE_ISSUANCE
LEASE_RENEWAL
PROTECTED_OPERATION
SECURITY_REVOCATION
```

### Session Establishment

A verified Authentication Assertion may establish a new session.

The assertion has no existing session binding and is consumed atomically when
the session is created.

### Session Step-Up

A verified Authentication Assertion may strengthen an existing session.

It must match the existing session, identity, device when required, Trust
Provider, audience, and environment exactly.

A step-up cannot change the identity or device bound to a session.

### Lease Issuance

A successful authorization evaluation may issue a short-lived Authorization
Lease.

### Lease Renewal

Renewal creates a new lease and new Decision Record.

The original lease is not extended in place.

### Protected Operation

A controlled operation validates the exact session, lease, secret, identity,
organization, service, purpose, operation, target, Governed Scope,
classification, policy version, revocation state, usage state, and
authoritative time.

### Security Revocation

A security action may revoke an Authentication Assertion, session, lease,
identity, device, or Trust Provider relationship.

It remains attributable and policy-governed.

## Canonical Request Context

Every material authorization request carries explicit context:

```text
request_id
correlation_id
decision_class
requester_identity_id
requester_organization_id
session_id
device_id
authentication_assertion_id
service_id
purpose_definition_id
operation_definition_id
operation_key
protected_target_type
protected_target_reference
governed_scope_id
classification_key
authorization_policy_version_id
approval_request_id
authorization_lease_id
requested_at
evaluated_at
```

A field may be null only when the decision class and applicable policy
explicitly permit it.

## Request Context Meanings

### Request Identifier

`request_id` uniquely identifies one authorization request.

The same identifier with different immutable context is rejected as
`REQUEST_IDENTIFIER_CONFLICT`.

### Correlation Identifier

`correlation_id` connects the request, Authentication Assertion, session,
approval actions, Authorization Lease, Protected Operation, Decision Record,
telemetry, and Delivery Destination records.

It is not an authorization secret.

### Governed Operation

`operation_definition_id` is the authoritative relational identity of the
Governed Operation.

`operation_key` is the stable machine-readable key and may be retained in an
immutable record as a historical snapshot.

When both are stored, the database must enforce that the key belongs to the
referenced definition. An approval request, Authorization Policy Version,
Authority Grant, Authorization Lease, and Decision Record participating in
one authorization chain must resolve to the same Governed Operation
definition.

Operation keys use:

```text
^[a-z][a-z0-9_.-]*$
```

### Protected Resource Target

The target is represented by:

```text
protected_target_type
protected_target_reference
```

The type identifies the target class.

The reference identifies the exact record or bounded set understood by the
controlled operation.

The target is never interpreted as caller-supplied SQL.

### Definition Identifiers and Snapshot Keys

Definition identifiers are authoritative for relational consistency.

Stable keys may be stored beside identifiers in immutable or append-oriented
records to preserve historical readability. A composite foreign key or an
equivalent controlled-write invariant must prove that each stored key matches
its referenced definition.

A free-form key must not substitute for a definition identifier after the
definition catalog exists.

### Governed Scope

`governed_scope_id` references the applicable typed boundary.

A null value means the applicable policy explicitly does not require a
Governed Scope. It does not mean universal authority.

### Data Classification

`classification_key` identifies the governed handling category when the
classification catalog is not yet available as an earlier migration
dependency.

A later migration may replace the key with a versioned classification
identifier.

## Authentication Assertion Contract

### Purposes

Initial assertion purposes are:

```text
SESSION_ESTABLISHMENT
SESSION_STEP_UP
```

### Lifecycle

```text
RECEIVED
    ↓
VERIFIED
    ↓
CONSUMED
```

Terminal alternatives:

```text
REJECTED
EXPIRED
REVOKED
```

Meanings:

- `RECEIVED` — stored but not trusted for authorization.
- `VERIFIED` — a controlled external verifier supplied attributable
  provider-verification metadata, and PostgreSQL accepted all required local
  Trust Provider, identity, optional device, optional Platform Service, and
  applicable step-up-session conditions. This state does not claim that
  PostgreSQL performed provider-specific cryptographic verification.
- `CONSUMED` — used exactly once for its intended context.
- `REJECTED` — validation failed.
- `EXPIRED` — no longer valid due to authoritative time.
- `REVOKED` — explicitly invalidated before use.

Only `VERIFIED` assertions are consumable.

### Verification Boundary

Trust-Provider-specific signature and claim verification may occur outside
PostgreSQL.

PostgreSQL must not treat an arbitrary runtime insert as verified.

The transition to `VERIFIED` is a controlled verifier action.
PostgreSQL independently enforces the local conditions it owns before
accepting that transition.

The complete accepted boundary is defined in
[Authentication Assertion Verification and Consumption Model](authentication-assertion-verification-and-consumption-model.md)
and evidenced by
[Phase 1 Authentication Assertion Acceptance](phase-1-authentication-assertion-acceptance.md).

### Context Match

Consumption requires exact matching of every applicable field:

- Assertion identifier
- Assertion purpose
- Identity
- Device
- Session
- Trust Provider
- Service
- Audience
- Environment
- Status
- Authoritative time

A mismatch produces a generic external denial and a specific internal reason
code.

## Session Contract

A session binds:

- Identity
- Organization
- Device when device-bound
- Trust Provider
- Platform Service
- Authentication time
- Absolute expiration
- Activity state
- Revocation state
- Correlation identifier

Initial statuses are:

```text
ACTIVE
LOCKED
EXPIRED
REVOKED
TERMINATED
```

A session does not independently grant a Protected Operation.

The accepted Phase 2 session boundary is defined by
[Session Establishment, Step-Up, and Lifecycle Model](session-establishment-step-up-and-lifecycle-model.md)
and evidenced by
[Phase 2 Session Establishment, Step-Up, and Lifecycle Acceptance](phase-2-session-establishment-step-up-and-lifecycle-acceptance.md).
Phase 3 consumes that boundary without treating session continuity as durable
authority.

## Policy Contract

An Authorization Policy Version defines:

- Decision class
- Effective period
- Applicable service
- Applicable purpose
- Applicable operation
- Governed Scope requirement
- Protected Resource Target requirement
- Authentication Assertion requirement
- Maximum assertion age
- Device requirement
- Session requirement
- Access Eligibility requirement
- Authority requirements
- Separation-of-duties requirements
- Approval policy
- Risk and security stages
- Lease use mode
- Lease lifetime
- Lease usage limit
- Decision-stage requirements
- Governing document version

Policy selection must be deterministic.

No applicable policy denies the request.

Ambiguous policy selection denies the request.

## Decision Stages

Each stage returns:

```text
PASS
FAIL
NOT_REQUIRED
NOT_EVALUATED
```

Initial stage keys are:

```text
REQUEST_CONTEXT
AUTHENTICATION_ASSERTION
IDENTITY_STATE
DEVICE_TRUST
ORGANIZATION_PARTICIPATION
ACCESS_ELIGIBILITY
SESSION_STATE
PURPOSE_AND_OPERATION
GOVERNED_SCOPE
DATA_CLASSIFICATION
AUTHORITY
SEPARATION_OF_DUTIES
APPROVAL
AUTHORIZATION_LEASE
RISK_AND_SECURITY
DATABASE_BOUNDARY
```

A required stage returning `FAIL` or `NOT_EVALUATED` denies the request.

## Approval Contract

An Approval Request binds:

- Requester identity
- Requester organization
- Requester session
- Platform Service
- Governed Purpose
- Governed Operation
- Protected Resource Target
- Governed Scope
- Data Classification
- Approval policy version
- Expiration
- Correlation identifier

Self-approval is prohibited unless the exact active policy version explicitly
allows it.

Multiple actions by the same effective actor do not satisfy multiple
independent-approval requirements.

Approval history is append-oriented.

## Authority Contract

An Authority Grant is applicable only when its explicit context matches:

- Identity
- Organization
- Platform Service
- Governed Purpose
- Governed Operation
- Protected Resource Target
- Governed Scope
- Effective time

Role or grant accumulation must not bypass separation of duties.

Delegated authority must be explicit, attributable, time-bounded, revocable,
and no broader than the delegator’s current authority.

## Authorization Lease Contract

A lease binds:

- Request identifier
- Identity
- Requester organization
- Session
- Device when required
- Platform Service
- Governed Purpose
- Governed Operation
- Protected Resource Target
- Governed Scope
- Data Classification
- Authorization Policy Version
- Issuing Decision Record
- Approval Request when required
- Issue time
- Expiration time
- Use mode
- Usage limit
- Revocation state
- Correlation identifier

Initial use modes are:

```text
REUSABLE
SINGLE_USE
LIMITED_USE
```

A plaintext lease secret is never stored.

A secret match by itself is not a complete authorization result.

## Time Contract

One authorization evaluation captures:

```sql
v_evaluated_at := statement_timestamp();
```

Every validity comparison in that evaluation uses the same captured time.

Effective periods are half-open:

```text
valid_from <= evaluated_at
evaluated_at < valid_until
```

`clock_timestamp()` is used only when moving wall-clock observation is
intentional.

## Final Results

```text
ALLOW
DENY
PENDING
ESCALATED
```

A system error is not a final authorization result.

## Denial Persistence

A normal policy denial should:

1. Record stage results.
2. Finalize a `DENY` Decision Record.
3. Avoid the protected mutation.
4. Return a typed denial result.
5. Allow the caller to commit the denial record.

A function must not write a denial record and then raise an exception that
rolls back that same record.

Unexpected integrity or infrastructure failures raise an error and roll back.

## Stable Reason Codes

Reason codes use:

```text
^[A-Z][A-Z0-9_]*$
```

Initial Authentication Assertion codes:

```text
AUTHENTICATION_ASSERTION_REQUIRED
AUTHENTICATION_ASSERTION_NOT_FOUND
AUTHENTICATION_ASSERTION_NOT_VERIFIED
AUTHENTICATION_ASSERTION_NOT_YET_VALID
AUTHENTICATION_ASSERTION_EXPIRED
AUTHENTICATION_ASSERTION_REVOKED
AUTHENTICATION_ASSERTION_CONSUMED
AUTHENTICATION_ASSERTION_CONTEXT_MISMATCH
AUTHENTICATION_ASSERTION_FRESHNESS_EXCEEDED
```

Initial Governed Scope and target codes:

```text
GOVERNED_SCOPE_REQUIRED
GOVERNED_SCOPE_MISMATCH
PROTECTED_TARGET_REQUIRED
PROTECTED_TARGET_MISMATCH
```

Initial lease codes:

```text
LEASE_REQUIRED
LEASE_NOT_FOUND
LEASE_SECRET_INVALID
LEASE_NOT_ACTIVE
LEASE_NOT_YET_VALID
LEASE_EXPIRED
LEASE_REVOKED
LEASE_CONSUMED
LEASE_USAGE_LIMIT_REACHED
LEASE_CONTEXT_MISMATCH
LEASE_IDENTITY_MISMATCH
LEASE_ORGANIZATION_MISMATCH
LEASE_SESSION_MISMATCH
LEASE_DEVICE_MISMATCH
LEASE_SERVICE_MISMATCH
LEASE_PURPOSE_MISMATCH
LEASE_OPERATION_MISMATCH
LEASE_TARGET_MISMATCH
LEASE_GOVERNED_SCOPE_MISMATCH
LEASE_CLASSIFICATION_MISMATCH
```

## Decision Record Contract

Every material Decision Record stores explicit request context, policy
version, stage results, reason codes, final result, and supporting-record
references.

A Decision Record cannot finalize as `ALLOW` when a required stage is
`FAIL` or `NOT_EVALUATED`.

Finalized records are not edited in place.

Corrections, annotations, revocations, and supersession create linked records.

Decision Records never contain plaintext lease secrets, session tokens,
private keys, passwords, MFA secrets, or credentials used to access external
systems.

## Concurrency Contract

- Exactly one transaction may consume a verified Authentication Assertion.
  This invariant is implemented and has an accepted two-connection proof.
- Exactly one concurrent operation may consume a `SINGLE_USE` lease.
- A `LIMITED_USE` lease cannot exceed its usage limit.
- Duplicate effective approval by one actor does not count twice.
- A Decision Record finalizes once.
- Serialization and deadlock failures are system retry conditions, not policy
  denials.

## Phase 3 Controlled Decision and Lease-Issuance Boundary

The normative Phase 3 implementation contract is:

- [Authorization Decision and Lease Issuance Model](authorization-decision-and-lease-issuance-model.md)

Phase 3 adds a planned migration:

```text
081_postgresql_authorization_decision_and_lease_issuance.sql
```

It is placed after `080_decision_record_repository.sql` and before
`082_data_classification_and_governance.sql`.

The planned boundary requires:

- Unique deterministic policy selection,
- Persistent closure of every required decision stage,
- Finalization-once Decision Records,
- Controlled lease issuance only from a finalized eligible `ALLOW`,
- At most one lease per issuing Decision Record,
- Exact request, session, authority, approval, policy, target, scope,
  classification, and audience bindings,
- Policy-bounded lifetime and usage,
- Independent-connection concurrency proofs,
- Preservation of every accepted Phase 1 and Phase 2 invariant.

Phase 3 Step 1 froze the contract. Phase 3 Step 2 adds migration `081` and
the structural regression test
`130_authorization_decision_and_lease_structure.sql`.

Step 2 establishes typed policy applicability, exact policy-stage mapping,
lease-request fields, one issuing-decision/one issued-lease cardinality, core
decision-to-lease context binding, lease chronology and terminal-state shape,
and attributable authority and use evidence. Controlled finalization,
issuance, verification, and consumption remain later Phase 3 steps.

## Phase 3 Step 3 Controlled Decision Finalization

Step 3 implements these controlled routines in migration `081`:

```text
decision.resolve_authorization_policy(uuid)
decision.bind_authorization_policy(uuid)
decision.finalize_authorization_decision(uuid)
decision.finalize_decision(uuid, text, text)
```

The authoritative finalizer accepts only a Decision Record identifier and
computes the result from persisted policy and evaluation evidence. The
three-argument compatibility wrapper rejects caller-supplied values that do
not exactly match the computed result.

Missing, ambiguous, and expected-policy mismatch are persisted as terminal
denials. Every policy stage must have one evaluation, required `FAIL` and
`NOT_EVALUATED` deny, `NOT_REQUIRED` must match the selected policy rule, and
configured supporting evidence must exist before `ALLOW`.

## Phase 3 Step 4 Controlled Lease Boundary

Step 4 implements the database-controlled lease path defined by this contract.
A lease may be issued only from one finalized `ALLOW` Decision Record and is
bound to the exact identity, organization, session, device, service, purpose,
operation, target, scope, classification, policy, audience, and authoritative
time represented by that decision.

The controlled functions are:

```text
access_control.issue_authorization_lease_from_decision(uuid, text)
access_control.authorization_lease_context_is_usable(...)
access_control.consume_authorization_lease(...)
access_control.expire_authorization_lease(uuid)
access_control.revoke_lease(uuid, text)
```

Plaintext lease secrets are never stored. Issuance and use revalidate the
selected policy, required supporting evidence, linked authority, current
session, and locally owned trust state. One lease has one issuing or renewing
Decision Record, while a reusable lease may support multiple separately
attributable protected-operation Decision Records. Consumption requires the
exact lease, protected-operation decision, request identifier, correlation
identifier, context, audience, and remaining use allowance. Single-use and
limited-use consumption is atomic and writes an attributable use event in the
same transaction. Concurrency proof remains a later Phase 3 gate.
## Phase 3 Step 5 Fail-Closed Lease Behavior

Step 5 expands the controlled lease boundary with sequential negative-path
proof. Lease issuance and use must fail closed when the current session,
identity, device, Trust Provider, Platform Service, selected policy, required
supporting evidence, or linked authority is no longer valid.

When an `AUTHORITY` stage is required, usability requires at least one current
authority linkage that remains bound to the issuing Decision Record, its PASS
evaluation, a required `AUTHORITY_GRANT` supporting record, the same identity,
and the exact service, purpose, operation, organization, scope, and target.
Deleting the linkage or retargeting the grant invalidates the lease.

Protected-operation consumption rejects request, correlation, record-state,
result, and target mismatches. A denied attempt must not increment
`successful_use_count` and must not append an Authorization Lease Use Event.

The Step 5 regression target is 33 migrations, 16 sequential tests, 4 accepted
concurrency tests, 353 PASS, 0 FAIL, and 3 understood WARN results.


## Phase 3 Step 6 Independent-Connection Concurrency Proof

Step 6 does not add a new production routine. It proves the accepted controlled
functions under competing PostgreSQL connections. Advisory-lock release
barriers ensure both workers commit readiness before they attempt the same
Decision Record or Authorization Lease boundary.

The proof set covers finalization-once, single-winner issuance, single-use
consumption, the final slot of a limited-use lease, and mutually exclusive
expiration-versus-revocation terminal transition. Each successful use retains
a separately attributable protected-operation Decision Record and one
same-transaction use event.

The accepted Step 6 result is 33 migrations, 16 sequential tests,
9 concurrency tests, 408 PASS, 0 FAIL, and 3 understood WARN results.
Formal acceptance is recorded in [phase-3-authorization-decision-and-controlled-lease-acceptance.md](phase-3-authorization-decision-and-controlled-lease-acceptance.md)
and tagged as `phase-3-authorization-control-complete-v1`.
