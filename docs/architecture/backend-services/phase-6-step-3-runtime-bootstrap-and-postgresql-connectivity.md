# Phase 6 Step 3 — Runtime Bootstrap and Bounded PostgreSQL Connectivity

> **Status:** Candidate until the complete Phase 6 Step 3 gate passes.
>
> **Accepted predecessor:** Phase 6 Step 2 implementation commit
> `2c154e4f7e7cbb050c39f8ff99d132fae8c90658`.
>
> **Database predecessor:** Phase 5 formal acceptance tag
> `phase-5-production-database-security-boundary-complete-v1`.

## 1. Decision

Implement the smallest production runtime needed to prove that each bounded Go
process can load typed configuration, read a protected PostgreSQL URL, connect
as its exact accepted Phase 5 login, verify PostgreSQL compatibility, expose
local health/readiness, and stop cleanly.

Step 3 still introduces no protected business operation.

## 2. Process and Identity Boundary

The exact process-to-login mapping remains:

| Executable | PostgreSQL login |
|---|---|
| `foundation-api` | `issp_service_authorization` |
| `integration-delivery-worker` | `issp_service_integration_delivery` |
| `monitoring-delivery-worker` | `issp_service_monitoring_delivery` |

The identity is compiled into each executable. The PostgreSQL URL must name that
same role. A URL naming another accepted service role is rejected before a pool
is created.

No universal application login is introduced.

## 3. Typed Configuration

Configuration is read only through the `internal/config` package. Required
values are:

```text
ISSP_ADMIN_LISTEN_ADDRESS
ISSP_DATABASE_DSN_FILE
```

The administrative address must use a literal loopback IP and a nonzero TCP
port. Wildcard, external, hostname, and public binds are rejected.

Optional values have explicit lower and upper bounds:

| Variable | Default | Accepted range |
|---|---:|---:|
| `ISSP_DATABASE_CONNECT_TIMEOUT` | `5s` | `1s–30s` |
| `ISSP_DATABASE_MAX_CONNECTIONS` | `4` | `1–16` |
| `ISSP_DATABASE_MIN_CONNECTIONS` | `0` | `0–4`, not above maximum |
| `ISSP_DATABASE_MAX_CONNECTION_LIFETIME` | `30m` | `1m–24h` |
| `ISSP_DATABASE_MAX_CONNECTION_IDLE_TIME` | `5m` | `30s–1h` |
| `ISSP_DATABASE_HEALTH_CHECK_PERIOD` | `30s` | `5s–5m` |
| `ISSP_STARTUP_TIMEOUT` | `15s` | `1s–1m` |
| `ISSP_SHUTDOWN_TIMEOUT` | `10s` | `1s–1m` |

Configuration errors identify the field but never echo its supplied value.

## 4. Secret Loading

The PostgreSQL URL is not accepted directly from an environment variable or
command-line argument. `ISSP_DATABASE_DSN_FILE` must name an absolute path.

The file must be:

- a regular file;
- not a symbolic link;
- nonempty and no larger than 16 KiB;
- one text line;
- inaccessible to group and other users;
- unchanged between path validation and the opened file descriptor.

The URL and password are never included in configuration strings, structured
logs, health responses, or database error messages.

Credential provisioning, rotation, and production storage remain deployment
responsibilities. Step 3 proves only the consumption boundary.

## 5. PostgreSQL Driver Decision

Step 3 accepts:

```text
github.com/jackc/pgx/v5 v5.10.0
```

The standard library has no PostgreSQL driver. pgx v5 is a mature PostgreSQL
client and pool implementation. Its use is confined to `internal/database/`.

The complete module graph and dependency rationale are recorded in
`go/platform/DEPENDENCIES.md`. No ORM, migration framework, or general-purpose
application framework is introduced.

## 6. Connection Security

The PostgreSQL URL must be complete, include an explicit TCP port, and use `postgresql://` or `postgres://`.
Multi-host URLs and unapproved URL options are rejected.

Remote operation requires:

```text
sslmode=verify-full
```

A loopback URL using `sslmode=disable` is permitted only when the operator also
sets:

```text
ISSP_DATABASE_ALLOW_INSECURE_LOCAL=true
```

This exception exists only for disposable local validation and explicitly
configured local development. It cannot authorize an insecure non-loopback
connection.

Ambient `PG*` settings cannot change the accepted role, host, port, database,
or fallback-host behavior after URL validation.

## 7. Pool and Session Boundary

Each process owns one bounded `pgxpool` pool. The pool has:

- maximum 16 connections and default 4;
- default zero minimum connections;
- bounded connect, lifetime, idle, and health-check durations;
- no fallback hosts;
- deterministic application name `issp/<process-name>`.

Every connection receives these session settings:

```text
TimeZone=UTC
search_path=pg_catalog
statement_timeout=5000
lock_timeout=2000
idle_in_transaction_session_timeout=5000
```

The restricted `search_path` requires future code to schema-qualify every
controlled routine. Step 3 executes no protected routine.

## 8. Compatibility Check

After connectivity succeeds, Step 3 executes one read-only compatibility query
that obtains:

- `current_user`;
- `current_database()`;
- `server_version_num`;
- `application_name`;
- `TimeZone`;
- `search_path`;
- `standard_conforming_strings`.

Startup fails unless:

- `current_user` equals the exact compiled service role;
- PostgreSQL major version is exactly 18;
- application name equals `issp/<process-name>`;
- time zone is UTC;
- search path is `pg_catalog`;
- standard-conforming strings are enabled.

The query reads session facts only. It performs no mutation and grants no
additional authority.

## 9. Health and Readiness

The process opens one loopback-only administrative HTTP listener. Its complete
surface is:

```text
GET /healthz
GET /readyz
```

`/healthz` reports process liveness. `/readyz` returns HTTP 503 until the exact
PostgreSQL identity and compatibility contract passes, then returns HTTP 200.
Readiness returns to false before shutdown begins.

Responses contain only process name and bounded status. They contain no
configuration, host inventory, credential, database URL, policy state, or
protected data.

This is an administrative surface, not a business API.

## 10. Cancellation and Graceful Shutdown

Each executable derives its root context from SIGINT and SIGTERM. Startup,
database operations, HTTP shutdown, and tests use bounded contexts.

Shutdown ordering is:

1. mark readiness false;
2. stop accepting administrative requests within the shutdown timeout;
3. close the PostgreSQL pool;
4. emit a bounded final structured event;
5. exit zero for an ordinary signal-driven stop.

Configuration rejection exits 78. Database unavailability or incompatibility
exits 69. Listener operating-system failure exits 71. Unexpected runtime
software failure exits 70.

## 11. Validation

The Step 3 gate proves:

- exact Step 2 predecessor ancestry and isolated predecessor revalidation;
- unchanged accepted SQL, deployment tests, and historical phase gates;
- exact Go compiler build;
- exact pgx and transitive module inventory;
- protected-file secret handling and redaction;
- literal-loopback administrative binding;
- bounded pool and session parameters;
- exact service-role validation;
- PostgreSQL 18 compatibility checks;
- health/readiness transitions;
- context cancellation;
- reproducible builds;
- fail-closed behavior without configuration;
- disposable-cluster runtime behavior for all three executables;
- wrong-role denial;
- graceful SIGTERM shutdown;
- absence of protected SQL and business transport.

Historical Step 2 validation runs in an isolated local clone checked out on a
branch named `dev` at the exact predecessor commit. It is not run against the
newer Step 3 candidate tree.

## 12. Explicit Non-Claims

Step 3 does not claim:

- a production credential has been provisioned;
- a business or user-facing listener exists;
- authentication or authorization transport exists;
- a protected Foundation routine is invoked;
- protected data is read or written;
- a migration is executed by a runtime process;
- an integration or monitoring item is claimed or delivered;
- systemd units, socket activation, packaging, or deployment are complete;
- high availability, load balancing, or disaster recovery is complete;
- the platform is production-ready.

## 13. Next Step

Phase 6 Step 4 may implement process-host integration, systemd service and
credential boundaries, startup ordering, socket-activation decisions, resource
limits, watchdog behavior, and hostile runtime failure tests while preserving
the Step 3 database and administrative surfaces.
