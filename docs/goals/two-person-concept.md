
# Two-Person Concept

## Goal

No single compromised identity, account, device, administrator, or service
should be able to obtain unrestricted platform authority or silently approve
its own material escalation.

The two-person concept is a separation-of-duties goal. It does not mean every
routine action requires two people.

## Policy-Driven Application

Independent approval is appropriate when an action could materially affect:

- Privileged access
- Cross-organization access
- Sensitive data disclosure
- Security policy
- Emergency authority
- Module-owned evidence or record integrity
- Risk acceptance
- Compliance exceptions
- Destructive administration
- Recovery or break-glass procedures

The governing policy determines the required stages, number of actors,
authority, independence dimensions, and duration.

## More Than Two Clicks

A valid two-person control requires more than two recorded actions.

The platform evaluates:

- Distinct effective identities
- Requester independence
- Directly affected identity independence
- Current identity and organizational eligibility
- Current session and device trust when required
- Exact Authority Grants
- Delegation lineage
- Distinct organization when required
- Duplicate effective actor
- Explicit reciprocal approval cycles
- Incompatible authority
- Separation of duties
- Approval scope
- Approval expiration
- Withdrawal, correction, and supersession

Different accounts, sessions, devices, roles, organizations, or delegated
grants do not make one identity count as two people.

## Record Requirements

A material approval chain retains exact record types:

- Approval Request
- Governing Approval Policy Version
- Required Approval Policy Stages
- Approval Action Records
- Approval stage-evaluation records
- Acting identity, organization, session, and Authority Grant context
- Requester and directly affected identity context
- Correlation and approval-chain identifiers
- Timestamps and expiration
- Final Approval Request status
- Linked Decision Record
- Later withdrawal, correction, supersession, revocation, or exception records

Approval Action Records are append-only through the controlled write boundary.
Append-only semantics apply to Approval Action Records. Evidence may instead
refer to a legal, assurance, records-management, or module concept.

## Failure Behavior

Missing, expired, revoked, conflicting, duplicate, non-independent, or
not-evaluated required conditions fail closed.

An Approval Request cannot finalize as approved when a required stage is
unsatisfied.

## Emergency Authority

Emergency authority must be explicit, narrowly scoped, time-limited,
attributable, and reviewed.

It must not become a permanent bypass.

Emergency policy may change the required approval path, but it does not erase
request, actor, authority, decision, or lifecycle records.

## Normative Models

- [Approval Independence and Separation of Duties Model](../architecture/foundation/approval-independence-and-separation-of-duties-model.md)
- [Approval Framework](../architecture/foundation/approval-framework.md)
- [Authority and Authorization](../architecture/foundation/authority-and-authorization-model.md)
- [Authorization Evaluation Contract](../architecture/foundation/authorization-evaluation-contract.md)
- [Decision Record Repository](../architecture/foundation/decision-record-repository.md)

Migrations `050` and `055` provide the initial structural implementation.
Phase 4 plans migration `083` for the controlled independence and
separation-of-duties boundary.
