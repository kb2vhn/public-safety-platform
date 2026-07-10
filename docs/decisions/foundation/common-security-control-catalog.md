# Platform Common Security Control Catalog

## Purpose

This document defines the generic control catalog capability used by all compliance profiles and domains.

The catalog provides stable internal controls that external requirements may map to without forcing the Foundation to depend on a specific framework.

## Control Families

The Foundation should support control families such as:

```text
AC - Access Control
AT - Awareness and Training
AU - Audit and Accountability
CA - Assessment and Authorization
CM - Configuration Management
CP - Contingency Planning
IA - Identification and Authentication
IR - Incident Response
MA - Maintenance
MP - Media Protection
PE - Physical and Environmental Protection
PL - Planning
PM - Program Management
PS - Personnel Security
RA - Risk Assessment
SA - System and Services Acquisition
SC - System and Communications Protection
SI - System and Information Integrity
SR - Supply Chain Risk Management
GV - Governance
DG - Data Governance
PR - Privacy
BC - Business Continuity
```

These family identifiers are internal organizational categories unless explicitly mapped to an external standard.

## Control Definition

A Common Control should include:

- Stable control identifier
- Control family
- Title
- Objective
- Requirement statement
- Rationale
- Applicability rules
- Implementation guidance
- Evidence requirements
- Assessment procedure
- Review frequency
- Control owner role
- Control operator role
- Independent assessor requirements
- Dependencies
- Related controls
- Version
- Effective period
- Status
- Integrity hash
- Decision Record

## Control Types

Controls may be:

- Preventive
- Detective
- Corrective
- Deterrent
- Compensating
- Recovery
- Administrative
- Technical
- Physical
- Privacy-related

A control may have more than one type.

## Common Controls and System-Specific Controls

A control may be:

- Organization-wide
- Platform-wide
- Service-wide
- Domain-specific
- System-specific
- Deployment-specific
- Provider-supplied
- Inherited

## Control Enhancements

A control may have optional or required enhancements.

Enhancements must have stable identifiers and independent applicability rules.

## Control Relationships

Relationships may include:

```text
DEPENDS_ON
SUPPORTS
PARTIALLY_SATISFIES
COMPENSATES_FOR
INHERITS_FROM
SUPERSEDES
CONFLICTS_WITH
REQUIRES_EVIDENCE_FROM
```

## Versioning

A control update must preserve:

- Prior wording
- Prior evidence requirements
- Prior assessment procedure
- Prior applicability
- Effective dates
- Supersession relationships
- Historical profile mappings

## Architectural Invariants

1. Common controls are framework-neutral.
2. External requirements map to controls rather than becoming Foundation logic.
3. Control identifiers remain stable across wording changes.
4. Material changes create new versions.
5. Control applicability is explicit.
6. Required evidence and assessment procedures are defined.
7. Historical mappings remain reconstructable.
