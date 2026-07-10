# Platform Governed Document and Policy Versioning Model

## Purpose

This document defines versioning, approval, effective dating, integrity, and historical preservation for policies, agreements, standards, procedures, regulations, and executable rules.

## Core Principle

A policy name alone is not sufficient.

Every decision must reference the exact version in force at the time.

## Required Identity

Every governed document has:

- Stable document identifier
- Title
- Version
- Revision number where applicable
- Approval date
- Effective-from date
- Effective-until date or explicit open-ended status
- State
- Approving authority
- Supersession relationship
- Integrity hash
- Storage reference
- Decision Record

## Lifecycle States

```text
DRAFT
UNDER_REVIEW
APPROVED
SCHEDULED
ACTIVE
SUSPENDED
SUPERSEDED
EXPIRED
RETIRED
WITHDRAWN
```

## Rule-Level References

Evaluations should reference the specific:

- Section
- Clause
- Control
- Rule identifier
- Requirement

used in the decision.

## Future-Effective Versions

A version approved today but effective later must not be enforced early.

## Historical Resolution

Historical decisions use the version effective at the original evaluation timestamp.

Current policy must not retroactively redefine a past decision.

## External Documents

External laws, regulations, contracts, and standards should preserve:

- External authority
- Publication or revision date
- Edition
- Internal adoption record
- Retrieved date
- Document hash
- Source reference
- Internal interpretation policy

A live URL alone is insufficient.

## Machine-Readable Rules

Executable policy definitions must be linked to the human-governed document through:

- Stable identifiers
- Matching version
- Effective dates
- Hashes
- Approval records

## Architectural Invariants

1. Every governed document has stable identity.
2. Every material revision creates an immutable version.
3. Every version has approval and effective dates.
4. Decision Records reference exact versions.
5. Historical decisions use historical rules.
6. Missing required versions fail safely.
7. PostgreSQL verifies version, scope, approval, effective period, and integrity.
