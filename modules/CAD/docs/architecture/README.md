# CAD Architecture

> **Owner:** Iron Signal Systems
>
> **Status:** Normative CAD architecture under active refinement
>
> **Implementation status:** Design and assurance metadata only

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
It resolves ownership where domain, interface, workstation, integration, and
assurance documents touch the same workflow.

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

## Delivery, Assurance, and Acceptance

### Governing Models

- [CAD Testing and Acceptance Model](cad-testing-and-acceptance-model.md)
- [CAD Phased Implementation Plan](cad-phased-implementation-plan.md)
- [CAD Operational Readiness and Production Acceptance Model](cad-operational-readiness-and-production-acceptance-model.md)
- [CAD Standards-Conformance and Interoperability Model](cad-standards-conformance-and-interoperability-model.md)
- [CAD Data-Migration, Cutover, and Transition Model](cad-data-migration-cutover-and-transition-model.md)
- [CAD Requirements and Evidence Traceability Model](../requirements/cad-requirements-traceability-model.md)

### Supporting Assurance Contracts

- [CAD Testing Identifiers and Authoritative Registries Model](cad-testing-identifiers-and-authoritative-registries-model.md)
- [CAD Test Campaign Accounting Model](cad-test-campaign-accounting-model.md)
- [CAD Test-Oracle and Side-Effect Verification Model](cad-test-oracle-and-side-effect-verification-model.md)
- [CAD Test Execution Tiers and Gate Cadence](cad-test-execution-tiers-and-gate-cadence.md)
- [CAD Test Evidence Retention and Integrity Model](cad-test-evidence-retention-and-integrity-model.md)
- [CAD Acceptance Record Model](cad-acceptance-record-model.md)

### Platform Assurance Dependencies

- [Platform Verification, Validation, and Acceptance Governance](../../../../docs/architecture/verification-validation-and-acceptance-governance-model.md)
- [Platform Software Supply-Chain and Release Integrity](../../../../docs/architecture/software-supply-chain-and-release-integrity-model.md)
- [Platform Host Software, Configuration, and Runtime Integrity](../../../../docs/architecture/host-software-configuration-and-runtime-integrity-model.md)

## Machine-Readable Assurance Metadata

```text
modules/CAD/requirements/cad-requirements.yaml
modules/CAD/testing/cad-controlled-operations.yaml
modules/CAD/testing/cad-enforcement-points.yaml
modules/CAD/testing/cad-hostile-classes.yaml
modules/CAD/testing/test-oracles.yaml
```

These registries are design scaffolding until executable implementation and
applicable tests are accepted.

## Architecture Acceptance Rule

An architecture model is not implemented merely because it exists.

Implementation claims require exact executable artifacts, authoritative
registration, clean installation or reproducible build, structural and
privilege validation, positive and negative tests, independent-connection
concurrency tests where state can race, accessibility evaluation for
human-facing behavior, resource observation for executable paths, synchronized
status documentation, and a retained acceptance record.
