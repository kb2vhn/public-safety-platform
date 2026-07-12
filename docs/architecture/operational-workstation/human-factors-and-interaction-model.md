# Human Factors and Interaction Model

> Status: Normative target architecture.
>
> Implementation status: Not yet field validated with operational users.

## Purpose

This document defines interaction rules intended to reduce operator workload, preserve context, and prevent the interface from becoming an additional source of operational risk.

## Primary principle

Operator attention is a constrained operational resource. The console must spend it deliberately.

The interface should help the operator perceive, understand, decide, and act without requiring them to manage the computer.

## Interaction requirements

- Keyboard-first does not mean keyboard-exclusive.
- Every critical shortcut has a visible and accessible control.
- Focus remains predictable after navigation and live updates.
- Routine updates do not steal focus.
- New information does not reorder active work unexpectedly without a clear rule.
- Critical alerts are distinguishable without relying only on color.
- Destructive or high-impact operations receive confirmation appropriate to risk and urgency.
- Repeated warnings are grouped or escalated rather than creating an alert storm.
- The operator can determine data age and source.
- The interface differentiates committed, pending, rejected, conflicted, and outcome-unknown actions.
- A failed module displays a deliberate degraded surface rather than an empty normal-looking area.
- Recovery preserves context where safe.
- Error language explains operational effect rather than exposing only implementation detail.

## Workspace continuity

The console should preserve:

- Current incident selection.
- current resource selection.
- scroll and focus position where safe.
- active search context.
- map viewport and approved layers.
- unsaved recoverable draft state.
- accessibility settings.
- monitor placement.
- visible degraded-state indicators.

A module restart must not unexpectedly redirect the operator to a default home screen when the prior context can be reconstructed safely.

## Alert hierarchy

Alert levels must be based on operator consequence, not only technical severity.

A useful hierarchy may include:

- Informational state change.
- operator attention requested.
- workflow blocked.
- safety-relevant degradation.
- urgent security or trust restriction.
- complete capability failure.

The exact names and presentation are profile governed.

A backend error that has no operator effect may remain a support event. A stale unit location may require immediate operator-visible warning even if no process crashed.

## Confirmation design

Confirmation depends on:

- Consequence.
- reversibility.
- time sensitivity.
- frequency.
- likelihood of accidental activation.
- availability of later correction.
- whether another approval is already required.

The system must not train operators to dismiss constant generic confirmation dialogs.

High-frequency low-risk actions should avoid unnecessary confirmation. Rare irreversible actions require clear context and explicit intent.

## Focus management

- Live updates do not move focus.
- A newly inserted row does not displace the row currently being acted upon.
- Keyboard focus is always visually apparent.
- Modal surfaces are minimized.
- A module failure does not send focus to another module unexpectedly.
- After restart, focus returns only when doing so is safe and predictable.
- Screen readers receive state changes in a prioritized, non-repetitive manner.

## Keyboard bindings

Each binding record includes:

- Chord.
- scope.
- action.
- visible alternative.
- accessibility alternative.
- collision review.
- risk classification.
- confirmation behavior.
- focus effect.
- authorization effect.
- owner.
- approval state.
- test evidence.

A keyboard binding may request an action; it does not bypass server-side authorization.

## Live data

For changing data:

- Updates are applied without obscuring active operator work.
- freshness is visible where operationally relevant.
- old values are not silently replaced in a way that hides a meaningful change.
- significant status changes may be highlighted temporarily.
- rapid updates are coalesced when individual intermediate values have no operational value.
- update animation does not impede reading or create motion sensitivity issues.

## Degraded operation

When a capability degrades, the operator sees:

- What is affected.
- current state.
- last known data age.
- what remains safe.
- whether recovery is automatic.
- whether alternate procedure is required.
- whether any action has an uncertain outcome.

The console does not expose a large diagnostic trace to the operator, but it provides an episode or support reference when useful.

## Error language

Operator-facing errors should follow this pattern:

```text
Capability
Current condition
Operational effect
Safe next action
Recovery status
Support reference
```

Example:

```text
Mapping unavailable — recovering

Incident entry and resource status remain available.
Do not rely on map positions until mapping is restored.
Recovery is in progress.

Reference: OFE-2026-000184
```

## Accessibility

Every workstation profile must declare the applicable cross-platform accessibility profile, supported assistive technologies, display configurations, and validation matrix.

A profile may add requirements. It must not weaken a binding cross-platform, legal, contractual, or deployment accessibility requirement.

Validation must include, as applicable:

- Keyboard-only operation.
- screen-reader navigation and announcements.
- high contrast.
- scaling and magnification.
- reduced motion.
- alternate input.
- focus visibility.
- non-color state communication.
- accessible lock, handoff, degraded, and recovery workflows.
- accessible support and maintenance messaging.

## Operator validation

Architecture acceptance requires structured evaluation with representative operational users.

Validation should include:

- Normal workload.
- high event volume.
- interruption.
- shift handoff.
- module failure.
- degraded data.
- uncertain action outcome.
- display loss.
- accessibility profiles.
- fatigue and extended use.
- training and first-use behavior.

Feedback becomes governed design evidence rather than informal preference alone.
