# Platform Compliance and Control Framework

## Purpose

This document defines the domain-neutral compliance capabilities provided by the Platform Foundation.

The Foundation does not declare a system compliant merely because a named framework, encryption feature, certificate, MFA method, or audit log exists.

Compliance requires identifiable requirements, assigned controls, implemented safeguards, persistent evidence, assessment, findings, remediation, exceptions, risk decisions, and accountable authorization.

## Core Principle

```text
External or Internal Requirement
        ↓
Compliance Profile Requirement
        ↓
Common Control
        ↓
Control Implementation
        ↓
Implementation Evidence
        ↓
Assessment
        ↓
Finding or Satisfactory Result
        ↓
Remediation, Exception, or Risk Decision
        ↓
Current Attested Status
```

No layer may be skipped when policy requires it.

## Foundation Responsibilities

The Foundation provides reusable models for:

- Control identifiers and control families
- Control objectives
- Control ownership
- Control applicability
- Control implementations
- Shared and inherited controls
- Evidence requirements
- Evidence collection
- Assessments
- Findings
- Deficiencies
- Corrective action
- Remediation tracking
- Compensating controls
- Exceptions
- Risk acceptance
- Review schedules
- Attestation
- Historical status
- Compliance profile mapping
- Decision Records and Justification Chains

## Foundation Non-Responsibilities

The Foundation does not hard-code:

- CJIS-specific operational procedures
- HIPAA-specific healthcare workflows
- IRS Publication 1075 implementation details
- PCI DSS payment-processing architecture
- State-specific records schedules
- Local facility procedures
- Vendor implementation instructions

Those belong in compliance profiles, domain models, and deployment documentation.

## Compliance Scope

Compliance applicability may be scoped by:

- Organization
- Service
- Domain
- Module
- System
- Environment
- Facility
- Network segment
- Data classification
- Record type
- Provider
- Jurisdiction
- Regulatory authority
- Effective period

A control may be applicable in one scope and not applicable in another.

## Control States

A control implementation may have states such as:

```text
NOT_APPLICABLE
PLANNED
PARTIALLY_IMPLEMENTED
IMPLEMENTED
OPERATING
INEFFECTIVE
DEFICIENT
SUSPENDED
SUPERSEDED
RETIRED
```

A state alone is not sufficient. It must be supported by evidence and assessment records.

## Assessment Results

Assessment results may include:

```text
SATISFIED
PARTIALLY_SATISFIED
NOT_SATISFIED
NOT_APPLICABLE
NOT_TESTED
INCONCLUSIVE
```

A required `NOT_TESTED` or `INCONCLUSIVE` result must not be represented as compliant.

## Shared and Inherited Controls

A service may inherit controls from:

- Platform infrastructure
- Identity provider
- Network provider
- Data center
- Cloud provider
- Managed service provider
- Organizational policy
- Shared security service

Inheritance must be explicit and must identify:

- Control source
- Responsible organization
- Scope
- Evidence
- Effective period
- Review requirements
- Limitations
- Termination effects

## Compliance Status

Compliance status must be derived from current records, not manually asserted as an unsupported Boolean.

A status calculation should consider:

- Applicable profile requirements
- Required controls
- Control implementations
- Evidence freshness
- Assessment results
- Open findings
- Accepted risks
- Active exceptions
- Remediation deadlines
- Expired documents
- Scope changes

## Prohibited Claims

The platform must not infer:

```text
"Uses MFA" = Compliant
"Uses encryption" = Compliant
"Has a certificate" = Compliant
"Uses Zero Trust" = Compliant
"Has audit logs" = Compliant
"Passed once" = Currently compliant
```

## Architectural Invariants

1. Compliance is derived from persistent records.
2. Every applicable requirement maps to one or more controls.
3. Every implemented control identifies responsible parties and scope.
4. Evidence has provenance, integrity, collection time, and retention.
5. Assessments are attributable and versioned.
6. Findings cannot be erased by changing status fields.
7. Exceptions and risk acceptance are explicit, approved, scoped, and time-bounded.
8. Compliance profiles are separate from the generic Foundation.
9. Current compliance status does not rewrite historical status.
10. Every material compliance action creates a Decision Record.
