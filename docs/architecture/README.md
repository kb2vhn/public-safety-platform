# Platform Architecture

> **Owner:** Iron Signal Systems
>
> **Status:** Normative architecture under active refinement
>
> **Current status:** Phase 4 approval independence and separation of duties
> formally accepted at `phase-4-approval-independence-and-separation-of-duties-complete-v1`

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

### Platform Foundation

- [Platform Foundation Documentation](foundation/README.md)
- [Approval Independence and Separation of Duties](foundation/approval-independence-and-separation-of-duties-model.md)
- [Resource Telemetry and Performance-Regression Testing](foundation/resource-telemetry-and-performance-regression-testing-model.md)
- [Foundation Migration Timeout and Execution Performance Standard](foundation/foundation-migration-timeout-and-execution-performance-standard.md)
- [Performance, Efficiency, and Resource Governance](foundation/performance-efficiency-and-resource-governance-model.md)
- [Observability, Health, and Operational Telemetry](foundation/observability-health-and-operational-telemetry-model.md)
- [Approval Framework](foundation/approval-framework.md)
- [Authority and Authorization](foundation/authority-and-authorization-model.md)
- [Authorization Evaluation Contract](foundation/authorization-evaluation-contract.md)
- [Phase 3 Authorization Acceptance](foundation/phase-3-authorization-decision-and-controlled-lease-acceptance.md)
- [Phase 4 Approval Independence and Separation of Duties Acceptance](foundation/phase-4-approval-independence-and-separation-of-duties-acceptance.md)

### Platform Assurance and Release Governance

- [Verification, Validation, and Acceptance Governance](verification-validation-and-acceptance-governance-model.md)
- [Software Supply-Chain and Release Integrity](software-supply-chain-and-release-integrity-model.md)
- [Host Software, Configuration, and Runtime Integrity](host-software-configuration-and-runtime-integrity-model.md)

### Platform Services and Client Architecture

- [Backend Services](backend-services/README.md)
- [Location Service Architecture](backend-services/location-service-architecture.md)
- [Communications](communications/README.md)
- [Resource Subscription and Live Update Model](communications/resource-subscription-and-live-update-model.md)
- [GIS and Mapping](gis-and-mapping/README.md)
- [Map Rendering and Data Delivery Architecture](gis-and-mapping/map-rendering-and-data-delivery-architecture.md)
- [Operational Workstation](../../modules/CAD/docs/architecture/operational-workstation/README.md)
- [Operational Workstation Architecture](../../modules/CAD/docs/architecture/operational-workstation/operational-workstation-architecture.md)
- [User-Interface Architecture](../../modules/CAD/docs/architecture/user-interface/README.md)
- [Accessibility and Inclusive Interaction](../../modules/CAD/docs/architecture/user-interface/accessibility-and-inclusive-interaction-model.md)

## Accepted Implementation Status

Phases 1, 2, 3, and 4 are formally accepted. The accepted Phase 4 boundary is
identified by:

```text
phase-4-approval-independence-and-separation-of-duties-complete-v1
```

Accepted result:

```text
34 manifest migrations
34 registered migrations
21 sequential test files
16 concurrency test files
734 PASS
0 FAIL
3 understood WARN
Correctness result: PASS
Resource observation: RECORDED
Performance thresholds: NOT_EVALUATED
159 phase-gate PASS checks
0 phase-gate FAIL checks
```

## Accepted Architecture Boundary

Phase 4 closes the domain-neutral approval-independence and
separation-of-duties database boundary: controlled action recording,
independence enforcement, delegated-grant lineage, incompatible-authority and
prohibited-duty enforcement, stage satisfaction, finalization, later-use
approval continuity, and independent-connection concurrency proofs.

Backend services may consume Foundation decisions; communications may deliver
governed state; GIS clients may render published facts; operational
workstations may present module capabilities; and user interfaces may support
authorized work. None of those downstream areas becomes an independent source
of identity, authority, approval, commitment, or canonical truth.

## Migration Execution Boundary

The current clean-install Foundation migration contract is `5s` lock wait,
`1min` statement execution, and `1min` idle-in-transaction, all established
with `SET LOCAL`. A statement observed above ten seconds requires investigation
even while broader performance budgets remain observation-only. The active
phase gate executes the static migration-timeout validator before database
execution.

## Phase 4 Formal Acceptance

The formal acceptance record is:

- [Phase 4 Approval Independence and Separation of Duties Acceptance](foundation/phase-4-approval-independence-and-separation-of-duties-acceptance.md)

Revalidate the accepted tag, implementation tree, documentation, correctness,
and resource-observation contract with:

```bash
./tools/validation/phase-gates/validate_phase4_step8.sh
```

The accepted Phase 4 boundary does not make downstream service, mapping,
workstation, presentation, transport, or module-owned state part of the
Platform Foundation.

## Active Phase 5 — Production Database Security Boundary

Phase 5 Step 1 freezes database ownership, role topology, migration authority,
least-privileged runtime access, investigation, audit, validation,
default-privilege, and break-glass boundaries.

This step does not move CAD, GIS, communications, workstation, interface, or
other module state into the Platform Foundation.

See:

- [Production Database Role, Ownership, and Runtime Privilege Model](foundation/production-database-role-ownership-and-runtime-privilege-model.md)

## Active Phase 5 Step 2

The deployment layer now has a separate `sql/deployment` tree, canonical role
shells, bounded service-to-capability memberships, and disposable-cluster
validation. Ownership transfer and object privileges remain deferred.

See:

- [Phase 5 Step 2 — Deployment Manifest and PostgreSQL Role Topology](foundation/phase-5-step-2-deployment-role-topology.md)

## Active Phase 5 Step 3

Phase 5 Step 3 implements production database, protected schema, relation,
routine, and standalone-type ownership plus creator-specific default
privileges.

The work remains in the deployment layer and does not move CAD or other
module-owned state into the Platform Foundation.

See:

- [Phase 5 Step 3 — Ownership and Creator-Specific Default Privileges](foundation/phase-5-step-3-ownership-and-default-privileges.md)

## Active Phase 5 Step 4

The active deployment-security work grants bounded database connection and
controlled API execution without allowing workstation, interface, module, or
service code to create database authority independently.

See:

- [Phase 5 Step 4 — Least-Privileged Runtime Grants and Controlled Service APIs](foundation/phase-5-step-4-least-privileged-runtime-grants.md)

<!-- ISSP_PHASE5_STEP5_REVIEW_AND_VALIDATION_ROLES -->

## Phase 5 Step 5 — Review and Validation Roles

Phase 5 Step 5 implements separate `NOLOGIN` investigator, audit-reader, and validation-reader capabilities through an exact 40-row view-only privilege contract. The implementation adds two reduced-disclosure investigator views, eight audit-lineage views, and 23 validation-posture views. No review role receives direct protected base-table, sequence, mutation, routine-execution, schema-creation, or temporary-object authority. Phase 5 Step 6 may implement disabled-at-rest break-glass activation and credential lifecycle controls.

## Phase 5 Step 6 Implementation Status

Phase 5 Step 6 implements disabled-at-rest `issp_break_glass` activation,
independent approval evidence, bounded expiration, forced deactivation,
append-only emergency evidence, off-host-export requirements, and external
credential lifecycle policy through deployment migration
`940_break_glass_and_credential_lifecycle.sql`. Credentials, private keys,
tokens, and passwords remain outside the repository and database. Phase 5 Step
7 may perform hostile-condition and role-race validation.

## Phase 5 Step 7 — Hostile-Condition and Role-Race Validation

Phase 5 Step 7 adds hostile-input and PostgreSQL role-race validation plus one pre-freeze hardening correction to deployment migration `940_break_glass_and_credential_lifecycle.sql`: an activated SCRAM verifier must use at least 4096 iterations and cryptographically match the independently approved fingerprint. It introduces no new deployment migration or authority. Concurrent preparation, activation, live-session deactivation, use-versus-closure, and expiration-versus-deactivation must remain deterministic, attributable, and fail-closed before Phase 5 formal acceptance.

## Accepted Phase 5 Architecture Boundary

Phase 5 formally accepts and freezes the PostgreSQL production role, ownership, runtime privilege, review-surface, break-glass, credential-lifecycle, and hostile-condition concurrency boundary at `phase-5-production-database-security-boundary-complete-v1`.

Downstream services and modules consume this accepted Foundation boundary. They do not independently redefine database ownership, grant protected authority, bypass controlled routines, or create standing emergency access.

<!-- PHASE6_STEP1_STATUS -->

## Phase 6 Step 1 — Production Go Service Boundary

The production backend now has a contract-only checkpoint defining three
bounded initial Go processes, their exact Phase 5 PostgreSQL service identities,
controlled database API use, and runtime, observability, shutdown, build, and
testing boundaries.

- [Production Go Service Boundary and Runtime Model](backend-services/production-go-service-boundary-and-runtime-model.md)
- [Phase 6 Step 1 Contract Freeze](backend-services/phase-6-step-1-production-go-service-contract.md)

<!-- phase-6-step-2-status:start -->
## Phase 6 Step 2 — Production Go Workspace and Reproducible Build Baseline

The production module now exists at `go/platform/` with three fail-closed
bounded executable skeletons, the exact `go1.26.5` toolchain, zero third-party
modules, deterministic build controls, and a validation gate. No listener,
database connection, credential, protected operation, or worker loop exists.
<!-- phase-6-step-2-status:end -->

<!-- phase-6-step-3-status:start -->
## Phase 6 Step 3 — Runtime Bootstrap and Bounded PostgreSQL Connectivity

The three production Go processes now have typed fail-closed configuration,
protected-file PostgreSQL URL loading, exact service-role verification, bounded
pgx pools, PostgreSQL 18 compatibility checks, loopback-only health/readiness,
context cancellation, and graceful shutdown. No protected business operation,
business listener, migration, or durable worker loop is implemented.

Active gate:

```bash
./tools/validation/phase-gates/validate_phase6_step3.sh
```
<!-- phase-6-step-3-status:end -->
