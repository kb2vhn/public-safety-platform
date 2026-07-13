# Platform Architecture

> **Owner:** Iron Signal Systems
>
> **Status:** Normative architecture under active refinement
>
> **Current status:** Phase 4 Step 6 accepted; Phase 4 Step 7
> independent-connection approval concurrency candidate

## Dependency Direction

```text
Project Goals and Technology Decisions
        ↓
Domain-Neutral Platform Foundation
        ↓
Platform Services and Shared Resources
        ↓
Module Families
        ↓
External-System Adapters, Integrations, and User Interfaces
```

The Foundation must not depend on one operational module, deployment product,
monitoring vendor, identity provider, or compliance framework.

## Current Architecture

### Platform Foundation

- [Platform Foundation Documentation](foundation/README.md)
- [Approval Independence and Separation of Duties](foundation/approval-independence-and-separation-of-duties-model.md)
- [Resource Telemetry and Performance-Regression Testing](foundation/resource-telemetry-and-performance-regression-testing-model.md)
- [Foundation Migration Timeout and Execution Performance Standard](foundation/foundation-migration-timeout-and-execution-performance-standard.md)
- [Performance, Efficiency, and Resource Governance](foundation/performance-efficiency-and-resource-governance-model.md)
- [Observability, Health, and Operational Telemetry](foundation/observability-health-and-operational-telemetry-model.md)
- [Approval Framework](foundation/approval-framework.md)
- [Authority and Authorization](foundation/authority-and-authorization-model.md)
- [Authorization Evaluation Contract](foundation/authorization-evaluation-contract.md)
- [Phase 3 Authorization Acceptance](foundation/phase-3-authorization-decision-and-controlled-lease-acceptance.md)

### Platform Services and Client Architecture

- [Backend Services](backend-services/README.md)
- [Location Service Architecture](backend-services/location-service-architecture.md)
- [Communications](communications/README.md)
- [Resource Subscription and Live Update Model](communications/resource-subscription-and-live-update-model.md)
- [GIS and Mapping](gis-and-mapping/README.md)
- [Map Rendering and Data Delivery Architecture](gis-and-mapping/map-rendering-and-data-delivery-architecture.md)
- [Operational Workstation](../../modules/CAD/docs/architecture/operational-workstation/README.md)
- [Operational Workstation Architecture](../../modules/CAD/docs/architecture/operational-workstation/operational-workstation-architecture.md)
- [User-Interface Architecture](../../modules/CAD/docs/architecture/user-interface/README.md)
- [Accessibility and Inclusive Interaction](../../modules/CAD/docs/architecture/user-interface/accessibility-and-inclusive-interaction-model.md)

## Accepted Implementation Status

Phases 1, 2, and 3 are formally accepted. Phase 4 Step 6 is the current
accepted implementation boundary:

```text
34 migrations
21 sequential tests
9 concurrency tests
650 PASS
0 FAIL
3 understood WARN
Correctness result: PASS
Resource observation: RECORDED
Performance thresholds: NOT_EVALUATED
```

## Active Architecture Boundary

Phase 4 Step 7 adds database-owned independent-connection concurrency proofs
without changing dependency direction. The Foundation serializes only the
governed approval records needed to close explicit request, chain, authority,
withdrawal, stage-evaluation, and finalization races.

Backend services may consume Foundation decisions; communications may deliver
governed state; GIS clients may render published facts; operational
workstations may present module capabilities; and user interfaces may support
authorized work. None of those downstream areas becomes an independent source
of identity, authority, approval, commitment, or truth.

## Migration Execution Boundary

The current clean-install Foundation migration contract is `5s` lock wait,
`1min` statement execution, and `1min` idle-in-transaction, all established
with `SET LOCAL`. A statement observed above ten seconds requires investigation
even while broader performance budgets remain observation-only. The active
phase gate executes the static migration-timeout validator before database
execution.

## Phase 4 Step 7 Candidate

Seven new concurrency files add 84 assertions and increase the candidate
inventory to:

```text
34 manifest migrations
34 registered migrations
21 sequential test files
16 concurrency test files
734 PASS
0 FAIL
3 understood WARN
Correctness result: PASS
Resource observation: RECORDED
Performance thresholds: NOT_EVALUATED
```

The active gate is:

```bash
./tools/validation/phase-gates/validate_phase4_step7.sh
```
