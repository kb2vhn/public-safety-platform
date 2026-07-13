# Authorization, Audit, and Supervisory Control Model

> **Document status:** Normative CAD architecture
>
> **Implementation status:** Not implemented

## Purpose

Apply the Platform Foundation's exact-context authorization, explainability,
historical integrity, and separation-of-duties principles to CAD operations.

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
- Authority Grant.
- Policy version.
- Required approval.
- Time.
- Operational and risk state.

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
- Add or approve a premise hazard.
- Acknowledge or resolve an alert.
- Close or reopen an incident.
- Override a recommendation.
- Enter major-incident mode.
- Export incident data.
- Access restricted caller or premise information.
- Correct or supersede material history.
- Invoke degraded or break-glass operation.
- Reconcile offline or queued actions.

The exact operation set must be versioned and tied to controlled APIs.

## Dispatcher Boundary

A dispatcher should normally be able to perform authorized operational work
within assigned agencies, disciplines, positions, and scopes.

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
- Approve exceptional closure or reopening.
- Approve or review sensitive premise warnings.
- Authorize certain overrides.
- Manage major-incident coordination.
- Review overdue incidents.
- Declare specific degraded procedures.
- Review corrections.
- Place units or positions out of service.
- Initiate after-action preservation.

Supervisor authority is not unrestricted administration.

Material overrides require a reason and durable record.

## Administrative Separation

Configuration administration, security administration, operational supervision,
database ownership, deployment administration, and ordinary dispatch must remain
separable.

No ordinary identity or accumulated role set should independently possess
unrestricted authority across:

- Identity administration.
- Policy administration.
- Security administration.
- Data administration.
- Approval.
- Operational execution.
- Audit modification.
- Deployment ownership.

## Controlled Database Boundary

Production services must invoke controlled database APIs.

Runtime identities must not own CAD schemas or receive unrestricted direct write
access to protected records.

PostgreSQL must independently verify the minimum database-boundary conditions
for protected operations.

## Decision Records

High-impact operations may require a Foundation Decision Record or a module-owned
operational decision record linked to the Foundation decision context.

A material decision should answer:

- Who or what requested the action?
- What organization, service, and scope applied?
- What purpose and operation were requested?
- What protected target was affected?
- What session, device, identity, policy, authority, and approval conditions
  existed?
- Why was the action allowed, denied, pending, or escalated?
- What was committed?
- Can the historical record be trusted?

## Audit and Operational History

Audit records and operational timeline records are related but not identical.

The operational timeline communicates authorized incident activity.

Security audit records support accountability, access review, investigation,
and assurance.

One must not be used as an incomplete substitute for the other.

## Restricted Access and Exports

Sensitive access should be purpose-bound and logged.

Bulk export requires:

- Exact scope.
- Data classification.
- Purpose.
- Recipient or destination.
- Format.
- Volume.
- Retention.
- Approval when required.
- Delivery protection.
- Decision and audit context.

## Break-Glass

Break-glass behavior must be explicit, limited, time-bound, attributable, and
reviewable.

It must not become a permanent alternate login with unrestricted CAD access.

Break-glass and emergency workflows must remain accessible.
