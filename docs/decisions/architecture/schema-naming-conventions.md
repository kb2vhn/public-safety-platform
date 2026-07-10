# Public Safety Platform Schema Naming Conventions

## Purpose

This document defines database naming standards for the Public Safety Platform.

The purpose is to create a consistent, understandable, and maintainable database structure as the platform grows across multiple operational domains.

The database must communicate:

* Ownership
* Purpose
* Relationships
* Security boundaries

A developer or administrator should be able to understand the role of a table without reading application code.

---

# Core Naming Philosophy

The platform follows these principles:

## Names Should Describe the Domain

Prefer:

```text
operational_assignments
```

over:

```text
assignments
```

The first communicates ownership.

---

## Avoid Application-Specific Names

Avoid:

```text
cad_users
dispatch_people
rms_accounts
```

Identity and resources belong to the platform, not an application.

---

## Avoid Ambiguous Terms

Avoid:

```text
user
role
event
record
object
data
item
```

unless the context is explicit.

---

# Database Organization

The database is organized by ownership boundaries.

Preferred structure:

```text
public_safety_platform

├── foundation

├── operational_resources

├── cad

├── rms

├── evidence

├── personnel

├── fleet

└── fire_ems
```

---

# Schema Naming

Schemas represent ownership domains.

Format:

```text
<domain>
```

Examples:

```sql
foundation
operational_resources
cad
rms
evidence
fleet
```

---

# Foundation Schemas

Foundation schemas contain platform-wide capabilities.

Examples:

```text
foundation_identity

foundation_trust

foundation_authorization

foundation_decisions

foundation_audit
```

or:

```text
foundation.identity
foundation.trust
foundation.authorization
```

The preferred implementation is PostgreSQL schemas by domain:

```sql
CREATE SCHEMA foundation_identity;
CREATE SCHEMA foundation_trust;
CREATE SCHEMA foundation_authorization;
```

---

# Table Naming

Tables use:

```text
plural_snake_case
```

Examples:

Correct:

```text
identities

device_certificates

authority_grants

decision_records

audit_events
```

Avoid:

```text
identity

device_certificate

AuthorityGrant

tbl_users
```

---

# Primary Keys

All primary keys use UUID.

Format:

```text
<entity>_id
```

Examples:

```text
identity_id

device_id

decision_id

incident_id

resource_id
```

Example:

```sql
identity_id uuid primary key
```

---

# Foreign Keys

Foreign keys use the referenced entity name.

Example:

```sql
identity_id uuid references identities(identity_id)
```

Avoid:

```sql
owner
user_ref
person_number
```

---

# Timestamps

All timestamps use explicit names.

Required:

```text
created_at

updated_at
```

For business events:

```text
occurred_at

approved_at

expired_at

revoked_at
```

All timestamps should use:

```sql
TIMESTAMPTZ
```

---

# Boolean Naming

Boolean fields should describe a state.

Preferred:

```text
is_active

is_trusted

is_verified

is_revoked
```

Avoid:

```text
active

trusted

verified
```

---

# Status Fields

Status values should use controlled types.

Preferred:

```sql
CREATE TYPE device_trust_status AS ENUM
(
 'TRUSTED',
 'SUSPENDED',
 'REVOKED'
);
```

Avoid:

```text
status varchar(50)
```

without validation.

---

# Version Fields

All policy and engine versions must be explicit.

Examples:

```text
authorization_engine_version

policy_version

trust_policy_version
```

---

# Audit Fields

Standard audit fields:

```text
created_at

created_by_identity_id

updated_at

updated_by_identity_id
```

Example:

```sql
created_by_identity_id uuid
```

---

# Decision Record Naming

Decision records are central to the platform.

Use:

```text
decision_records
```

not:

```text
security_logs

access_logs

audit_logs
```

because decisions are operational records, not only security events.

---

# Justification Chain Naming

The platform uses:

```text
justification_chain
```

or:

```text
decision_justifications
```

Avoid:

```text
evidence_chain
```

because the platform is broader than law enforcement evidence.

---

# Authority Naming

Avoid:

```text
permissions
```

for operational authority.

Use:

```text
authority_grants
```

because authority is contextual.

Example:

```text
authority_grants

person

authority

scope

valid_from

valid_until

approved_by
```

---

# Resource Naming

Operational resources use the generic term:

```text
resource
```

Examples:

```text
resources

resource_assignments

resource_capabilities

resource_status_history
```

A resource may represent:

* Person
* Unit
* Vehicle
* Equipment

---

# Person vs Identity

These are separate concepts.

Identity:

```text
Who can authenticate?
```

Person:

```text
Who exists operationally?
```

Example:

```text
identities

        |

        |

persons

        |

        |

operational_assignments
```

---

# Incident Naming

An incident is an operational event.

Use:

```text
incidents
```

Avoid:

```text
calls
tickets
jobs
cases
```

because different modules may have different meanings.

---

# Module Table Prefixes

Do not prefix tables unnecessarily.

Avoid:

```text
cad_incidents
cad_units
cad_dispatches
```

inside a CAD schema.

Prefer:

```text
cad.incidents

cad.dispatches

cad.units
```

The schema provides ownership.

---

# History Tables

Historical tables should be explicit.

Preferred:

```text
authority_grant_history

resource_status_history

assignment_history
```

Avoid:

```text
old_data

archive

backup
```

---

# Junction Tables

Many-to-many tables describe relationships.

Format:

```text
<entity>_<entity>
```

Example:

```text
resource_capabilities

organization_memberships
```

---

# Enum Naming

Enums should describe the domain.

Example:

```sql
device_trust_status

decision_result

incident_priority
```

Values use uppercase:

```text
ALLOW

DENY

PENDING
```

---

# Function Naming

Functions should describe actions.

Format:

```text
verb_entity
```

Examples:

```text
evaluate_authorization()

create_decision_record()

validate_device_trust()
```

Avoid:

```text
do_auth()

process()
check()
```

---

# Security Function Rules

Security-sensitive functions must:

* Use explicit search_path
* Define security behavior clearly
* Be reviewed
* Produce audit information where appropriate

---

# Migration Naming

Migration files use:

```text
<number>_<description>.sql
```

Example:

```text
010_identity.sql

020_device_trust.sql

070_decision_engine.sql
```

---

# Module Numbering

Database numbering follows platform boundaries:

```text
000-099 Platform Foundation

100-199 Operational Resources

200-299 CAD

300-399 RMS

400-499 Evidence / Property

500-599 Personnel Extensions

600-699 Fleet Extensions

700-799 Fire / EMS

800-899 Future Modules

900-999 Deployment / Bootstrap
```

---

# Documentation Relationship

Database changes should update:

```text
SQL Migration

        ↓

Architecture Documentation

        ↓

Domain Model

        ↓

Data Ownership
```

The database should never become the only documentation.

---

# Final Principle

The database schema is part of the platform architecture.

Good naming creates:

* Clear ownership
* Easier audits
* Safer development
* Better onboarding
* Long-term maintainability

A future developer should be able to understand the system by reading the schema names alone.

The database should explain itself.

