# CAD Module Boundary and Dependency Model

> **Document status:** Normative CAD architecture
>
> **Implementation status:** Not implemented

## Purpose

Define what the Computer Aided Dispatch module owns, what it consumes, and what
must remain outside its boundary.

## CAD-Owned Domain

CAD owns the canonical operational records and workflows required to receive,
classify, dispatch, monitor, coordinate, and close emergency and non-emergency
response activity.

Expected CAD-owned concepts include:

- Call or request intake references.
- Incidents.
- Incident classifications and priority.
- Reported, caller, verified, staging, destination, and other operational
  locations.
- Incident ownership and dispatch-position responsibility.
- Unit and resource availability.
- Unit capabilities.
- Unit status observations.
- Unit assignments and assignment lifecycle.
- Response plans and response-plan evaluation.
- Explainable resource recommendations.
- Operational timeline records.
- Alerts, timers, escalation, acknowledgment, and resolution.
- Premise information and responder-safety hazards.
- Incident relationships, duplicates, and major-incident grouping.
- Communications references and delivery intent.
- Operational corrections, supersession, and reconciliation.
- CAD-specific exports, reports, and retained acceptance records.

## Foundation-Owned Capabilities

The Platform Foundation owns broadly reusable security, governance, trust,
authorization, assurance, resilience, telemetry, and integration mechanisms.

CAD must not redefine Foundation identity, session, authorization, approval,
Decision Record, assurance, or governance concepts merely to make CAD
implementation easier.

CAD requests controlled Foundation decisions using exact domain context.

## Shared-Resource Candidates

The following may become shared resources rather than CAD-owned resources when
their use is broader than CAD:

- Canonical address normalization.
- Geographic reference data.
- Organization and facility directories.
- Contact and notification destinations.
- Shared document rendering.
- Common scheduling.
- Common personnel or credential summaries.
- Cross-module event delivery.
- Shared search and indexing.
- Common client-profile and preference services.

A shared-resource decision must not move CAD-specific operational meaning into
the Foundation.

## Other Module Boundaries

CAD may integrate with, but must not absorb, the complete responsibilities of:

- Records Management.
- Evidence and Property.
- Fire and EMS clinical documentation.
- Personnel Operations.
- Fleet Management.
- Emergency Management.
- Jail or corrections systems.
- Court systems.
- Public works.
- Hospital clinical systems.
- State and federal criminal-justice systems.

A CAD incident may create or reference another module record through a governed
contract. The referenced module remains authoritative for its own record.

## Interface Boundary

The dispatcher workstation is a projection and command surface over controlled
CAD operations.

The interface must not:

- Write protected tables directly.
- Infer authorization from a hidden button or client-side role.
- silently convert a recommendation into a committed action.
- Treat locally cached or externally supplied state as authoritative without
  provenance.
- rewrite material history when an operator corrects a mistake.

## External-System Boundary

External systems may provide observations, communications, recordings, location
updates, queries, or delivery capabilities.

Each integration must define:

- Contract version.
- Direction.
- Authentication and authorization.
- Source and destination identifiers.
- Idempotency behavior.
- Ordering expectations.
- Retry and replay behavior.
- Freshness and staleness.
- Failure and degradation behavior.
- Data classification.
- Retention.
- Audit and telemetry.
- Replacement and exit behavior.

An external provider must not become an undocumented source of CAD authority,
canonical history, or operator identity.

## Migration Boundary

CAD migrations belong in the module-owned `200–899` range only after an approved
module-range decision allocates an exact range.

The first CAD migration must not be created before:

1. The module boundary is accepted.
2. Core terminology is stable enough to name durable records.
3. Domain invariants are documented.
4. Controlled write paths are designed.
5. The test and phase-gate strategy is defined.
6. The exact migration range is approved.

## Non-Goals of the Initial CAD Module

The initial CAD module does not need to replace every neighboring public-safety
system.

It must first provide a trustworthy dispatch core that can be extended through
controlled contracts without weakening history, authorization, performance,
accessibility, or degraded-operation behavior.
