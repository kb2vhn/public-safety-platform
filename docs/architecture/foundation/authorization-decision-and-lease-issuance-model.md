# Authorization Decision and Lease Issuance Model

> **Layer:** Platform Foundation
>
> **Program:** Central Authorization Completion Program
>
> **Phase:** 3 — Authorization Decision and Controlled Lease Issuance
>
> **Status:** Normative Phase 3 contract; accepted
>
> **Accepted prerequisite:** `phase-2-session-control-complete-v1`
>
> **Accepted release tag:** `phase-3-authorization-control-complete-v1`
>
> **Active implementation migration:**
> `081_postgresql_authorization_decision_and_lease_issuance.sql`

## 1. Purpose

Define the exact Foundation contract for evaluating a bounded authorization
request, persisting its explanation, finalizing one authoritative Decision
Record, and issuing at most one context-bound Authorization Lease from an
eligible `ALLOW` decision.

Phase 3 connects structures that already exist in the Foundation:

- Authority, purpose, operation, and policy definitions
- Approval Requests and approval actions
- Access Eligibility and organizational participation
- Accepted Authentication Assertion and session boundaries
- Authorization Lease structures and secret hashing
- Decision Records, evaluation records, and supporting-record references

The existence of those structures is not sufficient. Phase 3 must provide one
controlled, fail-closed path that proves why a lease was issued and prevents a
caller from constructing authority by directly inserting rows or supplying
unverified booleans, role names, identifiers, timestamps, or scope text.

## 2. Security Objective

PostgreSQL may issue an Authorization Lease only when all of the following are
true in one authoritative evaluation context:

1. The request context is complete and internally consistent.
2. Exactly one applicable Authorization Policy Version is selected.
3. The accepted session is currently usable for the same identity, device,
   organization, service, audience, and environment.
4. Every required decision stage has a persistent terminal result.
5. No required stage is `FAIL` or `NOT_EVALUATED`.
6. Every `NOT_REQUIRED` stage cites the exact policy rule that made it
   inapplicable.
7. The Decision Record is finalized exactly once as `ALLOW`.
8. The lease context matches the finalized Decision Record exactly.
9. Lease lifetime and use limits are no broader than the selected policy.
10. The lease secret is represented only by a verifier at rest.
11. The issuing transaction creates no second lease for the same decision.
12. The complete result remains attributable and reconstructable.

A caller-supplied `allowed=true`, role name, policy name, decision result,
scope string, client timestamp, or preassembled lease row is never an
authority source.

## 3. Non-Goals

Phase 3 does not claim to complete:

- Provider-specific authentication protocol verification
- Final Go service implementation
- Final production database ownership or runtime-role grants
- Every future municipal or public-safety authorization policy
- Final data-classification compatibility algorithms
- Final risk-scoring algorithms
- External policy engines
- Cross-database distributed transactions
- Multi-region lease invalidation
- Off-host integrity anchoring
- Production secret delivery
- Break-glass procedures
- Backup, rebuild, or compromise-recovery procedures
- Protected module operations themselves

Phase 3 establishes the database-enforced decision and lease-issuance
boundary upon which those later capabilities rely.

## 4. Governing Principles

### 4.1 Authentication Is Not Authorization

A verified Authentication Assertion and an active session establish trusted
identity continuity. They do not prove authority for a protected operation.

### 4.2 Durable Authority Is Not a Capability

An Authority Grant is evidence considered by a decision. It does not create a
permanent session, unrestricted role, or reusable universal capability.

### 4.3 Approval Is an Input

An approval action is attributable policy evidence. Approval alone does not
issue a lease and does not bypass identity, session, scope, policy,
classification, or authority checks.

### 4.4 Policy Selection Is Deterministic

Exactly one active, effective policy version must govern the request.

- No applicable policy denies the request.
- More than one equally applicable policy denies the request.
- A caller may identify an expected policy version, but PostgreSQL must verify
  that it is the unique applicable version.
- A policy key or display name cannot replace the authoritative policy-version
  identifier.

### 4.5 Required Stages Fail Closed

A required stage returning `FAIL` or `NOT_EVALUATED` denies issuance.

`NOT_REQUIRED` is valid only when the selected policy contains an exact,
persisted rule making that stage inapplicable.

### 4.6 Database Time Is Authoritative

One evaluation captures one authoritative timestamp:

```sql
v_evaluated_at := statement_timestamp();
```

Every effective-period, expiration, freshness, and lifetime comparison in
that evaluation uses the same captured value.

Client clocks are never authoritative.

### 4.7 Explanation Is Part of the Result

An `ALLOW` without its required stage records and supporting evidence is
invalid.

A normal policy denial must remain persistable and explainable. It must not be
written and then erased by an exception in the same transaction.

Unexpected integrity, serialization, deadlock, or infrastructure failures are
system errors. They are not silently converted into policy denials.

## 5. Canonical Authorization Request

A material lease-issuance request uses explicit typed context.

Initial required fields are:

```text
request_id
correlation_id
decision_class
requester_identity_id
requester_organization_id
session_id
device_id
service_id
purpose_definition_id
operation_definition_id
protected_target_type
protected_target_reference
governed_scope_id
classification_key
expected_policy_version_id
approval_request_id
requested_at
requested_lease_lifetime
requested_use_mode
requested_usage_limit
lease_audience
```

A field may be null only when the decision class and selected policy
explicitly permit it.

### 5.1 Request Identifier

`request_id` identifies one immutable authorization request.

Reusing a request identifier with different immutable context is denied as
`REQUEST_IDENTIFIER_CONFLICT`.

### 5.2 Correlation Identifier

`correlation_id` links the request, session, approval, Decision Record, lease,
protected operation, audit export, and telemetry.

It is not a secret and does not grant authority.

### 5.3 Operation Identity

`operation_definition_id` is authoritative.

A stable `operation_key` may be retained as an immutable historical snapshot,
but the database must prove that the key belongs to the referenced definition.

### 5.4 Protected Resource Target

The target uses:

```text
protected_target_type
protected_target_reference
```

The target reference is data interpreted by the controlled operation. It is
never caller-supplied SQL.

### 5.5 Governed Scope

`governed_scope_id` identifies the applicable typed Foundation boundary.

A null Governed Scope means the selected policy explicitly does not require
one. It never means universal scope.

### 5.6 Classification

The request carries the applicable governed classification identifier or,
until the final versioned catalog dependency is available, the exact governed
classification key required by the policy.

Free-form classification text is not authoritative.

## 6. Deterministic Policy Selection

The selected Authorization Policy Version must be:

- `ACTIVE`
- Effective at `v_evaluated_at`
- Applicable to the decision class
- Applicable to the Platform Service
- Applicable to the Governed Purpose
- Applicable to the Governed Operation
- Applicable to the organization and Governed Scope where configured
- Compatible with the target and classification context
- Not replaced, revoked, or superseded for the evaluated time
- The unique most-specific applicable version under the defined precedence

Initial precedence must be explicit rather than inferred from row order.

A later implementation may encode precedence using typed specificity columns
or a controlled ranking function. It must not rely on:

- Physical table order
- UUID ordering
- `LIMIT 1` without a uniqueness proof
- Caller preference
- Display names
- Unversioned policy keys

Policy ambiguity produces a persisted `DENY` decision with reason
`AUTHORIZATION_POLICY_AMBIGUOUS`.

No policy produces a persisted `DENY` decision with reason
`AUTHORIZATION_POLICY_NOT_FOUND`.

## 7. Decision Stages

Each governed stage records exactly one result:

```text
PASS
FAIL
NOT_REQUIRED
NOT_EVALUATED
```

Initial lease-issuance stage keys are:

```text
REQUEST_CONTEXT
POLICY_SELECTION
IDENTITY_STATE
DEVICE_TRUST
ORGANIZATION_PARTICIPATION
ACCESS_ELIGIBILITY
SESSION_STATE
PURPOSE_AND_OPERATION
PROTECTED_TARGET
GOVERNED_SCOPE
DATA_CLASSIFICATION
AUTHORITY
SEPARATION_OF_DUTIES
APPROVAL
RISK_AND_SECURITY
LEASE_CONDITIONS
DATABASE_BOUNDARY
```

### 7.1 Result Meanings

`PASS`
: Authoritative records prove the condition.

`FAIL`
: The condition was evaluated and not satisfied.

`NOT_REQUIRED`
: The selected policy contains an exact rule making the stage inapplicable.

`NOT_EVALUATED`
: Evaluation did not complete or the required evidence was unavailable.

### 7.2 Required Stage Closure

A Decision Record cannot finalize as `ALLOW` while any required stage:

- Is missing
- Has more than one effective result
- Is `FAIL`
- Is `NOT_EVALUATED`
- Is `NOT_REQUIRED` without an exact supporting policy rule
- Lacks required supporting-record references

### 7.3 Evaluation Ordering

`evaluation_order` is deterministic for one policy version.

Order supports explanation and review. It must not be treated as a substitute
for the required/optional flag or the selected policy rule.

## 8. Session and Context Verification

Phase 3 consumes the accepted Phase 2 session boundary without weakening it.

At `v_evaluated_at`, the session must:

- Exist
- Be `ACTIVE`
- Not be absolutely expired
- Not exceed its inactivity limit
- Match the requester identity
- Match the requester organization
- Match the device when device-bound
- Match the Trust Provider context retained by the session
- Match the Platform Service
- Match required audience and environment context
- Remain locally usable under current identity, device, organization, and
  service state

A lease cannot outlive the session that authorized it.

A lease lifetime is bounded by the earliest of:

- Policy maximum lease lifetime
- Session absolute expiration
- Applicable Authority Grant expiration
- Applicable Access Eligibility expiration
- Applicable approval expiration
- Applicable organizational participation expiration
- Applicable security restriction or policy-version expiration

## 9. Authority Evaluation

An Authority Grant is applicable only when all configured context matches:

- Identity
- Organization
- Platform Service
- Governed Purpose
- Governed Operation
- Protected Resource Target where constrained
- Governed Scope
- Classification limit
- Effective time
- Active status

The complete effective grant set must be evaluated.

A caller cannot select one favorable grant while hiding other active grants
that create an incompatibility or separation-of-duties conflict.

### 9.1 Incompatible Authority

Every active incompatible-authority set applicable to the operation is
evaluated against the identity's complete effective authority.

An incompatible combination fails with
`INCOMPATIBLE_AUTHORITY_COMBINATION`.

### 9.2 Delegated Authority

Delegated authority must be:

- Explicit
- Attributable
- Effective-dated
- Revocable
- No broader than the delegator's current effective authority
- Included in incompatibility and separation-of-duties evaluation

## 10. Approval Evaluation

When approval is required:

- The Approval Request must exist and be active.
- Its immutable request context must match the authorization request.
- It must use the required approval-policy version.
- It must not be expired.
- Required approval actions must be effective.
- Duplicate actions by one effective actor count once.
- Self-approval is denied unless the exact policy version explicitly permits
  it.
- The requester, approver, issuer, and executor separation rules must be
  enforced where configured.
- Revoked, superseded, withdrawn, or denied approval evidence cannot satisfy
  the request.

Approval mismatch denies issuance. It does not silently create a new Approval
Request.

## 11. Decision Record Lifecycle

Initial decision lifecycle:

```text
PENDING
    ↓
ALLOW
```

or:

```text
PENDING
    ↓
DENY
```

`ESCALATED` may be used only when a policy-defined external or additional
approval path is required. It does not issue a lease.

### 11.1 Creation

The controlled evaluation creates one Decision Record with:

- Immutable request context
- Selected policy-version identifier
- Evaluation timestamp
- Engine and schema versions
- Correlation identifier
- Initial `PENDING` state

### 11.2 Evaluation Records

Each stage creates one append-oriented evaluation record containing:

- Stage key
- Deterministic order
- Required flag
- Result
- Stable reason code
- Safe explanation
- Evaluation timestamp
- Duration where available
- Supporting-record references
- Supporting record versions or hashes where applicable

### 11.3 Finalization

A Decision Record finalizes once.

Finalization must lock the Decision Record and validate its complete stage set.

An `ALLOW` finalization requires every required stage to satisfy the closure
rules in this document.

A `DENY` finalization preserves the failed and unevaluated stages needed to
explain the result.

A finalized Decision Record is not edited in place.

Corrections, review, revocation, supersession, or later reevaluation create
linked records.

### 11.4 Decision/Lease Cardinality

One Decision Record may issue at most one Authorization Lease.

A `DENY`, `PENDING`, or `ESCALATED` decision issues no lease.

A second issuance attempt for the same `ALLOW` decision returns a generic
external denial and records an internal
`AUTHORIZATION_DECISION_ALREADY_USED` reason.

## 12. Authorization Lease Contract

An issued lease binds, at minimum:

```text
authorization_lease_id
issuing_decision_id
request_id
correlation_id
identity_id
organization_id
session_id
device_id
service_id
purpose_definition_id
operation_definition_id
protected_target_type
protected_target_reference
governed_scope_id
classification_key
authorization_policy_version_id
approval_request_id
lease_audience
use_mode
usage_limit
issued_at
not_before
expires_at
status
lease_secret_hash
```

### 12.1 Context Exactness

Lease verification requires exact match for every applicable field.

A correct secret with the wrong identity, organization, session, device,
service, purpose, operation, target, scope, classification, policy, or
audience is denied as a context mismatch.

### 12.2 Lifetime

The lease is short-lived.

Renewal creates a new authorization request, a new Decision Record, and a new
lease. The existing lease is never extended in place.

### 12.3 Use Modes

Initial use modes:

```text
REUSABLE
SINGLE_USE
LIMITED_USE
```

`REUSABLE`
: May be used repeatedly until expiration or revocation.

`SINGLE_USE`
: Exactly one transaction may consume it.

`LIMITED_USE`
: Successful consumption count cannot exceed the policy-bounded usage limit.

### 12.4 Secret Handling

The plaintext lease secret must be cryptographically random and high entropy.

PostgreSQL stores only a verifier.

The secret must not appear in:

- Decision context
- Evaluation explanations
- Supporting-record JSON
- General logs
- URLs
- Metrics labels
- Audit exports
- Error details

A secret match is only one verification input.

### 12.5 Status

Initial lease statuses:

```text
ACTIVE
CONSUMED
EXPIRED
REVOKED
```

A terminal lease cannot return to `ACTIVE`.

Expiration is based on PostgreSQL time even when the row has not yet been
materially updated to `EXPIRED`.

### 12.6 Revocation

Revocation may be triggered by:

- Session revocation, termination, or expiration
- Identity ineligibility
- Device distrust or revocation
- Organization or service participation loss
- Authority Grant revocation
- Approval withdrawal or invalidation
- Policy revocation or supersession
- Security restriction
- Explicit administrative security action

Revocation is attributable and reason-coded.

## 13. Controlled Issuance Transaction

The planned controlled issuance path performs the following in one database
transaction:

1. Capture `v_evaluated_at`.
2. Validate immutable request shape.
3. Select and lock the unique applicable policy version.
4. Create or lock the request's Decision Record.
5. Revalidate accepted session context and current local trust.
6. Evaluate organization participation and Access Eligibility.
7. Evaluate purpose, operation, target, scope, and classification.
8. Evaluate the complete effective Authority Grant set.
9. Evaluate incompatibilities and separation of duties.
10. Evaluate required approval evidence.
11. Evaluate risk and security restrictions owned by PostgreSQL.
12. Record every required evaluation result and supporting evidence.
13. Finalize the Decision Record once.
14. When the result is `ALLOW`, calculate the maximum permitted lease bounds.
15. Insert exactly one context-bound lease linked to the Decision Record.
16. Link the lease to every Authority Grant that supported issuance.
17. Return a typed result that does not expose internal verification detail.

The issuance path must not:

- Accept an `ALLOW` boolean from the caller
- Accept a client-selected final result
- Trust client timestamps
- Trust unverified identity or device identifiers
- Permit direct lease insertion by an ordinary runtime identity
- Issue from an incomplete Decision Record
- Issue from a denial
- Issue more than once from one decision
- Store plaintext secrets
- Create a lease broader or longer than the selected policy permits

## 14. Controlled Function Boundary

The planned migration is:

```text
sql/schema/migrations/foundation/
081_postgresql_authorization_decision_and_lease_issuance.sql
```

It is placed after `080_decision_record_repository.sql` and before
`082_data_classification_and_governance.sql`.

This preserves the accepted Phase 2 migrations and allows the controlled
issuance path to depend on:

- Authority and policy structures from `055`
- Session structures from `060`
- Lease structures from `065`
- Accepted assertion controls from `070`
- Accepted session controls from `072`
- Baseline lease hashing and revocation functions from `075`
- Decision Record structures from `080`

Migration `081` may add constraints, indexes, typed binding columns, and
controlled functions required by this contract.

It must not silently rewrite the accepted meaning of migrations `060`, `070`,
or `072`.

### 14.1 Initial Planned Functions

Exact signatures are frozen in the implementation step, but the initial
controlled responsibilities are:

```text
select_applicable_authorization_policy
finalize_authorization_decision
issue_authorization_lease_from_decision
authorization_lease_context_is_usable
consume_authorization_lease
```

A helper may be split when doing so produces a clearer privilege or locking
boundary.

Every function must:

- Use an explicit trusted `search_path`
- Schema-qualify security-sensitive calls
- Be revoked from `PUBLIC`
- Have a complete `COMMENT`
- Avoid `SECURITY DEFINER` unless a separately reviewed ownership and privilege
  design proves it necessary
- Lock rows in a deterministic order
- Use stable reason codes
- Avoid leaking secret-verification detail

## 15. Denial and Error Contract

### 15.1 Policy Denial

A normal denial:

1. Persists its Decision Record and stage results.
2. Performs no lease insertion.
3. Performs no protected operation.
4. Returns a typed denial result.
5. Uses a generic external message.
6. Retains a stable internal reason code.

### 15.2 System Error

Unexpected failures raise an error and roll back the incomplete transaction.

Examples:

- Constraint violation caused by implementation error
- Serialization failure
- Deadlock
- Missing required database object
- Corrupt or contradictory authoritative state
- Failure to persist required evidence

A system error is not recorded as an ordinary `DENY` unless a separate,
successful transaction later records the operational failure.

## 16. Stable Reason Codes

Initial policy-selection codes:

```text
AUTHORIZATION_POLICY_NOT_FOUND
AUTHORIZATION_POLICY_AMBIGUOUS
AUTHORIZATION_POLICY_INACTIVE
AUTHORIZATION_POLICY_NOT_EFFECTIVE
AUTHORIZATION_POLICY_CONTEXT_MISMATCH
```

Initial decision-finalization codes:

```text
AUTHORIZATION_DECISION_NOT_FOUND
AUTHORIZATION_DECISION_ALREADY_FINALIZED
AUTHORIZATION_DECISION_INCOMPLETE
AUTHORIZATION_DECISION_REQUIRED_STAGE_FAILED
AUTHORIZATION_DECISION_REQUIRED_STAGE_NOT_EVALUATED
AUTHORIZATION_DECISION_NOT_REQUIRED_RULE_MISSING
AUTHORIZATION_DECISION_ALREADY_USED
```

Initial authority and approval codes:

```text
AUTHORITY_GRANT_REQUIRED
AUTHORITY_GRANT_NOT_FOUND
AUTHORITY_GRANT_INACTIVE
AUTHORITY_GRANT_NOT_EFFECTIVE
AUTHORITY_GRANT_CONTEXT_MISMATCH
INCOMPATIBLE_AUTHORITY_COMBINATION
SEPARATION_OF_DUTIES_FAILED
APPROVAL_REQUIRED
APPROVAL_NOT_FOUND
APPROVAL_INCOMPLETE
APPROVAL_EXPIRED
APPROVAL_CONTEXT_MISMATCH
SELF_APPROVAL_PROHIBITED
```

Initial lease-issuance codes:

```text
LEASE_ISSUANCE_NOT_ALLOWED
LEASE_LIFETIME_INVALID
LEASE_LIFETIME_EXCEEDS_POLICY
LEASE_LIFETIME_EXCEEDS_SESSION
LEASE_USE_MODE_INVALID
LEASE_USAGE_LIMIT_INVALID
LEASE_AUDIENCE_REQUIRED
LEASE_CONTEXT_INCOMPLETE
```

Reason codes are stable machine-readable values:

```text
^[A-Z][A-Z0-9_]*$
```

## 17. Concurrency Contract

Phase 3 must prove with independent PostgreSQL connections:

1. One Decision Record finalizes once.
2. One `ALLOW` Decision Record issues at most one lease.
3. Concurrent policy selection cannot choose different equally applicable
   versions.
4. A `SINGLE_USE` lease is consumed by exactly one transaction.
5. A `LIMITED_USE` lease never exceeds its usage limit.
6. Revocation racing consumption produces one allowed terminal outcome and no
   mixed state.
7. A denied or incomplete decision cannot win an issuance race.

Serialization and deadlock errors are retryable system conditions, not policy
denials.

## 18. Privilege and Ownership Contract

Ordinary runtime identities must not receive direct insert, update, or delete
privileges on:

- Decision Records
- Evaluation records
- Supporting-record links
- Authorization Leases
- Lease-to-authority evidence
- Decision finalization state
- Lease usage state

Runtime access is through controlled functions with narrowly defined execute
grants established during the deployment-security phase.

The unavoidable database-owner and PostgreSQL-superuser boundary remains an
infrastructure trust boundary and must be handled through operational
separation, protected credentials, off-host evidence, and trusted rebuild
procedures.

## 19. Test Contract

### 19.1 Structural Tests

Tests must verify:

- Required columns, constraints, indexes, and foreign keys
- Decision-to-lease uniqueness
- Allowed decision and evaluation states
- Terminal-state chronology
- Trusted function search paths
- Function comments
- `PUBLIC` execution removal
- No unexpected `SECURITY DEFINER`
- No direct ordinary-runtime table-write path

### 19.2 Sequential Behavioral Tests

Tests must cover:

- Unique policy selection
- Missing policy denial
- Ambiguous policy denial
- Session mismatch
- Expired or locked session
- Identity, device, organization, or service mismatch
- Missing or expired Access Eligibility
- Purpose or operation mismatch
- Target mismatch
- Governed Scope mismatch
- Classification mismatch
- Missing Authority Grant
- Incompatible authority
- Separation-of-duties failure
- Missing, expired, duplicate, or self approval
- Required `FAIL`
- Required `NOT_EVALUATED`
- Valid policy-defined `NOT_REQUIRED`
- Invalid `NOT_REQUIRED` without a supporting rule
- Successful `ALLOW` finalization
- Exactly one linked lease
- Lease lifetime bounding
- Lease context verification
- Denial persistence without lease insertion
- No plaintext secret persistence

### 19.3 Concurrency Tests

Tests must use real independent connections and deterministic release barriers
for:

- Decision finalization
- Lease issuance
- Single-use consumption
- Limited-use consumption
- Consumption versus revocation

### 19.4 Regression

Every Phase 3 run must retain the accepted Phase 2 baseline:

```text
32 accepted Phase 2 manifest migrations
12 accepted sequential test files
4 accepted concurrency test files
213 accepted PASS assertions
0 accepted FAIL assertions
3 understood WARN results
```

The accepted Phase 3 Step 2 target adds one migration and one 60-assertion
structural test:

```text
33 manifest migrations
33 registered migrations
13 sequential test files
4 concurrency test files
273 PASS assertions
0 FAIL assertions
3 understood WARN results
```

The Phase 3 Step 3 target adds one 24-assertion controlled behavior test:

```text
33 manifest migrations
33 registered migrations
14 sequential test files
4 concurrency test files
297 PASS assertions
0 FAIL assertions
3 understood WARN results
```

The accepted Phase 3 Step 4 target adds one 32-assertion controlled lease test:

```text
33 manifest migrations
33 registered migrations
15 sequential test files
4 concurrency test files
329 PASS assertions
0 FAIL assertions
3 understood WARN results
```

## 20. Implementation Sequence

### Step 1 — Contract Freeze

- Add this normative model.
- Mark Phase 2 as accepted in the Foundation index and wider evaluation
  contract.
- Define migration `081` ownership and ordering.
- Preserve the accepted Phase 2 SQL and test boundary.

### Step 2 — Decision and Lease Structure

Implementation candidate:

```text
sql/schema/migrations/foundation/
081_postgresql_authorization_decision_and_lease_issuance.sql

test-framework/sql/tests/foundation/
130_authorization_decision_and_lease_structure.sql
```

Step 2 adds:

- Migration `081` after `080` and before `082`,
- Typed policy applicability for organization, Governed Scope, Protected
  Resource Target, classification, audience, and explicit selection priority,
- Exact policy-stage rule identity for later `NOT_REQUIRED` closure,
- Typed requested lease lifetime, use mode, usage limit, audience, and
  expected-policy input on Decision Records,
- Relational evaluation-to-policy-stage mapping,
- One issuing or renewing Decision Record to at most one Authorization Lease,
- Core lease context binding to the issuing Decision Record,
- Lease `not_before`, audience, expiration timestamp, chronology, terminal
  state, and revocation-reason constraints,
- Decision and evaluation linkage for lease Authority Grant evidence,
- Decision Record linkage for every lease use event,
- Structural regression coverage while preserving every accepted Phase 1 and
  Phase 2 test.

Step 2 does not implement policy selection, Decision Record finalization,
Authorization Lease issuance, or lease consumption behavior. Those controlled
functions remain Phase 3 Steps 3 and 4.

### Step 3 — Controlled Decision Finalization

Implementation candidate:

```text
sql/schema/migrations/foundation/
081_postgresql_authorization_decision_and_lease_issuance.sql

test-framework/sql/tests/foundation/
140_authorization_policy_selection_and_decision_finalization.sql
```

Step 3 adds deterministic policy resolution from persisted Decision Record
context, controlled policy binding, missing and ambiguous policy denial,
expected-policy mismatch denial, complete policy-stage closure, exact
`NOT_REQUIRED` rule validation, required supporting-evidence enforcement,
finalization-once behavior, and a compatibility wrapper that rejects
caller-supplied result mismatches.

Step 3 does not issue, verify, consume, renew, or revoke Authorization Leases.
Those behaviors remain Phase 3 Step 4.

### Step 4 — Controlled Lease Issuance and Verification

Implementation candidate:

```text
sql/schema/migrations/foundation/
081_postgresql_authorization_decision_and_lease_issuance.sql

test-framework/sql/tests/foundation/
150_authorization_lease_issuance_and_use.sql
```

Step 4 implements:

- Issuance only from a finalized eligible `ALLOW`,
- One issuing or renewing Decision Record per lease,
- Multiple separately attributable protected-operation Decision Records for a
  reusable lease without weakening issuing-decision uniqueness,
- Current selected-policy, required supporting-evidence, linked-authority,
  active-session, and locally owned trust revalidation,
- Policy-, request-, session-, evidence-, and authority-bounded lifetime,
- Exact identity, organization, session, device, service, purpose, operation,
  target, scope, classification, policy, audience, request, correlation, and
  protected-operation Decision Record binding,
- Secret hashing without plaintext persistence,
- Atomic reusable, single-use, and limited-use consumption,
- Same-transaction attributable use events,
- Materialized expiration and terminal reason-coded revocation,
- No production `SECURITY DEFINER` routine and no `PUBLIC` execution.

Step 4 does not yet add multi-connection lease issuance, consumption, or revocation races; those remain Step 6.

### Step 5 — Fail-Closed Sequential Behavioral Expansion

Implementation candidate:

```text
test-framework/sql/tests/foundation/
160_authorization_lease_fail_closed_behavior.sql
```

Step 5 proves that issuance and use fail closed when current session, identity,
device, Trust Provider, Platform Service, selected policy, required supporting
evidence, or required authority is no longer valid. Required authority must
remain linked to the issuing Decision Record through a current PASS evaluation
and required supporting record. A missing link or authority retargeted to a
different identity invalidates the lease.

Protected-operation consumption must also reject request, correlation, draft,
deny, and target mismatches without changing successful-use counters or
appending use events. Step 5 adds 24 assertions for a total target of:

```text
33 manifest migrations
33 registered migrations
16 sequential test files
4 concurrency test files
353 PASS assertions
0 FAIL assertions
3 understood WARN results
```

### Step 6 — Independent-Connection Concurrency Proofs

Step 6 adds five Bash-driven, independent-connection PostgreSQL races:

```text
test-framework/sql/tests/concurrency/
140_authorization_decision_finalization_race.sh
150_authorization_lease_issuance_race.sh
160_authorization_lease_single_use_race.sh
170_authorization_lease_limited_use_race.sh
180_authorization_lease_terminal_transition_race.sh
```

The proofs require:

- exactly one successful finalization of one draft Decision Record,
- exactly one lease issued from one eligible Decision Record,
- exactly one successful use of one single-use lease,
- exactly one winner for the final remaining limited-use slot,
- exactly one terminal expiration-or-revocation transition,
- no duplicate counters, use numbers, use events, terminal timestamps, or
  mixed terminal state,
- all accepted Phase 1 and Phase 2 concurrency proofs to remain passing.

The accepted Step 6 result is 33 migrations, 16 sequential tests,
9 concurrency tests, 408 PASS, 0 FAIL, and 3 understood WARN results.

### Step 7 — Acceptance

Step 7 is complete.

- Acceptance record: [phase-3-authorization-decision-and-controlled-lease-acceptance.md](phase-3-authorization-decision-and-controlled-lease-acceptance.md)
- Annotated release tag: `phase-3-authorization-control-complete-v1`
- Accepted tag target: `853d26e37f1471aeeaeea4e7690e1a0605a22870`
- Accepted result: 33 migrations, 16 sequential tests, 9 concurrency
  tests, 408 PASS, 0 FAIL, and 3 understood WARN results

## 21. Acceptance Gate

Phase 3 was accepted after all of the following conditions passed:

- The current Foundation manifest installs cleanly.
- Migration and registry counts agree.
- All accepted Phase 1 and Phase 2 tests pass.
- Policy selection is deterministic.
- Missing and ambiguous policy fail closed.
- Every required stage has one terminal result.
- Required `FAIL` and `NOT_EVALUATED` deny.
- `NOT_REQUIRED` requires an exact policy rule.
- Decision Records finalize once.
- A decision issues at most one lease.
- Only finalized `ALLOW` decisions issue leases.
- Lease context exactly matches the decision.
- Lease lifetime and usage are policy-bounded.
- Plaintext secrets are not stored.
- Runtime table-write paths are controlled.
- Independent-connection races prove finalization, issuance, consumption, and
  revocation behavior.
- The acceptance record documents remaining warnings and non-claims.
- The annotated acceptance tag identifies the exact accepted tree.

## 22. Revalidation Triggers

Phase 3 must be revalidated after any change to:

- Migrations `055`, `060`, `065`, `070`, `072`, `075`, `080`, or `081`
- Authority, policy, approval, session, decision, or lease structures
- Policy-selection precedence
- Decision-stage definitions
- Finalization rules
- Lease issuance, verification, consumption, expiration, or revocation
- Decision or lease privileges and ownership
- The Foundation manifests
- The Foundation test runner
- Phase 1, Phase 2, or Phase 3 regression tests
- This normative contract
- The Phase 3 acceptance record or tag

A passing historical result does not replace a fresh run after a relevant
change.

## 23. Related Documents

- [Authorization Evaluation Contract](authorization-evaluation-contract.md)
- [Authentication and Authorization Evaluation](authentication-and-authorization-evaluation-model.md)
- [Authority and Authorization](authority-and-authorization-model.md)
- [Approval Framework](approval-framework.md)
- [Authorization Lease](authorization-lease-model.md)
- [Decision Record Repository](decision-record-repository.md)
- [Session Establishment, Step-Up, and Lifecycle Model](session-establishment-step-up-and-lifecycle-model.md)
- [Phase 2 Session Establishment, Step-Up, and Lifecycle Acceptance](phase-2-session-establishment-step-up-and-lifecycle-acceptance.md)
- [Phase 3 Authorization Decision and Controlled Lease Acceptance](phase-3-authorization-decision-and-controlled-lease-acceptance.md)
- [SQL Migration Map](sql-migration-map.md)
