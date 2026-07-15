# Production Go Service Boundary and Runtime Model

> **Document status:** Normative Platform service architecture.
>
> **Phase status:** Phase 6 Step 8 Hostile, Failure, Concurrency, and Resource
> Validation implementation candidate.
>
> **Implementation status:** Phase 6 Step 7 is accepted at commit
> `79e9723b2dd12e813de8a8c665d08d4f61cc8fab` with 142 PASS and 0 FAIL in
> both static and complete validation. Step 8 adds only adversarial tests,
> hostile fixtures, validation orchestration, and observation-only resource
> telemetry. Production Go, SQL, deployment, identity, and authority boundaries
> remain frozen.
>
> **Database predecessor:** Phase 5 production database security boundary at
> `phase-5-production-database-security-boundary-complete-v1`, targeting
> `9f8dbf9d909ef157df72b12511b165a689559093`.

## 1. Purpose

Define the production Go service boundary that will consume the accepted Iron
Signal Platform PostgreSQL security boundary without weakening it.

The first production Go implementation must remain understandable, testable,
observable, replaceable, and supportable on modest hardware. It must not turn a
service compromise into database ownership, migration authority, unrestricted
table access, audit-rewrite authority, or emergency access.

PostgreSQL remains an independent security boundary. Go coordinates trusted
inputs and controlled workflows; it does not replace the database controls that
have already been accepted.

## 2. Scope

This model governs:

- the initial production Go process topology;
- process-to-PostgreSQL identity mapping;
- package and dependency boundaries;
- configuration and secret handling;
- connection-pool ownership;
- transaction and timeout behavior;
- request, actor, device, session, purpose, operation, resource, and scope
  context;
- controlled database API invocation;
- error and reason-code handling;
- health, readiness, shutdown, and backpressure behavior;
- structured logging, metrics, tracing, and resource observation;
- testing, build, provenance, and release expectations;
- the boundary between shared production code and historical experiments.

This model does not yet define:

- CAD incidents, units, assignments, calls, locations, or other module records;
- workstation presentation behavior;
- public HTTP routes or an externally stable API specification;
- a final identity-provider integration;
- production credentials or secret-store products;
- host hardening, backup protection, or off-host log transport in full;
- Kubernetes, containers, or a distributed service mesh;
- an external message broker or distributed cache;
- production deployment to a shared or persistent database.

## 3. Non-Negotiable Service Boundary

A production Go process must never obtain authority merely because it runs on a
trusted host, possesses a database credential, or is part of the Iron Signal
Platform repository.

No ordinary production Go process may:

- connect as `issp_database_owner`, `issp_foundation_owner`,
  `issp_extension_owner`, `issp_migration_executor`, or `issp_break_glass`;
- use a PostgreSQL superuser or role-creation identity;
- own protected schemas or objects;
- perform deployment migrations during normal startup;
- write protected Foundation tables directly;
- grant itself database privileges or role memberships;
- bypass the accepted controlled routine boundary;
- mint user authority from transport authentication alone;
- treat a client-supplied role, organization, purpose, scope, or resource as
  authoritative without controlled validation;
- expose raw database errors, SQL text, credentials, secrets, or protected
  context to clients;
- silently continue after sequence gaps, integrity failures, authorization
  ambiguity, or unverifiable state.

## 4. Initial Production Process Topology

Phase 6 begins with one production Go workspace and three independently bounded
processes. This is a deliberately small service topology and not a microservice
mandate.

A universal application database identity is prohibited.

| Process boundary | PostgreSQL login | Accepted database capability |
|---|---|---|
| Foundation API process | `issp_service_authorization` | Accepted authorization, session, approval, Decision Record, and lifecycle controlled routines granted through Phase 5 |
| Integration delivery worker | `issp_service_integration_delivery` | Bounded outbox claim, completion, and retry routines |
| Monitoring delivery worker | `issp_service_monitoring_delivery` | Bounded monitoring-delivery claim, completion, and retry routines |

Each process requires:

- its own credential or certificate;
- its own connection pool;
- its own connection limits and timeouts;
- its own health and readiness state;
- its own shutdown and drain behavior;
- its own logs, metrics, and deployment identity;
- no ability to reuse another process's database identity.

A later architecture decision may combine deployment units or extract services,
but it may not collapse the accepted database identities into one universal
runtime account.

## 5. Modular Monolith Direction

The initial implementation is a single versioned Go workspace with explicit
internal package boundaries and multiple bounded executables.

This approach is preferred initially because it provides:

- one dependency and toolchain baseline;
- shared typed contracts without network serialization between every package;
- simpler local testing and profiling;
- fewer independently failing deployment components;
- clear future extraction boundaries when evidence justifies extraction.

The modular monolith must not become an unstructured package graph. A package
may depend only on lower-level contracts or explicitly accepted peer
interfaces. Foundation code must not import CAD or another operational module.

The planned production workspace root is:

```text
go/platform/
```

The exact Go module path, toolchain version, package tree, and dependency set
are frozen in Phase 6 Step 2 after repository and toolchain validation.

Historical experiments remain under:

```text
go/experiments/
```

Production packages must not import experiment packages.

## 6. Database Access Contract

### 6.1 Controlled APIs Only

Production runtime code invokes only:

- the routines granted to its exact Phase 5 service identity;
- explicitly approved read surfaces where a later accepted contract grants
  them;
- database catalog checks required for bounded health or compatibility
  validation.

Direct protected-table mutation is prohibited. Direct reads are also prohibited
unless an accepted privilege contract explicitly exposes the relation or view.

### 6.2 No Runtime Migration

Normal service startup must not:

- execute deployment migrations;
- create schemas, tables, views, types, extensions, functions, or roles;
- alter ownership or default privileges;
- repair checksum mismatches automatically.

A service may fail readiness when the database schema or deployment boundary is
incompatible. It must not attempt to make the database compatible using its
runtime identity.

### 6.3 Typed Repository Boundary

SQL invocation belongs behind narrow typed interfaces. Application and
transport packages must not scatter SQL strings throughout handlers.

A repository or database adapter must:

- name the controlled routine or approved view being used;
- bind all values through driver parameters;
- preserve exact UUID, timestamp, enum, and nullable semantics;
- distinguish no-row, conflict, denied, expired, unavailable, and internal
  failures;
- avoid `SELECT *` in production contracts;
- bound result size and iteration;
- never use string concatenation for caller-controlled SQL identifiers.

### 6.4 Transaction Ownership

The layer that defines an atomic business operation owns the transaction.
Lower-level repositories must not secretly begin independent transactions that
break atomicity or attribution.

Transaction helpers must:

- accept a caller context;
- apply bounded statement, lock, and transaction timeouts;
- roll back on every unsuccessful path;
- preserve the original failure while reporting rollback failure separately;
- avoid retrying non-idempotent operations without a governed retry contract;
- emit transaction duration and outcome observations without exposing secrets.

## 7. Request and Decision Context

A protected operation must carry a typed context sufficient to preserve the
accepted Foundation decision model. Depending on the operation, this includes:

- request and correlation identifiers;
- effective actor identity;
- authenticated device or workstation identity;
- session identifier;
- organization and Platform Service;
- Governed Purpose and Governed Operation;
- Protected Resource Target;
- Governed Scope;
- Data Classification;
- Authentication Assertion reference;
- Authorization Lease reference;
- client-observed and server-received times;
- reason, justification, or supporting-record references.

Transport headers or JSON fields do not become authoritative merely because
they are well formed. The service must separate:

1. caller-supplied claims;
2. trusted authentication results;
3. current server-side context;
4. values verified by controlled PostgreSQL routines;
5. final Decision Record and operation result.

## 8. Authentication and Authorization Separation

Go may terminate a transport, validate a certificate chain, verify an external
identity-provider response, or validate a signed Authentication Assertion.
Those actions establish authentication context. They do not independently grant
permission for a protected operation.

The Foundation API process must:

- assemble typed authorization inputs;
- call the accepted controlled Foundation APIs;
- preserve returned reason codes and Decision Record references;
- fail closed when required context is missing, stale, ambiguous, or not
  evaluated;
- avoid locally duplicating PostgreSQL authorization logic in a way that can
  diverge from the accepted boundary.

Local prechecks may reject obviously invalid requests early, but a successful
local precheck is not an authorization decision.

## 9. Configuration and Secret Boundary

Configuration is divided into:

- non-secret static configuration;
- environment- or deployment-specific endpoints and limits;
- secret references;
- secret material supplied at runtime;
- dynamically discovered service and database state.

Production secrets must not appear in:

- source files;
- committed configuration examples;
- build arguments;
- command histories generated by project scripts;
- logs, panic output, metrics labels, traces, or health responses;
- test fixtures intended for repository retention.

Configuration loading must:

- reject unknown or conflicting critical fields;
- validate limits and durations before opening listeners or accepting work;
- identify the process role explicitly;
- never silently fall back to a broader database identity;
- distinguish absent optional values from malformed required values;
- produce a redacted effective-configuration fingerprint for supportability.

The concrete secret-management provider remains replaceable.

## 10. Connection Pool Contract

Each process owns exactly the pools required for its identity and database.
Pools are not shared across unrelated process identities.

Pool configuration must bound:

- maximum and minimum connections;
- acquisition wait;
- connection lifetime and idle time;
- health-check interval;
- startup connection attempts;
- retry backoff;
- per-operation timeout budgets.

Readiness requires proof that the process connected using the expected database
role and can perform only its required compatibility check. Readiness must not
execute a protected mutation merely to prove connectivity.

A database outage must not trigger an unbounded connection storm.

## 11. API and Transport Boundary

The service contract is transport-neutral. HTTP, Unix-domain sockets,
WebSockets, or another approved transport may carry requests, but transport
selection must not alter authorization semantics.

Every externally reachable listener must define:

- authentication expectations;
- maximum request size;
- header and field limits;
- read, write, idle, and total request timeouts;
- concurrency and queue limits;
- cancellation behavior;
- stable error-envelope behavior;
- trusted proxy rules when applicable;
- TLS or local-socket protection requirements.

Administrative, health, metrics, and protected operational interfaces must not
be merged merely for convenience.

## 12. Error and Reason-Code Contract

Errors are separated into:

- stable public or caller-visible reason codes;
- internal typed causes;
- attributable logs and traces;
- database-specific diagnostic details retained only where appropriate.

A client response must not expose:

- raw SQL;
- PostgreSQL object names not intended as public contracts;
- connection strings;
- stack traces;
- secret values;
- credential fingerprints;
- protected supporting-record content;
- whether a hidden resource exists when disclosure is not authorized.

Decision denials, pending approvals, conflicts, stale state, and infrastructure
failures must remain distinguishable without fabricating success.

## 13. Observability and Auditability

Each process must emit structured observations for:

- startup and shutdown;
- build and configuration fingerprints;
- database role and compatibility posture without secret material;
- request counts, durations, outcomes, and reason-code classes;
- database pool saturation and acquisition delay;
- controlled routine duration and result class;
- worker claim, completion, retry, and dead-letter conditions;
- queue depth, backpressure, and dropped or coalesced work;
- resource use and runtime health;
- unexpected panics and forced termination.

High-cardinality identities, UUIDs, resource identifiers, and raw error strings
must not become unbounded metrics labels.

Logs and traces support investigation; they do not replace Decision Records,
Approval Action Records, lifecycle history, or database evidence.

## 14. Health, Readiness, and Degraded Operation

Liveness answers whether the process is running and able to make progress.
Readiness answers whether it should receive new work.

Readiness must fail when required dependencies or compatibility checks are not
satisfied. A process may remain live while unready during bounded recovery.

Health output must distinguish at least:

- starting;
- ready;
- degraded;
- unready;
- draining;
- stopped.

A dependency failure must not be hidden behind a generic healthy response.
Health output must not disclose secrets, full connection strings, protected
record identifiers, or internal topology beyond the approved operational need.

## 15. Shutdown and Work Draining

Every executable must support deterministic cancellation and graceful shutdown.

Shutdown order must normally:

1. stop accepting new work;
2. mark the process unready;
3. cancel or drain bounded in-flight work according to operation semantics;
4. stop claim loops and timers;
5. flush bounded telemetry where possible;
6. close database pools and listeners;
7. exit with an attributable status.

A worker must not claim additional durable work after entering the draining
state. Abandoned claims must be recoverable through the accepted database retry
contract.

## 16. Worker Delivery Contract

Integration and monitoring workers consume only their accepted Phase 5
claim/completion/retry routines.

Workers must:

- use bounded batch sizes;
- honor claim ownership and retry timing;
- avoid holding database transactions across external network calls;
- treat external delivery as at-least-once unless a stronger contract is
  explicitly accepted;
- use idempotency or duplicate-tolerant provider contracts where possible;
- preserve delivery attempt attribution;
- apply bounded exponential backoff with jitter;
- expose terminal and repeatedly failing delivery states;
- stop claiming work while required dependencies are unavailable or the process
  is draining.

External systems remain replaceable and are not the canonical source of
Foundation state.

## 17. Dependency and Build Discipline

Phase 6 favors the Go standard library and small, mature dependencies with
clear ownership and maintenance history.

Every production dependency must have:

- a documented purpose;
- a pinned module version;
- checksum verification;
- license review;
- vulnerability disposition;
- an upgrade and removal path;
- evidence that the dependency does not silently broaden the security
  boundary.

An ORM, dependency-injection framework, web framework, configuration framework,
or message broker is not accepted merely because it reduces initial code.
Step 2 must justify every non-standard dependency.

Production builds must be reproducible enough to record:

- Go toolchain version;
- module graph and checksums;
- source commit and dirty state;
- build flags;
- target operating system and architecture;
- artifact SHA-256;
- SBOM and provenance references when the release pipeline is introduced.

## 18. Testing Contract

Production Go behavior requires separate layers of proof:

- package unit tests;
- table-driven validation and reason-code tests;
- database adapter tests against disposable PostgreSQL;
- process startup, readiness, and shutdown tests;
- integration and monitoring worker delivery tests;
- privilege-denial tests using exact Phase 5 service identities;
- cancellation, timeout, retry, and backpressure tests;
- hostile-input and malformed-context tests;
- concurrency and race-detector execution;
- fuzzing for parsers and externally controlled inputs where useful;
- resource telemetry and performance observation;
- static analysis, formatting, vetting, and dependency checks.

Mock-only testing cannot prove the PostgreSQL security boundary. Database tests
must apply the accepted Foundation and deployment migrations in isolated test
environments.

Correctness, security, and resource observations remain separate outcomes.
Performance thresholds become failures only after representative baselines and
explicit budgets are accepted.

## 19. Production Source Boundary

Steps 2 and 3 created the following bounded production direction. Step 4 may
add only the process-host deployment and notification boundaries recorded in
its governing contract:

```text
go/
├── README.md
├── experiments/                 # historical; not imported by production
└── platform/                    # created in Phase 6 Step 2
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
    └── test/
```

The exact package graph is frozen in Step 2. No package under `internal` is a
promise of a network service.

## 20. Phase 6 Step Plan

### Step 1 — Contract Freeze

Freeze this production process, database-consumption, configuration, secret,
transaction, observability, health, shutdown, dependency, build, and testing
boundary. Create no production Go code.

### Step 2 — Workspace and Reproducible Build Baseline

Create the production Go workspace, toolchain declaration, initial package
boundaries, formatting and static-analysis commands, dependency policy,
reproducible build metadata, and empty bounded executables.

### Step 3 — Runtime Bootstrap and Database Connectivity

Implement typed configuration, redaction, process identity, bounded PostgreSQL
pools, compatibility checks, health/readiness, cancellation, and graceful
shutdown without protected business operations.

### Step 4 — Process-Host Integration and Hostile Runtime Validation

Implement and validate the Linux process-host boundary around the accepted
Step 3 runtime. Add explicit systemd service, credential, startup-ordering,
readiness-notification, watchdog, restart, shutdown, resource-limit, and
sandboxing contracts. Exercise hostile host-environment, notification,
listener, database-startup, cancellation, and shutdown conditions without
adding a protected business operation, business listener, migration, or
durable worker loop.

Socket activation is decided explicitly in this step but is not introduced
unless it can preserve the accepted loopback-only administrative surface
without broadening process authority.

### Step 5 — Controlled Foundation API Adapter

Implement exactly one typed vertical slice over
`decision.bind_authorization_policy(uuid)`. Accept only a canonical Decision
Record UUID, preserve the exact Decision Record reference and closed reason-code
inventory, enforce the Foundation API identity, apply a bounded operation
deadline, and rely on PostgreSQL for locking and atomic mutation. Do not expose
the adapter through a business listener in this step.

### Step 6 — Authenticated Request and Transport Boundary

Implement the accepted request-context construction, transport limits,
authentication handoff, error envelopes, and cancellation behavior without
allowing transport identity to become authorization.

### Step 7 — Integration and Monitoring Delivery Workers

Accepted at commit `79e9723b2dd12e813de8a8c665d08d4f61cc8fab` with
142 PASS and 0 FAIL in static and complete validation. The two accepted delivery
identities use six operation-specific claim, completion, and reschedule methods.
Claimed destination values remain metadata; one deployment-owned relay per
worker owns network authority. Every request carries the durable identifier as
an idempotency key. Batch, concurrency, payload, timeout, claim lease, retry
delay, polling, and shutdown are bounded, and no database transaction spans
external delivery.

### Step 8 — Hostile, Failure, Concurrency, and Resource Validation

Prove privilege denial, malformed-context rejection, replay and capacity
containment, timeout and cancellation behavior, connection-pool containment,
claim-lease recovery, completion-race single-winner behavior, process shutdown,
race-detector cleanliness, relay escape prevention, redaction, and
observation-only resource baselines across the protected adapter,
authenticated transport, and durable workers. Step 8 changes validation and
documentation only; production source remains byte-for-byte frozen at Step 7.

### Step 9 — Formal Acceptance

Create the Phase 6 acceptance record and annotated implementation tag for the
accepted production Go service boundary.

## 21. Step 1 Acceptance Criteria

Phase 6 Step 1 is accepted only when:

- Phase 5 remains formally accepted and revalidates completely;
- this normative contract and the Step 1 implementation record exist;
- the initial three-process identity mapping is explicit;
- the controlled database API boundary is explicit;
- runtime migrations and universal database identities are prohibited;
- configuration, secret, transaction, health, shutdown, observability, worker,
  dependency, build, and testing requirements are explicit;
- historical experiments remain isolated;
- no production Go module or source file is created;
- no accepted Foundation SQL, deployment SQL, or executable predecessor test is
  changed;
- the Step 1 static and complete gates pass.

## 22. Explicit Non-Claims

Phase 6 Step 1 does not claim:

- production Go code exists;
- an API listener exists;
- external authentication is integrated;
- database service credentials are provisioned;
- a service has connected to PostgreSQL;
- a protected operation has been executed from Go;
- integration or monitoring delivery is operational;
- release artifacts, SBOMs, signatures, or provenance have been produced;
- host compromise containment, backup protection, or off-host logging is
  complete;
- CAD or another operational module is implemented;
- the repository is production-ready.

It freezes the contract against which production Go code will be created and
tested.
