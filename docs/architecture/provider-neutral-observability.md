# Provider-Neutral Observability

> **Status:** Normative architecture with initial SQL support in Foundation migrations `095–097`.

## Decision

The platform owns its operational events, health state, delivery intent, and provider-independent telemetry model.

Monitoring, logging, metrics, tracing, alerting, and SIEM products are adapters. They are not the platform's source of truth and must not become hidden dependencies of authorization, business workflow, or historical accountability.

## Canonical Model

```text
Platform action or condition
            ↓
Canonical operational event
            ↓
Provider-independent subscription or delivery intent
            ↓
Transactional outbox
            ↓
Provider adapter
            ↓
Zabbix, Graylog, Security Onion, OpenMetrics, syslog, or another provider
```

The named products are examples, not required components.

## Requirements

- Canonical events must use stable event types and versioned payload contracts.
- Events must carry sufficient organization, service, workload, correlation, and severity context.
- Provider failures must not silently discard delivery intent.
- Retry, dead-letter, acknowledgement, and provider transition state must be observable.
- A provider outage must not corrupt the authoritative operational transaction.
- Sensitive event fields must follow data-classification and disclosure rules.
- Provider-specific identifiers must not replace platform identifiers.
- Monitoring must explain operational impact, not only infrastructure symptoms.
- Health models must distinguish healthy, impaired, degraded, unavailable, unknown, and administratively suppressed states where applicable.

## Delivery Reliability

The integration outbox records provider-delivery intent in the same authoritative transaction as the event or state change when practical. Provider workers deliver asynchronously and record delivery progress without rewriting the canonical event.

## Current Implementation Mapping

- `095_observability_health_and_operational_telemetry.sql`
- `096_monitoring_subscriptions_and_provider_delivery_state.sql`
- `097_provider_integration_outbox.sql`

The current SQL is an initial data model. Provider workers, canonical payload schemas, retention policies, alert-routing behavior, and operational tests remain to be implemented.

## Related Foundation Documents

- [Observability, Health, and Operational Telemetry](foundation/observability-health-and-operational-telemetry-model.md)
- [Resilience, Availability, and Recovery](foundation/resilience-availability-and-recovery-model.md)
- [Performance, Efficiency, and Resource Governance](foundation/performance-efficiency-and-resource-governance-model.md)
