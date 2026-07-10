# Decision: PostgreSQL as the Platform Data Foundation

## Status

Accepted

## Date

2026-07-10

## Decision

The Public Safety Platform will use PostgreSQL as the authoritative relational data store for core platform data and operational module data.

PostgreSQL was selected because it provides the reliability, consistency, security controls, extensibility, and operational maturity required for a public safety platform.

The database is not considered a CAD database.

It is the canonical data foundation for the entire Public Safety Platform.

---

# Context

The Public Safety Platform is designed as a modular system consisting of:

* Platform Foundation
* Operational Resources
* CAD
* RMS
* Evidence / Property
* Personnel Management Extensions
* Fleet Management Extensions
* Fire / EMS Modules
* Future operational modules

Multiple modules require shared concepts including:

* Identity
* Organizations
* Resources
* Authority
* Decisions
* Audit records
* Historical information

A database design based around a single application would create duplication and inconsistent sources of truth.

The database must support a platform architecture.

---

# Requirements

The database must support:

## Security

* Strong authentication controls
* Role separation
* Least privilege
* Row Level Security
* Secure function execution
* Auditable access patterns

## Integrity

* Transaction consistency
* Referential integrity
* Historical preservation
* Immutable decision records where appropriate

## Extensibility

The schema must allow additional modules without redesigning foundational concepts.

## Auditability

The system must support:

* Operational audit
* Security audit
* Legal review
* Incident reconstruction

---

# Architectural Model

PostgreSQL supports the following logical layers:

```text id="jv7x4h"
PostgreSQL Platform Database


000-099 Platform Foundation

        |

        |

100-199 Operational Resources

        |

        |

200-899 Operational Modules

        |

        |

900-999 Deployment / Bootstrap
```

---

# Schema Organization

Schemas should follow ownership boundaries.

Example:

```text id="m0w7ka"
platform_identity

platform_trust

platform_authorization

platform_decisions

platform_audit

operational_resources

cad

rms

evidence

fleet

personnel
```

Each schema owns its domain.

---

# Data Ownership

The database follows the platform data ownership model.

Examples:

| Domain                  | Owner                        |
| ----------------------- | ---------------------------- |
| Identity                | Platform Foundation          |
| Device Trust            | Platform Foundation          |
| Authorization Decisions | Platform Foundation          |
| Operational Resources   | Operational Resources Module |
| Incidents               | CAD                          |
| Reports                 | RMS                          |
| Evidence Custody        | Evidence Module              |
| Maintenance             | Fleet Module                 |

---

# Security Model

The database must not be directly exposed to end-user applications.

Application access should occur through controlled service layers.

The preferred architecture:

```text id="6p2f8s"
User Application

        |

        |

API / Service Layer

        |

        |

Authorization Framework

        |

        |

PostgreSQL
```

---

# Database Roles

Database access must follow separation of duties.

Examples:

```text id="4h9v2m"
Database Owner

    |
    |
Migration Role

    |
    |
Application Roles

    |
    |
Read-Only Reporting Roles
```

No application account should have unrestricted database ownership privileges.

---

# Application Access Model

Applications should not directly execute unrestricted SQL.

The application should request operations through controlled interfaces.

Example:

Incorrect:

```text id="5p3v8q"
Application

SELECT *
FROM evidence_items;
```

Correct:

```text id="1n9c5v"
Application

Request:

View Evidence Item


Authorization Engine

        |

PostgreSQL Function/API

        |

Decision Record Created
```

---

# PostgreSQL Features Used

The platform may leverage:

## Row Level Security

Purpose:

Ensure data access follows organizational and authorization boundaries.

---

## Security Definer Functions

Purpose:

Provide controlled operations while limiting direct table access.

Requirements:

* Explicit search_path
* Reviewed ownership
* Audited changes

---

## UUID Identifiers

Purpose:

Avoid predictable sequential identifiers.

---

## JSONB

Purpose:

Support flexible configuration and future module expansion.

JSONB should not replace relational modeling where relationships are important.

---

## Extensions

Potential extensions:

* uuid-ossp
* pgcrypto
* PostGIS

Additional extensions require architectural review.

---

# Audit and Decision Storage

PostgreSQL stores canonical platform decision records.

A decision record includes:

* Decision ID
* Timestamp
* Requesting identity
* Device context
* Session context
* Operation
* Result
* Policy version
* Authorization version
* Engine version
* Justification Chain

Example:

```text id="8m4qzs"
Decision:

ALLOW


Operation:

Approve Evidence Transfer


Validation:

Certificate Chain Valid

Device Trusted

Identity Authenticated

Authority Valid

Approval Framework Passed


Policy Version:

8.3


Authorization Engine:

2.4.1
```

---

# External Logging Integration

PostgreSQL remains the system of record.

External platforms receive exported records.

Example:

```text id="1q8r6w"
PostgreSQL

Decision Records

        |

        |

Platform Provider Streaming Service

        |

        |

Graylog
Security Onion
Elastic
Splunk
```

External systems provide:

* Monitoring
* Alerting
* Search
* Correlation

They do not replace the canonical record.

---

# Migration Philosophy

Database changes should be:

* Version controlled
* Reviewed
* Documented
* Repeatable

Migrations should follow architectural ownership boundaries.

Example:

```text id="5k2v9m"
000-099 Foundation

100-199 Operational Resources

200-299 CAD

300-399 RMS
```

---

# Why PostgreSQL

PostgreSQL provides:

* Mature relational modeling
* Strong consistency
* Advanced security features
* Row Level Security
* JSON capabilities
* Geographic extensions
* Long-term operational stability
* Large ecosystem support

It aligns with the platform goals of:

* Security
* Reliability
* Transparency
* Auditability

---

# Final Decision Statement

PostgreSQL will serve as the authoritative data foundation for the Public Safety Platform.

The database design will follow platform boundaries, clear ownership, least privilege, and auditable decision-making.

The goal is not simply to store information.

The goal is to maintain a trusted operational record of public safety activity.

