# Go Source

> **Current production status:** Phase 6 Step 5 Controlled Foundation API
> Adapter implementation candidate. Phase 6 Step 4 is the newest accepted
> implementation checkpoint.

The production Go module exists at:

```text
go/platform/
```

It contains three bounded executables with the exact accepted Go toolchain,
typed fail-closed configuration, protected-file PostgreSQL URL consumption,
exact service-role verification, bounded PostgreSQL 18 connectivity,
loopback-only administrative health/readiness, cancellation, and graceful
shutdown.

The code under `go/experiments/` remains historical experimentation created
before the accepted Platform Foundation and production database security
boundaries. It is not production backend code and must not be imported by
production packages.

Governing records:

- [Production Go Service Boundary and Runtime Model](../docs/architecture/backend-services/production-go-service-boundary-and-runtime-model.md)
- [Phase 6 Step 3 Runtime Bootstrap and PostgreSQL Connectivity](../docs/architecture/backend-services/phase-6-step-3-runtime-bootstrap-and-postgresql-connectivity.md)
- [Phase 6 Step 4 Process-Host Integration and Hostile Runtime Validation](../docs/architecture/backend-services/phase-6-step-4-process-host-integration-and-hostile-runtime-validation.md)
- [Phase 6 Step 5 Controlled Foundation API Adapter](../docs/architecture/backend-services/phase-6-step-5-controlled-foundation-api-adapter.md)

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

Step 4 is accepted at commit `3e15c8cbb7b666537be6a7ec832800e8f4ca9af0`
with 71 complete gate PASS checks and 0 failures.
<!-- phase-6-step-4-status:end -->

<!-- phase-6-step-5-status:start -->
## Phase 6 Step 5 — Controlled Foundation API Adapter

Step 5 adds one standard-library typed Decision ID and closed reason-code
adapter over the accepted policy-binding routine. `pgx` remains confined to
`internal/database`; no business transport is added.
<!-- phase-6-step-5-status:end -->
