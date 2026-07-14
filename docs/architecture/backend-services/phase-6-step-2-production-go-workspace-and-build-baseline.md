# Phase 6 Step 2 — Production Go Workspace and Reproducible Build Baseline

> **Status:** Complete. The complete Phase 6 Step 2 gate passed with zero failures.
>
> **Accepted predecessor:** Phase 6 Step 1 implementation commit
> `77f9ead23f5275e97989ea8c59b0c9c44f0c5a0b`.
>
> **Database predecessor:** Phase 5 formal acceptance tag
> `phase-5-production-database-security-boundary-complete-v1`.

## 1. Decision

Create the first production Go module at `go/platform/` without implementing a
listener, database connection, secret loader, protected Foundation operation,
or durable worker loop.

Step 2 freezes:

- module path;
- exact Go toolchain;
- initial internal package boundaries;
- the three executable-to-database-identity mappings;
- zero-third-party dependency posture;
- formatting, vetting, testing, and module-tidiness commands;
- deterministic build flags and artifact checksums;
- fail-closed executable skeleton behavior.

## 2. Toolchain

The module declares:

```text
go 1.26.0
toolchain go1.26.5
```

Validation sets `GOTOOLCHAIN=local` and requires exactly `go1.26.5`. This
prevents an implicit toolchain download from changing the validated build
context.

The `go` directive is the required language and module baseline. The toolchain
directive pins the exact patch-level implementation used for Step 2.

## 3. Module and Workspace Decision

The module path is:

```text
github.com/Iron-Signal-Systems/iron-signal-platform/go/platform
```

Only one production module exists, so Step 2 deliberately creates no `go.work`
file. A workspace file is justified only when a second independently versioned
local module actually exists.

## 4. Initial Source Boundary

```text
go/platform/
├── go.mod
├── TOOLCHAIN
├── DEPENDENCIES.md
├── README.md
├── cmd/
│   ├── foundation-api/
│   ├── integration-delivery-worker/
│   └── monitoring-delivery-worker/
├── internal/
│   ├── bootstrap/
│   ├── config/
│   ├── database/
│   ├── foundation/
│   ├── observability/
│   ├── transport/
│   └── workers/
└── scripts/
    ├── build.sh
    └── check.sh
```

The `internal` boundary prevents import by code outside this module. Package
presence does not claim implementation completeness.

## 5. Process Identity Freeze

| Executable | Process name | PostgreSQL login |
|---|---|---|
| `foundation-api` | `foundation-api` | `issp_service_authorization` |
| `integration-delivery-worker` | `integration-delivery-worker` | `issp_service_integration_delivery` |
| `monitoring-delivery-worker` | `monitoring-delivery-worker` | `issp_service_monitoring_delivery` |

The executable skeletons contain no credential and do not contact PostgreSQL.
They preserve the accepted service-identity boundary in typed code so later
bootstrap work cannot silently collapse the identities.

## 6. Dependency Baseline

Step 2 uses only the Go standard library. `go list -m all` must contain one
module, and `go.sum` must not exist.

No framework, PostgreSQL driver, configuration library, logging library,
metrics library, command framework, or test dependency is accepted yet. Step 3
must justify and pin any database driver or other non-standard module before it
is introduced.

## 7. Reproducible Build Baseline

`go/platform/scripts/build.sh`:

- requires the exact local toolchain;
- uses `CGO_ENABLED=0`;
- uses `-trimpath`;
- disables implicit VCS stamping with `-buildvcs=false`;
- removes the linker build ID with `-ldflags=-buildid=`;
- builds the three exact executables;
- records SHA-256 values and stable environment facts in
  `build-manifest.json`;
- writes only beneath the ignored output directory supplied to it.

The manifest records source commit and dirty state for attribution, but omits a
wall-clock build timestamp so identical source and toolchain inputs remain
comparable.

## 8. Validation Baseline

`go/platform/scripts/check.sh` proves:

- exact toolchain use;
- `gofmt` cleanliness;
- `go vet ./...` success;
- `go test ./...` success;
- one-module and zero-third-party dependency posture;
- module tidiness;
- two-build binary and manifest reproducibility;
- fail-closed exit status 78 for all three skeletons.

Race-detector, fuzzing, database integration, privilege-denial, cancellation,
and resource telemetry campaigns remain mandatory later in Phase 6, but Step 2
does not pretend that empty executable skeletons prove those runtime behaviors.

## 9. Explicit Non-Claims

Step 2 does not claim:

- a process can remain running as a service;
- configuration is loaded;
- a listener or health endpoint exists;
- a database driver or pool exists;
- a service credential is provisioned;
- a migration or protected routine is invoked;
- authentication or authorization transport exists;
- workers claim or deliver durable work;
- a release artifact is signed or promoted;
- the platform is production-ready.

## 10. Next Step

Phase 6 Step 3 may implement typed configuration, redaction, exact process
identity selection, bounded PostgreSQL connectivity, compatibility checks,
health/readiness states, cancellation, and graceful shutdown without adding a
protected business operation.

## Canonical Arch Compiler Build

The exact compiler build validated by Step 2 is `go1.26.5-X:nodwarf5`. The `go.mod` toolchain directive remains `go1.26.5` because it names the upstream Go release, while `go/platform/TOOLCHAIN` records the complete distribution build identity.

<!-- phase-6-step-2-accepted-result:start -->
## Accepted Result

Phase 6 Step 2 passed its complete gate with zero failures and was committed at
`2c154e4f7e7cbb050c39f8ff99d132fae8c90658`. Step 3 may add runtime bootstrap only within the frozen
service, identity, toolchain, dependency-review, and reproducible-build
boundaries.
<!-- phase-6-step-2-accepted-result:end -->
