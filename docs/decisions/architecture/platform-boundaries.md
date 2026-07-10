# Public Safety Platform Boundaries

## Purpose

This document defines the architectural boundaries of the Public Safety Platform.

The purpose of these boundaries is to ensure that the platform remains modular, maintainable, secure, and understandable as new operational capabilities are added.

The platform must grow through well-defined modules and shared services, not through duplicated functionality or tightly coupled systems.

---

# Core Architectural Principle

The Public Safety Platform is not a single application.

It is a platform composed of:

```text id="h8r4qp"
Platform Foundation

        +

Platform Services

        +

Operational Modules
```

Each layer has defined responsibilities.

---

# Layer Model

```text id="f9p3xd"
                    Public Safety Platform


                         Users / Systems


                              |

                              ▼


                    Operational Modules

             CAD | RMS | Evidence | Fire | EMS


                              |

                              ▼


                    Platform Services

      Workflow | Notifications | Reporting | Streaming


                              |

                              ▼


                  Platform Foundation

 Identity | Trust | Authorization | Decisions | Audit
```

---

# Boundary 1: Platform Foundation

## Purpose

The Platform Foundation establishes trust and provides shared capabilities required by every module.

The foundation answers:

> "Can this request be trusted enough to evaluate?"

---

## Foundation Owns

* Identity
* Device Trust
* Authentication context
* Organizations
* Operational Authorization
* Authorization
* Approval Framework
* Decision Engine
* Decision Records
* Session Security
* Policy Evaluation
* Configuration
* Cryptographic validation
* Platform audit

---

## Foundation Does Not Own

* Dispatch workflows
* Reports
* Evidence lifecycle
* Personnel administration
* Fleet maintenance
* Agency-specific operations

---

# Boundary 2: Platform Services

## Purpose

Platform Services provide reusable capabilities shared by multiple modules.

They solve common problems once.

---

## Platform Services Include

Examples:

```text id="x2c7fz"
Workflow Engine

Notification Engine

Reporting Engine

Attachment Service

GIS Service

Template Service

Scheduling Services

Platform Provider Streaming Service
```

---

## Platform Service Rules

Platform Services:

* May depend on Platform Foundation.
* May support multiple modules.
* Must not contain module-specific business rules.
* Must not become a hidden operational application.

---

## Example

Correct:

```text id="7j4zq1"
Notification Engine

Input:
Send notification request

Output:
Notification delivered
```

Incorrect:

```text id="m3k8yv"
Notification Engine

Rule:
If CAD fire call then notify Fire Chief
```

That decision belongs to workflow and policy.

---

# Boundary 3: Operational Modules

## Purpose

Operational Modules provide domain-specific functionality.

They represent the activities public safety organizations perform.

---

## Modules

```text id="9c4v1m"
200-299 CAD

300-399 RMS

400-499 Evidence / Property

500-599 Personnel Management

600-699 Fleet Management

700-799 Fire / EMS

800-899 Future Modules
```

---

# Module Rules

Operational modules:

* Own their operational workflows.
* Own their domain records.
* Consume platform capabilities.
* Do not recreate foundation services.

---

# Dependency Direction

Dependencies must flow downward.

Correct:

```text id="6m1q8d"
CAD

 |

Platform Services

 |

Platform Foundation
```

Incorrect:

```text id="r5y2pk"
Platform Foundation

 |

CAD
```

The foundation must never become dependent on an operational module.

---

# Identity Boundary

## Rule

Authentication identity and operational identity are separate concepts.

Identity answers:

> Who are you?

Operational Resources answers:

> What role can you perform?

Example:

```text id="d7n4vq"
Identity

John.Smith


Operational Resource

Firefighter


Authority

Operate Engine 4
```

---

# Trust Boundary

The platform establishes trust through multiple validation layers.

A request may require:

* Certificate validation
* Device trust
* Identity verification
* Session validation
* Operational authorization
* Approval Framework
* Policy evaluation

No single attribute should create unrestricted authority.

---

# Authorization Boundary

Modules must not make independent authorization decisions.

Correct:

```text id="p2z8jk"
CAD Request

        |

Decision Engine

        |

ALLOW / DENY

        |

Decision Record
```

Incorrect:

```text id="q6v1ms"
CAD Logic:

User is supervisor

Allow
```

---

# Data Boundary

Each domain has one authoritative owner.

Examples:

| Data                    | Owner                 |
| ----------------------- | --------------------- |
| Authentication identity | Platform Foundation   |
| Device trust            | Platform Foundation   |
| Operational assignments | Operational Resources |
| Incidents               | CAD                   |
| Official reports        | RMS                   |
| Evidence custody        | Evidence Module       |
| Vehicle maintenance     | Fleet Module          |

Other modules may reference data but do not own it.

---

# Audit Boundary

All significant actions must produce an auditable decision trail.

The platform must preserve:

* Who requested the action
* What operation was requested
* What authority existed
* What policies were evaluated
* What decision was made
* Why the decision occurred

---

# External Integration Boundary

External systems are consumers of platform information.

Examples:

* Graylog
* Security Onion
* Elastic
* Splunk

The Platform Provider Streaming Service exports canonical platform records.

External systems:

* May analyze data.
* May create alerts.
* May create dashboards.

External systems do not replace the platform system of record.

---

# Expansion Boundary

New functionality must answer:

## Is this required by all modules?

If yes:

It belongs in Platform Foundation or Platform Services.

---

## Is this specific to an operational workflow?

If yes:

It belongs in an Operational Module.

---

## Is this organization-specific behavior?

If yes:

It belongs in configuration, policy, or workflow.

---

# Architecture Review Questions

Before adding a new capability:

1. Who owns this data?
2. Which layer does this belong to?
3. Does another module already provide this capability?
4. Does this create a new trust boundary?
5. Does this require a new decision type?
6. Can this be configured instead of hard coded?

---

# Final Boundary Statement

The Public Safety Platform should become more capable over time without becoming more complex.

The goal is not to build one large application.

The goal is to create a trusted operational platform where new capabilities inherit:

* Identity
* Trust
* Authorization
* Workflow
* Notifications
* Auditability
* Decision accountability

without rebuilding the foundation.

A module should add capability.

It should not redefine the platform.

