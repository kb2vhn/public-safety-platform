# Platform Documentation

> **Owner:** Iron Signal Systems
>
> **Current status:** Phase 3 accepted; next Foundation contract not
> yet frozen
>
> **Status:** Pre-alpha; not ready for production use

## Start Here

- [Repository Overview](../README.md)
- [Architecture Index](architecture/README.md)
- [Platform Foundation Documentation](architecture/foundation/README.md)
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

Phase 3 accepted evidence:

```text
33 manifest migrations
33 registered migrations
16 sequential test files
9 concurrency test files
408 PASS
0 FAIL
3 understood WARN
```

## Next Foundation Contract

The next phase must define its normative boundary before production
SQL changes. Leading remaining work includes approval independence,
self-approval prevention, separation of duties, incompatible authority,
stronger historical integrity, migration-checksum enforcement, and
production role topology.

## Change Discipline

A material Foundation change normally updates the governing
architecture, SQL migration, authoritative manifests, positive and
negative tests, concurrency tests when applicable, phase gate, and
documentation indexes. Passing tests do not by themselves establish
production readiness.
