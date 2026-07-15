# Phase Gates

> **Owner:** Iron Signal Systems

This directory contains reproducible acceptance gates for completed and active
Foundation phases. Historical gates validate their own checkpoint trees.

Newest accepted production Go gate:

```text
validate_phase6_step6.sh
```

Phase 6 Step 6 is accepted at
`ec3c36081c686fa8ec82c8fd94bda421ed6cff42` with 92 complete gate PASS checks
and 0 failures. Phase 6 Step 7 is the active implementation candidate.

Phase 4 progression:

- Step 1 froze the approval-independence and separation-of-duties contract.
- Step 2 added migration `083`, structural test `170`, and resource telemetry.
- Step 3 added controlled Approval Action recording and test `180`; accepted
  at 500 PASS, 0 FAIL, and 3 understood WARN.
- Step 4 added independence enforcement and test `190`; accepted at
  540 PASS, 0 FAIL, and 3 understood WARN.
- Step 5 added delegated-grant lineage, incompatible-authority and prohibited-
  duty enforcement, and test `200`; accepted at 590 PASS, 0 FAIL, and
  3 understood WARN.
- Step 6 added current-action derivation, stage satisfaction, finalization,
  Decision Record stage links, and approval continuity; accepted at
  650 PASS, 0 FAIL, and 3 understood WARN.
- Step 7 added seven independent-connection approval concurrency files and
  84 assertions; accepted at 734 PASS, 0 FAIL, and 3 understood WARN.
- Step 8 records formal Phase 4 acceptance and verifies the annotated tag,
  accepted tree, documentation, correctness result, and resource observation.

## Cross-Phase Static Standard

The active phase gate invokes the separate cross-phase migration timeout
standard before database execution:

```bash
./tools/validation/validate_foundation_migration_timeouts.sh
```

## Active Gate: Phase 4 Step 8

```bash
./tools/validation/phase-gates/validate_phase4_step8.sh
```

The gate validates the annotated tag `phase-4-approval-independence-and-separation-of-duties-complete-v1`, 34 migrations, 21 sequential
tests, 16 concurrency tests, the accepted SQL and executable test tree, the
734 PASS result, synchronized acceptance documentation, and observation-only
resource telemetry.

## Phase 5 Step 1

`validate_phase5_step1.sh` freezes the production database role, ownership,
migration, runtime privilege, investigation, audit, validation,
default-privilege, and break-glass contract.

Step 1 is documentation and validation only. It preserves the accepted Phase 4
implementation and uses `validate_phase4_step8.sh` as its regression
predecessor.

## Accepted Phase 5 Step 2

`validate_phase5_step2.sh` validates the separate deployment tree, migration
900, canonical role inventory, membership semantics, documentation, accepted
Foundation regression, and isolated disposable-cluster role behavior.

## Phase 5 Step 3

`validate_phase5_step3.sh` verifies deployment migration `910`, protected
database ownership, creator-specific default privileges, documentation
synchronization, the frozen Phase 4 tree, the accepted Foundation regression,
and isolated disposable-cluster ownership behavior.

## Phase 5 Step 4

`validate_phase5_step4.sh` validates the deployment manifest, exact runtime
privilege contract, controlled `SECURITY DEFINER` routines, documentation,
the accepted Foundation regression, and disposable-cluster runtime behavior.

<!-- ISSP_PHASE5_STEP5_REVIEW_AND_VALIDATION_ROLES -->

## Phase 5 Step 5

The Step 5 gate preserves the frozen Phase 4 tree, revalidates Step 4, validates migration `930`, and proves that investigator, audit-reader, and validation-reader roles can read only their exact approved views.

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

## Active Gate: Phase 5 Step 8

```text
./tools/validation/phase-gates/validate_phase5_step8.sh
```

This gate formally accepts and freezes the production database security boundary at `phase-5-production-database-security-boundary-complete-v1` after complete Step 7 revalidation.

## CAD Phase 0 Static Gate

```bash
./tools/validation/phase-gates/cad/validate_phase0.sh
```

The CAD Phase 0 gate validates the documentation package, 104 seeded
requirements, testing registries, identifier uniqueness, cross-registry
references, status synchronization, and the absence of executable or production
claims. It does not establish CAD implementation acceptance.

<!-- PHASE6_STEP1_STATUS -->

## Phase 6 Step 1

`validate_phase6_step1.sh` validates the production Go service contract,
three exact process-to-database-role mappings, absence of premature production
Go code, unchanged accepted SQL and deployment trees, and the Phase 5 formal
acceptance predecessor.

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

`validate_phase6_step4.sh` is the accepted process-host gate. The accepted
checkpoint is `3e15c8cbb7b666537be6a7ec832800e8f4ca9af0` with 71 PASS and 0 FAIL.
<!-- phase-6-step-4-status:end -->

<!-- phase-6-step-5-status:start -->
## Phase 6 Step 5 — Controlled Foundation API Adapter

`validate_phase6_step5.sh` is accepted at
`1aefa613a80c1f5cdaf7807702b1b747d7e77ec5` with 96 PASS and 0 FAIL.
<!-- phase-6-step-5-status:end -->

<!-- phase-6-step-6-status:start -->
## Phase 6 Step 6 — Authenticated Request and Transport Boundary

`validate_phase6_step6.sh` is the accepted authenticated transport gate. The
accepted checkpoint is `ec3c36081c686fa8ec82c8fd94bda421ed6cff42` with
92 PASS and 0 FAIL.
<!-- phase-6-step-6-status:end -->

<!-- phase-6-step-7-status:start -->
## Phase 6 Step 7 — Integration and Monitoring Delivery Workers

`validate_phase6_step7.sh` validates the two-worker candidate. It revalidates
Step 6 from an isolated branch named `dev`, freezes accepted SQL and business
transport, and runs static or disposable PostgreSQL 18 worker evidence.
<!-- phase-6-step-7-status:end -->
