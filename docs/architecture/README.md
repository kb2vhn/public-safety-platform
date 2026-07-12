# Platform Architecture

> **Owner:** Iron Signal Systems
>
> **Status:** Normative architecture under active refinement
>
> **Current status:** Phase 4 Step 2 — approval-independence structural
> extension and baseline resource observation

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

- [Platform Foundation Documentation](foundation/README.md)
- [Approval Independence and Separation of Duties](foundation/approval-independence-and-separation-of-duties-model.md)
- [Resource Telemetry and Performance-Regression Testing](foundation/resource-telemetry-and-performance-regression-testing-model.md)
- [Performance, Efficiency, and Resource Governance](foundation/performance-efficiency-and-resource-governance-model.md)
- [Observability, Health, and Operational Telemetry](foundation/observability-health-and-operational-telemetry-model.md)
- [Approval Framework](foundation/approval-framework.md)
- [Authority and Authorization](foundation/authority-and-authorization-model.md)
- [Authorization Evaluation Contract](foundation/authorization-evaluation-contract.md)
- [Phase 3 Authorization Acceptance](foundation/phase-3-authorization-decision-and-controlled-lease-acceptance.md)

## Accepted Implementation Status

Phase 1, Phase 2, and Phase 3 are accepted.

```text
33 accepted Phase 3 migrations
16 accepted Phase 3 sequential tests
9 accepted Phase 3 concurrency tests
408 PASS
0 FAIL
3 understood WARN
```

Accepted Phase 3 tag:

```text
phase-3-authorization-control-complete-v1
```

## Active Architecture Boundary

Phase 4 Step 2 adds structural approval context without claiming behavioral
completion. It also adds a resource-aware wrapper around the unchanged
correctness suite.

Correctness and resource observations remain distinct:

```text
Correctness result: PASS or FAIL
Resource observation: RECORDED or NOT_RECORDED
Performance thresholds: NOT_EVALUATED
```

Validation gates are maintained under:

```text
tools/validation/phase-gates/
```

Architecture documents define requirements. Migrations implement selected
database controls. Tests demonstrate selected properties. Resource observations
describe execution cost. None replaces production deployment security or
operational verification.
