# Iron Signal Platform Production Go Module

> **Phase status:** Phase 6 Step 7 Integration and Monitoring Delivery Workers
> implementation candidate.
>
> **Accepted predecessor:** Phase 6 Step 6 at commit
> `ec3c36081c686fa8ec82c8fd94bda421ed6cff42`, with 92 PASS and 0 FAIL in
> complete validation.
>
> **Runtime status:** Three bounded service processes, typed configuration,
> protected-file database credentials, PostgreSQL 18 compatibility checks,
> local administrative health/readiness, systemd notification/watchdog
> behavior, one typed authorization-policy adapter, one authenticated loopback
> business route, and two bounded durable delivery-worker loops exist. No local
> authorization engine, direct protected-table access, generic job framework,
> or database transaction spanning external delivery exists.

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
Only the Foundation API identity may construct the controlled adapter and
business transport. Only the integration and monitoring identities may
construct their corresponding Step 7 worker.

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

Delivery workers additionally require:

```text
ISSP_DELIVERY_ENDPOINT
ISSP_DELIVERY_TOKEN_FILE
```

Batch size, maximum concurrency, claim lease, poll interval, request timeout,
and retry delays have bounded defaults and accepted ranges. Remote relay
endpoints require HTTPS. Plain HTTP is test-only through an explicit
literal-loopback exception.

## Accepted Step 5 Controlled Adapter

The accepted adapter is implemented in:

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
- is exposed only through the accepted Step 6 authenticated loopback route.

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

`test-delivery-workers.sh` runs the Step 7 source, identity, operation-specific
database-boundary, unit, and race checks.

`test-delivery-workers-runtime.sh` uses PostgreSQL 18 and a bounded local relay
to prove distinct claims, idempotency headers, success, retry, monitoring retry
exhaustion, cross-role denial, no direct table privilege, and secret redaction.

## Governing Records

- [Production Go Service Boundary and Runtime Model](../../docs/architecture/backend-services/production-go-service-boundary-and-runtime-model.md)
- [Phase 6 Step 4 Process-Host Integration and Hostile Runtime Validation](../../docs/architecture/backend-services/phase-6-step-4-process-host-integration-and-hostile-runtime-validation.md)
- [Phase 6 Step 5 Controlled Foundation API Adapter](../../docs/architecture/backend-services/phase-6-step-5-controlled-foundation-api-adapter.md)
- [Phase 6 Step 6 Authenticated Request and Transport Boundary](../../docs/architecture/backend-services/phase-6-step-6-authenticated-request-and-transport-boundary.md)
- [Phase 6 Step 7 Integration and Monitoring Delivery Workers](../../docs/architecture/backend-services/phase-6-step-7-integration-and-monitoring-delivery-workers.md)

## Boundary

This module must not import `go/experiments/`.

Step 7 does not add a second protected API operation, migration, generic job
framework, direct table access, database-selected network destination, shared
worker identity, exactly-once claim, or production credential.


## Accepted Step 6 Authenticated Transport

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
./scripts/test-delivery-workers.sh
./scripts/test-delivery-workers-runtime.sh
```


## Step 7 Delivery Worker Candidate

The integration and monitoring worker identities receive distinct encrypted
`delivery-token` credentials and fixed deployment-owned relay endpoints. They
invoke only their exact claim, completion, and reschedule routines.

Every delivery uses `ISSP-DELIVERY-V1`, a bounded JSON envelope, a bearer
credential, and the durable item identifier as `Idempotency-Key`. Claimed
external-system and monitoring-destination fields remain metadata and never
select the relay URL.

The worker loops stop claiming on cancellation, cancel in-flight HTTP requests,
attempt bounded completion or reschedule only when the network result is known,
and drain before the PostgreSQL pool closes. Integration retries are bounded
per attempt but do not claim a terminal dead-letter state because the accepted
integration schema has no terminal-failure routine.
