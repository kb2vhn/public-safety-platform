# Platform Foundation Documentation

## Purpose

The Platform Foundation is a domain-neutral security, governance, authorization, compliance, resilience, lifecycle, and decision-recording layer intended for reuse across multiple systems.

Potential consumers include:

- Public safety
- Municipal finance
- Human resources
- Records management
- Fleet and asset management
- Permitting
- Healthcare-connected services
- Future vendor-integrated services

The Foundation does not contain CAD, RMS, evidence, payroll, procurement, permitting, healthcare workflow, or vendor-specific business logic.

## CIA Triad Architecture

### Confidentiality

The Foundation protects confidentiality through:

- Trust separation
- Device and identity assurance
- Least privilege
- Organization and jurisdiction scope
- Purpose limitation
- Data classification
- Approval
- Short-lived Authorization Leases
- Revocation
- Cross-organization access controls
- No non-infrastructure God Access
- Role accumulation and incompatible-authority checks

### Integrity

The Foundation protects integrity through:

- PostgreSQL independent verification
- Controlled database APIs
- Append-only Decision Records
- Immutable versions
- Policy and document hashes
- Historical lineage
- Separation of duties
- Evidence provenance
- Assessment records
- Tamper-evident controls
- Protection from silent overwrites

### Availability

The Foundation protects availability through:

- Service criticality
- Resilience planning
- Recovery objectives
- Backup and restoration
- Failover
- Dependency management
- Degraded operating modes
- Provider transition
- Capacity controls
- Denial-of-service protections
- Disaster recovery exercises
- Recovery validation
- Reconciliation after restoration

## Non-Negotiable Principles

1. Trust must be established before identity is evaluated.
2. A valid certificate does not grant access.
3. MFA does not grant access.
4. Authentication establishes identity, not authority.
5. Except for the unavoidable PostgreSQL infrastructure-superuser boundary, no human, application, service account, or database role may possess unrestricted platform authority.
6. Role accumulation must not create effective God Access.
7. The Go backend evaluates and attests.
8. PostgreSQL independently verifies and enforces.
9. Every `PASS`, `FAIL`, `NOT_REQUIRED`, and `NOT_EVALUATED` result must have a persistent record trail.
10. Every policy, agreement, control, rule, and governed document used in a decision must be versioned, approved, effective-dated, and integrity-verifiable.
11. Current state must not overwrite historical state.
12. Shared infrastructure does not create centralized organizational authority.
13. Data classification must affect handling and access decisions.
14. Authorization must be scoped by identity, organization, service, purpose, classification, operation, jurisdiction, and time.
15. Compliance must be represented through reusable controls, implementations, evidence, assessments, findings, remediation, exceptions, and risk decisions.
16. A compliance framework name or product feature must never be treated as proof of compliance.
17. Threats and abuse cases must be explicitly modeled.
18. Availability, recovery, and degraded operation must be governed before implementation.
19. Every material decision, lifecycle change, control assessment, finding, remediation action, exception, risk acceptance, failover, and recovery action must produce a persistent record.
20. Every material workload, query, job, integration, and storage consumer must be attributable and resource-bounded.
21. Monitoring must provide operational context, not only infrastructure symptoms.
22. Monitoring and telemetry providers remain replaceable and may not become hidden core dependencies.

## Documentation Set

```text
platform-boundaries.md
trust-and-decision-engine-model.md
database-security-model.md
organization-and-jurisdiction-model.md
service-participation-and-federation-model.md
organizational-attestation-and-access-eligibility-model.md
approval-framework.md
authority-and-authorization-model.md
authorization-lease-model.md
decision-record-repository.md
data-classification-and-information-governance-model.md
governed-document-and-policy-versioning-model.md
lifecycle-versioning-and-historical-lineage-model.md
compliance-and-control-framework.md
common-security-control-catalog.md
control-implementation-and-evidence-model.md
risk-assessment-and-treatment-model.md
compliance-profile-versioning-model.md
security-finding-exception-and-remediation-model.md
threat-and-abuse-case-model.md
resilience-availability-and-recovery-model.md
performance-efficiency-and-resource-governance-model.md
client-experience-and-accessibility-model.md
observability-health-and-operational-telemetry-model.md
schema-naming-conventions.md
sql-migration-map.md
```

## Architectural Layers

```text
Platform Foundation
        ↓
Compliance Profiles
        ↓
Domain Platforms
        ↓
Domain Modules
        ↓
Service and Deployment Profiles
        ↓
Provider Adapters and User Interfaces
```

Dependencies must never flow from the Foundation into a particular regulatory framework, domain module, deployment, or vendor product.


## Relationship to Project Goals

The project-level performance and efficiency goal is documented in:

```text
docs/goals/performance-and-efficiency-goals.md
```

The goal states the intended long-term outcome.

The Foundation performance and client-experience models define the requirements every implementation must follow.


## Operational Simplicity Goal

The project-level operational simplicity and supportability goal is documented in:

```text
docs/goals/operational-simplicity-and-supportability-goals.md
```

The Foundation observability and resource-governance models turn that goal into enforceable architecture.
