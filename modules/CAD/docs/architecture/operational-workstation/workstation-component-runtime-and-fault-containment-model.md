# Workstation Component Runtime and Fault Containment Model

> Status: Normative CAD target architecture.
>
> Implementation status: Process boundaries and supervision contracts are not yet implemented.

## Purpose

This document defines what it means for a console function to be an independently recoverable workstation component.

## Workstation Component Definition

A console workstation component is a versioned operational capability with a declared:

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

A directory, Go package, JavaScript bundle, panel, or iframe is not by itself a workstation component boundary.

## Reference Workstation Component Structure

```text
Component UI process
├── GTK window or controlled surface
├── WebKitGTK renderer
├── custom URI content provider
└── narrow native message bridge
             │
             ▼
Component service process
├── authenticated local IPC server
├── remote platform client
├── local projection/cache manager
├── health endpoint
└── fault-event publisher
```

Some workstation components may combine the native UI host and local service when retained validation results demonstrate that the combined boundary remains safe and independently recoverable. High-risk or high-resource workstation components should remain separated.

## Isolation goals

A failed workstation component must not automatically:

- Freeze the complete console.
- Terminate the operator session.
- corrupt another workstation component's local state.
- consume unbounded CPU, memory, disk, GPU, file descriptors, or sockets.
- acquire another workstation component's platform capability.
- restart unrelated workstation components.
- suppress global alerts.
- hide its own failed state.
- retain stale authority after restart.

## Significant workstation components

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

Every workstation component declares health checks for:

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

A workstation component may be:

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

A workstation component may report ready only after:

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

Each component service must declare:

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
Workstation Component marked delayed or degraded
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
New component instance identity issued
        ↓
Local IPC reauthenticated
        ↓
Authoritative state resynchronized
        ↓
Operator context restored
        ↓
Functional health verified
        ↓
Workstation Component returned to healthy
```

The console must not display “restored” before functional restoration is complete.

## Workstation Component instance identity

Every process start receives a new component instance identifier.

All requests, events, health records, state checkpoints, and fault records include that identifier.

Capabilities associated with the previous instance become invalid when the instance terminates.

Delayed messages from an old instance must not be accepted by a replacement instance.

## Resource containment

Each component profile defines:

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

The mapping workstation component is expected to require a larger graphics and cache budget than text-oriented workstation components, but it must not be able to starve the incident or global status workstation components.

## State reconstruction

A workstation component restart must reconstruct:

- Current authoritative projection.
- Current freshness state.
- Current operator selection.
- Relevant workspace location.
- Approved accessibility settings.
- Pending local drafts or actions according to policy.
- Last acknowledged server sequence.
- Any visible conflict or outcome-unknown state.

State that cannot be safely reconstructed must be declared lost or unavailable. It must not be fabricated.

## Incompatible workstation component behavior

A workstation component that does not support the active local IPC or platform protocol version must:

- Refuse normal operation.
- enter an explicit incompatible state.
- provide version-verification records.
- avoid repeated restart loops.
- preserve unrelated console functions.
- create or join an Operational Fault Episode.
