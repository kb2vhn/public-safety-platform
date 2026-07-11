# Decision Record Repository

> **Document status:** Normative Platform Foundation architecture.
>
> **Implementation status:** The Foundation SQL migrations provide an initial structural implementation. A requirement described here is not considered fully enforced until the applicable database controls, deployment roles, runtime behavior, automated tests, and operational safeguards are in place.

## Purpose

Preserve an attributable and explainable record of material allowed, denied, not-required, and not-evaluated decision stages.

## Architectural Requirements

### Record Content

A Decision Record captures:

- Decision identifier and correlation context,
- Requester, actor, organization, service, session, and device context,
- Purpose, operation, target, jurisdiction, and classification scope,
- Governing policy and document versions,
- Required and observed approvals,
- Stage results and reason codes,
- Final result,
- Decision and evaluation timestamps,
- Integrity metadata.

### Append-Oriented Model

A material Decision Record is not edited to change history. Corrections, annotations, revocations, and supersession are represented by new linked records.

### Integrity

Database privileges, controlled write paths, triggers where appropriate, hashes, sequence or chain metadata, protected export, and off-host anchoring provide layered integrity.

No database-only mechanism can make data immutable against the database owner or superuser. Operational controls are therefore part of the complete model.

### Disclosure

Decision explanations must be useful to authorized reviewers without exposing credentials, token verifiers, unnecessary personal information, or protected provider payloads.

### Retention

Retention follows legal, regulatory, operational, and classification requirements. Deletion or disposition requires governed authority and an attributable record.

### Availability

Critical decision records must remain available during investigation and recovery. Replication or backup does not replace integrity validation.

## SQL Implementation Mapping

Migration `080_decision_record_repository.sql` provides the initial structural implementation. Migration `099` inventories append-only candidates and security posture.

Complete runtime privileges, immutable write controls, correction APIs, and off-host integrity anchoring remain pending.

The migration mapping identifies the current structural implementation. It does not, by itself, prove that every requirement in this document is operationally enforced.

## Validation Expectations

The Foundation SQL test framework must test the requirements that can be demonstrated at the database boundary. Runtime, deployment, recovery, and provider behavior must be tested in their respective layers.

## Related Documents

- [Trust and Decision Engine](trust-and-decision-engine-model.md)
- [Database Security](database-security-model.md)
- [Observability, Health, and Operational Telemetry](observability-health-and-operational-telemetry-model.md)
