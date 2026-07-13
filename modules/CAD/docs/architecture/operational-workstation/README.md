# CAD Operational Workstation Architecture

> **Status:** Normative CAD target architecture under active refinement
>
> **Implementation status:** No production workstation profile is accepted
>
> **Scope note:** Here, console means the complete managed computing environment
> and graphical CAD suite used by a call taker, dispatcher, or supervisor. Core
> radio and telephone functions remain separate systems and integrate through
> governed contracts.

## Purpose

Define the CAD Operational Workstation as a managed, verifiable, recoverable
operational appliance rather than a general-purpose desktop.

This architecture is owned by the CAD module. It does not claim authority over
future non-CAD workstations.

The target workstation contains only packages, services, accounts, interfaces,
and capabilities required for its approved CAD purpose. It must remain
responsive during high workload, contain workstation-component failures, expose
degraded conditions, support attributable remote administration, and recover
from known-good artifacts.

## Foundational Direction

The initial reference direction is:

- Arch Linux or an equivalently minimal, deliberately composed Linux base.
- A Managed Operational Console Session instead of a normal desktop session.
- Go for native console services and local workstation-component hosts.
- GTK 4 and WebKitGTK 6.0 for standards-based HTML, CSS, and JavaScript presentation.
- Application-registered custom URI schemes for release-controlled UI content.
- Authenticated Unix-domain sockets for local workstation-component IPC.
- systemd for process supervision, resource controls, readiness, and selected
  socket activation.
- Independent process boundaries for significant workstation components.
- A deny-by-default host firewall and independent upstream segmentation.
- Daily, Pre-production, and Release channels using immutable promoted artifacts.
- Named SSH administration through approved management paths with complete
  terminal input and output recording.
- Rebuild from approved artifacts when integrity or configuration cannot be
  established confidently.

These are target decisions, not claims of implementation.

## Relationship to Other CAD Architecture

The [CAD domain architecture](../README.md) owns canonical incidents, units,
assignments, alerts, authorization, and operational history.

The [CAD User-Interface Architecture](../user-interface/README.md) owns
role-centered interaction, accessibility, focus, input, state presentation, and
human-facing workflow behavior.

This directory owns the appliance and local implementation profile used to host
those accepted CAD interfaces.

The [CAD Architecture Boundary and Precedence Model](../cad-architecture-boundary-and-precedence-model.md)
resolves overlapping concerns.

## Document Map

### Core Workstation Boundary

- [CAD Operational Workstation Architecture](operational-workstation-architecture.md)
- [Managed Operational Console Session Model](managed-operational-console-session-model.md)
- [Workstation Component Runtime and Fault Containment Model](workstation-component-runtime-and-fault-containment-model.md)
- [Local UI Content and WebView Security Model](local-ui-content-and-webview-security-model.md)
- [Local IPC and systemd Activation Model](local-ipc-and-systemd-activation-model.md)

### Operator State and Failure Behavior

- [Operator Session, Lock, Handoff, and Privacy Model](operator-session-lock-handoff-and-privacy-model.md)
- [Local State, Cache, Spool, and Recovery Model](local-state-cache-spool-and-recovery-model.md)
- [Degraded Operation and Action State Model](degraded-operation-and-action-state-model.md)
- [Operational Fault Episode Model](operational-fault-episode-model.md)
- [Human Factors and Interaction Model](human-factors-and-interaction-model.md)

### Workstation Security and Management

- [Workstation Platform Security and Data Protection Model](workstation-platform-security-and-data-protection-model.md)
- [Network Communication Profile](network-communication-profile.md)
- [Remote Management and Session Recording Model](remote-management-and-session-recording-model.md)
- [Software Package and Release Governance](software-package-and-release-governance.md)
- [Workstation Baseline and Trust Assertion Model](workstation-baseline-and-trust-assertion-model.md)
- [Provisioning, Rebuild, Lifecycle, and Recovery Model](provisioning-rebuild-lifecycle-and-recovery-model.md)
- [Performance and Resource Budget](performance-and-resource-budget.md)

## Dependency Direction

```text
Platform Foundation and governed services
        ↓
CAD domain and application services
        ↓
CAD user-interface contracts
        ↓
Local Go services and workstation-component hosts
        ↓
Managed Operational Console Session presentation
```

The workstation consumes Foundation and CAD service decisions. It is not an
independent authorization authority.

A visible control, loaded workstation component, local cache, keyboard binding,
local socket, or successful renderer message does not grant permission.

## External Communications Boundary

Radio, telephony, recording, alerting, mapping, and other systems may integrate
through governed adapters.

The workstation must not create a false dependency in which loss of the CAD
console disables core radio transmission or telephone call receipt, loss of one
integration makes unrelated CAD functions unusable, a recording reference is
treated as proof of successful recording, or provider failure is hidden behind
a normal-looking surface.

## Architecture Invariants

1. A significant workstation component is not isolated unless its failure can be
   detected, contained, restarted, and reconstructed without restarting
   unrelated console functions.
2. Canonical committed state does not exist only inside a renderer or one local
   process.
3. The renderer does not directly retrieve operational application content from
   remote servers.
4. Remote platform communication is performed by controlled native services.
5. A local IPC endpoint is not trusted merely because it is local.
6. Process restart is not recovery until required state is resynchronized and
   operator context is restored.
7. A degraded capability is visibly degraded; blank or stale information must
   not appear normal.
8. Console availability does not bypass authorization, trust, audit, or data
   protection.
9. Every installed component and background capability has an approved CAD
   purpose.
10. Administrative activity is attributable, recorded, and independently retained.
11. Production releases are promoted immutable artifacts, not fresh rebuilds of
    supposedly identical source.
12. When integrity is uncertain, trusted rebuild is preferred over undocumented repair.

## Examples

The [examples](examples/) directory is reserved for non-production
machine-readable records, service definitions, and validation fixtures. Any
example placed there must identify placeholders and must not be deployed
unchanged.

## Related Platform Architecture

- [Platform Engineering Principles](../../../../../docs/architecture/platform-engineering-principles.md)
- [External-System-Independent Observability](../../../../../docs/architecture/external-system-independent-observability.md)
- [Backend Services Architecture](../../../../../docs/architecture/backend-services/README.md)
- [GIS and Mapping Architecture](../../../../../docs/architecture/gis-and-mapping/README.md)
- [Communications Architecture](../../../../../docs/architecture/communications/README.md)
