# Production Go Dependency Record

> **Phase status:** Phase 6 Step 3 bounded PostgreSQL connectivity.

Phase 6 Step 3 introduces one direct third-party module:

```text
github.com/jackc/pgx/v5 v5.10.0
```

## Accepted Purpose

`pgx/v5` supplies the PostgreSQL wire-protocol client and bounded connection
pool used by the three production processes. The Go standard library does not
contain a PostgreSQL driver, so a reviewed external module is necessary to
perform real PostgreSQL connectivity.

The accepted use is limited to:

- parsing one complete PostgreSQL URL read from a protected file;
- creating a bounded `pgxpool` pool;
- setting fixed connection and session parameters;
- pinging PostgreSQL;
- executing the Step 3 compatibility query;
- closing the pool during shutdown.

Step 3 does not use pgx to run migrations, write protected data, invoke a
protected routine, claim durable work, or implement a business operation.

## Version and Support

- Direct module: `github.com/jackc/pgx/v5 v5.10.0`
- License: MIT
- Stable major: v5
- Minimum supported Go declared by pgx: Go 1.25
- PostgreSQL support declared by pgx includes PostgreSQL 18

The version is pinned in `go.mod`; all module content is verified by `go.sum`
and `go mod verify`.

## Transitive Modules

The complete accepted production module graph is:

```text
github.com/Iron-Signal-Systems/iron-signal-platform/go/platform
github.com/jackc/pgpassfile v1.0.0
github.com/jackc/pgservicefile v0.0.0-20240606120523-5a60cdf6a761
github.com/jackc/pgx/v5 v5.10.0
github.com/jackc/puddle/v2 v2.2.2
golang.org/x/sync v0.17.0
golang.org/x/text v0.29.0
```

No ORM, migration framework, configuration library, logging framework, metrics
framework, command framework, or test framework is introduced.

## Authority and Removal Boundary

The dependency receives no authority by itself. Database authority remains
entirely determined by the exact Phase 5 PostgreSQL login and grants used by
each process.

The pgx-specific implementation remains confined to `internal/database/`.
Callers consume the database package rather than importing pgx directly. This
keeps replacement or upgrade work bounded.

Production packages must not import code under `go/experiments/`.
