# Iron Signal Platform Production Go Module

> **Phase status:** Phase 6 Step 6 Authenticated Request and Transport Boundary
> implementation candidate.
>
> **Accepted predecessor:** Phase 6 Step 5 at commit
> `1aefa613a80c1f5cdaf7807702b1b747d7e77ec5`, with 96 PASS and 0 FAIL in
> complete validation.
>
> **Runtime status:** Three bounded service processes, typed configuration,
> protected-file database credentials, PostgreSQL 18 compatibility checks,
> local administrative health/readiness, systemd notification/watchdog
> behavior, one typed authorization-policy adapter, and one authenticated
> loopback business route exist. No external gateway, local authorization
> engine, or durable worker loop exists.

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
Only the Foundation API identity may construct the Step 5 controlled adapter.

## Required Runtime Configuration

The process reads typed configuration only from explicitly named environment
variables. The PostgreSQL URL itself must be stored in a regular, non-symlink
file with no group or other permission bits.

Required variables:

```text
ISSP_ADMIN_LISTEN_ADDRESS
ISSP_DATABASE_DSN_FILE
```

The administrative listener accepts only a literal loopback address and exposes
only:

```text
/healthz
/readyz
```

The PostgreSQL URL must name the exact role compiled into the executable and
include an explicit TCP port. Remote connections require
`sslmode=verify-full`. A loopback connection using `sslmode=disable` is
accepted only when `ISSP_DATABASE_ALLOW_INSECURE_LOCAL=true` is set explicitly.

No password or full PostgreSQL URL is logged.

## Step 5 Controlled Adapter

The candidate adapter is implemented in:

```text
internal/foundation/authorization_policy.go
```

It invokes exactly:

```sql
SELECT decision.bind_authorization_policy($1::uuid)
```

The operation accepts one canonical non-zero Decision ID and returns the same
Decision ID plus one closed stable reason code. The adapter:

- accepts no caller-supplied policy, result, or reason;
- uses a fixed three-second operation deadline;
- preserves context cancellation;
- performs no automatic retry;
- contains no direct protected-table reference;
- exposes no generic SQL or pgx primitive;
- is not connected to a business-facing listener in Step 5.

PostgreSQL remains authoritative for row locking, policy resolution, terminal
deny persistence, and statement atomicity.

## Commands

From this directory:

```bash
./scripts/check.sh
./scripts/build.sh
./scripts/test-runtime.sh
./scripts/test-process-host.sh
./scripts/test-process-host-runtime.sh
./scripts/test-foundation-adapter.sh
./scripts/test-foundation-adapter-runtime.sh
```

`check.sh` verifies formatting, vetting, unit tests, module integrity, exact
dependency inventory, fail-closed configuration behavior, and reproducible
builds.

`test-foundation-adapter.sh` runs adapter-specific static checks and race tests.

`test-foundation-adapter-runtime.sh` creates a disposable PostgreSQL 18 cluster,
applies the unchanged accepted Foundation and deployment migrations, and proves
exact reason codes, persisted Decision Record state, wrong-role denial,
concurrency serialization, no direct protected-table privilege, and secret
non-disclosure.

## Governing Records

- [Production Go Service Boundary and Runtime Model](../../docs/architecture/backend-services/production-go-service-boundary-and-runtime-model.md)
- [Phase 6 Step 4 Process-Host Integration and Hostile Runtime Validation](../../docs/architecture/backend-services/phase-6-step-4-process-host-integration-and-hostile-runtime-validation.md)
- [Phase 6 Step 5 Controlled Foundation API Adapter](../../docs/architecture/backend-services/phase-6-step-5-controlled-foundation-api-adapter.md)

## Boundary

This module must not import `go/experiments/`.

Step 5 does not expose a business API, authenticate a caller, construct trusted
request context, finalize an authorization decision, issue an Authorization
Lease, run a migration, access protected tables directly, claim delivery work,
or provision a production credential.


## Step 6 Authenticated Transport Candidate

Foundation API requires a separate loopback business address and encrypted
`transport-hmac-key` credential. The exact route is:

```text
POST /v1/foundation/authorization-policy-bindings
```

The handoff verifier authenticates a short-lived signed gateway result and
atomically rejects replay. Subject, provider, and assertion identifiers are not
passed to the Step 5 adapter or returned to clients.

Validation:

```bash
./scripts/test-authenticated-transport.sh
./scripts/test-authenticated-transport-runtime.sh
```
