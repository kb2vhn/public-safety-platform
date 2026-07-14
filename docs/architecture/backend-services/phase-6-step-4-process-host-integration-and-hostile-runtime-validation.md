# Phase 6 Step 4 — Process-Host Integration and Hostile Runtime Validation

> **Status:** Acceptance-hardening implementation candidate. The
> pre-hardening candidate passed 59 static checks and 60 complete checks with
> zero failures. This corrected tree must be revalidated before acceptance is
> claimed.
>
> **Predecessor:** Phase 6 Step 3, accepted on the authoritative `dev` branch at
> commit `45f5449d57eda0ea8a5f2e3128f6903251599810` with 144 PASS and
> 0 FAIL in static validation.
>
> **Boundary:** This step may integrate the three accepted Go executables with a
> Linux systemd process host and may test hostile runtime failure behavior. It
> must not implement a protected business operation, business-facing listener,
> runtime migration, or durable delivery-worker loop.

## 1. Purpose

Phase 6 Step 3 established typed configuration, protected-file PostgreSQL URL
loading, exact service-role binding, bounded PostgreSQL pools, compatibility
checks, loopback-only administrative health/readiness, cancellation, and
graceful shutdown.

Step 4 establishes the operating-system process boundary around that runtime.
The objective is not merely to make the executables start at boot. The objective
is to ensure that the service manager, credential delivery, readiness state,
watchdog, restart policy, resource controls, privilege restrictions, and
failure behavior remain explicit, bounded, testable, and fail-closed.

## 2. Authoritative Sequencing Correction

The accepted Step 3 record authorizes process-host integration as Phase 6
Step 4. An older roadmap labeled Step 4 as the Controlled Foundation API
Adapter.

This record resolves that conflict as follows:

1. Phase 6 Step 4 is Process-Host Integration and Hostile Runtime Validation.
2. The former Steps 4 through 8 move to Steps 5 through 9.
3. No protected Phase 5 routine is invoked in Step 4.
4. No business transport or durable worker behavior is introduced in Step 4.
5. The accepted Step 3 runtime and database surfaces remain the predecessor
   boundary.

This is a sequencing correction, not an expansion of Step 4 authority.

## 3. In-Scope Work

Step 4 may introduce:

- one systemd service unit for each accepted executable;
- one distinct non-login operating-system identity per service;
- systemd credential delivery for each service-specific PostgreSQL URL;
- readiness and stopping notifications to the service manager;
- watchdog signaling only when the service manager explicitly enables it;
- explicit startup, shutdown, restart, and start-rate limits;
- bounded file-descriptor, task, memory, and process resource controls;
- systemd sandboxing and privilege restrictions;
- deterministic package-stage validation for the executable and unit files;
- hostile runtime tests for malformed host environment, unavailable
  notification sockets, startup cancellation, occupied administrative ports,
  unavailable or incompatible PostgreSQL, notification failure, watchdog
  failure, repeated termination, and shutdown deadlines;
- static verification of the complete service-unit boundary;
- disposable runtime validation that preserves the Step 3 database authority
  and administrative surface.

## 4. Prohibited Work

Step 4 must not introduce:

- a business or user-facing listener;
- authentication or authorization transport;
- a call to an accepted protected Foundation routine;
- protected data reads or writes;
- SQL mutation, migration, or schema-management behavior;
- integration or monitoring claim, delivery, completion, or retry loops;
- a universal service account or shared PostgreSQL login;
- a repository-stored password, PostgreSQL URL, private key, token, or
  production credential;
- a shell wrapper as the long-running service process;
- unbounded restart, retry, queue, goroutine, connection, or logging behavior;
- high-availability, load-balancing, clustering, or disaster-recovery claims;
- a production-readiness claim.

## 5. Process Inventory

The exact process inventory remains:

| Executable | Operating-system identity | PostgreSQL identity |
|---|---|---|
| `foundation-api` | `issp-foundation-api` | `issp_service_authorization` |
| `integration-delivery-worker` | `issp-integration-delivery` | `issp_service_integration_delivery` |
| `monitoring-delivery-worker` | `issp-monitoring-delivery` | `issp_service_monitoring_delivery` |

The operating-system identities are distinct, non-login identities. They do not
share a writable home directory, runtime state directory, or credential file.

The PostgreSQL role remains compiled into each executable through the accepted
Step 3 service identity. A systemd unit cannot select a different database role
by changing environment variables.

## 6. systemd Service Boundary

Each executable receives one explicit service unit.

The accepted service model shall use:

```text
Type=notify
NotifyAccess=main
```

The executable remains the direct `ExecStart` process. It must not fork,
daemonize, or depend on a shell wrapper.

The process sends readiness only after all of the following succeed:

1. typed configuration validation;
2. loopback administrative listener creation;
3. bounded PostgreSQL connection establishment;
4. exact PostgreSQL service-role verification;
5. PostgreSQL version and session compatibility verification;
6. transition of `/readyz` to ready.

When `NOTIFY_SOCKET` is absent, the executable runs in explicit standalone mode
and does not claim systemd readiness integration. When `NOTIFY_SOCKET` is
present, readiness notification is required. A malformed socket address or a
local send failure causes startup to fail closed with the process-host
operating-system exit class.

A successful local send establishes only that the notification datagram was
accepted by the local socket interface; it is not treated as proof that the
service manager has already applied the state transition. `Type=notify` remains
the service-manager authority for deciding when the unit becomes active.

The process sends `STOPPING=1` before administrative shutdown and before the
PostgreSQL pool closes. A stopping-notification error is logged with a bounded
redacted diagnostic, but cleanup continues so notification failure cannot block
resource release.

## 7. Watchdog Boundary

Watchdog behavior is opt-in through the service-manager environment. It is
disabled when `WATCHDOG_USEC` is absent or when `WATCHDOG_PID` names a different
process. A present but malformed, zero, negative, or excessive watchdog interval
is a fail-closed configuration error rather than an implicit disablement.

When enabled:

- the interval is parsed as a bounded positive duration;
- the current process identifier must match `WATCHDOG_PID` when that variable
  is present;
- the process sends watchdog notifications only after readiness;
- the transmission period is no greater than half the configured watchdog
  interval;
- the watchdog loop stops before graceful shutdown completes;
- watchdog notification failure causes the runtime to leave readiness and
  terminate with the unexpected runtime software-failure exit class;
- the watchdog loop performs no database, business, worker, or durable action.

Malformed watchdog values, invalid notification sockets, and notification
payload construction failures must return bounded typed errors and must not
panic.

## 8. Credential Boundary

Each service receives exactly one service-specific credential named:

```text
database-url
```

Each systemd unit shall use `LoadCredentialEncrypted=` with an explicit source
path and expose the decrypted immutable runtime credential under the short name
`database-url`.

The planned encrypted source artifacts are distinct:

```text
/etc/iron-signal-platform/credentials/foundation-api.database-url.cred
/etc/iron-signal-platform/credentials/integration-delivery-worker.database-url.cred
/etc/iron-signal-platform/credentials/monitoring-delivery-worker.database-url.cred
```

The existing typed configuration remains authoritative:

```text
ISSP_DATABASE_DSN_FILE=%d/database-url
```

The `%d` service-manager specifier identifies the service's credential
directory. The process continues to reject symlinks, non-regular files,
oversized files, empty files, multiline files, and files with group or other
permission bits.

Credential source artifacts, plaintext credentials, passwords, and PostgreSQL
URLs remain outside the repository. Step 4 defines names, delivery, and
validation; it does not provision a production secret.

Each service uses a different encrypted credential source. A credential for one
service must not be mounted into or accepted by another service. The units shall
use filesystem namespacing and distinct non-login users so one service does not
gain ordinary access to another service's runtime credential directory.

## 9. Startup Ordering

The units may order after the network-online target because Step 3 permits
remote PostgreSQL with certificate verification.

The base units must not hard-code a dependency on a distribution-specific
PostgreSQL unit. A deployment using local PostgreSQL may add a governed
site-specific drop-in that names the local database unit.

Startup remains bounded by:

- the systemd start timeout;
- the typed `ISSP_STARTUP_TIMEOUT`;
- the PostgreSQL connect timeout;
- the bounded pool configuration.

systemd restart behavior may retry a transient failed start, but restart rate
and delay must be bounded.

## 10. Socket-Activation Decision

Socket activation is not introduced in Step 4.

The accepted Step 3 administrative listener is internal, loopback-only, and
created only for `/healthz` and `/readyz`. Introducing inherited descriptors
would expand configuration and lifecycle semantics without adding a required
capability at this stage.

No `.socket` unit is created. Future business transport work must make a
separate, explicit socket-activation decision after authentication, request
context, transport limits, and authorization boundaries are frozen.

## 11. Resource and Privilege Boundary

The systemd units shall define and validate a conservative baseline including:

- no ambient or bounding capabilities;
- `NoNewPrivileges`;
- a restrictive umask;
- private temporary storage;
- read-only system and home boundaries;
- protection of kernel tunables, modules, logs, control groups, and clock;
- restrictions on set-user-ID and set-group-ID transitions;
- native system-call architecture;
- only the address families required for local notification and PostgreSQL
  connectivity;
- bounded open files, tasks, and memory;
- no writable persistent state directory;
- no supplementary operational or administrative groups.

Resource limits begin as conservative containment values, not performance
budgets. Resource observations remain separate from correctness acceptance.

Any directive unavailable on the canonical host must fail validation visibly or
be removed through a documented compatibility decision. It must not be silently
ignored through a leading hyphen.

## 12. Restart and Exit Semantics

The Step 3 exit-code boundary remains:

```text
0   ordinary signal-driven stop
69  PostgreSQL unavailable or incompatible
70  unexpected runtime software failure
71  listener or process-host operating-system failure
78  typed configuration rejection
```

The service manager may restart on failure but must not restart after an
ordinary controlled stop. Start-rate limiting must prevent an invalid
configuration, missing credential, wrong database identity, or persistent
host failure from creating an unbounded restart storm.

The process must become not-ready before shutdown begins.

## 13. Hostile Runtime Validation and Evidence Matrix

Step 4 acceptance uses explicit evidence classes. It does not claim that every
failure can or should be manufactured through a live production binary.

### 13.1 Process-Host Unit Evidence

The race-tested `internal/processhost` unit suite proves:

- standalone behavior when notification environment is absent;
- malformed and inconsistent notification and watchdog environment rejection;
- filesystem and Linux abstract-namespace notification sockets;
- bounded readiness, stopping, and watchdog payloads;
- watchdog process-identifier mismatch behavior;
- cancellation of the watchdog loop;
- disappeared notification-socket failure;
- bounded redacted diagnostics without socket-path disclosure.

### 13.2 Accepted Step 3 Database Evidence

The isolated accepted Step 3 predecessor continues to prove:

- PostgreSQL 18 connectivity and compatibility on the canonical test host;
- exact compiled service-role binding for all three executables;
- wrong-role denial;
- fixed application name and session parameters;
- rejection branches for unsupported PostgreSQL major versions and
  incompatible session facts;
- PostgreSQL unavailability exit classification;
- graceful SIGTERM shutdown;
- absence of protected SQL and business transport.

The canonical host has one PostgreSQL major version. Step 4 does not add a
production runtime override or test-only environment variable merely to falsify
the server version or session facts. Unsupported-version and incompatible-
session branches therefore remain deterministic source and unit/static
evidence, while the live disposable cluster proves the accepted PostgreSQL 18
path.

### 13.3 Step 4 Disposable Runtime Evidence

The Step 4 hostile-runtime script proves:

- readiness, watchdog, stopping, and secret non-disclosure for all three
  executables;
- readiness is emitted only after exact database compatibility succeeds;
- database-unavailable startup exits 69 and emits no readiness notification;
- SIGTERM during a deliberately blocked PostgreSQL startup exits cleanly,
  remains unready, and emits stopping notification;
- SIGINT followed by a repeated termination signal remains bounded and exits
  cleanly;
- malformed notification sockets exit 71;
- malformed watchdog intervals exit 78;
- occupied loopback administrative ports exit 71;
- disappeared watchdog notification sockets terminate fail-closed with exit 70;
- temporary sockets, processes, credentials, and PostgreSQL state are removed.

### 13.4 Administrative Listener and Shutdown Unit Evidence

The race-tested `internal/transport` suite proves:

- unexpected listener closure after serving begins is returned as an error;
- shutdown with an in-flight administrative request is bounded by context;
- the administrative surface remains exactly `/healthz` and `/readyz`;
- readiness transitions from unavailable to ready and returns to unavailable
  before process shutdown.

Configuration parsing and listener binding are synchronous bounded startup
steps. Their malformed and occupied conditions are tested directly. Artificial
sleep hooks are not added to production code solely to send a signal during
those short synchronous operations.

### 13.5 Service-Manager Static Evidence

Static validation proves:

- all three service units parse with `systemd-analyze verify`;
- offline security analysis produces an exposure result for every unit;
- users, groups, binaries, administrative ports, and encrypted credential
  sources are exact and distinct;
- restart, start-rate, startup, shutdown, watchdog, file-descriptor, task, and
  memory limits are explicit;
- capability, namespace, filesystem, kernel, process, and address-family
  restrictions are present;
- socket activation, shell wrappers, shared identities, credential material,
  and unaccepted host expansion remain absent.

Hostile tests must remain deterministic and clean up temporary sockets,
processes, PostgreSQL clusters, credential files, and service-manager state.

## 14. Implemented Candidate Repository Boundary

The Step 4 implementation candidate adds the following bounded structure:

```text
go/platform/
├── deployment/
│   ├── README.md
│   ├── systemd/
│   │   ├── iron-signal-foundation-api.service
│   │   ├── iron-signal-integration-delivery-worker.service
│   │   └── iron-signal-monitoring-delivery-worker.service
│   └── sysusers.d/
│       └── iron-signal-platform.conf
├── internal/
│   ├── processhost/
│   │   ├── notify.go
│   │   └── notify_test.go
│   └── transport/
│       └── hostile_test.go
└── scripts/
    ├── test-process-host.sh
    └── test-process-host-runtime.sh
```

The `processhost` package remains specific to Linux service-manager
notification. It uses only the Go standard library, imports no business
package, and does not expand database authority.

The candidate units target the verified canonical host baseline of systemd 261
and use only directives accepted by `systemd-analyze verify` on that host.

## 15. Acceptance Criteria

Phase 6 Step 4 is accepted only when:

- the exact accepted Step 3 predecessor revalidates in an isolated local
  clone on branch `dev` with the canonical GitHub origin restored;
- the Phase 6 sequence is synchronized across governing documentation;
- all three service units exist and validate;
- all three operating-system service identities are distinct;
- all three encrypted credential sources are distinct;
- each unit starts the exact corresponding binary directly;
- readiness notification occurs only after Step 3 readiness;
- stopping notification precedes resource shutdown;
- watchdog behavior is bounded, opt-in, main-process-bound, and tested;
- socket activation remains explicitly absent;
- restart, start-rate, startup, shutdown, file-descriptor, task, and memory
  limits are explicit;
- the systemd sandbox prevents unnecessary filesystem, capability, kernel, and
  privilege access;
- the complete Section 13 validation evidence matrix is satisfied;
- hostile process-host and administrative-shutdown tests pass;
- Go formatting, vetting, unit tests, race tests, module verification,
  reproducible builds, and runtime integration pass;
- no dependency is added unless separately reviewed and recorded;
- no accepted Foundation SQL, deployment SQL, or historical executable test is
  changed;
- no protected SQL verb or protected routine appears in production Go source;
- the administrative surface remains exactly `/healthz` and `/readyz`;
- the root README, documentation indexes, backend-service index, Go indexes,
  dependency record, validation indexes, phase record, gate output, counts,
  terminology, and next-step statement describe the same repository state;
- no business listener, protected operation, migration, or durable worker loop
  exists;
- static and complete Step 4 gates report zero failures.

## 16. Explicit Non-Claims

Step 4 does not claim:

- a production credential has been created or installed;
- a protected Foundation API adapter exists;
- a user or external system can make an authenticated request;
- a business listener exists;
- a protected routine is called;
- protected data is read or written;
- an integration or monitoring item is claimed or delivered;
- systemd socket activation is implemented;
- packaging is published to a repository;
- a production host has been approved;
- the platform is production-ready.

## 17. Next Step

After Step 4 is accepted, Phase 6 Step 5 may implement the Controlled Foundation
API Adapter as a narrow typed vertical slice over accepted Phase 5 routines.
