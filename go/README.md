# Go Source

> **Current production status:** Phase 6 Step 1 contract freeze.

The existing code under `go/experiments/` is historical experimentation created
before the accepted Platform Foundation and production database security
boundaries. It is not production backend code and must not be imported by future
production packages.

The planned production workspace is:

```text
go/platform/
```

Phase 6 Step 1 creates no production Go module or source files. Phase 6 Step 2
will freeze the Go module path, toolchain version, package graph, dependency
policy, build commands, artifact metadata, and initial bounded executable
skeletons.

The governing contract is:

- [Production Go Service Boundary and Runtime Model](../docs/architecture/backend-services/production-go-service-boundary-and-runtime-model.md)
- [Phase 6 Step 1 Production Go Service Contract Freeze](../docs/architecture/backend-services/phase-6-step-1-production-go-service-contract.md)

<!-- phase-6-step-2-status:start -->
## Phase 6 Step 2 — Production Go Workspace and Reproducible Build Baseline

The production module now exists at `go/platform/` with three fail-closed
bounded executable skeletons, the exact `go1.26.5` toolchain, zero third-party
modules, deterministic build controls, and a validation gate. No listener,
database connection, credential, protected operation, or worker loop exists.
<!-- phase-6-step-2-status:end -->
