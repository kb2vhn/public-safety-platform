# Service Participation and Federation Model

> **Document status:** Normative Platform Foundation architecture.
>
> **Implementation status:** The Foundation SQL migrations provide an initial structural implementation. A requirement described here is not considered fully enforced until the applicable database controls, deployment roles, runtime behavior, automated tests, and operational safeguards are in place.

## Purpose

Govern how organizations participate in platform services and how authority crosses organizational boundaries.

## Architectural Requirements

### Platform Services

A platform service is a governed capability offered through the shared platform. Service registration identifies ownership, criticality, lifecycle, and configuration boundaries.

### Participation

An organization must explicitly participate in a service before its identities, devices, or resources can receive authority within that service.

Participation is effective-dated, revocable, and independent of infrastructure tenancy.

### Federation

Federation records the governed relationship that permits one organization or service to rely on another organization's identity, authority, data, or operational action.

Federation must define:

- Participating parties,
- Services and operations,
- Governed Scope and classification limits,
- Purpose,
- Effective period,
- Approval and revocation authority,
- Governing agreement or policy version.

### Fail-Closed Behavior

Missing, expired, revoked, or non-applicable participation or federation denies the cross-boundary operation.

### Provider Separation

An external identity, monitoring, or integration provider does not become a federation authority merely because it supplies infrastructure.

## SQL Implementation Mapping

Migration `035_platform_services_and_configuration.sql` establishes platform services. Migration `040_service_participation_and_federation.sql` establishes participation and federation structures.

The migration mapping identifies the current structural implementation. It does not, by itself, prove that every requirement in this document is operationally enforced.

## Validation Expectations

The Foundation SQL test framework must test the requirements that can be demonstrated at the database boundary. Runtime, deployment, recovery, and provider behavior must be tested in their respective layers.

## Related Documents

- [Organization and Governed Scope](organization-and-governed-scope-model.md)
- [Authority and Authorization](authority-and-authorization-model.md)
- [Governed Document and Policy Versioning](governed-document-and-policy-versioning-model.md)
