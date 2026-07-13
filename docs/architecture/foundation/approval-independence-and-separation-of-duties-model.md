
# Approval Independence and Separation of Duties Model

> **Layer:** Platform Foundation
>
> **Program:** Central Authorization Completion Program
>
> **Phase:** 4 — Approval Independence and Separation of Duties
>
> **Step:** 7 — Independent-Connection Concurrency Proof
>
> **Status:** Normative Phase 4 contract; Step 6 accepted and Step 7 concurrency candidate
>
> **Accepted prerequisite:** `phase-3-authorization-control-complete-v1`
>
> **Accepted prerequisite commit:** `853d26e37f1471aeeaeea4e7690e1a0605a22870`

## 1. Purpose

Define a domain-neutral, policy-driven approval boundary that proves who acted,
under which current authority, whether that actor was independent from the
request and other counted actors, whether prohibited duty or authority
combinations existed, and whether an Approval Request was validly finalized.

Phase 4 strengthens the initial structures created by migrations `050` and
`055`. It does not replace them and does not weaken any accepted Phase 1,
Phase 2, or Phase 3 invariant.

## 2. Primary Rule

An approval is a bounded policy input.

It is not an identity proof, session, role, Authority Grant, Authorization
Decision, Authorization Lease, or permission to perform a Protected Operation.

A request satisfies an approval stage only when the required number of current,
eligible, applicable, and independent Approval Action Records exist for that
exact request and stage at one authoritative evaluation time.

## 3. Scope

Phase 4 covers:

- Approval Policy Version and stage requirements
- Controlled Approval Request creation
- Typed requester and directly affected identity context
- Controlled Approval Action recording
- Exact acting identity, organization, session, and Authority Grant binding
- Effective-actor uniqueness
- Self-approval prevention
- Directly affected identity approval prevention
- Duplicate approval prevention
- Policy-driven organizational independence
- Explicit approval dependency and reciprocal-cycle checks
- Delegation-lineage checks
- Incompatible-authority evaluation
- Separation-of-duties rules
- Current stage satisfaction
- Finalization-once Approval Requests
- Withdrawal, correction, and supersession through new Approval Action Records
- Current approval continuity when an Authorization Decision relies on a request
- Decision Record linkage and stable reason codes
- Independent-connection concurrency proofs
- Database privilege and controlled-write boundaries

## 4. Non-Goals

Phase 4 does not claim to provide:

- Module-specific business workflow
- A universal requirement that every operation use two people
- Legal determinations about conflicts of interest
- Automated inference of family, financial, political, or social relationships
- Production human-resources data integration
- Production Go workflow services
- Final notification, escalation, or user-interface behavior
- Final production role ownership and login topology
- Decision Record cryptographic anchoring
- Migration-checksum enforcement
- Off-host integrity anchoring
- Break-glass operating procedures
- Production readiness

Module-specific conflicts may be supplied later through governed, typed
relationships. The Foundation must not infer them from free-form text.

## 5. Terminology

### 5.1 Approval Policy Version

A versioned policy row that defines which stages apply, how many approvals each
stage requires, which authority is required, which independence dimensions
apply, how long actions remain current, and how denials, withdrawals,
corrections, and finalization behave.

The existing `approval.approval_policies` row is treated as a versioned policy
record because it already carries `policy_key` and `version_number`.

### 5.2 Approval Policy Stage

One ordered requirement within an Approval Policy Version.

A stage has an exact key, minimum count, authority requirement, independence
rules, and finalization semantics. Stage order does not permit an earlier stage
to satisfy a later stage unless the exact policy explicitly allows action reuse.

Default behavior is one counted Approval Action Record per stage.

### 5.3 Approval Request

A persisted request for approval of one exact protected context.

An Approval Request is not itself approved merely because approval rows exist.
Its controlled finalization function determines whether every required stage is
satisfied at one captured evaluation time.

### 5.4 Approval Action Record

The persisted record of an actor's approval-related action.

Examples include:

```text
APPROVE
DENY
ABSTAIN
WITHDRAW_APPROVAL
CANCEL_REQUEST
ESCALATE
CORRECT
SUPERSEDE
```

Approval Action Records are append-only through the controlled database
boundary. An existing record is not edited to represent withdrawal, correction,
or supersession. A new record references the prior record and explains the new
action.

This document does not apply a broad append-only label to an undefined evidence concept.

### 5.5 Approval Event

The real-world or platform occurrence represented by an Approval Action Record.

The persisted database object is the Approval Action Record. The term
“Approval Event” may describe the occurrence but must not obscure the exact
record type.

### 5.6 Effective Actor

The unique Foundation identity whose authority is being exercised.

Multiple accounts, sessions, devices, organizations, roles, group memberships,
or delegated grants do not turn one identity into multiple effective actors.

For the initial Phase 4 database boundary:

```text
effective_actor_identity_id = acting_identity_id
```

A later service-principal model must define an equally explicit effective actor
identifier before automated actors can satisfy human-approval requirements.

### 5.7 Requester Identity

The identity that initiated the Approval Request.

The requester may differ from the identity directly affected by the requested
operation.

### 5.8 Directly Affected Identity

The identity whose authority, access, status, account, or protected standing is
directly changed or materially benefited by the requested operation when an
identity subject exists.

Phase 4 introduces an explicit nullable typed identifier for this context. A
Protected Resource Target string is not silently parsed to infer an identity.

### 5.9 Duty

A policy-defined function performed in one request, approval, authorization, or
execution chain.

Initial duty keys are:

```text
REQUEST
APPROVE
GRANT_AUTHORITY
EXECUTE
FINALIZE_APPROVAL
ADMINISTER_POLICY
AUDIT
ACCEPT_RISK
AUTHORIZE_EXCEPTION
```

A duty is not necessarily an employment title or database role.

### 5.10 Authority Grant

The exact current grant that makes an actor eligible to perform an approval
action for the request and stage context.

A free-form authority description does not satisfy this requirement after the
Authority Grant catalog exists.

### 5.11 Supporting Record

A typed record referenced by a decision or approval evaluation, such as an
Authority Grant, session, organizational attestation, eligibility record, or
approval-action record.

### 5.12 Assurance Artifact

Material used to demonstrate that a control was designed, implemented,
operated, tested, reviewed, or assessed.

Assurance Artifacts are governed by the assurance model and are not approval
actions.

### 5.13 Evidence Terminology

The unqualified term “evidence” is avoided in this contract because it can mean
supporting records, assurance artifacts, legal evidence, records-management
material, or module-owned evidence.

When the word is necessary, it must be qualified, for example:

```text
authorization supporting record
assurance artifact
legal evidence
module-owned evidence record
```

## 6. Canonical Approval Request Context

A material Approval Request carries explicit typed context:

```text
approval_request_id
approval_policy_id
requester_identity_id
requester_organization_id
requester_session_id
directly_affected_identity_id
service_id
purpose_definition_id
operation_definition_id
operation_key
protected_target_type
protected_target_reference
governed_scope_id
classification_key
correlation_id
approval_chain_id
requested_at
expires_at
status
finalized_at
finalized_by_identity_id
final_reason_code
```

A field may be null only when the exact policy and request class permit it.

The operation identifier and snapshot key must refer to the same governed
operation definition.

## 7. Approval Policy Contract

An Approval Policy Version must define:

- Effective period
- Status
- Applicable request class
- Applicable service, purpose, operation, target type, scope, and
  classification conditions
- Required stages
- Minimum approvals per stage
- Required Authority Definition or typed authority rule per stage
- Whether requester approval is prohibited
- Whether directly affected identity approval is prohibited
- Whether distinct effective actors are required
- Whether distinct organizations are required
- Whether one action may satisfy more than one stage
- Whether delegated authority is allowed
- Maximum delegation depth when delegation is allowed
- Action validity duration
- Denial effect
- Withdrawal rules
- Correction and supersession rules
- Finalization rules
- Approval continuity requirements for later Authorization Decisions
- Governing document and version

Missing or ambiguous applicable policy denies controlled processing.

## 8. Actor Eligibility

Eligibility and independence are separate evaluations.

An actor is eligible for a stage only when all applicable conditions pass at
the captured evaluation time:

- Identity is current and active
- Session is current and usable when required
- Device and Trust Provider state are current when required
- Acting organization is current and permitted
- Platform Service participation is current when required
- Exact Authority Grant exists
- Authority Grant matches identity, organization, service, purpose, operation,
  target, Governed Scope, and effective time
- Delegated authority is allowed and its lineage remains current
- Approval request is pending, unexpired, and context-matched
- Approval Policy Version and stage are active and applicable

An eligible actor may still fail independence or separation-of-duties checks.

## 9. Controlled Approval Action Recording

Runtime identities must not insert directly into
`approval.approval_actions`.

A controlled database function records an Approval Action Record only after
validating:

- Exact request and stage
- Current request status
- Current policy and stage
- Acting identity
- Acting organization
- Acting session when required
- Exact Authority Grant
- Action type permitted for the stage and request state
- Independence rules
- Incompatible-authority rules
- Separation-of-duties rules
- Authoritative time
- Correlation and approval-chain context
- Prior action linkage for withdrawal, correction, or supersession

The function returns a typed outcome and stable reason code. A normal policy
denial does not create a successful approval action.

## 10. Independence Rules

### 10.1 Self-Approval

Self-approval is denied when the acting identity equals the requester identity
and the policy does not explicitly permit that exact stage behavior.

The default is prohibited.

### 10.2 Directly Affected Identity Approval

An actor cannot approve a request that directly grants, expands, restores, or
otherwise materially benefits that same identity when the policy prohibits
affected-identity approval.

The default for privileged access, authority grants, exceptions, risk
acceptance, and security-sensitive changes is prohibited.

### 10.3 Duplicate Effective Actor

Multiple Approval Action Records from the same effective actor do not satisfy
multiple independent-approval requirements.

Different sessions, devices, accounts, organizations, or Authority Grants do
not make the same identity distinct.

### 10.4 Distinct Organization

When policy requires organizational independence, counted approval actions
must use distinct eligible acting organizations and must satisfy any
requester-organization or affected-organization exclusion rule.

Distinct organization never substitutes for distinct effective identity.

### 10.5 Authority-Origin Independence

When policy requires authority-origin independence, a counted approver may not
rely on an Authority Grant created, approved, or delegated through a prohibited
participant in the same request chain.

The rule operates on explicit persisted lineage, not inferred relationships.

### 10.6 Circular and Reciprocal Approval

Circular approval is evaluated only through explicit persisted Approval Request
dependencies and approval-chain relationships.

The initial prohibited pattern is:

- Identity A is requester or directly affected identity for Request A.
- Identity B records a counted approval for Request A.
- Identity B is requester or directly affected identity for linked Request B.
- Identity A records a counted approval for Request B.
- The applicable policy prohibits reciprocal participation.

The database must not use an unbounded historical search or time-only heuristic.
No cycle is inferred without explicit request linkage.

## 11. Separation of Duties

Separation of duties evaluates duties exercised in the exact request,
approval-chain, authorization-decision, and protected-operation context.

Policy may prohibit combinations such as:

```text
REQUEST + APPROVE
APPROVE + EXECUTE
GRANT_AUTHORITY + APPROVE
ADMINISTER_POLICY + APPROVE
ADMINISTER_POLICY + ACCEPT_RISK
EXECUTE + AUDIT
AUTHORIZE_EXCEPTION + ACCEPT_RISK
```

A prohibited combination denies the affected stage or finalization.

Holding a job title, group membership, or database role does not by itself
prove that a duty was exercised. The controlled path records the duty actually
performed.

## 12. Incompatible Authority

An Incompatible Authority Set defines Authority Definitions that cannot be
combined under a configured enforcement mode.

Initial modes are:

```text
JOINT_EXERCISE
CONCURRENT_HOLDING
CHAIN_PARTICIPATION
```

### JOINT_EXERCISE

One effective actor may not exercise two member authorities in the same request
or authorization chain.

### CONCURRENT_HOLDING

One effective actor may not hold two current applicable member Authority Grants
in the evaluated context.

### CHAIN_PARTICIPATION

One effective actor may not participate in prohibited chain positions using
different member authorities.

The exact policy selects the mode. Merely belonging to one set does not create
a universal platform-wide denial.

Authority conflicts are evaluated across direct grants and explicit delegation
lineage. Grant accumulation must not bypass the rule.

## 13. Stage Satisfaction

A stage is satisfied only when:

1. The request and policy are current.
2. The stage is required and applicable.
3. The required Authority Definition or typed authority rule is resolved.
4. At least `minimum_approvals` current `APPROVE` actions exist.
5. Every counted action is eligible and context-matched.
6. Every counted action remains current after withdrawal, correction, and
   supersession processing.
7. Counted actions use the required number of distinct effective actors.
8. Organization-independence requirements pass.
9. Self-approval and directly affected identity rules pass.
10. Circular and reciprocal approval rules pass.
11. Incompatible-authority checks pass.
12. Separation-of-duties checks pass.
13. No blocking `DENY` action applies under the policy.
14. No required condition is `NOT_EVALUATED`.

A query that merely counts `APPROVE` rows is not a valid stage evaluation.

## 14. Approval Request Finalization

An Approval Request begins in `PENDING`.

Controlled terminal states are:

```text
APPROVED
DENIED
CANCELLED
EXPIRED
ESCALATED
```

A controlled finalization function:

- Locks the request
- Captures one authoritative evaluation time
- Resolves the exact Approval Policy Version
- Evaluates every required stage
- Persists stage outcomes and stable reason codes
- Rejects caller-supplied final-result mismatches
- Writes one final status and timestamp
- Prevents later re-finalization

A request cannot finalize as `APPROVED` when a required stage is unsatisfied,
failed, or not evaluated.

## 15. Withdrawal, Correction, and Supersession

An existing Approval Action Record is not updated or deleted to change meaning.

### Withdrawal

`WITHDRAW_APPROVAL` references the exact prior `APPROVE` action. The policy
determines who may withdraw and until which request state.

### Correction

`CORRECT` references the prior action and supplies an attributable reason. It
does not erase the original action.

### Supersession

`SUPERSEDE` identifies the prior action and the replacement action or
replacement context.

Current stage evaluation derives the effective action set from the complete
action lineage.

## 16. Current Validity and Later Authorization Use

At Approval Request finalization, every counted action and Authority Grant must
be current at the same captured time.

When an Authorization Decision later relies on an approved request, the
database must revalidate:

- Approval Request final status
- Exact request, policy, service, purpose, operation, target, scope,
  classification, and correlation context
- Required stage satisfaction
- Required action continuity
- Required Authority Grant continuity
- Request expiration
- Withdrawal, correction, supersession, suspension, or revocation state

The applicable Approval Policy Version determines which supporting records must
remain current after finalization.

A later invalidation does not rewrite a completed historical decision. It
prevents future reliance and may require revocation of an active lease or
pending operation.

## 17. Decision Record Integration

The `APPROVAL` and `SEPARATION_OF_DUTIES` Decision Record stages must reference
the exact Approval Request and the exact stage-evaluation records used.

A final `ALLOW` cannot rely solely on:

- Approval Request status text
- A raw count of approval actions
- A free-form authority description
- Caller-provided independence claims
- Caller-provided separation-of-duties results

The controlled database path independently verifies the minimum conditions it
owns.

## 18. Time Contract

One approval evaluation captures:

```sql
v_evaluated_at := statement_timestamp();
```

Every validity comparison in that evaluation uses the same captured time.

Effective periods are half-open:

```text
valid_from <= evaluated_at
evaluated_at < valid_until
```

A null `valid_until` means no configured end time, not unconditional validity.

## 19. Stable Reason Codes

Initial Phase 4 reason codes include:

```text
APPROVAL_REQUIRED
APPROVAL_REQUEST_NOT_FOUND
APPROVAL_REQUEST_NOT_PENDING
APPROVAL_REQUEST_EXPIRED
APPROVAL_REQUEST_FINALIZED
APPROVAL_POLICY_NOT_ACTIVE
APPROVAL_POLICY_AMBIGUOUS
APPROVAL_STAGE_NOT_FOUND
APPROVAL_STAGE_UNSATISFIED
APPROVER_NOT_ELIGIBLE
APPROVER_SESSION_REQUIRED
APPROVER_AUTHORITY_REQUIRED
APPROVER_AUTHORITY_NOT_CURRENT
APPROVAL_CONTEXT_MISMATCH
SELF_APPROVAL_PROHIBITED
AFFECTED_IDENTITY_APPROVAL_PROHIBITED
DUPLICATE_EFFECTIVE_ACTOR
INDEPENDENT_IDENTITY_REQUIRED
INDEPENDENT_ORGANIZATION_REQUIRED
AUTHORITY_ORIGIN_NOT_INDEPENDENT
CIRCULAR_APPROVAL_PROHIBITED
INCOMPATIBLE_AUTHORITY
SEPARATION_OF_DUTIES_CONFLICT
APPROVAL_ACTION_NOT_CURRENT
APPROVAL_WITHDRAWAL_NOT_ALLOWED
APPROVAL_CORRECTION_NOT_ALLOWED
APPROVAL_FINAL_RESULT_MISMATCH
```

Codes use:

```text
^[A-Z][A-Z0-9_]*$
```

## 20. Database Security Boundary

Phase 4 controlled routines must:

- Use typed parameters for authorization-critical context
- Use fixed trusted `search_path` settings
- Revoke execution from `PUBLIC`
- Avoid unrestricted direct runtime writes
- Avoid caller-selected final results
- Avoid caller-selected actor or authority substitution
- Preserve the accepted Phase 3 no-plaintext-secret boundary
- Avoid `SECURITY DEFINER` unless no sound alternative exists and a separate
  ownership and privilege review proves it necessary

The initial implementation should continue using invoker-rights routines with
explicit deployment grants where practical.

## 21. Concurrency Contract

Independent-connection tests must prove at least:

- Two simultaneous approvals by the same effective actor cannot count twice.
- Two workers cannot create duplicate effective approval actions for one actor
  and stage.
- Exactly one finalization transition closes a pending Approval Request.
- Finalization racing the last required approval cannot produce an approved
  request with an unsatisfied stage.
- Withdrawal racing finalization produces one valid serializable outcome.
- Authority revocation racing finalization cannot produce an approved request
  that relies on a non-current Authority Grant.
- Reciprocal linked approvals cannot both satisfy a prohibited cycle.
- Serialization or deadlock failures are system retry conditions, not policy
  denials.

## 22. Record and Terminology Discipline

The following record types have distinct meanings:

- Approval Action Record — actor action
- Approval Request stage-evaluation record — computed stage outcome
- Decision Record — authorization result and explanation
- Supporting Record — typed input referenced by an evaluation
- Assurance Artifact — control-assurance material
- Lifecycle event — state transition history
- Module-owned evidence record — domain-specific record outside the Foundation

Documentation, SQL comments, test names, and telemetry must use the exact term
that matches the object.

## 23. Planned SQL Mapping

Phase 4 Step 1 changes no production SQL.

The planned implementation migration is:

```text
083_postgresql_approval_independence_and_separation_of_duties.sql
```

It will be ordered after:

```text
082_data_classification_and_governance.sql
```

and before:

```text
084_lifecycle_and_historical_lineage.sql
```

The migration must extend the existing `approval` and `access_control`
structures rather than creating a parallel approval system.

Expected structural capabilities include:

- Typed directly affected identity context
- Approval-chain and request-dependency linkage
- Typed stage Authority Definition requirements
- Exact Approval Action to Authority Grant linkage
- Acting session and organization linkage
- Action lineage for withdrawal, correction, and supersession
- Policy-driven independence rules
- Policy-driven duty-combination rules
- Incompatible-authority enforcement modes
- Persisted stage-evaluation records
- Finalization fields and uniqueness constraints
- Controlled write and finalization routines
- Indexes supporting exact current-context evaluation

Step 2 froze the structural table, column, constraint, and index names.
Step 3 freezes the first controlled routine and action-lineage behavior before
independence enforcement.

## 24. Test Mapping

Step 1 adds no SQL test.

Planned sequential test progression begins after the accepted Phase 3 file:

```text
test-framework/sql/tests/foundation/
160_authorization_lease_fail_closed_behavior.sql
```

The first planned Phase 4 structural test is:

```text
170_approval_independence_and_separation_of_duties_structure.sql
```

Later behavioral tests will cover controlled action recording, actor
eligibility, independence, incompatible authority, separation of duties,
finalization, withdrawal, correction, supersession, and current-use
revalidation.

Concurrency tests will be added only after the sequential state model passes.

## 25. Phase 4 Steps

### Step 1 — Contract Freeze

- Normative Phase 4 model
- Terminology discipline
- Existing-schema extension plan
- No SQL, manifest, or test changes
- Full accepted Phase 3 regression remains green

### Step 2 — Structural Extension

Step 2 adds:

- Migration `083_postgresql_approval_independence_and_separation_of_duties.sql`
- Structural test
  `170_approval_independence_and_separation_of_duties_structure.sql`
- Typed directly affected identity and approval-chain context
- Typed Approval Request dependencies
- Generated effective-actor identity
- Acting-session, Authority Grant, and prior-action linkage
- Initial governed duty catalog
- Policy-prohibited duty combinations
- Incompatible-authority enforcement modes
- Persisted stage-evaluation and counted-action linkage
- Database privilege and index checks
- Observation-only resource telemetry around the unchanged correctness runner

Step 2 does not yet add controlled Approval Action recording, behavioral
independence enforcement, stage satisfaction, or Approval Request finalization.
Resource observations are separate from functional assertions and enforce no
performance budget.

### Step 3 — Controlled Approval Actions

Step 3 adds:

- `approval.record_approval_action`
- Exact current Approval Request and policy-stage validation
- Effective actor, acting organization, acting session, and Authority Grant
  binding
- Identity, session, service, purpose, operation, organization, Governed Scope,
  target, status, and effective-time checks
- Typed `RECORDED` result and stable reason code
- Typed prior-action lineage for withdrawal, correction, and supersession
- Append-only UPDATE and DELETE guards for Approval Action Records and typed
  duty links
- Behavioral test `180_controlled_approval_action_recording.sql`
- Continued observation-only resource telemetry

Step 3 does not add independence, incompatible-authority, duty-conflict, stage-
satisfaction, or Approval Request finalization enforcement. Those boundaries
remain explicit so Step 4 can add independence without claiming later steps.

### Step 4 — Independence Enforcement

Step 4 extends `approval.record_approval_action` and adds behavioral test
`190_approval_independence_enforcement.sql` for:

- Self-approval, denied unless policy and exact stage both permit it
- Directly affected identity approval, denied unless exact stage permits it
- Duplicate current approval by the same effective actor
- Distinct acting organizations when required by stage policy
- Authority-origin independence using persisted Authority Grant and Approval
  Request lineage
- Explicit circular and reciprocal approval using typed dependencies and
  approval-chain identifiers
- Withdrawal-aware current-approval derivation

Step 4 does not infer identity independence from sessions, devices, accounts,
organizations, or grants. It does not infer reciprocal relationships from time
proximity or free-form text.

### Step 5 — Incompatible Authority and Separation of Duties

Step 5 preserves every accepted Step 4 independence rule and adds:

- Explicit direct and delegated Authority Grant lineage
- Stage-controlled delegated-authority permission and maximum depth
- `JOINT_EXERCISE`, preventing one effective actor from exercising two member
  authorities in one Approval Request or explicit approval chain
- `CONCURRENT_HOLDING`, preventing one actor from holding two current applicable
  member grants when the set policy requires it
- `CHAIN_PARTICIPATION`, preventing prohibited member-authority participation
  across explicitly related requests or a shared approval-chain identifier
- Policy-controlled inclusion or exclusion of delegated grants
- Immutable `APPROVE` duty links for successful approval actions
- Prohibited-duty evaluation for exact evaluable stage, request, and approval-
  chain scope
- Fail-closed `DUTY_SCOPE_NOT_EVALUATED` when an authorization-chain scope is
  configured before that chain is represented by authoritative data

No conflict is inferred from job titles, group names, role names, time
proximity, or free-form descriptions. Rejected attempts create no successful
Approval Action Record or duty link.

### Step 6 — Stage Satisfaction and Finalization

- Current effective action derivation
- Stage evaluation
- Finalization once
- Denial persistence
- Decision Record integration
- Later-use continuity

### Step 7 — Independent-Connection Concurrency Proof

- Duplicate effective-actor approval race
- Finalized stage-evaluation race
- Approval Request finalization race
- Last approval versus finalization race
- Withdrawal versus finalization race
- Authority Grant revocation versus approval recording race
- Reciprocal approval race across explicit request linkage

The six normative race families use seven test files because finalization is
proved independently at both the stage-evaluation and Approval Request
boundaries.

### Step 8 — Formal Acceptance

- Clean manifest installation
- Complete sequential and concurrency suite
- Zero failed assertions
- Formal Phase 4 acceptance record
- Annotated Phase 4 release tag

## 26. Step 1 Acceptance Criteria

Phase 4 Step 1 passes only when:

1. The accepted Phase 3 annotated tag remains identifiable.
2. The current branch descends from the accepted Phase 3 commit.
3. `sql/schema` is identical to the accepted Phase 3 tag.
4. `test-framework/sql` is identical to the accepted Phase 3 tag.
5. The formal Phase 3 acceptance record is unchanged.
6. This contract exists and is indexed.
7. Approval Action Record terminology is defined.
8. Active Phase 4 documentation does not apply append-only semantics to an
   undefined evidence concept.
9. Eligibility and independence are separate requirements.
10. Requester and directly affected identity are distinct typed concepts.
11. Effective actor uniqueness is defined.
12. Self-approval and duplicate approval default to fail closed.
13. Circular approval uses explicit request linkage.
14. Incompatible-authority enforcement modes are defined.
15. Separation-of-duties duties and prohibited combinations are defined.
16. Stage satisfaction requires more than row counting.
17. Approval Request finalization is once-only.
18. Withdrawal, correction, and supersession create new Approval Action
    Records.
19. The planned migration and test order are documented.
20. The complete accepted Phase 3 suite remains at 408 PASS, 0 FAIL, and the
    same 3 understood WARN results.

## 27. Step 2 Acceptance Criteria

Step 2 is complete only when:

- The manifest contains 34 ordered migrations.
- Migration `083` installs into an empty database.
- The structural test manifest contains 17 tests.
- Test `170` contributes exactly 37 functional assertions.
- The accepted nine concurrency tests still pass unchanged.
- The complete correctness result is 445 PASS, 0 FAIL, and the same three
  understood WARN results.
- The resource-aware wrapper produces text and JSON reports for the same run.
- Correctness is `PASS`.
- Resource observation is `RECORDED`.
- Performance thresholds are `NOT_EVALUATED`.
- Resource fields are present, well-formed, and observation-only.
- No controlled Approval Action behavior is claimed by structural presence.
- The accepted Phase 3 tag and formal acceptance record remain unchanged.


## 28. Step 3 Acceptance Criteria

Step 3 is complete only when:

- The manifest remains at 34 ordered migrations.
- Migration `083` installs into an empty database with the controlled function
  and append-only mutation guards.
- The sequential manifest contains 18 tests.
- Test `180` contributes exactly 55 functional assertions.
- Exact request, policy, stage, actor, organization, session, and Authority
  Grant binding passes.
- Missing, stale, mismatched, or substituted context fails closed without
  creating a successful Approval Action Record.
- Withdrawal, correction, and supersession require exact typed prior-action
  lineage.
- Existing Approval Action Records reject UPDATE and DELETE.
- No Step 4 through Step 6 behavior is claimed by Step 3.
- The accepted nine concurrency tests remain unchanged.
- The complete correctness result is 500 PASS, 0 FAIL, and the same three
  understood WARN results.
- Resource observation is `RECORDED` and thresholds remain `NOT_EVALUATED`.
- The accepted Phase 3 tag and formal acceptance record remain unchanged.


## 29. Step 4 Acceptance Criteria

Step 4 is complete only when:

- The manifest remains at 34 ordered migrations.
- The sequential manifest contains 19 tests.
- Test `190` contributes exactly 40 functional assertions.
- Requester self-approval fails closed unless policy and exact stage both allow it.
- Directly affected identity approval fails closed unless the exact stage allows it.
- Multiple sessions, organizations, or Authority Grants do not make one
  effective actor distinct.
- A withdrawn approval no longer blocks a legitimate replacement approval.
- Required organization independence rejects a second current approval from
  the same organization and accepts a distinct eligible organization.
- Missing or prohibited Authority Grant origin lineage fails closed.
- Circular or reciprocal denial uses explicit request linkage or a shared
  approval-chain identifier and never a time-only heuristic.
- Rejected independence attempts create no successful Approval Action Record.
- The accepted nine concurrency tests remain unchanged.
- The complete candidate result is 540 PASS, 0 FAIL, and the same three
  understood WARN results.
- Resource observation is `RECORDED` and thresholds remain `NOT_EVALUATED`.
- Root, architecture, test, validation, and phase-status documentation are
  synchronized before acceptance.
- No Step 5 through Step 7 behavior is claimed by Step 4.

## 30. Step 5 Acceptance Criteria

Step 5 is complete only when:

- The manifest remains at 34 ordered migrations.
- The sequential manifest contains 20 tests.
- Test `200` contributes exactly 50 functional assertions.
- Direct grants remain usable under the exact accepted Step 4 boundary.
- Delegated grants require an explicit valid parent chain, stage permission,
  and a depth not exceeding the stage maximum.
- `JOINT_EXERCISE`, `CONCURRENT_HOLDING`, and `CHAIN_PARTICIPATION` each fail
  closed under their exact configured scope.
- Suspended grants, inactive sets, and malformed set membership do not satisfy
  an incompatible-authority policy.
- Successful `APPROVE` actions receive exactly one immutable `APPROVE` duty.
- Non-`APPROVE` controlled actions do not receive an automatic approval duty.
- Configured prohibited combinations involving `REQUEST`, `GRANT_AUTHORITY`,
  and recorded duties such as `EXECUTE` fail closed.
- An unavailable configured duty scope returns `DUTY_SCOPE_NOT_EVALUATED`.
- Rejected Step 5 attempts create no successful Approval Action Record or duty.
- The accepted nine concurrency tests remain unchanged.
- The complete candidate result is 590 PASS, 0 FAIL, and the same three
  understood WARN results.
- Resource observation is `RECORDED` and thresholds remain `NOT_EVALUATED`.
- Root, architecture, test, validation, and phase-status documentation are
  synchronized before acceptance.
- No Step 6 or Step 7 behavior is claimed by Step 5.

## Phase 4 Step 6 Accepted Implementation Boundary

The Step 5 enforcement boundary remains accepted. Phase 4 Step 6 is accepted
for current-action derivation, persisted stage satisfaction, finalization-once
Approval Requests, exact Decision Record stage linkage, and later-use
continuity for approval-backed Authorization Leases.

## 31. Step 6 Acceptance Criteria

Step 6 is accepted with:

- 34 ordered Foundation migrations.
- 21 sequential tests.
- Test `210` contributing exactly 60 functional assertions.
- Current-action derivation excluding withdrawn, corrected, superseded, stale,
  and otherwise inapplicable Approval Action Records.
- One authoritative PostgreSQL evaluation time for each persisted stage result.
- Stage satisfaction based on current policy, distinct effective actors,
  organization independence, exact Authority Grants, incompatible authority,
  prohibited duties, and blocking denials.
- Controlled finalization that locks one PENDING Approval Request, evaluates
  every policy stage, rejects caller-result mismatch, writes one terminal
  status, and prevents re-finalization.
- Exact Decision Record links to finalized SATISFIED stage evaluations.
- Fail-closed approval continuity for approval-backed Authorization Leases.
- Preservation of approval-unrelated Decision Records and leases.
- 650 PASS, 0 FAIL, and the same three understood WARN results.
- Correctness `PASS`, resource observation `RECORDED`, and performance
  thresholds `NOT_EVALUATED`.

## Phase 4 Step 7 Candidate Implementation Boundary

Step 7 preserves every accepted Step 6 invariant and adds only the
serialization and independent-connection proofs needed to close simultaneous
approval-state transitions.

The database acquires transaction advisory locks in stable UUID order for the
current Approval Request, every request in its explicit chain, and directly
linked reciprocal or shared-chain requests. This closes cross-request
check-then-insert races without one global approval lock.

The exact Authority Grant read used by controlled Approval Action recording is
protected with a row-level `FOR SHARE` lock so concurrent revocation or
suspension has one valid serial order.

## 32. Step 7 Acceptance Criteria

Step 7 is complete only when:

- The Foundation manifest remains at 34 ordered migrations.
- The sequential manifest remains at 21 tests.
- The concurrency manifest contains 16 tests.
- The accepted Step 6 test remains at exactly 60 assertions.
- Seven new independent-connection files contribute exactly 12 assertions
  each, for 84 new assertions.
- Duplicate effective-actor races permit exactly one successful current
  approval.
- Concurrent finalized stage evaluations persist exactly one finalized result.
- Concurrent Approval Request finalization succeeds exactly once.
- Last approval versus finalization produces only a valid serial outcome.
- Withdrawal versus finalization produces only a valid serial outcome.
- Authority Grant revocation versus approval recording produces only a valid
  serial outcome, and a revoked grant contributes no later counted approval.
- Reciprocal approvals across explicitly linked requests permit at most one
  successful side.
- Request-chain locks are acquired in stable UUID order and are limited to the
  current request, its explicit chain, and directly linked reciprocal or
  shared-chain requests.
- The controlled Authority Grant read excludes concurrent status mutation.
- The complete candidate result is 734 PASS, 0 FAIL, and the same three
  understood WARN results.
- Correctness is `PASS`.
- Resource observation is `RECORDED`.
- Performance thresholds remain `NOT_EVALUATED`.
- Root, architecture, test, validation, phase-gate, and module-boundary
  documentation are synchronized.
- No module-specific record or workflow is moved into the Platform Foundation.
- Formal Phase 4 acceptance and the annotated release tag remain Step 8 work.

## 33. Revalidation Triggers


Phase 4 must be revalidated after any change to:

- Approval Policy Version or stage structure
- Approval Request context or lifecycle
- Approval Action Record structure or action types
- Effective actor definition
- Directly affected identity semantics
- Authority Grant applicability or delegation lineage
- Incompatible Authority Sets
- Separation-of-duties duties or rules
- Approval stage satisfaction
- Approval Request finalization
- Withdrawal, correction, or supersession semantics
- Decision Record approval or separation-of-duties stages
- Authorization Decision or lease reliance on approvals
- Migrations `050`, `055`, `080`, `081`, or planned `083`
- Foundation test manifests
- Approval-related concurrency barriers
- The accepted Phase 3 tag or acceptance record
- This normative contract

## 34. Related Documents

- [Approval Framework](approval-framework.md)
- [Authority and Authorization Model](authority-and-authorization-model.md)
- [Authorization Evaluation Contract](authorization-evaluation-contract.md)
- [Authorization Decision and Lease Issuance Model](authorization-decision-and-lease-issuance-model.md)
- [Decision Record Repository](decision-record-repository.md)
- [Lifecycle Versioning and Historical Lineage](lifecycle-versioning-and-historical-lineage-model.md)
- [Two-Person Concept](../../goals/two-person-concept.md)
- [Phase 3 Authorization Decision and Controlled Lease Acceptance](phase-3-authorization-decision-and-controlled-lease-acceptance.md)
