# Platform Architecture

## Purpose

This directory contains the architecture shared across the Public Safety Platform.

The architecture is divided into:

- Technology and provider decisions that apply across the repository.
- The domain-neutral Platform Foundation.
- Future domain, deployment, integration, and user-interface architecture.

## Current Documents

### Technology and Provider Decisions

- [PostgreSQL Architecture](postgresql.md)
- [External-System-Independent Observability](external-system-independent-observability.md)
- [Authorization Evaluation Contract](authorization-evaluation-contract.md)

### Platform Foundation

- [Platform Foundation Documentation](foundation/README.md)

## Relationship to SQL

The current Foundation database implementation is located under:

```text
sql/schema/manifests/foundation.manifest
sql/schema/migrations/foundation/
```

The self-contained SQL test framework is located under:

```text
sql/test-framework/
```

Architecture documents define requirements. Migrations implement database structures and selected controls. Tests demonstrate selected properties. None of these should be treated as a substitute for production deployment security, runtime enforcement, or operational verification.

## Dependency Direction

```text
Technology Decisions
        ↓
Platform Foundation
        ↓
Platform Services and Shared Resources
        ↓
CAD, RMS, Evidence, Personnel, Fleet, Fire, EMS
        ↓
Provider Adapters, Integrations, and User Interfaces
```

A lower layer may consume an upper layer. An upper layer must not acquire a dependency on a specific lower-layer module.
