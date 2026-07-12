# Architecture Decision: External-System-Independent Observability

> **Decision status:** Accepted Foundation direction.

## Decision

The Platform Foundation maintains canonical health, metric, performance, integration, and operational event records independently of any external monitoring system or vendor.

A future Observability Subscription Service may translate canonical telemetry for configured Delivery Destinations such as:

- Zabbix
- OpenMetrics-compatible collectors
- Syslog receivers
- Webhooks
- SIEM platforms
- Other external monitoring systems

## Defined Terms

- **External Monitoring System:** A system that consumes canonical telemetry.
- **Delivery Destination:** One configured endpoint that receives telemetry.
- **External-System Adapter:** A replaceable translator between canonical telemetry and one destination protocol.
- **Integration Contract:** The versioned delivery contract used by an adapter.

The unqualified word “provider” is not used for these concepts.

## Reasons

- External monitoring systems may change.
- Self-hosted and commercial systems must be treated consistently.
- Failure of an external system must not affect core operations.
- Generic infrastructure alerts often lack ownership and operational context.
- Workloads, versions, owners, query fingerprints, and user impact must remain attributable.
- Monitoring data follows Data Classification, retention, and access policy.
- An external-system-specific schema must not become canonical.

## Consequences

- External-System Adapters use versioned Integration Contracts.
- Telemetry volume and cardinality are bounded.
- Delivery state is tracked per Delivery Destination and payload.
- Delivery retries use backpressure and defined limits.
- Canonical health records remain available when a destination is unavailable.
- External monitoring systems remain replaceable consumers rather than sources of truth.
