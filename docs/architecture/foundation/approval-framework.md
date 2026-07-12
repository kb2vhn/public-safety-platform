
# Approval Framework

> **Document status:** Normative Platform Foundation architecture.
>
> **Active implementation phase:** Phase 4 — Approval Independence and
> Separation of Duties.
>
> **Implementation status:** Migrations `050` and `055` provide the initial
> approval, authority, and incompatible-authority structures. Phase 4 Step 1
> freezes the stronger contract before migration `083` or new tests are added.

## Purpose

Provide reusable, attributable, policy-driven approval without embedding
domain-specific workflow in the Foundation.

An approval is one input to authorization. It is not a standalone capability.

## Core Objects

### Approval Policy Version

Defines applicable stages, required approval count, required authority,
independence dimensions, action validity, denial behavior, and finalization
rules.

### Approval Policy Stage

Defines one ordered approval requirement.

A stage may require:

- One or more distinct effective actors
- Exact Authority Definitions
- Distinct organizations
- Requester independence
- Directly affected identity independence
- Authority-origin independence
- Separation-of-duties checks
- Incompatible-authority checks

### Approval Request

Binds the requester, directly affected identity when applicable, organization,
session, service, purpose, operation, Protected Resource Target, Governed
Scope, Data Classification, policy version, correlation, approval chain, and
expiration.

### Approval Action Record

Persists one actor action such as approval, denial, abstention, withdrawal,
correction, or supersession.

Approval Action Records are append-only through the controlled write boundary.
Withdrawal, correction, and supersession create new records that reference the
prior record.

Append-only semantics apply to the Approval Action Record, not to an undefined evidence category.

### Approval Stage Evaluation

Persists the evaluated outcome of one required stage at one authoritative time.

A stage evaluation identifies the exact current Approval Action Records,
Authority Grants, independence checks, incompatible-authority checks, and
separation-of-duties checks used.

## Eligibility and Independence

Eligibility asks whether the actor may perform the approval action.

Independence asks whether that eligible actor may count for this request and
stage.

These are separate evaluations.

An eligible actor may still be prohibited because the actor is:

- The requester
- The directly affected identity
- A duplicate effective actor
- In a prohibited organization relationship
- Using non-independent authority lineage
- Part of an explicit reciprocal approval cycle
- Exercising an incompatible Authority Grant
- Exercising a prohibited duty combination

## Effective Actor

The initial effective actor is the acting Foundation identity.

Different accounts, sessions, devices, organizations, roles, or delegated
grants do not make one identity count as multiple independent approvers.

## Self-Approval

Self-approval is prohibited by default.

A policy may permit requester participation only for an exact low-risk stage.
Such participation must not silently satisfy a stage that requires an
independent actor.

Approval by the directly affected identity is separately evaluated and is
prohibited by default for privileged access, authority grants, exceptions,
risk acceptance, and security-sensitive changes.

## Duplicate Approval

Multiple actions by the same effective actor do not satisfy multiple
independent-approval requirements.

A raw count of `APPROVE` rows is never sufficient.

## Circular Approval

Circular or reciprocal approval is evaluated through explicit Approval Request
dependency and approval-chain relationships.

The Foundation does not infer a cycle from timing, organization membership, or
free-form descriptions.

## Authority Binding

A counted Approval Action Record must reference the exact current Authority
Grant used by the actor.

The grant must match the request and stage context and remain valid under the
applicable policy.

A free-form `authority_requirement` string is not sufficient after typed
Authority Definitions and Authority Grants exist.

## Separation of Duties

Policies may prohibit one effective actor from combining duties such as:

```text
REQUEST + APPROVE
APPROVE + EXECUTE
GRANT_AUTHORITY + APPROVE
ADMINISTER_POLICY + APPROVE
EXECUTE + AUDIT
AUTHORIZE_EXCEPTION + ACCEPT_RISK
```

The controlled path records duties actually exercised. Employment titles,
group memberships, and database roles do not by themselves prove duty
exercise.

## Incompatible Authority

Incompatible Authority Sets may prohibit joint exercise, concurrent holding,
or chain participation for their member Authority Definitions.

The applicable policy selects the enforcement mode and context.

## Finalization

An Approval Request may finalize as `APPROVED` only when every required stage
is current, eligible, applicable, independent, and satisfied at one captured
evaluation time.

Finalization is once-only.

A caller cannot select a final result that disagrees with database evaluation.

## Current Use

When a later Authorization Decision relies on an approved request, the
database revalidates the request, required stages, counted actions, required
Authority Grants, context, expiration, and applicable continuity rules.

Later invalidation does not rewrite a completed historical decision. It
prevents future reliance and may require an active lease or pending operation
to fail closed.

## Record-Type Discipline

Use exact terms:

- Approval Action Record
- Approval stage-evaluation record
- Decision Record
- Supporting Record
- Assurance Artifact
- Lifecycle event
- Module-owned evidence record

The unqualified term “evidence” is avoided when a specific record type is
known.

## SQL Implementation Mapping

Existing structures:

```text
050_approval_framework.sql
055_authority_purpose_and_authorization_policy.sql
```

Phase 4 Step 3 controlled boundary:

```text
083_postgresql_approval_independence_and_separation_of_duties.sql
```

Phase 4 Step 2 added the typed request, actor, Authority Grant, duty,
incompatible-authority, and stage-evaluation structure. Phase 4 Step 3 extends
migration `083` with `approval.record_approval_action`, exact current context
binding, typed prior-action lineage, and append-only mutation guards.

Test `180_controlled_approval_action_recording.sql` proves the controlled write
boundary. Independence, incompatible-authority, duty-conflict, stage-
satisfaction, and finalization behavior remain later steps.

## Validation Expectations

The Foundation SQL test framework must demonstrate database-enforceable
properties, including negative paths and independent-connection races.

Runtime, deployment, recovery, module-specific conflict providers, and user
interaction require separate validation.

## Governing Phase Contract

- [Approval Independence and Separation of Duties Model](approval-independence-and-separation-of-duties-model.md)

## Related Documents

- [Two-Person Concept](../../goals/two-person-concept.md)
- [Authority and Authorization](authority-and-authorization-model.md)
- [Authorization Evaluation Contract](authorization-evaluation-contract.md)
- [Decision Record Repository](decision-record-repository.md)
