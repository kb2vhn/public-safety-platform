# Platform Lifecycle, Versioning, and Historical Lineage Model

## Purpose

This document defines how meaning is preserved through changes in software, schemas, organizations, policies, agreements, identities, authority, classification, ownership, custody, integrations, and data.

Change is expected. Loss of historical meaning is not acceptable.

## Stable Identity and Immutable Versions

Every long-lived object has:

- Stable object identifier
- Immutable version identifier
- Version or revision number
- Effective period
- System recording time
- Change reason
- Acting identity and organization
- Policy version
- Software and schema versions
- Integrity metadata
- Decision Record

## Valid Time and System Time

The Foundation distinguishes:

- Valid time: when the fact was true or legally effective
- System time: when the platform recorded it

Critical domains may require bitemporal history.

## Material Changes

Material changes create new versions or lifecycle events.

Examples:

- Scope
- Classification
- Ownership
- Authority
- Policy
- Agreement
- Retention
- Legal hold
- Content correction
- Approval requirement

## Software and Schema Lifecycle

Material actions identify:

- Application version
- Build identifier
- Source commit
- Decision Engine version
- Policy Engine version
- Database function version
- Database schema version
- API contract version
- Provider adapter version

## Impact Analysis

Material changes should produce:

```text
NO_IMPACT
REVALIDATION_REQUIRED
LEASE_REVOCATION_REQUIRED
RECLASSIFICATION_REQUIRED
WORKFLOW_REQUIRED
MANUAL_REVIEW_REQUIRED
```

## Historical Reconstruction

The platform must answer separately:

- Was the decision valid under the rules then in force?
- Would the same request be allowed under current rules?

## Architectural Invariants

1. Stable identity survives version changes.
2. Material changes create immutable history.
3. Valid time and system time remain distinct.
4. Current state does not overwrite history.
5. Future-effective changes do not apply early.
6. Historical decisions reference historical versions.
7. Corrections create linked records.
8. Ownership, custody, and source-of-truth history are preserved.
9. Every material lifecycle change produces a Decision Record.
