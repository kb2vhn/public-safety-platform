# Public Safety Platform SQL Migration Map

## Purpose

This document maps the original database schema implementation to the new Public Safety Platform architecture.

The original SQL migrations were developed around the initial concept of building a secure Computer Aided Dispatch (CAD) system.

The architecture has since evolved into a modular Public Safety Platform.

The original work is not discarded.

It becomes the first implementation attempt of the Platform Foundation and early operational modules.

This document defines:

* What remains
* What moves
* What is renamed
* What is redesigned
* What becomes a new module

---

# Migration Philosophy

The migration follows these principles:

## Preserve Security Work

Existing work around:

* Trust
* Identity
* Authorization
* Sessions
* RLS
* Audit
* Cryptographic integrity

remains foundational.

---

## Correct Ownership Boundaries

Data and functionality move to the module that owns the domain.

Example:

Incorrect:

```text
CAD owns personnel
```

Correct:

```text
Operational Resources owns personnel

CAD consumes operational resources
```

---

## Avoid Artificial Compatibility

The goal is not to preserve old table structures.

The goal is to preserve the correct architectural intent.

---

# Current Migration Structure

## Original Structure

```text
db/schema/testing/

000_trust_foundation.sql

001_device_trust.sql

002_operational_authority.sql

003_authorization.sql

004_sessions.sql

006_cad_core.sql

007_cad_security.sql

008_cad_dispatch.sql

009_cad_personnel.sql

010_privilege_validation.sql

011_identity_database_binding.sql

012_row_level_security.sql

013_cryptographic_audit_chain.sql

014_security_authorization_api.sql

015_operational_integrity.sql

016_database_role_separation.sql

017_database_identity_lifecycle.sql

018_session_security_hardening.sql

019_security_boundary_hardening.sql

999_security_bootstrap.sql
```

---

# New Architecture Structure

```text
db/schema/

foundation/

operational_resources/

cad/

rms/

evidence/

personnel/

fleet/

fire_ems/

bootstrap/
```

---

# Foundation Migration Mapping

## 000_trust_foundation.sql

## New Location

```text
foundation/000_trust_foundation.sql
```

## Status

KEEP / REFACTOR

---

## Purpose

Establishes the initial trust model.

Includes concepts:

* Platform roles
* Trust concepts
* Base security structures

---

## Changes

Remove CAD-specific assumptions.

The foundation must exist before any operational module.

---

# 001_device_trust.sql

## New Location

```text
foundation/020_device_trust.sql
```

## Status

KEEP / REFACTOR

---

## Purpose

Device trust establishes whether a device is trusted before access decisions occur.

---

## Future Additions

Support:

* Certificate chain validation
* Device lifecycle
* Certificate expiration
* Revocation state
* Device posture

---

# 002_operational_authority.sql

## New Location

```text
foundation/040_operational_authority.sql
```

## Status

KEEP / EXPAND

---

## Purpose

Defines authority independent from identity.

Identity answers:

> Who are you?

Authority answers:

> What are you allowed to do?

---

## Future Additions

Support:

* Time-bound authority
* Supervisor approval
* Emergency extensions
* Operational validation

---

# 003_authorization.sql

## New Location

```text
foundation/050_authorization.sql
```

## Status

KEEP / REFACTOR

---

## Purpose

Authorization evaluation framework.

---

## Future Additions

Include:

* Policy evaluation
* Decision Engine integration
* Policy version tracking

---

# 004_sessions.sql

## New Location

```text
foundation/060_sessions.sql
```

## Status

KEEP / HARDEN

---

## Purpose

Manage authenticated sessions.

---

## Future Additions

Include:

* Device binding
* Certificate context
* Session expiration
* Step-up validation

---

# CAD Migration Mapping

# 006_cad_core.sql

## New Location

```text
cad/200_cad_core.sql
```

## Status

MOVE / REFACTOR

---

## Purpose

Core CAD incident model.

---

## Changes

Remove:

* Identity ownership
* Authorization logic
* Personnel ownership

Replace with references to:

* Identity
* Operational Resources
* Decision Records

---

# 007_cad_security.sql

## New Location

```text
cad/210_cad_security.sql
```

## Status

MERGE / REDUCE

---

## Purpose

CAD-specific security requirements.

---

## Changes

Move platform security controls into foundation.

CAD keeps only:

* CAD workflow restrictions
* Incident-level authorization rules

---

# 008_cad_dispatch.sql

## New Location

```text
cad/220_cad_dispatch.sql
```

## Status

KEEP / EXPAND

---

## Purpose

Dispatch operations.

---

## Depends On

* Operational Resources
* Workflow Engine
* Notification Engine
* Decision Engine

---

# 009_cad_personnel.sql

## New Location

```text
operational_resources/
```

## Status

MOVE / SPLIT

---

## Reason

CAD does not own personnel.

Personnel and resources exist before CAD.

---

## New Breakdown

```text
operational_resources/

110_people.sql

120_organizations.sql

130_units.sql

140_assignments.sql

150_qualifications.sql

160_availability.sql
```

---

# Security and Validation Mapping

# 010_privilege_validation.sql

## New Location

```text
foundation/070_decision_engine.sql
```

## Status

RENAME / EXPAND

---

## Purpose

Become the central authorization decision mechanism.

---

# 011_identity_database_binding.sql

## New Location

```text
foundation/010_identity.sql
```

## Status

KEEP

---

## Purpose

Identity relationships.

---

# 012_row_level_security.sql

## New Location

```text
foundation/090_security_boundaries.sql
```

## Status

SPLIT

---

## New Structure

```text
foundation/

091_rls_policies.sql

092_security_functions.sql

093_privilege_validation.sql
```

---

# 013_cryptographic_audit_chain.sql

## New Location

```text
foundation/080_decision_records.sql
```

## Status

RENAME / REFACTOR

---

## Reason

Replace evidence-oriented terminology.

New concept:

## Justification Chain

The platform records:

* Inputs
* Evaluations
* Decisions
* Reasons

---

# 014_security_authorization_api.sql

## New Location

```text
foundation/055_authorization_api.sql
```

## Status

KEEP / REFACTOR

---

## Purpose

Controlled authorization interface.

---

# 015_operational_integrity.sql

## New Location

```text
foundation/085_operational_validation.sql
```

## Status

KEEP / EXPAND

---

## Purpose

Validate operational context.

Examples:

* On shift
* Assigned
* Qualified
* Approved

---

# 016_database_role_separation.sql

## New Location

```text
foundation/095_database_security.sql
```

## Status

KEEP

---

## Purpose

Database privilege separation.

---

# 017_database_identity_lifecycle.sql

## New Location

```text
foundation/015_identity_lifecycle.sql
```

## Status

KEEP

---

# 018_session_security_hardening.sql

## New Location

```text
foundation/065_session_security.sql
```

## Status

KEEP

---

# 019_security_boundary_hardening.sql

## New Location

```text
foundation/099_security_validation.sql
```

## Status

KEEP

---

# Bootstrap Mapping

# 999_security_bootstrap.sql

## New Location

```text
bootstrap/999_platform_bootstrap.sql
```

## Status

RENAME

---

## Purpose

Initialize:

* Database roles
* Extensions
* Base configuration
* Initial security controls

---

# New SQL Areas Required

The original migrations did not contain these because the original design was CAD-focused.

New modules required:

---

# Operational Resources

```text
100_resource_foundation.sql

110_people.sql

120_organizations.sql

130_units.sql

140_assignments.sql

150_qualifications.sql

160_availability.sql

170_assets.sql

180_vehicles.sql

190_resource_validation.sql
```

---

# RMS

```text
300_rms_core.sql

310_reports.sql

320_cases.sql

330_arrests.sql

340_citations.sql

350_records_retention.sql
```

---

# Evidence

```text
400_evidence_core.sql

410_items.sql

420_custody.sql

430_transfers.sql

440_retention.sql
```

---

# Final Migration Goal

The completed schema should represent:

```text
Platform Foundation

        ↓

Operational Resources

        ↓

Operational Modules

        ↓

External Consumers
```

The database should answer:

* Who owns this data?
* Who changed it?
* Why was it changed?
* What authority allowed it?
* What was the operational context?

The migration is not a rewrite of the original work.

It is the evolution of the original security-focused design into a complete Public Safety Platform.

