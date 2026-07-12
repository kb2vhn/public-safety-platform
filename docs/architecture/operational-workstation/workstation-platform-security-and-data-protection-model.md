# Workstation Platform Security and Data Protection Model

> Status: Normative target architecture.
>
> Implementation status: Hardening profile and accepted hardware baseline are not yet implemented.

## Purpose

This document defines workstation-specific operating-system hardening, local data protection, device control, and compromise containment.

## Security objective

The workstation is treated as a first-class trust boundary, but no single workstation compromise may automatically become complete platform compromise.

The workstation must minimize:

- Exposed services.
- privileges.
- executable content.
- writable system state.
- local secrets.
- remote destinations.
- persistence opportunities.
- cross-module access.
- data remnants.
- administrative ambiguity.

## Boot and platform integrity

The accepted hardware and release profile should support:

- UEFI.
- Secure Boot.
- TPM-backed device identity.
- measured boot where practical.
- approved firmware versions.
- firmware configuration protection.
- disk encryption.
- recovery-key governance.
- boot-order governance.
- disabled or controlled external boot.
- integrity evidence available to the workstation trust provider.

The architecture must distinguish evidence availability from policy sufficiency. A TPM claim is evidence; the Decision Engine determines whether it is sufficient for a requested operation.

## Operating-system composition

The system contains only approved:

- Packages.
- services.
- sockets.
- timers.
- kernel modules.
- user and group accounts.
- capabilities.
- filesystem mounts.
- writable directories.
- device permissions.
- network paths.
- scheduled jobs.

No component is included merely because it may be useful later.

## Privilege model

Separate identities should exist for:

- Restricted operator session.
- console coordinator.
- significant module services.
- native UI hosts where isolation requires.
- trust and health agents.
- update and release activation.
- logging and telemetry.
- SSH administration.

Services run with the least privilege required.

Linux capabilities, setuid binaries, privileged groups, device access, and D-Bus permissions are explicitly governed.

## Service sandboxing

systemd service hardening should be evaluated for each service, including:

- `NoNewPrivileges=`
- `ProtectSystem=`
- `ProtectHome=`
- `PrivateTmp=`
- `PrivateDevices=`
- `ProtectKernelTunables=`
- `ProtectKernelModules=`
- `ProtectControlGroups=`
- `RestrictAddressFamilies=`
- `CapabilityBoundingSet=`
- `SystemCallFilter=`
- `RestrictNamespaces=`
- `MemoryDenyWriteExecute=`
- read-only and writable path declarations
- device policy
- network namespace or egress restrictions

No setting is enabled blindly. Exceptions are documented and tested.

## Renderer containment

The renderer must not possess:

- Platform credentials.
- device private keys.
- SSH keys.
- database credentials.
- unrestricted filesystem access.
- unrestricted local IPC access.
- direct remote application-content access.
- administrative capabilities.

Renderer compromise is assumed possible and must remain contained.

## Disk encryption and local stores

Full-disk encryption is required for supported profiles unless a documented deployment constraint provides equivalent protection.

Application-level encryption may additionally be required for:

- Operator-private drafts.
- pending protected actions.
- outcome-unknown action records.
- sensitive diagnostic bundles.
- cached protected information.
- locally retained integration data.

Key lifecycle must cover boot, operator session, handoff, support, rebuild, recovery, and decommissioning.

## Swap, hibernation, and crash data

Profiles must govern:

- Swap encryption.
- hibernation permission.
- suspend behavior.
- crash dumps.
- core dumps.
- kernel dumps.
- memory capture.
- diagnostic export.

Unrestricted core dumps may contain credentials and operational data.

Production defaults should prevent or tightly govern persistent sensitive memory images.

## Clipboard, screenshots, and screen recording

Policies must define:

- Permitted clipboard content and retention.
- clearing on lock and handoff.
- screenshot availability.
- screen recording.
- remote-support viewing.
- print-screen keys.
- module-to-module copy behavior.
- classification warnings.
- diagnostic capture approval.
- storage and retention.

Accessibility needs must be considered before disabling functions globally.

## Removable media and peripherals

Profiles govern:

- USB storage.
- USB human-interface devices.
- serial adapters.
- smart-card readers.
- headsets.
- printers.
- cameras.
- microphones.
- Bluetooth.
- Wi-Fi.
- mobile-device attachment.
- firmware-updatable peripherals.

Unknown removable storage is denied by default.

Human-interface-device attacks and unauthorized adapters must be considered separately from storage devices.

## Printing and export

Printing and export are protected workflows.

A profile defines:

- Which modules may print or export.
- destination restrictions.
- classification labels.
- spool protection.
- job retention.
- failure behavior.
- operator attribution.
- approval where required.
- local temporary-file cleanup.

## Browser-like functions

The console renderer must not provide a general-purpose:

- address bar.
- download manager.
- extension system.
- password manager.
- browser synchronization.
- arbitrary certificate exception.
- developer tools path for ordinary operators.
- external protocol launcher.

Development and diagnostic functions must be absent or separately controlled in Release builds.

## Time

Reliable time is required for:

- session validity.
- certificate validation.
- action ordering.
- freshness.
- audit.
- fault correlation.
- release validation.

Time health is monitored and reported as trust evidence.

Large or unexplained time changes may restrict protected operation.

## Malware and endpoint security

An endpoint security provider may contribute evidence and response capability.

It must not become the sole trust authority.

The architecture remains provider independent and requires:

- Current provider health.
- policy version.
- evidence freshness.
- tamper state.
- isolation state.
- detection references.
- update state.
- known blind spots.

## Compromise response

The workstation must support:

- Network isolation.
- operator-visible out-of-service state.
- session revocation.
- evidence preservation.
- off-host log continuity.
- trusted diagnostic capture.
- credential and certificate revocation.
- rebuild from known-good artifacts.
- replacement workstation activation.

Manual cleaning is not the default path when integrity cannot be established.

## Decommissioning

Decommissioning requires:

- Removal from inventory.
- certificate revocation.
- local key destruction.
- approved media sanitization.
- recovery-key disposition.
- retention of required audit and fault evidence.
- confirmation that no operator or platform session remains active.
