# CAD User-Interface Architecture

> **Status:** Normative CAD architecture under active refinement
>
> **Implementation status:** Design requirements only; no CAD interface or
> accessibility conformance is accepted by this directory

## Purpose

Define the shared human-interaction requirements for CAD interfaces.

A CAD interface exists to help a person perform an authorized emergency
communications or response role. It must complement the work, preserve
attention, reduce avoidable effort, and make state and results understandable.

> **The interface should support the work rather than become additional work.**

## Scope

These requirements apply to applicable CAD:

- Call-taker and dispatcher workspaces.
- Supervisor workspaces.
- Field and mobile CAD clients.
- CAD administrative and configuration interfaces.
- Authentication, session, lock, and handoff interfaces.
- Maps, queues, tables, timelines, alerts, timers, and visualizations.
- Reports, forms, notices, messages, and generated content.
- Installation, recovery, support, and maintenance interfaces.
- Third-party interfaces presented as part of a CAD workflow.

They do not govern every future Iron Signal Platform interface merely because
those interfaces use the same Foundation.

## Architectural Boundary

This directory is role- and domain-specific but technology-neutral.

It defines what a responsible CAD interface must accomplish for a person. It
does not select a programming language, rendering engine, desktop environment,
web framework, mobile framework, workstation process topology, local IPC,
deployment topology, or vendor product.

The interface may consume services, decisions, policies, and governed state. It
must not:

- Move presentation concepts into the Platform Foundation.
- Treat visibility of a control as authorization.
- Allow presentation logic to bypass governed policy.
- Require operators to understand internal service, database, process, or vendor
  boundaries.
- Conceal stale, uncertain, failed, queued, conflicted, or degraded state.
- Transfer avoidable implementation complexity to the person doing the work.

## Dependency Direction

```text
Platform Foundation and governed services
        ↓
CAD domain and application services
        ↓
CAD user-interface contracts
        ↓
CAD Operational Workstation and other CAD clients
```

The interface presents and supports governed capabilities. It does not independently create identity, Authority Grants, Approval Action Records, Authorization Decisions, Authorization Leases, committed state, or canonical truth.

## Relationship to the Operational Workstation

This directory owns human interaction and accessibility.

The sibling [CAD Operational Workstation Architecture](../operational-workstation/README.md)
owns the managed Linux appliance, local workstation components, native services,
renderer containment, IPC, caching, release, management, and recovery.

The workstation implements this interface architecture; it does not replace it.

## Governing Principles

1. The role and its work come first.
2. The interface must preserve attention rather than compete for it.
3. Common work should have a clear and direct path.
4. System state and action outcomes must be understandable.
5. A failure in one capability should not unnecessarily block unrelated work.
6. Accessibility is part of functional correctness.
7. Security must remain strong without creating needless friction.
8. The interface must not claim success before authoritative confirmation.
9. Degraded, stale, queued, uncertain, rejected, conflicted, and committed
   conditions must be recognizable.
10. Visual polish is not a substitute for effective, safe, and independently
    operable work.

## Documents

- [CAD Client Experience Model](client-experience-model.md)
- [CAD Accessibility and Inclusive Interaction Model](accessibility-and-inclusive-interaction-model.md)

The legacy filename
[Client Experience and Accessibility Model](client-experience-and-accessibility-model.md)
is retained only as a compatibility index for existing links. It does not
duplicate the normative requirements.
