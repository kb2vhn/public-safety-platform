# Location Service Architecture

> **Status:** Draft normative architecture.
>
> **Implementation status:** Not implemented or load tested.

## Purpose

The Location Service receives high-frequency position reports, maintains current live resource location, distributes authorized changes, and persists governed historical records without turning PostgreSQL into a live message bus.

## Ownership boundary

The Location Service owns:

- Validation of incoming location reports.
- Per-resource ordering and freshness.
- Current accepted live location in a bounded cache.
- A short bounded movement buffer where required.
- Publication of accepted live changes.
- Reduction, batching, and asynchronous persistence of routine telemetry.
- Backpressure and persistence-degradation state.

PostgreSQL owns:

- Durable historical location records.
- Durable critical operational events.
- Retention and historical-query policy.
- The last persisted recovery point.

Module services own resource identity, assignment, operational status, and business transitions unless a separate architecture decision assigns them elsewhere.

## Update flow

```text
Resource device
      |
      v
Authenticated location ingest
      |
      v
Validation, ordering, and plausibility checks
      |
      +--> current in-memory state and bounded recent buffer
      |           |
      |           +--> subscription publication
      |
      +--> bounded asynchronous persistence queue or spool
                  |
                  v
             PostgreSQL history
```

## Accepted location record

A current record should include at least:

- Resource identifier.
- Source device identifier.
- Latitude and longitude.
- Accuracy.
- Heading and speed when available.
- Source sequence or ordering context.
- Observed time and received time.
- Freshness state.
- Validation result.

## Database-churn control

Routine location reports may be accepted more frequently than they are durably stored.

Persistence policy may use:

- Maximum time interval.
- Significant distance moved.
- Material heading or speed change.
- Geofence or governed-boundary crossing.
- Resource status transition.
- Incident assignment transition.
- Evidentiary or policy requirement.

Routine points may be coalesced before persistence. Critical operational transitions must not be coalesced or silently discarded.

## Persistence and backpressure

- Live publication must not synchronously depend on every routine PostgreSQL insert.
- Persistence queues and memory buffers are bounded.
- When PostgreSQL is unavailable, routine pending points may be reduced to the newest required recovery point per resource according to policy.
- Critical events require protected durable handling and explicit failure behavior.
- A local encrypted spool may be introduced only if loss requirements justify its package, storage, integrity, and recovery costs.

## Restart behavior

After restart, the service may load the last durable point as recovery context, but it must mark that point stale. It becomes live only after a newer accepted device report.

## Scale direction

The initial implementation should avoid introducing an external broker or distributed cache without demonstrated need.

A single active owner with a clear standby or restart model is preferable at initial scale. Later horizontal scaling requires explicit resource ownership, partitioning, ordering, failover, and duplicate-delivery rules.

## Security boundary

The Location Service reports where a resource is. It does not decide who may see that resource. Visibility is enforced by authorization and the subscription boundary.
