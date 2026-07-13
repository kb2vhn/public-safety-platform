# Degraded Operations, Continuity, and Reconciliation Model

> **Document status:** Normative CAD architecture
>
> **Implementation status:** Not implemented

## Architecture Ownership

This document is authoritative for CAD degraded authority, canonical state,
queue meaning, conflict handling, reconciliation, and recovery acceptance.

Human-facing presentation is governed by the
[CAD User-Interface Architecture](user-interface/README.md). Local cache, spool,
component restart, and workstation restoration are governed by the
[CAD Operational Workstation Architecture](operational-workstation/README.md).

A locally displayed or locally persisted action does not become canonical merely
because the workstation accepted it.

## Purpose

Define explicit CAD behavior when dependencies are slow, unavailable,
partitioned, inconsistent, or recovering.

## Degraded Operation Is a Normal Design Condition

CAD must be designed for failures involving:

- Database connectivity.
- Site connectivity.
- Identity provider.
- Authorization dependency.
- Mapping.
- Geocoding.
- Routing.
- Telephony.
- Text-to-911.
- Radio integration.
- Paging.
- Station alerting.
- Unit messaging.
- AVL.
- State or federal query systems.
- External notification.
- Time synchronization.
- Storage.
- Logging or telemetry delivery.

A dependency failure must not silently make the entire CAD state untrustworthy.

## Operator-Visible Degradation

The interface must communicate:

- Which capability is affected.
- Start time.
- Last successful operation.
- Which data may be stale.
- Which actions remain available.
- Which actions are blocked.
- Which actions are queued.
- Which actions failed.
- Whether retry is safe.
- Current fallback procedure.
- How recovery will be recognized.

## Authoritative State

For each degraded workflow, architecture must define:

- Authoritative system during normal operation.
- Authoritative system during degradation.
- Allowed local records.
- Temporary identifiers.
- Queue and retry behavior.
- Maximum offline authority.
- Conflict rules.
- Reconciliation ownership.
- Required supervisory review.
- Recovery and acceptance criteria.

## Local and Queued Actions

An action performed during degradation must be labeled as:

- Locally recorded.
- Queued for delivery.
- Pending central authorization.
- Provisional local record awaiting authoritative validation.
- Rejected.
- Conflicted.
- Reconciled.

The user must not be shown a normal committed state when only a local or queued
state exists.

## Reconciliation

Reconciliation must be deterministic, reviewable, and non-destructive.

It should retain:

- Local action.
- Central state.
- Conflict type.
- Ordering and clock context.
- Actor.
- Session or degraded authority context.
- Proposed disposition.
- Approved disposition when required.
- Resulting canonical state.
- Correction or supersession records.
- Unresolved follow-up.

Conflicts must not be resolved by silently keeping the last received write.

## Duplicate and Replay Behavior

Recovery often causes duplicate delivery.

All externally delivered or replayable actions require idempotency and duplicate
handling appropriate to the operation.

Tests must prove that retries do not create duplicate incidents, assignments,
alerts, pages, messages, or timeline records where single effect is required.


## Foundation Approval and Authorization During Degradation

Degraded operation does not transfer Foundation approval or authorization authority to the workstation.

A local client, cache, queue, or fallback process must not create an authoritative Approval Action Record, evaluate or finalize an Approval Request, manufacture an Authorization Decision, issue or extend an Authorization Lease, or mark a protected CAD operation committed.

When service returns, the authoritative service must revalidate current Approval Request final state, stage satisfaction, Approval Action continuity, actor independence, Authority Grant continuity, withdrawal, correction, supersession, expiration, suspension, revocation, exact context, and any Authorization Lease before committing the CAD operation.

Serialization failure, deadlock, or another retryable Step 7 concurrency result must remain a technical retry condition rather than being shown as a policy denial or a successful operation.

See the [Foundation Approval and Protected CAD Operation Integration Model](foundation-approval-and-protected-operation-integration-model.md).

## Accessibility During Degradation

A degraded interface must preserve accessible interaction.

Fallback operation must not remove:

- Keyboard access.
- Non-color status.
- Text equivalents for sound.
- Essential list alternatives to maps.
- Focus predictability.
- Accessible error and queue state.
- Accessible recovery instructions.

## Continuity Artifacts

Future deployment design must define:

- Continuity procedures.
- Manual forms.
- Temporary numbering.
- Printed or offline reference material.
- Contact paths.
- Recovery roles.
- Reentry procedures.
- Reconciliation work queues.
- After-action preservation.

Manual fallback does not eliminate the requirement to protect sensitive
information and preserve accountable history.

## Recovery

Recovery must distinguish:

- Technical service restored.
- Data synchronized.
- Conflicts resolved.
- Queues drained.
- External delivery confirmed.
- Operator workflow returned to normal.
- Acceptance checks completed.

A green service-health check alone is not sufficient to declare operational
recovery.
