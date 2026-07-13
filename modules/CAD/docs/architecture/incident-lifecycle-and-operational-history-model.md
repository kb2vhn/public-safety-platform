# Incident Lifecycle and Operational History Model

> **Document status:** Normative CAD architecture
>
> **Implementation status:** Not implemented

## Purpose

Define the incident as a durable operational record with controlled lifecycle
transitions and append-oriented history.

## Intake and Incident Separation

A call, text, alarm, radio report, automated notification, walk-in report, or
external request is not automatically identical to a CAD incident.

The model should distinguish:

- Intake source.
- Source message or communication.
- Reporting party.
- Caller or device location.
- Initial interpretation.
- Incident creation decision.
- Incident location.
- Incident classification.
- Incident priority.
- Incident ownership.

Multiple intake records may relate to one incident.

One intake record may result in no incident, one incident, or multiple incidents
when the controlled workflow supports and records that outcome.

## Incident Identity

An incident requires a durable internal identifier.

Human-readable incident numbers may be generated for operational use, but they
must not be treated as the only database identity.

Incident-number allocation must define:

- Scope.
- Format.
- Sequence authority.
- Rollover behavior.
- Collision handling.
- Offline or degraded allocation.
- Reconciliation behavior.
- Historical uniqueness expectations.

## Lifecycle

The exact states require later domain refinement. The model must at minimum
support controlled transitions for conditions such as:

- Created.
- Awaiting classification.
- Awaiting dispatch.
- Assigned.
- Dispatched.
- Active response.
- On scene.
- Transport or destination activity.
- Held.
- Transferred.
- Closing.
- Closed.
- Reopened.
- Cancelled or determined not to require response.

A state name must not imply facts that the platform has not recorded.

## Ownership and Responsibility

The incident must distinguish:

- Call-taker responsibility.
- Dispatch-position responsibility.
- Supervisory responsibility.
- Agency responsibility.
- Current organization.
- Current Governed Scope.
- Transfer requested.
- Transfer accepted.
- Transfer rejected or expired.

A transfer is not complete merely because one side sent it.

## Operational Timeline

Material incident activity must produce append-oriented timeline records.

Expected timeline categories include:

- Intake received.
- Incident created.
- Classification changed.
- Priority changed.
- Location added, corrected, verified, or superseded.
- Note or update recorded.
- Unit recommended.
- Unit assigned.
- Dispatch sent.
- Dispatch acknowledged.
- Unit status changed.
- Unit arrived.
- Transport started or completed.
- Alert created, acknowledged, escalated, or resolved.
- Incident transferred.
- External notification requested or delivered.
- Supervisor action.
- Incident closed or reopened.
- Correction or reconciliation.
- System degradation affecting the incident.

Each material record should retain:

- Event identity.
- Incident identity.
- Event type and schema version.
- Effective time.
- Recorded time.
- Source.
- Actor or system identity.
- Session and authorization context.
- Organization and Governed Scope.
- Related unit, resource, location, alert, or communication.
- Structured reason or reason code.
- Human explanation when required.
- Correlation and causation identifiers.
- Correction or supersession lineage.
- Data classification.
- Integrity and retention metadata.

## Current State and History

Operational screens require efficient current-state projections.

Current state may be maintained through controlled projections, but projections
must be reproducible or defensible from trusted history and controlled records.

A projection must not become a path for silently rewriting the historical event
that produced it.

## Corrections

Operators must be able to correct mistakes without erasing the original record.

A correction should:

1. Identify the record being corrected.
2. State what is incorrect.
3. Record the corrected information.
4. Preserve the original.
5. Identify the actor, authority, reason, and time.
6. update current projections through a controlled process.
7. remain visible to authorized review.

## Duplicate and Related Incidents

The system should support typed relationships such as:

- Possible duplicate.
- Confirmed duplicate.
- Parent and child.
- Related event.
- Escalation.
- Major-incident grouping.
- Same location.
- Same caller.
- Same involved person or vehicle when authorized.
- Mutual-aid relationship.

Linking incidents must not automatically merge or delete their independent
histories.

## Closure and Reopening

Closure must require explicit completion criteria appropriate to the incident
type and responsible agencies.

Reopening must preserve the prior closure and record:

- Reopening reason.
- Actor.
- Authority.
- Time.
- Resulting ownership and state.
- Related new information.

## Time and Ordering

CAD must retain both effective time and recorded time where they can differ.

Events received out of order must not be silently reordered in a way that
changes historical meaning.

The system should retain source timestamps, platform receipt timestamps, clock
quality, and ordering uncertainty when material.
