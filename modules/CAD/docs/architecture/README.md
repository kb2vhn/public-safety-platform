# CAD Architecture

> **Owner:** Iron Signal Systems
>
> **Status:** Normative architecture under active refinement
>
> **Implementation status:** Design only

## Dependency Direction

```text
Platform Foundation
        ↓
Shared Resources and Platform Services
        ↓
CAD Domain and Application Services
        ↓
CAD External-System Adapters and User Interfaces
```

The dispatcher interface is not the CAD source of truth.

External integrations are not hidden sources of authorization or history.

The CAD domain must remain usable through controlled service and database
boundaries even when a particular map, radio, telephony, AVL, paging, or
notification provider is unavailable.

## Architecture Models

1. [CAD Module Boundary and Dependency Model](cad-module-boundary-and-dependency-model.md)
2. [Dispatcher Operational Workspace Model](dispatcher-operational-workspace-model.md)
3. [Incident Lifecycle and Operational History Model](incident-lifecycle-and-operational-history-model.md)
4. [Unit, Resource, and Response Recommendation Model](unit-resource-and-response-recommendation-model.md)
5. [Location, Mapping, Premise, and Hazard Model](location-mapping-premise-and-hazard-model.md)
6. [Alerts, Timers, and Attention Management Model](alerts-timers-and-attention-management-model.md)
7. [Authorization, Audit, and Supervisory Control Model](authorization-audit-and-supervisory-control-model.md)
8. [Communications and External-Integration Model](communications-and-external-integration-model.md)
9. [Degraded Operations, Continuity, and Reconciliation Model](degraded-operations-continuity-and-reconciliation-model.md)
10. [CAD Testing and Acceptance Model](cad-testing-and-acceptance-model.md)
11. [CAD Phased Implementation Plan](cad-phased-implementation-plan.md)

## Cross-Platform Architecture

CAD human-facing behavior is also governed by:

```text
docs/architecture/user-interface/
```

That cross-platform architecture remains responsible for common accessibility
and interaction requirements. This module remains responsible for accessible
CAD-specific workflows, alerts, queues, maps, timers, commands, status
representations, and generated content.

## Architecture Acceptance Rule

An architecture model is not considered implemented merely because it exists.

Implementation claims require:

- Exact executable artifacts.
- Authoritative manifests.
- Clean installation.
- Structural and privilege validation.
- Positive and negative behavioral tests.
- Independent-connection concurrency tests when state can race.
- Accessibility evaluation for human-facing behavior.
- Resource observation for executable paths.
- Synchronized status documentation.
- A retained phase acceptance record.
