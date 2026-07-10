# Two-Person Concept

## Purpose

In many systems, compromising a single administrative account can give an attacker broad control over users, permissions, configuration, and logs.

This platform is intended to prevent that failure mode from the beginning.

The goal is to create a resilient authorization model in which no single person, department, or compromised account can silently grant unrestricted access. Administrative authority should be divided across independent parties so that sensitive access requires multiple, verifiable actions.

This model is referred to as the **Two-Person Concept**, **Two-Person Rule**, or **Dual Authorization**.

## Core Questions

The design starts with two questions:

1. Who may administer the platform?
2. What may each administrator actually administer?

A title alone must not provide unrestricted access.

For example, a department director may need broad visibility during a mass-casualty event, but that does not automatically mean the director needs permission to create users, alter operational records, modify active CAD notes, or administer the database.

Authority should follow actual operational responsibility.

## Separation of Duties

Access decisions should involve multiple organizational authorities.

### Human Resources or Personnel Authority

Human Resources or another authorized personnel office verifies that:

- the person is employed or otherwise officially affiliated;
- the employment or assignment is current;
- the person's status supports the requested access;
- separation, retirement, suspension, or other personnel changes are reflected promptly.

HR verifies personnel facts. It does not create technical access or assign operational authority.

### Information Technology

IT creates and maintains the required technical accounts, systems, and access infrastructure.

IT may:

- create approved directory or platform accounts;
- maintain authentication infrastructure;
- register approved devices;
- revoke access immediately when a security threat is identified;
- operate platform infrastructure within its assigned boundary.

IT must not be able to unilaterally grant operational authority merely because it controls the technical environment.

Not every IT employee should have access to critical systems. Access should be limited to specifically authorized technical personnel with a demonstrated operational need.

### Department or Service Leadership

Department leadership confirms the operational need for access.

Leadership may:

- approve participation in the service;
- assign the person to an organizational unit, shift, platoon, or equivalent structure;
- identify the operational role the person is expected to perform;
- approve supervisors or other operational authorities within its own boundary.

Department leadership should not receive unrestricted database modification privileges merely because it holds executive authority.

### Shift or Operational Supervisor

The supervisor confirms whether an already eligible person is actually present, assigned, and expected to work during a specific operational period.

A supervisor may confirm or revoke current operational activation for people within the supervisor's authority.

A supervisor must not grant authority to:

- another supervisor outside the supervisor's chain of responsibility;
- a person above the supervisor's authority;
- an individual who has not already completed the required personnel, technical, and leadership approvals.

This is a **check-left-only** model: authority may be exercised only within the approved subordinate scope.

## Access Establishment Flow

A possible access-establishment sequence is:

1. HR or Personnel verifies the person's current official status.
2. IT creates the required technical accounts and device associations.
3. Authorized IT leadership confirms the technical access request.
4. Department leadership confirms the operational need.
5. Department leadership assigns the person to an approved shift, platoon, unit, or equivalent scope.
6. The operational supervisor confirms that the person is present and expected to work.
7. The platform evaluates all required trust, identity, eligibility, assignment, and authorization conditions.
8. The platform issues short-lived operational authority for the approved scope.

At the end of the approval process, the person may have **eligibility**, but not automatically active access.

Active access should require current operational validation.

## Shift-Bound Operational Access

Public-safety operations run continuously, and personnel may be called in outside normal schedules. Static directory logon-hour restrictions are therefore insufficient.

The platform should maintain its own operational assignments and activation rules.

A normal shift schedule may be recorded in advance. A supervisor may then:

- confirm a scheduled person;
- mark a person absent;
- add an already eligible person for additional coverage;
- approve a documented temporary override.

The platform may allow a configurable grace period before and after the scheduled assignment, such as 10 or 15 minutes.

Outside that approved period, operational authority should expire or be suspended unless an authorized override exists.

The database clock should be authoritative for authorization expiration.

## Device Trust

The platform must verify that sensitive requests originate from an approved device.

A device certificate may be used as one trust input, particularly in environments already using short-lived machine certificates for 802.1X or similar controls.

Examples include:

- HR actions performed only from approved HR-managed systems;
- IT authorization actions performed only from approved IT systems;
- operational leadership actions performed only from approved leadership systems;
- shift activation performed only from approved operational terminals.

Cross-department device use should fail when the policy requires department-specific trust.

Examples:

- IT should not approve personnel actions from an HR workstation.
- Department leadership should not perform protected approvals from an untrusted or unrelated system.
- A shift supervisor should not activate personnel from a non-operational workstation when policy requires an approved operations terminal.

Every denied attempt should be recorded and may generate a security alert.

## Important Trust Boundary

A valid device certificate does **not** grant access by itself.

It only establishes one trust fact.

The platform must separately evaluate:

- device trust;
- identity;
- authentication assurance;
- personnel status;
- organizational participation;
- access eligibility;
- assignment;
- supervisor validation;
- purpose;
- requested authority;
- policy;
- approval requirements;
- classification and scope.

A compromised approved device must not automatically provide unrestricted access.

## Short-Lived Operational Authority

After successful evaluation, the platform should issue short-lived operational authority rather than permanent always-on access.

The current architecture represents this through a short-lived **Authorization Lease**, not by treating a certificate as the authorization itself.

The lease should:

- be scoped to a service and purpose;
- include only approved authorities;
- expire using PostgreSQL time;
- be revocable;
- require reevaluation after logout, restart, sleep, session loss, or other invalidating events;
- be bound to the relevant identity, device, session, and decision record.

The user must repeat the authorization process when the previous operational context is no longer trustworthy.

## Audit and Decision Records

Every material step must be recorded.

The record should identify:

- who initiated the request;
- who verified personnel status;
- who performed the technical action;
- who approved the operational need;
- who assigned the person;
- who activated or revoked current access;
- which devices were used;
- which policies and policy versions were evaluated;
- when each action occurred;
- the result of every required evaluation;
- the reason for approval, denial, revocation, or override.

The platform's Decision Record Repository and Justification Chain provide the canonical record of these actions.

No participant should be able to erase or silently rewrite the history of an access decision.

## Accreditation Triangle

```text
┌─────────────────────────────────────────────┐
│ IT or Technical Authority                   │
│                                             │
│ • Creates approved technical access         │
│ • May revoke access defensively              │
│ • Cannot unilaterally grant operational      │
│   authority                                  │
└─────────────────────────────────────────────┘
                      │
                      │ Technical action
                      ▼
┌─────────────────────────────────────────────┐
│ HR or Personnel Authority                   │
│                                             │
│ • Verifies official personnel status        │
│ • Provides independent attestation          │
│ • Does not create operational authority     │
└─────────────────────────────────────────────┘
                      │
                      │ Personnel attestation
                      ▼
┌─────────────────────────────────────────────┐
│ Department or Service Leadership            │
│                                             │
│ • Confirms operational need                 │
│ • Assigns organizational and shift scope    │
│ • Does not receive unrestricted data-write  │
│   or database-administration authority      │
└─────────────────────────────────────────────┘
```

The operational supervisor then validates current presence and duty status within the approved organizational boundary.

## Defensive Revocation

Immediate revocation is different from granting authority.

Authorized security or technical personnel may need the ability to suspend or revoke access quickly when:

- credentials are suspected of compromise;
- a device is lost or compromised;
- employment status changes;
- a certificate is revoked;
- an assignment is no longer valid;
- suspicious activity is detected;
- an emergency containment action is required.

Defensive revocation should not require the same approval sequence as granting new authority, but it must still be logged, attributable, reviewable, and subject to policy.

## No Single-Party Administrative Control

The platform must not rely on a simple flag such as:

```sql
is_admin = true
```

Sensitive authority should result from the intersection of multiple independently verified records.

Conceptually:

```text
Identity Established
    ∩ Device Trusted
    ∩ Personnel Status Attested
    ∩ Service Participation Approved
    ∩ Access Eligibility Granted
    ∩ Assignment Active
    ∩ Supervisor Validation Current
    ∩ Required Approvals Complete
    ∩ Purpose Allowed
    ∩ Policy Evaluation Passed
    = Short-Lived Operational Authority
```

No single successful condition should imply full access.

## Role-Accumulation Protection

Separately limited roles must not combine into unrestricted authority.

The platform must evaluate incompatible authority sets and role accumulation so that one person cannot bypass the Two-Person Concept merely by obtaining several individually limited roles.

Examples of incompatible combinations may include:

- technical account creation and final operational approval;
- personnel attestation and self-approval;
- request initiation and required independent approval;
- evidence custody and disposition approval;
- platform operation and unrestricted data ownership.

## Limitations

The Two-Person Concept reduces the risk of single-account compromise, insider abuse, privilege creep, and unauthorized access.

It does not make compromise mathematically impossible.

The platform must also address:

- collusion;
- compromised endpoints;
- compromised identity providers;
- database-administrator abuse;
- operating-system compromise;
- policy tampering;
- backup compromise;
- logging failure;
- recovery from trusted artifacts.

These concerns are addressed through additional security, observability, integrity, and recovery controls.

## Final Principle

> No single person, account, department, device, certificate, or administrative title should be sufficient to create unrestricted authority.

The platform should require independent, scoped, attributable, time-bound, and policy-verified actions before sensitive access becomes active.
