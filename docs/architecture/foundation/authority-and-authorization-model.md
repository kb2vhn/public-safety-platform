
# Authority and Authorization Model

> **Document status:** Normative Platform Foundation architecture.
>
> **Active implementation phase:** Phase 4 — Approval Independence and
> Separation of Duties.
>
> **Implementation status:** Migration `055` provides the initial authority,
> purpose, operation, policy, and incompatible-authority structures. Phase 4
> Step 1 freezes stronger authority-use, delegation-lineage, and
> separation-of-duties requirements before implementation.

## Purpose

Distinguish durable, scoped sources of authority from individual approval
actions and time-bounded authorization decisions.

## Authority

Authority describes what an identity may approve or perform under a governing
policy.

Authority is bounded by applicable:

- Identity
- Organization
- Platform Service
- Governed Purpose
- Governed Operation
- Protected Resource Target
- Governed Scope
- Data Classification
- Effective period
- Delegation lineage
- Governing policy

An Authority Grant does not create a session, approval, Authorization Decision,
Authorization Lease, or permanent capability.

## Authority Definition

An Authority Definition identifies one governed kind of authority.

A stable authority key is not a grant. A current, applicable Authority Grant is
required before an actor may exercise that authority.

## Authority Grant

An Authority Grant binds one identity to one Authority Definition and its exact
context.

A grant may be:

```text
PENDING
ACTIVE
SUSPENDED
REVOKED
EXPIRED
SUPERSEDED
```

Only a current applicable grant may be exercised.

## Authority Exercise

Authority is exercised when a controlled operation records that the actor used
an exact Authority Grant for an exact duty and request context.

Holding a grant and exercising a grant are different facts.

Phase 4 uses this distinction when evaluating incompatible authority and
separation of duties.

## Delegation

Delegation is explicit, bounded, effective-dated, attributable, revocable, and
no broader than the delegator's current authority.

A delegated grant must retain:

- Parent Authority Grant
- Delegator identity
- Delegate identity
- Delegated Authority Definition
- Context bounds
- Effective period
- Delegation depth
- Governing policy
- Approval Request when required
- Revocation and supersession lineage

Multiple delegated grants do not make one identity multiple effective actors.

## Governed Purpose

Every protected request identifies a governed purpose when policy requires it.

Free-form purpose text may supplement but must not replace the authoritative
purpose definition.

## Governed Operation

Every material approval and authorization chain identifies one exact governed
operation definition.

Snapshot keys retained for historical readability must match the referenced
definition.

## Approval Authority

A counted Approval Action Record references the exact Authority Grant used.

A free-form stage authority description cannot prove current authority.

The grant must match the exact Approval Request and stage context.

## Incompatible Authority

An Incompatible Authority Set identifies Authority Definitions that cannot be
combined under a policy-selected enforcement mode:

```text
JOINT_EXERCISE
CONCURRENT_HOLDING
CHAIN_PARTICIPATION
```

### Joint Exercise

One effective actor may not exercise two member authorities in the same request
or authorization chain.

### Concurrent Holding

One effective actor may not hold two current applicable member grants in the
evaluated context.

### Chain Participation

One effective actor may not participate in prohibited chain positions through
different member authorities.

Grant accumulation across direct and delegated authority must not bypass these
rules.

## Separation of Duties

Authority to request, approve, grant authority, execute, finalize approval,
administer policy, audit, accept risk, and authorize exceptions is separated
where policy requires it.

Separation of duties evaluates duties actually exercised in the exact chain.

Role or group accumulation is an input to evaluation but is not a substitute
for recording duty exercise.

## Effective Actor

The initial effective actor is the acting Foundation identity.

Accounts, sessions, devices, organizations, roles, and grants are context for
that identity; they do not create independent actors.

## Authorization Policy

An Authorization Policy Version defines required trust, eligibility,
authority, approval, separation-of-duties, classification, scope, risk, and
lease conditions for one decision context.

Durable authority does not decide the operation by itself.

## Approval Independence

An actor can hold valid authority and still be disqualified from counting as
an approver because of:

- Self-approval
- Directly affected identity conflict
- Duplicate effective actor
- Organization-independence requirement
- Prohibited authority origin
- Explicit reciprocal approval cycle
- Incompatible Authority Grant
- Prohibited duty combination

## Authorization Decision

Authorization is one specific decision for one exact operation context.

The `AUTHORITY`, `APPROVAL`, and `SEPARATION_OF_DUTIES` stages are distinct.
Passing one stage does not imply that another passed.

## Failure Behavior

The operation fails closed when required authority or approval conditions are:

- Missing
- Ambiguous
- Expired
- Suspended
- Revoked
- Superseded
- Context-mismatched
- Delegated outside scope
- Incompatible
- Not independent
- Not evaluated

A normal policy denial is recorded as a decision result, not silently converted
to infrastructure failure.

## Record-Type Discipline

Use the exact object name when discussing retained history:

- Authority Grant
- Authority-exercise record
- Approval Action Record
- Approval stage-evaluation record
- Decision Record
- Supporting Record
- Assurance Artifact

The term “evidence” must be qualified when used.

## SQL Implementation Mapping

Existing principal mapping:

```text
055_authority_purpose_and_authorization_policy.sql
```

Phase 4 Step 3 controlled boundary:

```text
083_postgresql_approval_independence_and_separation_of_duties.sql
```

Migrations `080` and `081` record and consume authorization results.
Migration `083` adds typed approval-stage Authority Definition references,
Approval Action Record-to-Authority Grant linkage, incompatible-authority
modes, and stage-evaluation structure. Phase 4 Step 3 adds controlled current
Authority Grant validation for Approval Action recording. It verifies exact
identity, required authority, service, purpose, operation, organization,
Governed Scope, target, status, and effective time.

Incompatible-authority and delegated-authority accumulation remain later Phase
4 behavior and must preserve the accepted Step 3 boundary.

## Governing Phase Contract

- [Approval Independence and Separation of Duties Model](approval-independence-and-separation-of-duties-model.md)

## Related Documents

- [Approval Framework](approval-framework.md)
- [Authorization Evaluation Contract](authorization-evaluation-contract.md)
- [Authorization Lease](authorization-lease-model.md)
- [Authentication and Authorization Evaluation](authentication-and-authorization-evaluation-model.md)
