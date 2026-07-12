# Operational Workstation Architecture

> Status: Normative architecture under active refinement.
>
> Implementation status: Target architecture; not yet implemented or field validated.

## Purpose

The Operational Workstation Architecture defines the complete computing environment used by an operational user, including the operating system, local services, graphical suite, module runtime, workstation trust, local state, input devices, displays, management path, recovery behavior, and operator-visible failure states.

For a dispatcher, the console is the unified information, decision-support, and workflow environment. Radio and telephone systems remain separate systems. The console may receive call metadata, recording references, channel or unit state, timestamps, location information, and integration events, but it does not own the core communications function of those systems.

## Architectural objective

The console must behave like a dependable operational appliance:

- Fast and predictable under sustained workload.
- Understandable during normal and degraded operation.
- Resistant to unnecessary software and service growth.
- Able to isolate and recover individual modules.
- Unable to convert a local presentation decision into platform authority.
- Reproducible from governed artifacts.
- Manageable without taking over or obstructing the operator workspace.
- Auditable from operator action through platform decision and support response.
- Accessible across supported operator needs and workstation profiles.

## Reference structure

```text
Managed Operational Console Session
│
├── Session coordinator and global status surface
├── Incident module process boundary
├── Resource or unit module process boundary
├── Mapping module process boundary
├── Messaging and notification process boundary
├── Search and reference process boundary
├── Local state and delivery service
├── Trust-evidence and health agent
└── Management, logging, and recovery services
```

A module may contain:

```text
WebKitGTK renderer
        │
        │ narrow native message bridge
        ▼
Go module host
        │
        │ authenticated Unix-domain socket
        ▼
Go module service
        │
        │ authenticated platform connection
        ▼
Platform services
```

The exact number of processes may vary by profile, but significant functions must not be combined merely for implementation convenience when doing so would create a shared failure boundary.

## Workstation responsibilities

The workstation is responsible for:

- Rendering approved UI resources.
- Receiving operator input.
- Maintaining visible workspace layout.
- Presenting current connection, freshness, trust, and action states.
- Protecting local temporary information.
- Preserving safe recoverable drafts where policy permits.
- Delivering structured actions to platform services.
- Detecting local module and dependency failures.
- Supervising and restarting local components.
- Reconstructing views from authoritative state.
- Producing workstation health, security, performance, and fault evidence.
- Supporting governed administration, update, rollback, isolation, and rebuild.

## Workstation non-responsibilities

The workstation does not:

- Grant protected platform authority.
- Replace the Foundation Decision Engine.
- Become the authoritative database for committed operational records.
- Allow UI visibility to imply authorization.
- Treat local cache as current merely because it is available.
- Let a module communicate directly with the database.
- Make radio or telephone core operation dependent on the console.
- Permit an external provider to declare the workstation or operator trusted.
- Hide failed integrations behind normal-looking controls.
- Depend on one monitoring, EDR, mapping, radio, telephone, or recording vendor.

## Process and authority boundaries

A Go package boundary is not a runtime failure boundary.

A JavaScript component, iframe, or panel is not a runtime failure boundary.

A separate WebView inside one unsupervised process may improve rendering isolation but is not sufficient when failure of the owning process would still terminate the complete console.

Each significant module profile must declare:

- Process boundary.
- Native host boundary.
- Renderer boundary.
- Local IPC endpoint.
- Remote platform dependencies.
- State ownership.
- Cache and spool ownership.
- Health contract.
- Startup deadline.
- Resource budget.
- Restart policy.
- Restart-loop policy.
- State-restoration contract.
- Operator-visible degraded behavior.
- Compatible protocol and release versions.
- Security privileges.
- Network permissions.
- Logging and Operational Fault Episode participation.

## State ownership

Committed operational state belongs to authoritative platform services.

The workstation may hold:

- Display projections.
- Freshness metadata.
- Short-lived caches.
- Operator drafts.
- Idempotent pending actions.
- Delivery acknowledgments.
- Workspace and accessibility preferences.
- Diagnostic evidence.

Local state must be classified explicitly as authoritative, projected, cached, draft, pending, acknowledged, rejected, conflicted, outcome-unknown, or disposable.

A module must be restartable without inventing, losing, or silently duplicating committed work.

## Security boundaries

The operator session runs without general administrative authority.

The renderer receives no platform private key, database credential, device private key, administrative token, or unrestricted network path.

The native Go services perform controlled remote communication and expose only narrowly scoped local interfaces.

The host firewall is deny by default. Upstream segmentation is an independent control.

The management path is separate from the operator path. Named administrators use approved SSH access with strong authentication, controlled privilege elevation, and complete session recording.

## Availability and degraded operation

A capability that is unavailable, delayed, stale, resynchronizing, restricted, or untrusted must be clearly identified.

Failure of one module must not automatically:

- Terminate the operator session.
- Clear unrelated visible context.
- restart unrelated modules.
- discard acknowledged actions.
- mark stale data as live.
- disable core radio or telephone operation.
- convert an uncertain action outcome into a retry prompt.

Recovery is complete only after the required service, data, operator context, and functional checks succeed.

## Minimal and deliberate composition

The initial platform may use Arch Linux because it permits deliberate construction from a small base. The architectural requirement is not a brand name or the smallest possible package count. The requirement is that every installed package, enabled service, open socket, timer, user, group, kernel module, writable path, and background process has:

- A documented purpose.
- An owner.
- A version and source.
- A security and resource review.
- A lifecycle and update path.
- A known removal impact.

Production consoles must not follow an uncontrolled rolling repository. They consume tested and signed release snapshots.

## Acceptance conditions

No workstation profile is accepted until evidence demonstrates:

- Module failure containment.
- Restart and state reconstruction.
- No renderer remote-content path.
- Local IPC authentication and authorization.
- Clear degraded-state presentation.
- Operator lock and handoff privacy.
- Local state protection and replay safety.
- Resource-budget enforcement.
- Accessible operation across the accepted profile.
- Recorded remote administration.
- Reproducible provisioning and rebuild.
- Signed release promotion and rollback.
- Drift and workstation trust evidence.
- Fault-event correlation from detection through resolution.
