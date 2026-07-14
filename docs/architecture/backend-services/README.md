# Backend Services Architecture

> **Status:** Architecture area under active refinement.

## Documents

- [Location Service Architecture](location-service-architecture.md)

Service documents define ownership, interfaces, state, failure behavior, persistence, security, and performance boundaries for the Go modular monolith and any later extracted service.

<!-- PHASE6_STEP1_STATUS -->

## Phase 6 Step 1

- [Production Go Service Boundary and Runtime Model](production-go-service-boundary-and-runtime-model.md)
- [Phase 6 Step 1 Production Go Service Contract Freeze](phase-6-step-1-production-go-service-contract.md)

Step 1 is contract-only. Production Go workspace creation begins in Step 2.

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
