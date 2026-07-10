# Architecture Decision: Provider-Neutral Observability

## Decision

The platform will maintain canonical health, metric, performance, integration, and operational event records independently of any monitoring vendor.

A Go Observability Subscription Service will adapt canonical telemetry for Zabbix, OpenMetrics-compatible collectors, syslog, webhooks, SIEM platforms, and future providers.

## Reasons

- Monitoring providers may change.
- Generic infrastructure alerts frequently lack operational context.
- Provider failure must not affect core operations.
- Workloads, versions, owners, query fingerprints, and user impact must remain attributable.
- Monitoring data must follow classification, retention, and access policy.
- A provider-specific schema must not become canonical.

## Consequences

- Provider adapters require versioned contracts.
- Telemetry volume and cardinality must be bounded.
- Delivery state must be tracked.
- Provider retries must use backpressure and limits.
- Canonical health records remain available even when a provider is unavailable.
- Monitoring tools remain consumers rather than sources of truth.
