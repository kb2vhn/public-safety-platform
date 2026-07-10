# Platform Authority and Authorization Model

## Purpose

This document defines generic authority, authorization policy, purpose, scope, delegation, and separation-of-duty controls.

## Identity Is Not Authority

Authentication identifies the requester.

Authority determines what the organization has granted the requester permission to do.

## Authority Definition

An Authority Definition describes a capability recognized by the platform.

Examples:

```text
VIEW_CLASSIFIED_RECORD
APPROVE_FINANCIAL_REPORT
CREATE_OPERATIONAL_ASSIGNMENT
EXPORT_RESTRICTED_DATA
MANAGE_SERVICE_PARTICIPATION
```

Authority definitions must describe capabilities, not event reasons.

## Authority Grant

A grant includes:

- Recipient
- Authority Definition
- Service
- Organization
- Jurisdiction
- Purpose
- Scope
- Effective period
- Granting identity and authority
- Approval requirements
- Delegation state
- Revocation state
- Policy version
- Decision Records

## Purpose

Purpose may be required independently of authority.

Examples:

- Operational response
- Financial reporting
- Audit
- Records administration
- Legal review
- Security review
- Public-record response

Authority for one purpose does not automatically authorize another.

## Scope

Authority may be scoped by:

- Service
- Module
- Organization
- Jurisdiction
- Operation
- Resource type
- Individual resource
- Classification
- Data Owner
- Purpose
- Time

## Delegation

A person may not delegate authority:

- They do not possess
- Outside their scope
- Beyond their expiration
- When policy prohibits delegation

Re-delegation is prohibited by default.

## No Self-Elevation

An identity may not:

- Grant itself authority
- Extend its own authority
- Broaden its own scope
- Remove its own restrictions
- Approve its own independent elevation
- Circumvent policy through another identity

## Separation of Duties

The authorization model must evaluate incompatible combinations.

No non-infrastructure identity may independently control all of:

- Policy creation
- Policy activation
- Identity lifecycle
- Eligibility
- Approval
- Authority granting
- Operational execution
- Decision-record administration
- Audit review

## Architectural Invariants

1. Identity is not authority.
2. Approval is not authority.
3. Eligibility is not authority.
4. Authority is explicit, scoped, effective-dated, and revocable.
5. Purpose is independently evaluated where required.
6. No self-elevation.
7. Role accumulation is evaluated.
8. Every grant and revocation has a Decision Record.
