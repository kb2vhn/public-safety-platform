# CAD Architecture Boundary and Precedence Model

> **Document status:** Normative CAD architecture
>
> **Implementation status:** Design only

## Purpose

Define ownership and precedence among the CAD domain, CAD user-interface, and
CAD Operational Workstation architecture so overlapping concerns do not create
competing sources of truth.

## Layer Ownership

### Platform Foundation

The Platform Foundation remains authoritative for reusable identity, device
trust, Authentication Assertions, sessions, Authority Grants, Approval Requests,
Approval Action Records, stage evaluations, Approval Request finalization,
Authorization Decisions, Authorization Leases, Decision Records, applicable
Decision Supporting Records, classification, assurance, resilience, telemetry,
and governed integration mechanisms.

CAD consumes those capabilities. CAD does not redefine them inside a client or
workstation.

### CAD Domain and Application Architecture

The CAD domain and application layer is authoritative for:

- Incident, intake, unit, resource, assignment, location, alert, timer, response
  plan, recommendation, and operational-history semantics.
- Allowed lifecycle transitions and invariants.
- Canonical committed state.
- Controlled operations and service contracts.
- Server-side authorization context.
- External integration intent and delivery state.
- Degraded authority, queueing, conflict, and reconciliation semantics.

### CAD User-Interface Architecture

The CAD user-interface layer is authoritative for:

- Role-centered interaction.
- Information hierarchy and understandable state presentation.
- Keyboard, alternate-input, focus, semantic, and assistive-technology behavior.
- Non-color and multi-sensory meaning.
- Accessible maps, queues, tables, alerts, timers, forms, and generated content.
- Human-facing error, pending, queued, failed, conflicted, degraded, and recovery
  behavior.
- Interface evaluation results and accessibility Assurance Artifacts.

It does not select the operating system, renderer, process topology, local IPC,
or workstation hardening profile.

### CAD Operational Workstation Architecture

The CAD Operational Workstation layer is authoritative for:

- Managed operating-system and console-session behavior.
- Native process and workstation-component boundaries.
- Local IPC and systemd supervision.
- Renderer and WebView containment.
- Local cache, spool, draft, and action-recovery implementation.
- Workstation Observation Records, Workstation Trust Assertions, hardening, network profile, package governance,
  remote management, release, resource containment, provisioning, and rebuild.
- Operator-visible workstation and local-component health.

It does not define CAD incident semantics, independently authorize protected
operations, or convert local state into canonical committed state.

## Precedence Rules

1. Foundation security and governance contracts control where applicable.
2. CAD domain semantics control the meaning and validity of operational state.
3. CAD user-interface rules control how that state and available actions are
   presented and operated by people.
4. CAD Operational Workstation rules control how the accepted interface is
   hosted, isolated, secured, observed, and recovered locally.
5. A lower layer may impose a stricter safety or availability restriction, but
   it may not fabricate authorization, success, commitment, or canonical state.

## Resolved Overlaps

### Dispatcher Workspace and Client Experience

The Dispatcher Operational Workspace Model defines what operational information
and actions belong in the dispatcher context.

The CAD Client Experience and Accessibility models define how that context must
behave for a person.

The Operational Workstation defines how workstation components render, isolate,
restart, and restore that context.

### Degraded Operation

The CAD Degraded Operations, Continuity, and Reconciliation Model defines
canonical meaning, allowed degraded authority, queue state, conflicts, and
reconciliation.

The CAD user-interface architecture defines how those states are communicated
and operated accessibly.

The Operational Workstation degraded-state and local-state models define local
implementation, persistence, restart, and restoration.

### Alerts

A CAD operational alert is a domain record about an operational condition.

A workstation health or fault notification is a local operational-support
condition.

The workstation may present both in a unified attention surface, but it must
preserve source, type, severity, ownership, acknowledgment, and resolution
semantics. Acknowledging one must not resolve the other.

### Mapping

The CAD location and mapping model owns location roles, provenance, confidence,
and canonical operational use.

The CAD user-interface layer owns accessible map interaction and equivalent
representations.

The workstation owns the local mapping renderer, cache, resource budget, health,
and failure containment.

### Authorization and Trust

The workstation supplies attributable Workstation Observation Records and
Workstation Trust Assertions. The Foundation may bind applicable assertions into
Decision Supporting Records for the exact requested operation.

The Platform Foundation evaluates current assertions and all other exact-context
conditions. The workstation does not produce an Authorization Decision or an
Authorization Lease.

A visible control, local socket, running workstation component, cached policy,
or healthy endpoint never grants authority by itself.

### Communications

The CAD communications model owns external contract, delivery intent,
idempotency, acknowledgment, and canonical delivery state.

The workstation network profile owns which local processes may communicate with
which destinations and how that policy is independently enforced.

### Testing

The CAD Testing and Acceptance Model coordinates the complete acceptance gate.

The CAD user-interface architecture owns detailed human-interaction and
accessibility evaluation.

The workstation performance and resource documents own local appliance and
workstation-component measurements.

Correctness, accessibility, and resource results remain separately reported.

## Terminology Rule

**Module** means a top-level Iron Signal Platform module family such as CAD.

A separately supervised local CAD console process or surface is a
**workstation component**, not another Platform module.

This terminology prevents a map renderer, incident panel, local service, or
message process from being mistaken for an independently governed Platform
module.

## Conflict Handling

When two documents appear to conflict:

1. Identify the affected layer and authoritative owner.
2. Preserve the stricter security, accessibility, integrity, or degraded-state
   requirement while the conflict is reviewed.
3. Do not implement ambiguous protected behavior.
4. Record the resolution through an architecture or decision update.
5. Update tests and acceptance records and artifacts with the same change.

## Foundation Approval Precedence

The [Foundation Approval and Protected CAD Operation Integration Model](foundation-approval-and-protected-operation-integration-model.md) is authoritative whenever a CAD or workstation statement could be read as allowing a client, cache, queue, supervisor, or degraded workflow to create or reuse approval or authorization state.

CAD may define domain review records, but the Platform Foundation remains authoritative for Approval Requests, Approval Action Records, stage evaluation, request finalization, Authorization Decisions, Authorization Leases, Decision Records, and Decision Supporting Records.
