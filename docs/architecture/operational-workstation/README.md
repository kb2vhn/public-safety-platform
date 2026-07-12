# Operational Workstation Architecture

> Status: Normative architecture under active refinement.
>
> Implementation status: Target architecture; no production workstation profile is yet accepted.
>
> Scope note: In this directory, **console** means the complete computing environment and graphical suite used by an operator. Radio and telephone systems remain separate systems. They may provide metadata, state, or recording references through governed integrations, but their core communications functions are outside this workstation boundary.

## Purpose

This directory defines the Operational Workstation as a managed, verifiable, recoverable operational appliance rather than a general-purpose desktop.

The initial demanding profile is a public-safety dispatch console. The architecture remains usable by future municipal, school, institutional, and other operational module families.

The target console is deliberately composed from only the packages, services, accounts, interfaces, and capabilities required for its approved purpose. It is designed to remain responsive during high workload, contain module failures, expose degraded conditions clearly, support recorded remote administration, and recover from known-good artifacts.

## Foundational direction

The initial reference direction is:

- Arch Linux or an equivalently minimal, deliberately composed Linux base.
- A **Managed Operational Console Session** instead of a normal desktop session.
- Go for native console services and local module hosts.
- GTK 4 and WebKitGTK 6.0 for standards-based HTML, CSS, and JavaScript presentation.
- Application-registered custom URI schemes for release-controlled UI content.
- Authenticated Unix-domain sockets for local module IPC.
- systemd for process supervision, resource controls, service readiness, and selected socket activation.
- Independent process boundaries for significant modules.
- A deny-by-default host firewall and independent upstream segmentation.
- Daily, Pre-production, and Release software channels using immutable promoted artifacts.
- Named SSH administration through approved management paths with complete terminal input and output recording.
- Rebuild from approved artifacts when integrity or configuration cannot be established confidently.

These are target architecture decisions, not claims of current implementation.

## Document map

### Core console boundary

- [Operational Workstation Architecture](operational-workstation-architecture.md)
- [Managed Operational Console Session Model](managed-operational-console-session-model.md)
- [Module Runtime and Fault Containment Model](module-runtime-and-fault-containment-model.md)
- [Local UI Content and WebView Security Model](local-ui-content-and-webview-security-model.md)
- [Local IPC and systemd Activation Model](local-ipc-and-systemd-activation-model.md)

### Operator state and failure behavior

- [Operator Session, Lock, Handoff, and Privacy Model](operator-session-lock-handoff-and-privacy-model.md)
- [Local State, Cache, Spool, and Recovery Model](local-state-cache-spool-and-recovery-model.md)
- [Degraded Operation and Action State Model](degraded-operation-and-action-state-model.md)
- [Operational Fault Episode Model](operational-fault-episode-model.md)
- [Human Factors and Interaction Model](human-factors-and-interaction-model.md)

### Workstation security and management

- [Workstation Platform Security and Data Protection Model](workstation-platform-security-and-data-protection-model.md)
- [Network Communication Profile](network-communication-profile.md)
- [Remote Management and Session Recording Model](remote-management-and-session-recording-model.md)
- [Software Package and Release Governance](software-package-and-release-governance.md)
- [Workstation Baseline and Trust Evidence Model](workstation-baseline-and-trust-evidence-model.md)
- [Provisioning, Rebuild, Lifecycle, and Recovery Model](provisioning-rebuild-lifecycle-and-recovery-model.md)
- [Performance and Resource Budget](performance-and-resource-budget.md)

## Dependency direction

```text
Platform Foundation and governed platform services
                    ↓
        Operational module services
                    ↓
     Local Go module services and hosts
                    ↓
 Managed Operational Console Session presentation
```

The console may consume Foundation and module-service decisions. It must not become an independent authorization authority.

A workspace, visible control, loaded module, local cache, keyboard binding, or successful renderer message does not grant permission. Protected actions remain subject to current server-side identity, device, scope, purpose, policy, approval, session, and Authorization Lease evaluation.

## External communications boundary

Radio, telephony, recording, alerting, mapping, and other external systems may integrate with the console through governed adapters.

The console must not create a false dependency in which:

- Loss of the console disables core radio transmission.
- Loss of the console prevents a telephone from receiving a call.
- Loss of a radio or telephone integration makes unrelated console functions unusable.
- A recording reference is treated as proof that recording actually succeeded.
- External provider health is hidden behind a normal-looking console surface.

Each integration reports its own availability, freshness, confidence, and failure state.

## Architecture invariants

1. A significant module is not isolated unless its failure can be detected, contained, restarted, and reconstructed without restarting unrelated console functions.
2. Authoritative committed state does not exist only inside a renderer or one replaceable module process.
3. The renderer does not directly retrieve operational application content from remote servers.
4. Remote platform communication is performed by controlled native services.
5. A locally reachable IPC endpoint does not become trusted merely because it is local.
6. A process restart is not recovery until required state is resynchronized and operator context is restored.
7. A degraded capability is visibly degraded; blank or stale information must not appear normal.
8. Console availability does not bypass authorization, trust, audit, or data-protection requirements.
9. Every installed component and enabled background capability has an approved operational purpose.
10. Administrative activity is attributable, recorded, and independently retained.
11. Production releases are promoted immutable artifacts, not fresh rebuilds of supposedly identical source.
12. When integrity is uncertain, trusted rebuild is preferred over undocumented repair.

## Examples

The [examples](examples/) directory contains non-production examples of machine-readable records and systemd units. They contain placeholders and must not be deployed unchanged.

## Related architecture

- [Platform Engineering Principles](../platform-engineering-principles.md)
- [External-System-Independent Observability](../external-system-independent-observability.md)
- [User-Interface Architecture](../user-interface/README.md)
- [Accessibility and Inclusive Interaction Model](../user-interface/accessibility-and-inclusive-interaction-model.md)
- [Client Experience and Accessibility Model](../user-interface/client-experience-and-accessibility-model.md)
- [Backend Services Architecture](../backend-services/README.md)
- [GIS and Mapping Architecture](../gis-and-mapping/README.md)
- [Communications Architecture](../communications/README.md)
