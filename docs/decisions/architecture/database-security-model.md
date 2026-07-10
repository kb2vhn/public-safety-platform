# Public Safety Platform Database Security Model

## Purpose

This document defines the security architecture of the Public Safety Platform database layer.

The purpose is to ensure PostgreSQL is implemented as a trusted data foundation that supports:

* Least privilege
* Separation of duties
* Operational accountability
* Secure authorization
* Auditable decisions
* Historical integrity

The database is not treated as a passive data store.

It is an active enforcement layer within the overall trust architecture.

---

# Security Philosophy

The platform follows the principle:

> Access to data is not granted solely because an identity is authenticated. Access is granted only after trust, authority, operational context, and policy requirements are satisfied.

Authentication answers:

> Who are you?

Authorization answers:

> What are you allowed to do?

Operational validation answers:

> Should you be allowed to do this right now?

The database participates in all three concepts.

---

# Security Architecture Layers

The database security model consists of multiple layers:

```text
Public Safety Platform


        Identity

          |

          |

     Device Trust

          |

          |

      Session Trust

          |

          |

 Operational Authority

          |

          |

 Authorization Engine

          |

          |

 Database Security Controls

          |

          |

 PostgreSQL Data
```

No single layer creates unrestricted access.

---

# Trust Boundary Model

A request entering the platform must pass multiple trust checks.

Example:

```text
Request:

Approve Evidence Transfer


Checks:

✓ Certificate Chain Valid

✓ Device Trusted

✓ Identity Authenticated

✓ Session Valid

✓ Operational Authority Active

✓ Approval Framework Passed

✓ Policy Evaluation Passed


Decision:

ALLOW
```

Each validation result becomes part of the Decision Record.

---

# PostgreSQL Security Principles

## Least Privilege

Every database role receives only the permissions required.

No application account should have:

* Superuser privileges
* Ownership of platform schemas
* Unrestricted table access

---

## Separation of Duties

Database responsibilities are separated.

Example:

```text
Database Administrator

        |

        |

Migration Role

        |

        |

Application Roles

        |

        |

Reporting Roles
```

No single operational account should control every layer.

---

# Database Roles

The platform separates database responsibilities.

Example:

## Database Owner

Purpose:

* Own database objects
* Perform structural maintenance

Restrictions:

* Not used by applications
* Not used for daily operations

---

## Migration Role

Purpose:

* Apply schema changes
* Manage controlled database evolution

Restrictions:

* Requires administrative approval

---

## Application Roles

Purpose:

* Perform application operations

Restrictions:

* Limited permissions
* No schema ownership

---

## Reporting Roles

Purpose:

* Read approved information

Restrictions:

* Read-only
* Limited visibility

---

# Schema Security Boundaries

Schemas represent ownership boundaries.

Example:

```text
foundation_identity

foundation_trust

foundation_authorization

foundation_decisions

operational_resources

cad

rms

evidence
```

A module should not directly modify another module's data.

---

# Row Level Security (RLS)

## Purpose

Row Level Security enforces data boundaries at the database layer.

RLS protects against:

* Application mistakes
* Excessive queries
* Unauthorized access paths

---

## Example

A user may be authorized for:

```text
County A
```

but not:

```text
County B
```

The database enforces that boundary.

---

# RLS Principles

RLS policies should be based on:

* Identity context
* Organization membership
* Operational authority
* Approved scope

RLS should not depend only on application logic.

---

# Security Definer Functions

## Purpose

Security definer functions provide controlled operations without granting direct table access.

Example:

Instead of:

```sql
SELECT *
FROM evidence_items;
```

the application requests:

```sql
request_evidence_access()
```

The function:

1. Validates context
2. Evaluates authorization
3. Records decision
4. Returns approved result

---

# Security Definer Requirements

All security definer functions must:

* Define explicit search_path
* Avoid dynamic SQL where possible
* Validate input
* Record meaningful security decisions

Example:

```sql
SET search_path = foundation_authorization, pg_catalog;
```

---

# Authorization Model

Authorization is not a simple permission lookup.

The platform evaluates:

```text
Identity

+

Device

+

Session

+

Organization

+

Operational Authority

+

Policy

+

Time

+

Approval Requirements

        ↓

Decision Engine

        ↓

ALLOW / DENY
```

---

# Operational Authority

Operational authority is separate from database permissions.

Database permissions answer:

> Can the software perform this operation?

Operational authority answers:

> Is this person allowed to perform this action?

Example:

A firefighter may authenticate successfully.

That does not automatically mean:

* They are on shift.
* They are assigned.
* They can approve transfers.
* They can access restricted records.

---

# Time-Bounded Authority

Operational authority is temporary by design.

Examples:

```text
Shift Start

        |

Active Authority

        |

Shift End

        |

Automatic Expiration
```

Authority should expire automatically.

---

# Emergency Extensions

The platform supports temporary operational extensions.

Examples:

* Major incident
* Emergency operations center activation
* Extended response period

The model is:

```text
Authority

+

Scope

+

Reason

+

Expiration
```

Not:

```text
FIRE_EXTENSION

TORNADO_EXTENSION

FLOOD_EXTENSION
```

The platform records why authority existed without creating endless special cases.

---

# Session Security

Sessions are trusted objects.

A session contains context:

* Identity
* Device
* Authentication method
* Start time
* Expiration
* Validation state

---

# Session Rules

Sessions should support:

* Short lifetime
* Device binding
* Revocation
* Revalidation

High-risk operations may require additional validation.

---

# Certificate and PKI Trust

The platform integrates with existing organizational PKI.

Requirements:

* Existing CA hierarchy supported
* Minimum SHA-256 certificate signatures
* Certificate revocation supported
* Intermediate CA support

The platform should not require organizations to replace established PKI infrastructure.

---

# Certificate Lifetime Philosophy

Certificates should be short-lived while remaining operationally practical.

Suggested targets:

| Device Type        | Maximum Lifetime |
| ------------------ | ---------------- |
| Static Workstation | 45 days          |
| Mobile Device      | 31 days          |
| Server / VM        | 7 days           |

The goal is:

* Reduce compromise window
* Avoid unnecessary administrative burden

---

# Decision Record Security

Every authorization decision creates a record.

The platform records:

* Decision ID
* Timestamp
* Operation
* Result
* Identity context
* Device context
* Session context
* Authority context
* Policy version
* Engine version
* Justification Chain

---

# Justification Chain

The Justification Chain explains why a decision occurred.

Example:

```text
Decision ID:

9f8e...


Operation:

Approve Evidence Transfer


Decision:

ALLOW


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


Decision Time:

4.7 ms
```

---

# Security Event Streaming

The database remains the canonical source.

Security and operational events may be streamed through the:

## Platform Provider Streaming Service

Output targets:

* Graylog
* Security Onion
* Elastic Stack
* Splunk
* Other SIEM platforms

Flow:

```text
PostgreSQL

        |

Decision Records

        |

Platform Provider Streaming Service

        |

External Systems
```

---

# Failure Handling

Failures are meaningful events.

Examples:

* Invalid certificate
* Expired authority
* Untrusted device
* Failed approval requirement
* Policy denial

Failures should:

* Be recorded
* Be correlated
* Potentially trigger notifications

Repeated failures may generate operational alerts.

---

# Administrative Access

The PostgreSQL administrator account is a necessary exception.

The platform cannot eliminate the database owner.

However:

* It should not be used by applications.
* Administrative actions should be audited.
* Access should be restricted.
* Use should be reviewed.

The goal is not impossible security.

The goal is controlled accountability.

---

# Security Model Summary

The database security model is based on:

```text
Trust

+

Identity

+

Device

+

Authority

+

Policy

+

Decision

+

Audit
```

The database does not simply answer:

> Can this query run?

It supports the larger question:

> Should this action be trusted in this context?

---

# Final Security Principle

The Public Safety Platform must make every important decision:

* Explainable
* Auditable
* Attributable
* Time-aware
* Context-aware

Security is not a feature added around the database.

Security is part of the database architecture.

