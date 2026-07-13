# Alerts, Timers, and Attention Management Model

> **Document status:** Normative CAD architecture
>
> **Implementation status:** Not implemented

## Purpose

Provide actionable, explainable attention management without creating avoidable
alarm fatigue.

## Condition and Alert Separation

An operational condition is the underlying fact or rule evaluation.

An alert is a governed notification instance created because a condition
requires attention.

The system must not treat alert acknowledgment as proof that the underlying
condition is resolved.

## Alert Record

An alert should include:

- Alert identity.
- Alert type and version.
- Severity.
- Priority.
- Source.
- Affected incident, unit, resource, integration, or scope.
- Condition identity.
- Created time.
- Effective time.
- Age.
- Required action.
- Owner or responsible position.
- Acknowledgment state.
- Escalation state.
- Resolution state.
- Expiration.
- Suppression or deduplication context.
- Accessibility presentation requirements.
- Correction and supersession lineage.

## Expected Alert Conditions

Examples include:

- Unanswered emergency intake.
- Incident awaiting dispatch.
- High-priority incident without an assigned resource.
- Unit failing to acknowledge.
- Unit overdue en route.
- Unit overdue on scene.
- Responder emergency activation.
- Stale or missing unit location.
- Conflicting unit state.
- Caller disconnected during a critical event.
- Incomplete required response.
- Mutual-aid request awaiting acceptance.
- Transfer awaiting acceptance.
- Road or hazard change affecting response.
- Critical premise warning.
- Failed dispatch delivery.
- CAD, radio, mapping, telephony, text, paging, or AVL degradation.
- Required supervisor review.
- Reconciliation conflict.

## Timers

A timer must identify:

- Policy and version.
- Start event.
- Pause behavior.
- Stop event.
- Threshold.
- Warning threshold.
- Escalation threshold.
- Applicable incident, unit, resource, or workflow.
- Responsible position.
- Current state.
- Effective and recorded times.
- Degraded-operation behavior.

A timer must not be implemented only as a client-side visual countdown.

## Acknowledgment

Acknowledgment means that an authorized actor has taken responsibility for
reviewing or acting on the alert.

Acknowledgment should record:

- Actor.
- Position.
- Session.
- Authority.
- Time.
- Alert version.
- Optional or required note.
- Resulting ownership.

Acknowledgment must not remove the alert from authorized history.

## Resolution

Resolution means the underlying condition is no longer active or has received a
governed disposition.

Resolution should identify:

- Resolving event or condition.
- Actor or system.
- Time.
- Reason.
- Whether the resolution was automatic or manual.
- Whether follow-up remains.
- Related incident or supervisory action.

## Escalation

Escalation rules should define:

- Time or condition trigger.
- New severity or priority.
- New responsible position or organization.
- Additional notification channels.
- Maximum escalation.
- Suppression behavior.
- Degraded-operation behavior.
- Audit and telemetry.

## Deduplication and Suppression

Repeated observations of the same condition should not create uncontrolled alert
storms.

Deduplication must remain explainable and must not hide a materially changed
condition.

Suppression requires:

- Exact rule.
- Scope.
- Start and end.
- Actor or policy.
- Reason.
- Maximum duration.
- Safety constraints.
- Review and audit.

Mandatory life-safety alerts must not be suppressible through an ordinary user
preference.

## Accessible Presentation

Critical alerts must have appropriate combinations of:

- Text.
- Severity label.
- Icon or shape.
- Visual emphasis.
- Sound.
- Programmatic announcement.
- Persistent queue presence.

No critical alert may depend solely on color, sound, flashing, vibration, screen
position, or transient display.

High-frequency status changes must not overwhelm assistive technology with
low-value announcements.

## Testing

Tests must cover:

- Alert creation.
- No duplicate active alert when policy requires deduplication.
- Material change creating or updating attention state.
- Acknowledgment without resolution.
- Resolution without history loss.
- Escalation.
- Expiration.
- Suppression limits.
- Concurrent acknowledgment.
- Concurrent resolution.
- Degraded delivery.
- Accessibility presentation and keyboard operation.
