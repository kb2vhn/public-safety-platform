# Operational Workstation Architecture

> **Status:** Normative architecture under active refinement.
>
> **Implementation status:** Not yet implemented or validated.

## Purpose

The Operational Workstation Architecture defines how an operator interacts with the platform and how the workstation remains fast, predictable, secure, manageable, and recoverable.

The workstation is a first-class platform boundary. It is not merely a screen layout and must not be treated as an unmanaged endpoint.

## Architectural philosophy

The workstation exists to minimize operator cognitive load during routine work and high-stress operations. Every interface element, shortcut, notification, workspace, and workflow must help the operator perceive, understand, and act on authorized information without weakening security, auditability, or operational trust.

The workstation should behave like a dedicated mission-critical operational console rather than a general-purpose office desktop.

## Domain neutrality

The common workstation architecture must remain independent of CAD, RMS, EMS, fire, municipal finance, permitting, education, or another module family.

Module-specific workstation profiles may define:

- Workspace names and layouts.
- Permitted applications.
- Keyboard bindings.
- Data subscriptions.
- Notification priorities.
- Map layers.
- Accessibility requirements.
- Performance profiles.

The initial public-safety profile may be the most demanding profile, but it must not redefine the common workstation boundary as public-safety-only.

## Reference workstation direction

The initial reference implementation is expected to evaluate:

- A controlled Arch Linux image.
- i3wm as the initial window manager.
- A lightweight operational client or hardened browser application mode.
- Local GPU-assisted map rendering.
- Fixed, profile-driven workspaces.
- Keyboard-first and mouse-capable interaction.

These are deployment choices, not Foundation dependencies. A future approved profile may use a different operating system, window manager, display server, client toolkit, or endpoint-security product while satisfying the same contracts.

## Core responsibilities

The workstation architecture owns:

- Human factors and interaction consistency.
- Desktop and workspace behavior.
- Accessibility and input methods.
- Local rendering and bounded caching.
- Package and dependency governance.
- Host network policy.
- Workstation trust evidence collection.
- Remote administration and lifecycle management.
- Provisioning, rebuild, and recovery.
- Client performance budgets.
- Visible degraded and stale-data behavior.

It does not own:

- Identity or authorization policy.
- Authoritative operational records.
- Durable location history.
- Incident, case, personnel, or module business rules.
- Final trust decisions.
- GIS source-of-record data.

## Non-negotiable boundaries

- Opening a workspace, application, or shortcut never grants authority.
- Local possession of cached data never creates a new authorization right.
- The workstation must not silently display stale data as current.
- A workstation must be replaceable and reproducible from approved artifacts.
- Production packages, services, connections, and privileges require documented purposes.
- The client must remain responsive on the lowest supported workstation profile.
- The Foundation evaluates trust; endpoint tools provide evidence.

## Architecture relationships

```text
Operator
   |
   v
Operational Workstation
   |-- authenticated session and authorization context
   |-- one bounded live-update connection
   |-- local map rendering and short-lived cache
   |-- workstation trust evidence
   |
   +--> Foundation and module service APIs
   +--> Subscription Gateway
   +--> Map and GIS publication services
   +--> Controlled management, logging, update, and trust services
```

## Acceptance direction

A workstation profile is not accepted merely because it boots or launches the client. Acceptance requires documented evidence for:

- Reproducible provisioning.
- Package and dependency manifest accuracy.
- Default-deny network enforcement.
- Remote-management restrictions.
- Update and rollback behavior.
- Snapshot and restore testing.
- Trust-evidence freshness and failure behavior.
- Degraded-operation visibility.
- Performance on the lowest supported hardware.
- Human-factor and accessibility review.
