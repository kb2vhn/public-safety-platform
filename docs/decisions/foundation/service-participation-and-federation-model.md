# Platform Service Participation and Federation Model

## Purpose

This document defines how independent organizations participate in shared services.

## Core Principle

Shared infrastructure does not create centralized authority.

Each organization remains authoritative for the facts and responsibilities it owns.

## Platform Service

A service has:

- Stable identifier
- Service Owner
- Platform Operator
- Policy
- Effective period
- Status
- Supported domain modules

## Service Participation Agreement

An agreement may define:

- Service
- Service Owner
- Participating Organization
- Platform Operator
- Permitted operations
- Organization and jurisdiction scope
- Data ownership and custody
- Accepted authorities
- Required approvals
- Delegation rules
- Effective, review, expiration, suspension, and termination dates
- Governing document version and hash

## Agreement States

```text
DRAFT
PENDING_APPROVAL
ACTIVE
SUSPENDED
EXPIRED
TERMINATED
SUPERSEDED
```

## Federation

The Foundation supports multiple:

- Identity Authorities
- Technical Authorities
- Personnel Authorities
- Access Sponsors
- Supervisor Authorities
- Service Owners
- Data Owners
- Data Custodians

Each may act only within an explicit scope.

## Delegation

Delegation must be:

- Explicit
- Scoped
- Time-bounded
- Versioned
- Approved
- Attributable
- Revocable

Re-delegation is prohibited by default.

## Cross-Organization Access

Cross-organization access requires:

- Active participation
- Data Owner permission
- Purpose authorization
- Classification compatibility
- Scope match
- Approval where required
- Current authority
- Valid lease

## Record Trail

Every participation, suspension, delegation, amendment, and termination must reference:

- Governing agreement
- Exact version
- Effective dates
- Acting identities
- Approvals
- Decision Record

## Architectural Invariants

1. Hosting does not create organizational authority.
2. Participation in one service does not imply another.
3. Agreements are explicit, scoped, versioned, and effective-dated.
4. Delegation is revocable.
5. Cross-organization access is policy-controlled.
6. Data ownership is not inferred from custody.
7. PostgreSQL verifies agreements, delegation, scope, and expiration.
