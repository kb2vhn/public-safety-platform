# Public Safety Platform Domain Model

## Purpose

This document defines the conceptual domain model of the Public Safety Platform.

The purpose of this model is to describe the relationships between people, organizations, resources, incidents, records, decisions, and operational events before implementation details such as database tables are created.

The domain model establishes how the platform understands public safety operations.

---

# Domain Philosophy

The Public Safety Platform is built around the concept that public safety operations are interactions between:

* People
* Organizations
* Resources
* Authority
* Events
* Decisions
* Records

The platform must understand not only what occurred, but:

* Who was involved?
* What resources were used?
* What authority existed?
* What decisions were made?
* Why were those decisions allowed?

---

# High-Level Domain Model

```text id="q3l9f7"
                    Organization

                         |

                         |

                    Personnel

                         |

                         |

                 Operational Assignment

                         |

                         |

                    Resource

              /                    \

             /                      \

        Person                    Asset

             \                      /

              \                    /

                Operational Event

                         |

                         |

                    Incident

                         |

          ┌──────────────┼──────────────┐

          |              |              |

        CAD            RMS          Evidence

          |

          |

   Decision Records
```

---

# Core Domain Objects

## Identity

### Purpose

Identity represents who an entity is from an authentication perspective.

Identity answers:

> "Who are you?"

---

## Identity Owns

* Authentication identity
* Account lifecycle
* Authentication references
* External identity mappings

---

## Identity Does Not Own

* Job assignment
* Operational authority
* Qualifications
* Organizational position

Example:

```text id="ynxj3q"
Identity

John.Smith@agency.gov
```

---

# Person

## Purpose

Person represents an individual who participates in the organization.

Person answers:

> "Who is this individual?"

---

## Person Relationships

A person may have:

* Identity
* Personnel record
* Qualifications
* Assignments
* Operational roles

Example:

```text id="p0s9w4"
Person

John Smith

        |

        |

Identity

john.smith@agency.gov

        |

        |

Assignment

Firefighter

        |

        |

Unit

Engine Company 4
```

---

# Organization

## Purpose

Organizations represent the structure in which operations occur.

Examples:

* County
* Department
* Division
* Station
* Company
* Team

---

## Organization Relationships

```text id="7j4d2w"
Organization

      |

      |

Department

      |

      |

Station

      |

      |

Unit
```

Organizations provide context for assignments, authority, and operations.

---

# Operational Resource

## Purpose

Operational Resources represent things that can participate in an operation.

A resource may be:

* Person
* Vehicle
* Equipment
* Unit
* Team

---

## Resource Model

```text id="2q5x8n"
Resource

   |

   ├── Person Resource

   |

   ├── Vehicle Resource

   |

   ├── Equipment Resource

   |

   └── Unit Resource
```

---

# Assignment

## Purpose

Assignment connects resources to operational responsibilities.

Assignment answers:

> "Who or what is assigned to perform this function?"

---

## Example

```text id="4x0j7c"
Person:

John Smith


Assignment:

Firefighter


Unit:

Engine Company 4


Effective:

07:00


Expires:

19:00
```

---

# Qualification

## Purpose

Qualifications describe capabilities a resource possesses.

Examples:

* EMT
* Firefighter Certification
* Supervisor Qualification
* Specialized Training

---

## Important Rule

Qualifications do not grant authority.

They contribute to authority decisions.

Example:

```text id="u8m3kg"
Qualification:

EMT Certification

        +

Assignment:

EMS Provider

        +

Operational Validation

        +

Policy

        ↓

Authority Decision
```

---

# Authority Grant

## Purpose

Authority represents permission granted by organizational policy.

Authority answers:

> "What is this resource allowed to do?"

---

## Authority Depends On

* Identity
* Assignment
* Qualification
* Organization
* Policy
* Time
* Approval requirements

---

## Authority Example

```text id="x4cg92"
Person:

John Smith


Authority:

Approve Evidence Transfer


Valid:

07:00-19:00


Approved By:

Supervisor
```

---

# Operational Event

## Purpose

Operational events represent activities occurring within the organization.

Examples:

* Emergency call
* Dispatch action
* Report creation
* Evidence transfer
* Approval request

---

## Event Model

```text id="v0h6rm"
Operational Event

        |

        |

Participants

        |

        |

Resources

        |

        |

Decisions

        |

        |

Records
```

---

# Incident

## Purpose

An incident represents a public safety occurrence requiring coordination or documentation.

Examples:

* Fire
* Medical call
* Traffic collision
* Investigation

---

## Incident Lifecycle

```text id="b8q0o3"
Reported

   |

Created

   |

Assigned

   |

Active

   |

Resolved

   |

Recorded
```

---

# CAD Domain

CAD manages the real-time operational response.

CAD relationships:

```text id="3p7n2k"
Incident

    |

    |

Dispatch

    |

    |

Assigned Resources

    |

    |

Response Actions
```

CAD consumes:

* Operational Resources
* Authority Decisions
* Workflow
* Notifications

---

# RMS Domain

RMS transforms operational activity into official records.

Relationship:

```text id="7h4v8d"
CAD Incident

        |

        |

RMS Record

        |

        |

Case / Report

        |

        |

Retention
```

RMS preserves official documentation.

---

# Evidence / Property Domain

Evidence represents controlled custody and retention.

Relationship:

```text id="w9r3mq"
Incident

    |

    |

Evidence Item

    |

    |

Custody Transfer

    |

    |

Disposition
```

Every sensitive evidence operation should produce Decision Records.

---

# Decision Domain

## Purpose

The Decision domain records why the platform allowed or denied an operation.

---

## Decision Flow

```text id="a7v1kx"
Request

   |

   |

Decision Engine

   |

   |

Trust Evaluation

   |

   |

Authorization Evaluation

   |

   |

Approval Framework

   |

   |

Decision Record

   |

   |

Justification Chain
```

---

# Decision Record Relationships

A Decision Record may reference:

* Identity
* Device
* Session
* Resource
* Authority
* Policy
* Approval
* Operation

---

# Example Complete Relationship

```text id="6d2nq8"
Person

John Smith

   |

   |

Operational Assignment

Firefighter

   |

   |

Resource

Engine Company 4

   |

   |

Incident

Structure Fire

   |

   |

CAD Dispatch

   |

   |

Decision Engine

Can Engine 4 Respond?

   |

   |

Decision Record

ALLOW

   |

   |

RMS Record

Incident Report

   |

   |

Evidence

Collected Materials
```

---

# Historical Integrity

The platform must preserve historical context.

Current data may change.

Historical records must remain understandable.

Example:

A firefighter changes stations.

The current assignment changes.

Previous incidents must still show:

* Assignment at the time
* Authority at the time
* Qualifications at the time
* Decisions made at the time

---

# Domain Rules

## Rule 1: Identity Is Not Authority

A person being authenticated does not mean they are authorized.

---

## Rule 2: Qualification Is Not Permission

A certification contributes to decisions but does not independently grant access.

---

## Rule 3: Resources Are Assigned, Not Created By Applications

CAD does not create firefighters or vehicles.

It requests available resources.

---

## Rule 4: Decisions Are Recorded

All important decisions create Decision Records.

Both success and failure are meaningful.

---

# Architectural Goal

The domain model provides a common understanding of the Public Safety Platform.

Before adding functionality, the question should be:

> Does this belong to the platform foundation, an operational resource, or a specific operational module?

A well-defined domain model allows the platform to grow while maintaining trust, clarity, and operational reliability.

