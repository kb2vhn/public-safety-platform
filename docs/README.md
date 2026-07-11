# Platform Documentation

> **Development status:** Pre-alpha, domain-neutral Platform Foundation.
>
> **Current implementation phase:** Phase 2 — Session Establishment, Step-Up,
> and Lifecycle Enforcement.
>
> This repository is not ready for production use.

## Purpose

This directory contains the project goals, architecture, compliance profiles,
and implementation-support documentation for the Platform.

Public safety is the first demanding module family, but the shared Platform
Foundation is intentionally domain-neutral and must remain usable by municipal,
school, institutional, and future operational modules that have unrelated
business records and workflows.

## Start Here

- [Repository Overview](../README.md)
- [Architecture Index](architecture/README.md)
- [Platform Foundation Documentation](architecture/foundation/README.md)
- [Project Goals](goals/README.md)
- [Compliance Profiles](compliance-profiles/README.md)

## Current Accepted Boundary

Phase 1 — Authentication Assertion Verification and Consumption — is accepted
at tag:

```text
phase-1-authentication-assertion-complete-v1
```

Accepted evidence:

```text
31 manifest migrations
31 registered migrations
10 sequential test files
1 concurrency test file
135 PASS
0 FAIL
3 understood WARN
```

See:

- [Authentication Assertion Verification and Consumption Model](architecture/foundation/authentication-assertion-verification-and-consumption-model.md)
- [Phase 1 Authentication Assertion Acceptance](architecture/foundation/phase-1-authentication-assertion-acceptance.md)

## Current Phase

Phase 2 begins from the accepted Phase 1 boundary and is governed by:

- [Session Establishment, Step-Up, and Lifecycle Model](architecture/foundation/session-establishment-step-up-and-lifecycle-model.md)

Phase 2 covers database-enforced session establishment, step-up completion,
activity checkpoints, lifecycle transitions, event consistency, and required
multi-connection concurrency proofs.

Phase 2 does not include production bearer-token design, production Go
services, full authorization evaluation, Authorization Lease issuance,
protected-operation execution, or production deployment security.

## Documentation Areas

### Architecture

The architecture directory defines cross-platform decisions, the domain-neutral
Foundation, provider boundaries, and the dependency direction that later
modules must follow.

- [Architecture Index](architecture/README.md)
- [PostgreSQL Architecture](architecture/postgresql.md)
- [External-System-Independent Observability](architecture/external-system-independent-observability.md)
- [Platform Foundation Documentation](architecture/foundation/README.md)

### Goals

Project goals describe the intended operational outcomes. Architecture
contracts translate those outcomes into explicit technical requirements.

- [Project Goals](goals/README.md)

### Compliance Profiles

Compliance profiles map external obligations to reusable Platform controls.
A profile name or product feature is not proof of compliance.

- [Compliance Profiles](compliance-profiles/README.md)

## Relationship to Implementation

The active Foundation SQL is maintained under:

```text
sql/schema/
```

The self-contained SQL test framework is maintained under:

```text
sql/test-framework/
```

Architecture documents define requirements. Migrations implement selected
database structures and controls. Tests demonstrate selected properties.
Passing tests do not prove production readiness, host security, protected
backup and restore, break-glass behavior, off-host integrity, trusted recovery,
or complete runtime authorization.

## Change Discipline

A material Foundation change should normally update:

1. The governing architecture contract,
2. The applicable migration or a new migration,
3. The authoritative manifest when migration order changes,
4. The SQL migration map,
5. Positive and negative behavior tests,
6. Concurrency tests when state can be consumed or changed simultaneously,
7. Operational documentation when the change crosses the database boundary,
8. The applicable phase acceptance record after a clean passing run.
