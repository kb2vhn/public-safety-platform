
# Platform Documentation

> **Owner:** Iron Signal Systems
>
> **Current status:** Phase 4 Step 1 — approval-independence and
> separation-of-duties contract freeze
>
> **Status:** Pre-alpha; not ready for production use

## Start Here

- [Repository Overview](../README.md)
- [Architecture Index](architecture/README.md)
- [Platform Foundation Documentation](architecture/foundation/README.md)
- [Phase 4 Approval Independence and Separation of Duties](architecture/foundation/approval-independence-and-separation-of-duties-model.md)
- [Phase 3 Authorization Acceptance](architecture/foundation/phase-3-authorization-decision-and-controlled-lease-acceptance.md)
- [Project Goals](goals/README.md)
- [Compliance Profiles](compliance-profiles/README.md)
- [Validation Tools](../tools/validation/README.md)

## Accepted Boundaries

- Phase 1 Authentication Assertions:
  `phase-1-authentication-assertion-complete-v1`
- Phase 2 Session Control:
  `phase-2-session-control-complete-v1`
- Phase 3 Authorization Decision and Controlled Lease Issuance:
  `phase-3-authorization-control-complete-v1`

Phase 3 accepted result:

```text
33 manifest migrations
33 registered migrations
16 sequential test files
9 concurrency test files
408 PASS
0 FAIL
3 understood WARN
```

## Active Phase 4 Contract

Phase 4 Step 1 defines approval independence, self-approval prevention,
duplicate effective-actor handling, explicit reciprocal approval-cycle
checks, typed Authority Grant binding, incompatible-authority modes,
separation-of-duties duties, stage satisfaction, and Approval Request
finalization.

Step 1 changes no SQL, manifest, or SQL test file.

The terminology deliberately distinguishes Approval Action Records, supporting
records, assurance artifacts, and module-owned evidence records.

## Change Discipline

A material Foundation change normally updates the governing architecture, SQL
migration, authoritative manifests, positive and negative tests, concurrency
tests when applicable, phase gate, and documentation indexes. Passing tests do
not by themselves establish production readiness.
