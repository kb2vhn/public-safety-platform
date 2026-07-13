# Location, Mapping, Premise, and Hazard Model

> **Document status:** Normative CAD architecture
>
> **Implementation status:** Not implemented

## Purpose

Define location as structured operational information rather than one generic
address field.

## Location Roles

CAD must distinguish location roles, including:

- Caller or reporting-device location.
- Reported incident location.
- Verified incident location.
- Unit location.
- Staging location.
- Command-post location.
- Landing zone.
- Evacuation point.
- Pickup location.
- Transport destination.
- Receiving facility.
- Road closure or hazard area.
- Search area.
- Mutual-aid reporting location.

One location must not silently overwrite another location with a different
operational meaning.

## Location Representation

A location may require:

- Structured civic address.
- Common place or premise name.
- Building.
- Floor.
- Suite, apartment, room, or unit.
- Cross streets.
- Highway, direction, exit, or mile marker.
- Municipality.
- Postal information.
- Coordinates.
- Parcel, facility, or geographic identifier.
- Entrance, gate, or access point.
- Free-form clarification.
- Jurisdiction and response-area derivation.
- Source.
- Confidence.
- Verification state.
- Effective and recorded time.

## Source and Confidence

The system must retain location provenance, including whether the location was:

- Caller reported.
- Device derived.
- Network derived.
- Imported from an external provider.
- Selected from a known premise.
- Geocoded.
- Manually corrected.
- Verified by a unit.
- Estimated.
- Reconciled after degraded operation.

Estimated, unconfirmed, conflicting, and verified locations must be
distinguishable.

## Mapping

The map is a replaceable projection over canonical CAD and geographic data.

Map-provider availability must not determine whether the incident record exists
or whether essential location text can be used.

Map layers may include:

- Incidents.
- Units.
- Stations and posts.
- Response districts.
- Jurisdictions.
- Road closures.
- Hydrants and water sources.
- Hospitals and receiving facilities.
- Schools and public buildings.
- Critical infrastructure.
- Flood, weather, wildfire, or evacuation areas.
- Mutual-aid resources.
- Staging and command locations.

Each layer requires ownership, version, source, freshness, classification, and
failure behavior.

## Accessible Alternative

Essential map information must have an equivalent synchronized representation
that exposes:

- Object identifier.
- Type.
- Status.
- Location description.
- Coordinates when appropriate.
- Assignment.
- Incident.
- Direction of travel when available.
- Last update.
- Age.
- Confidence or accuracy.
- Priority.
- Proximity.
- Jurisdiction or Governed Scope.

## Premise Information

Premise information may include:

- Common name.
- Address and access points.
- Building or site layout reference.
- Contact instructions.
- Fire-protection information.
- Utility shutoff information.
- Hazardous-material reference.
- Gate or access instructions.
- Critical infrastructure classification.
- Known communication limitations.
- Response instructions.
- Supporting document references.

Sensitive access details require classification, exact authorization, limited
display, and appropriate logging.

## Responder-Safety Hazards

A responder-safety warning must not become permanent merely because someone
entered unverified free text.

A hazard record should include:

- Hazard type.
- Structured description.
- Source.
- Verification status.
- Confidence.
- Date added.
- Effective date.
- Review date.
- Expiration.
- Responsible organization.
- Applicable location or scope.
- Access classification.
- Governed independent review and, when policy requires it, a finalized Foundation Approval Request.
- Correction and supersession lineage.
- Usage and display rules.

## Expiration and Review

Hazards and premise instructions may become dangerously stale.

The system must support:

- Required review intervals.
- Expiration.
- Reverification.
- Temporary warnings.
- Disputed warnings.
- Withdrawal.
- Correction.
- Supersession.
- Historical preservation.

## Geospatial Failure

During map or geocoding degradation, CAD must show:

- Which provider or layer is unavailable.
- Last successful update.
- Which derived fields may be stale.
- Whether jurisdiction or response-area derivation is affected.
- Which manual workflows remain available.
- Whether queued corrections require later reconciliation.
