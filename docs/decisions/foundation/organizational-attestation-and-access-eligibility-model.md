# Platform Organizational Attestation and Access Eligibility Model

## Purpose

This document defines persistent organizational attestations and the scoped Access Eligibility Grants created from them.

Eligibility is a prerequisite boundary. It is not active access.

## Attestation Responsibilities

### Identity Authority

Attests to identity establishment and lifecycle.

### Technical Authority

Attests to identity provisioning, device enrollment, certificates, technical readiness, and technical suspension.

### Personnel Authority

Attests to the person’s valid employment, membership, appointment, contract, volunteer, or affiliate relationship.

### Access Sponsor

Attests to legitimate need, service, module, authority, scope, reason, review date, and expected expiration.

### Service Owner

Attests that requested participation and scope comply with service rules.

### Operational Supervisor Authority

Attests to current assignment and presence after eligibility already exists.

Department names such as IT or HR must not be hard-coded.

## Attestation Authority Record

An authority record defines:

- Category
- Authorizing organization
- Attesting organization
- Authorized role or identity
- Service, module, organization, and jurisdiction scope
- Effective and expiration dates
- Delegation source
- Status and revocation state
- Governing policy version

## Organizational Attestation

An attestation is a persistent record containing:

- Subject
- Category
- Attesting organization
- Acting identity
- Acting authority
- Scope
- Effective period
- Review date
- Reason
- Restrictions
- Policy identifier and version
- Status
- Decision Record

## Access Eligibility Grant

A grant contains:

- Person and identity
- Employing and participating organizations
- Service and module
- Eligible authority definitions
- Organization and jurisdiction scope
- Required attestations
- Participation Agreement
- Eligibility Policy version
- Effective, review, and expiration dates
- Restrictions
- Status
- Decision Records

There must be no global `is_eligible` flag.

## Scope Intersection

```text
Eligibility Scope =
    Requested Scope
    ∩ Participation Scope
    ∩ Sponsorship Scope
    ∩ Attestation Scope
    ∩ Qualification Scope
    ∩ Approval Scope
    ∩ Policy Scope
```

## Activation Boundary

```text
Active Authority
    ⊆ Assignment
    ⊆ Eligibility
    ⊆ Participation Agreement
```

Supervisors may activate less authority, never more.

## Revocation Propagation

Revocation of a required attestation invalidates only dependent eligibility, assignments, validations, and leases.

## Record Trail

Every eligibility `PASS` must identify each required attestation, its issuer, organization, scope, effective period, policy version, and revocation state.

## Architectural Invariants

1. Eligibility exists before active authority.
2. Eligibility is scoped and effective-dated.
3. Every attestation is persistent.
4. Delegation is explicit and revocable.
5. Supervisors cannot expand eligibility.
6. PostgreSQL verifies supporting records.
7. Every result has a Decision Record and Justification Chain.
