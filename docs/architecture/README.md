# Platform Architecture

> **Owner:** Iron Signal Systems
>
> **Status:** Normative architecture under active refinement
>
> **Current status:** Phase 4 Step 4 accepted; Phase 4 Step 5 incompatible-authority
> and duty-conflict enforcement candidate with observation-only resource telemetry

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
- [Foundation Migration Timeout and Execution Performance Standard](foundation/foundation-migration-timeout-and-execution-performance-standard.md)
- [Performance, Efficiency, and Resource Governance](foundation/performance-efficiency-and-resource-governance-model.md)
- [Observability, Health, and Operational Telemetry](foundation/observability-health-and-operational-telemetry-model.md)
- [Approval Framework](foundation/approval-framework.md)
- [Authority and Authorization](foundation/authority-and-authorization-model.md)
- [Authorization Evaluation Contract](foundation/authorization-evaluation-contract.md)
- [Phase 3 Authorization Acceptance](foundation/phase-3-authorization-decision-and-controlled-lease-acceptance.md)

## Accepted Implementation Status

Phases 1, 2, and 3 are formally accepted. Phase 4 Step 4 is the current
accepted implementation boundary:

```text
34 migrations
19 sequential tests
9 concurrency tests
540 PASS
0 FAIL
3 understood WARN
Resource observation: RECORDED
Performance thresholds: NOT_EVALUATED
```

## Active Architecture Boundary

Phase 4 Step 5 extends the accepted controlled Approval Action and independence
boundary with explicit delegation lineage, bounded delegated-authority use,
`JOINT_EXERCISE`, `CONCURRENT_HOLDING`, and `CHAIN_PARTICIPATION` enforcement,
immutable `APPROVE` duties, and policy-defined prohibited-duty combinations.
It uses persisted identities, Authority Grants, request dependencies, and
approval-chain identifiers; it does not infer conflicts from titles, groups,
time proximity, or free-form text.

Step 6 stage satisfaction and finalization and Step 7 independent-connection
approval races remain future work.

## Migration Execution Boundary

The current clean-install Foundation migration contract is `5s` lock wait,
`1min` statement execution, and `1min` idle-in-transaction, all established
with `SET LOCAL`. A statement observed above ten seconds requires investigation
even while broader performance budgets remain observation-only. The active
phase gate executes the static migration-timeout validator before database
execution.
