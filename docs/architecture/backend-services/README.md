# Backend Services Architecture

> **Status:** Architecture area under active refinement.

## Documents

- [Production Go Service Boundary and Runtime Model](production-go-service-boundary-and-runtime-model.md)
- [Phase 6 Step 1 Production Go Service Contract Freeze](phase-6-step-1-production-go-service-contract.md)
- [Phase 6 Step 2 Production Go Workspace and Build Baseline](phase-6-step-2-production-go-workspace-and-build-baseline.md)
- [Phase 6 Step 3 Runtime Bootstrap and PostgreSQL Connectivity](phase-6-step-3-runtime-bootstrap-and-postgresql-connectivity.md)
- [Phase 6 Step 4 Process-Host Integration and Hostile Runtime Validation](phase-6-step-4-process-host-integration-and-hostile-runtime-validation.md)
- [Phase 6 Step 5 Controlled Foundation API Adapter](phase-6-step-5-controlled-foundation-api-adapter.md)
- [Phase 6 Step 6 Authenticated Request and Transport Boundary](phase-6-step-6-authenticated-request-and-transport-boundary.md)
- [Location Service Architecture](location-service-architecture.md)

Service documents define ownership, interfaces, state, failure behavior, persistence, security, and performance boundaries for the Go modular monolith and any later extracted service.

<!-- PHASE6_STEP1_STATUS -->

## Phase 6 Step 1

- [Production Go Service Boundary and Runtime Model](production-go-service-boundary-and-runtime-model.md)
- [Phase 6 Step 1 Production Go Service Contract Freeze](phase-6-step-1-production-go-service-contract.md)

Step 1 is the historical contract-freeze checkpoint. The production workspace was created in Step 2.

<!-- phase-6-step-2-status:start -->
## Phase 6 Step 2 — Production Go Workspace and Reproducible Build Baseline

The production module now exists at `go/platform/` with three fail-closed
bounded executable skeletons, the exact `go1.26.5` toolchain, zero third-party
modules, deterministic build controls, and a validation gate. No listener,
database connection, credential, protected operation, or worker loop exists.
<!-- phase-6-step-2-status:end -->

<!-- phase-6-step-3-status:start -->
## Phase 6 Step 3 — Runtime Bootstrap and Bounded PostgreSQL Connectivity

- [Phase 6 Step 3 Runtime Bootstrap and PostgreSQL Connectivity](phase-6-step-3-runtime-bootstrap-and-postgresql-connectivity.md)

Step 3 implements only configuration, secret consumption, exact database
identity and compatibility checks, local administrative health/readiness, and
graceful lifecycle behavior. Protected operations remain absent.
<!-- phase-6-step-3-status:end -->

<!-- phase-6-step-4-status:start -->
## Phase 6 Step 4 — Process-Host Integration and Hostile Runtime Validation

- [Phase 6 Step 4 Process-Host Integration and Hostile Runtime Validation](phase-6-step-4-process-host-integration-and-hostile-runtime-validation.md)

Step 4 is the accepted process-host checkpoint at
`3e15c8cbb7b666537be6a7ec832800e8f4ca9af0`, validated at 71 PASS and 0 FAIL.
<!-- phase-6-step-4-status:end -->

<!-- phase-6-step-5-status:start -->
## Phase 6 Step 5 — Controlled Foundation API Adapter

Step 5 is accepted at `1aefa613a80c1f5cdaf7807702b1b747d7e77ec5` with
96 PASS and 0 FAIL.

- [Phase 6 Step 5 Controlled Foundation API Adapter](phase-6-step-5-controlled-foundation-api-adapter.md)
<!-- phase-6-step-5-status:end -->

<!-- phase-6-step-6-status:start -->
## Phase 6 Step 6 — Authenticated Request and Transport Boundary

- [Phase 6 Step 6 Authenticated Request and Transport Boundary](phase-6-step-6-authenticated-request-and-transport-boundary.md)

Step 6 exposes the accepted adapter through one authenticated loopback route
without creating local authorization semantics.
<!-- phase-6-step-6-status:end -->
