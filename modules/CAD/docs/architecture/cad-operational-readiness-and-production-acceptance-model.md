# CAD Operational Readiness and Production Acceptance Model

> **Owner:** Iron Signal Systems
>
> **Module:** Computer Aided Dispatch
>
> **Document status:** Normative CAD architecture
>
> **Implementation status:** Acceptance contract only; no production-readiness
> claim is established by this document

## Architecture Ownership

This document is authoritative for CAD pre-production qualification,
availability, high availability, failover, capacity margin, operational burn-in,
pilot entry, and production acceptance.

The [CAD Testing and Acceptance Model](cad-testing-and-acceptance-model.md) is
authoritative for correctness, hostile testing, failure classification,
telemetry, and evidence requirements.

The [CAD Phased Development Roadmap](cad-phased-implementation-plan.md) is
authoritative for phase order and entry or exit dependencies.

Platform-wide release integrity is governed by the
[Software Supply-Chain and Release-Integrity Model](../../../../docs/architecture/software-supply-chain-and-release-integrity-model.md).
Independent verification and acceptance authority are governed by the
[Verification, Validation, and Acceptance-Governance Model](../../../../docs/architecture/verification-validation-and-acceptance-governance-model.md).

Installed package, `/etc`, host, and runtime integrity are governed by the
[Host Software, Configuration, and Runtime-Integrity Model](../../../../docs/architecture/host-software-configuration-and-runtime-integrity-model.md).

## Purpose

Define the minimum evidence required before an Iron Signal CAD deployment may
advance from engineering acceptance into pilot or production use.

A system is not production-ready merely because:

- It starts successfully.
- A demonstration completes.
- Individual tests pass.
- A failover occurs once.
- An uptime dashboard reports a favorable percentage.
- A monitoring system remains green.
- A provider acknowledges a message.

Production readiness requires sustained correct service, preserved authority,
measured capacity margin, repeatable recovery, bounded degradation, complete
telemetry, accepted release provenance, trained operational ownership, and a
retained acceptance decision.

## Controlled Terms

### Availability-Qualification Environment

A representative pre-production environment used to establish availability,
failover, recovery, capacity, and operational-readiness evidence.

It must preserve the production topology, trust boundaries, runtime identities,
HA control plane, database replication mode, queue and outbox behavior,
workstation communication path, telemetry path, and deployment process.
Capacity may be scaled only when the scaling relationship and resulting limits
are documented and accepted.

Ordinary disposable developer and test environments are not required to remain
available continuously. However, no CAD deployment may enter pilot or
production until the availability-qualification environment passes this model.

### Critical Service Path

A complete operator-visible or machine-controlled path required for safe CAD
operation. At minimum, the accepted deployment profile must identify:

- Session establishment and renewal.
- Incident queue read.
- Selected incident read.
- Incident creation and accepted update operations.
- Unit-board read.
- Protected assignment commit.
- Alert presentation and acknowledgment.
- Authoritative timeline read.
- Current delivery and reconciliation state.
- Health and degraded-state visibility.

### Qualifying Unavailability

Time during which a critical service path:

- Cannot complete within its accepted hard deadline.
- Returns an incorrect, stale-success, unauthorized, contradictory, or
  unprovable result.
- Cannot determine whether an operation committed.
- Cannot preserve required authority or current-state validation.
- Depends on a failed hidden component without presenting the accepted degraded
  state.
- Lacks the telemetry needed to establish its actual condition.

An incorrect success is unavailability even when the transport returned a
successful status.

### Acknowledged Commit

A protected CAD transaction for which the authoritative database returned the
accepted committed outcome through the controlled operation contract.

An external provider acknowledgment, workstation queue entry, local cache
record, or retry result is not an acknowledged CAD commit.

## Pre-Production Availability Gate

### Required Threshold

Before pilot or production entry, every required critical service path and the
aggregate critical CAD service must demonstrate:

```text
MEASURED_AVAILABILITY >= 99.99 percent
```

The minimum measurement window is **30 consecutive calendar days** in the
availability-qualification environment.

For a 30-day window, 99.99 percent permits no more than approximately:

```text
259.2 seconds
4 minutes 19.2 seconds
```

of total qualifying unavailability.

A deployment that measures less than 99.99 percent must not advance. Rounding
must not turn a failing result into a pass.

### Calculation

```text
availability =
  (eligible_observation_time - qualifying_unavailability_time)
  / eligible_observation_time
```

The acceptance artifact must retain the exact numerator, denominator, outage
intervals, event identifiers, probe evidence, service logs, and classification
for every unavailable interval.

### Measurement Rules

- Critical synthetic transactions must run from at least two independent
  observers or test agents.
- Probe frequency must be five seconds or less for critical service paths.
- An outage interval begins conservatively at the first failed or invalid
  observation after the last known good result.
- An outage interval ends only when the critical path returns a correct result
  and required reconciliation is complete.
- A transport-level success with an incorrect, stale, duplicated, unauthorized,
  or uncertain authoritative result counts as unavailable.
- Missing mandatory telemetry invalidates the affected interval. When service
  continuity cannot be independently proved, the interval counts as
  unavailable.
- Planned rolling maintenance remains inside the measurement window and must
  preserve service. Maintenance that interrupts a critical path counts as
  unavailability.
- A test-environment reset, topology change, or evidence gap restarts the
  30-day qualification window unless the acceptance authority determines that
  the prior evidence remains valid and records why.
- Each critical path must pass individually. A high aggregate result must not
  conceal failure of one essential operation.

### Automatic Availability Failures

The availability percentage cannot compensate for any of the following:

- Loss of an acknowledged commit.
- Split-brain or simultaneous authoritative writers.
- Unauthorized or manufactured authority.
- Unauthorized committed CAD state.
- Stale-success or false-commit response.
- Unreconciled uncertain outcome beyond the accepted recovery deadline.
- Corruption of authoritative state.
- Failure to fence an unsafe former primary.
- Required audit, Decision Record, or operational-history loss.
- Critical telemetry loss that prevents determination of authoritative state.
- An unresolved severity-one or severity-two failure.

Any such result fails the qualification window and requires a new window after
remediation and regression acceptance.

## High-Availability Architecture Contract

### Production Minimum

The production deployment profile must not contain an undocumented single
component whose ordinary failure disables every critical service path.

At minimum, the profile must define redundancy and failure behavior for:

- Authoritative PostgreSQL service.
- Quorum, witness, or other decision mechanism.
- Fencing or equivalent split-brain prevention.
- Go service instances.
- Service discovery, routing, or ordered endpoint selection.
- Transactional outbox, queue, and worker execution.
- Workstation reconnection and current-state refresh.
- Identity, authorization, certificate, and secret dependencies.
- Monitoring, alerting, and off-host evidence retention.
- Time synchronization.
- Network paths and power dependencies.
- Backup and trusted rebuild capability.

Backups are recovery controls. They are not high availability.

### Database Safety

The accepted HA profile must prove:

- At most one authoritative writer is accepted.
- Quorum loss fails safe.
- The former primary is fenced, isolated, or otherwise prevented from
  accepting protected writes before replacement authority is established.
- An acknowledged protected transaction has an accepted recovery-point
  objective of zero data loss.
- Replication lag is measured and bounded.
- Read-only or degraded behavior is explicit when safe write authority cannot
  be established.
- Automatic failback, priority-based preemption, and role rebalancing are
  prohibited.
- A recovered former primary must not reclaim authority merely because it has
  returned, has a preferred location, has higher configured priority, or appears
  healthier than the current authoritative writer.
- A planned authoritative role transition uses the same integrity,
  availability, fencing, and evidence requirements as failover.

### Stable-Primary and Anti-Oscillation Contract

HA must prefer stable authority over topology symmetry. After an accepted
promotion, the newly promoted writer remains authoritative while it is healthy
and retains quorum, regardless of whether the former primary later recovers.

The accepted HA profile must enforce all of the following:

- One causal failure incident may produce no more than one automatic
  authoritative promotion.
- Promotion uses a monotonically increasing authority epoch, timeline, term, or
  equivalent token that an older primary cannot reuse.
- The former primary remains fenced until its process state, storage state,
  timeline, replication position, and authority token have been verified.
- A recovered former primary rejoins only as a non-authoritative secondary. It
  must complete full resynchronization and integrity validation before becoming
  eligible for any later promotion.
- Recovery of a former primary never initiates automatic failback.
- The current healthy primary is not demoted merely to restore a preferred node,
  site, or original topology.
- Health hysteresis, hold-down, and cooldown controls prevent transient network,
  process, storage, or monitoring flaps from repeatedly changing authority.
- After any promotion, the topology enters a stabilization period of at least
  30 consecutive minutes. During that period, nonessential role transitions
  are prohibited.
- A planned database role transition may occur only after the incident is
  closed, the topology has remained healthy for the stabilization period, the
  intended candidate is fully synchronized, preflight checks pass, and an
  authorized operator approves the transition.
- If the newly promoted primary independently fails, that is a new failure
  incident. Another promotion may occur only to an independently qualified and
  currently eligible secondary; the system must not blindly bounce authority
  back to the former primary.
- Two or more unplanned authoritative promotions within any rolling 15-minute
  interval place the HA system in `HA_UNSTABLE` state, trigger immediate
  operational escalation, and prohibit optional rebalancing or maintenance
  transitions until the cause is resolved.
- A repeated promotion attributable to one causal incident, an automatic
  failback, or authority oscillation is a qualification failure.

Distinct injected failures used to satisfy campaign counts must be separated by
an accepted stable-state checkpoint. Repeated failover/failback oscillation may
not be counted as multiple completed events.

### Service and Workstation Safety

The accepted HA profile must prove:

- Go services are replaceable and do not retain hidden authoritative state.
- In-flight requests preserve one idempotency and retry identity.
- A workstation reconnect does not convert local state into CAD authority.
- Current state is reread after failover.
- Stale sessions, approvals, leases, and policy state are revalidated.
- Queue and outbox replay preserves ordering, duplication, expiration, and
  authorization rules.
- The dispatcher can distinguish unavailable, degraded, reconnecting,
  uncertain, queued, failed, and committed states.
- Alerting and accessibility paths continue or expose an explicit accepted
  degraded mode.

## Failover Thresholds

Unless a stricter deployment profile is accepted, production qualification must
use both an engineering goal and a maximum acceptable threshold from the
beginning of an injected or actual failure:

| Measure | Engineering goal | Maximum acceptable |
|---|---:|---:|
| Failure detection | 5 seconds | 10 seconds |
| Quorum decision and unsafe-primary fencing | 10 seconds | 20 seconds |
| Critical read path restored | 15 seconds | 30 seconds |
| Replacement authoritative writer ready | 30 seconds | 45 seconds |
| Critical protected write path restored | 30 seconds | 60 seconds |
| In-flight uncertain outcome reconciled | 45 seconds | 60 seconds |
| Workstation current-state refresh and operational reconciliation | 60 seconds | 90 seconds |
| Nominal-load queue age returned to its pre-failure budget | 2 minutes | 5 minutes |
| Accepted-peak queue age returned to its pre-failure budget | 15 minutes | 15 minutes |

The maximum acceptable value is a hard event limit. Any event that exceeds it is
classified as a qualification failure even when service eventually recovers.
Availability impact continues to accrue independently.

The engineering goal is the normal design and operating target. Formal
qualification must report goal attainment separately for every failure class,
topology, workload band, and recovery stage. For each class with enough events
to support percentile reporting, the 95th percentile must meet the engineering
goal. A class that remains within the maximum acceptable limit but misses its
goal requires documented root-cause analysis, trend review, and remediation or
a time-bounded acceptance exception before production recommendation.

Averages must not hide individual near-limit or maximum-limit events. Reports
must retain the minimum, median, 95th percentile, 99th percentile where the
sample size supports it, maximum, and complete event distribution.

The timer begins at the first independently observable loss or unsafe condition,
not when an operator notices it or when automation chooses to start a timer.

## Production-Stability Capacity Threshold

### Normal Peak

At the accepted representative peak workload, normal healthy topology must
retain:

- At least 35 percent headroom for each identified critical bottleneck.
- No critical CPU, memory, connection-pool, worker-pool, storage, or network
  resource sustained above 65 percent of its accepted usable capacity at the
  95th percentile.
- At least 20 percent free usable storage in every critical writable tier.
- No swap thrashing, out-of-memory event, uncontrolled garbage-collection
  pause, descriptor exhaustion, or connection starvation.
- Latency within every accepted critical-path budget.
- Non-growing queues after ordinary bursts.

### One-Failure Degraded Topology

After loss of any one protected component or failure domain, the remaining
system must sustain **125 percent of the accepted representative peak workload
for at least 60 consecutive minutes** while meeting:

- No critical resource sustained above 80 percent of accepted usable capacity
  at the 95th percentile.
- No critical resource above 90 percent for more than 60 consecutive seconds.
- No hard operation deadline violation.
- Critical-path 99th-percentile latency no greater than twice the accepted
  normal-peak budget.
- No unbounded queue, retry, memory, goroutine, thread, descriptor, connection,
  disk, or WAL growth.
- Queue growth becomes non-positive after failover recovery.
- All backlogs return to the accepted pre-failure budget within the required
  drainage threshold.
- No reduction in authorization, audit, integrity, accessibility, or telemetry
  enforcement.

A production deployment must not depend on emergency capacity that has never
been demonstrated under the accepted failure topology.

## Mandatory Failover and Fault Campaign

Formal HA qualification must include at least:

| Failure class | Minimum completed events |
|---|---:|
| Planned service-instance switchover | 100 |
| Unplanned Go service process loss | 1,000 |
| Database primary process loss | 100 |
| Database primary host loss | 25 |
| Replication interruption and recovery | 100 |
| Quorum or witness loss | 25 |
| Network partition affecting the primary | 25 |
| Queue or worker failure during protected work | 100 |
| Workstation disconnect and reconnect | 1,000 |
| Failover during retry, cancellation, and deadline pressure | 100 |
| Failover during representative hostile and stress traffic | 25 |
| Operator-authorized planned database role transition | 25 |

Counts are minimum endurance floors. The campaign must also vary state,
workload, concurrency, timing, active operation, transaction phase, queue depth,
replication state, and failure duration.

Each completed database-authority event must begin from an accepted stable
checkpoint and end only after the promoted primary is stable, the former primary
is fenced or safely rejoined as a secondary, replication is within its accepted
budget, and no unresolved transaction or queue state remains. A single causal
failure may contribute at most one promotion event. Thrashing, repeated
failover/failback, or promotion loops do not increase event counts and fail the
campaign.

Every event must record:

- Failure identifier and classification.
- Injection mechanism.
- Random seed.
- Exact topology before, during, and after the event.
- Active workload and concurrency.
- Database timeline, replication, quorum, fencing, and promotion evidence.
- In-flight operation and idempotency state.
- Queue, outbox, worker, and adapter state.
- Workstation-visible state.
- Detection, fencing, promotion, recovery, and reconciliation times.
- Resource, latency, error, denial, and availability telemetry.
- Authoritative state before and after recovery.
- Data-loss, duplication, stale-success, authority-manufacture, and split-brain
  counters.

Formal acceptance requires all such counters to equal zero. The HA report must
also include promotion count per causal incident, authority-epoch changes,
former-primary rejoin disposition, stabilization-period compliance, automatic
failback attempts, and `HA_UNSTABLE` entries. Automatic failback attempts,
repeated promotion from one incident, and authority oscillation must equal zero.

## Relationship Between HA Fault Injection and Availability Qualification

Anti-oscillation prevents one fault from multiplying into repeated outages, but
it does not erase the deliberate service impact of many distinct destructive
fault injections. The full event-count HA campaign and the 30-day availability
qualification therefore remain separate but linked gates:

- The full HA campaign executes every required destructive event count and
  evaluates each event against fencing, integrity, recovery, and maximum-time
  thresholds.
- The 30-day availability window measures normal service, supported rolling
  maintenance and patching, ordinary component failures, and a representative
  subset of accepted HA events.
- The 30-day window must include at least one database-primary process loss, one
  database-primary host loss, one primary network partition, one protected-node
  rolling patch cycle, ten unplanned Go service process losses, and one hundred
  workstation disconnect-and-reconnect events.
- Additional destructive events may occur in the availability window only when
  the qualification plan states how their deliberate service impact will be
  measured. They are never silently excluded from the outage ledger.
- Passing the event-specific HA campaign cannot compensate for failing 99.99
  percent availability, and passing 99.99 percent availability cannot
  compensate for failing any required destructive HA event.

This separation prevents an artificial contradiction in which hundreds of
intentional destructive injections consume the entire availability budget while
still requiring the platform to prove that representative failures, routine
patching, and normal operations preserve semantic availability.

## Rolling Maintenance and Upgrade Assurance Gate

Routine operating-system, Windows workstation, database, Platform, integration,
certificate, firmware, and security maintenance must be proven without relying
on a full-system outage.

### Required Maintenance Behavior

The accepted deployment and procedure must prove all of the following under
representative valid and hostile workload:

- Protected nodes are patched or upgraded one at a time.
- The next node is not changed until the previous node has rejoined, passed
  integrity and health validation, and the topology has reached an accepted
  stable-state checkpoint.
- Active workload is drained, moved, or safely completed before reboot or
  service termination.
- Database leadership transfers through the accepted quorum, fencing,
  authority-epoch, and stable-primary contract.
- A recovered former primary returns as a validated secondary; patching does not
  cause automatic failback.
- Quorum remains healthy throughout the procedure, and no step removes more
  voters or failure domains than the accepted safety margin permits.
- Integrations use an accepted redundant route or expose the defined safe
  degraded state; a nominally redundant CAD core must not conceal a
  single-path external dependency.
- Workstations reconnect automatically, reauthenticate or renew safely, discard
  stale state, reread authoritative state, and preserve no local authority.
- Schema changes are backward compatible with the oldest application version
  permitted during the rollout and forward compatible with the rollback
  version for the accepted rollback window.
- The old and new application versions coexist safely for the complete accepted
  mixed-version interval.
- A failed package, node, database, application, adapter, or workstation update
  can be rolled back or forward-repaired without a full-system outage.
- Package, `/etc`, service, artifact, SBOM, provenance, and runtime-integrity
  baselines are verified before and after each node change.

### Required Executable Tests

The gate must include at least:

1. A complete protected-node rolling operating-system patch cycle, including a
   reboot-requiring kernel or equivalent platform update.
2. A complete Windows Operational Workstation patch and reboot cycle with
   positions updated in controlled groups while dispatch service remains
   available.
3. A database role transfer, patch of the former primary, secondary rejoin,
   stabilization, later operator-authorized role transition when needed, and
   patch of the remaining node.
4. Go service and worker rolling replacement while valid, hostile, retrying,
   queued, and reconciling work is active.
5. Integration-path maintenance proving redundant routing or accepted degraded
   operation.
6. A mixed-version application and schema campaign covering the oldest and
   newest versions permitted by the compatibility matrix.
7. An intentionally failed update followed by rollback without a full-system
   outage.
8. A rollback attempted after a partially applied schema or application change,
   proving the documented safe boundary and refusal behavior.
9. Workstation disconnect, patch, reboot, reconnect, current-state refresh, and
   pending-action reconciliation.
10. Complete before-and-after package, `/etc`, runtime, telemetry, availability,
    and audit evidence comparison.

### Maintenance Stop Conditions

Automation must stop before changing another node when:

- Quorum, fencing, replication, capacity, or telemetry is outside its accepted
  budget.
- The previous node has not rejoined or passed integrity verification.
- A critical path is unavailable or near its maximum recovery threshold.
- Queue age, replication lag, resource use, or error rate is increasing without
  accepted bound.
- Mixed-version compatibility is not proven.
- Package, configuration, or runtime integrity differs unexpectedly.
- Rollback material or authority is unavailable.

Maintenance completion is not established by a successful package-manager exit
code. It requires restored critical service, stable topology, reconciled
workstations and integrations, verified host baseline, and accepted observation
through the post-maintenance interval.

## Cumulative Pre-Pilot Qualification Gates

The following are independent, cumulative gates. They may overlap in calendar
time only when every applicable evidence rule is satisfied, but none may replace,
offset, average with, or provide partial credit for another:

1. **Fourteen-day failure-free clock:** fourteen consecutive calendar days in
   which planned attacks and injected component failures produce no unresolved
   platform `SEV_1_CRITICAL` or `SEV_2_HIGH` outcome. The injections themselves
   do not break the clock; unsafe, incorrect, unrecovered, or insufficiently
   evidenced platform behavior does. A qualifying outcome restarts the clock
   after remediation and regression acceptance.
2. **Distributed attack-wave campaign:** at least 180 valid credited campaign
   hours inside a fourteen-consecutive-day, 336-hour observed window.
3. **Semantic-availability gate:** at least 99.99 percent availability for every
   critical service path and aggregate CAD service over at least thirty
   consecutive days.
4. **Destructive HA and failover campaign:** all event-specific counts,
   integrity rules, and recovery thresholds pass.
5. **Rolling-maintenance and upgrade assurance gate:** patching, version
   coexistence, role movement, reconnection, compatibility, and rollback are
   proven under workload.
6. **Release, package, host, and runtime-integrity gate:** accepted artifact,
   package, `/etc`, baseline-generation, and running-process identities agree.

Passing the 180-hour campaign does not establish the fourteen-day failure-free
result or the thirty-day availability result. Passing availability does not
establish hostile coverage, HA correctness, maintenance safety, or release
integrity.

## Randomized Adversarial Stress Qualification

Before pilot entry, CAD must complete the dedicated randomized mixed stress,
attack, fault, and recovery phase defined by the CAD roadmap and testing model.

The campaign must combine valid operational work with randomized:

- Hostile inputs.
- Authorization and approval changes.
- Concurrency races.
- Retries and deadlocks.
- Queue and cache misuse.
- Process and host failures.
- Network degradation and partition.
- Replication disruption.
- Storage, CPU, memory, descriptor, and connection pressure.
- Workstation disconnection and restart.
- Provider duplication, delay, reordering, and partial success.
- Telemetry impairment.
- Backup, restore, rebuild, failover, and reconciliation operations.

The random scheduler must preserve minimum class coverage while randomizing the
type, count, order, concurrency, timing, duration, target, and combination of
injected conditions. Every run must retain enough evidence for exact replay.

## Burn-In Requirements

The availability-qualification environment must complete:

1. Three independently seeded 24-hour randomized stress and failure campaigns.
2. A 14-consecutive-day mixed endurance and attack-wave campaign containing at
   least 180 valid credited campaign hours.
3. A fourteen-consecutive-day failure-free clock covering the full observed
   attack-wave window.
4. The complete 30-day availability window.
5. Repeated HA and failover campaigns meeting the thresholds in this document.
6. At least one backup restoration into a clean environment.
7. At least one trusted rebuild from accepted release artifacts and protected
   backups.
8. At least one complete loss-of-primary recovery exercise.
9. At least one operator-led manual fallback and controlled reentry exercise.

The three 24-hour seeded campaigns may be scheduled inside and credited toward
the 180-hour minimum when they occur within the accepted 14-day window and meet
every campaign-validity rule. They are not automatically additive, and no hour
outside the accepted 14-day window counts toward the 180-hour requirement.

The full 336 hours of the 14-day campaign are observed for availability,
correctness, delayed effects, resource drift, recovery residue, and telemetry
completeness. A credited campaign hour is a wall-clock hour containing accepted
mixed workload, hostile activity, injected failure, recovery, or deliberate
post-wave validation. Concurrent attack generators do not multiply credited
hours.

The 180 credited hours must:

- Be distributed across at least 10 of the 14 calendar days.
- Include at least 12 separately scheduled attack or failure waves.
- Exercise at least eight applicable attack or fault families.
- Include short high-intensity bursts, prolonged low-rate pressure, compound
  failure waves, failover waves, recovery waves, and post-recovery validation.
- Include representative legitimate CAD operations during hostile activity.
- Include quiet observation intervals between selected waves to expose delayed
  retries, leaks, backlog residue, replication drift, stale state, corruption,
  and incomplete recovery.
- Prevent any one attack or fault family from contributing more than 25 percent
  of the credited campaign hours unless a stricter accepted profile applies.
- Prevent denial-of-service or generic resource exhaustion from serving as the
  sole or dominant campaign type.

A campaign may contribute to more than one requirement only when its workload,
telemetry, and evidence satisfy every applicable rule. The 14-day window restarts
following a qualifying severity-one or severity-two failure, loss of required
evidence, or an unresolved unknown outcome.

## Campaign Validity Gate

Before campaign outcomes are evaluated, the evidence set must pass a separate
validity gate. An invalid campaign receives zero qualification credit and must be
rerun; its action count, elapsed time, successful defenses, and failovers may not
be carried forward.

The campaign is invalid when any of the following occurs:

- Most activity is concentrated in one attack or fault family.
- A DDoS-style, volumetric, or generic resource-exhaustion workload dominates
  credited time or action volume.
- A required hostile, failure, state, enforcement-point, or recovery class does
  not meet its accepted minimum coverage.
- Required quiet recovery and latent-effect observation intervals are omitted.
- A seed, scheduler version, generator version, registry version, selected
  count, or replay input is missing.
- Required telemetry is incomplete, uncorrelated, altered, or insufficient to
  determine authoritative state and side effects.
- Hostile activity is run without representative normal CAD activity except for
  an explicitly isolated test that cannot claim mixed-campaign credit.
- Failover is exercised only while the platform is idle.
- Recovery is declared complete merely because processes or services restarted.
- An action, injected condition, unknown outcome, or operator intervention is
  unaccounted for.

Recovery credit requires proof that authority, quorum, fencing, replication,
protected reads and writes, uncertain transactions, queues, outboxes, workers,
integrations, workstation state, telemetry, and delayed effects have returned to
the accepted state. Service restart is only one observation within recovery.

## Pilot Entry Gate

Pilot entry requires:

- Exact accepted release and artifact digests.
- Exact environment and HA profile.
- 99.99 percent availability PASS for every critical path and aggregate CAD
  service over the full 30-day window.
- Every HA event remains within its maximum acceptable threshold, and
  engineering-goal attainment is accepted.
- Normal and one-failure capacity thresholds PASS.
- Fourteen-consecutive-day failure-free clock PASS.
- At least 180 valid credited attack-wave campaign hours PASS.
- Randomized adversarial stress qualification and campaign-validity gate PASS.
- Rolling-maintenance and upgrade assurance gate PASS.
- Release, package, `/etc`, host-baseline, and runtime-integrity gate PASS.
- Zero lost acknowledged commits.
- Zero split-brain events.
- Zero authority-manufacture or unauthorized-commit events.
- Zero stale-success or false-commit outcomes.
- Zero unresolved severity-one or severity-two failures.
- Complete telemetry and failure classification.
- Backup, restore, rebuild, rollback, and reconciliation accepted.
- Accessibility status accepted or governed without blocking critical use.
- Standards-conformance status explicit.
- Supply-chain and release-integrity status accepted.
- Operational procedures, training, support, and escalation ownership assigned.
- Independent acceptance authority approval.

Pilot use must not be used to discover whether the foundational HA or integrity
model works.

## Production Acceptance

Production acceptance requires completion of pilot remediation and repetition
of every affected qualification gate.

The production acceptance record must state:

- Exact release, source, provenance, SBOM, signature, and artifact digests.
- Exact schema migration inventory.
- Exact deployment, network, HA, workstation, and integration profiles.
- Availability numerator, denominator, percentage, and outage ledger.
- Capacity and failover results.
- Failure and attack classification summary.
- Open findings, accepted exceptions, owners, and expiration dates.
- Standards-conformance claims and deviations.
- Recovery, rollback, support, and continuity readiness.
- Monitoring thresholds and response procedures.
- Acceptance authorities and separation-of-duty status.
- Known limitations and explicitly unsupported behavior.

## Production Monitoring Thresholds

Production alerting must be more conservative than acceptance failure limits.
Unless a stricter deployment profile is accepted, alert no later than:

- Availability projected below 99.995 percent for the rolling 30-day window.
- Any critical path unavailable for 10 seconds.
- Replication lag threatening the accepted zero-loss profile.
- Critical resource above 70 percent for 5 minutes in healthy topology.
- Critical resource above 80 percent for 2 minutes in degraded topology.
- Critical storage below 25 percent free.
- Queue age above 50 percent of its hard budget.
- Failover stage exceeding 50 percent of its maximum threshold.
- Any split-brain, fencing, stale-success, uncertain-commit, authority, data
  integrity, or telemetry-completeness warning.

Monitoring thresholds provide intervention margin. They are not permission to
operate continuously at the acceptance limit.

## Requalification Triggers

Requalification is required when a change materially affects:

- Database replication, quorum, fencing, or failover.
- Runtime topology or capacity.
- Protected operation semantics.
- Retry, idempotency, queue, outbox, or reconciliation behavior.
- Identity, approval, authorization, lease, or Decision Record behavior.
- Workstation cache, spool, IPC, or reconnect behavior.
- Critical external integrations.
- Build, deployment, signing, or artifact provenance.
- Backup, restore, rebuild, or rollback.
- Monitoring or availability measurement.
- A previously accepted capacity or latency budget.

The change-impact decision must identify whether full 30-day availability
requalification, targeted failover requalification, or another accepted scope is
required.

## Non-Claims

Passing this model proves only the exact release, environment, workload,
topology, failure classes, and observation window recorded by the acceptance
artifact.

It does not prove universal availability, prevention of every attack, immunity
to every disaster, or readiness for an untested deployment profile.
