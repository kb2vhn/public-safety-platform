# Local State, Cache, Spool, and Recovery Model

> Status: Normative CAD target architecture.
>
> Implementation status: Storage engines, encryption mechanisms, and replay protocols are not yet selected.

## Purpose

This document defines what the workstation may store locally, how local state is protected, and how work is recovered without confusing local availability with authoritative commitment.

## State classes

Every local item must be assigned one state class.

### Authoritative reference

A durable authoritative state owned by a platform service. The workstation may hold a copy but does not become the owner.

### Projection

A rendered or query-optimized representation derived from authoritative state.

### Cache

A replaceable local copy used for performance or degraded read-only operation.

### Draft

Operator work that has not been submitted as a protected platform action.

### Pending action

An action prepared for delivery but not yet acknowledged by the authoritative service.

### Committed action

An action for which the authoritative service returned a durable commitment identifier.

### Rejected action

An action explicitly refused by the authoritative service.

### Conflicted action

An action that cannot be safely applied because current authoritative state differs from the action's expected context.

### Outcome-unknown action

An action for which the workstation cannot determine whether the authoritative service committed it.

### Diagnostic state

Local information used for health, fault, performance, or support analysis.

### Disposable state

Presentation state that may be discarded without operational consequence.

## Core rules

- Local presence does not imply currentness.
- Successful local write does not imply server commitment.
- A retry is not safe merely because the previous response was lost.
- A cache must expose source, age, and freshness.
- A pending action must have an idempotency key.
- A committed action must carry the authoritative commitment reference.
- Outcome-unknown actions require reconciliation before ordinary retry.
- Workstation Components must not invent replacement state after restart.
- Local storage exhaustion must become visible before critical data is lost.

## Storage ownership

Local state should be owned by a dedicated service or narrowly scoped component service rather than uncontrolled renderer storage.

The renderer must not be the sole holder of:

- Unsaved critical drafts.
- pending protected actions.
- delivery acknowledgment.
- replay cursor.
- fault episode identifier.
- recovery checkpoint.

## Data protection

Each state class declares:

- Classification.
- encryption requirement.
- TPM or device binding where applicable.
- operator, session, workstation component, or workstation scope.
- retention.
- maximum size.
- freshness limit.
- backup policy.
- secure deletion behavior.
- crash-recovery behavior.
- handoff behavior.
- rebuild behavior.
- support-access policy.

Sensitive state must be protected at rest even when the full disk is encrypted if a separate application-level boundary is required.

## Cache policy

A cache entry includes:

- Source service.
- source object identifier.
- authoritative version or sequence.
- retrieved time.
- effective time where relevant.
- expiration time.
- classification.
- integrity reference.
- dependency version.
- last successful refresh.
- current freshness state.

Cached information shown during degraded operation must be visibly identified as cached, delayed, stale, or offline.

## Draft policy

A draft must declare:

- Owning operator.
- console session.
- workstation.
- workflow.
- classification.
- creation and modification time.
- expected authoritative context.
- recovery eligibility.
- maximum retention.
- handoff disposition.
- encryption state.

Draft recovery must not make a prior operator's work visible to a new operator without governed transfer.

## Action delivery

Protected actions use:

- Stable action identifier.
- idempotency key.
- expected authoritative version or context.
- operator and session reference.
- workstation and component instance reference.
- creation time.
- expiration.
- ordered delivery requirements.
- payload integrity.
- current delivery state.

## Acknowledgment

The workstation may mark an action committed only when it receives sufficient authoritative acknowledgment.

An acknowledgment should include:

- Action identifier.
- commitment identifier.
- authoritative sequence or version.
- commitment time.
- decision-record reference where applicable.
- resulting state reference.
- integrity-verification or signature records where required.

## Outcome unknown

An action enters outcome-unknown when:

- The request may have reached the server.
- The authoritative response is absent or unverifiable.
- The workstation cannot prove rejection or commitment.

The UI must not present outcome-unknown as a simple failure.

The recovery path is:

1. Query authoritative status by action or idempotency key.
2. verify the current operator and session context.
3. determine committed, rejected, expired, or unresolved.
4. update the local state.
5. require governed support or supervisor action if unresolved beyond policy.
6. record the complete event chain.

## Replay

Replay must be:

- Ordered where ordering matters.
- idempotent.
- bounded.
- resumable.
- attributable.
- version compatible.
- conflict aware.
- visible to the operator when it affects workflow.

A replay cursor is durable and integrity protected.

## Disk and queue limits

Each workstation component and state class declares a storage budget.

The workstation monitors:

- Free space.
- write latency.
- queue depth.
- oldest queued item.
- cache age.
- failed deletion.
- filesystem errors.
- encryption errors.
- database or journal integrity.

Threshold behavior must be defined before exhaustion.

The console may restrict new nonessential work when safe persistence cannot be guaranteed.

## Crash recovery

After restart:

1. Verify local store integrity.
2. quarantine invalid records.
3. restore only version-compatible state.
4. identify pending and outcome-unknown actions.
5. reconcile with authoritative services.
6. restore eligible drafts after operator authentication.
7. expose conflicts.
8. record recovery results.

## Rebuild

A trusted rebuild normally discards local caches and disposable state.

Before rebuild, governed recovery may preserve:

- Unsent critical actions.
- outcome-unknown references.
- eligible drafts.
- required fault diagnostic records.
- approved diagnostic bundles.

Preserved data must be integrity protected, encrypted, attributable, and imported through a validated recovery process.

## Backup

The workstation is not the primary backup location for authoritative platform data.

Local backups are permitted only for explicitly approved state classes. A backup must not silently turn transient workstation data into a long-lived uncontrolled repository.

## Prohibited Local Authority

The local store and spool must never become an alternate Foundation authority. They must not contain locally authoritative:

- Approval Action Records.
- Approval Request stage evaluations or finalization.
- Authorization Decisions.
- Authorization Leases.
- Decision Records.
- Protected CAD commits.

A cached copy of one of these records is read-only supporting context with an explicit freshness limit. It cannot be replayed as authority.

When queued protected work is submitted, the authoritative service performs current-state validation, including Phase 4 Step 7 Approval Request, Approval Action, stage-evaluation, finalization, and Authority Grant continuity. The workstation may mark the action **committed** only after authoritative acknowledgment identifies the committed CAD result.
