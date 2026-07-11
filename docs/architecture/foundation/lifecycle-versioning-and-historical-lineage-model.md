# Lifecycle Versioning and Historical Lineage Model

> **Document status:** Normative Platform Foundation architecture.
>
> **Implementation status:** The Foundation SQL migrations provide an initial structural implementation. A requirement described here is not considered fully enforced until the applicable database controls, deployment roles, runtime behavior, automated tests, and operational safeguards are in place.

## Purpose

Preserve state transitions, effective periods, supersession, and lineage without silently rewriting history.

## Architectural Requirements

### Stable Identity and Historical Versions

A durable entity identifier represents the continuing subject. Material changes are represented through version records, lifecycle events, or effective-dated relationships.

### Time Semantics

The model distinguishes, where applicable:

- When an event actually occurred,
- When the platform learned of it,
- When a record became effective,
- When it ceased to be effective,
- When it was recorded.

### State Changes

State transitions identify prior state, new state, actor or source, reason, governing policy, and timestamp. Invalid transitions are rejected.

### Supersession and Correction

Correction does not destroy the original record. A correction or superseding record links to the prior record and explains the change.

### Lineage

Derived or transformed records identify their source records, transformation context, and responsible workload where material to trust or audit.

### Current-State Views

Convenience views may expose current state, but the underlying historical records remain available and authoritative.

## SQL Implementation Mapping

Migration `025_identity_lifecycle.sql` introduces identity lifecycle history. Migration `084_lifecycle_and_historical_lineage.sql` generalizes lifecycle and lineage structures.

The migration mapping identifies the current structural implementation. It does not, by itself, prove that every requirement in this document is operationally enforced.

## Validation Expectations

The Foundation SQL test framework must test the requirements that can be demonstrated at the database boundary. Runtime, deployment, recovery, and provider behavior must be tested in their respective layers.

## Related Documents

- [Governed Document and Policy Versioning](governed-document-and-policy-versioning-model.md)
- [Decision Record Repository](decision-record-repository.md)
- [Observability, Health, and Operational Telemetry](observability-health-and-operational-telemetry-model.md)
