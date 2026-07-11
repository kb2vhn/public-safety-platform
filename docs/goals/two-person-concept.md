# Two-Person Concept

## Goal

No single compromised identity, account, device, administrator, or service should be able to obtain unrestricted platform authority or silently approve its own material escalation.

The two-person concept is a separation-of-duties goal. It does not mean every routine action requires two people.

## Application

Dual authorization is appropriate when an action could materially affect:

- Privileged access,
- Cross-organization access,
- Sensitive data disclosure,
- Security policy,
- Emergency authority,
- Evidence or record integrity,
- Risk acceptance,
- Compliance exceptions,
- Destructive administration,
- Recovery or break-glass procedures.

The governing policy determines which actions require independent approval.

## Independence Requirements

A valid two-person control requires more than two recorded clicks.

The requester and approver must be independently eligible for their roles. The platform must evaluate:

- Distinct identities,
- Distinct effective authority where required,
- Current employment and organizational eligibility,
- Current session and device trust,
- Conflicts of interest,
- Delegation limits,
- Approval scope,
- Approval expiration,
- Self-approval and circular-approval prevention.

## Record Requirements

A material approval must retain:

- The request,
- The governing policy version,
- Required approval conditions,
- Each approval or denial,
- Actor and organization context,
- Relevant trust and session context,
- Timestamps and expiration,
- The final decision,
- Any subsequent revocation, supersession, or exception.

## Failure Behavior

Missing, expired, revoked, conflicting, or not-evaluated required approval must fail closed.

Emergency authority must be explicit, narrowly scoped, time-limited, recorded, and reviewed. It must not become a permanent bypass.

## Normative Models

This goal is implemented architecturally through:

- [Approval Framework](../architecture/foundation/approval-framework.md)
- [Authority and Authorization](../architecture/foundation/authority-and-authorization-model.md)
- [Trust and Decision Engine](../architecture/foundation/trust-and-decision-engine-model.md)
- [Decision Record Repository](../architecture/foundation/decision-record-repository.md)

SQL migrations `050`, `055`, `070`, `075`, and `080` provide the initial structural implementation.
