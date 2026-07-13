# CAD Testing and Acceptance Model

> **Document status:** Normative CAD architecture
>
> **Implementation status:** Test design only

## Architecture Ownership

This document coordinates complete CAD phase acceptance.

Detailed human-interaction and accessibility evaluation is governed by the
[CAD User-Interface Architecture](user-interface/README.md). Detailed local
appliance and workstation-component resource measurement is governed by the
[CAD Operational Workstation Architecture](operational-workstation/README.md).

Correctness, accessibility, and resource observations must remain separately
reported even when one phase gate gathers all three.

## Purpose

Define how CAD changes are designed, built, tested, observed, and accepted.

Passing tests prove only the asserted behavior. They do not establish complete
production readiness.

## Definition of Progress

A material CAD change should normally include:

1. Governing architecture.
2. Stable terminology and invariants.
3. A controlled SQL, service, adapter, or interface change.
4. Authoritative manifest or build registration.
5. Clean installation or reproducible build.
6. Structural and catalog validation.
7. Privilege and security-boundary validation.
8. Positive behavior tests.
9. Repeated adversarial campaigns at every applicable prevention and enforcement layer.
10. Independent-connection hostile-concurrency campaigns when state can race.
11. Idempotency and replay tests when delivery can repeat.
12. Accessibility tests for human-facing behavior.
13. Degraded-operation and recovery tests where material.
14. Resource observation when an executable path changes.
15. Updated documentation and exact counts.
16. Static and full phase-gate validation.
17. A retained acceptance record.

## Test Categories

### Static Repository Validation

Validate:

- Required files.
- Naming.
- Manifests.
- Migration ranges.
- Documentation links.
- Exact status language.
- No forbidden placeholders or secrets.
- File hygiene.
- Generated-file policy.
- Phase counts.
- Required reason codes and operation identifiers.

### Clean Installation

Build a uniquely named disposable database and apply the authoritative
Foundation, shared-resource, and CAD manifests in dependency order.

A CAD test must not depend on a manually prepared database.

### Structural and Catalog Tests

Validate:

- Schemas.
- Tables.
- Types.
- Constraints.
- Indexes.
- Functions.
- Triggers.
- Ownership.
- Privileges.
- Security-definer properties.
- Search paths.
- Row-level security where applicable.
- Migration registry.
- Manifest registration.

### Positive Behavior

Prove authorized and valid workflows succeed with exact committed effects.

### Negative, Hostile, and Adversarial Campaign Behavior

Prove invalid, stale, replayed, unauthorized, malformed, oversized,
out-of-scope, contradictory, inconsistent, and deliberately abusive requests
fail closed without unintended side effects.

A hostile condition must not be executed only once and counted as proven.

Every applicable prevention or enforcement point must be attacked directly and
repeatedly. The test suite must not assume that one successful rejection by the
Go service proves the PostgreSQL boundary, or that one successful PostgreSQL
rejection proves the Go service.

#### Prevention and Enforcement Points

Campaigns must exercise every applicable point that can prevent, contain, or
reject an action, including:

1. Client command parsing and local input validation.
2. Go transport decoding, schema validation, size limits, and normalization.
3. Go authentication-context and authorization-context construction.
4. Go application and domain precondition checks.
5. Go idempotency, retry, timeout, cancellation, and state-version checks.
6. PostgreSQL connection role and schema privilege boundaries.
7. PostgreSQL controlled APIs.
8. PostgreSQL current-state revalidation.
9. PostgreSQL constraints, triggers, row-level security, ownership, and
   security-definer boundaries where applicable.
10. Foundation approval, authorization, Decision Record, and Authorization Lease
    validation used by CAD.
11. Transactional outbox, queue, worker, adapter, replay, and reconciliation
    boundaries.
12. Full end-to-end paths through Go and PostgreSQL.
13. Direct PostgreSQL bypass attempts that omit Go.
14. Go requests containing forged, missing, contradictory, or stale context.
15. Concurrent and reordered requests across independent connections, clients,
    workers, or processes.

The user interface is never treated as an authoritative prevention boundary.
Hiding or disabling a control is useful interaction behavior, not security
enforcement.

#### Minimum Campaign Counts

Unless a later accepted phase decision establishes a stricter requirement:

- Every defined hostile behavior class must execute at least 1,000 completed
  attempts at every applicable enforcement point during a candidate gate.
- Every high-impact protected operation must execute at least 10,000 completed
  hostile attempts at every applicable enforcement point during formal phase
  acceptance.
- Every required hostile behavior class must execute at least 10,000 completed
  attempts during formal acceptance.
- Mixed hostile-concurrency campaigns must execute enough independent attempts
  to exercise timing, ordering, retry, and winner-selection variation rather
  than repeating one fixed schedule.
- Long-running fuzz, mutation, endurance, and mixed-traffic campaigns may
  execute tens or hundreds of thousands of attempts when practical.

A phase may require larger counts based on consequence, exposed attack surface,
implementation complexity, prior defects, observed variability, or threat
assessment.

Reducing an accepted count requires a documented decision. Counts must not be
reduced merely to make a gate faster.

#### Required Hostile Classes

The matrix must include applicable permutations of:

- Unknown, disabled, expired, suspended, corrected, superseded, withdrawn, or
  revoked identities, accounts, sessions, credentials, approvals, Authority
  Grants, Authorization Leases, and protected targets.
- Wrong organization, agency, dispatch position, Governed Scope, Governed
  Purpose, Governed Operation, target, incident, unit, alert, or resource.
- Missing, forged, duplicated, contradictory, or malformed identity and
  authorization context.
- Stale policy, stale version, stale location, stale recommendation, stale
  assignment, stale alert, stale timer, and stale optimistic-concurrency state.
- Duplicate request, duplicate actor, duplicate action, duplicate delivery,
  duplicate acknowledgment, repeated idempotency key, and replayed payload.
- Oversized, truncated, invalidly encoded, unexpected-field, unknown-enum,
  boundary-value, null, empty, and structurally malformed input.
- Illegal state transitions and terminal-state modifications.
- Direct protected-table writes.
- Unauthorized function execution.
- Search-path manipulation.
- Cross-schema object substitution.
- Transaction reordering.
- Serialization failure.
- Deadlock.
- Timeout.
- Cancellation.
- Connection loss.
- Queue redelivery.
- Worker restart.
- Provider duplication or reordering.
- Partial external success.
- Recovery and reconciliation conflict.
- Attempts to convert a local record, cache entry, queued action, technical
  retry, or external acknowledgment into authoritative CAD commitment.

#### Mandatory Local Cache and Queue Authority-Misuse Campaign

Every phase that introduces or changes a local cache, workstation queue, spool,
retry buffer, offline record, service queue, transactional outbox, worker
backlog, replay mechanism, or reconciliation path must include a dedicated
high-impact authority-misuse campaign.

The campaign must attempt to use local or queued state to manufacture, imply,
promote, replay, or counterfeit:

- Approval Action Records.
- Approval stage satisfaction.
- Approval Request finalization.
- Authorization Decisions.
- Authorization Leases.
- Decision Records.
- Decision Supporting Records.
- Foundation current-state validation.
- Committed CAD incidents, assignments, alerts, acknowledgments, resolutions,
  timeline events, or other protected state.
- Successful external delivery or acknowledgment.
- Supervisory approval or operator authority.
- A technical retry outcome as a policy allow decision.
- A local record as an authoritative server commit.

This is a required hostile behavior class and a high-impact protected-operation
campaign. Therefore:

- A candidate gate must complete at least 1,000 attempts for every defined cache
  or queue misuse variant at every applicable enforcement point.
- Formal acceptance must complete at least 10,000 attempts for every high-impact
  cache or queue authority-misuse operation at every applicable enforcement
  point.
- Every required cache or queue hostile class must complete at least 10,000
  attempts during formal acceptance.

Applicable enforcement points include:

1. Workstation cache read and restore.
2. Workstation local queue or spool creation.
3. Workstation component restart and replay.
4. Unix-domain socket message submission.
5. Go client or local-service validation.
6. Go server request validation.
7. Go application and authorization-context construction.
8. Server-side queue and worker processing.
9. Transactional outbox creation and delivery.
10. PostgreSQL runtime-role privileges.
11. PostgreSQL controlled APIs.
12. PostgreSQL current-state and Foundation-context revalidation.
13. Direct PostgreSQL bypass attempts.
14. Full Go-to-PostgreSQL execution.
15. Offline recovery, conflict handling, and reconciliation.
16. Duplicate, reordered, delayed, expired, corrupted, truncated, and forged
    cache or queue records.

The campaign must include applicable attempts to:

- Edit or replace local cache files.
- Insert fabricated queue entries.
- Copy queue entries between users, workstations, organizations, incidents,
  units, sessions, or environments.
- Replay valid entries after session expiry, logout, revocation, withdrawal,
  finalization, closure, reassignment, or policy change.
- Change identifiers, timestamps, sequence values, state labels, signatures,
  hashes, version fields, authorization context, organization, scope, purpose,
  operation, target, or actor.
- Reorder, duplicate, omit, truncate, or concatenate queued records.
- Submit a locally recorded action directly to a lower layer.
- Restart a workstation component or worker between validation and commit.
- Restore a stale snapshot after authoritative state changed.
- Convert provider acknowledgment into CAD commitment.
- Convert technical retry, timeout, deadlock, serialization failure, or network
  loss into an allowed or committed result.
- Bypass Go and invoke PostgreSQL directly with the runtime identity.
- Cause one user's or workstation's local state to affect another protected
  context.
- Exhaust queue capacity, disk capacity, memory, file descriptors, connections,
  or worker concurrency while preserving fail-closed authority behavior.

For every attempt or reproducible bounded batch, tests must prove:

- No Foundation record or state was manufactured.
- No CAD protected state was committed.
- No unauthorized outbox or external delivery was created.
- No local state was promoted without a fresh authoritative decision.
- No stale authorization context was accepted.
- No cross-user, cross-workstation, cross-organization, cross-scope, or
  cross-incident effect occurred.
- Rejected or quarantined entries remained distinguishable from committed work.
- Recovery and reconciliation preserved the original hostile input, reason,
  disposition, and resulting authoritative state for review without executing
  the prohibited effect.

#### Direct-Layer and Bypass Proof

For an operation protected by both Go and PostgreSQL, the campaign must include:

- Direct Go tests proving malformed or unauthorized requests are rejected before
  database invocation when Go owns that check.
- Instrumentation or test assertions proving PostgreSQL was not invoked when
  rejection should occur in Go.
- Direct PostgreSQL tests using the runtime role or a deliberately constrained
  test role to prove the database independently rejects bypass attempts.
- Full-stack tests proving validly formed but unauthorized requests cannot pass
  through Go to create a database effect.
- Full-stack tests proving a defect or omission in one non-authoritative layer
  does not create an unrestricted path around the authoritative database
  boundary.
- Privilege tests proving the Go runtime identity cannot replace controlled APIs
  with direct writes.

Checks may intentionally exist in more than one layer, but each duplicate check
must have a defined purpose. Duplicate validation must not create contradictory
rules or inconsistent error semantics.

#### Side-Effect Verification

A rejection is not sufficient unless the run proves the request caused no
unintended effect.

Applicable assertions include:

- No protected row inserted, updated, or deleted.
- No impossible current projection.
- No unauthorized timeline or audit entry.
- No Decision Record, Authorization Lease, approval, or finalization fabricated.
- No outbox or delivery record created.
- No unit assignment changed.
- No alert acknowledged or resolved.
- No timer reset.
- No cache or queue state promoted to authoritative state.
- No privilege, ownership, or session state changed.
- No external message sent.
- No hidden partial transaction committed.

Side-effect checks may be performed after every attempt or after bounded batches
when the batch method can still identify the exact failing seed and request.

#### Determinism and Reproduction

Every campaign must retain:

- Campaign identifier.
- Threat-model or hostile-class identifier.
- Operation and enforcement point.
- Configured count.
- Generated count.
- Attempted count.
- Completed count.
- Expected-rejection count.
- Technical-retry count.
- Unexpected-success count.
- Unintended-side-effect count.
- Seed or seed range.
- Generator version.
- Corpus version.
- Environment fingerprint.
- First failing case.
- Minimal reproducible case when reduction is supported.
- Duration and resource observations.

Randomized testing must use retained seeds so a failure can be reproduced.
A stable regression corpus should retain every previously discovered malicious
or malformed case.

#### Acceptance Rule

Any unexpected success or unintended side effect is a correctness failure.

A serialization failure, deadlock, timeout, cancellation, or connection loss is
not automatically a successful security rejection. The test must classify the
technical outcome and prove that retry or failure handling did not create an
unauthorized effect.

These campaigns provide strong, repeatable evidence of sustained adversarial
resistance within the defined threat model and tested environments. No finite
campaign can honestly prove prevention of every possible malicious technique.

### Concurrency

Use real independent database connections, service clients, workers, or
processes. Concurrency-sensitive hostile conditions must be repeated as
campaigns rather than executed as one fixed race.

Expected race tests include:

- Concurrent incident-number allocation.
- Concurrent unit assignment.
- Assignment racing unit unavailability.
- Concurrent alert acknowledgment.
- Concurrent incident transfer.
- Closure racing a new operational event.
- Correction racing another correction.
- Recommendation expiration during commit.
- Duplicate inbound delivery.
- Offline reconciliation conflict.

### State-Machine Tests

Prove:

- Allowed transitions.
- Denied transitions.
- Terminal behavior.
- Reopening behavior.
- Correction and supersession.
- No impossible current projection.

### Integration Contract Tests

Use provider simulators or controlled test doubles to prove:

- Authentication.
- Contract version handling.
- Duplicate detection.
- Idempotency.
- Timeout.
- Retry.
- Replay.
- Ordering.
- Partial failure.
- Queue recovery.
- Replacement-adapter compatibility.


### Foundation Approval and Authorization Integration

CAD tests that use Foundation approval or authorization must prove:

- Approval Action recording, stage satisfaction, Approval Request finalization, Authorization Decision, Authorization Lease, and CAD commit remain distinct.
- Withdrawn, corrected, superseded, expired, suspended, or revoked state fails closed at later use.
- Authority Grant revocation invalidates the affected path.
- Duplicate-actor, duplicate-action, finalization, withdrawal, revocation, and reciprocal-approval races preserve the Phase 4 Step 7 contract.
- Serialization and deadlock results remain bounded retryable technical
  outcomes rather than policy denials, subject to the retry contract below.
- A local cache or queue cannot manufacture Approval Action Records, Approval Request finalization, Authorization Decisions, Authorization Leases, Decision Records, or committed CAD state.
- Every applicable Foundation-dependent denial is exercised repeatedly through direct PostgreSQL, direct Go, and full-stack adversarial campaigns.

### Bounded Serialization and Deadlock Retry Contract

Serialization and deadlock outcomes are technical concurrency outcomes.

They are not:

- Policy denials.
- Authorization denials.
- Approval denials.
- Successful approvals.
- Successful Authorization Decisions.
- Successful CAD commits.
- Proof that the request is safe to retry after an external side effect.

#### Attempt Budget

For a retry-enabled protected operation:

- The maximum total attempt count is 11.
- The total attempt count includes the initial execution.
- Therefore, no operation may perform more than 10 retry executions after the
  initial attempt.
- A production operation must select an accepted maximum between 5 and 11 total
  attempts.
- Cancellation, deadline expiry, shutdown, revoked authority, stale state,
  non-retryable error, or successful commit may end the sequence before the
  configured maximum.
- Retry exhaustion produces a distinct technical outcome such as
  `RETRY_EXHAUSTED`.
- Retry exhaustion is not converted into a policy denial or a successful
  operation.

A retry loop must never be unbounded.

#### Single Retry Owner

Every protected operation must identify one retry owner.

The retry owner may be the Go application boundary, a controlled worker, or
another explicitly accepted execution boundary.

Nested retry loops must not multiply the attempt budget.

For example, an 11-attempt Go loop must not invoke an independent 11-attempt
database wrapper or worker loop and thereby produce 121 executions.

The end-to-end operation must retain one:

- Retry sequence identifier.
- Attempt budget.
- Attempt counter.
- Deadline.
- Idempotency context.
- Cancellation context.
- Correlation context.

Lower layers may report retryable technical outcomes, but they must not silently
create a second independent retry budget.

#### Eligible Outcomes

Automatic retry is allowed only for explicitly classified transient
serialization or deadlock outcomes covered by the accepted operation contract.

Automatic retry must not be used for:

- Authentication failure.
- Authorization denial.
- Approval denial.
- Missing approval.
- Expired, suspended, withdrawn, corrected, superseded, or revoked state.
- Invalid or stale Authorization Lease.
- Invalid Decision Record context.
- Wrong organization, scope, purpose, operation, target, incident, unit, or
  resource.
- Validation failure.
- Malformed input.
- Unsupported version.
- Illegal state transition.
- Constraint violation that represents a durable business conflict.
- Direct privilege denial.
- Queue or cache authority-misuse rejection.
- External provider rejection.
- Unknown failure without an accepted retry classification.

#### Fresh Transaction and Revalidation

Every retry attempt must:

1. Begin a new database transaction.
2. Re-read the authoritative current state needed by the operation.
3. Revalidate the current Foundation approval and authorization context.
4. Revalidate the Authorization Lease when one is required.
5. Revalidate operation-specific preconditions and state versions.
6. Reuse the same end-to-end idempotency identity where repetition must have one
   effect.
7. Avoid reusing transaction-local observations as though they remained current.
8. Stop immediately when the request is no longer authorized or valid.
9. Preserve one authoritative committed outcome.

A retry must not reuse a previously allowed decision as proof that the new
transaction is still authorized.

#### Exponential Backoff with Full Jitter

The accepted retry family is:

- Total attempts: 5 through 11, including the initial attempt.
- Initial backoff interval: 50 through 100 milliseconds.
- Backoff multiplier: `2.0`.
- Maximum backoff cap: 1 through 2 seconds.
- Jitter: full randomization.

For retry number `r`, where `r = 1` is the first retry after the initial
attempt:

```text
calculated_cap_r =
    min(maximum_backoff_cap,
        initial_backoff_interval * 2^(r - 1))

actual_sleep_r =
    uniform_random_duration(0, calculated_cap_r)
```

The initial backoff interval and maximum cap are accepted configuration values
for an operation or workload profile. Stress testing must cover the allowed
range rather than testing only one convenient value.

The selected delay and actual randomized sleep must be observable and
reproducible from retained test data or a retained random seed.

#### Deadline and Side-Effect Rules

The operation deadline remains authoritative over the retry budget.

The retry owner must stop when there is insufficient time to perform another
safe attempt and return a technical timeout or retry-exhaustion outcome.

An operation must not be automatically retried after an irreversible or
externally visible side effect unless the operation uses an accepted
idempotency, outbox, or reconciliation contract that proves repetition cannot
create duplicate or unauthorized effect.

#### Mandatory Retry-Storm Campaign

Every phase that introduces or changes a retry-enabled operation must include a
retry-storm campaign.

The campaign is a required hostile behavior class and must satisfy the general
CAD campaign minimums:

- Candidate gate: at least 1,000 completed attempts per retry-storm hostile
  class at every applicable enforcement point.
- Formal acceptance: at least 10,000 completed hostile attempts per high-impact
  retry-enabled operation at every applicable enforcement point.
- Every required retry-storm hostile class: at least 10,000 completed attempts
  during formal acceptance.

The campaign must sweep:

- Maximum total attempts from 5 through 11.
- Initial backoff intervals from 50 through 100 milliseconds.
- Maximum backoff caps from 1 through 2 seconds.
- Full-jitter seeds and timing distributions.
- Varying independent client, connection, worker, process, and workstation
  counts.
- Serialization-heavy contention.
- Deadlock-heavy contention.
- Mixed serialization and deadlock outcomes.
- Success on early, middle, and final allowed attempts.
- Exhaustion at every configured maximum.
- Cancellation during backoff.
- Deadline expiry during backoff.
- Shutdown and restart during a retry sequence.
- Authorization or Approval state changing between attempts.
- Authorization Lease expiry or revocation between attempts.
- Incident, unit, assignment, alert, or other CAD state changing between
  attempts.
- Queue, worker, cache, outbox, and reconciliation interaction.
- Direct PostgreSQL execution and full Go-to-PostgreSQL execution.
- Slow database, pool exhaustion, socket pressure, CPU pressure, memory
  pressure, disk pressure, and network degradation where applicable.

The campaign must prove:

- No operation exceeds 11 total attempts.
- The configured total includes the initial execution.
- No nested layer multiplies the retry budget.
- Only eligible technical outcomes are retried.
- Policy denials and revoked or stale state stop the sequence.
- Every attempt uses a fresh transaction and current-state revalidation.
- Backoff doubles before capping.
- Every actual sleep is within the full-jitter range from zero through the
  calculated cap.
- The maximum cap is never exceeded.
- Retry exhaustion is returned as a technical outcome.
- One successful commit produces one effect.
- Duplicate external delivery does not occur.
- No Foundation or CAD authority is manufactured.
- No unauthorized partial transaction or side effect survives.
- Cancellation, shutdown, and deadline handling do not create hidden retries.
- A retry storm does not cause an unbounded goroutine, thread, connection,
  queue, descriptor, memory, disk, or workstation-resource increase.
- Recovery drains or terminates retry work predictably.

#### Retry-Storm Telemetry

Every retry-enabled attempt must record or correlate:

- Retry sequence identifier.
- Operation and protected target.
- Retry owner.
- Configured maximum total attempts.
- Current total attempt number.
- Retry number.
- Eligible technical outcome.
- Database outcome classification.
- Initial backoff interval.
- Backoff multiplier.
- Calculated backoff cap.
- Configured maximum cap.
- Actual jittered sleep.
- Cumulative backoff time.
- Attempt start and completion time.
- Transaction identifier where safely available.
- Connection and pool state.
- Lock and wait context.
- Deadline remaining.
- Cancellation state.
- Idempotency identity.
- Authorization, Approval, Lease, policy, and state versions or safe
  fingerprints.
- Commit, technical retry, retry exhaustion, timeout, cancellation, denial, and
  unexpected-result counters.
- Server and workstation resource telemetry required by this model.

Aggregate retry-storm artifacts must include:

- Retry sequences started.
- Attempts by ordinal position.
- Serialization outcomes.
- Deadlock outcomes.
- Successful commits by attempt number.
- Exhausted sequences.
- Cancelled sequences.
- Timed-out sequences.
- Denials discovered during revalidation.
- Maximum observed attempts.
- Backoff minimum, maximum, average, and percentiles.
- Actual-sleep distribution.
- Contention, lock-wait, pool-wait, queue-depth, CPU, memory, disk, network, and
  workstation-impact time series.
- Unexpected success.
- Unintended side effect.
- Attempt-budget violation.
- Backoff-bound violation.
- Nested-retry amplification.

Formal acceptance requires zero:

- Attempt-budget violations.
- Backoff-bound violations.
- Nested-retry amplification events.
- Unexpected successes.
- Unintended side effects.
- Manufactured authority or committed state.

### Accessibility Tests

Human-facing CAD acceptance requires applicable:

- Automated checks.
- Keyboard-only testing.
- Focus testing.
- Screen-reader testing.
- High-contrast and forced-color testing.
- Zoom and magnification testing.
- Non-color meaning.
- Multi-modal alert testing.
- Map alternative testing.
- Timer and queue testing.
- Degraded-operation testing.
- Representative operational user evaluation.

A clean automated scan is not accessibility acceptance.

### Mandatory Server and Workstation Telemetry

Correctness, adversarial outcomes, resource telemetry, and performance
evaluation must remain separate result dimensions.

Every candidate and formal-acceptance adversarial campaign must record
correlated telemetry for every participating server, database, Go process,
worker, adapter, workstation, and workstation component.

Telemetry collection must begin before the campaign, continue throughout the
campaign, and capture a post-campaign recovery interval. Averages alone are not
sufficient. The run must retain totals, rates, minimums, maximums, percentiles,
peaks, time series where available, and pre-run and post-run state.

#### Correlation and Run Identity

Record:

- Run, phase, campaign, hostile-class, operation, enforcement-point, process,
  host, workstation, and environment identifiers.
- Attempt and bounded-batch identifiers.
- Wall-clock and monotonic timestamps.
- Time-zone and clock-synchronization state.
- Seed or seed range.
- Generator and corpus version.
- Software revision, build identity, configuration revision, and schema
  migration inventory.
- Host, operating system, kernel, architecture, virtualization, container,
  cgroup, PostgreSQL, Go, GTK, WebKitGTK, and workstation-profile fingerprints
  where applicable.

#### Server Host Telemetry

Record applicable:

- CPU user, system, idle, I/O wait, steal, per-core utilization, load average,
  scheduling pressure, frequency, thermal state, and throttling.
- Physical memory, resident memory, cache, buffers, swap, page faults, pressure,
  allocation failures, and out-of-memory events.
- Disk and filesystem read and write operations, bytes, latency, queue depth,
  utilization, flushes, free space, inode use, filesystem errors, and storage
  pressure.
- Network bytes, packets, connections, connection attempts, errors, drops,
  retransmissions, resets, socket backlog, latency, and interface state.
- Process, thread, child-process, open-file, socket, and file-descriptor counts.
- cgroup or service limits and throttling.
- systemd state, activation, restart, failure, watchdog, and dependency events.
- Kernel and service faults relevant to the run.

#### PostgreSQL Telemetry

Record applicable:

- Connections by role, database, state, and wait event.
- Connection acquisition and authentication failures.
- Transactions, commits, rollbacks, serialization failures, deadlocks, and
  cancelled statements.
- Statement and controlled-operation count, latency, rows, plans, and errors.
- Locks, wait events, blocking chains, and long transactions.
- Shared-buffer hits, reads, dirtied blocks, writes, checkpoints, background
  writer activity, and temporary files.
- WAL records, full-page images, bytes, flush behavior, archive or replication
  lag where applicable.
- Database, schema, table, index, toast, and temporary size and growth.
- Tuple insert, update, delete, fetch, scan, and vacuum or analyze activity.
- Index use and sequential-scan activity.
- Function execution counts and failures where safely measurable.
- Runtime-role direct-write attempts, controlled-API denials, privilege denials,
  and current-state revalidation failures.
- Counts proving that rejected Go-owned requests did or did not reach
  PostgreSQL as expected.

#### Go Service and Worker Telemetry

Record applicable:

- Request, operation, result, denial-reason, technical-retry, and error counts.
- End-to-end, handler, authorization, database, queue, adapter, and external
  call latency.
- Database-pool open, in-use, idle, wait count, wait duration, max-open, and
  connection lifetime behavior.
- CPU, resident memory, heap, stack, allocations, allocation rate, garbage
  collection count and pause, goroutines, operating-system threads, and open
  descriptors.
- Queue and outbox depth, oldest-item age, enqueue, dequeue, retry, replay,
  quarantine, expiration, reconciliation, and drainage rates.
- Timeout, cancellation, retry, circuit-breaker, backoff, panic, crash, restart,
  health, readiness, and graceful-shutdown behavior.
- IPC, socket, message-size, decode, validation, and authorization failures.
- Adapter and provider request, response, duplicate, reordering, partial
  failure, and acknowledgment counts.
- Unexpected-success and unintended-side-effect counters by enforcement point.
- Retry sequences, attempt ordinals, retry ownership, configured budgets,
  serialization and deadlock classifications, calculated caps, actual
  jittered sleeps, cumulative wait, exhaustion, cancellation, timeout, and
  amplification counters.

#### Workstation Host and Component Telemetry

Record applicable:

- Workstation CPU, per-component CPU, load, scheduling pressure, frequency,
  thermal state, and throttling.
- Physical memory, per-component resident memory, heap where applicable, cache,
  swap, page faults, pressure, and out-of-memory events.
- Disk and filesystem I/O, latency, utilization, free space, inode use, cache
  size, spool size, queue size, oldest queued-item age, and growth.
- Network throughput, latency, connection establishment, drops, retransmissions,
  disconnects, reconnects, and service reachability.
- Workstation component process, thread, child-process, descriptor, socket, and
  restart counts.
- systemd service and socket activation, watchdog, dependency, restart, and
  failure state.
- Unix-domain socket connection, queue, message, error, rejection, latency, and
  backpressure behavior.
- GTK and WebKitGTK process CPU, memory, process count, crash, restart, and
  content-process behavior.
- Graphics or GPU utilization, memory, frame timing, render stalls, and display
  errors where available and relevant.
- Display count, resolution, scaling, refresh, layout, and active accessibility
  preference profile.
- Startup, login, session establishment, queue load, incident selection,
  unit-board refresh, command acknowledgment, alert presentation,
  input-to-visible-response, map update, alternative-list update, focus change,
  programmatic announcement, and recovery latency.
- Event-loop stalls, dropped or coalesced updates, stale-data age, cache hit and
  miss, cache invalidation, local-record creation, replay, quarantine,
  reconciliation, and context-restoration behavior.
- Keyboard, pointer, assistive-technology, high-contrast, zoom, reduced-motion,
  audible-alert, and non-audible-alert path activity where measurable without
  collecting protected user content.
- Local cache or queue tampering, fabrication, replay, cross-context copy,
  rejection, quarantine, deletion, retention, and attempted promotion counts.
- Counts proving no local cache, queue, or spool manufactured Foundation records,
  Authorization Decisions, Authorization Leases, Decision Records, approvals,
  or committed CAD state.
- Workstation-originated retry sequence, attempt, backoff, jitter, IPC,
  disconnect, reconnect, cancellation, deadline, queue, and recovery impact.

#### Telemetry Safety and Completeness

Telemetry must not:

- Contain authentication secrets, private keys, session tokens, raw protected
  content, or unnecessary caller, patient, personnel, criminal-justice, or
  premise information.
- Become a hidden authorization or commitment source.
- Change the outcome being measured beyond documented instrumentation overhead.
- Collapse policy denials and technical failures into one counter.

Required telemetry loss, missing correlation, unreadable artifacts, unknown
environment fingerprints, or unaccounted campaign attempts are gate failures.

The gate must report telemetry completeness for each participating server and
workstation. Formal acceptance requires complete mandatory telemetry for the
accepted workload and environment, with any unsupported metric explicitly
identified, justified, and governed.

Resource observations begin as observation-only data.

Performance thresholds become pass or fail criteria only after representative,
same-environment runs establish governed budgets.

## Test Data

Tests must use synthetic data.

Real caller, patient, criminal-justice, protected-person, personnel, or premise
data must not be copied into disposable test environments without explicit
authorization and protection.

## Result Artifacts

A CAD test run should eventually retain:

- Complete log.
- Compact correctness summary.
- Machine-readable result.
- Adversarial campaign summary and per-layer matrix.
- Reproducible seeds and retained hostile corpus.
- Unexpected-success and unintended-side-effect counters.
- Resource observation text.
- Resource observation JSON.
- Correlated server telemetry time series and summary.
- Correlated workstation and workstation-component telemetry time series and
  summary.
- PostgreSQL, Go runtime, queue, outbox, IPC, cache, spool, and adapter
  telemetry artifacts.
- Telemetry completeness and unsupported-metric report.
- Retry-storm sequence ledger, backoff distribution, amplification report,
  and attempt-budget compliance report.
- Environment fingerprint.
- Failed database or service state when needed for investigation.
- Phase-gate result.
- Acceptance record reference.

## Acceptance

A CAD phase is accepted only when:

- Its exact scope is stated.
- Required tests and adversarial campaign counts pass.
- Unexpected-success count is zero.
- Unintended-side-effect count is zero.
- Warnings are understood and documented.
- Resource observation status is explicit.
- Mandatory server and workstation telemetry is complete and correlated.
- Required telemetry loss or unexplained missing metrics equals zero.
- Retry attempt-budget, backoff-bound, and nested-amplification violations
  equal zero.
- Accessibility status is explicit.
- Unimplemented controls are listed.
- Counts are synchronized.
- The next boundary is stated.
- The acceptance record is retained.
