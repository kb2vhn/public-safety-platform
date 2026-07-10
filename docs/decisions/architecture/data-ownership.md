# Public Safety Platform Data Ownership

## Purpose

This document defines ownership boundaries for data within the Public Safety Platform.

The goal is to ensure that every piece of information has a clear authoritative source while allowing modules to reference information required for their operational workflows.

The platform follows a simple principle:

> Data should have one authoritative owner. Other modules may consume or reference that data but should not recreate ownership.

---

# Data Ownership Principles

## Single Source of Truth

Each domain has one authoritative owner.

Examples:

* Identity owns user identity.
* Operational Resources owns operational capability.
* CAD owns dispatch activity.
* RMS owns official records.
* Evidence owns custody records.

---

## Reference, Do Not Duplicate

Modules should store references to data owned elsewhere.

Incorrect:

```text
CAD Database

Person Name:
John Smith

Rank:
Captain

Certification:
EMT
```

Correct:

```text
CAD Incident

Assigned Resource:

Person ID:
12345

Unit ID:
67890
```

CAD knows who responded.

Operational Resources knows who that person is.

---

## Historical Preservation

While current information has an authoritative owner, operational records must preserve historical context.

Example:

A person changes assignment.

Current state:

```text
John Smith

Current Assignment:

Fire Station 2
```

Historical incident:

```text
Incident 2026-07-10

Responding Resource:

John Smith

Assignment at Time:

Engine Company 4
```

Historical records must remain understandable even when current information changes.

---

# Ownership Model

```text
000-099 Platform Foundation

        Owns trust, identity, decisions, and platform state


100-199 Operational Resources

        Owns operational capability


200-299 CAD

        Owns real-time incident coordination


300-399 RMS

        Owns official records


400-499 Evidence / Property

        Owns custody and retention


500-599 Personnel Management

        Owns administrative personnel lifecycle


600-699 Fleet Management

        Owns asset lifecycle


700-799 Fire / EMS

        Owns specialized operational workflows
```

---

# 000-099 Platform Foundation Ownership

## Identity

Owns:

* User identity
* Authentication identity
* Account lifecycle
* External identity references
* Identity attributes required for authentication

Does not own:

* Personnel assignments
* Operational roles
* Employment history

---

## Device Trust

Owns:

* Device identity
* Device certificates
* Trust status
* Device validation history

Does not own:

* Hardware inventory
* Fleet assets
* User assignments

---

## Authorization

Owns:

* Permission evaluation
* Policy decisions
* Authority evaluation
* Decision outcomes

Does not own:

* Operational qualifications
* Training records

---

## Decision Record Repository

Owns:

* Decision records
* Justification Chains
* Evaluation results
* Engine versions
* Policy versions

This is the authoritative record of:

> Why the platform allowed or denied an action.

---

# 100-199 Operational Resources Ownership

## Purpose

Operational Resources represents what an organization can use to perform operations.

---

## Owns

### People as operational resources

Examples:

* Firefighter
* Dispatcher
* EMS provider
* Supervisor

---

### Units

Examples:

* Engine Company 4
* Medic Unit 2
* Dispatch Group A

---

### Assignments

Examples:

* Person assigned to unit
* Person assigned to shift
* Person assigned to operational role

---

### Qualifications

Examples:

* EMT Certification
* Firefighter Certification
* Specialized training

---

### Resource Availability

Examples:

* Available
* Assigned
* Unavailable
* Out of service

---

## Does Not Own

* Authentication accounts
* Payroll records
* HR documents
* Maintenance history

---

# 200-299 CAD Ownership

## Purpose

CAD owns the real-time response workflow.

---

## Owns

* Calls for service
* Incidents
* Dispatch actions
* Unit assignments
* Response status
* Dispatch timeline

---

## References

Operational Resources:

* Who responded
* What unit responded
* What capabilities existed

Identity:

* Who performed dispatch actions

Decision Records:

* Why assignments or approvals occurred

---

## Does Not Own

* Personnel qualifications
* Vehicle maintenance
* User accounts

---

# 300-399 RMS Ownership

## Purpose

RMS owns official operational records.

---

## Owns

* Reports
* Cases
* Arrest records
* Citations
* Case lifecycle
* Records retention

---

## References

CAD:

* Incident origin
* Response history

Evidence:

* Associated evidence items

Identity:

* Report authors
* Reviewers

---

## Does Not Own

* Authentication
* Personnel authority
* Evidence custody

---

# 400-499 Evidence / Property Ownership

## Purpose

Evidence manages controlled custody and retention.

---

## Owns

* Evidence items
* Property records
* Custody transfers
* Storage locations
* Retention lifecycle

---

## References

RMS:

* Related case

Identity:

* Custodians

Operational Resources:

* Authorized personnel

Decision Records:

* Transfer approvals
* Access decisions

---

# 500-599 Personnel Management Ownership

## Purpose

Administrative personnel lifecycle.

---

## Owns

* Personnel files
* Training records
* Evaluations
* Administrative history
* HR integrations

---

## Does Not Own

* Authentication identity
* Operational authorization
* Live availability

---

# 600-699 Fleet Management Ownership

## Purpose

Vehicle and asset lifecycle management.

---

## Owns

* Maintenance
* Inspections
* Repairs
* Fuel
* Costs
* Vendors

---

## Does Not Own

* Dispatch availability
* Operational assignment
* User authority

---

# 700-799 Fire / EMS Ownership

## Purpose

Specialized fire and EMS workflows.

---

## Owns

Examples:

* Fire preplans
* Hydrant information
* EMS documentation
* Patient care workflows
* Specialized inspections

---

## Does Not Own

* Identity
* Authorization
* General resources

---

# External System Data Ownership

External systems are consumers of platform records.

Examples:

* Graylog
* Security Onion
* Elastic
* Splunk

These systems may:

* Store copies
* Analyze records
* Create dashboards
* Generate alerts

They do not become authoritative sources.

---

# Platform Provider Streaming Service

The Platform Provider Streaming Service provides controlled distribution of canonical records.

The flow is:

```text
Platform Data Owner

        |

Decision Record Repository

        |

Platform Provider Streaming Service

        |

External Systems
```

External systems receive representations of platform data.

---

# Data Integrity Rule

When a module requires information owned elsewhere:

1. Reference the authoritative record.
2. Do not duplicate ownership.
3. Preserve required historical context.
4. Record decisions through the platform decision framework.

---

# Architectural Goal

The Public Safety Platform should maintain a clear chain of ownership for every important piece of information.

At any point, the system should answer:

* Who owns this data?
* Who changed it?
* When did it change?
* Why was it changed?
* What decisions depended on it?

A trustworthy system requires not only secure access, but clear ownership of information.

