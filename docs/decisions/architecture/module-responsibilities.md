# Public Safety Platform Module Responsibilities

## Purpose

This document defines the responsibilities and boundaries of each major Public Safety Platform module.

The purpose of these boundaries is to prevent duplicated functionality, maintain clear ownership of data, and ensure that shared platform capabilities are developed once and reused across all operational modules.

The platform should provide capabilities.

Modules should provide operational functionality.

Each module should have clear ownership of its domain while relying on shared platform services for identity, trust, authorization, workflow, notifications, and auditing.

---

# Module Architecture

The Public Safety Platform is organized into logical ranges:

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

---

# Dependency Model

The platform follows a layered dependency model.

```text
                    Platform Foundation

                            |

                            ▼

                Operational Resources

                            |

             ┌──────────────┼──────────────┐

             ▼              ▼              ▼

            CAD            RMS       Other Modules

             |

             ▼

      Evidence / Property
```

Modules consume platform capabilities.

Modules do not recreate platform capabilities.

---

# 000-099 Platform Foundation

## Purpose

The Platform Foundation establishes trust, identity, authorization, decision accountability, and shared services required by all modules.

The foundation answers:

> "Can this action be trusted and evaluated?"

---

## Owns

* Identity
* Device Trust
* Certificate validation
* Authentication context
* Organizations
* Operational Authorization
* Authorization
* Approval Framework
* Decision Engine
* Decision Record Repository
* Justification Chain
* Session Management
* Policy Evaluation
* Configuration
* Platform Audit

---

## Does Not Own

* Incident workflows
* Personnel administration
* Fleet maintenance
* Reports
* Evidence workflows
* Agency-specific operational processes

---

# 100-199 Operational Resources

## Purpose

Operational Resources represents the people, equipment, vehicles, and organizational structures available to perform public safety operations.

Operational Resources answers:

> "What resources exist, what can they do, and what is their current operational state?"

---

## Owns

* People as operational resources
* Units
* Organizations
* Assignments
* Positions
* Qualifications
* Certifications
* Availability
* Resource status
* Resource relationships
* Operational readiness

---

## Examples

```text
Person

    John Smith

    Assignment:
    Firefighter

    Unit:
    Engine Company 4

    Qualification:
    Firefighter II

    Status:
    Available
```

```text
Vehicle

    Engine 4

    Station:
    Station 1

    Status:
    Available
```

---

## Does Not Own

* Authentication accounts
* Authorization decisions
* Payroll
* HR records
* Vehicle maintenance history

Those belong elsewhere.

---

# 200-299 CAD

## Purpose

Computer Aided Dispatch coordinates real-time response operations.

CAD answers:

> "What is happening, and what resources are responding?"

---

## Owns

* Calls for service
* Incidents
* Dispatch workflow
* Unit assignment workflow
* Response plans
* Mutual aid coordination
* Incident status
* Dispatch history

---

## CAD Uses

CAD consumes:

* Identity
* Operational Resources
* Authorization decisions
* Workflow services
* Notification services
* GIS services

---

## CAD Does Not Own

* Personnel records
* Vehicle maintenance
* Authentication
* Certificates
* Authority grants

CAD requests resources; it does not create them.

---

# 300-399 RMS

## Purpose

Records Management System creates and maintains official operational records.

RMS answers:

> "What official record was created from operational activity?"

---

## Owns

* Reports
* Cases
* Offenses
* Arrest records
* Citations
* Case documentation
* Records retention workflows

---

## RMS Uses

RMS consumes:

* CAD incident information
* Identity
* Operational Resources
* Evidence references
* Approval Framework
* Decision Records

---

## RMS Does Not Own

* User accounts
* Device trust
* Authentication
* Personnel authority
* Evidence custody systems

---

# 400-499 Evidence / Property

## Purpose

Evidence and Property manages controlled custody, retention, and disposition of physical and digital materials.

---

## Owns

* Evidence items
* Property records
* Transfers
* Storage locations
* Retention schedules
* Disposal workflows
* Digital evidence references

---

## Uses

* Decision Engine
* Approval Framework
* Justification Chain
* Operational Authorization

---

## Does Not Own

* User identity
* Authentication
* Personnel assignment
* Case ownership

---

# 500-599 Personnel Management Extensions

## Purpose

Personnel Management provides administrative and lifecycle management capabilities.

This module extends Operational Resources but does not replace it.

---

## Owns

* Personnel records
* Administrative history
* Training records
* Evaluations
* Certifications management
* Scheduling administration
* HR integrations

---

## Does Not Own

* Authentication identity
* Operational authority decisions
* Active resource validation

---

# 600-699 Fleet Management Extensions

## Purpose

Fleet Management provides lifecycle management for vehicles and assets.

---

## Owns

* Maintenance
* Inspections
* Repairs
* Fuel
* Parts
* Costs
* Vendors
* Fleet reporting

---

## Does Not Own

* Dispatch availability
* Authorization
* Resource trust

---

# 700-799 Fire / EMS Specific

## Purpose

Provides specialized workflows for fire and emergency medical operations.

---

## Potential Responsibilities

* Fire apparatus operations
* Preplans
* Hydrant information
* Inspections
* EMS encounters
* Patient care documentation
* Fire investigations
* Specialized operations

---

## Does Not Own

* Identity
* Authorization
* General resource management
* Platform auditing

---

# 800-899 Future Modules

Reserved for future expansion.

Potential examples:

```text
Emergency Management

Jail Management

Court Integration

Training Academy

Public Information

Advanced Analytics

Community Services
```

Future modules must follow established platform boundaries.

---

# 900-999 Deployment / Bootstrap

## Purpose

Deployment, initialization, and system lifecycle support.

---

## Owns

* Database bootstrap
* Initial configuration
* Deployment tooling
* System initialization
* Migration support

---

# Cross-Module Rules

## Identity Rule

No module creates its own authentication system.

All identity must originate from the Platform Foundation.

---

## Authorization Rule

No module independently determines user authority.

Authorization decisions flow through the platform decision framework.

---

## Audit Rule

Important operational decisions must produce Decision Records.

All outcomes must be recorded:

* Successful decisions
* Failed decisions
* Denied requests
* Approval failures
* Validation failures

---

## Integration Rule

External systems consume platform records through the Platform Provider Streaming Service.

External systems do not become the source of truth.

---

# Design Goal

The Public Safety Platform should grow by adding operational capabilities without increasing architectural complexity.

A new module should inherit:

* Trust
* Identity
* Authorization
* Workflow
* Notifications
* Auditability
* Decision accountability

without rebuilding those systems.

The result should be a platform where every important action is:

* Understandable
* Attributable
* Observable
* Explainable
* Dependable

