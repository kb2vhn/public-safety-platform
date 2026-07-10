# Platform Foundation Boundaries

## Purpose

This document defines the responsibilities and limits of the reusable Platform Foundation.

## Foundation Responsibilities

The Foundation owns reusable capabilities for:

- Cryptographic participation and device trust
- Identity references and lifecycle
- Organizations and jurisdictions
- Service participation and federation
- Attestation authorities
- Access Eligibility
- Approval
- Authority and authorization policy
- Authorization Leases
- Decision Records and Justification Chains
- Data classification and information governance
- Policy and governed-document versioning
- Lifecycle and historical lineage
- Common security controls
- Compliance profile mappings
- Control implementations
- Evidence and assessments
- Findings, remediation, exceptions, and risk acceptance
- Retention and legal holds
- Integration contracts
- Audit integrity
- Platform configuration
- Performance and resource governance
- Client experience and accessibility
- Canonical health, observability, and operational telemetry
- Monitoring-provider subscription contracts

## Compliance Boundary

The Foundation defines how controls, evidence, assessments, findings, risk, exceptions, and profiles are represented.

The Foundation does not hard-code the substantive requirements of CJIS, HIPAA, IRS Publication 1075, PCI DSS, or any state-specific framework.

Those requirements belong in separately versioned compliance profiles.

## Domain Responsibilities

Domain platforms define domain objects, operations, workflows, classifications, authority definitions, lifecycle states, policies, and control implementations.

## Deployment Responsibilities

A deployment defines the actual administrative, technical, physical, personnel, facility, provider, and operational implementation for a specific environment.

## External Providers

External systems may supply inherited controls or evidence through explicit contracts.

Provider claims must not be accepted without scope, provenance, validation, and current evidence.

## No Centralized Authority by Hosting

The Platform Operator may host infrastructure without becoming Service Owner, Data Owner, Personnel Authority, Access Sponsor, Operational Supervisor, Approval Authority, Compliance Assessor, or Risk Accepting Authority.

## Architectural Invariants

1. The Foundation remains domain-neutral and framework-neutral.
2. Domain modules and compliance profiles depend on Foundation contracts.
3. The Foundation does not depend on a domain, framework, or vendor.
4. Shared hosting does not imply unrestricted authority.
5. Compliance claims require records and assessment.
6. External providers do not replace the Decision Record Repository.
7. Every protected operation and material compliance action is scoped, attributable, effective-dated, and recorded.
8. Performance, resource efficiency, and client accessibility are Foundation requirements.
9. High-end hardware must not be required for normal core operation.
10. Monitoring providers are replaceable consumers, not sources of truth.
11. Every material workload and integration must be attributable, bounded, and failure-contained.
