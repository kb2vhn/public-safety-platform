# Platform Organization and Governed Scope Model

> **Document status:** Normative Platform Foundation architecture.

## Purpose

Define organizations, organizational units, explicit relationships, governed scopes, ownership roles, and authority boundaries without assuming one operational domain.

## Organization

An Organization is an independently identifiable legal, administrative, contractual, or operational entity with a stable identifier.

Names may change without changing identity.

Examples include:

- Municipality
- County
- School district
- School
- Department
- Public authority
- Utility
- Emergency-services organization
- Contracted service organization
- Regional consortium

## Organizational Unit

An Organizational Unit is an internal subdivision of one Organization.

Examples include a department, bureau, office, school, campus, division, team, station, or program.

A parent Organizational Unit must belong to the same Organization.

## Organizational Roles

The Foundation distinguishes roles such as:

- Platform Operator
- Service Owner
- Participating Organization
- Employing Organization
- Identity Authority
- Technical Authority
- Personnel Authority
- Access Sponsor
- Supervisory Authority
- Data Owner
- Data Custodian
- Governed Scope Authority

No role is inferred from another.

Hosting a service does not imply ownership of the service, data, identities, or governed scopes.

## Organization Relationships

Relationships are explicit, typed, effective-dated, and historically preserved.

Examples include:

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

A relationship does not create authority beyond its exact type and scope.

## Governed Scope

A Governed Scope is a stable, typed boundary used by policy, authority, eligibility, approval, classification, or a protected operation.

It is separate from Organization.

Governed Scopes may overlap and may be hierarchical when the scope type permits hierarchy.

Examples include:

- Legal authority boundary
- Geographic service area
- Response area
- School district
- Campus
- Department
- Facility
- Taxing district
- Utility district
- Regulatory area
- Data-residency area
- Contractual service boundary

A public-safety or municipal module may define `JURISDICTION` as one `governed_scope_type`.

The Foundation does not assume that every Governed Scope is legal, geographic, or governmental.

## Governed Scope Authority

Governed Scope Authority associates one Organization with authority inside one Governed Scope for one explicit purpose and effective period.

Examples of purpose categories include:

- Service administration
- Record creation
- Data ownership
- Data custody
- Financial approval
- Permitting
- Inspection
- Student administration
- Emergency response
- Mutual assistance

Authority for one purpose does not imply authority for another.

## Scope Intersection

Effective authority remains inside the intersection of all applicable constraints, including:

- Requested Governed Scope
- Organization participation
- Access Eligibility
- Authority Grant
- Approval
- Data Classification
- Protected Resource Target
- Session
- Policy
- Time

An empty intersection results in denial.

## Historical Preservation

Renames, mergers, splits, transfers, boundary changes, and dissolution do not rewrite historical context.

A historical Decision Record references the exact Organization and Governed Scope records and versions used at evaluation time.

## Architectural Invariants

1. Organizations use stable identifiers.
2. Organization names are not identity.
3. Organizational Units cannot cross Organization boundaries.
4. Platform Operator, Service Owner, Data Owner, and Data Custodian remain distinct.
5. Governed Scope is separate from Organization.
6. Overlapping Governed Scopes are supported.
7. `JURISDICTION` is a module-defined Governed Scope type, not a universal Foundation field.
8. Relationships and authorities are effective-dated and historically preserved.
9. Hosting does not imply ownership or authority.
10. PostgreSQL independently verifies Organization and Governed Scope claims used by protected operations.
