# Dynamic Dispatch Coverage and Service Routing

## Purpose

The Public Safety Platform must support jurisdictions whose dispatch services are provided by different organizations at different times or under different operational conditions.

A municipality, village, department, district, campus, or special jurisdiction may:

* Operate its own dispatcher during normal business hours
* Transfer after-hours dispatch to a city or county
* Use a regional communications center on weekends
* Use another agency during staffing shortages
* Route overflow calls to a backup center
* Transfer operations during a communications outage
* Use temporary mutual-aid dispatch during a major incident
* Operate under an emergency arrangement not reflected in the normal schedule

The CAD architecture must not assume that the organization being served is always the organization performing dispatch.

---

## Distinct Organizational Roles

For each CAD operation, the platform must distinguish:

### Jurisdiction Being Served

The municipality, district, agency, campus, facility, or geographic area for which dispatch service is being provided.

### CAD Service Owner

The organization or governing body responsible for the CAD service, its policies, and its participation rules.

### Platform Operator

The organization operating the shared platform infrastructure.

### Dispatch Provider

The organization currently responsible for call-taking, dispatch, or both.

### Backup Dispatch Provider

An organization authorized to assume responsibility during overflow, outage, staffing shortage, planned closure, or emergency transfer.

### Incident-Owning Organization

The organization that has authoritative ownership or primary responsibility for the operational incident record.

### Responding Organization

An organization supplying personnel, units, apparatus, vehicles, or other resources to an incident.

### Data Custodian

The organization operating the system in which the CAD records are stored and protected.

These roles may be held by the same organization, but the platform must not assume that they are identical.

---

## Dispatch Coverage Agreement

A Dispatch Coverage Agreement defines which organization may provide dispatch services for a jurisdiction.

The agreement may include:

* Agreement identifier
* CAD service
* Jurisdiction being served
* Primary dispatch provider
* Backup dispatch providers
* Call-taking provider
* Dispatching provider
* Covered agencies
* Covered incident types
* Covered geographic area
* Effective time
* Expiration time
* Normal coverage schedule
* Holiday schedule
* After-hours schedule
* Overflow rules
* Outage rules
* Mutual-aid rules
* Required supervisor authorities
* Data ownership rules
* Records-access rules
* Transfer requirements
* Applicable approval policies
* Suspension and termination state

A jurisdiction may have multiple active Dispatch Coverage Agreements when each applies to a different time, function, incident type, or operational condition.

---

## Dispatch Routing Policy

A Dispatch Routing Policy determines which approved provider is responsible at a particular moment.

The policy may evaluate:

* Current date and time
* Day of week
* Holiday calendar
* Jurisdiction
* Incident type
* Call source
* Geographic location
* Current provider availability
* Staffing state
* Communications-center status
* Overflow threshold
* Declared outage
* Emergency declaration
* Active mutual-aid agreement
* Manual command-authorized transfer
* Existing incident ownership

The routing result must identify the policy and facts that selected the provider.

---

## Example Coverage Schedule

```text
Jurisdiction:
Village A

Monday through Friday, 08:00–16:00:
Village A Communications

Monday through Friday, 16:00–08:00:
County 911 Communications

Weekends and holidays:
City B Communications Center

Primary-provider outage:
Regional Backup PSAP

Major incident overflow:
County 911 Communications
```

These relationships must be data-driven and versioned.

They must not be hard-coded into CAD application logic.

---

## Current Dispatch Responsibility

The platform should resolve a Current Dispatch Responsibility for each call or operational period.

The resolved responsibility may include:

* Jurisdiction
* Call-taking provider
* Dispatch provider
* Supervising organization
* Applicable coverage agreement
* Applicable routing policy
* Effective time
* Expected expiration
* Reason for selection
* Manual override
* Decision Record

The current provider is not necessarily the permanent owner of the jurisdiction or record.

---

## Call-Taking and Dispatch May Be Separate

One organization may answer the call while another organization dispatches resources.

Example:

```text
Call-Taking Provider:
County 911

Dispatch Provider:
Village A Dispatcher

Law Enforcement Dispatch:
Village A Police

Fire and EMS Dispatch:
County 911
```

The platform must permit separate responsibility by:

* Operational function
* Agency
* Discipline
* Incident type
* Resource type
* Time period

A single incident may therefore involve more than one authorized dispatch provider.

---

## Dispatch Provider Handoff

Dispatch responsibility may transfer while a call or incident remains active.

A handoff must record:

* Transferring provider
* Receiving provider
* Transferring dispatcher
* Receiving dispatcher
* Supervising authorities
* Calls or incidents transferred
* Resources currently assigned
* Pending actions
* Outstanding safety information
* Transfer reason
* Transfer time
* Acceptance time
* Applicable agreement or emergency authority
* Decision Records

The transfer must not overwrite the earlier provider.

The complete provider history must remain visible.

---

## Handoff States

Possible handoff states include:

```text
REQUESTED

ACKNOWLEDGED

ACCEPTED

REJECTED

IN_PROGRESS

COMPLETED

CANCELLED

FAILED
```

Responsibility must not become ambiguous during transfer.

The platform must identify which provider remains responsible until the receiving provider formally accepts the handoff.

---

## Scheduled Provider Changes

A scheduled coverage transition should not silently abandon active incidents.

At the scheduled transition:

* New calls may route to the incoming provider.
* Existing incidents may remain with the outgoing provider.
* Existing incidents may be transferred individually.
* All active incidents may be transferred as a group.
* Certain high-risk incidents may remain with the original provider until completion.

The applicable routing policy must define the expected behavior.

---

## Overflow Coverage

Overflow routing may occur when:

* Call volume exceeds policy limits
* No qualified dispatcher is available
* A dispatch center loses connectivity
* A provider manually requests assistance
* A major incident consumes local capacity
* A regional plan activates

Overflow authority must be based on an active agreement or temporary emergency grant.

The backup provider must not receive unrestricted access to unrelated jurisdictions or records.

---

## Emergency and Unplanned Coverage

The platform must support situations where the normal provider is unexpectedly unavailable and no routine schedule cleanly applies.

Examples include:

* Communications-center evacuation
* Staffing collapse
* Network outage
* Telephone outage
* Building emergency
* Regional disaster
* Loss of primary and secondary providers
* Unplanned assistance by an available neighboring agency

Emergency coverage must still be explicit and attributable.

A temporary Emergency Dispatch Coverage Grant should identify:

* Jurisdiction being served
* Temporary provider
* Granting authority
* Reason
* Permitted functions
* Organization and geographic scope
* Effective time
* Maximum expiration
* Required approvals
* Review requirement
* Decision Record

“God only knows who is answering tonight” must become a controlled, visible, temporary assignment in the platform rather than an undocumented operational fact.

---

## Dispatcher Access Eligibility

A dispatcher’s eligibility must identify the services and jurisdictions for which the dispatcher may operate.

Example:

```text
Dispatcher:
Identity 1234

Employing Organization:
County 911

Eligible Service:
Shared CAD

Eligible Functions:
CALL_TAKING
LAW_DISPATCH
FIRE_DISPATCH
EMS_DISPATCH

Jurisdiction Scope:
Village A
Village B
County Unincorporated Area

Effective Time:
2026-01-01

Expiration Time:
2026-12-31
```

Eligibility does not mean the dispatcher is always actively responsible for every listed jurisdiction.

The applicable Dispatch Coverage Agreement and Routing Policy must also select that dispatcher’s organization as the current provider.

---

## Supervisor Attestation

The supervisor who validates a dispatcher’s on-duty status must belong to an organization authorized to supervise the active dispatch provider.

A Village A supervisor may validate Village A dispatch personnel during village-operated hours.

A county communications supervisor may validate county dispatch personnel during county coverage hours.

A regional supervisor may validate cross-organizational staff only when an agreement or delegation grants that authority.

Supervisor validation must not expand the underlying Dispatch Coverage Agreement.

---

## Authorization Evaluation

Before permitting a CAD dispatch action, the platform may evaluate:

```text
PASS - Device trusted

PASS - Identity active

PASS - Dispatcher access eligibility active

PASS - Required personnel and technical attestations active

PASS - Dispatcher marked present for duty

PASS - Dispatch Coverage Agreement active

PASS - Routing Policy selects dispatcher’s organization

PASS - Requested discipline permitted

PASS - Jurisdiction inside approved scope

PASS - Dispatcher authority active

PASS - Authorization Lease valid
```

If the routing policy selects another provider, the request must be denied unless an approved handoff, overflow, mutual-aid, or emergency grant authorizes the action.

---

## Jurisdiction and Data Ownership

A dispatch provider does not automatically become the owner of all data it handles.

The platform must preserve:

* Jurisdiction being served
* Agency responsible for the incident
* Organization that created each entry
* Dispatch provider at the time
* Call-taking provider at the time
* Data owner
* Data custodian
* Participating responding agencies

A county communications center may dispatch for a village without becoming the owner of the village’s RMS reports.

A village dispatcher may create a CAD incident on a county-hosted platform without becoming the platform operator.

---

## Historical Provider Context

Every CAD action must retain sufficient historical context to identify:

* Which provider was responsible
* Which dispatcher performed the action
* Which supervisor validated the dispatcher
* Which agreement authorized the provider
* Which routing policy selected the provider
* Which jurisdiction was being served
* Whether the action occurred during normal, overflow, backup, mutual-aid, or emergency coverage

Later schedule or provider changes must not alter the historical record.

---

## Failure and Ambiguity

When the platform cannot determine an authorized provider, it must not silently assign broad access.

The result may be:

```text
DENY

PENDING

ESCALATED
```

Depending on approved policy.

The platform may escalate to an authorized command or emergency coverage workflow.

Any manual selection must record:

* Selecting identity
* Selecting authority
* Reason
* Temporary provider
* Scope
* Expiration
* Applicable emergency policy
* Decision Record

---

## Architectural Invariants

1. The jurisdiction being served is not necessarily the dispatch provider.

2. The dispatch provider is not necessarily the CAD Service Owner.

3. The CAD Service Owner is not necessarily the Platform Operator.

4. Call-taking and dispatch may be provided by different organizations.

5. Different disciplines may have different providers for the same incident.

6. Provider selection must be based on versioned coverage agreements and routing policies.

7. Provider responsibility may change by schedule, availability, outage, overflow, mutual aid, or emergency authority.

8. Scheduled provider changes must define handling for active incidents.

9. A provider handoff must be explicitly accepted and historically preserved.

10. A backup provider must receive only the scope required by the applicable agreement or emergency grant.

11. Dispatcher eligibility must not automatically activate responsibility for every eligible jurisdiction.

12. Supervisor validation must remain within the provider and service scope the supervisor is authorized to manage.

13. An emergency provider assignment must be explicit, temporary, scoped, and attributable.

14. Data ownership must remain separate from dispatch-service delivery.

15. PostgreSQL must independently verify the applicable provider, agreement, routing result, jurisdiction, authority, scope, and expiration.

16. Every provider selection, handoff, override, failure, escalation, and emergency assignment must produce a Decision Record.

---

## Final Principle

CAD must answer more than:

> Which agency normally dispatches for this jurisdiction?

It must answer:

> Which approved organization is responsible for this function, for this jurisdiction, at this moment, under which agreement, policy, staffing state, and operational condition?

Dispatch responsibility must be dynamic.

It must be explicit.

It must be transferable.

It must be historically preserved.

It must remain limited to the authority and scope granted by the participating organizations.

