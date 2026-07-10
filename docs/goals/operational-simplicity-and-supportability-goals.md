# Platform Operational Simplicity and Supportability Goals

## Purpose

This document defines the long-term operational simplicity, transparency, diagnosability, and supportability goals for the platform.

The platform must remain understandable and supportable without requiring undocumented server dependencies, hidden database workloads, oversized infrastructure, or vendor-only knowledge.

## Core Goal

> Every service, workload, query, integration, background process, storage consumer, and external dependency must be attributable, documented, versioned, owned, observable, resource-bounded, failure-contained, testable, and removable.

## Operational Simplicity

The preferred operational shape is intentionally small:

```text
PostgreSQL
Go application services
Optional bounded workers
Provider adapters
Web client
```

Additional services must be introduced only when they satisfy a documented requirement that cannot be met cleanly within the existing architecture.

## No Hidden Workloads

No material SQL statement, scheduled task, report, import, export, provider job, or maintenance process may operate anonymously.

Every workload must identify:

- Stable workload identifier
- Owning component
- Owning organization or team
- Application and version
- Database role
- Workload class
- Purpose
- Trigger
- Expected frequency
- Resource budget
- Failure behavior
- Retirement path

## No Capacity Masking

Increasing CPU, memory, storage, or server count may be used for temporary containment, but it must not be treated as remediation for unexplained or unbounded resource growth.

An unexplained workload consuming hundreds of gigabytes of temporary storage is an unresolved high-severity operational finding.

## Failure Containment

A failed provider, report, background job, integration, export, or maintenance task must degrade only the dependent capability.

It must not cascade into unrelated operational services.

## Diagnosability

An operator should be able to determine quickly:

- What failed
- Which service caused it
- Which version was running
- Which workload or query was responsible
- Which organization owns it
- What users are affected
- What resource budget was exceeded
- What automatic containment occurred
- What recovery action is recommended

## Documentation Goal

Operational knowledge must reside in version-controlled documentation and system records rather than only in vendor support staff, individual memory, or undocumented server configurations.

## Final Principle

> A mission-critical system must be easier to understand during failure than during normal operation, not harder.
