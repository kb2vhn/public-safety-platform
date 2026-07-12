# Software Package and Release Governance

> Status: Normative target architecture.
>
> Implementation status: Release tooling, repository infrastructure, and approved package set are not yet implemented.

## Purpose

This document governs every package and production console release.

The workstation is intentionally composed. Nothing is installed, enabled, or retained merely because it may be useful later.

## Package governance

Every explicit and transitive package must identify:

- Package name and version.
- Package source.
- repository snapshot or build source.
- cryptographic digest.
- upstream project.
- license.
- explicit or dependency inclusion reason.
- requiring service, workflow, control, or accessibility need.
- classification.
- optional features enabled and disabled.
- files and directories introduced.
- services, sockets, timers, kernel modules, hooks, and scheduled tasks introduced.
- users, groups, capabilities, and privileged paths introduced.
- network behavior.
- runtime CPU, memory, disk, and startup impact.
- update and vulnerability-review requirements.
- removal impact.
- owner and approval.
- first and last release containing it.

## Package classifications

A package may have one or more classifications:

- Runtime.
- build.
- maintenance.
- recovery.
- accessibility.
- diagnostics.
- security.
- hardware support.
- development-only.
- test-only.

Development and test packages must not appear in a production release unless separately justified for production.

## Arch Linux use

Arch Linux is the initial reference base because it permits a small, deliberate system composition.

Production consoles must not follow uncontrolled public rolling repository state.

An administrator must not perform an unrestricted production:

```text
pacman -Syu
```

against current public repositories.

Iron Signal Systems or the deploying authority must provide governed release snapshots.

## Third-party and AUR packages

A production console must not consume packages directly from the AUR.

A required third-party package must be:

- Reviewed.
- built in controlled infrastructure.
- dependency pinned.
- source and build inputs recorded.
- signed.
- placed in an approved internal repository.
- vulnerability monitored.
- tested with the complete release.
- owned throughout its lifecycle.

## Release unit

A console release is a coherent set that may include:

- Bootloader.
- kernel.
- firmware.
- graphics stack.
- GTK and WebKitGTK.
- Go binaries.
- UI resources.
- systemd units.
- firewall policy.
- package set.
- workstation baseline.
- communication profile.
- workspace profile.
- accessibility profile.
- protocol versions.
- database or local-state migrations.
- trust-evidence policy.
- rollback instructions.
- release manifest and signatures.

Partial package updates outside the release process are prohibited unless an emergency process explicitly authorizes and validates them.

## Release channels

The required channels are:

```text
Daily
  ↓
Pre-production
  ↓
Release
```

### Daily

Daily receives automated current builds and performs:

- Reproducible build checks.
- static analysis.
- unit and integration tests.
- dependency and vulnerability analysis.
- module compatibility tests.
- workstation image construction.
- startup tests.
- renderer policy tests.
- local IPC tests.
- failure injection.
- restart and state-restoration tests.
- baseline and communication-profile validation.

Daily artifacts are not deployed to ordinary production consoles.

### Pre-production

Pre-production receives a selected immutable Daily artifact and validates it on representative:

- Hardware.
- graphics.
- displays.
- input devices.
- network conditions.
- authentication flows.
- accessibility configurations.
- datasets.
- operator workflows.
- shift handoff.
- module failure and recovery.
- update and rollback.
- remote administration.
- degraded operation.

### Release

Release receives the exact approved Pre-production artifact.

The artifact is promoted, not rebuilt.

The digest remains identical across promotion:

```text
Daily artifact digest
        =
Pre-production candidate digest
        =
Release artifact digest
```

## Emergency release

An emergency security or operational release may shorten scheduling and observation periods, but it must not bypass:

- Source and dependency integrity.
- build provenance.
- signature.
- minimum compatibility tests.
- startup and rollback validation.
- fault-containment checks relevant to the change.
- approval.
- deployment tracking.

## Release manifest

The signed release manifest includes:

- Release identifier.
- channel.
- artifact digests.
- source revision.
- build environment reference.
- package snapshot.
- module versions.
- protocol versions.
- configuration versions.
- security fixes.
- known issues.
- minimum hardware.
- migration requirements.
- rollback compatibility.
- approvals.
- activation and expiration policy.
- superseded releases.

## Activation

Release activation must:

1. Verify signatures and digests.
2. verify workstation eligibility.
3. verify disk and recovery capacity.
4. preserve required local recovery state.
5. place the console into appropriate maintenance state.
6. activate the coherent release.
7. restart or reboot as required.
8. run post-activation validation.
9. report health.
10. roll back automatically or procedurally when validation fails.
11. record the complete change.

## Module hot update

An independently restartable module may be updated without restarting the entire console only when:

- The module boundary is real.
- Local IPC and platform protocol compatibility are declared.
- shared library changes are not required.
- state migration is safe.
- rollback remains available.
- operator impact is explicit.
- the signed release policy permits independent module activation.

Kernel, WebKitGTK, graphics-stack, libc, systemd, or broadly shared dependency changes normally require a coherent console release.

## Retention

Internal repositories must retain enough approved history to:

- Rebuild a deployed release.
- roll back.
- investigate a fault.
- reproduce a security issue.
- verify package provenance.
- support legal or contractual evidence.

## Unsupported release

A console on an unsupported or revoked release must enter the governed restricted, maintenance, or out-of-service state defined by policy.

The console must not silently continue protected operation indefinitely on an untrusted release.
