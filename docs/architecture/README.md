# Platform Architecture

> **Status:** Normative architecture under active refinement.
>
> **Current implementation phase:** Phase 2 — Session Establishment, Step-Up,
> and Lifecycle Enforcement.
>
> The repository is pre-alpha and is not ready for production use.

## Purpose

This directory contains architecture shared across the platform.

The repository began with public safety as its first demanding operational
focus. The Platform Foundation is intentionally domain-neutral and must remain
usable by unrelated municipal, school, and institutional module families.

Architecture is separated into:

- Cross-platform technology and provider decisions,
- The domain-neutral Platform Foundation,
- Future Shared Resources and module-family architecture,
- Deployment, integration, provider-adapter, and user-interface architecture.

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

A lower layer may consume an upper layer.

An upper layer must not acquire a dependency on one specific lower-layer
module, deployment product, monitoring product, external provider, or
compliance framework.

## Current Documents

### Cross-Platform Decisions

- [PostgreSQL Architecture](postgresql.md)
- [External-System-Independent Observability](external-system-independent-observability.md)

### Platform Foundation

- [Platform Foundation Documentation](foundation/README.md)
- [Domain-Neutral Foundation Principle](foundation/domain-neutral-foundation-principle.md)
- [Foundation Terminology and Domain Neutrality](foundation/foundation-terminology-and-domain-neutrality.md)
- [Authorization Evaluation Contract](foundation/authorization-evaluation-contract.md)
- [Authentication Assertion Verification and Consumption Model](foundation/authentication-assertion-verification-and-consumption-model.md)
- [Phase 1 Authentication Assertion Acceptance](foundation/phase-1-authentication-assertion-acceptance.md)
- [Session Establishment, Step-Up, and Lifecycle Model](foundation/session-establishment-step-up-and-lifecycle-model.md)

## Current Accepted Boundary

Phase 1 is accepted at tag:

```text
phase-1-authentication-assertion-complete-v1
```

The accepted Phase 1 test evidence is:

```text
31 manifest migrations
31 registered migrations
10 sequential test files
1 concurrency test file
135 PASS
0 FAIL
3 understood WARN
```

Phase 2 begins from that exact boundary. Phase 2 must not weaken the accepted
Authentication Assertion verification, exact-context, terminal-state, or
single-use guarantees.

## Relationship to SQL

The authoritative Foundation migration order is maintained in:

```text
sql/schema/manifests/foundation.manifest
```

The active Foundation migrations are maintained in:

```text
sql/schema/migrations/foundation/
```

The self-contained SQL test framework is maintained in:

```text
test-framework/
```

Architecture documents define requirements. Migrations implement database
structures and selected controls. Tests demonstrate selected properties.

None of these replaces production deployment security, runtime enforcement,
operational verification, protected backup and restore, trusted recovery,
break-glass controls, or off-host integrity anchoring.

## Status Language

- **Normative** — required by the target architecture.
- **Structurally implemented** — represented by database objects or migration
  logic.
- **Database-enforced** — actively protected by constraints, privileges,
  controlled functions, locks, or other PostgreSQL controls.
- **Runtime-enforced** — actively enforced by the production service.
- **Operationally enforced** — supported by deployment, monitoring, backup,
  recovery, and administrative procedure.
- **Validated** — demonstrated by automated tests or documented operational
  exercises.

No one status implies all other statuses.
