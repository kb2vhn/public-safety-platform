# Workstation Baseline Manifest Model

> **Status:** Draft normative architecture.
>
> **Implementation status:** Proposed machine-readable contract.

## Purpose

The baseline manifest describes both the approved workstation state and the observed state needed for drift and trust evaluation.

## Required domains

- Hardware and firmware identity.
- Boot and disk-encryption state.
- Operating-system image and kernel.
- Package and repository state.
- Enabled services, sockets, timers, and modules.
- Local users, groups, privileges, and administrative boundaries.
- Firewall and communication-profile versions.
- Listening sockets, interfaces, routes, and resolvers.
- Client and workspace profile versions.
- Certificate and trust-anchor state.
- EDR, logging, monitoring, integrity, and time-service health.
- Snapshot, backup, update, and last-attestation state.

## Approved versus observed state

The approved baseline and observed inventory must remain distinct.

An endpoint must not claim compliance merely by emitting its own desired values. A verifier compares signed or otherwise protected observed evidence with the approved baseline and records the result.

## Drift handling

Drift must be classified at least as:

- Expected and approved.
- Informational.
- Degraded.
- Untrusted.
- Isolation required.
- Rebuild required.

Material drift must not be silently normalized into the baseline.

See [workstation-baseline.example.yaml](examples/workstation-baseline.example.yaml).
