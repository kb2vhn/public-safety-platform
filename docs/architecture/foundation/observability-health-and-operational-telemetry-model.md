# Platform Observability, Health, and Operational Telemetry Model

## Purpose

This document defines the domain-neutral observability, health, telemetry, alerting, and monitoring-subscription capabilities provided by the Platform Foundation.

The Foundation must expose meaningful operational context rather than only generic infrastructure symptoms.

## Core Principle

> Infrastructure measurements without component ownership, workload identity, version, user impact, and recommended response are insufficient observability.

## Canonical Operational Telemetry

PostgreSQL, Go services, workers, provider adapters, and clients may produce canonical operational telemetry.

Canonical telemetry must remain provider-neutral.

Monitoring systems such as Zabbix, Prometheus-compatible collectors, Datadog, SIEM platforms, or future providers consume this telemetry through adapters.

They do not become the platform's source of truth.

## Architecture

```text
PostgreSQL and Go Components
        ↓
Canonical Health, Metric, and Operational Event Records
        ↓
Go Observability Subscription Service
        ├── Zabbix Adapter
        ├── OpenMetrics Adapter
        ├── Syslog Adapter
        ├── Webhook Adapter
        ├── SIEM Adapter
        └── Future Provider Adapters
```

## Telemetry Types

The Foundation should distinguish:

- Health state
- Numeric metric
- Operational event
- Performance budget violation
- Capacity threshold event
- Security event
- Compliance event
- Dependency event
- Degraded-mode event
- Failover and recovery event
- Finding or remediation event

## Canonical Health Event

A canonical health event should include:

- Event identifier
- Event type
- Severity
- Service
- Component
- Deployment
- Environment
- Application version
- Database schema version where applicable
- Workload class
- Database role
- Query fingerprint where applicable
- Job or process identifier
- Correlation identifier
- Resource name
- Current value
- Threshold or expected state
- First observed time
- Last observed time
- Current status
- User impact
- Affected operation
- Owning organization or team
- Recommended action
- Supporting evidence
- Decision Record where material

## Workload Attribution

Every database and background workload must be attributable through context such as:

```text
service_id
component_id
deployment_id
application_name
application_version
database_role
workload_class
request_id
correlation_id
job_id
organization_id
purpose
```

PostgreSQL connections must use meaningful `application_name` values.

## Workload Classes

Suggested workload classes include:

```text
CORE_OPERATIONAL
INTERACTIVE
INTEGRATION
REPORTING
EXPORT
BACKGROUND
MAINTENANCE
MIGRATION
RECOVERY
```

Each class may have different limits, priorities, alert thresholds, and containment behavior.

## Database Observability

The observability model should support detection and attribution of:

- Long-running statements
- Temporary-file growth
- Disk spills
- Lock waits
- Blocked sessions
- Idle transactions
- Connection saturation
- Sequential-scan anomalies
- Query-plan regressions
- WAL growth
- Table and index growth
- Replication delay
- Storage acceleration
- Recurring query fingerprints

An alert must identify the responsible application, role, workload class, query fingerprint, and owner whenever possible.

## Integration Observability

Provider and integration telemetry should include:

- Provider identity
- Contract or adapter version
- Connection state
- Last successful exchange
- Queue depth
- Retry count
- Oldest pending item
- Acknowledgment status
- Error category
- Affected capability
- Manual fallback
- Responsible owner
- Open finding or remediation plan

A failed integration must not create an unbounded retry storm or queue.

## Subscription Service

The Go Observability Subscription Service should:

- Read canonical health and operational records
- Expose lightweight health endpoints
- Expose authenticated detailed health APIs
- Publish OpenMetrics-compatible metrics where useful
- Deliver structured events to subscribed providers
- Apply bounded retries and backpressure
- Track delivery status
- Prevent provider failure from affecting core operations
- Support provider replacement without changing canonical records

## Health Endpoints

Services may expose:

### Liveness

Indicates whether the process is functioning.

### Readiness

Indicates whether it can safely accept its intended workload.

### Detailed Health

Provides authenticated component, dependency, capacity, and degradation information.

A liveness response must not falsely imply full service readiness.

## Alert Quality

Alerts should answer:

- What is wrong?
- Where is it occurring?
- Which version is affected?
- Who owns it?
- What is the operational impact?
- Is core service still available?
- What automatic containment occurred?
- What should the operator do next?

## Example Meaningful Alert

```text
Reporting worker reporting-worker-02, version 1.8.4,
exceeded its 2 GB temporary-file budget while running
query fingerprint a91f....

Core operational workload remains healthy.
Background reporting was suspended automatically.
Owner: Reporting Services.
Recommended action: review query plan and input cardinality.
```

## Telemetry Security

Telemetry may contain sensitive operational information.

Access and delivery must be controlled by:

- Classification
- Purpose
- Organization
- Service
- Provider agreement
- Data minimization
- Retention
- Authorization Lease where applicable

Secrets, credentials, tokens, and reusable proofs must not be included.

## Retention and Volume

Telemetry retention must be policy-driven.

The platform must prevent:

- Unbounded metric cardinality
- Log amplification
- Infinite event retention
- Duplicate provider payloads
- Monitoring systems becoming a new availability dependency

## Findings and Remediation

Repeated or serious operational events may create:

- Security finding
- Performance finding
- Availability finding
- Integration finding
- Capacity finding
- Remediation plan
- Risk assessment

Closing the alert does not close the underlying finding.

## Architectural Invariants

1. Canonical telemetry is provider-neutral.
2. Monitoring providers are replaceable consumers.
3. Every material workload is attributable.
4. Generic infrastructure symptoms are enriched with operational context.
5. Provider failure cannot block core operations.
6. Retries, queues, and telemetry volume are bounded.
7. Telemetry access follows classification and purpose.
8. Repeated operational failures create findings and remediation.
9. Material degraded, failover, and recovery events create Decision Records.
10. Monitoring does not become another hidden mission-critical dependency.
