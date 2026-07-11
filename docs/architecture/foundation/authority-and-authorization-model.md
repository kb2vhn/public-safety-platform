# Authority and Authorization Model

> **Document status:** Normative Platform Foundation architecture.
>
> **Implementation status:** The Foundation SQL migrations provide an initial structural implementation. A requirement described here is not considered fully enforced until the applicable database controls, deployment roles, runtime behavior, automated tests, and operational safeguards are in place.

## Purpose

Distinguish durable sources of authority from individual, time-bounded authorization decisions.

## Architectural Requirements

### Authority

Authority describes what an identity, organization, role, office, service, or delegated relationship is permitted to authorize or perform under a governing policy.

Authority must be scoped by organization, service, purpose, operation, jurisdiction, classification, and effective period.

### Purpose

Every protected request identifies a declared purpose selected from governed purpose definitions. Free-form purpose text may supplement but must not replace the governed purpose identifier.

### Authorization Policy

A policy version defines required trust, eligibility, approval, classification, scope, risk, and lease conditions for an operation.

### Separation of Duties

Authority to request, approve, issue, execute, audit, and alter policy must be separated where the risk warrants it. Role accumulation is evaluated across effective memberships and delegations.

### Delegation

Delegation is explicit, bounded, effective-dated, attributable, revocable, and never broader than the delegator's authority.

### Authorization Decision

Authorization is a specific decision for a specific operation. Durable authority does not create a permanent session or unrestricted capability.

### Denial

Missing policy, ambiguous scope, invalid purpose, conflicting authority, or required `NOT_EVALUATED` stages deny the operation.

## SQL Implementation Mapping

Migration `055_authority_purpose_and_authorization_policy.sql` provides the principal structural implementation. Migrations `065`, `070`, `075`, and `080` apply and record the resulting authorization.

The migration mapping identifies the current structural implementation. It does not, by itself, prove that every requirement in this document is operationally enforced.

## Validation Expectations

The Foundation SQL test framework must test the requirements that can be demonstrated at the database boundary. Runtime, deployment, recovery, and provider behavior must be tested in their respective layers.

## Related Documents

- [Approval Framework](approval-framework.md)
- [Authorization Lease](authorization-lease-model.md)
- [Trust and Decision Engine](trust-and-decision-engine-model.md)
