# Provisioning, Rebuild, Lifecycle, and Recovery Model

> Status: Normative target architecture.
>
> Implementation status: Provisioning transport, filesystem layout, image tooling, and recovery service are not yet selected.

## Purpose

Every production workstation must be reproducible, continuously verifiable, updateable, recoverable, and replaceable from approved artifacts without relying on undocumented manual intervention.

## Lifecycle states

A workstation may be:

- Ordered.
- received.
- inventory verified.
- firmware prepared.
- provisioning.
- enrolled.
- validating.
- ready.
- in service.
- restricted.
- maintenance.
- isolated.
- recovery.
- rebuild required.
- decommissioning.
- decommissioned.

Transitions are attributable and recorded.

## Provisioning objective

Provisioning produces a workstation whose:

- Hardware identity is known.
- firmware policy is applied.
- boot path is verified.
- storage is encrypted.
- operating-system release is approved.
- package and console release match the manifest.
- users and services match baseline.
- firewall and communication profile are active.
- device identity and certificates are enrolled.
- time and logging are healthy.
- remote management is governed.
- workstation trust evidence is available.
- functional validation passes.

## Provisioning transport

PXE, iPXE, removable trusted media, or another controlled mechanism may be used.

Transport is not the trust boundary.

Trust depends on:

- Verified firmware state.
- signed boot artifacts.
- verified installer.
- approved repositories.
- protected enrollment.
- authenticated configuration.
- release signatures.
- auditable build record.
- post-build validation.

## Preflight

Before changing a workstation, tooling must perform a complete dependency and readiness preflight.

The preflight should identify all missing commands, packages, credentials, storage capacity, network dependencies, signing material, and services before making modifications.

It must fail before partial change when prerequisites are absent.

## Declarative configuration

Production configuration is derived from:

- Workstation baseline.
- package manifest.
- console release manifest.
- communication profile.
- hardware profile.
- workspace and accessibility profile.
- deployment-specific governed values.
- certificate and identity enrollment.
- systemd unit set.
- firewall policy.

Manual configuration may be used during investigation but must be reconciled, reverted, or incorporated through governance before return to service.

## Local recovery points

A snapshot is a local recovery point.

A backup is an independently protected copy that survives loss or compromise of the workstation or local storage.

Neither replaces the other.

Snapshots may support rapid rollback of:

- Operating-system release.
- console release.
- configuration.
- local state schema.

Snapshot use must not restore expired credentials, revoked trust, or stale protected authority without re-evaluation.

## Workstation backup scope

The workstation is not the primary backup location for authoritative platform data.

Backups may include only approved:

- Build and deployment evidence.
- configuration references.
- eligible operator drafts.
- pending and outcome-unknown action records.
- required fault evidence.
- local recovery metadata.
- diagnostic bundles.

Caches are normally reconstructed rather than backed up.

## Update

Updates follow Software Package and Release Governance.

Before activation, the workstation verifies:

- Artifact signature.
- digest.
- eligibility.
- compatibility.
- disk capacity.
- rollback point.
- local queue and action state.
- operator impact.
- maintenance authorization.

After activation, the workstation verifies:

- Boot.
- release identity.
- module startup.
- local IPC.
- remote dependency access.
- trust evidence.
- renderer policy.
- state migration.
- operator session path.
- fault and logging path.
- rollback health.

## Rollback

Rollback is permitted only to an approved release whose:

- Security status remains acceptable.
- state schema is compatible or has a governed reverse migration.
- certificates and policy remain valid.
- release artifacts remain verified.

Rollback is recorded as a release transition and may create an Operational Fault Episode.

## Repair versus rebuild

A minor understood failure may be repaired through approved automation.

Trusted rebuild is preferred when:

- Integrity cannot be established.
- unauthorized packages or services are found.
- root compromise is suspected.
- baseline drift is broad or unexplained.
- local repair history is undocumented.
- disk or filesystem integrity is uncertain.
- release activation repeatedly fails.
- recovery would require one-off manual changes.
- certificate or device identity protection is uncertain.

## Rebuild workflow

A rebuild should:

1. Place the console out of service.
2. revoke or suspend active sessions and capabilities.
3. preserve only approved recovery state and evidence.
4. isolate the workstation where required.
5. capture inventory and fault references.
6. wipe or reinitialize storage according to policy.
7. establish trusted boot and disk encryption.
8. install the approved base.
9. activate the approved console release.
10. enroll new device credentials as required.
11. restore only validated eligible local state.
12. run complete baseline, trust, network, performance, and functional checks.
13. return to service through approval.
14. record the full lifecycle event.

## Replacement workstation

The architecture should support replacing failed hardware rather than depending on prolonged repair of one console.

A replacement receives:

- Appropriate hardware profile.
- current approved release.
- deployment configuration.
- new device identity.
- current trust policy.
- required shared operational projection.

It must not inherit the old workstation's identity blindly.

## Recovery exercises

Operational validation includes periodic exercises for:

- Failed update.
- failed rollback.
- disk loss.
- filesystem corruption.
- device certificate revocation.
- complete rebuild.
- replacement hardware.
- loss of provisioning service.
- loss of internal package repository.
- restoration of eligible pending work.
- off-host evidence retrieval.

## Decommissioning

Decommissioning requires:

- Asset-state update.
- session and certificate revocation.
- local-key destruction.
- media sanitization.
- recovery-key disposition.
- removal from update and management systems.
- retention of required audit and fault evidence.
- confirmation that the workstation cannot reconnect as its prior identity.
