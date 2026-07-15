# Go Source

> **Current production status:** Phase 6 Step 7 Integration and Monitoring
> Delivery Workers accepted. Phase 6 Step 8 hostile, failure, concurrency, and
> resource validation is the active validation-only candidate.

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
- [Phase 6 Step 6 Authenticated Request and Transport Boundary](../docs/architecture/backend-services/phase-6-step-6-authenticated-request-and-transport-boundary.md)
- [Phase 6 Step 7 Integration and Monitoring Delivery Workers](../docs/architecture/backend-services/phase-6-step-7-integration-and-monitoring-delivery-workers.md)
- [Phase 6 Step 8 Hostile, Failure, Concurrency, and Resource Validation](../docs/architecture/backend-services/phase-6-step-8-hostile-failure-concurrency-and-resource-validation.md)

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

Step 5 is accepted at `1aefa613a80c1f5cdaf7807702b1b747d7e77ec5` with
96 PASS and 0 FAIL.
<!-- phase-6-step-5-status:end -->

<!-- phase-6-step-6-status:start -->
## Phase 6 Step 6 — Authenticated Request and Transport Boundary

Step 6 is accepted at commit `ec3c36081c686fa8ec82c8fd94bda421ed6cff42`
with 92 complete gate PASS checks and 0 failures.
<!-- phase-6-step-6-status:end -->

<!-- phase-6-step-7-status:start -->
## Phase 6 Step 7 — Integration and Monitoring Delivery Workers

Step 7 is accepted at commit `79e9723b2dd12e813de8a8c665d08d4f61cc8fab`. Static and complete validation each
reported 142 PASS and 0 FAIL. The production module includes the two bounded,
service-specific durable delivery-worker loops without a generic job framework
or transaction spanning external delivery.

- [Phase 6 Step 7 Integration and Monitoring Delivery Workers](../docs/architecture/backend-services/phase-6-step-7-integration-and-monitoring-delivery-workers.md)
<!-- phase-6-step-7-status:end -->

<!-- phase-6-step-8-status:start -->
## Phase 6 Step 8 — Hostile, Failure, Concurrency, and Resource Validation

Step 8 adds test-only adversarial campaigns, disposable PostgreSQL evidence,
and observation-only resource reporting. It does not modify production Go
source, dependencies, service units, migrations, or authority.

- [Phase 6 Step 8 Hostile, Failure, Concurrency, and Resource Validation](../docs/architecture/backend-services/phase-6-step-8-hostile-failure-concurrency-and-resource-validation.md)
<!-- phase-6-step-8-status:end -->
