# Platform Modules

> **Owner:** Iron Signal Systems
>
> **Status:** Module-family structure under active design
>
> **Implementation status:** No module in this directory is production-ready

## Purpose

This directory is the normative home for domain-specific module families.

The Platform Foundation remains domain-neutral. Module-owned records, workflows,
terminology, operational rules, and acceptance criteria belong here rather than
inside the Foundation.

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

A module may consume controlled Foundation capabilities.

The Platform Foundation must not depend on a module.

One module must not become a hidden prerequisite for another module unless an
explicit shared-resource or integration contract establishes that relationship.

## Module Documentation Contract

Each module should define:

1. Mission and scope.
2. Domain terminology.
3. Owned records and workflows.
4. Foundation and shared-resource dependencies.
5. Authorization and audit boundaries.
6. External-system contracts.
7. Accessibility and human-interaction requirements.
8. Degraded-operation and recovery behavior.
9. Testing and acceptance requirements.
10. Phased implementation and release boundaries.

## Executable Artifact Locations

The `modules/` tree governs module intent and architecture. Executable artifacts
remain in the repository's established implementation trees.

A module may eventually use paths such as:

```text
sql/schema/manifests/<module>.manifest
sql/schema/migrations/<module>/
test-framework/sql/tests/<module>/
go/services/<module>/
tools/validation/phase-gates/<module>/
```

Those paths must not be created merely to imply progress. They are created when
the governing architecture, migration-range decision, implementation contract,
and test plan are ready.

## Current Modules

- [Computer Aided Dispatch](CAD/README.md)
