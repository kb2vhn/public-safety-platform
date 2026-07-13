# CAD Phased Development Roadmap

> **Owner:** Iron Signal Systems
>
> **Module:** Computer Aided Dispatch
>
> **Document status:** Normative planning architecture
>
> **Implementation status:** CAD design scaffold exists; no CAD production SQL,
> Go service, test inventory, phase gate, deployment, or production acceptance
> is established by this document
>
> **Roadmap basis:** Dependency-driven and acceptance-driven, not calendar-driven

## Purpose

Define how the Computer Aided Dispatch module advances through documentation,
PostgreSQL, Go, testing, phase gates, resource observation, performance
governance, user-interface implementation, Operational Workstation delivery,
integration, pilot use, and production acceptance.

This roadmap replaces a coarse sequence of large implementation stages with
smaller governed phases that can be designed, built, tested, measured, and
accepted independently.

The roadmap does not authorize CAD executable work before its prerequisites are
accepted.

## Current CAD Position

The repository already contains substantial CAD design covering:

- Module ownership and dependency direction.
- Dispatcher workflow and information hierarchy.
- Incident lifecycle and append-oriented operational history.
- Units, resources, assignments, recommendations, alerts, timers, locations,
  premises, hazards, authorization, integrations, degraded operation,
  accessibility, and workstation behavior.
- Testing and acceptance expectations.
- Architecture decisions and acceptance-record structure.

That design is valuable, but it is not an accepted executable CAD phase.

The current CAD boundary still includes:

- No allocated CAD migration range.
- No CAD schema manifest.
- No CAD schema migration.
- No CAD production database object.
- No CAD SQL test manifest.
- No CAD SQL concurrency manifest.
- No CAD production Go service.
- No CAD service build contract.
- No CAD phase gate.
- No CAD formal phase acceptance record.
- No CAD performance threshold.
- No CAD accessibility acceptance.
- No CAD pilot or production readiness claim.

Existing design work may satisfy much of a future documentation phase, but the
repository must not retroactively label a CAD phase complete until its exact
gate and acceptance record exist and pass.

## Controlling Dependency Direction

```text
Accepted Platform Foundation
        ↓
Accepted production database security and deployment boundary
        ↓
Governed shared capabilities
        ↓
CAD domain architecture and controlled database APIs
        ↓
CAD production Go services
        ↓
CAD user-interface contracts
        ↓
CAD Operational Workstation and other clients
        ↓
Replaceable external adapters and delivery technologies
```

A lower layer may consume an accepted upper layer.

An upper layer must not acquire a dependency on a CAD implementation detail.

## Entry Prerequisites

### Documentation Work

CAD documentation may continue while later Platform Foundation work is active,
provided that the documentation:

- Does not claim executable implementation.
- Does not redefine Foundation concepts.
- Does not allocate a migration range without an accepted decision.
- Does not create a hidden production Go contract.
- Does not claim production readiness.
- Remains synchronized with the current repository boundary.

### CAD SQL Work

The first CAD schema migration must not be accepted until:

1. The CAD module boundary is accepted.
2. CAD terminology and state-machine invariants are stable enough to name
   durable records.
3. The exact CAD migration range is allocated within the module-owned range.
4. CAD schema, ownership, migration, runtime-role, and controlled-write
   contracts are accepted.
5. The production database security boundary needed by CAD is accepted.
6. The authoritative CAD manifest and test-manifest structure are defined.
7. The CAD migration timeout and transaction contract is defined.
8. The initial CAD phase gate exists in static-only form.
9. Synthetic workload and resource-observation profiles are defined.

### Production Go Work

Production CAD Go code must not begin by promoting or importing historical code
from `go/experiments`.

Production Go work requires:

1. Accepted CAD controlled database APIs for the implemented slice.
2. Accepted runtime database roles and privileges.
3. A production Go repository and package contract.
4. A service identity and configuration contract.
5. Context cancellation, timeout, error, logging, telemetry, and secret-handling
   rules.
6. Reproducible builds.
7. Unit, integration, race, and end-to-end test strategy.
8. Resource-observation hooks from the first executable service.

### User-Interface and Workstation Work

Production dispatcher interface or Operational Workstation work requires:

1. Accepted CAD service contracts for the implemented workflow.
2. Stable state and error semantics.
3. Explicit stale, queued, failed, pending, conflicted, and committed states.
4. Accepted accessibility test strategy.
5. Accepted workstation component, IPC, cache, spool, update, rollback, fault,
   and recovery contracts.
6. No direct protected-table access from a client.

## Expected Authoritative Paths

Exact paths are frozen during the repository-contract phase. The expected
layout is:

```text
modules/CAD/
modules/CAD/docs/
modules/CAD/docs/acceptance/
modules/CAD/docs/architecture/
modules/CAD/docs/decisions/
modules/CAD/docs/requirements/

sql/schema/manifests/cad.manifest
sql/schema/migrations/cad/

test-framework/sql/tests/cad/
test-framework/sql/tests/concurrency/cad/
test-framework/sql/tests/cad-tests.manifest
test-framework/sql/tests/cad-concurrency-tests.manifest
test-framework/sql/schema/scripts/test_cad.sh
test-framework/sql/schema/scripts/test_cad_with_resources.sh

go/services/cad/

tools/validation/phase-gates/cad/
```

The roadmap does not create these paths merely to imply progress.

## Standard CAD Phase Lifecycle

Each executable CAD phase should normally advance through the following steps.

### Step 1 — Contract Freeze

Update and accept the governing architecture before implementation.

The contract must define:

- Exact scope.
- Terminology.
- Owned records.
- State transitions.
- Controlled operations.
- Authorization and approval context.
- Transaction boundaries.
- Concurrency invariants.
- Failure behavior.
- Degraded behavior.
- Accessibility requirements when human-facing.
- Resource-observation requirements.
- Explicitly excluded behavior.

### Step 2 — Static Gate

Create or update the phase gate before executable implementation is accepted.

The static gate should validate:

- Required files.
- Exact paths.
- Naming.
- Documentation links.
- Migration and test registration.
- Range ownership.
- Status language.
- Prohibited placeholders.
- No committed secrets.
- No production imports from `go/experiments`.
- Expected phase counts.
- Required timeout headers.
- Prior accepted boundary unchanged unless the phase explicitly changes it.

### Step 3 — Minimum Coherent Implementation

Implement only the smallest coherent boundary needed for the phase.

A phase must not mix unrelated features merely because they use the same table,
service, screen, or provider.

### Step 4 — Sequential Correctness and Adversarial Campaign Tests

Add:

- Structural tests.
- Catalog tests.
- Ownership and privilege tests.
- Positive behavior.
- Invalid-transition behavior.
- Repeated negative and hostile behavior at every applicable enforcement point.
- Direct Go rejection campaigns.
- Direct PostgreSQL rejection and bypass campaigns.
- Full-stack Go-to-PostgreSQL adversarial campaigns.
- Idempotency and replay campaigns when applicable.
- Exact unintended-side-effect checks.
- Retained seeds and hostile regression corpus.

A hostile case is not accepted as proven after one execution. Candidate gates must run at least 1,000 completed attempts per hostile class
at every applicable enforcement point. Formal acceptance gates must run at
least 10,000 completed attempts per high-impact operation at every applicable
enforcement point, and every required hostile class must reach at least 10,000
completed attempts.

### Step 5 — Independent-Connection and Hostile-Race Campaigns

Use real independent database connections, service clients, workers, or
processes when state can race.

A concurrency-sensitive behavior is not accepted based only on one transaction,
one connection, mocks, sequential tests, or one fixed race schedule.

Hostile-race campaigns must repeat timing, ordering, cancellation, retry,
revocation, replay, winner-selection, and recovery variations while asserting
the exact authoritative result and absence of unintended side effects.

### Step 6 — Go, PostgreSQL Bypass, and End-to-End Tests

When the phase includes Go:

- Add unit tests.
- Add package contract tests.
- Run `go test`.
- Run the race detector where applicable.
- Add repeated malformed-input, stale-context, replay, and authorization-denial
  campaigns at the Go boundary.
- Assert when a Go-owned rejection prevents database invocation.
- Add direct PostgreSQL campaigns that bypass Go and prove the runtime role,
  controlled APIs, privileges, current-state checks, and constraints
  independently fail closed.
- Add service-to-database adversarial campaigns.
- Add request cancellation, timeout, pool-exhaustion, bounded retry, and
  retry-storm campaigns.
- Prove one retry owner, one end-to-end attempt budget, no nested retry
  amplification, and a maximum of 11 total attempts including the initial
  execution.
- Prove no direct protected-table write path.
- Prove exact error, technical-retry, policy-denial, and commit semantics.
- Prove a weakness or omission in one non-authoritative layer cannot bypass the
  remaining authoritative controls.

### Step 7 — Resource Observation

Run correctness and resource observation separately.

Record applicable:

- Total and phase duration.
- CPU.
- Memory.
- Disk and filesystem activity.
- PostgreSQL transactions and blocks.
- Temporary files.
- Locks and deadlocks.
- WAL generation.
- Database size and growth.
- Query and operation latency.
- Connection-pool wait.
- Go heap, allocations, garbage collection, goroutines, and open descriptors.
- Queue depth.
- Retry and replay counts.
- Retry sequence, attempt ordinal, serialization, deadlock, calculated
  backoff, actual full-jitter sleep, cumulative wait, exhaustion, and
  retry-amplification telemetry.
- Workstation component CPU and memory.
- Client input, update, and render latency.
- Environment fingerprint.

### Step 8 — Candidate Gate

Run the complete phase gate.

The candidate gate must:

- Re-run or verify the accepted prerequisite boundary.
- Run static checks.
- Build a clean disposable environment.
- Apply manifests in dependency order.
- Run sequential tests.
- Run concurrency tests.
- Run the required per-layer adversarial campaigns at the accepted minimums.
- Run the mandatory local cache and queue authority-misuse campaign when any
  such mechanism exists or changes.
- Verify exact campaign counts, seeds, technical retries, unexpected
  successes, unintended side effects, and authority-manufacture counters.
- Capture and correlate mandatory server, PostgreSQL, Go, worker, adapter,
  workstation, workstation-component, IPC, cache, spool, queue, and outbox
  telemetry for the pre-run, active-run, and recovery intervals.
- Fail when mandatory telemetry is missing, uncorrelated, unreadable, or does
  not account for all completed attempts.
- Analyze unexpected errors, resource anomalies, timing deviations,
  telemetry gaps, retry behavior, crashes, recovery behavior, and
  inconsistent outcomes for previously unidentified attack mechanisms.
- Correlate related failures across Go, PostgreSQL, queues, workers,
  adapters, workstations, retries, recovery, and external delivery.
- Convert every confirmed attack mechanism into a stable hostile-class
  identifier and permanent adversarial regression case.
- Evaluate whether a discovered mechanism affects other CAD operations,
  Foundation capabilities, workstation components, integrations,
  deployment boundaries, or future modules.
- Run Go tests when applicable.
- Run resource observation when applicable.
- Produce exact counts.
- Preserve failed state when needed for investigation.
- Report correctness, resources, performance, accessibility, and deployment
  status separately.

### Step 9 — Formal Acceptance

Formal acceptance requires:

- Exact accepted boundary.
- Exact files.
- Exact migration and test counts.
- PASS, FAIL, and understood WARN totals.
- Correctness result.
- Resource-observation result.
- Performance-threshold status.
- Accessibility status.
- Deployment status.
- Known limitations.
- Explicitly unimplemented behavior.
- Accepted tag or commit.
- Retained acceptance record.
- Next planned boundary.
- Every discovered attack mechanism has a documented disposition.
- Every confirmed mechanism has been added to the permanent adversarial
  regression corpus.
- Required prevention, detection, containment, telemetry, alerting,
  recovery, and operational-response controls are implemented and tested.
- No unresolved critical or high-impact mechanism remains outside an
  accepted remediation, exception, or risk process.

## Gate Naming and Behavior

The exact naming convention is frozen during CAD Phase 3. A recommended pattern
is:

```text
tools/validation/phase-gates/cad/validate_cad_phase0_step1.sh
tools/validation/phase-gates/cad/validate_cad_phase4_step3.sh
tools/validation/phase-gates/cad/validate_cad_phase4_acceptance.sh
```

Every gate should support, where meaningful:

```text
--static-only
```

A complete CAD gate should fail closed when:

- The repository is dirty in a way that invalidates provenance.
- A required manifest entry is absent.
- A migration or test count differs from the accepted inventory.
- A prior accepted tree changed unexpectedly.
- A timeout contract is missing.
- A required test did not run.
- A resource result is missing when required.
- A warning is new or unexplained.
- Documentation and implementation describe different boundaries.

A gate must not silently change cluster-global roles in a shared development
cluster. Cluster-global deployment tests require an isolated disposable
PostgreSQL cluster.

## SQL Development Standard

CAD SQL should follow the established Platform pattern:

- Manifest-driven migration order.
- Registered applied migrations.
- Clean installation into a uniquely named disposable database.
- Separate schema and deployment trees.
- Explicit ownership.
- Least-privileged runtime roles.
- Controlled write APIs.
- Security-definer hardening where used.
- Fixed `search_path` behavior.
- No unrestricted runtime schema ownership.
- No direct protected-table writes by a production service.
- Append-oriented history where the governing contract requires it.
- Explicit correction and supersession.
- Exact-context Foundation authorization integration.
- Independent PostgreSQL verification of minimum protected-operation
  conditions.
- Idempotent migration behavior only where explicitly required.
- No rollback fiction for destructive production data changes.

Unless a later accepted decision changes the rule, CAD migrations should adopt
the established execution-safety standard:

```sql
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '1min';
SET LOCAL idle_in_transaction_session_timeout = '1min';
```

Any individual migration statement observed above ten seconds requires
investigation. These limits expose abnormal behavior; they are not normal
performance budgets.

## Go Development Standard

The production CAD Go service should be designed independently from historical
experiments.

The production contract should include:

- A deliberate module or workspace structure.
- `cmd` entry points only for supported executables.
- Internal packages that prevent accidental external coupling.
- Explicit domain and application boundaries.
- PostgreSQL adapters that invoke controlled APIs.
- External adapters separated from canonical CAD behavior.
- No SQL hidden inside user-interface code.
- No authorization inferred from HTTP routes, UI visibility, or client claims.
- Context propagation.
- Timeouts and cancellation.
- Bounded retries.
- Idempotency keys where delivery can repeat.
- Structured errors.
- Structured logging without secrets or protected content leakage.
- Health and readiness behavior.
- Metrics and tracing hooks.
- Secure configuration and secret retrieval.
- Graceful shutdown.
- Bounded goroutine ownership.
- Bounded database pools.
- Reproducible builds.
- Dependency review.
- Unit, integration, race, and end-to-end tests.

The first production Go phase should be small enough to prove the service
boundary before broad feature work begins.

## Testing Layers

CAD testing should remain layered.

### Layer 1 — Static Repository Policy

Prove repository structure, paths, manifests, naming, required documentation,
timeouts, counts, and prohibited patterns.

### Layer 2 — SQL Structure and Privilege

Prove schemas, types, tables, indexes, constraints, functions, triggers,
ownership, privileges, search paths, row-level security where applicable,
security-definer properties, and manifest registration.

### Layer 3 — SQL Behavior

Prove controlled operations, exact state transitions, append-oriented history,
correction, supersession, denial without side effects, and Foundation
authorization integration.

### Layer 4 — SQL Concurrency

Prove single-winner, finalization-once, uniqueness, transfer, assignment,
acknowledgment, closure, correction, revocation, and replay behavior using
independent connections.

### Layer 5 — Go Unit and Package Tests

Prove parsing, validation, state handling, error mapping, timeout behavior,
configuration, adapter contracts, and internal package boundaries.

### Layer 6 — Go Integration

Prove service identity, database role, controlled API use, transaction
boundaries, cancellation, connection-pool behavior, and exact committed effects.

### Layer 7 — End-to-End CAD Workflow

Prove a complete request from an authenticated client context through the Go
service and controlled PostgreSQL boundary to the committed CAD result and
returned operational projection.

### Layer 8 — Integration and Replay

Prove external authentication, contract versions, outbox behavior, duplicate
detection, idempotency, retry, replay, ordering, partial failure, queue recovery,
and provider replacement.

### Layer 9 — Accessibility and Human Interaction

Prove keyboard operation, focus, programmatic state, non-color meaning,
screen-reader behavior, high contrast, zoom, map alternatives, alert delivery,
degraded behavior, and representative dispatcher workflows.

### Layer 10 — Load, Endurance, Recovery, and Operations

Prove workload limits, resource use, queue drainage, restart, backup, restore,
rebuild, failover, reconciliation, and sustained operation.

## Defense-in-Depth Adversarial Campaign Standard

### Purpose

CAD must prove sustained fail-closed behavior under deliberate abuse, not merely
show that one hand-written negative example was rejected once.

Every executable phase must identify all prevention and enforcement points for
each high-impact operation and attack each applicable point directly.

### Layer Matrix

The phase traceability matrix must identify applicable campaigns for:

| Layer | Required proof |
|---|---|
| Client and command input | Malformed or ambiguous input is contained, but the client is never treated as the security authority. |
| Go transport boundary | Decoding, schema, size, normalization, and unsupported-version checks reject correctly. |
| Go application boundary | Context, preconditions, state version, idempotency, timeout, cancellation, and retry rules reject correctly. |
| Go authorization integration | Missing, forged, stale, contradictory, revoked, or out-of-scope context fails before commit. |
| PostgreSQL role boundary | Runtime identities cannot own schemas, bypass controlled APIs, or directly write protected records. |
| PostgreSQL controlled API | The database independently revalidates current state and exact protected-operation context. |
| PostgreSQL structural boundary | Constraints, triggers, row-level security, ownership, and security-definer hardening prevent invalid effects. |
| Foundation dependency | Approval, finalization, authorization, lease, Decision Record, and current-state rules cannot be fabricated or replayed. |
| Outbox and worker boundary | Duplicate, replayed, reordered, expired, or partially failed delivery cannot create duplicate or unauthorized effect. |
| External adapter boundary | Provider behavior cannot redefine CAD commitment or authorization. |
| Full stack | A request traversing Go and PostgreSQL fails closed with zero unintended state. |
| Direct bypass | Direct database and lower-layer attempts remain denied when higher layers are omitted. |
| Concurrency and recovery | Independent actors, connections, workers, retries, restarts, and reconciliation preserve one authoritative outcome. |

### Mandatory Local Cache and Queue Authority-Misuse Campaign

A local cache, workstation queue, spool, offline record, server queue, outbox,
worker backlog, replay buffer, or reconciliation item is never authority.

Every applicable phase must attack those mechanisms as high-impact protected
operations and prove they cannot manufacture, imply, promote, replay, or
counterfeit:

- Approval Action Records or stage satisfaction.
- Approval Request finalization.
- Authorization Decisions or Authorization Leases.
- Decision Records or Decision Supporting Records.
- Foundation current-state validation.
- Committed CAD state.
- Successful external delivery.
- Supervisory or operator authority.

The campaign must cover workstation storage, IPC, Go client and server
boundaries, server queues and workers, PostgreSQL runtime roles and controlled
APIs, direct database bypass, full-stack execution, restart, replay, recovery,
and reconciliation.

Required misuse variants include tampering, fabrication, cross-context copying,
stale replay, duplication, reordering, truncation, corruption, forged
identifiers or context, component restart, worker restart, resource exhaustion,
and attempts to reinterpret technical failures or provider acknowledgment as
authorization or commitment.

This campaign is subject to the full candidate and formal-acceptance minimums
below. Any manufactured Foundation record, unauthorized CAD commit, external
delivery, or cross-context side effect is an immediate correctness failure.

### Campaign Volume

Unless an accepted decision requires more:

- Candidate gates execute at least 1,000 completed attempts for every hostile
  behavior class at every applicable enforcement point.
- Formal acceptance executes at least 10,000 completed hostile attempts for
  every high-impact protected operation at every applicable enforcement point.
- Every required hostile behavior class executes at least 10,000 completed
  attempts during formal acceptance.
- Fuzz, mutation, mixed-traffic, and endurance campaigns may run tens or
  hundreds of thousands of attempts.
- A later phase must retain and rerun the hostile corpus from every earlier
  accepted phase.

The total campaign volume will commonly be hundreds of thousands or millions
of attempts in one formal acceptance gate because the same operation is
challenged at multiple independent layers and every required hostile class
must reach its own minimum count.

### Campaign Accounting

Every gate must report:

```text
configured
generated
attempted
completed
expected rejection
technical retry
unexpected success
unintended side effect
seed or seed range
generator and corpus version
duration
```

`unexpected success` and `unintended side effect` must both equal zero.

Technical retries are reported separately. Deadlocks, serialization failures,
timeouts, and connection failures are not automatically counted as successful
security rejections.

### Exact Side-Effect Proof

After each attempt or bounded reproducible batch, assert applicable:

- Protected records unchanged.
- No unauthorized current projection.
- No timeline, audit, approval, authorization, lease, or Decision Record
  fabricated.
- No assignment, alert, timer, queue, or outbox effect.
- No external delivery.
- No privilege or ownership change.
- No hidden partial commit.

### Reproducibility

Generated campaigns must use retained seeds, versioned generators, and a stable
regression corpus.

Every discovered malicious, malformed, stale, replayed, or concurrency case
that exposes a defect becomes a permanent regression case.

### Claim Boundary

Successful campaigns are strong evidence of sustained adversarial resistance
within the accepted threat model and environment.

No finite test count proves prevention of every possible attack. The project
must not describe the result as absolute or universal malice prevention.

## Bounded Retry and Retry-Storm Standard

### Technical Outcome Boundary

Serialization and deadlock outcomes remain retryable technical outcomes.

They must not be classified as policy denials, approval denials, authorization
denials, successful approvals, successful Authorization Decisions, or committed
CAD results.

Retry exhaustion remains a technical failure.

### Accepted Retry Envelope

The accepted retry family is:

```text
Maximum total attempts: 11
Accepted configured total attempts: 5 through 11
Initial backoff interval: 50 through 100 milliseconds
Backoff multiplier: 2.0
Maximum backoff cap: 1 through 2 seconds
Jitter: full randomization
```

The total attempt count includes the initial execution.

A configuration of 11 therefore permits one initial execution and at most 10
retry executions.

For retry number `r`, beginning with `r = 1` after the initial attempt:

```text
calculated_cap_r =
    min(maximum_backoff_cap,
        initial_backoff_interval * 2^(r - 1))

actual_sleep_r =
    uniform_random_duration(0, calculated_cap_r)
```

### Retry Ownership

Every operation must have exactly one end-to-end retry owner and one retry
budget.

Go, PostgreSQL wrappers, workers, adapters, and workstation components must not
create nested independent retry loops that multiply the accepted maximum.

The retry sequence must retain one correlation identity, idempotency identity,
attempt counter, deadline, and cancellation context.

### Fresh Revalidation

Every retry begins a new transaction and revalidates:

- Current CAD state.
- Current Foundation Approval state.
- Current Authorization Decision context.
- Current Authorization Lease.
- Current policy and authority state.
- Exact organization, scope, purpose, operation, and protected target.
- Operation-specific preconditions and version state.

A prior allowed decision cannot be treated as permanently reusable authority for
a later transaction.

### Non-Retryable Results

Authentication failure, policy denial, authorization denial, approval denial,
revocation, withdrawal, expiry, stale state, malformed input, illegal
transition, durable business conflict, privilege denial, cache or queue
authority-misuse rejection, and unknown unclassified failures do not enter the
automatic retry loop.

### Mandatory Retry-Storm Campaign

Every retry-enabled phase must run candidate and formal retry-storm campaigns at
the normal CAD hostile-campaign minimums.

Campaigns must sweep:

- Total attempts 5 through 11.
- Initial intervals 50 through 100 milliseconds.
- Caps 1 through 2 seconds.
- Full-jitter seeds.
- Client, connection, worker, process, and workstation concurrency.
- Serialization and deadlock mixtures.
- Early, middle, final-attempt success, and complete exhaustion.
- Cancellation, timeout, shutdown, restart, revocation, lease expiry, and state
  change between attempts.
- Direct PostgreSQL, direct Go, worker, queue, outbox, adapter, IPC,
  workstation-originated, and full-stack paths.
- Database, pool, CPU, memory, disk, network, socket, descriptor, queue, and
  workstation pressure.

The campaign must prove:

- No sequence exceeds 11 total attempts.
- No nested retry amplification occurs.
- Full jitter remains within the calculated bound.
- The cap remains within the accepted 1-to-2-second profile.
- A new transaction and current-state validation occur on every attempt.
- A policy denial stops retry.
- Retry exhaustion remains technical.
- One commit creates one effect.
- Cancellation and deadlines stop work cleanly.
- No approval, authorization, lease, Decision Record, external delivery, or
  committed CAD state is manufactured.
- Server and workstation resources remain bounded and recover.

### Mandatory Retry Telemetry

Every retry-storm run must correlate:

- Run, campaign, operation, retry sequence, attempt, host, workstation, process,
  worker, connection, and transaction identifiers.
- Configured budget and retry owner.
- Serialization, deadlock, denial, cancellation, timeout, exhaustion, and commit
  outcomes.
- Initial interval, multiplier, calculated cap, configured cap, actual jittered
  sleep, cumulative sleep, and remaining deadline.
- Current-state, Approval, authorization, Lease, policy, and idempotency safe
  fingerprints.
- PostgreSQL locks, waits, transactions, rollbacks, deadlocks, serialization
  outcomes, buffers, WAL, and connections.
- Go pool waits, goroutines, threads, heap, allocations, garbage collection,
  descriptors, queue state, worker state, and request latency.
- Workstation CPU, memory, disk, network, IPC, cache, queue, spool, disconnect,
  reconnect, focus, responsiveness, and recovery impact.
- Attempt-budget violations, backoff-bound violations, nested amplification,
  unexpected successes, unintended side effects, and authority-manufacture
  counters.

Formal acceptance requires all violation counters to equal zero.

## Performance and Resource Governance

### Observation First

Resource telemetry begins with the first executable CAD phase.

Correctness results and resource observations remain separate.

A phase may be:

```text
Correctness: PASS
Resource observation: RECORDED
Performance thresholds: NOT_EVALUATED
```

This is valid while representative baselines are still being collected.

### Mandatory Server and Workstation Telemetry During Adversarial Campaigns

Every candidate and formal-acceptance campaign must collect correlated telemetry
from the server and workstation sides for the full pre-run, active-run, and
post-run recovery interval.

The required telemetry matrix includes:

- Host CPU, memory, pressure, disk, filesystem, network, process, thread,
  descriptor, socket, cgroup, systemd, thermal, and fault state.
- PostgreSQL connections, transactions, statements, controlled operations,
  denials, waits, locks, deadlocks, buffers, temporary files, WAL, checkpoints,
  sizes, growth, plans, rows, roles, privileges, and current-state
  revalidation.
- Go request, authorization, denial, retry, timeout, cancellation, database-pool,
  heap, allocation, garbage-collection, goroutine, thread, descriptor, queue,
  outbox, adapter, health, restart, and shutdown behavior.
- Workstation and workstation-component CPU, memory, disk, network, process,
  thread, descriptor, Unix-domain socket, systemd, GTK, WebKitGTK, graphics,
  display, accessibility-profile, input, focus, render, alert, cache, spool,
  queue, replay, quarantine, restart, and recovery behavior.
- Per-layer hostile-attempt, expected-rejection, technical-retry,
  unexpected-success, unintended-side-effect, direct-database-invocation,
  external-delivery, and authority-manufacture counters.
- Retry sequence, attempt budget, attempt ordinal, retry owner,
  serialization, deadlock, calculated cap, actual full-jitter sleep,
  cumulative delay, exhaustion, cancellation, timeout, and nested-retry
  amplification counters.

Every metric must be correlated to the run, campaign, hostile class, operation,
enforcement point, host, workstation, process, software revision, environment,
seed, and time interval.

Missing mandatory telemetry, missing correlation, unaccounted attempts, or lost
server or workstation observations cause the gate to fail. Unsupported metrics
must be explicitly identified and governed; they must not silently disappear
from the report.

Telemetry must exclude secrets and unnecessary protected content and must never
be used as an authorization or commitment source.

### Reference Environments

CAD performance results must identify the environment.

At minimum, profiles should distinguish:

- Minimal development database host.
- Representative production database host.
- Go service host.
- Dispatcher Operational Workstation.
- Integrated single-site pilot environment.
- Degraded or constrained environment.

Results from unlike environments must not be compared as though they are one
continuous benchmark series.

### SQL Measurements

Measure applicable:

- Clean-install migration duration.
- Per-migration duration.
- Lock waits.
- Statement latency.
- Transaction latency.
- Rows examined and affected.
- Index usage.
- Temporary files.
- Buffer activity.
- WAL generation.
- Database size and growth.
- Deadlocks.
- Long transactions.
- Connection use.
- Current-projection refresh cost.
- History growth cost.

### Go Measurements

Measure applicable:

- Request latency.
- Database time.
- Connection-pool acquisition wait.
- CPU.
- Resident memory.
- Heap.
- Allocations.
- Garbage collection.
- Goroutine count.
- Open descriptors.
- Queue depth.
- Retry rate.
- Timeout rate.
- Cancellation completion.
- Shutdown duration.
- Outbox processing latency.

### User-Interface and Workstation Measurements

Measure applicable:

- Startup.
- Login and session establishment.
- Incident-queue initial load.
- Incident selection.
- Unit-board refresh.
- Command acknowledgment.
- Alert presentation.
- Input-to-visible-response latency.
- Map and alternative-list update.
- Recovery after component restart.
- Cache and spool growth.
- CPU, memory, threads, descriptors, sockets, restarts, and faults by
  workstation component.
- Host CPU, memory pressure, swap, disk I/O, filesystem capacity, network
  latency and loss, thermal state, and throttling.
- Unix-domain socket latency, errors, rejection, queueing, and backpressure.
- GTK and WebKitGTK process health, memory, crashes, restarts, and render
  behavior.
- Graphics or GPU utilization, memory, frame timing, and render stalls where
  available.
- Local cache, queue, spool, replay, quarantine, reconciliation, and attempted
  authority-promotion counters.
- systemd service, socket activation, watchdog, restart, and dependency state.
- Operation under one, two, and representative multi-monitor layouts.
- Accessibility-feature performance.
- Degraded-mode operation.

### Workload Profiles

Before performance thresholds are enabled, define synthetic workload profiles
for:

- Number of organizations and agencies.
- Dispatch positions.
- Concurrent dispatchers.
- Active incidents.
- Incidents created per time interval.
- Units and tracked resources.
- Unit-status update rate.
- Location-update rate.
- Timeline-event rate.
- Alert and timer volume.
- Outbox and external-delivery rate.
- Retained history.
- Query and reporting load.
- Integration degradation and recovery backlog.

The roadmap does not invent production scale or latency budgets before these
profiles are accepted.

### Promotion to Performance Gates

A performance observation may become a pass/fail threshold only after:

1. The workload is defined.
2. The environment is defined.
3. The measurement method is reproducible.
4. Enough representative same-environment runs exist.
5. Normal variation is understood.
6. The budget has operational meaning.
7. The budget includes a documented margin.
8. The threshold and response to failure are accepted in a decision record.

Thresholds should be operation-specific. One global “CAD must be fast” threshold
is not defensible.

---

# Phase Roadmap

## CAD Phase 0 — Governance, Roadmap, and Repository Truth

### Goal

Establish one authoritative roadmap and make the current CAD status explicit.

### Documentation

- Accept this roadmap.
- Confirm the CAD module boundary.
- Confirm architecture precedence.
- Inventory all CAD architecture, requirements, decisions, and acceptance paths.
- Define document status vocabulary.
- Define phase, step, candidate, accepted, and production-ready meanings.
- Record explicitly that existing CAD design is not executable acceptance.

### SQL

No CAD SQL.

### Go

No production CAD Go code.

### Testing

Static documentation checks:

- Required files exist.
- Links resolve.
- Status statements agree.
- No old root architecture paths remain.
- No production claim exists.
- No migration range is implied.

### Gate

Create the first CAD static-only gate.

The gate should validate documentation and repository truth only.

### Performance

```text
Resource observation: NOT_APPLICABLE
Performance thresholds: NOT_APPLICABLE
```

### Exit

- CAD Phase 0 acceptance record exists.
- Exact static PASS count is retained.
- Next phase is stated.
- No executable implementation is claimed.

## CAD Phase 1 — Dispatcher Operational Contract and Terminology

### Goal

Freeze what a dispatcher, supervisor, and supported workstation must understand
and do before database naming begins.

### Documentation

Accept:

- Dispatcher workspace.
- Incident queue.
- Selected incident context.
- Unit and resource board.
- Alerts and timers.
- Map and equivalent non-map representations.
- Command and quick-action behavior.
- Dispatcher and supervisor boundaries.
- Information hierarchy.
- Accessibility requirements.
- Degraded-state presentation.
- Canonical CAD glossary.

Define exact distinctions such as:

- Intake versus incident.
- Caller location versus incident location.
- Available versus dispatchable.
- Recommendation versus proposed assignment versus committed assignment.
- Acknowledged alert versus resolved condition.
- Locally recorded versus queued versus authoritatively committed.
- CAD operational timeline versus security audit record.

### SQL

No production SQL.

A non-executable conceptual model may be retained in documentation.

### Go

No production Go.

Service and client terminology may be documented.

### Testing

Static requirement checks:

- Every key term has one meaning.
- Every dispatcher capability has a requirement identifier.
- Critical states have accessible representations.
- No client is treated as an authorization source.
- No workstation cache is treated as canonical truth.

### Gate

Static-only.

### Performance

Define the categories to be measured later, but do not set thresholds.

### Exit

- Glossary and operational contract accepted.
- Requirement identifiers stable.
- No unresolved term is used to name a durable database object.

## CAD Phase 2 — Domain Invariants, State Machines, and Controlled Operation Catalog

### Goal

Freeze the business invariants PostgreSQL and Go must enforce.

### Documentation

Define:

- Incident identity and lifecycle.
- Intake-to-incident relationships.
- Operational timeline semantics.
- Correction and supersession.
- Incident ownership and transfer.
- Unit and resource identity.
- Availability, dispatchability, and status.
- Assignment lifecycle.
- Alert, timer, acknowledgment, escalation, and resolution.
- Response plans and recommendations.
- Location roles.
- Premise and hazard governance.
- Duplicate and related incidents.
- Closure and reopening.
- Exact Foundation approval and authorization integration.
- Governed Purposes.
- Governed Operations.
- Protected Resource Targets.
- Decision Supporting Records.
- Required reason codes.
- Concurrency invariants.
- Failure and retry taxonomy.

### SQL

No accepted migration yet.

Create a data-design inventory in documentation only.

### Go

No production Go.

Define request, response, command, event, error, and retry semantics without
freezing a transport technology prematurely.

### Testing

Create a traceability matrix mapping:

```text
Requirement
→ invariant
→ controlled operation
→ expected positive test
→ expected negative test
→ expected race test
→ expected resource observation
```

### Gate

Static-only.

### Performance

Define initial synthetic workload dimensions.

Do not assign final scale values yet.

### Exit

- State machines accepted.
- Controlled operation catalog accepted.
- Concurrency-sensitive operations identified.
- Foundation integration boundary accepted.
- Durable naming is stable enough for the repository-contract phase.

## CAD Phase 3 — Migration Range, Repository, Runtime, Test, Gate, and Performance Contract

### Goal

Authorize the executable CAD repository structure without yet implementing
domain behavior.

### Documentation and Decisions

Approve:

- Exact CAD migration range within `200–899`.
- Schema names.
- Manifest name.
- Migration naming.
- Registry behavior.
- Dependency order.
- Separate schema and deployment boundaries.
- Owner roles.
- Migration roles.
- Runtime service roles.
- Read-only and validation roles.
- Break-glass relationship.
- Controlled database API conventions.
- Transaction isolation expectations.
- Timeout contract.
- Go service repository structure.
- Test manifest structure.
- Gate naming.
- Result artifact paths.
- Resource-observation format.
- Reference environment fingerprints.

### SQL

Create only the accepted repository and manifest skeleton.

No domain table is accepted merely because the directory exists.

### Go

Create only the production Go module or workspace skeleton if the Foundation Go
runtime contract is ready.

It must not import `go/experiments`.

### Testing

Add framework self-tests for:

- Empty CAD manifest behavior.
- Dependency ordering.
- Duplicate registration denial.
- Migration range enforcement.
- Test-manifest registration.
- Gate result formatting.
- Resource artifact creation.
- Deterministic adversarial generator and seed retention.
- Per-layer campaign accounting.
- Zero unexpected-success and unintended-side-effect gate behavior.

### Gate

Full repository-contract gate.

Database execution may be limited to framework behavior if no CAD domain
migration exists.

### Performance

Record framework and clean-environment overhead.

No domain performance threshold.

### Exit

- Exact paths and ranges accepted.
- CAD implementation is authorized to begin at Phase 4.
- No CAD business behavior is claimed.

## CAD Phase 4 — Core Incident Structure and Append-Oriented History

### Goal

Create the smallest durable CAD domain structure.

### Documentation

Freeze:

- Incident identifier.
- Human-readable incident-number strategy.
- Intake references.
- Classification and priority.
- Organization and Governed Scope binding.
- Operational location roles.
- Timeline event envelope.
- Effective time and recorded time.
- Source and provenance.
- Correction and supersession lineage.
- Current projection rules.
- Data classification.
- Retention placeholders without inventing legal policy.

### SQL

Implement the smallest coherent structural migrations for:

- Incident identity.
- Incident number allocation structure.
- Incident classification references.
- Operational locations.
- Append-oriented incident timeline.
- Correction and supersession links.
- Minimal current-state projection.
- Validation views.

Do not yet implement broad dispatcher actions.

### Go

No production command service is required.

A read-only contract prototype may begin only if the production Go skeleton is
accepted, but it must not become a supported service in this phase.

### Testing

Add:

- Clean installation.
- Catalog and constraint tests.
- Ownership and privilege tests.
- Timeline append behavior.
- Correction and supersession structure.
- Incident-number uniqueness.
- Independent-connection incident-number allocation race.
- Invalid location-role behavior.
- Projection consistency.

### Gate

Full SQL gate with exact counts and resource observation.

### Performance

Record:

- Migration time.
- Incident insert cost.
- Timeline append cost.
- Projection maintenance cost.
- WAL.
- Database growth per synthetic incident.
- Incident-number allocation contention.

Thresholds remain observation-only.

### Exit

- Core structure accepted.
- No general dispatcher write API claimed.
- Next phase adds controlled incident behavior.

## CAD Phase 5 — Controlled Incident Lifecycle

### Goal

Implement protected incident creation and lifecycle transitions through
controlled PostgreSQL APIs.

### Documentation

Freeze controlled operations for:

- Create incident.
- Classify.
- Change priority.
- Add and verify location.
- Record operational update.
- Place on hold.
- Transfer responsibility.
- Close.
- Reopen.
- Cancel.
- Correct or supersede material information.

Define exact authorization, reason, Decision Record, Decision Supporting Record,
and Authorization Lease use where required.

### SQL

Implement controlled functions and supporting records.

Runtime roles must not receive direct protected-table write access.

### Go

No broad production service yet.

A test-only caller may invoke the controlled APIs.

### Testing

Add:

- Positive lifecycle tests.
- Denied transition tests.
- Stale context denial.
- Revoked lease denial.
- Wrong scope denial.
- Wrong organization denial.
- Correction without history loss.
- Close versus new-event race.
- Transfer acceptance race.
- Reopen versus correction race.
- Retryable serialization and deadlock behavior.
- Retry-storm campaigns across 5-to-11 total attempts, 50-to-100-millisecond
  initial intervals, 2.0 backoff, 1-to-2-second caps, and full jitter.

### Gate

Full SQL behavior and concurrency gate.

### Performance

Record:

- Controlled-operation latency.
- Lock waits.
- transaction duration.
- Timeline growth.
- Projection update cost.
- Denial cost.
- Contention behavior.

### Exit

- Incident lifecycle accepted at the database boundary.
- Production Go may consume only the accepted operations.

## CAD Phase 6 — Units, Resources, Capabilities, Availability, and Status

### Goal

Establish trustworthy resource identity and current operational state.

### Documentation

Freeze:

- Unit versus resource.
- Organization and discipline ownership.
- Capabilities.
- Staffing dependencies.
- Availability versus dispatchability.
- Status types and transitions.
- Location observation relationship.
- Source and freshness.
- Current state and history.
- Temporary restrictions.
- Out-of-service behavior.

### SQL

Implement:

- Resource identities.
- Resource types.
- Capabilities and validity.
- Unit composition where applicable.
- Availability and dispatchability records.
- Status observations and current projection.
- Controlled status transitions.
- Freshness metadata.
- Validation views.

### Go

No production CAD Go service is accepted in this phase.

Test-only clients may exercise the controlled PostgreSQL boundary. Production
read projections wait for the accepted Go service foundation in Phase 11.

### Testing

Add:

- Capability validity.
- Allowed and denied status transitions.
- Stale source behavior.
- Concurrent status update races.
- Out-of-order observation behavior.
- Unavailable versus nondispatchable distinctions.
- Direct-write denial.
- Read-only role behavior.

### Gate

SQL plus any accepted read-only Go projection tests.

### Performance

Record:

- Unit-board query cost.
- Status-update throughput.
- Current projection cost.
- Location freshness query cost.
- Growth under synthetic update rates.

### Exit

- Resource and status model accepted.
- No assignment is implied by status.

## CAD Phase 7 — Assignment, Dispatch Intent, Delivery State, and Acknowledgment

### Goal

Implement concurrency-safe unit assignment and dispatch lifecycle.

### Documentation

Freeze:

- Recommended.
- Proposed.
- Authorized.
- Committed.
- Delivery queued.
- Delivery sent.
- Provider accepted.
- Delivered.
- Acknowledged.
- Accepted or rejected.
- En route.
- On scene.
- Completed.
- Cleared.
- Cancelled.
- Reassigned.
- Failed.
- Conflicted.

Define exactly what is authoritative at each state.

### SQL

Implement:

- Assignment identity.
- Incident-resource relationship.
- Assignment lifecycle.
- Controlled assign, cancel, reassign, accept, reject, and clear operations.
- Dispatch delivery intent.
- Idempotency keys.
- Acknowledgment records.
- Current assignment projection.
- Transactional outbox use where the Foundation contract applies.

### Go

No production CAD Go service is accepted in this phase.

Test-only clients may invoke the controlled assignment APIs and must verify exact
result states. Production service exposure waits for Phase 11 and Phase 12.

### Testing

Add:

- Assignment positive and negative tests.
- Same-unit concurrent assignment race.
- Assignment versus unit-unavailable race.
- Cancellation versus acknowledgment race.
- Duplicate request and replay tests.
- Outbox atomicity.
- Provider acknowledgment duplication through test-only contract inputs.
- Transaction timeout and retry behavior.
- Controlled-API exact-effect tests.

### Gate

Full SQL assignment, concurrency, idempotency, and resource gate.

### Performance

Record:

- Assignment commit latency.
- Contention.
- Outbox enqueue latency.
- Synthetic delivery backlog growth.
- Lock waits.
- WAL generation.
- Current-assignment projection cost.

### Exit

- The protected assignment database boundary is accepted.
- Production Go exposure remains unimplemented until Phase 11 and Phase 12.
- External delivery success remains distinct from CAD commitment.

## CAD Phase 8 — Alerts, Timers, Escalation, Acknowledgment, and Resolution

### Goal

Implement explainable attention management without alarm-state ambiguity.

### Documentation

Freeze:

- Condition versus alert.
- Severity.
- Ownership.
- Timer policy.
- Start, pause, stop, warning, and escalation behavior.
- Deduplication.
- Suppression.
- Acknowledgment.
- Resolution.
- Expiration.
- Accessibility presentation requirements.

### SQL

Implement:

- Alert types and versions.
- Alert instances.
- Timer policies and state.
- Acknowledgment.
- Escalation.
- Resolution.
- Deduplication context.
- Governed suppression.
- Current alert projection.

### Go

No production CAD Go service is accepted in this phase.

Test-only clients may exercise alert and timer operations. Timers requiring
central authority must not exist only in a client process. Production service
exposure waits for Phase 11 and Phase 12.

### Testing

Add:

- Alert creation.
- Deduplication.
- Material-change behavior.
- Acknowledgment without resolution.
- Resolution without history loss.
- Concurrent acknowledgment.
- Concurrent resolution.
- Escalation.
- Expiration.
- Suppression limits.
- Database session or test-runner interruption.
- Timer-state recovery.
- Accessible state semantics at the contract level.

### Gate

SQL, concurrency, timer-recovery, and resource gate.

### Performance

Record:

- Timer evaluation cost.
- Alert query and update latency.
- Deduplication cost.
- Escalation backlog.
- High-volume status-update effect.
- Workstation alert delivery latency later remains a separate measurement.

### Exit

- Alert lifecycle accepted.
- No client-only timer is authoritative.

## CAD Phase 9 — Response Plans and Explainable Resource Recommendations

### Goal

Provide governed decision support without silently dispatching resources.

### Documentation

Freeze:

- Response-plan applicability.
- Versioning.
- Required and preferred resources.
- Capability matching.
- Jurisdiction and scope.
- Coverage constraints.
- Fallback and mutual aid.
- Recommendation freshness.
- Ranking explanation.
- Exclusion explanation.
- Override and supervisory review.

### SQL

Implement:

- Response plans and versions.
- Applicability rules.
- Resource requirements.
- Recommendation evaluation records.
- Considered and excluded resources.
- Explanation data.
- Expiration.
- Override records.

### Go

No production CAD Go service is accepted in this phase.

A test-only evaluator may exercise recommendation behavior. Production
recommendation service work waits for the accepted Go service foundation.
Recommendation calculation must be reproducible from retained inputs or retain
enough supporting context to explain the result.

### Testing

Add:

- Plan selection.
- Version binding.
- Capability match.
- Exclusion reasons.
- Stale location behavior.
- Expiration.
- Recommendation versus assignment separation.
- Override preservation.
- Concurrent recommendation expiration during assignment.
- Deterministic result tests where required.
- Property or fuzz tests for rule parsing where useful.

### Gate

SQL explanation, concurrency, determinism, and resource gate.

### Performance

Record:

- Recommendation-evaluation latency by workload profile.
- Candidate-set size.
- Query count.
- Database CPU and buffer activity.
- Temporary-file use.
- Expiration and reevaluation volume.
- External routing contribution remains unevaluated until adapter phases.

### Exit

- Recommendations are accepted as explainable decision support.
- No automatic assignment is implied.

## CAD Phase 10 — Premises, Hazards, Geospatial Context, and Incident Relationships

### Goal

Add structured operational context without turning unverified free text into
permanent truth.

### Documentation

Freeze:

- Premise identity.
- Access points.
- Sensitive access information.
- Hazard types.
- Source.
- Verification.
- Confidence.
- Review.
- Expiration.
- Approval where required.
- Location provenance.
- Map layers.
- Non-map alternatives.
- Duplicate and related incident relationships.
- Major-incident grouping.

### SQL

Implement:

- Premises.
- Access points.
- Hazard records.
- Review and expiration.
- Verification and approval references.
- Location provenance.
- Relationship types.
- Incident links.
- Current effective warnings.

### Go

No production CAD Go service is accepted in this phase.

Test-only clients may exercise authorized premise, hazard, and relationship
operations. Production service exposure waits for Phase 11 and Phase 12.
Map-provider behavior remains in a replaceable adapter.

### Testing

Add:

- Unverified-warning restrictions.
- Expiration.
- Review.
- Sensitive access denial.
- Wrong-scope denial.
- Correction and supersession.
- Duplicate-link race.
- Relationship cycles where prohibited.
- Conflicting or missing geospatial provenance.
- Map-independent canonical location operation.
- Accessible list-equivalence contract through static traceability.

### Gate

SQL authorization, relationship, provenance, and resource gate.

### Performance

Record:

- Premise lookup latency.
- Spatial or normalized-address query cost.
- Active-warning query cost.
- Relationship traversal cost.
- Canonical location-query cost without an external map adapter.

### Exit

- Operational context accepted.
- Essential CAD location use remains available without one map provider.

## CAD Phase 11 — Production Go Service Foundation

### Goal

Establish the supported production Go runtime as a first-class accepted boundary.

### Documentation and Decisions

Freeze:

- Go module or workspace layout.
- Executables.
- Internal package boundaries.
- Domain and application packages.
- PostgreSQL adapters.
- External adapters.
- Configuration.
- Secret retrieval.
- Service identity.
- Logging.
- Metrics.
- Tracing.
- Health.
- Readiness.
- Graceful shutdown.
- Build provenance.
- Dependency update policy.
- Versioning.
- Compatibility.

### SQL

No broad new domain behavior should be mixed into this phase.

Add only database support required by the accepted service boundary.

### Go

Build the production service foundation.

It must:

- Not import `go/experiments`.
- Use least-privileged database roles.
- Invoke controlled APIs.
- Apply deadlines.
- Propagate cancellation.
- Bound pools and retries.
- Protect secrets.
- Avoid protected-data logging.
- Produce structured telemetry.
- Shut down predictably.

### Testing

Add:

- Unit tests.
- Configuration tests.
- Secret-handling tests.
- Controlled database API contract tests.
- Direct-table-access denial.
- Timeout.
- Cancellation.
- Pool exhaustion.
- Graceful shutdown.
- Health and readiness.
- Race detector.
- Retry-storm campaign proving bounded attempts, full-jitter behavior,
  current-state revalidation, technical exhaustion, and no nested retry
  amplification.
- Dependency and static analysis.
- Reproducible build verification.

### Gate

Production Go foundation acceptance gate.

### Performance

Record:

- Idle resource use.
- Startup.
- Shutdown.
- Connection establishment.
- Pool behavior.
- Health endpoint cost.
- Baseline request overhead.
- Heap.
- Allocations.
- Garbage collection.
- Goroutines.
- Descriptors.

### Exit

- Supported production Go runtime accepted.
- Historical experiments remain isolated.

## CAD Phase 12 — End-to-End Dispatcher Service Slice

### Goal

Deliver the first complete supported dispatcher workflow through Go and
PostgreSQL without yet claiming a full workstation.

### Recommended First Slice

A narrow slice should include:

- Incident queue read.
- Selected incident read.
- Unit-board read.
- Create or update one accepted incident operation.
- Assign one resource through the accepted assignment operation.
- Return exact committed and delivery states.
- Expose current alerts for the selected context.

### Documentation

Freeze API contracts and client-visible state semantics.

### SQL

Add only required read models, indexes, or controlled APIs.

### Go

Implement:

- Request validation.
- Foundation context assembly.
- Controlled operation invocation.
- Read models.
- Exact error mapping.
- Pagination.
- Freshness and version metadata.
- Idempotency.
- Telemetry.

### Testing

Add:

- API contract tests.
- Unauthorized access.
- Wrong scope.
- Stale version.
- Duplicate request.
- Cancellation.
- Partial response.
- Database unavailable.
- Outbox delayed.
- Independent service-client races.
- End-to-end exact-effect tests.

### Gate

Complete end-to-end slice gate.

### Performance

Record:

- Queue load.
- Incident selection.
- Unit-board load.
- Command round trip.
- Database contribution.
- Serialization.
- Service resource use.
- Concurrent client behavior.

### Exit

- First supported dispatcher service slice accepted.
- No user-interface production acceptance yet.

## CAD Phase 13 — External Adapters, Degraded Operation, and Reconciliation

### Goal

Prove CAD remains trustworthy when providers fail, duplicate, delay, reorder, or
recover.

### Documentation

Freeze adapter contracts for selected pilot integrations.

Define:

- Authentication.
- Contract versions.
- Ordering.
- Idempotency.
- Retry.
- Replay.
- Expiration.
- Partial failure.
- Queueing.
- Local recording limits.
- Authoritative state.
- Reconciliation.
- Conflict handling.
- Recovery completion.

### SQL

Implement required:

- Integration contract records.
- Adapter state.
- Delivery attempts.
- Replay protection.
- Reconciliation work.
- Conflict records.
- Recovery state.

### Go

Implement selected adapters and workers.

Provider-specific behavior must not enter canonical CAD domain packages.

### Testing

Use controlled simulators to prove:

- Duplicate delivery.
- Out-of-order delivery.
- Timeout.
- Retry.
- Provider rejection.
- Partial success.
- Queue persistence.
- Process restart.
- Backlog recovery.
- Reconciliation conflict.
- No local manufacture of Foundation approval, authorization, Decision Records,
  Authorization Leases, or committed CAD state.

### Gate

Integration, replay, recovery, and reconciliation gate.

### Performance

Record:

- Outbox lag.
- Queue depth.
- Retry volume.
- Replay cost.
- Backlog drainage.
- Recovery time.
- CPU and memory under provider failure.
- Database growth during degradation.

### Exit

- Selected adapter boundaries accepted.
- Provider replacement remains possible.
- Recovery completion is more than a green process check.

## CAD Phase 14 — CAD User Interface and Operational Workstation

### Goal

Deliver an accessible, resilient, role-centered dispatcher workstation over
accepted service contracts.

### Documentation

Freeze:

- Screen and logical-region contracts.
- Keyboard commands.
- Focus behavior.
- Alert presentation.
- Map and alternative list.
- Multi-monitor and supported single-monitor layouts.
- Workstation components.
- Unix-domain socket contracts.
- WebKitGTK custom-scheme containment where used.
- systemd supervision and socket activation where useful.
- Cache and spool.
- Update and rollback.
- Fault containment.
- Context restoration.
- Accessibility acceptance plan.
- Workstation performance profile.

### SQL

No direct client SQL.

Add only accepted server-side support required by the interface.

### Go

Implement workstation-facing components and local services.

Local components must not become independent authorization or canonical-state
sources.

### Testing

Add:

- Keyboard-only workflows.
- Focus stability.
- Screen-reader workflows.
- High contrast and forced colors.
- Zoom and magnification.
- Non-color meaning.
- Alert modality.
- Map/list synchronization.
- Component restart.
- Context restoration.
- Cache corruption.
- Lost service connection.
- Queued and failed action visibility.
- Single-monitor and multi-monitor profiles.
- Representative dispatcher evaluation.
- Endurance testing.

### Gate

Combined correctness, accessibility, workstation resource, and recovery gate.

Report each result separately.

### Performance

Record:

- Startup.
- Session establishment.
- Queue load.
- Incident selection.
- Unit-board update.
- Command acknowledgment.
- Alert presentation.
- Input-to-visible-response latency.
- Component CPU and memory.
- Cache and spool growth.
- Restart and restoration time.
- Long-shift endurance behavior.

### Exit

- Supported workstation workflows accepted.
- Accessibility status is explicit.
- No production pilot claim yet.

## CAD Phase 15 — Pilot, Operational Readiness, and Production Acceptance

### Goal

Prove the accepted CAD system can be deployed, operated, recovered, supported,
and governed in a representative environment.

### Documentation

Complete:

- Deployment profile.
- Network and trust boundaries.
- Secrets.
- Certificates.
- Database roles.
- Service accounts.
- Monitoring.
- Off-host logging.
- Backup.
- Restore.
- Break-glass.
- Trusted rebuild.
- Incident response.
- Continuity.
- Manual fallback.
- Reentry and reconciliation.
- Training.
- Support.
- Change management.
- Retention.
- Legal and policy review.
- Known limitations.
- Release and rollback.

### SQL and Deployment

Validate:

- Clean deployment.
- Upgrade.
- Backup.
- Restore.
- Role topology.
- Credential state.
- Least privilege.
- Break-glass disabled at rest.
- Rebuild.
- Data integrity after recovery.

### Go and Workstation

Validate:

- Signed or otherwise governed release artifacts.
- Configuration separation.
- Service supervision.
- Upgrade and rollback.
- Crash recovery.
- Workstation replacement.
- Operational telemetry.
- Support bundle protection.

### Testing

Run:

- Full regression.
- Load.
- Endurance.
- Failure injection.
- Backup and restore.
- Rebuild.
- Integration loss and recovery.
- Queue drainage.
- Security assessment.
- Accessibility acceptance.
- Representative operational exercises.
- Pilot findings and remediation.

### Gate

Production acceptance gate.

The gate must not reduce production readiness to one automated script. It should
collect and verify retained technical and operational acceptance artifacts.

### Performance

Performance thresholds may be enforced only where representative baselines and
accepted budgets exist.

Final acceptance should identify:

- Evaluated budgets.
- Unevaluated budgets.
- Exceptions.
- Capacity margin.
- Scaling triggers.
- Monitoring thresholds.
- Response procedures.

### Exit

Production acceptance requires:

- Exact accepted release.
- Exact environment profile.
- Correctness PASS.
- Required resource records.
- Complete correlated server and workstation telemetry for all mandatory
  adversarial campaigns.
- Zero unexplained telemetry loss and zero unaccounted hostile attempts.
- Zero retry attempt-budget, backoff-bound, and nested-amplification
  violations.
- Required performance budgets PASS or governed exception.
- Accessibility accepted or governed exception with remediation.
- Security and deployment controls accepted.
- Recovery accepted.
- Pilot findings resolved or governed.
- Known limitations explicit.
- Rollback available.
- Operational ownership assigned.

---

# Phase Status Rules

Each phase must use one status from the following controlled set:

```text
NOT_STARTED
DOCUMENTATION_ACTIVE
CONTRACT_CANDIDATE
IMPLEMENTATION_ACTIVE
TEST_CANDIDATE
GATE_CANDIDATE
ACCEPTED
SUPERSEDED
BLOCKED
```

A phase must not use `ACCEPTED` merely because:

- Documentation exists.
- SQL applies once.
- Go builds.
- Tests pass on one developer database.
- A UI screenshot looks correct.
- A provider integration worked once.
- Resource telemetry was collected without evaluation.
- A phase gate exists but has not passed.
- A candidate result has not received a retained acceptance record.

## Cross-Phase Regression Rule

Every later CAD phase must prove that previously accepted CAD behavior remains
unchanged unless the new phase explicitly and normatively supersedes it.

The active CAD gate should either:

- Re-run the accepted prerequisite gates, or
- Verify immutable accepted tags and exact tree parity before running the new
  boundary.

Foundation regression must remain part of CAD acceptance because CAD is a
downstream consumer of Foundation trust, approval, authorization, Decision
Record, lease, telemetry, deployment-role, and security-boundary behavior.

## Documentation Synchronization Rule

A CAD phase is not complete until all applicable items agree:

- Module README.
- CAD documentation index.
- Architecture index.
- Requirements.
- Decisions.
- Roadmap status.
- SQL manifests.
- Migrations.
- Deployment artifacts.
- Test manifests.
- Sequential tests.
- Concurrency tests.
- Go build and test inventory.
- Phase gate.
- Resource reports.
- Accessibility reports.
- Acceptance record.
- Exact counts.
- Known limitations.
- Next-step statement.

## Change-Control Rule

If implementation exposes a contradiction in an accepted architecture model:

1. Stop expansion of the affected boundary.
2. Record the contradiction.
3. Determine whether the architecture, implementation, or both are wrong.
4. Correct the controlling contract first.
5. Update tests and gate expectations.
6. Re-run the full affected regression.
7. Retain the supersession or correction history.
8. Continue only after the corrected boundary is accepted.

## Roadmap Completion

This roadmap is complete only when CAD Phase 15 is formally accepted.

Completion of one phase proves only its exact accepted boundary.

It does not prove that future phases, unimplemented workflows, external
providers, deployment environments, accessibility conditions, legal
requirements, or operating procedures are ready.
