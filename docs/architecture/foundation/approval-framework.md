# Platform Approval Framework

## Purpose

The Approval Framework provides policy-driven support for operations requiring one or more approvals.

Approval is organizational consent. It is not authority by itself.

## Supported Models

- Single approval
- Supervisor approval
- Independent approval
- Dual authorization
- Multi-party approval
- Multi-stage approval
- External organization approval
- Judicial approval
- Emergency approval

## Core Objects

- Approval Policy
- Approval Policy Version
- Approval Request
- Approval Stage
- Approval Requirement
- Approval Action
- Approval Withdrawal
- Approval Escalation

## Separation of Duties

Policies may require:

- Different identity
- Different assignment
- Different organizational role
- Different organization
- Different chain-of-command position
- No conflicting ownership
- No prior incompatible participation

Self-approval is prohibited by default.

## Incompatible Authority Sets

The Approval Framework must reject a request when the same identity or combined authority set would allow one person to:

- Request
- Approve
- Activate
- Execute
- Review
- Alter the resulting audit trail

unless a narrowly scoped emergency policy explicitly permits a limited exception.

## Approval Lifecycle

```text
PENDING
PARTIALLY_APPROVED
APPROVED
DENIED
EXPIRED
WITHDRAWN
CANCELLED
ESCALATED
COMPLETED
```

## Versioning

Every approval result references:

- Stable policy identifier
- Version and revision
- Approval date
- Effective period
- Specific rule or stage
- Document hash
- Engine version

## Record Trail

Every action records:

- Acting identity and organization
- Acting authority
- Device and session
- Authorization Lease
- Scope
- Reason
- Timestamp
- Supporting records
- Decision Record

## Architectural Invariants

1. Approval does not replace authority.
2. Approval does not execute the operation.
3. Self-approval is denied by default.
4. Approval Actions are append-only.
5. Role concentration is evaluated.
6. Withdrawal creates a new linked record.
7. Every approval result has a persistent record trail.
8. PostgreSQL verifies approval state independently.
