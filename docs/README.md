# Platform Documentation

> **Owner:** Iron Signal Systems
>
> **Current implementation phase:** Phase 3 — Authorization Decision and
> Controlled Lease Issuance
>
> **Status:** Pre-alpha; not ready for production use

## Start Here

- [Repository Overview](../README.md)
- [Architecture Index](architecture/README.md)
- [Platform Foundation Documentation](architecture/foundation/README.md)
- [Project Goals](goals/README.md)
- [Compliance Profiles](compliance-profiles/README.md)
- [Validation Tools](../tools/validation/README.md)

## Accepted Boundaries

Phase 1 Authentication Assertions are accepted at
`phase-1-authentication-assertion-complete-v1`.

Phase 2 session control is accepted at
`phase-2-session-control-complete-v1` with 213 PASS, 0 FAIL, and 3 understood
warnings.

Phase 3 Step 3 is validated with 33 migrations, 14 sequential tests,
4 concurrency tests, 297 PASS, 0 FAIL, and 3 understood warnings.

Phase 3 Step 4 adds controlled Authorization Lease issuance, exact-context
usability, atomic consumption, materialized expiration, and revocation.

## Change Discipline

A material Foundation change normally updates the governing architecture, SQL
migration, authoritative manifests, positive and negative tests, concurrency
tests when applicable, phase gate, and documentation indexes. Passing tests do
not by themselves establish production readiness.
