# Federated Multi-Organization Attestation

## Purpose

The Public Safety Platform may be operated as a shared service supporting multiple independent organizations.

The organization operating the platform may not be the organization that:

* Employs the person
* Manages the person’s identity
* Manages the person’s device
* Sponsors the access
* Supervises the person
* Owns the operational data
* Owns the service being accessed

The platform must support multiple independent IT, personnel, departmental, supervisory, service-owner, and data-owner authorities.

No architectural rule may assume that a single county, municipality, department, or agency owns every part of the access decision.

---

## Organizational Roles

For each protected service or access request, the platform may identify:

* Platform Operator
* Service Owner
* Participating Organization
* Employing Organization
* Identity Authority
* Technical Authority
* Personnel Authority
* Access Sponsor
* Operational Supervisor Authority
* Data Owner
* Data Custodian
* Jurisdiction Authority

One organization may fulfill multiple roles.

Different organizations may fulfill each role.

The required roles are determined by versioned policy and the applicable Service Participation Agreement.

---

## Platform Operator

The Platform Operator manages the shared platform infrastructure.

The Platform Operator may be responsible for:

* Platform hosting
* Database operation
* Core platform security
* Trust Provider registration
* Shared-service availability
* Platform-wide emergency suspension
* Technical standards
* Participating-organization onboarding

The Platform Operator does not automatically own:

* Participating-agency personnel decisions
* Participating-agency operational need
* Participating-agency supervisory validation
* All records stored by the platform
* All module access decisions

Operating the infrastructure must not create unrestricted authority over every participating organization’s operations.

---

## Service Owner

The Service Owner governs a specific shared service.

Examples include:

* County 911 Communications as the CAD Service Owner
* Regional Records Consortium as the RMS Service Owner
* County Evidence Board as the shared Evidence Service Owner

The Service Owner may define:

* Participation requirements
* Permitted organizations
* Service-level policies
* Required attestation categories
* Minimum technical standards
* Permitted authority definitions
* Shared-service review requirements

The Service Owner does not replace the employing organization, personnel authority, or access sponsor unless it has explicitly been assigned those responsibilities.

---

## Service Participation Agreement

A Service Participation Agreement defines the relationship between a shared service and a participating organization.

The agreement may identify:

* Service
* Service Owner
* Participating Organization
* Permitted modules
* Permitted operations
* Data ownership rules
* Data-custody rules
* Organization and jurisdiction scope
* Accepted identity providers
* Accepted Trust Providers
* Accepted Technical Authorities
* Accepted Personnel Authorities
* Accepted Access Sponsors
* Accepted Supervisor Authorities
* Required approval policies
* Effective time
* Expiration time
* Suspension state
* Termination state

Access must not exceed the limits established by the applicable Service Participation Agreement.

---

## Attestation Authority

An Attestation Authority is an organization, organizational unit, role, or delegated provider authorized to attest to a defined category of fact.

Attestation categories may include:

```text
TECHNICAL_READINESS

IDENTITY_PROVISIONING

PERSONNEL_RELATIONSHIP

DEPARTMENTAL_NEED

SERVICE_PARTICIPATION

OPERATIONAL_ASSIGNMENT

PRESENCE_FOR_DUTY

QUALIFICATION_STATUS

DATA_ACCESS_SPONSORSHIP
```

An Attestation Authority record may define:

* Attestation category
* Authorizing organization
* Attesting organization
* Authorized role or identity
* Applicable service
* Applicable module
* Applicable organization
* Applicable jurisdiction
* Effective time
* Expiration time
* Delegation source
* Revocation state

Department names such as IT or HR must not be hard-coded as universal authorities.

The platform evaluates which authority is permitted to make a particular attestation within the applicable organization and service context.

---

## Delegated Attestation

An organization may delegate an attestation responsibility to another approved organization or provider.

Examples include:

* A village delegates technical operations to county IT.
* Several towns use a regional IT authority.
* A municipality delegates personnel administration to a shared HR service.
* A small agency authorizes its department head or municipal administrator to provide personnel attestation.
* A regional communications center provides operational supervision for participating dispatch personnel.

Delegation must be:

* Explicit
* Scoped
* Time-bounded
* Attributable
* Revocable
* Approved according to policy

A delegated authority must not attest outside the scope granted by the delegating organization.

---

## Operational Access Eligibility Grant

Operational Access Eligibility must be represented as one or more scoped grants.

A grant may include:

* Person
* Identity
* Employing Organization
* Participating Organization
* Service
* Module
* Eligible authority definitions
* Organization scope
* Jurisdiction scope
* Resource scope
* IT or Technical Attestation
* Personnel Attestation
* Departmental Sponsorship
* Service-owner approval
* Effective time
* Review time
* Expiration time
* Restrictions
* Current state
* Creation Decision Record

A person may hold multiple eligibility grants for different:

* Organizations
* Services
* Modules
* Jurisdictions
* Assignments
* Authority definitions

There must not be a single global eligibility flag that silently applies to all organizations and services.

---

## Policy-Resolved Attestation Requirements

The platform must determine required attestations from the requested service, organization, operation, and scope.

Example:

```text
Shared RMS access for a village officer may require:

PASS - Platform participation agreement active

PASS - Approved Technical Authority attestation

PASS - Employing Organization personnel attestation

PASS - Police Department access sponsorship

PASS - RMS Service Owner participation requirements

NOT_REQUIRED - Current shift presence validation
```

A live CAD dispatcher session may require:

```text
PASS - Platform participation agreement active

PASS - Approved Technical Authority attestation

PASS - Personnel Authority attestation

PASS - Communications Department sponsorship

PASS - CAD Service Owner authorization

PASS - Current shift assignment

PASS - Shift Supervisor presence validation
```

Attestation requirements must be configurable and versioned.

---

## Supervisory Activation

A supervisor may activate only authority already permitted by the applicable eligibility grant.

The supervisor’s organization must be authorized to provide operational validation for the applicable service and assignment.

A county 911 supervisor may validate a county dispatch assignment.

A municipal police supervisor may validate a municipal officer assignment.

A regional supervisor may validate assignments only when a participation agreement or delegation explicitly grants that responsibility.

The following invariant applies:

> Active operational authority must be equal to or narrower than the combined scope of the eligibility grant, Service Participation Agreement, Authority Grant, and supervisor’s validation authority.

---

## Cross-Organization Access

Access across organizational boundaries must be explicit.

The platform must evaluate:

* Requesting organization
* Employing organization
* Service-owning organization
* Data-owning organization
* Target organization
* Jurisdiction
* Participation agreement
* Data-sharing agreement
* Authority scope
* Approval requirements

Membership in one participating organization must not automatically provide access to another organization’s data.

---

## Data Ownership and Custody

The organization hosting the database may be the Data Custodian without being the Data Owner.

For shared services, the platform must distinguish:

```text
Data Owner
    Organization with authoritative ownership of the record

Data Custodian
    Organization operating the system that stores and protects the record

Service Owner
    Organization governing the shared service

Platform Operator
    Organization operating the platform infrastructure
```

These roles may be held by the same organization, but they must remain conceptually separate.

---

## Scoped Revocation

Revocation applies to the authority owned by the revoking organization.

Examples include:

* A Personnel Authority may revoke the personnel relationship it owns.
* A Technical Authority may revoke a device or technical attestation it manages.
* An Access Sponsor may withdraw the sponsorship it created.
* A Service Owner may suspend participation in that service.
* A Supervisor may withdraw the operational validation they issued.
* A Platform Operator may suspend platform participation for a platform-wide security reason.

Revocation must invalidate all dependent eligibility grants, operational validations, sessions, and Authorization Leases.

Revocation must not silently remove unrelated authority that does not depend on the revoked relationship.

---

## Architectural Invariants

1. The Platform Operator is not automatically the personnel, operational, or data authority for all participating organizations.

2. Department names such as IT and HR must not be hard-coded as universal attestation authorities.

3. Every attestation must identify the organization and authority responsible for the attested fact.

4. Every shared-service access decision must identify the applicable Service Participation Agreement.

5. A person may hold multiple independently scoped eligibility grants.

6. No global eligibility flag may authorize access across unrelated services or organizations.

7. Cross-organization access must be explicit and policy-controlled.

8. Delegated attestation must be explicit, scoped, time-bounded, attributable, and revocable.

9. Supervisory activation must remain within the supervisor’s organizational and service scope.

10. Data Owner, Data Custodian, Service Owner, and Platform Operator must remain distinguishable.

11. Revocation must invalidate dependent authority without automatically destroying unrelated authority.

12. PostgreSQL must independently verify organizations, delegated authorities, participation agreements, scopes, and expiration times.

13. Every attestation, delegation, sponsorship, activation, denial, expiration, suspension, and revocation must produce a Decision Record.

---

## Final Principle

Shared infrastructure must not become centralized organizational authority.

The platform may be operated by one county while serving many municipalities, villages, departments, and agencies.

Each participating organization remains authoritative for the facts it owns.

The platform combines those independently owned facts through explicit participation agreements, delegated authorities, scoped attestations, and policy-controlled eligibility grants.

The result must always show:

* Which organization owned each decision
* Which organization supplied each attestation
* Which service was being accessed
* Which organization owned the data
* Which scope was approved
* Which supervisor activated the authority
* Which relationships and policies permitted the access

