# Performance and Efficiency Goals

## Goal

The platform must remain responsive, predictable, and resource-efficient on modest hardware while preserving security, correctness, auditability, and operational clarity.

## Target Outcome

A small public-safety organization must be able to operate the platform without enterprise-scale hardware merely to compensate for inefficient software design.

The initial Foundation development environment is intentionally modest:

```text
2 vCPU
4 GB RAM
32 GB storage
```

This is a development constraint, not a final production sizing recommendation. It forces architecture and SQL design to remain disciplined.

## Required Qualities

- Common user actions should complete quickly and predictably.
- Database queries must have attributable owners, bounded result sets, and appropriate indexes.
- Background work must be rate-limited, observable, and resumable.
- Storage growth must be measurable and governed by retention requirements.
- Caches must not become correctness dependencies.
- Expensive operations must not be hidden inside routine request paths.
- Low-bandwidth and high-latency conditions must be considered.
- Security controls must be designed efficiently rather than bypassed for speed.
- Performance regressions must be detected by repeatable tests and operational telemetry.
- Resource budgets must exist for material services, workloads, integrations, and scheduled jobs.

## Foundation Translation

These goals are represented through:

- [Performance, Efficiency, and Resource Governance](../architecture/foundation/performance-efficiency-and-resource-governance-model.md)
- [Client Experience and Accessibility](../architecture/foundation/client-experience-and-accessibility-model.md)
- [Observability, Health, and Operational Telemetry](../architecture/foundation/observability-health-and-operational-telemetry-model.md)

SQL migrations `093–095` provide the initial structural implementation.
## Test Baseline Translation

Phase 4 Step 2 begins repeatable resource observation for the complete
Foundation SQL suite. The initial reports record timing, CPU, memory,
operating-system I/O counters, PostgreSQL statistics, WAL change, and database
size.

These first runs establish observations only. They do not create performance
budgets until enough representative runs on compatible environments support
defensible thresholds.

See [Resource Telemetry and Performance-Regression Testing](../architecture/foundation/resource-telemetry-and-performance-regression-testing-model.md).
