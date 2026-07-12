# Lifecycle, Snapshot, Backup, and Update Model

> **Status:** Draft normative architecture.
>
> **Implementation status:** Strategy defined; filesystem, storage, and update tooling not yet selected.

## Purpose

A production workstation is continuously managed, continuously verified, and continuously recoverable. It should normally be rebuilt from approved artifacts rather than repaired through undocumented manual changes.

## Snapshots are not backups

A snapshot is a local recovery point for rapid rollback. A backup is an independently protected copy that survives workstation or local-storage loss.

Neither replaces the other.

## Snapshot requirements

The selected storage design should support automated recovery points:

- Before operating-system and package updates.
- Before configuration and security-policy deployment.
- Before client or driver changes.
- On a governed periodic schedule where the storage and workload justify it.
- Before approved high-risk maintenance.

Each snapshot record must include:

- Snapshot identifier.
- Creation time and trigger.
- Baseline and release versions.
- Retention class.
- Verification state.
- Rollback eligibility.
- Expiry or deletion time.

Snapshots must be bounded. Uncontrolled snapshot growth is prohibited.

## Backup scope

The workstation should contain little unique state. Prefer central, declarative, or reproducible state over backing up entire endpoints.

Potentially protected workstation-specific state includes:

- Bounded unsent audit, telemetry, or location persistence spool.
- Approved local recovery metadata.
- Explicitly approved operator preferences not stored centrally.
- Unique enrollment records only when they cannot be safely reissued.

The following should normally be regenerated rather than backed up:

- Operating-system files.
- Installed packages.
- Declarative configuration.
- Offline map packages and ordinary caches.
- Application binaries.

Session secrets, authorization leases, and reusable private credentials must not be placed into ordinary workstation backups. Key recovery requires a separate cryptographic design.

## Backup protection

Backups must have:

- Encryption in transit and at rest.
- Access separation from ordinary workstation administration.
- Retention and deletion policy.
- Integrity verification.
- Restore testing.
- Protection from endpoint-originated deletion where practical.

## Controlled update pipeline

```text
Upstream packages and source
          |
          v
Controlled intake and internal mirror
          |
          v
Build and integration validation
          |
          v
Signed, coherent release snapshot
          |
          v
Pilot deployment
          |
          v
Phased production deployment
```

Production workstations must not track public repositories directly or assemble independent package combinations.

Updates require:

- Dependency and package-manifest review.
- Security and performance testing.
- Snapshot or recovery-point creation.
- Health validation after deployment.
- Automatic halt conditions.
- Tested rollback or trusted rebuild.
- Defined emergency security-update procedure.

## Recovery preference

Use rollback for a known, recent, non-compromise failure when the snapshot is verified. Use trusted rebuild when compromise, unexplained drift, integrity failure, or uncertain state is possible.
