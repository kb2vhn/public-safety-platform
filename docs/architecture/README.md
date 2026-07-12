# Platform Architecture

> **Owner:** Iron Signal Systems
>
> **Status:** Normative architecture under active refinement
>
> **Current implementation phase:** Phase 3 — Authorization Decision and
> Controlled Lease Issuance

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

The Foundation must not depend on one operational module, deployment product,
monitoring vendor, identity provider, or compliance framework.

## Current Architecture

- [Platform Foundation Documentation](foundation/README.md)
- [Authorization Evaluation Contract](foundation/authorization-evaluation-contract.md)
- [Authorization Decision and Lease Issuance Model](foundation/authorization-decision-and-lease-issuance-model.md)
- [Session Establishment, Step-Up, and Lifecycle Model](foundation/session-establishment-step-up-and-lifecycle-model.md)
- [PostgreSQL Architecture](postgresql.md)
- [External-System-Independent Observability](external-system-independent-observability.md)
- [User-Interface Architecture](user-interface/README.md)

## Implementation Status

Phase 1 and Phase 2 are accepted. Phase 3 Step 3 validated deterministic policy
selection and controlled Decision Record finalization. Step 4 implements
controlled lease issuance and use. Validation gates are maintained under:

```text
tools/validation/phase-gates/
```

Architecture documents define requirements. Migrations implement selected
database controls. Tests demonstrate selected properties. None replaces
production deployment security or operational verification.
