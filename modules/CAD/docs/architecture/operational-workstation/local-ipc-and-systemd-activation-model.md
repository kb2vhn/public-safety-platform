# Local IPC and systemd Activation Model

> Status: Normative CAD target architecture.
>
> Implementation status: Unix-domain sockets and selective systemd socket activation are the initial reference direction.

## Purpose

This document defines secure local communication between console processes and the role of systemd socket activation.

## Preferred transport

Unix-domain sockets are the preferred local transport for:

- Workstation Component control.
- Live local projections.
- Structured operator actions.
- Health checks.
- State restoration.
- Fault-event publication.
- Local capability negotiation.

Loopback TCP may be used only where a documented dependency cannot use Unix-domain sockets or a direct native bridge.

## Runtime paths

Runtime sockets must be created below a controlled runtime directory such as:

```text
/run/iron-console/
├── shell/
│   └── control.sock
├── workstation components/
│   ├── incident/
│   │   └── control.sock
│   ├── map/
│   │   └── control.sock
│   └── resources/
│       └── control.sock
└── sessions/
    └── <console-session-id>/
```

Sockets must not be placed in a world-writable location such as `/tmp`.

Runtime directories should be created and permissioned by systemd rather than by ad hoc application startup logic.

## Narrow interfaces

One universal local API is discouraged.

A workstation component endpoint should expose only the functions required by that workstation component.

For example:

```text
incident/control.sock
    Read incident projections
    submit governed incident actions
    receive incident updates

map/control.sock
    Read approved location projections
    submit map interaction events
    receive layer and resource updates

resources/control.sock
    Read resource projections
    submit governed resource actions
```

The mapping workstation component must not be able to close an incident merely because both functions are visible in the same console.

## Authentication and peer verification

Filesystem permissions are necessary but insufficient.

Each connection must be evaluated using multiple signals where available:

- Socket ownership and mode.
- Connecting Linux user and group.
- Peer process identifier.
- Expected cgroup or systemd unit.
- Workstation Component identity.
- Workstation Component instance identity.
- Console session identity.
- Per-start capability.
- Protocol version.
- Message sequence.
- Request identifier.
- Freshness and replay checks.

A process running as the ordinary operator must not gain every local component capability simply because it can discover a socket path.

## Per-start capability

Every workstation component start receives a new short-lived local capability.

The capability:

- Is scoped to one workstation component and purpose.
- Is bound to one component instance.
- Is delivered through a protected native mechanism.
- Is never embedded in static JavaScript.
- Expires when the process or session ends.
- Is rotated after restart.
- Is not accepted from an older component instance.
- Is redacted from ordinary logs.

## Message envelope

Local messages must be framed and versioned.

A conceptual envelope is:

```json
{
  "protocol_version": "1.0",
  "message_id": "01J...",
  "correlation_id": "01J...",
  "console_session_id": "session-...",
  "module_id": "map",
  "module_instance_id": "map-...",
  "sequence": 1842,
  "created_at": "2026-07-12T19:07:32.184Z",
  "message_type": "map.viewport.changed",
  "payload": {}
}
```

The transport must not assume one operating-system read equals one message.

An initial framing method may use a fixed-width length prefix followed by a bounded JSON document. Another encoding may be adopted after measurement, but inspectability and compatibility are primary requirements.

## Message requirements

Every message type declares:

- Maximum encoded size.
- required and optional fields.
- allowed sender.
- allowed receiver.
- ordering requirements.
- idempotency behavior.
- timeout.
- acknowledgment behavior.
- retry behavior.
- audit significance.
- error behavior.
- compatibility version.

Unknown message types or incompatible protocol versions fail closed.

## Backpressure

A slow or failed consumer must not cause unbounded memory growth.

Each connection defines:

- Queue limit.
- event coalescing policy.
- discard policy for replaceable projections.
- non-discardable critical-event policy.
- producer timeout.
- reconnect behavior.
- operator-visible effect.
- Operational Fault Episode threshold.

Live position updates may be coalesced to the newest safe projection. A protected operator action must not be silently discarded.

## systemd socket activation

systemd socket activation is a supported mechanism where an operating-system-owned endpoint improves:

- Startup ordering.
- Stable socket ownership.
- Consistent permissions.
- Service restart.
- On-demand activation.
- Recovery from an absent service.
- Removal of socket-creation races.

Socket activation does not preserve an accepted connection when the service process fails. The client must reconnect and reauthenticate.

## Critical workstation components

Critical operational workstation components should normally be proactively started and health validated as part of the console target.

Socket activation may still own their stable listening endpoints.

Examples include:

- Console coordinator.
- Incident and call-handling component.
- Unit and resource component.
- Mapping component.
- Messaging and notification component.
- Local delivery and recovery service.
- Audit and telemetry forwarding.

## On-demand workstation components

True on-demand activation may be appropriate for:

- Report preview and rendering.
- Historical search workers.
- Export preparation.
- Diagnostic collection.
- Rarely used administrative support tools.

An on-demand workstation component must still declare a startup deadline and visible behavior while starting.

## Socket activation mode

The default for stateful Go component services is:

```ini
Accept=no
```

One supervised service receives the listening socket and manages its accepted connections.

`Accept=yes` requires an explicit Architecture Decision Record because it creates one service instance per connection and changes state, resource, and audit behavior.

## Descriptor ownership

When socket activation is used:

- systemd creates and owns the listening endpoint.
- the service receives the open descriptor.
- the service must not silently create an unmanaged production socket if the descriptor is missing.
- descriptor names must be explicit.
- unexpected descriptors cause startup failure.
- development fallback behavior must be disabled in production releases.

## Recovery behavior

After a service failure:

1. Existing accepted connections fail.
2. The console marks the affected capability delayed or degraded.
3. systemd restarts or activates the replacement service.
4. The replacement receives the stable listening socket.
5. The client reconnects.
6. A new component instance authenticates.
7. State resynchronization begins.
8. Operator context is restored.
9. Functional health is verified.
10. The workstation component returns to healthy.

The mere existence of the socket does not prove workstation component readiness.

## Example units

Non-production examples are provided under:

```text
examples/systemd/
```

They illustrate structure only. Final units require security review, resource measurement, and validation on the accepted workstation profile.
