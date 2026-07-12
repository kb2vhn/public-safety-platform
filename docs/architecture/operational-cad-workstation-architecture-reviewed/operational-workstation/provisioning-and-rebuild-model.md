# Provisioning and Rebuild Model

> **Status:** Draft normative architecture.
>
> **Implementation status:** PXE/iPXE and Ansible are candidate mechanisms; no production provisioning service is yet accepted.

## Purpose

Every production workstation must be reproducible from approved source artifacts, package manifests, and declarative configuration without relying on undocumented manual intervention.

## Preferred provisioning path

A controlled PXE, iPXE, or equivalent network-boot workflow should be evaluated for initial deployment and trusted rebuild.

Network boot is transport, not the trust boundary. The trust boundary depends on verified firmware state, signed boot artifacts, verified installer content, approved repositories, protected enrollment, and auditable build records.

## Provisioning sequence

1. Place the device on an approved provisioning network.
2. Identify and authorize the hardware.
3. Boot a verified installer or recovery environment.
4. Apply the approved partition, encryption, and boot policy.
5. Install the approved coherent operating-system release.
6. Apply the approved package manifest.
7. Apply declarative workstation configuration.
8. Configure host firewall and management access.
9. Enroll device certificates, trust evidence, EDR, logging, and monitoring.
10. Install the approved client and workspace profile.
11. Validate the observed baseline.
12. Admit the workstation to pilot or production only after successful attestation.

## Declarative configuration

Ansible or an equivalent tool may define:

- Packages and removals.
- Services, sockets, and timers.
- i3wm and workspace profile.
- Firewall policy.
- OpenSSH policy.
- Logging and monitoring.
- EDR integration.
- Certificates and trust anchors.
- Time synchronization.
- Client configuration.
- Snapshot and update policy.
- Integrity verification.

Playbooks, roles, inventories, and YAML data must be version controlled, reviewed, tested, idempotent, environment-aware, auditable, and free of plaintext secrets.

## Secret handling

Provisioning secrets must use an approved protected mechanism such as encrypted automation data, a secret service, TPM-backed enrollment, one-time tokens, or short-lived bootstrap credentials.

Bootstrap secrets should expire or become unusable after enrollment.

## Build record

Each build must record:

- Device and hardware identity.
- Firmware and boot evidence.
- Image and kernel version.
- Package-manifest version.
- Configuration-baseline version.
- Workspace-profile version.
- Provisioning source and timestamp.
- Applied policy versions.
- Enrollment results.
- Validation evidence.
- Approval and environment state.

## Rebuild rule

Compromise, unexplained drift, integrity failure, or uncertain state requires trusted rebuild unless a documented incident-response decision establishes another safe path.
