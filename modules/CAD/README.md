# Computer Aided Dispatch Module

> **Module name:** Computer Aided Dispatch
>
> **Module identifier:** `CAD`
>
> **Owner:** Iron Signal Systems
>
> **Status:** Normative design scaffold under active refinement
>
> **Implementation status:** No production SQL, Go service, user interface, or
> deployment is established by this directory
>
> **Production status:** Not ready for production use

## Mission

Provide a trusted operational system that helps emergency communications
personnel understand what is happening, where it is happening, which resources
are available, what has been assigned, and what requires attention.

The CAD module must complement the dispatcher's training, judgment, and role. It
must not force the dispatcher to fight the software, reconstruct state from
unrelated screens, or trust unexplained automation.

## Relationship to the Platform Foundation

CAD is the first planned operational module, but CAD does not define the
Platform Foundation.

CAD may consume controlled Foundation capabilities for:

- Identity and identity lifecycle.
- Authentication Assertions.
- Sessions and step-up.
- Authorization Policies and Authorization Leases.
- Governed Purposes and Governed Operations.
- Protected Resource Targets and Governed Scopes.
- Independent approvals and separation of duties.
- Decision Records and Decision Supporting Records.
- Data Classification and information governance.
- Operational telemetry and health.
- Transactional integration outbox behavior.
- Assurance Artifacts, assessments, findings, remediation, exceptions, and risk.
- Resilience, continuity, workload, and resource governance.

CAD owns its domain-specific incidents, calls, dispatch assignments, unit
status, resource recommendations, operational timelines, alerts, timers,
premise information, response plans, and related workflows.

The Foundation must not contain CAD-specific records or acquire a dependency on
this module.

## Current Boundary

This scaffold establishes module architecture and acceptance expectations only.

It does not:

- Allocate a CAD migration range.
- Add a CAD manifest.
- Add mutable or production database objects.
- Create production Go services.
- Create a dispatcher workstation implementation.
- Claim CAD accessibility conformance.
- Claim operational, legal, security, or production acceptance.
- Change accepted Foundation migration or test counts.

CAD implementation remains gated by the controlling Foundation contracts and by
a future approved module-range decision.

## Design Principles

1. Every important operational decision must be explainable.
2. Authentication is not authorization.
3. Trust is additive and exact-context bound.
4. PostgreSQL remains an independent security boundary.
5. No ordinary identity or accumulated role set receives unrestricted authority.
6. Material operational history must not be silently rewritten.
7. A recommendation is not an authorization or committed dispatch action.
8. Acknowledging an alert does not mean the underlying condition is resolved.
9. Stale, estimated, unconfirmed, failed, queued, and committed state must be
   visibly and programmatically distinguishable.
10. External systems remain replaceable.
11. Correctness and resource observations remain separate.
12. Accessibility is functional correctness and operational resilience.
13. Critical meaning must not depend on color, sound, position, animation, or
    one input method alone.
14. Degraded operation must remain explicit, accountable, and recoverable.
15. The interface should expose the right information at the right time without
    placing the database schema in front of the dispatcher.

## Documentation

- [CAD Documentation Index](docs/README.md)
- [CAD Architecture Index](docs/architecture/README.md)
- [Dispatcher Capability Catalog](docs/requirements/dispatcher-capability-catalog.md)
- [CAD Decisions](docs/decisions/README.md)
- [CAD Acceptance Records](docs/acceptance/README.md)

## Planned Executable Boundaries

Executable paths are intentionally not created by this scaffold.

When implementation is authorized, the expected repository alignment is:

```text
sql/schema/manifests/cad.manifest
sql/schema/migrations/cad/
test-framework/sql/tests/cad/
test-framework/sql/tests/cad-tests.manifest
test-framework/sql/tests/cad-concurrency-tests.manifest
go/services/cad/
tools/validation/phase-gates/cad/
```

Exact paths and the migration range require a documented decision before use.

## Initial Operational Scope

The initial CAD scope is expected to include:

- Incident intake handoff and incident creation.
- Active incident queue.
- Selected incident workspace.
- Unit and resource board.
- Explainable response recommendations.
- Assignment and status management.
- Append-oriented operational history.
- Location, mapping, premise, and hazard context.
- Alerts, timers, acknowledgment, resolution, and escalation.
- Dispatcher and supervisor actions.
- Communications and external-system references.
- Degraded-operation visibility and reconciliation.
- Role-based access and exact-context authorization.
- Keyboard-first and accessible operation.
- Correctness, concurrency, accessibility, and resource testing.

Advanced emergency-management, clinical, records-management, evidence,
personnel, and fleet workflows remain separate module concerns unless an
explicit contract establishes an integration boundary.
