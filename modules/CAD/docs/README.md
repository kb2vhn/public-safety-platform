# CAD Documentation

> **Owner:** Iron Signal Systems
>
> **Status:** Normative module documentation under active refinement

## Purpose

This directory governs the Computer Aided Dispatch module before production SQL,
service code, integrations, or user-interface implementation begin.

The documentation is organized to support the same disciplined progression used
by the Platform Foundation:

```text
Mission and boundary
        ↓
Normative architecture
        ↓
Domain invariants and controlled operations
        ↓
Implementation design
        ↓
Clean installation and structural validation
        ↓
Positive, negative, and concurrency behavior
        ↓
Resource observation and accessibility evaluation
        ↓
Phase-gated acceptance
        ↓
Deployment and operational readiness
```

## Start Here

- [Architecture Index](architecture/README.md)
- [Dispatcher Capability Catalog](requirements/dispatcher-capability-catalog.md)
- [Decision Records](decisions/README.md)
- [Acceptance Records](acceptance/README.md)

## Documentation Synchronization Rule

A CAD phase is not complete until the module README, architecture index,
requirements, decisions, implementation paths, manifests, tests, phase gate,
acceptance record, counts, terminology, and next-step statement describe the
same repository state.

Documentation may describe planned behavior, but it must label that behavior as
planned until the implementation and applicable tests are accepted.
