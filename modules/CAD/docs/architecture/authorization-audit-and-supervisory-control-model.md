# Authorization, Audit, and Supervisory Control Model

> **Document status:** Normative CAD architecture
>
> **Implementation status:** Not implemented

## Architecture Ownership

This document is authoritative for CAD governed operations, protected targets,
supervisory workflows, security audit, and operational accountability.

The Platform Foundation remains authoritative for identities, Authentication
Assertions, sessions, Authority Grants, Approval Requests, Approval Action
Records, stage evaluations, Approval Request finalization, Authorization
Decisions, Authorization Leases, Decision Records, and applicable Decision
Supporting Records.

The Operational Workstation may collect and present Workstation Observation
Records and Workstation Trust Assertions. The workstation, renderer, local
socket, running component, or cached state does not make the final Authorization
Decision and does not commit a protected CAD operation.

See the [Foundation Approval and Protected CAD Operation Integration Model](foundation-approval-and-protected-operation-integration-model.md).

## Purpose

Apply the Platform Foundation's exact-context authorization, explainability,
historical integrity, approval-independence, and separation-of-duties principles
to CAD operations.

## Authentication Is Not Authorization

A dispatcher being signed in does not grant authority to perform every CAD
operation.

Authorization must consider applicable context such as:

- Identity.
- Account and eligibility state.
- Organization.
- Dispatch position.
- Agency.
- Governed Scope.
- Device and client profile.
- Session and step-up state.
- Governed Purpose.
- Governed Operation.
- Protected Resource Target.
- Incident, unit, alert, location, or export classification.
- Current Authority Grant.
- Policy version.
- Current finalized Approval Request and Approval Action continuity when policy
  requires an approval input.
- Time.
- Operational and risk state.

An approval is a bounded policy input. It is not an identity, role, Authority
Grant, Authorization Decision, Authorization Lease, permission, or committed CAD
action.

## Representative Governed Operations

Future CAD operations may include:

- Create incident.
- Classify incident.
- Change priority.
- Add or verify location.
- Record operational update.
- Assign unit.
- Cancel or reassign unit.
- Change unit status.
- Transfer incident responsibility.
- Create or modify response-plan configuration.
- Add a premise hazard or submit it for governed independent review.
- Acknowledge or resolve an alert.
- Close or reopen an incident.
- Override a recommendation.
- Enter major-incident mode.
- Export incident data.
- Access restricted caller or premise information.
- Correct or supersede material history.
- Invoke degraded or break-glass operation.
- Reconcile locally recorded or queued actions.

The exact operation set must be versioned and tied to controlled APIs.

## Dispatcher Boundary

A dispatcher should normally be able to perform authorized operational work
within assigned agencies, disciplines, positions, and Governed Scopes.

A normal dispatcher account must not provide:

- User or role administration.
- Policy administration.
- Audit deletion.
- Retention changes.
- Unrestricted data export.
- Integration-secret management.
- Direct protected-table writes.
- Silent incident deletion.
- Silent history modification.
- Unrestricted personnel or criminal-justice browsing.
- Security-control disablement.
- Impersonation of another operator.

## Supervisor Boundary

A supervisor may receive additional governed operations such as:

- Rebalance dispatch responsibility.
- Request or complete a governed independent review for exceptional closure or
  reopening.
- Review sensitive premise warnings or act as an eligible independent actor on
  a Foundation Approval Request when policy requires that workflow.
- Request or perform an authorized override.
- Manage major-incident coordination.
- Review overdue incidents.
- Declare specific degraded procedures through a controlled operation.
- Review corrections.
- Place units or positions out of service.
- Initiate after-action preservation.

Supervisor authority is not unrestricted administration.

Material overrides require a reason, a current Authorization Decision, and a
durable domain record. When policy requires a Foundation Approval Request, the supervisor's Approval
Action Record remains distinct from the later Authorization Decision and CAD
commit.

## Administrative Separation

Configuration administration, security administration, operational supervision,
database ownership, deployment administration, Approval Request participation,
and ordinary dispatch must remain separable.

No ordinary identity or accumulated role set should independently possess
unrestricted authority across:

- Identity administration.
- Policy administration.
- Security administration.
- Data administration.
- Approval Request creation, Approval Action recording, and request finalization.
- Operational execution.
- Audit modification.
- Deployment ownership.

## Controlled Database Boundary

Production services must invoke controlled database APIs.

Runtime identities must not own CAD schemas or receive unrestricted direct write
access to protected records.

PostgreSQL must independently verify the minimum database-boundary conditions
for protected operations.

No client-side visibility rule, cached Authorization Decision, previously issued
Authorization Lease, or previously approved request may replace current
server-side verification.

## Decision Records and Domain Records

A Foundation Decision Record is the authoritative explanation of an
Authorization Decision. A CAD operational record describes the domain effect
that was requested or committed. They are related but not interchangeable.

A material protected operation should be able to answer:

- Who or what requested the action?
- What organization, service, and Governed Scope applied?
- What Governed Purpose and Governed Operation were requested?
- What Protected Resource Target was affected?
- What session, device, identity, policy, Authority Grant, Approval Request, and
  Approval Action conditions existed?
- Why did the Foundation allow, deny, or require retry?
- What CAD operation, if any, committed?
- Which operational timeline, audit, Decision Record, Decision Supporting Record,
  and domain record identifiers correlate the result?

## Audit and Operational History

Audit records and operational timeline records are related but not identical.

The operational timeline communicates authorized incident activity.

Security audit records support accountability, access review, investigation,
and assurance.

A Foundation Decision Record, Approval Action Record, CAD operational timeline
record, security audit record, and Assurance Artifact must not be used as
incomplete substitutes for one another.

## Restricted Access and Exports

Sensitive access should be purpose-bound and logged.

Bulk export requires:

- Exact scope.
- Data classification.
- Governed Purpose.
- Governed Operation.
- Protected Resource Target.
- Recipient or destination.
- Format.
- Volume.
- Retention.
- A current finalized Approval Request and Approval Action continuity when policy
  requires an approval input.
- A current Authorization Decision or Authorization Lease appropriate to the
  exact export operation.
- Delivery protection.
- Correlated Decision Record, audit record, and export record.

## Break-Glass

Break-glass behavior must be explicit, limited, time-bound, attributable, and
reviewable.

It must not become a permanent alternate login with unrestricted CAD access.

Break-glass may change the policy path, required controls, or escalation route,
but it does not authorize a client to fabricate Approval Action Records,
Authorization Decisions, Authorization Leases, or committed CAD state.

Break-glass and emergency workflows must remain accessible.
