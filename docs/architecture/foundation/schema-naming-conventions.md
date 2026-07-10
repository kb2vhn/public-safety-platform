# Platform Schema and Naming Conventions

## Purpose

This document defines naming conventions for reusable Foundation schemas and domain schemas.

## General Rules

- Use `snake_case`.
- Use plural table names.
- Use stable UUID primary keys unless otherwise justified.
- Name primary keys `<entity>_id`.
- Use `timestamptz`.
- Use explicit effective periods.
- Use controlled vocabularies for lifecycle states.
- Avoid vendor-specific names in canonical tables.

## Domain Neutrality

Prefer:

```text
services
organizations
attestation_authorities
access_eligibility_grants
authority_grants
decision_records
classification_assignments
```

Avoid Foundation names tied to CAD, RMS, finance, or any vendor.

## Security-Sensitive State

Do not reduce complex state to unexplained Booleans such as:

```text
is_authorized
is_approved
is_trusted
is_eligible
```

when attribution, scope, time, reason, approval, and revocation history are required.

## Versioned Records

Versioned records should generally include:

```text
version_id
version_number
effective_from
effective_until
recorded_at
recorded_by_identity_id
supersedes_version_id
decision_id
```

## Functions

Use verb-first names:

```text
verify_trust_assertion
create_authorization_lease
record_decision
grant_access_eligibility
revoke_authority_grant
```

## Architectural Invariants

1. Names communicate ownership.
2. Foundation names remain domain-neutral.
3. Historical and lifecycle concepts are explicit.
4. Vendor-specific names do not enter canonical schemas.
5. Security-sensitive state is not reduced to unexplained Booleans.
