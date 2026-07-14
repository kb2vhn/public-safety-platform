# Platform Documentation

> **Owner:** Iron Signal Systems
>
> **Current status:** Phase 6 Step 5 Controlled Foundation API Adapter
> implementation candidate; Phase 6 Step 4 is the newest accepted production
> Go implementation checkpoint
>
> **Accepted database-security tag:**
> `phase-5-production-database-security-boundary-complete-v1`
>
> **Status:** Pre-alpha; not ready for production use

## Start Here

- [Repository Overview](../README.md)
- [Architecture Index](architecture/README.md)
- [Platform Foundation Documentation](architecture/foundation/README.md)
- [Approval Independence and Separation of Duties](architecture/foundation/approval-independence-and-separation-of-duties-model.md)
- [Phase 4 Approval Independence and Separation of Duties Acceptance](architecture/foundation/phase-4-approval-independence-and-separation-of-duties-acceptance.md)
- [Phase 5 Production Database Security Boundary Acceptance](architecture/foundation/phase-5-production-database-security-boundary-acceptance.md)
- [Backend Services Architecture](architecture/backend-services/README.md)
- [Phase 6 Step 3 Runtime Bootstrap and PostgreSQL Connectivity](architecture/backend-services/phase-6-step-3-runtime-bootstrap-and-postgresql-connectivity.md)
- [Phase 6 Step 4 Process-Host Integration and Hostile Runtime Validation](architecture/backend-services/phase-6-step-4-process-host-integration-and-hostile-runtime-validation.md)
- [Phase 6 Step 5 Controlled Foundation API Adapter](architecture/backend-services/phase-6-step-5-controlled-foundation-api-adapter.md)
- [Communications Architecture](architecture/communications/README.md)
- [GIS and Mapping Architecture](architecture/gis-and-mapping/README.md)
- [Operational Workstation Architecture](../modules/CAD/docs/architecture/operational-workstation/README.md)
- [User-Interface Architecture](../modules/CAD/docs/architecture/user-interface/README.md)
- [Resource Telemetry and Performance-Regression Testing](architecture/foundation/resource-telemetry-and-performance-regression-testing-model.md)
- [Foundation Migration Timeout and Execution Performance Standard](architecture/foundation/foundation-migration-timeout-and-execution-performance-standard.md)
- [Phase 3 Authorization Acceptance](architecture/foundation/phase-3-authorization-decision-and-controlled-lease-acceptance.md)
- [Project Goals](goals/README.md)
- [Compliance Profiles](compliance-profiles/README.md)
- [Validation Tools](../tools/validation/README.md)

## Assurance Architecture

- [Verification, Validation, and Acceptance Governance](architecture/verification-validation-and-acceptance-governance-model.md)
- [Software Supply-Chain and Release Integrity](architecture/software-supply-chain-and-release-integrity-model.md)
- [Host Software, Configuration, and Runtime Integrity](architecture/host-software-configuration-and-runtime-integrity-model.md)

## Accepted Boundaries

- Phase 1 Authentication Assertions:
  `phase-1-authentication-assertion-complete-v1`
- Phase 2 Session Control:
  `phase-2-session-control-complete-v1`
- Phase 3 Authorization Decision and Controlled Lease Issuance:
  `phase-3-authorization-control-complete-v1`
- Phase 4 Approval Independence and Separation of Duties:
  `phase-4-approval-independence-and-separation-of-duties-complete-v1`
- Phase 5 Production Database Security Boundary:
  `phase-5-production-database-security-boundary-complete-v1`

Phase 6 Step 4 is the newest accepted production Go implementation checkpoint
at commit `3e15c8cbb7b666537be6a7ec832800e8f4ca9af0`, with 71 complete gate PASS
checks and 0 failures.

Accepted Phase 4 result:

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

## Accepted Phase 4 Scope

The accepted boundary includes controlled Approval Action recording, exact
actor/session/Authority Grant context, approval independence, delegated-grant
lineage, incompatible-authority and prohibited-duty enforcement, stage
satisfaction, finalization-once Approval Requests, Decision Record stage
linkage, later-use approval continuity, and independent-connection concurrency
proofs.

The seven Phase 4 concurrency files contribute 84 assertions and increase the
complete concurrency inventory from 9 to 16.

## Module-Idea Boundary

The backend-service, communications, GIS and mapping, operational-workstation,
and user-interface documents are downstream architecture areas. Phase 4 does
not move their domain-specific records, presentation state, live transport,
map rendering, or workstation behavior into the domain-neutral Foundation.

## Documentation Synchronization Rule

A phase is not complete until the root README, documentation indexes,
architecture status, test documentation, validation documentation, acceptance
record, counts, terminology, accepted tag, and next-work statement describe
the same repository state.

## Foundation Migration Execution Standard

Ordinary clean-install Foundation migrations use transaction-local limits of
`5s` for lock waits, `1min` per statement, and `1min` for an idle open
transaction. Statements observed above ten seconds require investigation.

Static validation:

```bash
./tools/validation/validate_foundation_migration_timeouts.sh
```

The Phase 4 formal-acceptance gate invokes this validator automatically. The
repository-policy check does not add SQL PASS rows or activate a general
performance-regression threshold.

## Phase 4 Revalidation

Run the formal acceptance gate with:

```bash
./tools/validation/phase-gates/validate_phase4_step8.sh
```

## Historical Phase 5 Step 1

Phase 5 Step 1 freezes the production PostgreSQL role, ownership, migration,
runtime privilege, investigation, audit, validation, default-privilege, and
break-glass contract without changing the accepted Phase 4 SQL or executable
test tree.

- [Production Database Role, Ownership, and Runtime Privilege Model](architecture/foundation/production-database-role-ownership-and-runtime-privilege-model.md)

Active gate:

```bash
./tools/validation/phase-gates/validate_phase5_step1.sh
```

## Accepted Phase 5 Step 2

Phase 5 Step 2 implements the separate deployment tree and canonical
PostgreSQL role topology while preserving the accepted Phase 4 `sql/schema`
and executable test tree.

- [Phase 5 Step 2 — Deployment Manifest and PostgreSQL Role Topology](architecture/foundation/phase-5-step-2-deployment-role-topology.md)

## Historical Phase 5 Step 3

Phase 5 Step 3 transfers protected PostgreSQL ownership to approved non-login
owners and establishes creator-specific default privileges without granting
runtime service access.

- [Phase 5 Step 3 — Ownership and Creator-Specific Default Privileges](architecture/foundation/phase-5-step-3-ownership-and-default-privileges.md)

## Historical Phase 5 Step 4

Phase 5 Step 4 implements the least-privileged runtime database boundary for
the authorization, integration-delivery, and monitoring-delivery service
identities.

- [Phase 5 Step 4 — Least-Privileged Runtime Grants and Controlled Service APIs](architecture/foundation/phase-5-step-4-least-privileged-runtime-grants.md)

No direct protected relation grants are introduced.

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

## Accepted Phase 5 — Production Database Security Boundary

The production database security boundary is formally accepted at `phase-5-production-database-security-boundary-complete-v1`, targeting `9f8dbf9d909ef157df72b12511b165a689559093`. The accepted implementation preserves the five-migration deployment boundary through migration `940`, 82 hostile/race-test PASS checks, 97 final phase-gate PASS checks, and zero failures.

See [Phase 5 Production Database Security Boundary Acceptance](architecture/foundation/phase-5-production-database-security-boundary-acceptance.md).

<!-- PHASE6_STEP1_STATUS -->

## Phase 6 Step 1 — Production Go Service Contract

Phase 6 Step 1 freezes the production Go service and runtime boundary without
creating production Go code. See the
[Production Go Service Boundary and Runtime Model](architecture/backend-services/production-go-service-boundary-and-runtime-model.md)
and the
[Step 1 contract record](architecture/backend-services/phase-6-step-1-production-go-service-contract.md).

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

<!-- phase-6-step-4-status:start -->
## Phase 6 Step 4 — Process-Host Integration and Hostile Runtime Validation

Step 4 is accepted at commit `3e15c8cbb7b666537be6a7ec832800e8f4ca9af0`.
Its final complete gate reported 71 PASS and 0 FAIL.

- [Phase 6 Step 4 Process-Host Integration and Hostile Runtime Validation](architecture/backend-services/phase-6-step-4-process-host-integration-and-hostile-runtime-validation.md)
<!-- phase-6-step-4-status:end -->

<!-- phase-6-step-5-status:start -->
## Phase 6 Step 5 — Controlled Foundation API Adapter

Step 5 is an implementation candidate for one typed call to
`decision.bind_authorization_policy(uuid)`. The candidate preserves exact
Decision Record references and reason codes without adding a business listener,
direct table access, migration, or worker loop.

```bash
./tools/validation/phase-gates/validate_phase6_step5.sh --static-only
./tools/validation/phase-gates/validate_phase6_step5.sh
```

- [Phase 6 Step 5 Controlled Foundation API Adapter](architecture/backend-services/phase-6-step-5-controlled-foundation-api-adapter.md)
<!-- phase-6-step-5-status:end -->
