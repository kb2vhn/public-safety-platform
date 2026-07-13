# Foundation Approval and Protected CAD Operation Integration Model

> **Document status:** Normative CAD architecture
>
> **Foundation baseline:** Consumes the completed Phase 4 Step 7 implementation boundary
>
> **CAD implementation status:** Not implemented

## Purpose

Prevent CAD clients, workstation components, domain services, queued actions,
and supervisory workflows from weakening or duplicating the Platform
Foundation's approval and authorization contracts.

This model consumes the Phase 4 Step 7 boundary:

```text
34 Foundation manifest migrations
34 registered Foundation migrations
21 sequential Foundation test files
16 independent-connection Foundation concurrency test files
734 PASS
0 FAIL
3 understood WARN
Correctness: PASS
Resource observation: RECORDED
Performance thresholds: NOT_EVALUATED
```

These figures describe the Foundation Step 7 boundary. This CAD document does
not add to those counts and does not claim the formal Phase 4 acceptance and tag
reserved for the Foundation's later acceptance step.

## Foundation Ownership

The Platform Foundation is authoritative for:

- Approval Requests.
- Approval stages and policies.
- Approval Action Records.
- Current Approval Action derivation.
- Stage-evaluation records.
- One-time Approval Request finalization.
- Authority Grants and their current lifecycle state.
- Authorization Decisions.
- Authorization Leases.
- Decision Records.
- Applicable Decision Supporting Records.
- Approval independence and incompatible-duty enforcement.

CAD must not create a parallel table, cache, queue, or client-only workflow that
claims to replace any of those record types.

## State Separation

The following states are distinct and must remain distinguishable in APIs,
logs, tests, and user interfaces:

1. An Approval Request exists.
2. An eligible actor records an Approval Action Record.
3. The action remains current rather than withdrawn, corrected, superseded, or
   otherwise invalidated.
4. A stage evaluation determines whether the exact stage is satisfied, blocked,
   pending, expired, cancelled, or escalated.
5. The Approval Request is finalized once with one terminal result.
6. The Foundation evaluates exact current context and produces an Authorization
   Decision.
7. An Authorization Lease may be issued for a bounded later use.
8. The lease remains current and continuously valid for that later use.
9. The protected CAD operation commits through a controlled service and database
   boundary.
10. CAD operational timeline records, security audit records, and Foundation
    Decision Records correlate the result.

No UI label such as **approved**, **authorized**, **sent**, **accepted**, or
**committed** may collapse these states into one another.

## Approval Is Not Permission

An approval is a bounded policy input.

It is not:

- Authentication.
- A session.
- A role.
- An Authority Grant.
- An Authorization Decision.
- An Authorization Lease.
- General permission.
- A committed CAD action.

A displayed Approval Action or finalized `APPROVED` Approval Request must not be
represented as proof that the later CAD operation is currently allowed.

## Current-State Revalidation

At protected-operation commit, the authoritative service and PostgreSQL boundary
must revalidate all applicable current conditions, including:

- Exact identity, organization, service, Governed Scope, Governed Purpose,
  Governed Operation, and Protected Resource Target.
- Current session and required step-up.
- Current device and workstation assertions.
- Current policy version.
- Current Authority Grant and origin continuity.
- Exact Approval Request terminal state.
- Exact stage satisfaction.
- Current Approval Action continuity.
- Actor eligibility and independence.
- Withdrawal, correction, supersession, suspension, expiration, cancellation,
  and revocation.
- Authorization Lease scope, binding, expiration, and continuity when a lease is
  used.

A previous allow result, cached request status, local queue entry, or visible
button is insufficient.

## Phase 4 Step 7 Concurrency Contract

CAD callers must preserve the Foundation's deterministic behavior for:

- Duplicate effective-actor races.
- Duplicate Approval Action races.
- Concurrent stage evaluation and finalization.
- Concurrent Approval Request finalization.
- Last required approval racing finalization.
- Approval withdrawal racing finalization.
- Authority Grant revocation racing action recording or finalization.
- Reciprocal or shared-chain approval races.

The Foundation serializes the authoritative request chain and protects relevant
Authority Grant state. A serialization failure, deadlock, or retryable conflict
is a technical retry condition. It must not be transformed into a policy denial,
a successful approval, or a committed CAD action.

The client must preserve the operator's safe context and display a truthful
retry or conflict state.

## Queued and Degraded Operation

A CAD workstation may locally retain drafts, delivery intent, bounded reference
data, and explicitly permitted provisional operational records.

It must not locally:

- Create an authoritative Approval Action Record.
- Evaluate or finalize an Approval Request.
- Manufacture an Authorization Decision.
- Issue or extend an Authorization Lease.
- Reuse an expired, withdrawn, suspended, superseded, or revoked approval state.
- Mark a protected CAD action committed before authoritative acknowledgment.
- Replay a protected operation without fresh server-side validation.

A queued protected action must retain:

- Exact requested operation and target.
- Original actor, session, device, organization, service, purpose, and scope.
- Creation time and expiration.
- Idempotency key.
- Expected policy and contract version.
- Clear local state such as draft, locally recorded, queued, pending validation,
  conflicted, expired, rejected, or reconciled.

When connectivity returns, the authoritative service performs current-state
validation. The original cached result is supporting context, not authority.

## UI Vocabulary

CAD interfaces should use labels that identify the exact state, for example:

- `Approval action recorded`.
- `Approval action withdrawn`.
- `Approval stage satisfied`.
- `Approval request finalized: APPROVED`.
- `Authorization allowed`.
- `Authorization denied`.
- `Authorization retry required`.
- `Authorization lease current`.
- `CAD operation committed`.
- `Delivery queued`.
- `External delivery acknowledged`.

A generic label such as `Approved` is insufficient when more than one of these
states could apply.

## Domain Review Records

CAD may define domain-specific review, attestation, or supervisory-disposition
records when they describe CAD operational meaning.

Such records must:

- Use names that do not impersonate Foundation record types.
- State whether they are merely domain context or are linked to a Foundation
  Approval Request.
- Preserve actor, reason, time, scope, and lineage.
- Never grant authority by themselves.

## Test Requirements

Future CAD tests must prove:

- No protected CAD commit occurs from client-only approval state.
- A withdrawn or revoked approval path fails closed at later use.
- Authority Grant revocation invalidates the applicable operation path.
- Expired or mismatched Authorization Leases fail closed.
- Retryable serialization and deadlock results remain distinguishable from
  policy denial.
- Duplicate submission does not create duplicate Approval Action Records or CAD
  effects.
- Exactly one authoritative CAD effect commits when the domain operation requires
  single-winner behavior.
- UI and API states preserve every boundary listed in this model.
- Degraded queues cannot elevate local records into authoritative approval,
  authorization, or committed state.
