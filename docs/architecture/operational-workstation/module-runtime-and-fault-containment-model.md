# Module Runtime and Fault Containment Model

> Status: Normative target architecture.
>
> Implementation status: Process boundaries and supervision contracts are not yet implemented.

## Purpose

This document defines what it means for a console function to be an independently recoverable module.

## Module definition

A console module is a versioned operational capability with a declared:

- Purpose.
- State ownership.
- Process boundary.
- Renderer boundary.
- Native host boundary.
- Local IPC contract.
- Remote service contract.
- Runtime identity.
- Resource budget.
- Health contract.
- Restart policy.
- State-restoration contract.
- Operator-visible failure behavior.
- Release compatibility range.

A directory, Go package, JavaScript bundle, panel, or iframe is not by itself a module boundary.

## Reference module structure

```text
Module UI process
├── GTK window or controlled surface
├── WebKitGTK renderer
├── custom URI content provider
└── narrow native message bridge
             │
             ▼
Module service process
├── authenticated local IPC server
├── remote platform client
├── local projection/cache manager
├── health endpoint
└── fault-event publisher
```

Some modules may combine the native UI host and local service when evidence shows that the combined boundary remains safe and independently recoverable. High-risk or high-resource modules should remain separated.

## Isolation goals

A failed module must not automatically:

- Freeze the complete console.
- Terminate the operator session.
- corrupt another module's local state.
- consume unbounded CPU, memory, disk, GPU, file descriptors, or sockets.
- acquire another module's platform capability.
- restart unrelated modules.
- suppress global alerts.
- hide its own failed state.
- retain stale authority after restart.

## Significant modules

At minimum, the following should be evaluated as independent boundaries:

- Incident or call handling.
- Unit and resource status.
- Mapping and geospatial rendering.
- Messaging and notifications.
- Search and reference.
- Document or report rendering.
- Local action delivery and recovery.
- Global console coordination.

The final decomposition must follow failure, resource, authority, and state boundaries rather than visual layout alone.

## Health model

Every module declares health checks for:

- Process existence.
- Native event-loop responsiveness.
- Renderer responsiveness.
- Local IPC responsiveness.
- Required local dependency health.
- Required remote dependency health.
- Data synchronization.
- Operator-context restoration.
- Resource consumption.
- Error-rate or restart-rate threshold.

Health is not a single Boolean.

A module may be:

- Starting.
- Ready.
- Healthy.
- Delayed.
- Degraded.
- Failed.
- Restarting.
- Resynchronizing.
- Restricted.
- Disabled.
- Maintenance.
- Incompatible.

## Readiness

A process is not ready merely because it started.

A module may report ready only after:

- Its release and configuration are verified.
- Required local sockets are acquired.
- Its IPC identity is established.
- Required local state is opened safely.
- The UI surface is available.
- Initial authoritative state is synchronized or explicit offline behavior is established.
- Required operator context is restored.
- Functional health checks pass.

## Supervision

systemd is the initial reference supervisor.

Each module service must declare:

- `Restart=` behavior.
- Restart delay and backoff.
- Startup timeout.
- Stop timeout.
- Resource limits.
- Runtime identity.
- Filesystem access.
- network access.
- capability set.
- writable directories.
- logging destination.
- dependency ordering.
- participation in the console target.

Automatic restart must be bounded.

A repeated crash loop must lead to an explicit disabled or degraded state rather than endless resource consumption.

## Restart sequence

A normal automatic recovery sequence is:

```text
Health deadline exceeded
        ↓
Module marked delayed or degraded
        ↓
Operator receives visible state
        ↓
Failure threshold reached
        ↓
Operational Fault Episode opened
        ↓
Failed process diagnostics captured
        ↓
Process terminated and restarted
        ↓
New module instance identity issued
        ↓
Local IPC reauthenticated
        ↓
Authoritative state resynchronized
        ↓
Operator context restored
        ↓
Functional health verified
        ↓
Module returned to healthy
```

The console must not display “restored” before functional restoration is complete.

## Module instance identity

Every process start receives a new module instance identifier.

All requests, events, health records, state checkpoints, and fault records include that identifier.

Capabilities associated with the previous instance become invalid when the instance terminates.

Delayed messages from an old instance must not be accepted by a replacement instance.

## Resource containment

Each module profile defines:

- Memory ceiling.
- CPU weight and ceiling where appropriate.
- File-descriptor limit.
- process and thread limit.
- local cache ceiling.
- write-rate ceiling.
- network destination profile.
- startup time budget.
- response deadline.
- GPU use policy where measurable.
- restart-rate threshold.

The mapping module is expected to require a larger graphics and cache budget than text-oriented modules, but it must not be able to starve the incident or global status modules.

## State reconstruction

A module restart must reconstruct:

- Current authoritative projection.
- Current freshness state.
- Current operator selection.
- Relevant workspace location.
- Approved accessibility settings.
- Pending local drafts or actions according to policy.
- Last acknowledged server sequence.
- Any visible conflict or outcome-unknown state.

State that cannot be safely reconstructed must be declared lost or unavailable. It must not be fabricated.

## Incompatible module behavior

A module that does not support the active local IPC or platform protocol version must:

- Refuse normal operation.
- enter an explicit incompatible state.
- provide version evidence.
- avoid repeated restart loops.
- preserve unrelated console functions.
- create or join an Operational Fault Episode.
