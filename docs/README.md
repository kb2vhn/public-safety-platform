# Platform Documentation

## Purpose

The `docs/` tree defines the goals and architecture of the Public Safety Platform. It separates long-term project goals from the normative Platform Foundation, provider and technology decisions, and future compliance profiles.

The documentation describes both:

1. **Target architecture** — the requirements the finished platform must satisfy.
2. **Current implementation mapping** — the SQL migrations and supporting work that presently represent those requirements.

A documented requirement must not be described as fully implemented merely because a table, view, or migration exists.

## Current Directory Layout

```text
docs/
├── README.md
├── architecture/
│   ├── README.md
│   ├── postgresql.md
│   ├── provider-neutral-observability.md
│   └── foundation/
│       ├── README.md
│       └── *.md
├── compliance-profiles/
│   └── README.md
└── goals/
    ├── README.md
    ├── operational-simplicity-and-supportability-goals.md
    ├── performance-and-efficiency-goals.md
    └── two-person-concept.md
```

Directories for domain modules, formal architecture decisions, deployment profiles, and concrete compliance profiles will be added when those artifacts exist. They are not shown as current repository content until they are created.

## Documentation Layers

```text
Project Goals
      ↓
Architecture and Technology Decisions
      ↓
Platform Foundation
      ↓
Compliance Profiles
      ↓
Domain Platforms and Operational Modules
      ↓
Deployment Profiles and Provider Adapters
      ↓
User Interfaces and Integrations
```

Dependencies must point downward through this model. The Platform Foundation must not depend on a particular public-safety module, regulatory framework, deployment, or monitoring vendor.

## Status Language

The documentation uses the following meanings:

- **Normative** — a requirement of the target architecture.
- **Structurally implemented** — represented in schema objects or migration logic.
- **Database-enforced** — actively protected by constraints, privileges, row policies, controlled functions, or other PostgreSQL controls.
- **Runtime-enforced** — actively enforced by the production service implementation.
- **Operationally enforced** — supported by deployment controls, monitoring, backup, recovery, and administrative procedure.
- **Validated** — demonstrated by automated tests or documented operational exercises.

No single status implies all other statuses.

## Source-of-Truth Boundaries

The architecture documents define intent and invariants. The SQL manifest defines migration order. The SQL migrations define the current database implementation. The test framework demonstrates selected database properties. Deployment and runtime documentation will define controls outside PostgreSQL when those layers are implemented.

Current SQL locations:

```text
sql/schema/manifests/foundation.manifest
sql/schema/migrations/foundation/
sql/schema/scripts/
sql/test-framework/
```

## Governing Principle

> Security, performance, compliance, maintainability, accessibility, observability, operational simplicity, supportability, resilience, and affordability must be designed into the platform from the beginning and preserved throughout its lifetime.
