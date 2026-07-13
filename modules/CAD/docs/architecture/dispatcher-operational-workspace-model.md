# Dispatcher Operational Workspace Model

> **Document status:** Normative CAD architecture
>
> **Implementation status:** Not implemented

## Architecture Ownership

This document is authoritative for the operational information and governed CAD
actions that belong in the dispatcher workspace.

The [CAD User-Interface Architecture](user-interface/README.md) is authoritative
for interaction, accessibility, focus, input, presentation, and human-facing
failure behavior.

The [CAD Operational Workstation Architecture](operational-workstation/README.md)
is authoritative for the managed appliance, local workstation components,
renderer, IPC, cache, release, and recovery implementation.

## Purpose

Define the information hierarchy and interaction rules for a dispatcher-facing
CAD workspace.

The workspace must help the dispatcher answer:

1. What is happening?
2. Where is it happening?
3. Which resources are available and dispatchable?
4. Which resources are assigned and what are they doing?
5. What requires attention now?
6. What information is stale, unconfirmed, queued, failed, or degraded?

## Operational Regions

A default workspace should provide stable regions for:

- Center, position, and system status.
- Active incident queue.
- Unit and resource board.
- Map or synchronized geographic representation.
- Selected incident workspace.
- Alerts and pending actions.
- Quick actions or governed command entry.

The exact visual arrangement may vary by deployment and operator preference, but
the logical regions and their meanings must remain consistent.

## Always-Available Context

The dispatcher must be able to determine without leaving the active workflow:

- Authenticated operator and active dispatch position.
- Current date, time, and time-zone context.
- Assigned agencies, disciplines, and Governed Scopes.
- System and integration degradation.
- Number and severity of active alerts.
- Active incidents requiring attention.
- Available and committed units.
- Selected incident and selected unit.
- Pending, queued, failed, and unconfirmed actions.

## Incident Queue

Each queue entry should expose enough information to support rapid triage:

- Incident identifier.
- Priority and severity label.
- Call or incident type.
- Location summary.
- Jurisdiction or other module-defined scope.
- Time received.
- Waiting or elapsed time.
- Ownership.
- Assignment state.
- Assigned resources.
- Unread or changed information.
- Active timer or escalation state.
- Responder-safety warning state.
- Data freshness and confirmation state.

Critical meaning must not depend on color alone.

## Selected Incident Workspace

The selected incident should present one coherent operational context containing:

- Incident identity and current classification.
- Priority.
- Current lifecycle state.
- Operational locations.
- Caller or reporting-party information when authorized.
- Assigned units and resource state.
- Response-plan status.
- Operational timeline.
- Premise and hazard information.
- Related incidents.
- Active alerts and timers.
- Communications references.
- Controlled actions available to the current operator.

The interface should not require dispatchers to open unrelated windows to
perform common incident actions.

## Unit and Resource Board

The resource board should expose:

- Unit or resource identifier.
- Agency and discipline.
- Current status.
- Status age.
- Assignment.
- Current or last reported location.
- Location age and confidence.
- Crew or personnel summary when authorized.
- Capabilities.
- Station, post, beat, district, or response area.
- Radio channel or talkgroup reference when applicable.
- Last communication.
- Availability and dispatchability distinctions.
- Degraded or conflicting state.

## Map and Alternative Representation

The map is an operational projection, not the only representation of location.

Essential mapped information must have a synchronized list, table, or other
accessible representation.

Selecting an incident or unit from any representation should produce the same
active context.

## Quick Actions and Commands

High-frequency actions should support efficient keyboard operation.

Commands may use concise operational syntax or governed plain-language entry,
but the system must:

- Parse into an explicit proposed action.
- Resolve exact targets.
- identify ambiguity.
- show material effects before commit when necessary.
- require confirmation for ambiguous or high-impact actions.
- retain the original command and interpreted action when operationally
  significant.
- authorize and commit through controlled service and database boundaries.
- return a clear committed, rejected, queued, failed, or pending result.

Plain-language interpretation is not authority.

## Attention Management

The interface should prioritize actionable conditions rather than maximize
visual motion or alarm volume.

It must distinguish:

- Informational updates.
- New actionable alerts.
- Repeated alerts.
- Escalated alerts.
- Acknowledged alerts.
- Resolved conditions.
- Stale state.
- Failed actions.
- Lost connectivity.

## Multi-Monitor and Single-Monitor Operation

CAD may support multiple monitors, but essential operation must not silently
depend on a specific number of displays unless the deployment profile requires
and supplies that configuration.

A supported single-monitor mode must preserve access to essential workflows.

## Prohibited Interaction Patterns

The dispatcher workspace must not:

- Hide critical information only in hover content.
- Use modal dialogs for routine activity when an in-context action is safer.
- Move keyboard focus because background data refreshed.
- silently change the selected incident or unit.
- represent a recommendation as a committed assignment.
- make stale data look current.
- make acknowledgment look like resolution.
- remove an operator's work merely because step-up or reauthentication is needed
  when safe preservation is possible.
- place unrestricted administration inside the normal dispatcher session.
