# Authorization Evaluation Contract

> **Document status:** Normative Platform Foundation architecture.
>
> **Phase:** Central Authorization Completion Program — Phase 0.
>
> **Implementation status:** This document defines the contract that migrations `050–080` and their behavioral tests must implement. Structural presence does not imply complete enforcement.
>
> **Primary rule:** Authentication establishes an identity context. Authorization determines whether a specific protected operation may occur within a specific organization, service, purpose, operation, resource, jurisdiction, classification, device, session, policy, and time context.

## Purpose

Define one coherent authorization contract before implementing additional trust, session, approval, Authorization Lease, controlled-operation, and Decision Record behavior.

This contract prevents each later migration or service from inventing its own:

- Request context
- Time semantics
- Status meanings
- Reason codes
- Trust Assertion behavior
- Session relationship
- Approval interpretation
- Lease-use rules
- Denial behavior
- Decision-stage ordering
- Concurrency behavior

The contract is domain-neutral. It does not define CAD, RMS, Evidence and Property, Fleet, Personnel, Fire, EMS, or other operational-module records.

## Governing Principles

1. Every important decision must have an explanation.
2. A Trust Assertion is evidence, not authorization.
3. A session is identity continuity, not durable authority.
4. An approval is an attributable policy input, not a standalone capability.
5. An Authorization Lease is short-lived, scoped authority, not a role.
6. Possession of a lease secret is insufficient when the operation context does not match.
7. PostgreSQL independently verifies the minimum conditions required for a protected database operation.
8. Required stages fail closed on `FAIL` or `NOT_EVALUATED`.
9. `NOT_REQUIRED` is valid only when an applicable policy explicitly makes the stage unnecessary.
10. Client clocks are never authoritative for authorization validity.
11. A policy denial is an expected decision result, not automatically a database error.
12. An unexpected database or integrity failure is not silently converted into an authorization denial.
13. Material authorization history is append-oriented.
14. Core authorization fields use explicit typed columns and parameters, not opaque JSON payloads.
15. Supplemental metadata may use JSON only when it does not replace required typed scope.
16. No runtime identity receives direct unrestricted access to protected tables.
17. No single credential, device, session, role, approval, or network location grants unrestricted platform authority.

## Scope

This contract governs:

- Session establishment
- Step-up trust verification
- Authorization Lease issuance
- Authorization Lease renewal
- Protected-operation authorization
- Approval evaluation
- Database-boundary verification
- Decision-stage recording
- Final authorization results
- Stable reason codes
- Authorization-related concurrency behavior

This contract does not yet define:

- Production login roles
- Final ownership transfers
- Go package or API layout
- Provider-specific signature verification
- Operational-module resource schemas
- Off-host Decision Record anchoring
- Backup, restoration, or break-glass procedures

Those remain required later stages.

## Authorization Flow

The complete conceptual path is:

```text
Provider Evidence
      ↓
Verified Trust Assertion
      ↓
Session Establishment or Step-Up
      ↓
Identity, Device, Organization, and Eligibility Context
      ↓
Governed Purpose and Operation
      ↓
Authority and Separation-of-Duties Evaluation
      ↓
Independent Approval Evaluation
      ↓
Authorization Policy Decision
      ↓
Authorization Lease Issuance
      ↓
Controlled PostgreSQL Operation
      ↓
Decision Record and Protected History
```

Not every decision class uses every stage. An applicable policy explicitly identifies required and non-required stages.

## Decision Classes

Every authorization evaluation identifies one governed decision class.

Initial decision classes are:

### `SESSION_ESTABLISHMENT`

Establishes a new authenticated session from a verified Trust Assertion.

A successful result may create a new session.

It does not issue durable authority or permit an operational action by itself.

### `SESSION_STEP_UP`

Strengthens an existing session with a new verified Trust Assertion.

The assertion must be bound to the exact existing session, identity, device when required, audience, environment, and trust provider.

A step-up does not change the identity associated with a session.

### `LEASE_ISSUANCE`

Evaluates whether a short-lived Authorization Lease may be issued.

This class may evaluate:

- Identity state
- Device trust
- Session state
- Organization and service participation
- Eligibility
- Purpose
- Requested operation
- Jurisdiction
- Classification
- Authority grants
- Incompatible authority
- Approvals
- Risk or security restrictions
- Governing policy

### `LEASE_RENEWAL`

Issues a new lease after a new authorization evaluation or a narrowly governed renewal evaluation.

Renewal never extends the original row in place.

A renewal creates a new lease linked to the prior lease and Decision Record.

### `PROTECTED_OPERATION`

Evaluates whether one specific controlled database operation may execute.

The database verifies the Authorization Lease, current session, exact operation scope, current time, revocation state, usage state, and any minimum current conditions required by policy.

### `SECURITY_REVOCATION`

Records and applies an explicit security action such as session revocation, lease revocation, assertion revocation, or identity restriction.

A security revocation does not require the same flow as an ordinary operational action, but it must remain attributable and policy-governed.

## Canonical Request Context

Every material authorization evaluation carries a canonical request context.

Authorization-critical fields must be explicit.

The minimum request context is:

```text
request_id
correlation_id
decision_class
requester_identity_id
requester_organization_id
session_id
device_id
trust_assertion_id
service_id
purpose_definition_id
operation_key
target_type
target_reference
jurisdiction_id
classification_definition_id
authorization_policy_version_id
approval_request_id
authorization_lease_id
requested_at
evaluated_at
```

A field may be null only when the governing decision class and policy explicitly permit it.

### Request Identifier

`request_id` uniquely identifies the authorization request.

Retries must not silently create unrelated requests. A retry either:

- Reuses the original request identifier under a governed idempotency rule, or
- Creates a new request linked to the original request.

### Correlation Identifier

`correlation_id` connects the request, Trust Assertion, session, approvals, lease, protected operation, Decision Record, telemetry, and provider delivery records.

A correlation identifier is not an authorization secret.

### Requester Identity

`requester_identity_id` identifies the identity attempting the action.

A protected operation must not infer the requester solely from a database login name, network address, or unverified client field.

### Requester Organization

`requester_organization_id` identifies the organization under whose authority the requester is acting.

The identity must have current, applicable organizational eligibility or authority for that organization.

### Service

`service_id` identifies the Platform Service whose protected operation is being requested.

A protected operation requires an exact service match.

A platform-level session does not automatically authorize every service.

### Purpose

`purpose_definition_id` references a governed purpose definition.

Free-form explanatory text may supplement the purpose but must not replace it.

### Operation

`operation_key` identifies a governed operation.

Free-form operation names are not accepted for protected operations.

Operation keys use stable lowercase identifiers:

```text
^[a-z][a-z0-9_.-]*$
```

Examples:

```text
foundation.session.establish
foundation.session.revoke
foundation.lease.issue
foundation.lease.revoke
foundation.approval.record
```

Operational modules will later define their own governed operation keys.

### Target

The target is represented by:

```text
target_type
target_reference
```

`target_type` identifies the governed resource class.

`target_reference` identifies the exact resource or bounded resource set.

The target must be interpreted by the controlled operation, not through arbitrary dynamic SQL.

### Jurisdiction

`jurisdiction_id` identifies the applicable governed jurisdiction when jurisdiction is relevant.

Absence of a jurisdiction is not equivalent to universal jurisdiction.

### Classification

`classification_definition_id` identifies the applicable governed data classification when classification is relevant.

Absence of classification is not equivalent to unrestricted data.

### Policy Version

`authorization_policy_version_id` identifies the exact policy version evaluated.

A generic policy key without a version is insufficient for a material Decision Record.

## Explicit Data Contract

Authorization-critical values must not be accepted only inside a JSON object.

The following require typed columns or typed function parameters:

- Identity
- Organization
- Service
- Session
- Device
- Trust Assertion
- Purpose
- Operation
- Target
- Jurisdiction
- Classification
- Approval request
- Authorization Lease
- Policy version
- Evaluation time
- Final result
- Reason codes

JSON may be used for:

- Non-authoritative provider evidence snapshots
- Supplementary explanation
- Non-secret diagnostic context
- Policy-specific metadata that does not replace required scope

Secrets, plaintext lease values, session tokens, private keys, and provider credentials must not be stored in Decision Record JSON.

## Trust Assertion Contract

### Assertion Roles

A Trust Assertion supports one of two initial purposes:

```text
SESSION_ESTABLISHMENT
SESSION_STEP_UP
```

A future policy may define additional narrowly bounded assertion purposes.

### Session Establishment Assertion

A session-establishment assertion:

- Has no existing `session_id`
- Identifies the expected identity
- Identifies the expected device when device binding is required
- Identifies the trust provider
- Identifies the exact audience
- Identifies the exact environment
- Is cryptographically verified before consumption
- Is consumed atomically when the session is created

The assertion and new session must be connected in the resulting Decision Record.

### Step-Up Assertion

A step-up assertion:

- Has a non-null `session_id`
- Matches the existing session exactly
- Matches the session identity
- Matches the session device when device-bound
- Matches the trust provider required by policy
- Matches the exact audience
- Matches the exact environment
- Is cryptographically verified before consumption
- Is consumed atomically for the step-up decision

A step-up assertion must not rebind a session to another identity, device, service, audience, or environment.

### Assertion Lifecycle

The normative lifecycle is:

```text
RECEIVED
    ↓
VERIFIED
    ↓
CONSUMED
```

Terminal alternatives are:

```text
REJECTED
EXPIRED
REVOKED
```

Meanings:

- `RECEIVED` — stored but not yet trusted for authorization.
- `VERIFIED` — signature and provider evidence have been validated by an authorized verifier.
- `CONSUMED` — used exactly once for its intended decision context.
- `REJECTED` — verification failed or the provider evidence was unacceptable.
- `EXPIRED` — no longer valid due to time.
- `REVOKED` — explicitly invalidated before use.

Only `VERIFIED` assertions are consumable.

### Signature Verification Boundary

Provider-specific signature verification may occur outside PostgreSQL.

PostgreSQL must not treat an arbitrary runtime insert as verified evidence.

A later deployment design must restrict the transition to `VERIFIED` to a dedicated controlled verifier path.

### Assertion Freshness

Policy may require a maximum assertion age shorter than the provider expiration.

The effective assertion validity requires:

```text
issued_at <= evaluated_at
evaluated_at < expires_at
evaluated_at - issued_at <= policy maximum assertion age
```

when a maximum age is configured.

### Assertion Context Match

Consumption requires exact matching of every applicable context field:

- Assertion identifier
- Assertion purpose
- Identity
- Device
- Session
- Trust provider
- Audience
- Environment
- Current status
- Current time

A mismatch returns one externally generic denial while retaining a more specific internal reason code.

## Session Contract

### Session Meaning

A session represents authenticated identity continuity.

A session does not independently grant operational authority.

### Session Binding

A session binds:

- Identity
- Device when device-bound
- Trust provider
- Service scope
- Authentication time
- Absolute expiration
- Activity state
- Revocation state
- Correlation context

### Protected-Operation Session Rule

A protected operation requires:

- The exact expected session
- The exact identity
- The exact service
- The exact device when device-bound
- Active status
- No revocation
- No termination
- Current absolute validity
- Current inactivity validity when inactivity expiration is enabled

A platform-scoped session may support navigation or service-session creation, but it does not automatically satisfy a protected service operation.

### Session Lifecycle

The initial session statuses are:

```text
ACTIVE
EXPIRED
REVOKED
TERMINATED
LOCKED
```

Meanings:

- `ACTIVE` — currently eligible for evaluation.
- `EXPIRED` — validity ended by time.
- `REVOKED` — invalidated by security or administrative action.
- `TERMINATED` — deliberately ended through normal session termination.
- `LOCKED` — temporarily prohibited due to a security condition.

### Session Event History

Current session state may be maintained in a controlled current-state row.

Material changes also create append-oriented events:

```text
CREATED
ACTIVITY_RECORDED
STEP_UP_COMPLETED
LOCKED
UNLOCKED
REVOKED
TERMINATED
EXPIRED
```

## Authorization Policy Contract

Migration `055` must eventually contain an explicit authorization-policy and policy-version model.

An authorization policy version defines:

- Policy key
- Version number
- Decision class
- Effective period
- Status
- Applicable service
- Applicable organization scope
- Applicable purpose
- Applicable operation
- Applicable target scope
- Jurisdiction requirements
- Classification requirements
- Trust Assertion requirement
- Maximum assertion age
- Device requirement
- Session requirement
- Eligibility requirement
- Authority requirements
- Incompatible-authority rules
- Approval policy
- Risk or security stages
- Lease use mode
- Lease lifetime
- Lease usage limit
- Decision stages
- Reason-code behavior
- Governing document version
- Integrity metadata

### Policy Selection

Policy selection must be deterministic.

Multiple simultaneously applicable active policy versions for the same complete scope are not permitted unless a separate governed precedence rule resolves them.

No applicable policy results in denial.

Ambiguous policy selection results in denial.

### Policy Status

Initial policy statuses are:

```text
DRAFT
ACTIVE
SUSPENDED
SUPERSEDED
RETIRED
```

Only one applicable `ACTIVE` version may govern a specific evaluation scope unless precedence is explicitly modeled.

### Policy Effective Period

A policy is applicable only when:

```text
valid_from <= evaluated_at
evaluated_at < valid_until
```

when `valid_until` is present.

## Decision Stages

Each stage returns exactly one result:

```text
PASS
FAIL
NOT_REQUIRED
NOT_EVALUATED
```

### Result Meanings

- `PASS` — the stage was required or applicable and its condition was satisfied.
- `FAIL` — the stage was evaluated and denied the request.
- `NOT_REQUIRED` — the applicable policy explicitly made the stage unnecessary.
- `NOT_EVALUATED` — the stage could not be evaluated or was not evaluated.

A required stage returning `FAIL` or `NOT_EVALUATED` denies the operation.

### Initial Stage Catalog

The initial governed stage keys are:

```text
REQUEST_CONTEXT
TRUST_ASSERTION
IDENTITY_STATE
DEVICE_TRUST
ORGANIZATION_PARTICIPATION
ACCESS_ELIGIBILITY
SESSION_STATE
PURPOSE_AND_OPERATION
JURISDICTION
CLASSIFICATION
AUTHORITY
SEPARATION_OF_DUTIES
APPROVAL
AUTHORIZATION_LEASE
RISK_AND_SECURITY
DATABASE_BOUNDARY
```

A policy identifies which stages are required.

### Stage Ordering

The default evaluation order is:

1. `REQUEST_CONTEXT`
2. `TRUST_ASSERTION`
3. `IDENTITY_STATE`
4. `DEVICE_TRUST`
5. `ORGANIZATION_PARTICIPATION`
6. `ACCESS_ELIGIBILITY`
7. `SESSION_STATE`
8. `PURPOSE_AND_OPERATION`
9. `JURISDICTION`
10. `CLASSIFICATION`
11. `AUTHORITY`
12. `SEPARATION_OF_DUTIES`
13. `APPROVAL`
14. `AUTHORIZATION_LEASE`
15. `RISK_AND_SECURITY`
16. `DATABASE_BOUNDARY`

A decision class may make a stage `NOT_REQUIRED`, but it must not silently omit a required stage.

## Approval Contract

### Approval Request Binding

An approval request binds:

- Requester identity
- Requester organization
- Requester session
- Service
- Purpose
- Operation
- Target
- Policy version
- Required stages
- Expiration
- Correlation identifier

### Approval Independence

When required, effective approvals must be independent by:

- Identity
- Organization
- Authority source
- Session
- Conflict status

Policy determines the required independence dimensions.

### Self-Approval

Self-approval is prohibited unless the exact active approval-policy version explicitly allows it.

A general role or administrator status does not override this rule.

### Duplicate Effective Approval

Multiple approval rows from the same effective actor do not satisfy multiple required approvals.

The evaluator counts distinct qualifying actors after withdrawals, revocations, expiration, and supersession are applied.

### Approval History

Approval actions are append-oriented.

Approval, denial, abstention, withdrawal, cancellation, escalation, correction, and supersession are separate events.

An approval row is not edited to change its historical meaning.

## Authority Contract

### Authority Scope

An authority grant is applicable only when all required scope matches:

- Identity
- Organization
- Service
- Purpose
- Operation
- Target or scope
- Jurisdiction
- Classification
- Effective time

### Incompatible Authority

Role or grant accumulation must not bypass separation of duties.

The evaluator considers every effective direct, delegated, organizational, and service-derived authority.

An applicable incompatible-authority rule denies or escalates the request according to policy.

### Delegation

Delegated authority must be:

- Explicit
- Attributable
- Time-bounded
- Revocable
- No broader than the delegator's authority
- Applicable to the exact service and scope
- Included in the Decision Record

## Authorization Lease Contract

### Lease Meaning

An Authorization Lease is a short-lived, revocable, scope-bound capability issued after a successful authorization decision.

It is not a role, session, or permanent grant.

### Required Lease Bindings

A lease binds:

- Identity
- Requester organization
- Session
- Device when required
- Service
- Purpose
- Operation
- Target
- Jurisdiction
- Classification
- Authorization policy version
- Issuing Decision Record
- Approval request when required
- Authority grants used
- Issue time
- Activation time when applicable
- Expiration time
- Use mode
- Usage limit when applicable
- Revocation state
- Correlation identifier

### Lease Secret

When a lease uses a bearer secret:

- The plaintext is high entropy.
- PostgreSQL stores only a verifier.
- The plaintext is shown only at issuance.
- The plaintext is not stored in logs, Decision Records, URLs, or telemetry.
- Verification uses a timing-safe cryptographic comparison where applicable.

### Lease Use Modes

The initial use modes are:

```text
REUSABLE
SINGLE_USE
LIMITED_USE
```

#### `REUSABLE`

May authorize repeated matching operations until expiration or revocation.

The operation context must match on every use.

#### `SINGLE_USE`

May authorize exactly one successful matching protected operation.

Consumption is atomic.

Concurrent attempts permit at most one successful use.

#### `LIMITED_USE`

May authorize no more than the policy-defined maximum number of successful matching operations.

Each use creates an append-oriented lease-use event.

The usage limit is enforced atomically.

### Lease Lifetime

A lease expiration must not exceed the earliest applicable expiration of:

- Session
- Authority grant
- Approval validity
- Eligibility
- Policy version
- Trust condition required by policy
- Explicit policy maximum lease lifetime

### Lease Verification

A controlled operation verifies:

- Lease identifier
- Lease secret
- Active status
- Current time
- Revocation state
- Usage state
- Identity
- Organization
- Session
- Device
- Service
- Purpose
- Operation
- Target
- Jurisdiction
- Classification
- Policy version where required

A valid secret with mismatched scope denies the operation.

### Lease Renewal

Renewal creates a new lease and new Decision Record.

A lease is not extended by changing `expires_at` on the original historical authorization.

## Time Contract

### Authoritative Time

PostgreSQL time is authoritative at the database security boundary.

Client-supplied time may be recorded as evidence but is not used to establish validity.

### Evaluation Time

One authorization evaluation captures:

```sql
v_evaluated_at := statement_timestamp();
```

Every validity comparison in that evaluation uses the same captured value.

### Transaction Time

`transaction_timestamp()` may be used when a specifically documented multi-statement transaction must use one transaction-wide time.

Its use must be explicit.

### Wall-Clock Time

`clock_timestamp()` may be used for operational observation or event receipt times when moving wall-clock time is intended.

It must not be repeatedly called for validity comparisons within one authorization evaluation.

### Half-Open Validity Period

Effective periods use:

```text
valid_from <= evaluated_at
evaluated_at < valid_until
```

when `valid_until` is present.

This avoids overlapping inclusive end points.

## Final Decision Results

The initial final results are:

```text
ALLOW
DENY
PENDING
ESCALATED
```

### `ALLOW`

Every required stage passed, and the requested decision-class outcome may occur.

### `DENY`

At least one required stage failed, required context was invalid, policy was missing or ambiguous, or a required stage was not evaluated.

### `PENDING`

The decision is incomplete because a governed asynchronous requirement remains outstanding, such as required approval.

`PENDING` must not perform the protected operation.

### `ESCALATED`

The applicable policy requires a separate elevated review or security process.

`ESCALATED` must not perform the protected operation unless a later distinct decision allows it.

### System Error

An unexpected SQL, integrity, serialization, or infrastructure failure is not a final authorization result.

It is a system error.

A system error rolls back the incomplete protected transaction and is reported through operational error handling.

It must not be disguised as a normal `DENY`.

## Denial Persistence Contract

A policy denial is an expected authorization outcome.

A controlled authorization function should normally:

1. Evaluate the request.
2. Write stage results.
3. Finalize a `DENY` Decision Record.
4. Avoid the protected mutation.
5. Return a typed denial result.
6. Allow the caller to commit the denial record.

The function must not write a denial record and then automatically raise an exception that causes the same transaction to roll back that record.

Malformed input that cannot identify a valid request context may raise an exception before a material Decision Record exists.

Unexpected integrity or infrastructure failures raise an exception and roll back.

## Stable Reason-Code Contract

Reason codes are stable machine-readable identifiers.

They use uppercase identifiers:

```text
^[A-Z][A-Z0-9_]*$
```

Human-readable explanations may change without changing the stable code.

### Request and Policy

```text
REQUEST_CONTEXT_INVALID
REQUEST_IDENTIFIER_CONFLICT
POLICY_NOT_FOUND
POLICY_NOT_ACTIVE
POLICY_NOT_EFFECTIVE
POLICY_AMBIGUOUS
POLICY_SCOPE_MISMATCH
OPERATION_NOT_GOVERNED
PURPOSE_NOT_GOVERNED
TARGET_SCOPE_INVALID
```

### Trust Assertion

```text
TRUST_ASSERTION_REQUIRED
TRUST_ASSERTION_NOT_FOUND
TRUST_ASSERTION_NOT_VERIFIED
TRUST_ASSERTION_NOT_YET_VALID
TRUST_ASSERTION_EXPIRED
TRUST_ASSERTION_REVOKED
TRUST_ASSERTION_CONSUMED
TRUST_ASSERTION_CONTEXT_MISMATCH
TRUST_ASSERTION_FRESHNESS_EXCEEDED
```

### Identity and Device

```text
IDENTITY_NOT_FOUND
IDENTITY_NOT_ACTIVE
IDENTITY_SUSPENDED
IDENTITY_SCOPE_MISMATCH
DEVICE_REQUIRED
DEVICE_NOT_FOUND
DEVICE_NOT_TRUSTED
DEVICE_REVOKED
DEVICE_CONTEXT_MISMATCH
```

### Organization, Service, and Eligibility

```text
ORGANIZATION_NOT_ACTIVE
ORGANIZATION_SCOPE_MISMATCH
SERVICE_NOT_ACTIVE
SERVICE_PARTICIPATION_REQUIRED
SERVICE_PARTICIPATION_INVALID
ELIGIBILITY_REQUIRED
ELIGIBILITY_NOT_ACTIVE
ELIGIBILITY_EXPIRED
ELIGIBILITY_SCOPE_MISMATCH
```

### Session

```text
SESSION_REQUIRED
SESSION_NOT_FOUND
SESSION_NOT_ACTIVE
SESSION_EXPIRED
SESSION_REVOKED
SESSION_TERMINATED
SESSION_LOCKED
SESSION_CONTEXT_MISMATCH
SESSION_STEP_UP_REQUIRED
```

### Authority and Separation of Duties

```text
AUTHORITY_REQUIRED
AUTHORITY_NOT_ACTIVE
AUTHORITY_EXPIRED
AUTHORITY_SCOPE_MISMATCH
AUTHORITY_CONFLICT
DELEGATED_AUTHORITY_INVALID
SEPARATION_OF_DUTIES_VIOLATION
```

### Approval

```text
APPROVAL_REQUIRED
APPROVAL_PENDING
APPROVAL_INSUFFICIENT
APPROVAL_EXPIRED
APPROVAL_DENIED
SELF_APPROVAL_PROHIBITED
APPROVAL_IDENTITY_NOT_INDEPENDENT
APPROVAL_ORGANIZATION_NOT_INDEPENDENT
APPROVAL_AUTHORITY_INVALID
APPROVAL_CONFLICT
```

### Authorization Lease

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
LEASE_JURISDICTION_MISMATCH
LEASE_CLASSIFICATION_MISMATCH
```

### Decision Evaluation

```text
REQUIRED_STAGE_FAILED
REQUIRED_STAGE_NOT_EVALUATED
DECISION_PENDING
DECISION_ESCALATED
RISK_RESTRICTION_ACTIVE
SECURITY_RESTRICTION_ACTIVE
DATABASE_BOUNDARY_DENIED
PROTECTED_OPERATION_DENIED
```

### External Disclosure

External callers receive only the minimum explanation appropriate to their authority.

Detailed internal reason codes remain available to authorized auditors and investigators.

Secret-verification detail is never disclosed.

## Decision Record Contract

Every material decision records:

- Decision identifier
- Request identifier
- Correlation identifier
- Decision class
- Requester identity
- Requester organization
- Session
- Device
- Trust Assertion
- Service
- Purpose
- Operation
- Target
- Jurisdiction
- Classification
- Policy version
- Approval request
- Authorization Lease
- Evaluated time
- Individual stage results
- Stable reason codes
- Final result
- Supporting record versions
- Integrity metadata

### Finalization Rule

A Decision Record cannot finalize as `ALLOW` when any required stage is:

```text
FAIL
NOT_EVALUATED
```

A required stage may be `NOT_REQUIRED` only when the policy explicitly marks it inapplicable.

### Finalized Record

After finalization:

- New evaluation stages cannot be added.
- Existing evaluation stages cannot be edited.
- The final result cannot be changed in place.
- Corrections and annotations create linked records.
- Revocation or supersession creates linked records.

### Secret Exclusion

Decision Records must not contain:

- Plaintext lease secrets
- Session tokens
- Private keys
- Provider credentials
- Full authentication payloads unless separately protected and explicitly required
- Passwords or MFA secrets

## Controlled PostgreSQL Operation Contract

A protected table mutation is performed only through a narrowly scoped function or controlled writer path.

The controlled operation:

1. Accepts explicit typed context.
2. Captures one evaluation time.
3. Resolves the governed policy version.
4. Validates the exact operation key.
5. Validates the exact target.
6. Validates current session state.
7. Validates the Authorization Lease and its secret.
8. Validates complete lease scope.
9. Validates revocation and usage state.
10. Atomically consumes or records lease use when required.
11. Creates or finalizes the Decision Record.
12. Performs the protected mutation only after authorization succeeds.
13. Returns a typed result.
14. Reveals no secret-verification detail.

A controlled function must not execute caller-supplied SQL.

## Function Result Contract

Controlled authorization functions should return a typed result containing at least:

```text
decision_record_id
request_id
correlation_id
final_result
primary_reason_code
evaluated_at
protected_operation_performed
authorization_lease_id
```

Supplementary reason codes may be returned only when disclosure policy permits.

The result does not contain secrets.

## Concurrency Contract

### Trust Assertion Consumption

Consumption uses one atomic state transition:

```text
VERIFIED → CONSUMED
```

Concurrent attempts allow exactly one successful transition.

### Session Revocation

A session revocation racing with authorization must produce a deterministic result based on locking and evaluation order.

A protected operation must not succeed after observing a committed revocation.

### Approval Recording

Duplicate effective approval by the same actor must not count twice under concurrent submission.

### Lease Use

For `SINGLE_USE`, exactly one concurrent matching operation succeeds.

For `LIMITED_USE`, the usage count cannot exceed the configured maximum.

Every successful use creates one append-oriented use event.

### Decision Finalization

A Decision Record finalizes once.

Concurrent finalization attempts must not create conflicting final results.

### Serialization Failure

A serialization or deadlock failure is a system error and retry condition.

It is not recorded as a policy denial.

## Idempotency Contract

A retry-safe controlled operation uses a governed request identifier or idempotency identifier.

The same identifier with the same immutable request context may return the existing result.

The same identifier with different context is rejected with:

```text
REQUEST_IDENTIFIER_CONFLICT
```

Idempotency must not allow replay of a single-use Trust Assertion or lease for a different operation.

## Status and Reason Catalog Governance

Statuses, decision classes, stage keys, operation keys, and reason codes are governed identifiers.

They must be:

- Documented
- Stable
- Version-aware where semantics can change
- Validated at the database boundary
- Included in tests
- Included in Decision Records when evaluated

A free-form status string must not silently introduce new authorization semantics.

## SQL Implementation Mapping

This contract primarily affects:

| Migration | Phase 0 implication |
|---|---|
| `050_approval_framework.sql` | Approval request scope, independence, action history, status contract |
| `055_authority_purpose_and_authorization_policy.sql` | Operation definitions, policy versions, stage requirements, reason catalog |
| `060_sessions.sql` | Session lifecycle, binding, controlled state changes, event history |
| `065_authorization_leases.sql` | Complete lease scope, use modes, linkage, use history |
| `070_postgresql_trust_gate.sql` | Assertion purpose, `VERIFIED` state, context binding, atomic consumption |
| `075_controlled_authorization_api.sql` | Typed controlled verification and denial behavior |
| `080_decision_record_repository.sql` | Decision classes, stage consistency, finalization, reason codes |
| `098_security_boundaries_and_role_separation.sql` | Later controlled writer and runtime role mapping |
| `099_foundation_validation.sql` | Validation visibility for the implemented contract |

## Required Phase 0 Documentation Updates

This contract is the primary Phase 0 document.

The following documents remain authoritative for their specialized subjects and should link to this contract:

- `trust-and-decision-engine-model.md`
- `approval-framework.md`
- `authority-and-authorization-model.md`
- `authorization-lease-model.md`
- `database-security-model.md`
- `decision-record-repository.md`

Where a specialized document and this contract appear to conflict, development must stop until the documents are reconciled explicitly.

## Required Phase 0 Test Fixtures

Before Phase 1 implementation, the test framework should have a reusable fixture plan for:

- Two organizations
- One Platform Service
- Two human identities
- Two independent approver identities
- One trusted device
- One trust provider
- One provider identity mapping
- One eligibility grant
- One purpose definition
- One operation definition
- One authority definition
- One authority grant
- One approval policy
- One authorization policy version
- One session
- One Trust Assertion
- One Authorization Lease
- One protected test resource

Fixtures must use clearly recognizable non-production UUIDs and contain no real credentials or protected data.

## Phase 0 Exit Criteria

Phase 0 is complete when:

1. This contract is accepted as normative.
2. Decision classes are fixed for the next implementation phases.
3. Canonical request context is fixed.
4. Trust Assertion purposes and lifecycle are fixed.
5. Session-establishment and step-up relationships are fixed.
6. The time model is fixed.
7. Policy selection and ambiguity behavior are fixed.
8. Decision-stage results and ordering are fixed.
9. Lease use modes are fixed.
10. Denial persistence behavior is fixed.
11. System errors are distinguished from policy denials.
12. Stable reason-code conventions and initial codes are fixed.
13. Concurrency and idempotency rules are fixed.
14. The exact migrations affected by Phases 1–7 are identified.
15. No production backend or operational-module design is required to continue.
16. The existing Foundation migration and test suite still passes without a SQL change.

## Next Phase

Phase 1 implements Trust Assertion context binding.

Its work includes:

- Adding assertion purpose
- Adding `VERIFIED`
- Restricting consumable state
- Exact context matching
- Statement-consistent evaluation time
- Atomic consumption
- Generic external denial
- Detailed internal reason recording
- Positive, negative, replay, and concurrency tests
