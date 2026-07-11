# Organizational Attestation and Access Eligibility Model

> **Document status:** Normative Platform Foundation architecture.
>
> **Implementation status:** The Foundation SQL migrations provide an initial structural implementation. A requirement described here is not considered fully enforced until the applicable database controls, deployment roles, runtime behavior, automated tests, and operational safeguards are in place.

## Purpose

Represent time-bounded assertions that an identity, account, device, role, or relationship is eligible for a protected purpose.

## Architectural Requirements

### Attestation Meaning

An attestation is a signed or otherwise attributable statement from an authorized issuer. It is not permanent truth and is never authority by itself.

Examples include active employment, current training, device compliance, supervisor confirmation, on-duty status, or membership in an eligible group.

### Required Properties

An attestation identifies:

- Subject,
- Issuer and issuer authority,
- Attestation type,
- Organization and service audience,
- Purpose or eligibility scope,
- Issued, effective, and expiration times,
- Revocation and replacement state,
- Source and correlation context.

### Eligibility

Eligibility combines relevant attestations, lifecycle state, policy, and current time. A stale or unverified attestation must not silently remain valid.

### Independence

The issuer must possess current authority to make the attestation. Self-attestation is prohibited where policy requires independent verification.

### Re-evaluation

Changes to employment, organization, security status, device state, or required qualification must invalidate or supersede dependent eligibility as policy requires.

## SQL Implementation Mapping

Migrations `020` and `025` establish identity and lifecycle context. Migration `045_attestations_and_access_eligibility.sql` establishes the principal attestation and eligibility structures.

The migration mapping identifies the current structural implementation. It does not, by itself, prove that every requirement in this document is operationally enforced.

## Validation Expectations

The Foundation SQL test framework must test the requirements that can be demonstrated at the database boundary. Runtime, deployment, recovery, and provider behavior must be tested in their respective layers.

## Related Documents

- [Trust and Decision Engine](trust-and-decision-engine-model.md)
- [Approval Framework](approval-framework.md)
- [Lifecycle Versioning and Historical Lineage](lifecycle-versioning-and-historical-lineage-model.md)
