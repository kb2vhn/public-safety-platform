# CAD Architecture

> **Owner:** Iron Signal Systems
>
> **Status:** Normative CAD architecture under active refinement
>
> **Implementation status:** Design only

## Dependency Direction

```text
Platform Foundation and governed platform services
        ↓
CAD domain and application services
        ↓
CAD user-interface contracts
        ↓
CAD Operational Workstation and other CAD clients
        ↓
Replaceable external adapters and delivery technologies
```

No client, renderer, local cache, workstation component, or external provider is
an independent source of CAD authorization or canonical operational truth.

## Governing Boundary

Start with the
[CAD Architecture Boundary and Precedence Model](cad-architecture-boundary-and-precedence-model.md).
It resolves ownership where domain, interface, and workstation documents touch
the same workflow.

## CAD Domain and Application Models

1. [CAD Module Boundary and Dependency Model](cad-module-boundary-and-dependency-model.md)
2. [Dispatcher Operational Workspace Model](dispatcher-operational-workspace-model.md)
3. [Incident Lifecycle and Operational History Model](incident-lifecycle-and-operational-history-model.md)
4. [Unit, Resource, and Response Recommendation Model](unit-resource-and-response-recommendation-model.md)
5. [Location, Mapping, Premise, and Hazard Model](location-mapping-premise-and-hazard-model.md)
6. [Alerts, Timers, and Attention Management Model](alerts-timers-and-attention-management-model.md)
7. [Authorization, Audit, and Supervisory Control Model](authorization-audit-and-supervisory-control-model.md)
8. [Foundation Approval and Protected CAD Operation Integration Model](foundation-approval-and-protected-operation-integration-model.md)
9. [Communications and External-Integration Model](communications-and-external-integration-model.md)
10. [Degraded Operations, Continuity, and Reconciliation Model](degraded-operations-continuity-and-reconciliation-model.md)

## CAD Human Interaction

- [CAD User-Interface Architecture](user-interface/README.md)
- [CAD Client Experience Model](user-interface/client-experience-model.md)
- [CAD Accessibility and Inclusive Interaction Model](user-interface/accessibility-and-inclusive-interaction-model.md)

These documents own human-facing behavior independent of a particular operating
system, renderer, or workstation packaging choice.

## CAD Operational Workstation

- [CAD Operational Workstation Architecture](operational-workstation/README.md)

This directory owns the managed workstation appliance, local workstation
components, native services, IPC, cache, spool, release, security, management,
resource, fault, and recovery behavior.

## Delivery and Acceptance

- [CAD Testing and Acceptance Model](cad-testing-and-acceptance-model.md)
- [CAD Phased Implementation Plan](cad-phased-implementation-plan.md)

## Architecture Acceptance Rule

An architecture model is not implemented merely because it exists.

Implementation claims require exact executable artifacts, authoritative
registration, clean installation or reproducible build, structural and
privilege validation, positive and negative tests, independent-connection
concurrency tests where state can race, accessibility evaluation for
human-facing behavior, resource observation for executable paths, synchronized
status documentation, and a retained acceptance record.
