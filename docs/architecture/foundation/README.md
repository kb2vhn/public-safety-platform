# Platform Foundation Documentation

> **Architecture status:** Normative and under active refinement.
>
> **SQL status:** Initial Foundation migrations `000–099` exist. Structural presence does not imply complete runtime, deployment, or operational enforcement.

## Purpose

The Platform Foundation is a domain-neutral layer for trust, identity, authorization, governance, compliance, lifecycle, resilience, resource governance, observability, and accountable decision recording.

Potential consumers include public safety, municipal finance, human resources, records management, permitting, fleet and asset systems, and future integrated services.

The Foundation does not contain CAD, RMS, Evidence and Property, payroll, procurement, Fire/EMS workflow, or vendor-specific business logic.

## Non-Negotiable Principles

1. Trust must be established before protected identity and authority are accepted.
2. A certificate, password, MFA result, session, or role does not independently grant access.
3. Authentication establishes identity; authorization establishes bounded authority.
4. Future runtime services will assemble explicit authorization inputs and
   Decision Supporting Records, invoke controlled workflows, and coordinate
   external interactions. PostgreSQL will independently verify the minimum
   database-boundary conditions required before completing a Protected
   Operation.
5. No non-infrastructure actor may possess unrestricted platform authority.
6. Role accumulation must not create an effective unrestricted account.
7. Required decision stages fail closed when they return `FAIL` or `NOT_EVALUATED`.
8. Material decisions must retain an attributable record.
9. Policies, agreements, controls, rules, and governed documents used in decisions must be versioned and integrity-verifiable.
10. Current state must not silently overwrite historical state.
11. Shared infrastructure does not create centralized organizational authority.
12. Authorization is bounded by identity, organization, service, purpose, operation, governed scope, classification, and time.
13. External Monitoring Systems, Delivery Destinations, Integration Contracts,
    and External-System Adapters must remain replaceable.
14. Workloads and resource consumption must be attributable and bounded.
15. Availability, recovery, and degraded operation must be governed before production use.
16. Domain-specific concepts belong in modules; the Foundation uses neutral shared concepts and extension points.
## Documentation Groups

### Boundaries, Trust, and Database Enforcement

- [Foundation Terminology and Domain Neutrality](foundation-terminology-and-domain-neutrality.md)

- [Platform Boundaries](platform-boundaries.md)
- [Authentication and Authorization Evaluation](authentication-and-authorization-evaluation-model.md)
- [Database Security](database-security-model.md)
- [Schema Naming Conventions](schema-naming-conventions.md)
- [SQL Migration Map](sql-migration-map.md)

### Organizations, Services, Identity, and Eligibility

- [Organization and Governed Scope](organization-and-governed-scope-model.md)
- [Service Participation and Federation](service-participation-and-federation-model.md)
- [Organizational Attestation and Access Eligibility](organizational-attestation-and-access-eligibility-model.md)

### Approval and Authorization

- [Authorization Evaluation Contract](authorization-evaluation-contract.md)

- [Approval Framework](approval-framework.md)
- [Authority and Authorization](authority-and-authorization-model.md)
- [Authorization Lease](authorization-lease-model.md)
- [Decision Record Repository](decision-record-repository.md)

### Governance, Classification, and History

- [Data Classification and Information Governance](data-classification-and-information-governance-model.md)
- [Governed Document and Policy Versioning](governed-document-and-policy-versioning-model.md)
- [Lifecycle Versioning and Historical Lineage](lifecycle-versioning-and-historical-lineage-model.md)

### Compliance, Assurance, Findings, and Risk

- [Compliance and Control Framework](compliance-and-control-framework.md)
- [Common Security Control Catalog](common-security-control-catalog.md)
- [Compliance Profile Versioning](compliance-profile-versioning-model.md)
- [Control Implementation and Assurance Artifact Model](control-implementation-and-assurance-artifact-model.md)
- [Security Finding, Exception, and Remediation](security-finding-exception-and-remediation-model.md)
- [Risk Assessment and Treatment](risk-assessment-and-treatment-model.md)
- [Threat and Abuse Case](threat-and-abuse-case-model.md)

### Resilience, Performance, Experience, and Observability

- [Resilience, Availability, and Recovery](resilience-availability-and-recovery-model.md)
- [Performance, Efficiency, and Resource Governance](performance-efficiency-and-resource-governance-model.md)
- [Client Experience and Accessibility](client-experience-and-accessibility-model.md)
- [Observability, Health, and Operational Telemetry](observability-health-and-operational-telemetry-model.md)

## Current Implementation Boundaries

The `000–099` migrations establish the initial Foundation data model, selected controlled APIs, security inventory, and validation views.

The following remain incomplete until separately implemented and tested:

- Final production ownership and login-role topology,
- Complete runtime grants and controlled write paths,
- Full append-only enforcement,
- Off-host integrity anchoring and protected export,
- Migration-checksum population and enforcement,
- Production Go services,
- External-system adapters and delivery workers,
- Backup protection and restoration validation,
- Break-glass procedures,
- Trusted rebuild and compromise recovery,
- Complete behavioral and concurrency tests.

## Change Discipline

A Foundation change should normally update:

1. The governing architecture document,
2. The applicable SQL migration or a new migration,
3. The migration map,
4. Automated tests,
5. Operational or deployment documentation when the change crosses the database boundary.
