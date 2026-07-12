# Platform Foundation Documentation

> **Architecture status:** Normative and under active refinement.
>
> **SQL status:** Initial Foundation migrations `000–099` exist. Selected
> controls are database-enforced and tested; structural presence does not imply
> complete runtime, deployment, or operational enforcement.
>
> **Current implementation phase:** Phase 3 — Authorization Decision and
> Controlled Lease Issuance.

## Purpose

The Platform Foundation is a domain-neutral layer for trust, identity,
authentication inputs, sessions, authorization, approvals, accountable
Decision Records, governance, compliance, lifecycle, resilience, resource
governance, observability, and integration intent.

Potential consumers include public safety, municipal administration, finance,
human resources, records management, permitting, fleet and asset systems,
utilities, education, and future integrated services.

The Foundation does not contain CAD incidents, RMS cases, evidence custody,
payroll, procurement, Fire or EMS workflow, student records, permits, utility
accounts, or other module-owned business records.

## Non-Negotiable Principles

1. Trust must be established before protected identity or authority is
   accepted.
2. A certificate, password, MFA result, Authentication Assertion, session,
   role, approval, network location, or lease secret does not independently
   grant access.
3. Authentication establishes identity context; authorization establishes
   bounded authority.
4. Future Go services will gather evidence and coordinate workflows;
   PostgreSQL will independently verify selected protected operations and
   controlled state transitions.
5. No ordinary identity, application account, administrator, or accumulated
   role set may provide unrestricted platform authority.
6. Required decision stages fail closed on `FAIL` or `NOT_EVALUATED`.
7. Material decisions and lifecycle transitions must retain attributable,
   reviewable records.
8. Policies, agreements, controls, rules, and governed documents used in
   decisions must be versioned and integrity-verifiable.
9. Current state must not silently overwrite historical state.
10. Shared infrastructure does not create centralized organizational
    authority.
11. Authorization is bounded by identity, organization, Platform Service,
    Governed Purpose, Governed Operation, Protected Resource Target, Governed
    Scope, Data Classification, policy, and authoritative time.
12. External monitoring, integration, and delivery providers remain
    replaceable.
13. Workloads and resource consumption must be attributable and bounded.
14. Availability, recovery, degraded operation, and compromise recovery must
    be governed before production use.
15. Domain-specific concepts belong in modules; the Foundation uses neutral
    shared concepts and extension points.

## Accepted Phase 1 Boundary

Phase 1 is accepted at:

```text
phase-1-authentication-assertion-complete-v1
```

Accepted evidence:

```text
31 manifest migrations
31 registered migrations
10 sequential test files
1 concurrency test file
135 PASS
0 FAIL
3 understood WARN
```

Phase 1 established controlled local Authentication Assertion verification,
rejection, expiration, revocation, exact-context consumption, terminal-state
enforcement, and concurrent single-use behavior.

See:

- [Authentication Assertion Verification and Consumption Model](authentication-assertion-verification-and-consumption-model.md)
- [Phase 1 Authentication Assertion Acceptance](phase-1-authentication-assertion-acceptance.md)

## Accepted Phase 2 Boundary

Phase 2 is accepted at:

```text
phase-2-session-control-complete-v1
```

Accepted evidence:

```text
32 manifest migrations
32 registered migrations
12 sequential test files
4 concurrency test files
213 PASS
0 FAIL
3 understood WARN
```

Phase 2 established atomic session establishment, step-up, current-trust
revalidation, controlled activity, lock and administrative unlock, absolute
and inactivity expiration, revocation, termination, terminal-state
enforcement, same-transaction session events, and independent-connection
concurrency proofs.

See:

- [Session Establishment, Step-Up, and Lifecycle Model](session-establishment-step-up-and-lifecycle-model.md)
- [Phase 2 Session Establishment, Step-Up, and Lifecycle Acceptance](phase-2-session-establishment-step-up-and-lifecycle-acceptance.md)

## Current Phase 3 Boundary

Phase 3 begins with:

- [Authorization Decision and Lease Issuance Model](authorization-decision-and-lease-issuance-model.md)

Phase 3 will implement and test:

- Deterministic Authorization Policy Version selection,
- Exact request, session, operation, target, scope, and classification binding,
- Complete Authority Grant and incompatible-authority evaluation,
- Approval and separation-of-duties enforcement,
- Persistent `PASS`, `FAIL`, `NOT_REQUIRED`, and `NOT_EVALUATED` stage results,
- Finalization-once Decision Records,
- Controlled Authorization Lease issuance only from an eligible `ALLOW`,
- One Decision Record to at most one lease,
- Policy-bounded lease lifetime, audience, use mode, and usage limits,
- Exact-context lease verification and consumption,
- Multi-connection finalization, issuance, consumption, and revocation proofs.

Phase 3 must not change or bypass the accepted Phase 1 Authentication
Assertion or Phase 2 session boundaries.

## Documentation Groups

### Boundaries, Trust, Authentication, and Database Enforcement

- [Foundation Terminology and Domain Neutrality](foundation-terminology-and-domain-neutrality.md)
- [Platform Boundaries](platform-boundaries.md)
- [Authentication and Authorization Evaluation](authentication-and-authorization-evaluation-model.md)
- [Authentication Assertion Verification and Consumption Model](authentication-assertion-verification-and-consumption-model.md)
- [Phase 1 Authentication Assertion Acceptance](phase-1-authentication-assertion-acceptance.md)
- [Session Establishment, Step-Up, and Lifecycle Model](session-establishment-step-up-and-lifecycle-model.md)
- [Database Security](database-security-model.md)
- [Schema Naming Conventions](schema-naming-conventions.md)
- [SQL Migration Map](sql-migration-map.md)

### Organizations, Services, Identity, and Eligibility

- [Organization and Governed Scope](organization-and-governed-scope-model.md)
- [Service Participation and Federation](service-participation-and-federation-model.md)
- [Organizational Attestation and Access Eligibility](organizational-attestation-and-access-eligibility-model.md)

### Approval and Authorization

- [Authorization Evaluation Contract](authorization-evaluation-contract.md)
- [Authorization Decision and Lease Issuance Model](authorization-decision-and-lease-issuance-model.md)
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

The `000–099` migrations establish the initial Foundation data model, selected
controlled APIs, security inventories, and validation views.

The following remain incomplete until separately implemented and tested:

- Phase 3 deterministic Authorization Policy selection and stage resolution,
- Complete approval independence and self-approval enforcement,
- Controlled Authorization Lease issuance, use limits, renewal, and revocation,
- Complete Decision Record consistency, finalization, and integrity controls,
- Final production ownership and login-role topology,
- Least-privileged runtime grants and controlled write paths,
- Full append-only mutation protection,
- Migration-checksum population and enforcement,
- Production Go services,
- External-System Adapters and delivery workers,
- Off-host integrity anchoring and protected export,
- Backup protection and restoration validation,
- Break-glass procedures,
- Trusted rebuild and compromise recovery.

## Change Discipline

A Foundation change should normally update:

1. The governing architecture document,
2. The applicable SQL migration or a new migration,
3. The authoritative manifest when migration order changes,
4. The SQL migration map,
5. Positive and negative automated tests,
6. Concurrency tests when state can be consumed or changed simultaneously,
7. Operational or deployment documentation when the change crosses the
   database boundary.
