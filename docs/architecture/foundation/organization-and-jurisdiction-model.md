# Platform Organization and Jurisdiction Model

## Purpose

This document defines organizations, organizational units, relationships, jurisdictions, ownership roles, and authority boundaries.

## Organization

An Organization is an independently identifiable legal, administrative, operational, or contractual entity with a stable identifier.

Names may change without changing identity.

## Organizational Unit

An Organizational Unit is an internal subdivision such as a department, bureau, station, division, office, or team.

The model must support organizations with complex hierarchies and small organizations with minimal structure.

## Organizational Roles

The Foundation distinguishes:

- Platform Operator
- Service Owner
- Participating Organization
- Employing Organization
- Identity Authority
- Technical Authority
- Personnel Authority
- Access Sponsor
- Operational Supervisor Authority
- Data Owner
- Data Custodian
- Jurisdiction Authority

No role is inferred from another.

## Relationships

Relationships must be explicit, scoped, effective-dated, versioned, and historically preserved.

Examples:

```text
OPERATES_PLATFORM_FOR
OWNS_SERVICE_FOR
PARTICIPATES_IN_SERVICE
PROVIDES_TECHNICAL_SERVICES_FOR
PROVIDES_PERSONNEL_ADMINISTRATION_FOR
HOLDS_DATA_CUSTODY_FOR
OWNS_DATA_FOR
SUPERVISES_ASSIGNMENTS_FOR
DELEGATES_AUTHORITY_TO
```

## Jurisdiction

A Jurisdiction is a legal, geographic, administrative, operational, or service boundary.

It is separate from Organization.

Jurisdictions may overlap.

## Jurisdiction Authority

Jurisdiction Authority must identify the purpose for which authority applies.

Examples:

- Dispatch
- Law enforcement
- Fire response
- EMS response
- Record creation
- Data ownership
- Evidence custody
- Mutual aid

Authority for one purpose does not imply another.

## Scope Intersection

Effective authority must remain inside the intersection of:

- Requested scope
- Participation scope
- Eligibility scope
- Assignment scope
- Authority scope
- Approval scope
- Classification scope
- Supervisor scope

An empty intersection results in denial.

## Historical Preservation

Renames, mergers, splits, transfers, and dissolutions must not rewrite historical context.

## Architectural Invariants

1. Organizations use stable identifiers.
2. Organization name is not identity.
3. Platform Operator, Service Owner, Data Owner, and Data Custodian remain distinct.
4. Jurisdiction is separate from Organization.
5. Overlapping jurisdictions are supported.
6. Relationships are effective-dated and versioned.
7. Hosting does not imply ownership.
8. PostgreSQL independently verifies organization and jurisdiction claims.
