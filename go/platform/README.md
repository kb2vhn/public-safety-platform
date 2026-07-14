# Iron Signal Platform Production Go Module

> **Phase status:** Phase 6 Step 4 process-host acceptance-hardening
> implementation candidate. Step 3 remains the accepted implementation
> boundary.
>
> **Runtime status:** Typed configuration, protected-file secret loading,
> bounded PostgreSQL connectivity, compatibility checks, local administrative
> health/readiness, cancellation, and graceful shutdown are implemented. No
> protected business operation or durable worker loop is implemented.

## Module

```text
github.com/Iron-Signal-Systems/iron-signal-platform/go/platform
```

The module requires Go 1.26 semantics. `go.mod` names the upstream toolchain
release `go1.26.5`; `TOOLCHAIN` freezes the complete compiler identity used by
the canonical Arch development host:

```text
go1.26.5-X:nodwarf5
```

Validation uses `GOTOOLCHAIN=local` and will not silently download or substitute
another compiler.

## Executables

```text
cmd/foundation-api
cmd/integration-delivery-worker
cmd/monitoring-delivery-worker
```

Each executable is compiled with one exact Phase 5 PostgreSQL service identity.
At Step 3, all three processes share the same bounded bootstrap implementation
but receive different database roles.

## Required Runtime Configuration

The process reads typed configuration only from explicitly named environment
variables. The PostgreSQL URL itself must be stored in a regular, non-symlink
file with no group or other permission bits.

Required variables:

```text
ISSP_ADMIN_LISTEN_ADDRESS
ISSP_DATABASE_DSN_FILE
```

The administrative listener accepts only a literal loopback address. It exposes
only:

```text
/healthz
/readyz
```

The PostgreSQL URL must name the exact role compiled into the executable and include an explicit TCP port. Remote
connections require `sslmode=verify-full`. A loopback connection using
`sslmode=disable` is accepted only when
`ISSP_DATABASE_ALLOW_INSECURE_LOCAL=true` is set explicitly.

No password or full PostgreSQL URL is logged.

## Commands

From this directory:

```bash
./scripts/check.sh
./scripts/build.sh
./scripts/test-runtime.sh
```

`check.sh` verifies formatting, vetting, unit tests, module integrity, exact
approved dependency inventory, fail-closed no-configuration behavior, and
reproducible builds.

`test-runtime.sh` creates a disposable PostgreSQL 18 cluster, proves each
executable connects only as its exact service role, checks health/readiness,
verifies wrong-role denial, and proves graceful SIGTERM shutdown without
performing a protected business operation.

## Boundary

This module must not import `go/experiments/`.

Step 3 does not run migrations, expose a business API, authenticate a user,
make an authorization decision, invoke a protected Foundation routine, mutate
protected data, claim integration or monitoring work, or provision a production
credential.

## Step 4 Contract Boundary

The Step 4 process-host contract is recorded at:

```text
../../docs/architecture/backend-services/phase-6-step-4-process-host-integration-and-hostile-runtime-validation.md
```

Step 4 may add systemd process-host integration and hostile runtime validation.
It must not add a protected business operation, business listener, migration,
or durable worker loop. Step 3 remains the newest accepted executable
implementation until the acceptance-hardened Step 4 gate passes.

<!-- phase-6-step-4-implementation-candidate -->
## Step 4 Acceptance-Hardening Candidate

The pre-hardening candidate added a standard-library-only `internal/processhost` package,
native systemd-compatible readiness, stopping, and watchdog notification, three
hardened service units, three sysusers identities, service-specific encrypted
credential references, and hostile runtime validation.

Deployment boundary:

```text
deployment/README.md
```

Step 4 still performs no protected business operation, business transport,
migration, or durable worker loop.
