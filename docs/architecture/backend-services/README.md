# Backend Services Architecture

> **Status:** Architecture area under active refinement.

## Documents

- [Production Go Service Boundary and Runtime Model](production-go-service-boundary-and-runtime-model.md)
- [Phase 6 Step 1 Production Go Service Contract Freeze](phase-6-step-1-production-go-service-contract.md)
- [Phase 6 Step 2 Production Go Workspace and Build Baseline](phase-6-step-2-production-go-workspace-and-build-baseline.md)
- [Phase 6 Step 3 Runtime Bootstrap and PostgreSQL Connectivity](phase-6-step-3-runtime-bootstrap-and-postgresql-connectivity.md)
- [Phase 6 Step 4 Process-Host Integration and Hostile Runtime Validation](phase-6-step-4-process-host-integration-and-hostile-runtime-validation.md)
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

Step 4 is an acceptance-hardening implementation candidate for systemd
process hosting, distinct
operating-system service identities, encrypted service credentials, readiness
and stopping notification, bounded watchdog behavior, restart and resource
limits, sandboxing, and hostile runtime failure validation. Step 3 remains the
newest accepted implementation boundary.
<!-- phase-6-step-4-status:end -->
