# Workstation Baseline and Trust Assertion Model

> **Status:** Normative CAD target architecture
>
> **Implementation status:** Machine-readable contracts and providers are not yet implemented

## Purpose

Define approved workstation state, observed workstation state, drift assessment,
and the bounded workstation trust assertions supplied to the Platform Foundation
for exact-operation authorization decisions.

This document deliberately avoids using **evidence** as a generic record type.
The Platform Foundation already distinguishes exact record classes such as
Decision Supporting Records, Decision Records, Approval Action Records,
Assurance Artifacts, audit records, and lifecycle events.

## Separation of Concerns

The following are distinct:

- **Approved Baseline Artifact** — the governed workstation state expected for a
  specific release and deployment profile.
- **Workstation Observation Record** — attributable measured facts about the
  workstation at a specific time.
- **Drift Assessment Record** — the comparison between the approved baseline and
  current observation records.
- **Workstation Trust Assertion** — a normalized, bounded claim with provenance,
  freshness, and contradiction handling.
- **Decision Supporting Record** — the Foundation-owned record that binds an
  applicable trust assertion to an exact authorization decision context.
- **Authorization Decision** — the Foundation result for one exact requested
  operation.

An endpoint agent, EDR provider, local workstation component, or renderer must
not return a final platform result such as:

```text
device_trusted: true
```

It produces observations or bounded assertions. The Foundation determines
whether they are current, applicable, and sufficient for the exact requested
operation.

## Baseline Domains

The Approved Baseline Artifact may govern:

- Hardware identity.
- Firmware and UEFI configuration.
- Secure Boot and measured-boot policy.
- TPM identity and state.
- Disk encryption.
- Bootloader.
- Operating-system release.
- Kernel and command line.
- Package and repository snapshot.
- Signed console release.
- Enabled services, sockets, timers, and kernel modules.
- Local users, groups, privileges, and capabilities.
- Systemd sandboxing.
- Filesystem mounts and writable paths.
- Firewall and communication profile.
- Listening sockets.
- Interfaces, routes, and resolvers.
- Time synchronization.
- Workstation component and protocol versions.
- Workspace and accessibility profiles.
- Certificate and trust-anchor state.
- Local storage and queue health.
- Logging and telemetry.
- Endpoint security.
- Snapshot, rollback, and rebuild posture.
- SSH and session-recorder configuration.

## Approved and Observed Records

Approved baseline artifacts and observation records are separate artifacts.

The Approved Baseline Artifact is signed or otherwise integrity protected and
references the release, policy, and deployment profile that approved it.

A Workstation Observation Record includes:

- Observation time.
- Collector identity and version.
- Workstation identity.
- Observation source.
- Verification method.
- Freshness.
- Confidence.
- Raw diagnostic-record reference when retained.
- Anti-replay value.
- Measured value or result.

Observed state must not overwrite approved intent.

## Drift Categories

Drift may be:

- Expected temporary drift.
- Approved deployment-specific drift.
- Low-risk informational drift.
- Operationally significant drift.
- Security-significant drift.
- Trust-blocking drift.
- Unknown or unevaluated drift.

Each category defines:

- Operator effect.
- Administrative response.
- Alerting.
- Remediation window.
- Required observation or assertion type.
- Whether protected operation is restricted.

## Workstation Trust Assertions

Each assertion should be atomic enough to retain distinct provenance,
freshness, and contradiction state.

Example assertion types include:

- Secure Boot state.
- Measured-boot match.
- Approved firmware version.
- Disk-encryption state.
- Console release digest.
- Kernel state.
- Package-manifest match.
- Service-baseline match.
- Firewall-profile match.
- Unexpected listener count.
- Certificate health.
- Time health.
- Logging health.
- Endpoint-security health.
- Local-state integrity.
- Last successful update.
- Rollback availability.
- Management-recorder health.
- Recent security isolation.
- Unresolved critical fault episode.

## Assertion Structure

A Workstation Trust Assertion includes:

- Assertion type and version.
- Observed value.
- Expected value or policy reference when applicable.
- Observation time.
- Expiration or maximum age.
- Verification method.
- Confidence.
- Source and collector identity.
- Workstation identity.
- Console release.
- Nonce, sequence, or anti-replay value.
- Supporting observation-record references.
- Contradiction references.
- Classification.

## Freshness

Freshness is policy and operation specific.

Examples:

- Boot measurement may remain current for one boot instance.
- Endpoint-protection health may require frequent refresh.
- Firewall state may require event-driven and periodic observation.
- Package and release integrity may be checked after update and periodically.
- SSH recorder health may be required before a new administrative session.
- Local queue integrity may be evaluated continuously.

An expired assertion must not be silently reused.

## Contradiction Handling

Providers may disagree.

The workstation trust provider must preserve contradictory observations and
assertions rather than selecting whichever result is most favorable.

A required assertion that is missing, stale, contradictory, unverifiable, or
unevaluated must reach the Foundation through defined failure-safe semantics.

## Workstation Trust Provider

The provider:

- Normalizes observation records into bounded assertions.
- Verifies source and freshness.
- Preserves provenance.
- Exposes contradictions.
- References baseline and policy versions.
- Supplies assertions for creation of Foundation Decision Supporting Records.
- Records provider health.

The provider does not:

- Grant authorization.
- Bypass Foundation Approval Request, Approval Action, stage-evaluation, or
  finalization controls.
- Issue unrestricted operator sessions.
- Convert EDR health into universal trust.
- Hide unevaluated or contradictory assertions.

## Operation-Specific Decisions

A workstation may be sufficient for one operation and insufficient for another.

Examples:

- Read-only cached reference access may remain available.
- Viewing restricted records may require fresher workstation assertions.
- Administrative release activation may require a separate management posture.
- A high-impact operational action may require current disk, release, endpoint,
  logging, and time assertions.

## Protection

Approved Baseline Artifacts, Workstation Observation Records, Drift Assessment
Records, Workstation Trust Assertions, and resulting Decision Supporting Records
must receive protection appropriate to their exact record type. Applicable
controls include:

- Attribution.
- Integrity protection.
- Replay resistance.
- Time correlation.
- Off-host export when required.
- Policy-based retention.
- Independent verification where practical.
- Provider neutrality.

## Baseline Changes

A baseline change requires:

- Versioned proposal.
- Security and operational review.
- Package and service impact.
- Communication-profile impact.
- Performance impact.
- Accessibility impact.
- Validation.
- Governed authorization and, when policy requires, a finalized Foundation
  Approval Request.
- Release association.
- Rollback path.

Manual local edits do not become the new baseline automatically.
