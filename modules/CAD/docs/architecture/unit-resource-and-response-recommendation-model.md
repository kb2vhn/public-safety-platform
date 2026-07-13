# Unit, Resource, and Response Recommendation Model

> **Document status:** Normative CAD architecture
>
> **Implementation status:** Not implemented

## Purpose

Define trustworthy resource status, assignment, capability, and recommendation
behavior.

## Unit and Resource Distinction

A unit is an operationally identifiable response entity.

A resource is a broader capability, asset, team, facility, or support element
that may be requested, assigned, reserved, staged, or tracked.

Examples may include:

- Patrol unit.
- Ambulance.
- Engine.
- Ladder.
- Rescue.
- Supervisor.
- K-9 team.
- Drone team.
- Hazmat resource.
- Public works resource.
- Mutual-aid team.
- Command post.
- Staging area.
- Shelter or support facility.

The model must not force every resource into a vehicle-shaped record.

## Availability and Dispatchability

Availability and dispatchability are not identical.

A unit may be technically available but not dispatchable because of:

- Jurisdiction.
- Agency policy.
- Staffing.
- Capability.
- Maintenance.
- Coverage requirements.
- Current assignment.
- Training status.
- Location freshness.
- Communications failure.
- A policy-required finalized Foundation Approval Request, current Authorization Decision, or supervisory restriction.
- Temporary operational hold.

The system must record the reason a resource is or is not dispatchable.

## Unit Status

Unit status changes require:

- Exact unit.
- Status type and version.
- Effective time.
- Recorded time.
- Source.
- Actor or system.
- Related incident when applicable.
- Location or destination context when applicable.
- Prior state.
- Transition validation.
- Reason when the transition is exceptional.
- Current authorization context.

A unit status is not silently inferred from map movement unless a governed rule
explicitly creates an observation or recommendation.

## Assignment Lifecycle

An assignment should distinguish:

- Recommended.
- Proposed.
- Authorized.
- Committed.
- Dispatch delivery queued.
- Dispatch delivered.
- Acknowledged.
- Accepted or rejected when applicable.
- En route.
- On scene.
- Completed.
- Cleared.
- Cancelled.
- Reassigned.
- Failed or conflicted.

A recommendation or proposed assignment must never appear as committed.

## Capabilities

Capabilities should be structured, versioned, and attributable.

Examples include:

- ALS or BLS.
- Transport.
- Engine, ladder, tanker, rescue, or hazmat.
- Supervisor.
- Crisis intervention.
- Language capability.
- Four-wheel drive.
- Marine.
- Drone.
- Mass-casualty equipment.
- Specialized rescue.
- Command capability.

A capability may have:

- Validity dates.
- Source.
- Verification status.
- Organization.
- Personnel, unit, vehicle, or equipment dependency.
- Temporary restriction.
- Required minimum staffing.

## Response Plans

A response plan should define:

- Applicability.
- Incident classification.
- Priority.
- Agency and Governed Scope.
- Required capability or resource pattern.
- Minimum and preferred response.
- Ordering and fallback.
- Coverage constraints.
- Mutual-aid behavior.
- Version.
- Effective dates.
- Governed configuration authorization and, when policy requires it, a finalized Foundation Approval Request.
- Explanation text.
- Exception behavior.

The system must record which response-plan version was evaluated.

## Recommendations

A recommendation is decision support.

Every material recommendation should retain enough context to explain:

- Which incident was evaluated.
- Which response-plan version applied.
- Which units or resources were considered.
- Which resources were excluded and why.
- Availability and dispatchability at evaluation time.
- Capability match.
- Jurisdiction and organization.
- Location source, age, and confidence.
- Estimated travel or response information.
- Coverage or move-up impact.
- External data used.
- Policy or rule version.
- Recommendation rank.
- Reason for the recommendation.
- Time of evaluation.

A recommendation must have an expiration or freshness rule.

## Human Control and Overrides

The dispatcher or supervisor may select a different resource when authorized.

An override should record:

- Original recommendation.
- Selected resource.
- Actor.
- Authorization context.
- Reason.
- Relevant operational conditions.
- Whether an independent Foundation Approval Request and eligible Approval Action were required by policy.
- Resulting assignment.

The system must not shame the operator for a justified override or conceal the
override from later review.

## Location and Estimated Response

Location-based recommendation must distinguish:

- Last observed location.
- Observation age.
- Source.
- Accuracy.
- Direction and speed when available.
- Routing data version.
- Road or access restrictions.
- Estimated versus verified travel time.
- Missing or degraded map data.

A resource with stale location must not be ranked as though its location were
current without an explicit degraded rule and visible explanation.

## Concurrency

Assignment and status operations are concurrency-sensitive.

Tests must prove behavior when:

- Two dispatchers assign the same unit.
- A unit status changes while assignment is being committed.
- A recommendation expires during commit.
- An incident is transferred during assignment.
- A resource becomes unavailable.
- A duplicate delivery or acknowledgment arrives.
- A supervisor override races with a dispatcher action.

Exactly one authoritative result must be committed where the operation requires
single-winner behavior.
