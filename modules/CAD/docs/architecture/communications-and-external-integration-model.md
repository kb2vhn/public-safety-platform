# Communications and External-Integration Model

> **Document status:** Normative CAD architecture
>
> **Implementation status:** Not implemented

## Purpose

Define replaceable, observable, and recoverable integration boundaries for
communications and external operational systems.

## Expected Integration Categories

CAD may integrate with:

- Emergency telephony.
- Next Generation 911 services.
- Text-to-911.
- TTY or real-time text.
- Radio console and radio logging systems.
- Mobile data terminals.
- Secure unit messaging.
- Paging and station alerting.
- Automatic vehicle location.
- Language interpretation.
- Public warning and notification systems.
- Hospital or destination-status systems.
- Weather and road information.
- State and federal query systems.
- Alarm systems.
- Mapping, geocoding, and routing providers.
- Recording systems.
- Mutual-aid and regional CAD systems.

## Contract Requirements

Each integration contract must define:

- Contract identifier and version.
- Provider and consumer.
- Direction.
- Message types.
- Canonical identifiers.
- Authentication.
- Authorization.
- Encryption and transport.
- Data classification.
- Ordering.
- Idempotency.
- Duplicate detection.
- Retry.
- Replay.
- Expiration.
- Freshness.
- Timeout.
- Partial failure.
- Queue behavior.
- Reconciliation.
- Audit.
- Telemetry.
- Retention.
- Replacement and exit.

## Canonical Records

The platform owns its canonical CAD incident, assignment, timeline, alert,
delivery intent, and reconciliation records.

An external system may remain authoritative for its own native artifact, such as
a recording or provider-specific message, but CAD must retain sufficient
reference, provenance, and integrity information to explain its operational use.

## Transactional Delivery

Where CAD commits an operation and requests external delivery, the delivery
intent should be transactionally retained through an outbox or equivalent
controlled pattern.

The platform must distinguish:

- Requested.
- Queued.
- Sent.
- Provider accepted.
- Delivered.
- Acknowledged.
- Failed.
- Expired.
- Cancelled.
- Replayed.
- Reconciled.

A successful CAD database commit must not be misrepresented as successful radio,
message, page, or station-alert delivery.

## Inbound Observations

Inbound events require:

- Source identity.
- Contract version.
- Provider message identity.
- Receipt time.
- Source time.
- Integrity or authentication result.
- Duplicate handling.
- Parsing result.
- Correlation.
- Classification.
- Operational disposition.

Malformed, unauthenticated, stale, duplicated, or out-of-scope messages must
fail closed or enter an explicit review path.

## Recordings and Large Artifacts

CAD should generally retain governed references to protected recordings rather
than indiscriminately copying every audio or video object into the incident
record.

A reference should identify:

- Provider.
- Recording identity.
- Time range.
- Participants or channel when appropriate.
- Integrity metadata.
- Access classification.
- Retention authority.
- Retrieval status.
- Legal hold or preservation relationship when applicable.

## Provider Independence

Provider-specific behavior belongs in an adapter.

CAD domain rules must not be embedded only in:

- A radio vendor.
- A map provider.
- A telephony provider.
- A cloud notification service.
- A state query client.
- A proprietary message format.

Replacing a provider may require a new adapter and migration plan, but must not
require redefining CAD authorization or silently abandoning canonical history.

## Integration Health

The dispatcher and supervisors need operationally meaningful health, including:

- Available.
- Degraded.
- Delayed.
- Read-only.
- Queueing.
- Failed.
- Recovering.
- Unknown.

Health must identify affected capabilities and the operational consequence, not
only a technical component name.
