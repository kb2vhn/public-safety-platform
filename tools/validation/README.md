# Validation Tools

> **Owner:** Iron Signal Systems
>
> **Current production Go status:** Phase 6 Step 4 process-host
> acceptance-hardening implementation candidate. Phase 6 Step 3 remains the
> newest accepted implementation gate.

Phase gates are retained under `tools/validation/phase-gates/`.

## Phase 4 Formal-Acceptance Gate

Complete validation:

```bash
./tools/validation/phase-gates/validate_phase4_step8.sh
```

Static repository, tag, implementation-tree, and documentation validation:

```bash
./tools/validation/phase-gates/validate_phase4_step8.sh --static-only
```

The gate verifies the annotated Phase 4 tag, the accepted implementation
commit, unchanged SQL and executable test trees, 34 migrations, 21 sequential
tests, 16 concurrency tests, 734 PASS, zero failed assertions, three understood
warnings, synchronized acceptance documentation, and the resource-observation
contract.

Historical gates remain available for their own checkpoint trees. The Step 7
gate is the implementation gate for the tagged Phase 4 tree.

## Cross-Phase Foundation Migration Timeout Contract

Validate every migration listed in the authoritative Foundation manifest:

```bash
./tools/validation/validate_foundation_migration_timeouts.sh
```

The validator enforces one transaction-local header in each migration:

```sql
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '1min';
SET LOCAL idle_in_transaction_session_timeout = '1min';
```

It is a static repository-policy check and contributes no SQL PASS rows. The
Phase 4 formal-acceptance gate invokes it automatically before database
execution.

## Phase 5 Step 1 Gate

Run the production database role and ownership contract gate:

```bash
./tools/validation/phase-gates/validate_phase5_step1.sh
```

Static repository and contract validation only:

```bash
./tools/validation/phase-gates/validate_phase5_step1.sh --static-only
```

The complete gate re-runs the formally accepted Phase 4 gate and confirms that
Step 1 did not alter the accepted Foundation SQL or executable test tree.

## Foundation Repository/Database Parity

The accepted Phase 4 review script remains frozen under `sql/schema`.
Repository/database migration parity is checked separately with:

```bash
./tools/validation/validate_foundation_database_parity.sh dev_testing
```

## Accepted Phase 5 Step 2 Gate

Run the complete deployment-role topology gate:

```bash
./tools/validation/phase-gates/validate_phase5_step2.sh
```

Run static validation only:

```bash
./tools/validation/phase-gates/validate_phase5_step2.sh --static-only
```

## Phase 5 Step 3 Gate

Complete validation:

```bash
./tools/validation/phase-gates/validate_phase5_step3.sh
```

Static repository and contract validation:

```bash
./tools/validation/phase-gates/validate_phase5_step3.sh --static-only
```

The complete gate reruns the accepted Phase 4 regression and then validates
ownership and default privileges in a disposable PostgreSQL cluster.

## Phase 5 Step 4 Gate

Run the complete least-privileged runtime grant gate:

```bash
./tools/validation/phase-gates/validate_phase5_step4.sh
```

Static validation only:

```bash
./tools/validation/phase-gates/validate_phase5_step4.sh --static-only
```

<!-- ISSP_PHASE5_STEP5_REVIEW_AND_VALIDATION_ROLES -->

## Phase 5 Step 5 Gate

Run `tools/validation/phase-gates/validate_phase5_step5.sh --static-only` for repository checks and `tools/validation/phase-gates/validate_phase5_step5.sh` for complete predecessor, Foundation, and disposable-cluster validation.

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

## Accepted Phase 5 Formal Validation

The formal Phase 5 acceptance gate is:

```text
tools/validation/phase-gates/validate_phase5_step8.sh
```

It validates the annotated tag, exact accepted implementation commit, frozen deployment and executable test tree, documentation synchronization, and complete Step 7 regression.

## CAD Phase 0 Static Gate

Validate CAD documentation and assurance registries:

```bash
./tools/validation/phase-gates/cad/validate_phase0.sh
```

This gate validates documentation and machine-readable design metadata only. It
does not claim executable CAD implementation or production readiness.

<!-- PHASE6_STEP1_STATUS -->

## Phase 6 Step 1 — Production Go Service Contract

Run the active gate from the repository root:

```bash
./tools/validation/phase-gates/validate_phase6_step1.sh
```

Static repository and predecessor-integrity validation only:

```bash
./tools/validation/phase-gates/validate_phase6_step1.sh --static-only
```

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

The Step 4 contract is recorded at:

```text
docs/architecture/backend-services/phase-6-step-4-process-host-integration-and-hostile-runtime-validation.md
```

Step 3 remains the newest accepted implementation. The pre-hardening Step 4
candidate passed 59 static and 60 complete checks with zero failures. The
acceptance-hardening correction must pass both modes again before acceptance is
claimed.
Step 4 must not add a protected business operation, business listener,
migration, or durable worker loop.
The candidate gate revalidates Step 3 from an isolated local clone on branch
`dev` with the canonical GitHub origin restored before frozen predecessor gates
run.

<!-- phase-6-step-4-status:end -->
