# Platform Architecture

## Purpose

This directory contains architecture that applies across the platform.

The repository began with public safety as its first operational focus. The
Platform Foundation is intentionally domain-neutral and is expected to support
unrelated module families such as public safety, municipal administration,
finance, permitting, public works, utilities, human resources, and education.

## Architecture Layers

```text
Technology Decisions
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
module.

## Current Documents

### Technology Decisions

- [PostgreSQL Architecture](postgresql.md)
- [External-System-Independent Observability](external-system-independent-observability.md)

### Platform Foundation

- [Platform Foundation Documentation](foundation/README.md)
- [Domain-Neutral Foundation Principle](foundation/domain-neutral-foundation-principle.md)
- [Foundation Terminology and Domain Neutrality](foundation/foundation-terminology-and-domain-neutrality.md)
- [Authorization Evaluation Contract](foundation/authorization-evaluation-contract.md)
- [Authentication Assertion Verification and Consumption Model](foundation/authentication-assertion-verification-and-consumption-model.md)
- [Phase 1 Authentication Assertion Acceptance](foundation/phase-1-authentication-assertion-acceptance.md)

## Relationship to SQL

The active Foundation migration order is maintained in:

```text
sql/schema/manifests/foundation.manifest
```

The active Foundation migrations are maintained in:

```text
sql/schema/migrations/foundation/
```

The self-contained SQL test framework is maintained in:

```text
sql/test-framework/
```

Architecture documents define requirements.

Migrations implement database structures and selected controls.

Tests demonstrate selected properties.

None of these replaces production deployment security, runtime enforcement,
operational verification, backup protection, trusted recovery, or off-host
integrity controls.
