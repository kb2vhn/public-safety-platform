# Platform Architecture

> **Owner:** Iron Signal Systems
>
> **Status:** Normative architecture under active refinement
>
> **Current status:** Phase 3 accepted; next Foundation contract not
> yet frozen

## Dependency Direction

```text
Project Goals and Technology Decisions
        ↓
Domain-Neutral Platform Foundation
        ↓
Platform Services and Shared Resources
        ↓
Module Families
        ↓
External-System Adapters, Integrations, and User Interfaces
```

The Foundation must not depend on one operational module, deployment
product, monitoring vendor, identity provider, or compliance framework.

## Current Architecture

- [Platform Foundation Documentation](foundation/README.md)
- [Phase 3 Authorization Acceptance](foundation/phase-3-authorization-decision-and-controlled-lease-acceptance.md)
- [Authorization Evaluation Contract](foundation/authorization-evaluation-contract.md)
- [Authorization Decision and Lease Issuance Model](foundation/authorization-decision-and-lease-issuance-model.md)
- [Session Establishment, Step-Up, and Lifecycle Model](foundation/session-establishment-step-up-and-lifecycle-model.md)
- [PostgreSQL Architecture](postgresql.md)
- [External-System-Independent Observability](external-system-independent-observability.md)
- [User-Interface Architecture](user-interface/README.md)

## Accepted Implementation Status

Phase 1, Phase 2, and Phase 3 are accepted.

Phase 3 established deterministic policy selection, controlled Decision
Record finalization, controlled lease issuance and use, expanded
fail-closed revalidation, and independent-connection concurrency proofs.

```text
33 migrations
16 sequential tests
9 concurrency tests
408 PASS
0 FAIL
3 understood WARN
```

Accepted tag:

```text
phase-3-authorization-control-complete-v1
```

Validation gates are maintained under:

```text
tools/validation/phase-gates/
```

Architecture documents define requirements. Migrations implement
selected database controls. Tests demonstrate selected properties. None
replaces production deployment security or operational verification.
