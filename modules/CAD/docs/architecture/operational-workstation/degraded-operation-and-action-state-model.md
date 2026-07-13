# Degraded Operation and Action State Model

> Status: Normative CAD target architecture.
>
> Implementation status: State contracts and operator presentation are not yet implemented.

## Purpose

The console must present degraded conditions clearly and must never make old, incomplete, unavailable, or uncertain information appear normal.

Connection or data condition and action-delivery condition are separate state families.

## Connection and data states

### Live

Required services and subscriptions are current within the accepted latency and freshness budget.

### Delayed

Updates are arriving, but outside the normal latency budget.

### Stale

A resource or dataset has exceeded its freshness policy.

### Offline

The relevant connection or service is unavailable.

### Resynchronizing

The workstation component is rebuilding current state from an authoritative snapshot and ordered changes.

### Restricted

The workstation, session, operator, policy, or dependency state permits only a reduced operation set.

### Untrusted

The workstation cannot establish sufficient trust for protected operation.

### Unknown

The console cannot determine the current state safely.

### Maintenance

The capability is intentionally unavailable or limited for governed maintenance.

### Incompatible

The workstation component, protocol, release, or data version cannot interoperate safely.

## Action states

### Draft

The action exists only as operator work and has not been submitted.

### Pending

The action is prepared and waiting for delivery.

### Queued

The action is durably held for later delivery under an approved offline or backpressure policy.

### Transmitting

Delivery is in progress.

### Committed

The authoritative service acknowledged durable commitment.

### Rejected

The authoritative service refused the action.

### Conflicted

The action cannot be applied safely against current authoritative state.

### Cancelled

The action was cancelled before commitment under a valid workflow.

### Expired

The action exceeded its permitted delivery or authorization window.

### Outcome unknown

The request may have been committed, but the console cannot verify the result.

## Independence of states

Examples:

- A workstation component may be live while one action is outcome unknown.
- A workstation component may be offline while an operator edits a recoverable draft.
- A workstation component may be resynchronizing while committed records remain viewable.
- A workstation may be restricted while cached read-only reference information remains available.
- A map may be failed while incident entry and resource status remain healthy.

The UI must not collapse these situations into one generic offline banner.

## Presentation rules

- State is visible without opening a diagnostic screen.
- Meaning does not rely on color alone.
- Text, icon, shape, position, and accessible announcements reinforce important state.
- Resource markers expose data age when delayed or stale.
- Cached maps and reference data identify their age and missing live overlays.
- A blank workstation component surface is not an acceptable failure presentation.
- The operator sees what is unavailable, why if known, what remains safe, and what recovery is occurring.
- Repeated alerts must not create unusable alert storms.
- Restoration messages appear only after functional validation.

## Capability matrix

Each workstation component defines behavior for every relevant state.

A matrix identifies whether each operation is:

- Available normally.
- available read-only.
- available with stale-data warning.
- queued safely.
- requires session step-up or a finalized Foundation Approval Request with current Approval Action and Authority Grant continuity.
- blocked.
- requires alternate procedure.
- unavailable because the outcome cannot be determined.

## Security behavior

Degraded availability does not automatically bypass:

- Identity verification.
- session validity.
- device trust.
- operational scope.
- purpose.
- Current finalized Approval Request and Approval Action continuity when policy requires an approval input.
- Authorization Lease.
- data classification.
- audit.
- separation of duty.

Emergency or break-glass operation is a separately governed workflow with explicit authority, correlated audit and domain records, time bounds, alerts, and review.

## Integration failure

External integrations report their own state.

Examples include:

- Telephony metadata unavailable.
- radio unit-state feed delayed.
- recording reference unavailable.
- location provider stale.
- external alert gateway offline.

The failure of one integration must not make unrelated console capabilities appear failed.

A recording reference marked unavailable must not imply that no recording exists; it means the console cannot currently retrieve or verify the reference.

## Recovery

Recovery passes through explicit stages where applicable:

```text
Failed
  ↓
Restarting
  ↓
Local ready
  ↓
Resynchronizing
  ↓
Operator context restoring
  ↓
Functional validation
  ↓
Live
```

Skipping directly from failed to live is prohibited unless the same validation is performed and recorded.

## Alternate procedures

Every critical unavailable capability must have a profile-owned alternate-procedure reference.

The console may display concise operator guidance, but detailed operational procedure ownership remains with the deploying organization.

## Testing

Validation must include:

- Network loss.
- server restart.
- delayed subscriptions.
- stale cache.
- corrupted local state.
- renderer crash.
- component service crash.
- repeated restart failure.
- protocol incompatibility.
- storage exhaustion.
- time synchronization failure.
- certificate failure.
- workstation trust loss.
- outcome-unknown action.
- external integration failure.
- display loss.

## Approval and Authorization State

The workstation must not collapse these separate states:

- Approval Action Record recorded.
- Approval stage satisfied.
- Approval Request finalized.
- Authorization Decision allowed or denied.
- Authorization Lease current or invalid.
- CAD operation committed.
- External delivery acknowledged.

A local queue may preserve the requested action and supporting context, but it cannot create or finalize Foundation Approval Action Records, stage-evaluation records, or Approval Request finalization, create an Authorization Decision, issue an Authorization Lease, or mark a protected action committed.

Retryable serialization or deadlock results from the authoritative Step 7 concurrency boundary must be shown as retry or conflict states, not as policy denials.
