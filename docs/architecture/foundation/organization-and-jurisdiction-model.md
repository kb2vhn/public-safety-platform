# Organization and Jurisdiction Model

> **Document status:** Normative Platform Foundation architecture.
>
> **Implementation status:** The Foundation SQL migrations provide an initial structural implementation. A requirement described here is not considered fully enforced until the applicable database controls, deployment roles, runtime behavior, automated tests, and operational safeguards are in place.

## Purpose

Represent independent organizations and the geographic, legal, operational, and service scopes within which they may act.

## Architectural Requirements

### Organization Independence

An organization retains authority over its people, participation, policies, data, approvals, and delegated relationships. Shared hosting does not transfer that authority to the hosting organization.

### Jurisdiction

Jurisdictions may represent geographic areas, legal authority, dispatch responsibility, service coverage, mutual-aid scope, or another governed boundary.

A jurisdiction record must identify its type, owning organization, validity period, and lifecycle state.

### Relationships

Organization relationships, delegated authority, and cross-jurisdiction access must be explicit, versioned, scoped, and revocable.

### Authorization Use

Protected decisions must evaluate the actor organization, target organization, requested service, applicable jurisdiction, and any governing participation or federation agreement.

### History

Mergers, renaming, boundary changes, temporary coverage, and supersession must preserve historical identifiers and effective periods.

## SQL Implementation Mapping

Migration `030_organizations_and_jurisdictions.sql` provides the principal structural implementation. Migrations `040`, `045`, and `055` consume organization and jurisdiction scope.

The migration mapping identifies the current structural implementation. It does not, by itself, prove that every requirement in this document is operationally enforced.

## Validation Expectations

The Foundation SQL test framework must test the requirements that can be demonstrated at the database boundary. Runtime, deployment, recovery, and provider behavior must be tested in their respective layers.

## Related Documents

- [Service Participation and Federation](service-participation-and-federation-model.md)
- [Organizational Attestation and Access Eligibility](organizational-attestation-and-access-eligibility-model.md)
- [Authority and Authorization](authority-and-authorization-model.md)
