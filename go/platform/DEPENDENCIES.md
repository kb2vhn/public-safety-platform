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

## Selected Module Graph

The exact module build list accepted by the Step 3 gate is:

```text
github.com/davecgh/go-spew v1.1.1
github.com/Iron-Signal-Systems/iron-signal-platform/go/platform
github.com/jackc/pgpassfile v1.0.0
github.com/jackc/pgservicefile v0.0.0-20240606120523-5a60cdf6a761
github.com/jackc/pgx/v5 v5.10.0
github.com/jackc/puddle/v2 v2.2.2
github.com/kr/pretty v0.3.0
github.com/pmezard/go-difflib v1.0.0
github.com/stretchr/objx v0.1.0
github.com/stretchr/testify v1.11.1
golang.org/x/mod v0.27.0
golang.org/x/sync v0.17.0
golang.org/x/text v0.29.0
golang.org/x/tools v0.36.0
gopkg.in/check.v1 v1.0.0-20201130134442-10cb98267c6c
gopkg.in/yaml.v3 v3.0.1
```

The additional entries are selected upstream module requirements. The Iron
Signal Platform source does not import them directly, and they are not promoted
to direct requirements merely to mirror the selected build list.

No ORM, migration framework, configuration library, logging framework, metrics
framework, command framework, or test framework is imported by production
source or added as a direct dependency.

## Authority and Removal Boundary

The dependency receives no authority by itself. Database authority remains
entirely determined by the exact Phase 5 PostgreSQL login and grants used by
each process.

The pgx-specific implementation remains confined to `internal/database/`.
Callers consume the database package rather than importing pgx directly. This
keeps replacement or upgrade work bounded.

Production packages must not import code under `go/experiments/`.

<!-- phase-6-step-4-dependency-status -->
## Phase 6 Step 4 Dependency Status

Step 4 adds no direct or transitive Go module. Native systemd-compatible
notification is implemented with the Go standard library over a bounded Unix
datagram socket.


<!-- phase-6-step-5-dependency-status -->
## Phase 6 Step 5 Dependency Status

Step 5 adds no direct or transitive Go module. Canonical Decision ID parsing,
closed reason-code validation, timeouts, cancellation, and typed errors use the
Go standard library. The accepted `pgx/v5` dependency remains confined to
`internal/database`.
