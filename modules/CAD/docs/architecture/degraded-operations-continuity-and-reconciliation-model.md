# Degraded Operations, Continuity, and Reconciliation Model

> **Document status:** Normative CAD architecture
>
> **Implementation status:** Not implemented

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

- Locally committed.
- Queued for delivery.
- Pending central authorization.
- Provisionally accepted.
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
