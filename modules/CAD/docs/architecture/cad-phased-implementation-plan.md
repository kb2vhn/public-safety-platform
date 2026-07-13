# CAD Phased Implementation Plan

> **Document status:** Normative planning architecture
>
> **Implementation status:** Only the design scaffold exists

## Purpose

Sequence CAD development so that architecture, database behavior, service
boundaries, interface behavior, testing, and deployment controls advance
together.

This plan does not authorize skipping unfinished Platform Foundation work.

## Phase CAD-0 — Module Boundary

Establish:

- Mission.
- Module ownership.
- Dependency direction.
- Domain and non-domain boundaries.
- Initial terminology.
- Initial capability catalog.
- Documentation and decision structure.

Acceptance requires static documentation validation only.

## Phase CAD-1 — Dispatcher Operational Contract

Define:

- Incident queue.
- Selected incident workspace.
- Unit and resource board.
- Alerts and timers.
- Map and equivalent representations.
- Dispatcher and supervisor operations.
- Accessibility requirements.
- Degraded-operation presentation.

No production interface is built in this phase.

## Phase CAD-2 — Domain Invariants and Controlled Operations

Define:

- Incident identity and lifecycle.
- Intake and incident separation.
- Operational timeline.
- Assignment lifecycle.
- Unit status.
- Recommendations.
- Location roles.
- Premise and hazard governance.
- Alert acknowledgment and resolution.
- Transfer, closure, reopening, and correction.
- Exact governed operations and protected targets.
- Exact Foundation Approval Request, Approval Action, stage-evaluation, Authorization Decision, Authorization Lease, and protected-operation boundaries.

No migration is accepted until these invariants are sufficiently stable.

## Phase CAD-3 — Module Range and SQL Contract

Approve:

- Exact CAD migration range within `200–899`.
- CAD schema names.
- CAD manifest location.
- Dependency on Foundation and shared-resource manifests.
- Transaction and timeout contract.
- Migration registry behavior.
- Ownership and runtime-role model.
- Test-manifest structure.
- Phase-gate structure.

This phase produces an explicit decision record.

## Phase CAD-4 — Initial Structural SQL

Implement the smallest coherent structural boundary, likely including:

- Incident identity.
- Incident classification.
- Operational location roles.
- Unit or resource identity references.
- Assignment structure.
- Append-oriented timeline structure.
- Minimal validation views.

Acceptance requires:

- Clean installation.
- Catalog and constraint tests.
- Ownership and privilege tests.
- No unrestricted runtime write path.
- Resource observation.
- Synchronized documentation.

## Phase CAD-5 — Controlled Incident and Assignment Behavior

Implement controlled APIs for:

- Incident creation.
- Classification and priority.
- Operational updates.
- Unit status.
- Unit assignment and cancellation.
- Transfer.
- Closure and reopening.
- Correction and supersession.

Acceptance requires positive, negative, and independent-connection tests.

## Phase CAD-6 — Alerts, Recommendations, and Reconciliation

Implement:

- Timer policy.
- Alert creation, acknowledgment, escalation, and resolution.
- Response plans.
- Explainable recommendation records.
- Staleness.
- Idempotent delivery.
- Degraded-operation queueing and reconciliation.

Acceptance requires race, replay, timeout, retry, and recovery tests.

## Phase CAD-7 — Production Go Services

Build production services only against accepted controlled database APIs.

Establish:

- Service boundaries.
- Request validation.
- Foundation authorization context.
- Transaction boundaries.
- Integration outbox workers.
- Adapter contracts.
- Telemetry.
- Least-privileged runtime identities.
- Unix-domain socket use for appropriate same-host local communication.
- Error and retry semantics.

Historical experiments must not be promoted into production by renaming them.

## Phase CAD-8 — CAD User Interface and Operational Workstation

Build the dispatcher interface and CAD Operational Workstation against accepted CAD service contracts and the module-owned user-interface and workstation architecture.

Acceptance requires:

- Keyboard-first essential workflows.
- Accessible queues, tables, maps, timers, and alerts.
- Stable focus.
- Non-color-only state.
- Multi-monitor and supported single-monitor behavior.
- Workstation-component isolation, restart, and context restoration.
- Stale, queued, failed, and degraded-state visibility.
- Representative operational testing.
- Performance and resource observation.

## Phase CAD-9 — Integration and Pilot Readiness

Add controlled adapters and deployment profiles for selected pilot capabilities.

Validate:

- Provider replacement boundary.
- Authentication and secrets.
- Off-host logging.
- Backup and restore.
- Break-glass.
- Trusted rebuild.
- Monitoring.
- Continuity procedures.
- Training.
- Accessibility assurance.
- Operational acceptance.
- Incident response.

## Phase CAD-10 — Production Acceptance

Production acceptance requires more than feature completion.

It requires:

- Accepted Foundation and CAD behavior.
- Least privilege.
- Protected deployment.
- Recovery validation.
- Operational ownership.
- Legal and policy review.
- Data-retention decisions.
- Security assessment.
- Accessibility acceptance.
- Performance budgets.
- Load and endurance testing.
- Pilot findings resolved or governed.
- Exact known limitations.
- Release and rollback procedure.

## Step Discipline

Each phase may be divided into numbered steps.

Each step should freeze one understandable contract, implement the minimum
coherent behavior, prove it, and synchronize all documentation before the next
step begins.
