# Platform Authentication and Authorization Evaluation Model

> **Document status:** Normative Platform Foundation architecture.

## Purpose

Define how the Foundation receives authentication claims, validates identity and device context, evaluates bounded authority, and records the complete basis for each material result.

## Distinct Security Questions

The Foundation answers separate questions:

```text
Was an Authentication Assertion received?
Was it verified under the configured Trust Provider?
Is the device trusted?
Which identity was authenticated?
Is the Organization participating?
Is the identity currently eligible?
Is the session active?
Is the Governed Purpose permitted?
Is the Governed Operation permitted?
Does the requested Governed Scope match?
Is the Data Classification compatible?
Is an Authority Grant active?
Is separation of duties satisfied?
Are required approvals satisfied?
Is the Authorization Lease valid for this exact operation?
May the protected operation proceed?
```

A successful answer to one question does not imply success for another.

## Authentication Assertions

An Authentication Assertion is an externally issued set of authentication claims received from a configured Trust Provider.

Lifecycle state determines whether it is:

```text
RECEIVED
VERIFIED
CONSUMED
REJECTED
EXPIRED
REVOKED
```

Only a verified, current, context-matching assertion may be consumed.

An Authentication Assertion is an input to authorization. It does not grant authorization.

## Assurance Is Not Authorization

A valid certificate, successful MFA result, verified Authentication Assertion, trusted device, or active session increases confidence in identity context.

None independently proves:

- Organizational participation
- Access Eligibility
- Authority
- Governed Purpose
- Governed Operation
- Governed Scope
- Approval
- Data Classification compatibility
- Authorization Lease validity
- Permission to perform the protected operation

## Authorization Evaluation Process

The Authorization Evaluation Process is the governed sequence of stage evaluations.

It is not required to exist as one monolithic service.

A typical flow is:

```text
Request
    ↓
Authentication Assertion Verification
    ↓
Device and Identity Resolution
    ↓
Session Validation
    ↓
Organization Participation and Access Eligibility
    ↓
Governed Purpose, Operation, Scope, Target, and Classification
    ↓
Authority and Separation of Duties
    ↓
Independent Approval
    ↓
Authorization Policy Evaluation
    ↓
Authorization Lease
    ↓
Controlled PostgreSQL Operation
    ↓
Decision Record and Decision Explanation Chain
```

## Evaluation States

Every governed stage returns exactly one result:

```text
PASS
FAIL
NOT_REQUIRED
NOT_EVALUATED
```

- `PASS` requires authoritative supporting records.
- `FAIL` records the examined state, required state, and stable reason code.
- `NOT_REQUIRED` references the exact policy rule making the stage unnecessary.
- `NOT_EVALUATED` records why evaluation did not occur.

A required `FAIL` or `NOT_EVALUATED` denies the request.

## Application Responsibilities

The future application layer may:

- Validate transport security and configured certificate chains
- Validate external authentication protocols
- Perform revocation checks
- Resolve device and identity candidates
- Gather exact authoritative record identifiers
- Evaluate application workflow conditions
- Request an Authorization Lease
- Coordinate approval workflows
- Record application-stage evaluations

It must not create database authority by supplying unverified:

- Role names
- Boolean authorization flags
- Identity identifiers
- Device identifiers
- Client timestamps
- Free-form scope
- Unversioned policy names

## PostgreSQL Responsibilities

PostgreSQL independently verifies the minimum conditions required by a controlled protected operation, including applicable:

- Authentication Assertion state, context, lifetime, and replay state
- Device and certificate state
- Identity state
- Organization participation
- Access Eligibility
- Session state
- Governed Purpose
- Governed Operation
- Governed Scope
- Data Classification
- Authority Grant
- Separation of duties
- Approval
- Policy version
- Authorization Lease scope, time, revocation, and use state

## No Unrestricted Operational Identity

Except for the unavoidable infrastructure-superuser boundary, no application, user, administrator, or accumulated role set independently controls all of:

- Identity lifecycle
- Device trust
- Organization administration
- Policy activation
- Approval
- Authority granting
- Protected data access
- Decision Record administration
- Audit review
- Operational execution

## Architectural Invariants

1. Received Authentication Assertions are not treated as verified merely because they exist.
2. Authentication establishes identity context, not authority.
3. Certificates and MFA do not grant access by themselves.
4. Every required stage has a persistent result.
5. PostgreSQL independently verifies selected application-supplied claims.
6. Required `NOT_EVALUATED` fails closed.
7. Accumulated authority and incompatible grants are evaluated.
8. Every final material result is reconstructable from persistent records.
