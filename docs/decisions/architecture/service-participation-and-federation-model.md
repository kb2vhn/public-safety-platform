# Public Safety Platform Service Participation and Federation Model

## Purpose

This document defines how independent organizations participate in shared services provided through the Public Safety Platform.

The platform may be hosted by one organization while supporting services used, governed, supervised, and populated by many other organizations.

Examples include:

* A county operating the platform infrastructure
* A county 911 center providing CAD services
* A village operating its own daytime dispatch
* A city providing after-hours dispatch for neighboring municipalities
* A regional RMS shared by county, city, town, and village agencies
* A shared evidence or property service
* A regional fire or EMS coordination service
* A municipality using county IT while retaining its own personnel and operational authority

The architecture must not assume that the organization hosting the platform owns every service, identity, person, device, operational decision, or record.

---

# Core Principle

Shared infrastructure does not create centralized organizational authority.

The organization operating the platform may provide technical custody and availability without becoming the personnel authority, operational authority, data owner, or service owner for every participant.

Each organization remains authoritative for the facts, people, services, and records it owns.

The platform combines those facts through explicit agreements, delegated authorities, scoped access, and versioned policy.

---

# Federation Goals

The federation model must provide:

## Organizational Independence

Each participating organization must retain control over the facts and responsibilities it owns.

## Shared-Service Flexibility

A service may be used by multiple organizations under different participation terms.

## Scoped Trust

One organization’s trust, sponsorship, or authority must not automatically apply to another organization.

## Delegated Administration

An organization may delegate selected responsibilities to another organization or managed provider.

## Explainability

The platform must be able to explain which organizations, agreements, authorities, and policies permitted an action.

## Revocability

Participation, delegation, sponsorship, and access must be independently revocable.

## Historical Preservation

Changes to organizational relationships must not alter the historical meaning of prior decisions or records.

---

# Organizational Roles

The platform must distinguish among organizational roles.

One organization may fulfill several roles, but the roles must remain independently identifiable.

## Platform Operator

The organization responsible for operating the shared platform infrastructure.

Responsibilities may include:

* Platform hosting
* Database operation
* Core platform security
* Availability and disaster recovery
* Trust Provider registration
* Platform-wide technical policy
* Participating-organization onboarding
* Platform-wide security suspension

The Platform Operator does not automatically own:

* Participating personnel decisions
* Departmental access need
* Operational assignments
* All records stored in the platform
* All shared services
* All participating devices or identities

---

## Service Owner

The organization or governing body responsible for a specific platform service.

Examples include:

* County 911 Communications for a CAD service
* Regional Records Board for a shared RMS service
* County Sheriff for a shared evidence service
* Regional Fire Authority for fire-resource coordination

The Service Owner may define:

* Service participation requirements
* Minimum technical requirements
* Permitted organizations
* Service policies
* Supported authority definitions
* Required attestations
* Data-sharing requirements
* Review and suspension procedures

The Service Owner does not automatically become the owner of every record created through the service.

---

## Participating Organization

An organization approved to use a shared service.

Examples include:

* County department
* City
* Town
* Village
* Police department
* Fire department
* EMS agency
* School district
* Campus police department
* Tribal government
* State agency
* Contracted public safety provider

A Participating Organization may use one service without participating in all services available through the platform.

---

## Employing Organization

The organization responsible for the person’s employment, membership, contract, appointment, or volunteer relationship.

The Employing Organization may differ from:

* The Platform Operator
* The Service Owner
* The current Dispatch Provider
* The Data Owner
* The supervising organization for a temporary assignment

---

## Identity Authority

The organization or identity provider responsible for asserting and maintaining an identity.

Examples include:

* County Active Directory
* Municipal Active Directory
* Entra ID tenant
* Regional identity service
* Approved external identity provider

An Identity Authority establishes identity but does not independently establish operational authority.

---

## Technical Authority

The organization responsible for technical readiness and trust for identities, devices, or service connections.

Responsibilities may include:

* Device enrollment
* Certificate enrollment
* Endpoint compliance
* Identity provisioning
* Authentication configuration
* Technical suspension
* Trust-provider operation

The Technical Authority may be:

* County IT
* Municipal IT
* Regional IT authority
* Managed service provider
* Another delegated organization

---

## Personnel Authority

The organization or role authorized to attest to a person’s organizational relationship.

This may be:

* Human Resources
* Municipal administrator
* Department head
* Chief officer
* Clerk or personnel office
* Contract administrator
* Volunteer coordinator

The platform must not require that every organization have a department formally named `HR`.

---

## Access Sponsor

The organization or authority confirming that a person has a legitimate need to access a service.

The Access Sponsor identifies:

* Requested service
* Requested module
* Requested authority
* Organizational scope
* Jurisdictional scope
* Business or mission need
* Effective and review dates

---

## Operational Supervisor Authority

The organization or delegated authority permitted to validate current assignment, presence, and operational responsibility.

A supervisor may validate only within the scope assigned through policy, participation agreement, or delegation.

---

## Data Owner

The organization with authoritative ownership or responsibility for a record or defined portion of a record.

The Data Owner determines, subject to law and policy:

* Permitted use
* Sharing
* Correction
* Retention
* Disclosure
* Access scope

---

## Data Custodian

The organization responsible for storing, protecting, backing up, and technically administering data.

The Data Custodian may be the Platform Operator without being the Data Owner.

---

## Jurisdiction Authority

The organization responsible for a geographic, legal, or operational jurisdiction.

Jurisdiction authority may affect:

* Dispatch coverage
* Incident responsibility
* Records access
* Mutual aid
* Resource assignment
* Reporting requirements

---

# Services

A platform service is a defined shared capability offered to one or more organizations.

Examples include:

```text
CAD

RMS

Evidence and Property

Operational Resources

Fire Resource Coordination

EMS Resource Coordination

Fleet Services

Personnel Extensions

Reporting

GIS

Notification
```

Each service must have:

* Service identifier
* Service name
* Service Owner
* Platform Operator
* Service status
* Service policy
* Supported modules
* Effective time
* Retirement time

A service must not be assumed to apply globally to every organization.

---

# Service Participation Agreement

## Purpose

A Service Participation Agreement defines the relationship between a service and a Participating Organization.

The agreement is the platform’s authoritative record that an organization is permitted to participate in a particular service.

## Agreement Contents

A Service Participation Agreement may include:

* Agreement identifier
* Service
* Service Owner
* Participating Organization
* Platform Operator
* Effective time
* Expiration time
* Review date
* Agreement status
* Permitted modules
* Permitted operations
* Permitted authority definitions
* Organization scope
* Jurisdiction scope
* Data ownership rules
* Data custody rules
* Accepted Identity Authorities
* Accepted Technical Authorities
* Accepted Personnel Authorities
* Accepted Access Sponsors
* Accepted Supervisor Authorities
* Required Approval Policies
* Required trust policies
* Delegation rules
* Suspension rules
* Termination rules
* Applicable legal or intergovernmental agreement reference

---

# Agreement States

Possible states include:

```text
DRAFT

PENDING_APPROVAL

ACTIVE

SUSPENDED

EXPIRED

TERMINATED

SUPERSEDED
```

## DRAFT

The agreement is being developed and has no operational effect.

## PENDING_APPROVAL

The agreement awaits required organizational approval.

## ACTIVE

The organization may participate within the agreement’s approved scope.

## SUSPENDED

Participation is temporarily disabled.

## EXPIRED

The agreement reached its expiration time.

## TERMINATED

Participation was formally ended.

## SUPERSEDED

A newer agreement replaced the prior agreement.

Historical agreements must remain preserved.

---

# Participation Scope

Participation must be explicitly scoped.

Scope may include:

* Service
* Module
* Organization
* Organizational unit
* Jurisdiction
* Geographic area
* Discipline
* Incident type
* Resource type
* Record type
* Operation
* Time period

Example:

```text
Participating Organization:
Village A Police Department

Service:
Regional RMS

Permitted Modules:
RMS

Permitted Operations:
CREATE_REPORT
VIEW_OWN_AGENCY_REPORTS
SUBMIT_REPORT_FOR_APPROVAL

Organization Scope:
Village A Police Department

Jurisdiction Scope:
Village A

Cross-Organization Search:
Not permitted except through approved request policy
```

Participation in RMS must not automatically create CAD, Evidence, or platform-administration access.

---

# Multiple Agreements

An organization may have multiple participation agreements.

Example:

```text
Village A Police Department
    Regional RMS Agreement

Village A
    County CAD After-Hours Agreement

Village A Fire Department
    Regional Fire Dispatch Agreement

Village A
    County IT Managed Services Agreement
```

Each agreement must be evaluated independently.

Suspension of one agreement must not automatically suspend unrelated agreements unless platform-wide policy requires it.

---

# Attestation Authorities

An Attestation Authority is an organization, role, or delegated provider permitted to attest to a defined fact.

Attestation categories may include:

```text
IDENTITY_PROVISIONING

TECHNICAL_READINESS

DEVICE_TRUST

PERSONNEL_RELATIONSHIP

DEPARTMENTAL_NEED

SERVICE_PARTICIPATION

OPERATIONAL_ASSIGNMENT

PRESENCE_FOR_DUTY

QUALIFICATION_STATUS

DATA_ACCESS_SPONSORSHIP

DISPATCH_COVERAGE
```

An Attestation Authority must define:

* Attestation category
* Authorizing organization
* Attesting organization
* Applicable service
* Applicable organization
* Applicable jurisdiction
* Authorized roles or identities
* Effective time
* Expiration time
* Delegation source
* Revocation state

---

# Organizational Attestations

An organizational attestation is a time-bounded statement made by an approved Attestation Authority.

An attestation should include:

* Attestation identifier
* Attestation category
* Subject person, identity, device, organization, or agreement
* Attesting organization
* Acting identity
* Acting authority
* Applicable service
* Organization scope
* Jurisdiction scope
* Effective time
* Expiration time
* Reason
* Status
* Decision Record

Possible states include:

```text
PENDING

VALID

SUSPENDED

REVOKED

EXPIRED

SUPERSEDED
```

---

# Delegated Authority

## Purpose

An organization may delegate a defined responsibility to another organization or provider.

Examples include:

* A village delegates device management to county IT.
* A town delegates HR administration to a shared personnel office.
* A regional communications center supervises dispatchers from participating agencies.
* A managed service provider operates a Trust Provider.
* A city provides after-hours dispatch for a village.

## Delegation Requirements

Delegation must be:

* Explicit
* Scoped
* Time-bounded
* Attributable
* Approved
* Revocable
* Versioned

A delegation must identify:

* Delegating organization
* Receiving organization
* Delegated authority
* Applicable service
* Applicable module
* Organization scope
* Jurisdiction scope
* Effective time
* Expiration time
* Delegation depth
* Re-delegation rules
* Approval Policy
* Decision Record

---

# Delegation Limits

A delegated authority must not:

* Exceed the authority held by the delegating organization
* Apply outside the approved service
* Apply outside the approved organization
* Apply outside the approved jurisdiction
* Extend beyond its expiration
* Permit unrestricted re-delegation
* Create authority for unrelated services

Re-delegation should be denied by default unless explicitly permitted.

---

# Operational Access Eligibility

Operational access eligibility must be scoped to the participating relationship.

A person may hold separate eligibility grants for:

* Different services
* Different organizations
* Different jurisdictions
* Different modules
* Different authority definitions

Example:

```text
Person:
Officer Smith

Employing Organization:
Village A Police Department

Service:
Regional RMS

Eligible Authority:
CREATE_POLICE_REPORT

Organization Scope:
Village A Police Department

Jurisdiction Scope:
Village A
```

A separate eligibility grant would be required for county CAD access or cross-agency RMS access.

There must be no global eligibility flag that automatically applies across all services.

---

# Cross-Organization Access

Cross-organization access must be explicitly authorized.

The platform must evaluate:

* Requesting organization
* Employing organization
* Participating organization
* Service Owner
* Data Owner
* Target organization
* Jurisdiction
* Participation agreements
* Data-sharing agreements
* Authority Grants
* Approval requirements
* Purpose
* Scope
* Time

Membership in one participating organization must not automatically grant access to another organization’s records.

---

# Shared RMS Example

```text
Platform Operator:
County IT

RMS Service Owner:
Regional Records Board

Participating Organization:
Village A Police Department

Employing Organization:
Village A

Identity Authority:
Village A Active Directory

Technical Authority:
County IT

Personnel Authority:
Village Administrator

Access Sponsor:
Village Police Chief

Operational Supervisor:
Village Police Sergeant

Data Owner:
Village A Police Department

Data Custodian:
County IT
```

The county may operate the platform and store the data without becoming the owner of the village’s RMS reports.

---

# Shared CAD Example

```text
Platform Operator:
County IT

CAD Service Owner:
County 911 Communications

Jurisdiction Being Served:
Village A

Daytime Dispatch Provider:
Village A Communications

After-Hours Dispatch Provider:
County 911

Backup Provider:
City B Communications

Incident-Owning Agency:
Determined by incident and jurisdiction

Data Custodian:
County IT
```

Dynamic provider selection remains governed by the Dynamic Dispatch Coverage Model.

---

# Data Ownership

Data ownership must be assigned explicitly.

A record may include multiple ownership relationships.

Examples include:

* CAD call owned by the CAD Service Owner
* Incident responsibility assigned to a municipal agency
* RMS report owned by the reporting agency
* Evidence item owned by the seizing agency
* Attachment custody handled by the Platform Operator
* Shared resource record maintained by a regional service

The platform must not infer data ownership solely from:

* Database location
* Platform Operator
* Creating user
* Current dispatch provider
* Current Data Custodian

---

# Data Custody

Data custody defines technical responsibility.

A Data Custodian may be responsible for:

* Storage
* Encryption
* Backups
* Recovery
* Availability
* Technical access controls
* Export
* Retention execution
* Legal hold implementation

The Data Custodian must act according to the Data Owner’s policy and applicable law.

---

# Service-Level Policy

Each service may establish versioned policy for:

* Participation eligibility
* Required attestations
* Minimum trust requirements
* Permitted organizations
* Access sponsorship
* Supervisor validation
* Authority definitions
* Data sharing
* Cross-organization search
* Emergency operation
* Suspension
* Review
* Termination

Service policy must not silently override platform-wide security invariants.

---

# Participation Approval

Creation or expansion of a Service Participation Agreement may require approval from:

* Platform Operator
* Service Owner
* Participating Organization
* Data governance authority
* Legal authority
* Regional governing board
* Security authority

The Approval Framework determines the required approval stages.

No single technical administrator should be able to create an unrestricted organizational participation relationship without the required approvals.

---

# Suspension

Participation may be suspended because of:

* Security incident
* Agreement violation
* Expired agreement
* Loss of required trust
* Legal restriction
* Service termination
* Unresolved technical risk
* Organizational request
* Failure to maintain required authority records

Suspension must:

1. Preserve the agreement.
2. Create a suspension record.
3. Identify the suspending authority.
4. Identify the affected scope.
5. Invalidate dependent eligibility and leases.
6. Produce Decision Records.
7. Leave unrelated participation unaffected unless explicitly required.

---

# Termination

Termination permanently ends participation under an agreement.

Termination must define:

* Effective time
* Data access after termination
* Data export responsibilities
* Retention responsibilities
* Legal hold responsibilities
* Record custody
* Open operational work
* Active incident handling
* Identity and device revocation
* Historical access requirements

Historical records must remain attributable to the organization even after termination.

---

# Revocation Propagation

A revocation must affect only relationships that depend on the revoked authority.

Examples:

```text
Personnel Authority revokes employment relationship
        |
        v
Dependent access eligibility becomes invalid
        |
        v
Dependent operational validation becomes invalid
        |
        v
Dependent leases are rejected
```

```text
RMS participation agreement suspended
        |
        v
RMS eligibility and leases invalidated
        |
        v
Unrelated CAD agreement remains active
```

A platform-wide security suspension may affect multiple services when explicitly justified.

---

# Organizational Hierarchies

The platform must support organizations that contain:

* Departments
* Divisions
* Bureaus
* Units
* Stations
* Companies
* Precincts
* Offices
* Teams

It must also support independent organizations without complex internal structures.

A village police department must not be required to model the same hierarchy as a county government.

---

# Organization Identifiers

Organizations must have stable platform identifiers independent of display names.

Changing:

```text
Village A Police Department
```

to:

```text
Village A Department of Public Safety
```

must not silently create a new organization or alter historical records.

Organization mergers, splits, and reorganizations must be represented explicitly.

---

# Historical Preservation

Historical records must preserve:

* Participating Organization at the time
* Service Owner at the time
* Platform Operator at the time
* Data Owner at the time
* Data Custodian at the time
* Applicable agreement
* Applicable delegation
* Applicable Attestation Authorities
* Applicable policy versions

Later organizational changes must not rewrite historical context.

---

# Decision Evaluation and Authoritative Record Trail

A service-access decision must be supported by a complete, persistent record trail.

Each evaluation result must identify the authoritative record, policy, attestation, agreement, grant, approval, or lease that supports the result.

A recorded result such as:

```text
PASS - Personnel Authority accepted
```

is insufficient by itself.

The Decision Record must be able to show:

* Which Personnel Authority was accepted
* Which organization authorized that authority
* Which service and organization scope applied
* Which person or role issued the attestation
* When the attestation became effective
* When the attestation expires
* Whether it had been suspended or revoked
* Which policy required and accepted it
* Which database record supported the evaluation
* Which context was preserved at decision time

---

## Authoritative Supporting Records

A service-access decision may depend on records such as:

```text
Platform Operator Registration

Platform Service Record

Service Participation Agreement

Organization Record

Accepted Identity Authority Registration

Accepted Technical Authority Registration

Accepted Personnel Authority Registration

Access Sponsorship Record

Operational Access Eligibility Grant

Organizational Attestation

Authority Delegation

Jurisdiction Scope Grant

Data Ownership Assignment

Approval Request and Approval Actions

Operational Assignment

Operational Validation

Authority Grant

Session Record

Authorization Lease
```

These supporting records must exist independently of the final Decision Record.

The Decision Record references them and preserves the context used during evaluation.

---

## Evaluation Record Requirements

Every evaluation stage must record:

* Evaluation identifier
* Decision identifier
* Evaluation order
* Evaluation type
* Required or optional status
* Result
* Reason code
* Human-readable explanation
* Supporting record type
* Supporting record identifier
* Supporting record version
* Supporting organization
* Acting or attesting identity
* Applicable service
* Applicable organization scope
* Applicable jurisdiction scope
* Effective time
* Expiration time
* Revocation state at evaluation time
* Policy identifier
* Policy version
* Evaluating engine
* Engine version
* Evaluation timestamp
* Evaluation duration

Where a stage depends on multiple records, all supporting records must be linked.

---

## Example Service Access Evaluation

```text
Decision:
ALLOW

Requested Service:
Regional RMS

Requesting Identity:
Identity 6dd8...

Participating Organization:
Village A Police Department

Target Organization:
Village A Police Department

Evaluation Trail:

PASS - Platform Operator Active
Supporting Record:
Platform Operator Registration 1002
Organization:
County IT
Effective:
2026-01-01
Status:
ACTIVE

PASS - Service Active
Supporting Record:
Platform Service RMS-REGIONAL
Service Owner:
Regional Records Board
Status:
ACTIVE

PASS - Service Participation Agreement Active
Supporting Record:
Agreement SPA-2026-0041
Participant:
Village A Police Department
Effective:
2026-01-01
Expires:
2028-12-31
Status:
ACTIVE

PASS - Participating Organization Active
Supporting Record:
Organization ORG-0142
Status:
ACTIVE

PASS - Identity Authority Accepted
Supporting Record:
Accepted Authority IAA-0038
Authority:
Village A Active Directory
Applicable Service:
Regional RMS
Status:
ACTIVE

PASS - Technical Authority Accepted
Supporting Record:
Attestation Authority TAA-0017
Attesting Organization:
County IT
Delegated By:
Village A
Delegation Record:
DEL-2026-0092
Status:
ACTIVE

PASS - Personnel Authority Accepted
Supporting Record:
Attestation Authority PAA-0021
Authority:
Village Administrator
Organization Scope:
Village A Police Department
Status:
ACTIVE

PASS - Access Sponsor Authorized
Supporting Record:
Department Sponsorship ASP-0552
Sponsor:
Village A Police Chief
Requested Authority:
CREATE_POLICE_REPORT
Status:
VALID

PASS - Operational Access Eligibility Active
Supporting Record:
Eligibility Grant OAE-8831
Eligible Service:
Regional RMS
Eligible Authority:
CREATE_POLICE_REPORT
Organization Scope:
Village A Police Department
Expires:
2027-01-01
Status:
ELIGIBLE

PASS - Requested Organization Inside Scope
Supporting Record:
Participation Scope SPAS-0219
Organization:
Village A Police Department

PASS - Requested Jurisdiction Inside Scope
Supporting Record:
Jurisdiction Scope JUR-1027
Jurisdiction:
Village A

PASS - Data Owner Policy Satisfied
Supporting Record:
Data Ownership Assignment DOA-7710
Data Owner:
Village A Police Department
Policy:
RMS-DATA-ACCESS version 4.2

PASS - Required Approvals Satisfied
Supporting Records:
Approval Request APR-9901
Approval Action APA-9902
Approval Policy:
RMS-ACCESS-APPROVAL version 3.1

PASS - Authorization Lease Valid
Supporting Record:
Authorization Lease LEASE-77192
Issued:
2026-07-10T13:59:00Z
Expires:
2026-07-10T14:04:00Z
Status:
ACTIVE
```

The final decision is valid only because every required stage has a traceable supporting record.

---

## Evaluation States

Every stage must produce one of:

```text
PASS

FAIL

NOT_REQUIRED

NOT_EVALUATED
```

Each state requires a record trail.

### PASS

`PASS` requires one or more authoritative supporting records demonstrating that the condition was satisfied.

A `PASS` must never be accepted solely because the Go backend supplied a Boolean value.

### FAIL

`FAIL` must record:

* The condition that failed
* The records examined
* The state found
* The expected state
* The failure reason
* The responsible policy
* Whether processing stopped after the failure

Example:

```text
FAIL - Service Participation Agreement Active

Supporting Record:
Agreement SPA-2026-0041

State Found:
SUSPENDED

Required State:
ACTIVE

Reason:
Participation suspended by Service Owner on 2026-07-09.
```

### NOT_REQUIRED

`NOT_REQUIRED` must reference the policy rule that determined the stage did not apply.

Example:

```text
NOT_REQUIRED - Presence for Duty Validation

Policy:
RMS-ADMINISTRATIVE-ACCESS version 2.4

Reason:
Current shift presence is not required for approved records personnel performing administrative RMS duties.
```

`NOT_REQUIRED` must not be selected merely because no supporting record was found.

### NOT_EVALUATED

`NOT_EVALUATED` must record why the stage was not evaluated.

Examples include:

* Processing stopped after an earlier required failure
* Required dependency was unavailable
* Evaluation engine error
* Policy could not be resolved
* Database verification failed

Example:

```text
NOT_EVALUATED - Required Approvals Satisfied

Reason:
Evaluation stopped after Operational Access Eligibility failed.

Dependency:
Eligibility Grant OAE-8831 was expired.
```

A required stage returning `NOT_EVALUATED` must cause the final decision to fail safely.

---

## Decision Record and Supporting Records

The Decision Record does not replace the supporting records.

The relationship is:

```text
Authoritative Organizational and Operational Records
        |
        v
Individual Evaluation Records
        |
        v
Ordered Justification Chain
        |
        v
Final Decision Record
```

The Decision Record must reference the records used by the evaluation.

It must also preserve a historical snapshot of the important context so that later changes do not alter the meaning of the original decision.

---

## Historical Preservation

If a supporting record later changes, the prior decision must remain understandable.

For example, if:

* A Personnel Authority is later revoked
* A Service Participation Agreement is later superseded
* An organization is renamed
* An Access Sponsor changes position
* An eligibility grant expires
* A policy is replaced

the original Decision Record must still show the state and version used when the decision occurred.

The repository should therefore preserve both:

```text
Reference to the authoritative record

Context snapshot as evaluated at decision time
```

---

## Append-Only Record Trail

The following records must be append-only or historically versioned:

* Organizational attestations
* Authority delegations
* Access sponsorships
* Eligibility grants
* Approval Actions
* Operational Validations
* Authority Grants
* Lease issuance and revocation
* Evaluation records
* Decision Records

Corrections, withdrawals, suspensions, revocations, and replacements must create new linked records.

They must not erase the original record.

---

## PostgreSQL Verification

PostgreSQL must independently confirm that the supporting records:

* Exist
* Match the supplied identifiers
* Belong to the expected organization
* Apply to the requested service
* Include the required scope
* Were effective at the time of evaluation
* Had not expired
* Had not been suspended or revoked
* Were issued by an accepted authority
* Satisfy the applicable policy version

Go may identify the records it evaluated, but PostgreSQL must retrieve and verify the authoritative database state itself.

---

## Architectural Invariants

1. No evaluation result may exist only as an in-memory Boolean.

2. Every `PASS` must reference one or more authoritative supporting records.

3. Every `FAIL` must record the examined state and reason for failure.

4. Every `NOT_REQUIRED` result must reference the policy rule making the stage unnecessary.

5. Every `NOT_EVALUATED` result must record why evaluation did not occur.

6. A required `NOT_EVALUATED` result must fail safely.

7. The final Decision Record must contain an ordered Justification Chain.

8. The Decision Record must reference all material supporting records.

9. Historical context must be preserved even when supporting records later change.

10. Supporting records must not be deleted or rewritten to alter prior decisions.

11. PostgreSQL must independently verify the supporting records used by Go.

12. Every attestation, agreement, delegation, grant, approval, validation, lease, evaluation, and decision must be attributable to its issuing identity and organization.

---

## Final Principle

The platform must not merely state:

> Access was allowed because all checks passed.

It must be able to demonstrate:

> Access was allowed because these specific organizations, authorities, agreements, attestations, grants, approvals, policies, validations, and leases were active, applicable, and independently verified at that exact time.

A decision without a supporting record trail is not a complete platform decision.


---

# PostgreSQL Enforcement

PostgreSQL must independently verify:

* Service
* Service status
* Participating Organization
* Participation Agreement
* Agreement status
* Agreement scope
* Delegated authority
* Attestation authority
* Eligibility grant
* Organization scope
* Jurisdiction scope
* Data ownership boundary
* Approval state
* Expiration
* Revocation

The Go backend may evaluate and attest, but PostgreSQL must not blindly trust organizational identifiers or scopes supplied by Go.

---

# Conceptual Database Objects

The final implementation may include concepts such as:

```text
organizations

organization_relationships

platform_services

service_owners

service_participation_agreements

service_participation_scopes

service_policies

attestation_authorities

organizational_attestations

authority_delegations

data_ownership_assignments

data_custody_assignments

participation_suspensions

participation_terminations
```

Final schemas and table names must follow the platform naming conventions.

---

# Architectural Invariants

1. Shared infrastructure does not create centralized organizational authority.

2. The Platform Operator is not automatically the Service Owner.

3. The Service Owner is not automatically the Data Owner.

4. The Data Custodian is not automatically the Data Owner.

5. The Employing Organization is not necessarily the supervising or service-providing organization.

6. Every service relationship must be represented through an explicit participation agreement.

7. Participation must be scoped by service, organization, jurisdiction, operation, and time where applicable.

8. Participation in one service must not automatically grant access to another service.

9. Department names such as IT and HR must not be hard-coded as universal authorities.

10. Delegated authority must be explicit, scoped, time-bounded, attributable, and revocable.

11. Re-delegation must be prohibited by default.

12. Cross-organization access must be explicit and policy-controlled.

13. Data ownership must not be inferred solely from platform hosting or database custody.

14. Suspension of one participation agreement must not automatically terminate unrelated agreements.

15. Historical organizational relationships must remain preserved.

16. PostgreSQL must independently verify participation agreements, delegation, scope, and expiration.

17. Every agreement, approval, delegation, attestation, suspension, termination, and revocation must produce a Decision Record.

---

# Final Principle

The platform must always be able to answer:

* Who operates the platform?
* Who owns the service?
* Which organization is participating?
* Who employs the person?
* Who manages the identity and device?
* Who attested to personnel status?
* Who sponsored the access?
* Who supervises the current assignment?
* Who owns the data?
* Who holds technical custody?
* Which agreement permits the relationship?
* Which delegation permits one organization to act for another?
* What scope, jurisdiction, and timeframe apply?

Federation must remain explicit.

Participation must remain scoped.

Authority must remain with the organization that owns it.

Shared service delivery must not erase organizational boundaries.

