# CAD Data-Migration, Cutover, and Transition Model

> **Owner:** Iron Signal Systems
>
> **Module:** Computer Aided Dispatch
>
> **Document status:** Normative CAD architecture
>
> **Implementation status:** Transition contract only

## Purpose

Define how CAD data, configuration, integrations, users, and operational
responsibility move from an existing environment into Iron Signal CAD without
silent loss, semantic corruption, unverifiable history, or uncontrolled service
interruption.

A successful import count is not migration acceptance.

## Scope

A transition may include:

- Incidents and historical event timelines.
- Personnel, users, organizations, agencies, and units.
- Resources, capabilities, status codes, and response plans.
- Premises, hazards, access information, addresses, GIS, and geocoding data.
- Alert, timer, disposition, nature, priority, and code tables.
- Attachments, recordings, and external references.
- Audit, retention, legal-hold, and provenance records.
- Integrations, endpoints, certificates, keys, and provider identifiers.
- Workstations, queues, caches, offline records, and local configuration.
- Training, support, operational procedures, and authority handoff.

## Source-System Inventory

Every source must identify:

- System and owner.
- Product and version.
- Database, file, API, or export mechanism.
- Data classification.
- Time range.
- Record counts.
- Identifier rules.
- Time-zone and timestamp behavior.
- Code lists and local meanings.
- Known defects and incomplete areas.
- Retention and legal constraints.
- Extract authority.
- Source freeze and delta strategy.

## Traceable Transformation

Every migrated authoritative record must be traceable through:

```text
source system
→ source record identity
→ source extract identity and digest
→ transformation rule and version
→ validation result
→ destination record identity
→ reconciliation result
→ accepted exception, when applicable
```

Transformation logic must be version controlled, reviewed, tested, and bound to
the release used for cutover.

## Mapping Requirements

Mappings must classify every source value as:

```text
EXACT
NORMALIZED
DERIVED
SPLIT
MERGED
LOSSY
OMITTED_BY_POLICY
UNSUPPORTED
AMBIGUOUS
INVALID_SOURCE
MANUAL_REVIEW
```

Silent default substitution is prohibited.

Mappings must address:

- Identifier collisions.
- Duplicate people, units, incidents, and premises.
- Local versus canonical enumerations.
- Unknown and retired codes.
- Null, empty, sentinel, and malformed values.
- Timestamp precision and time zones.
- Daylight-saving transitions.
- Historical corrections and supersession.
- Referential relationships.
- Data classification and access restrictions.
- Audit and provenance preservation.
- Truncation and encoding.
- Legal retention and deletion restrictions.

## Rehearsal Migration

Before cutover, the migration must be rehearsed repeatedly against a protected
copy or approved synthetic equivalent.

Each rehearsal must retain:

- Source extract and digest.
- Transformation version.
- Environment fingerprint.
- Start and end time.
- Counts by record type and disposition.
- Constraint, mapping, and validation failures.
- Performance and resource telemetry.
- Destination digest or accepted comparison method.
- Manual review findings.
- Rerun determinism result.
- Cleanup and repeatability result.

The same frozen source and transformation version must produce the same accepted
result, except for explicitly documented generated values.

## Validation

Migration acceptance must include:

- Complete record counts.
- Referential-integrity validation.
- Semantic field validation.
- Code-list and enumeration validation.
- Timestamp and ordering validation.
- Identity and organization-scope validation.
- Historical query equivalence.
- Current-state projection equivalence.
- Data-classification preservation.
- Access-control validation.
- Audit and provenance validation.
- Hash or digest comparison where meaningful.
- Statistical and targeted sampling.
- Complete review of rejected, ambiguous, lossy, and unsupported records.

Matching row counts without semantic validation is insufficient.

## Cutover Plan

The cutover plan must define:

- Command authority.
- Go/no-go authority.
- Technical and operational roles.
- Communication channels.
- Source freeze time.
- Final extract and delta capture.
- Integration sequencing.
- Identity and access activation.
- Workstation transition.
- Validation checkpoints.
- Maximum outage and degraded-operation window.
- Manual fallback.
- Rollback and forward-repair decision points.
- Reconciliation.
- Evidence retention.
- Support escalation.

## Parallel Operation

When parallel operation is used, the plan must define which system is
authoritative for each operation and time interval.

Dual entry must not create two independent authoritative histories without an
accepted reconciliation contract.

## Rollback and Forward Repair

Rollback is allowed only when:

- The source remains trustworthy and available.
- Post-freeze work can be accounted for.
- External deliveries and acknowledgments can be reconciled.
- Identity and authority state can be restored safely.
- No accepted committed work is silently lost.

When rollback would create greater risk, the plan must define controlled
forward repair.

## Post-Cutover Reconciliation

Reconciliation must verify:

- Final source and destination counts.
- Delta and late-arriving records.
- External provider state.
- Queue and outbox state.
- Active incidents and assignments.
- Unit status.
- Alerts and timers.
- Identity, session, approval, and authorization state.
- Historical retrieval.
- Workstation state.
- Audit and telemetry continuity.

## Cutover Acceptance

Cutover is accepted only when:

- The exact source, extract, transformation, destination, and release are known.
- Required validations pass.
- Every rejected or lossy record has a disposition.
- No unauthorized access or scope expansion occurred.
- No active operational state is unexplained.
- No external delivery is falsely represented.
- Rollback or forward-repair status is explicit.
- Operational owners approve the transition.
- Evidence is retained.
