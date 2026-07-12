# Approval Framework

> **Document status:** Normative Platform Foundation architecture.
>
> **Implementation status:** The Foundation SQL migrations provide an initial structural implementation. A requirement described here is not considered fully enforced until the applicable database controls, deployment roles, runtime behavior, automated tests, and operational safeguards are in place.

## Purpose

Provide reusable, attributable, policy-driven approval without embedding domain-specific workflow in the Foundation.

## Architectural Requirements

### Approval Request

A request identifies the requester, organization, service, purpose, target, requested operation, governing policy, required approvals, and expiration.

### Approval Requirement

Policy defines the number, type, independence, authority, organization, and timing of required approvals.

### Approval Decision

An approver may approve, deny, abstain, or record another explicitly modeled outcome. Each decision is an append-oriented event with actor, authority, session, time, reason, and scope.

### Independence Controls

Where required, the platform must prevent:

- Self-approval,
- Circular approval,
- Duplicate approval by the same effective actor,
- Approval using expired or delegated authority outside its scope,
- Approval after request expiration,
- Approval by an actor with a prohibited conflict.

### Two-Person Authorization

Dual authorization is a policy configuration built on this framework. It is not a hard-coded assumption for every action.

### Revocation and Supersession

An approval is not edited after issuance. Revocation, withdrawal, correction, and supersession are recorded as new events.

### Finalization

A request may satisfy its approval requirement only when all required approvals are current, independent, applicable, and valid at the time of authorization.

## SQL Implementation Mapping

Migration `050_approval_framework.sql` provides the principal structural implementation. Migrations `055`, `065`, `070`, `075`, and `080` consume approval results.

The migration mapping identifies the current structural implementation. It does not, by itself, prove that every requirement in this document is operationally enforced.

## Validation Expectations

The Foundation SQL test framework must test the requirements that can be demonstrated at the database boundary. Runtime, deployment, recovery, and provider behavior must be tested in their respective layers.

## Related Documents

- [Two-Person Concept](../../goals/two-person-concept.md)
- [Authority and Authorization](authority-and-authorization-model.md)
- [Decision Record Repository](decision-record-repository.md)
