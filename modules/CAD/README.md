# Computer Aided Dispatch Module

> **Module name:** Computer Aided Dispatch
>
> **Module identifier:** `CAD`
>
> **Owner:** Iron Signal Systems
>
> **Status:** Normative design architecture under active refinement
>
> **Implementation status:** No production SQL, Go service, dispatcher interface,
> operational workstation profile, or deployment is accepted by this directory
>
> **Production status:** Not ready for production use

## Mission

Provide a trusted operational system that helps emergency communications
personnel understand what is happening, where it is happening, which resources
are available, what has been assigned, and what requires attention.

The CAD module must complement the dispatcher's training, judgment, and role. It
must not force the dispatcher to fight the software, reconstruct state from
unrelated screens, or trust unexplained automation.

## Relationship to the Iron Signal Platform

CAD is the first planned operational module, but CAD does not define the
Platform Foundation.

CAD may consume controlled Foundation capabilities for identity, sessions,
Authorization Decisions, Approval Requests, Approval Action Records, Decision Records, classification, assurance,
resilience, telemetry, and integration delivery.

CAD owns its domain-specific incidents, calls, dispatch assignments, unit
status, resource recommendations, operational timelines, alerts, timers,
premise information, response plans, human-facing CAD interfaces, and the CAD
Operational Workstation profile.

The Foundation must not contain CAD-specific records or acquire a dependency on
this module.

## Architecture Layers

The CAD architecture is intentionally separated into three owned layers:

1. **CAD domain and application architecture** — canonical incidents, units,
   assignments, alerts, authorization context, history, and service behavior.
2. **CAD user-interface architecture** — role-centered interaction,
   accessibility, information presentation, keyboard behavior, and human-facing
   workflow requirements.
3. **CAD Operational Workstation architecture** — the managed Linux appliance,
   local native services, workstation components, IPC, caching, release,
   management, security, and recovery behavior.

The governing boundary and precedence rules are defined in the
[CAD Architecture Boundary and Precedence Model](docs/architecture/cad-architecture-boundary-and-precedence-model.md).

## Current Boundary

This directory establishes architecture and acceptance expectations only.

It does not:

- Allocate a CAD migration range.
- Add a CAD manifest.
- Add mutable or production database objects.
- Create production Go services.
- Create a production dispatcher interface.
- Accept a production Operational Workstation profile.
- Claim CAD accessibility conformance.
- Claim operational, legal, security, or production acceptance.
- Change accepted Foundation migration or test counts.

CAD implementation remains gated by controlling Foundation contracts and a
future approved module-range decision.

## Design Principles

1. Every important operational decision must be explainable.
2. Authentication is not authorization.
3. Trust is additive and exact-context bound.
4. PostgreSQL remains an independent security boundary.
5. No ordinary identity or accumulated role set receives unrestricted authority.
6. Material operational history must not be silently rewritten.
7. A recommendation is not an authorization or committed dispatch action.
8. Acknowledging an alert does not mean the underlying condition is resolved.
9. Stale, estimated, unconfirmed, failed, queued, conflicted, and committed
   state must be visibly and programmatically distinguishable.
10. External systems remain replaceable.
11. Correctness and resource observations remain separate.
12. Accessibility is functional correctness and operational resilience.
13. Critical meaning must not depend on color, sound, position, animation, or
    one input method alone.
14. Degraded operation must remain explicit, accountable, and recoverable.
15. The interface should expose the right information at the right time without
    placing the database schema in front of the dispatcher.
16. A workstation component is not a Platform module and receives no authority
    merely because it is installed or locally reachable.

## Documentation

- [CAD Documentation Index](docs/README.md)
- [CAD Architecture Index](docs/architecture/README.md)
- [CAD User-Interface Architecture](docs/architecture/user-interface/README.md)
- [CAD Operational Workstation Architecture](docs/architecture/operational-workstation/README.md)
- [CAD Requirements Index](docs/requirements/README.md)
- [Dispatcher Capability Catalog](docs/requirements/dispatcher-capability-catalog.md)
- [CAD Requirements and Evidence Traceability Model](docs/requirements/cad-requirements-traceability-model.md)
- [CAD Testing and Acceptance Model](docs/architecture/cad-testing-and-acceptance-model.md)
- [CAD Testing Identifiers and Authoritative Registries Model](docs/architecture/cad-testing-identifiers-and-authoritative-registries-model.md)
- [CAD Test Campaign Accounting Model](docs/architecture/cad-test-campaign-accounting-model.md)
- [CAD Test-Oracle and Side-Effect Verification Model](docs/architecture/cad-test-oracle-and-side-effect-verification-model.md)
- [CAD Test Execution Tiers and Gate Cadence](docs/architecture/cad-test-execution-tiers-and-gate-cadence.md)
- [CAD Test Evidence Retention and Integrity Model](docs/architecture/cad-test-evidence-retention-and-integrity-model.md)
- [CAD Acceptance Record Model](docs/architecture/cad-acceptance-record-model.md)
- [CAD Operational Readiness and Production Acceptance Model](docs/architecture/cad-operational-readiness-and-production-acceptance-model.md)
- [CAD Standards-Conformance and Interoperability Model](docs/architecture/cad-standards-conformance-and-interoperability-model.md)
- [CAD Decisions](docs/decisions/README.md)
- [CAD Acceptance Records](docs/acceptance/README.md)

## Planned Production Executable Boundaries

Production executable paths remain intentionally absent until authorized:

```text
sql/schema/manifests/cad.manifest
sql/schema/migrations/cad/
test-framework/sql/tests/cad/
test-framework/sql/tests/cad-tests.manifest
test-framework/sql/tests/cad-concurrency-tests.manifest
go/services/cad/
```

Exact production paths and the migration range require a documented decision before use.

## Current Static Gate

The design-only CAD Phase 0 repository and registry gate is:

```text
tools/validation/phase-gates/cad/validate_phase0.sh
```

A passing result proves documentation and assurance-metadata consistency only.
It does not prove executable CAD behavior or production readiness.

## Current Assurance Metadata

The following machine-readable files establish stable design identities and
traceability scaffolding:

```text
modules/CAD/requirements/cad-requirements.yaml
modules/CAD/testing/cad-controlled-operations.yaml
modules/CAD/testing/cad-enforcement-points.yaml
modules/CAD/testing/cad-hostile-classes.yaml
modules/CAD/testing/test-oracles.yaml
```

They do not create SQL, Go services, workstation authority, deployment, or
production acceptance. Seeded objects remain proposed, design-only, not
implemented, and not tested.
