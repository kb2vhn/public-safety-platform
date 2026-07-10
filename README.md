# Public Safety Platform

## Overview

The Public Safety Platform is a modular, security-first operational platform designed to support the needs of modern public safety organizations.

The platform is not built as a single application.

It is designed as a collection of shared capabilities and operational modules built on a common trusted foundation.

Computer Aided Dispatch (CAD) is the first operational module, not the definition of the platform.

The long-term goal is to provide a dependable foundation for public safety operations including:

* CAD
* RMS
* Evidence and Property
* Personnel Operations
* Fleet Management
* Fire and EMS Operations
* Future public safety services

---

# Project Vision

Build software that is secure, understandable, observable, and dependable enough that I would trust my own local community to rely on it during an emergency.

The ultimate measure of success is not the number of features implemented, but whether the people who depend on the system can trust it when it matters most.

---

# Architectural Philosophy

The Public Safety Platform is built around four principles:

## Trust

Every operational action must be evaluated against appropriate identity, device, authority, and policy requirements.

## Accountability

Important decisions must be attributable to:

* Who requested the action
* What authority existed
* When it occurred
* Why it was allowed or denied

## Observability

The platform must record meaningful operational events that allow administrators, investigators, and organizations to understand what occurred.

## Dependability

The system must remain understandable and reliable under the conditions where public safety organizations depend on it most.

---

# Platform Architecture

The platform is organized into three major layers:

```text
                    Public Safety Platform

                            |

        ┌───────────────────┼───────────────────┐

        │                   │                   │

 Platform Foundation  Platform Services  Operational Modules

```

---

# Platform Foundation

The foundation establishes the trusted environment that all modules use.

The foundation provides:

* Identity
* Device Trust
* Organizations
* Operational Authorization
* Authorization
* Approval Framework
* Decision Engine
* Decision Record Repository
* Sessions
* Policy Evaluation
* Configuration
* Cryptographic Audit

The foundation answers:

> Can this operation be trusted and evaluated?

---

# Operational Resources

Operational Resources represents the people, equipment, vehicles, and organizational structures required for public safety operations.

It answers:

> What resources exist, what are they capable of, and what is their current operational state?

Examples:

* Personnel
* Units
* Assignments
* Qualifications
* Certifications
* Vehicles
* Equipment
* Availability
* Resource status

Operational Resources provides the capability layer used by CAD, RMS, Fire, EMS, and future modules.

---

# Operational Modules

Modules provide domain-specific functionality while consuming shared platform capabilities.

```text
000-099  Platform Foundation

100-199  Operational Resources

200-299  CAD

300-399  RMS

400-499  Evidence / Property

500-599  Personnel Management Extensions

600-699  Fleet Management Extensions

700-799  Fire / EMS Specific

800-899  Future Modules

900-999  Deployment / Bootstrap
```

Each module has clear ownership boundaries and does not recreate platform capabilities.

---

# Decision Engine

All important platform decisions are evaluated through the Decision Engine.

The Decision Engine evaluates:

* Identity
* Device trust
* Operational authority
* Operational validation
* Approval requirements
* Policy requirements
* Session state

Every decision produces a record.

---

# Decision Record Repository

The Decision Record Repository is the authoritative record of platform decisions.

Every successful and failed decision is recorded.

A Decision Record contains:

* Decision ID
* Timestamp
* Operation
* Result
* Identity context
* Device context
* Session context
* Authority context
* Approval results
* Policy versions
* Engine versions
* Justification Chain

The platform records not only:

> What happened?

but also:

> Why did it happen?

---

# Justification Chain

The Justification Chain provides a complete explanation of the factors used to reach a decision.

Example:

```text
Decision:

ALLOW

Operation:

Approve Evidence Transfer


Justification:

✓ Certificate Chain Valid

✓ Device Trusted

✓ Identity Authenticated

✓ Operational Authorization Active

✓ Operational Validation Passed

✓ Approval Framework Satisfied

✓ Authority Grant Valid

✓ Session Valid

✓ Authorization Passed


Decision Evaluation Time:

4.7 ms
```

Both successful and failed evaluations are preserved.

---

# Platform Provider Streaming Service

The platform maintains the authoritative operational record.

External systems consume exported representations through the Platform Provider Streaming Service.

The service translates canonical platform records into formats appropriate for:

* Graylog
* Security Onion
* Elastic Stack
* Splunk
* Other SIEM and logging platforms

Architecture:

```text
Decision Record Repository

            |

Platform Provider Streaming Service

            |

+-------------+-------------+-------------+

Graylog     Elastic      Splunk

Security    SIEM         Future
Onion       Systems      Providers
```

External systems provide analysis and monitoring capabilities but do not replace the platform as the system of record.

---

# Security Model

The platform follows a layered trust approach.

Security decisions may include:

* Certificate chain validation
* Device trust validation
* Identity verification
* Operational authorization
* Operational validation
* Approval Framework requirements
* Session validation
* Authorization evaluation

The platform is designed to integrate with an organization's existing PKI infrastructure.

The platform does not require organizations to replace established certificate authorities.

---

# Development Principles

The platform follows these principles:

* Security by design
* Least privilege
* Separation of duties
* Modular architecture
* Clear ownership boundaries
* Vendor independence
* Explainable decisions
* Immutable decision history
* Operational usability

---

# Current Development Focus

Current development is focused on:

* Platform Foundation
* Identity architecture
* Device Trust
* Operational Resources
* Authorization Framework
* Decision Engine
* Decision Record Repository
* Database architecture

Future development will expand operational modules on top of this foundation.

---

# Documentation

Architecture documentation:

```text
docs/
 └── architecture/

     platform-boundaries.md

     module-responsibilities.md

     future architecture documents
```

Database design:

```text
db/
 └── schema/
```

Decision records:

```text
docs/
 └── decisions/
```

---

# Final Goal

The Public Safety Platform exists to create a trusted operational foundation where every important action can be understood, verified, and defended.

The system should answer:

* Who performed the action?
* What authority allowed it?
* What conditions existed at the time?
* What policies were evaluated?
* Why was the decision allowed or denied?

A public safety system should not only function.

It should be trusted.

Every important decision should have an explanation.
Build software that is secure, understandable, observable, and dependable enough that I would trust my own local community to rely on it during an emergency.

The ultimate measure of success is not the number of features implemented, but whether the people who depend on the system can trust it when it matters most.
