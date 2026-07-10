# Platform Data Classification and Information Governance Model

## Purpose

This document defines reusable classification and governance for all domains.

Classification must influence handling and access.

## Classification Dimensions

- Confidentiality
- Regulatory category
- Operational sensitivity
- Financial sensitivity
- Disclosure status
- Integrity requirement
- Availability requirement
- Retention category
- Ownership
- Residency

## Classification Sources

Classification may originate from:

- Service
- Domain
- Module
- Record type
- Individual record
- Field
- Attachment
- Data Owner
- Regulation
- Workflow state
- Imported source

## Effective Classification

The effective result is normally the most restrictive compatible combination of all applicable classifications.

## Classification Lifecycle

Actions may include:

```text
CLASSIFY
RECLASSIFY
ADD_CATEGORY
REMOVE_CATEGORY
RESTRICT
RELEASE
SEAL
UNSEAL
PLACE_LEGAL_HOLD
RELEASE_LEGAL_HOLD
APPROVE_DISPOSITION
```

Each action preserves prior state.

## Handling Requirements

Classification may affect:

- View
- Modify
- Export
- Print
- Share
- Redact
- Encrypt
- Retain
- Dispose
- Deliver to providers
- Require enhanced approval
- Require enhanced Decision Recording

## Composite Chains

High-level checks such as:

```text
PASS - CJIS handling requirements satisfied
```

must expand into child evaluations.

## Policy Versioning

Every handling decision references:

- Stable policy identifier
- Version and revision
- Approval date
- Effective period
- Specific rule
- Document hash
- Engine version
- Evaluation timestamp

## Architectural Invariants

1. Classification is multidimensional.
2. Classification affects authorization.
3. High-level conclusions expand into child evaluations.
4. Every child result has supporting records.
5. Reclassification preserves history.
6. Data Owner permission is derived from real agreements, purpose, scope, and policy.
7. PostgreSQL verifies material supporting records.
