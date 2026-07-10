# Platform Trust and Decision Engine Model

## Purpose

This document defines how the Foundation establishes trust, authenticates identity, verifies organizational and operational authority, evaluates requested actions, and records the complete basis for every result.

## Core Principles

> Trust must be established before identity is evaluated.

> Certificates and MFA are assurance inputs. They do not grant access.

> Authentication establishes identity, not authority.

> The Go backend evaluates and attests.

> PostgreSQL independently verifies and enforces.

> No high-level result is valid without a complete supporting-record chain.

## Assurance Is Not Authorization

The following are distinct:

```text
Certificate Valid
        ≠
Device Trusted
        ≠
Identity Authenticated
        ≠
Organization Participating
        ≠
Person Eligible
        ≠
Assignment Active
        ≠
Approval Satisfied
        ≠
Authority Active
        ≠
Purpose Permitted
        ≠
Classification Compatible
        ≠
Authorization Lease Valid
        ≠
Operation Allowed
```

A certificate proves only that a credential was presented and validated according to policy.

MFA increases confidence in identity authentication.

Neither proves organizational need, assignment, authority, purpose, scope, or permission.

## Runtime Flow

```text
Requesting System
        ↓
Cryptographic Trust Establishment
        ↓
Device Trust
        ↓
Identity Authentication
        ↓
Service Participation
        ↓
Organizational Attestations
        ↓
Access Eligibility
        ↓
Assignment and Current Validation
        ↓
Approval Framework
        ↓
Authority and Purpose Evaluation
        ↓
Data Classification and Handling Evaluation
        ↓
Go Decision Evaluation
        ↓
Signed Trust Assertion
        ↓
PostgreSQL Trust Gate
        ↓
Authorization Lease
        ↓
Protected Operation
        ↓
Decision Record and Justification Chain
```

## Evaluation States

Every stage must produce:

```text
PASS
FAIL
NOT_REQUIRED
NOT_EVALUATED
```

### PASS

Requires authoritative supporting records.

### FAIL

Must record examined state, required state, and reason.

### NOT_REQUIRED

Must reference the exact policy rule making the stage unnecessary.

### NOT_EVALUATED

Must record why evaluation did not occur.

A required `NOT_EVALUATED` result must fail safely.

## Composite Evaluations

A conclusion such as:

```text
PASS - CJIS handling requirements satisfied
```

must be a parent evaluation containing child evaluations for:

- Classification
- Policy version
- Organization participation
- Identity assurance
- Device trust
- Personnel relationship
- Eligibility
- Authority
- Purpose
- Destination
- Approval
- Lease

The parent may pass only when every required child passes.

## Go Responsibilities

The Go backend may:

- Validate mTLS and certificate chains
- Perform revocation checks
- Resolve devices and identities
- Gather policy and authoritative record identifiers
- Evaluate application logic
- Produce signed Trust Assertions
- Request leases
- Coordinate workflows
- Record application-stage evaluation results

Go must not create database authority by supplying:

- Role names
- Boolean flags
- User identifiers
- Device identifiers
- Client timestamps
- Unverified scope
- Unversioned policy names

## PostgreSQL Responsibilities

PostgreSQL independently verifies:

- Trust Provider
- Connection role
- Assertion signature, audience, environment, lifetime, and replay state
- CA, certificate, and device state
- Identity state
- Service participation
- Attestation authority and records
- Eligibility
- Assignment and validation
- Approval
- Authority
- Purpose
- Classification and handling requirements
- Organization and jurisdiction scope
- Policy versions
- Lease expiration and revocation

## No God Access

Except for the unavoidable infrastructure-superuser boundary, no identity may independently possess unrestricted authority across:

- Identity administration
- Device trust
- Organization administration
- Policy administration
- Approval
- Authority granting
- Data access
- Decision-record administration
- Audit administration
- Operational execution

The Decision Engine must evaluate both individual grants and combined authority.

## Architectural Invariants

1. Untrusted systems do not reach user authentication.
2. Certificates and MFA do not grant access.
3. Authentication alone does not establish authority.
4. No `PASS` exists only in memory.
5. PostgreSQL verifies Go-supplied claims independently.
6. Required `NOT_EVALUATED` fails safely.
7. Role accumulation is evaluated.
8. Every final result is reconstructable from persistent records.
