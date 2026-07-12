# Workstation Baseline and Trust Evidence Model

> Status: Normative target architecture.
>
> Implementation status: Machine-readable contracts and providers are not yet implemented.

## Purpose

This document defines approved workstation state, observed workstation state, drift evaluation, and the evidence supplied to the Platform Foundation for operation-specific trust decisions.

## Separation of concerns

The following are distinct:

- **Approved baseline** — the governed state the workstation is expected to have.
- **Observed state** — measured facts about the workstation now.
- **Drift evaluation** — comparison between approved and observed state.
- **Trust evidence** — normalized claims supplied to the Foundation.
- **Trust decision** — operation-specific evaluation performed by the Foundation Decision Engine.

An endpoint agent or EDR provider must not return a final platform decision such as:

```text
device_trusted: true
```

It reports evidence. The Decision Engine decides whether that evidence is sufficient for the requested operation.

## Baseline domains

The baseline includes:

- Hardware identity.
- firmware and UEFI configuration.
- Secure Boot and measured-boot policy.
- TPM identity and state.
- disk encryption.
- bootloader.
- operating-system release.
- kernel and command line.
- package and repository snapshot.
- signed console release.
- enabled services, sockets, timers, and kernel modules.
- local users, groups, privileges, and capabilities.
- systemd sandboxing.
- filesystem mounts and writable paths.
- firewall and communication profile.
- listening sockets.
- interfaces, routes, and resolvers.
- time synchronization.
- module and protocol versions.
- workspace and accessibility profiles.
- certificate and trust-anchor state.
- local storage and queue health.
- logging and telemetry.
- endpoint security.
- snapshot, rollback, and rebuild posture.
- SSH and recorder configuration.

## Approved and observed records

Approved and observed records must be separate artifacts.

The approved record is signed or otherwise integrity protected and references the release and policy that approved it.

The observed record includes:

- Observation time.
- collector identity.
- collector version.
- workstation identity.
- evidence source.
- verification method.
- freshness.
- confidence.
- raw evidence reference where retained.
- anti-replay data.
- result or measured value.

Observed state must not overwrite approved intent.

## Drift categories

Drift may be:

- Expected temporary drift.
- approved deployment-specific drift.
- low-risk informational drift.
- operationally significant drift.
- security-significant drift.
- trust-blocking drift.
- unknown or unevaluated drift.

Each category defines:

- operator effect.
- administrative response.
- alerting.
- remediation window.
- evidence requirement.
- whether protected operation is restricted.

## Evidence claims

Each trust-evidence claim should be atomic enough to retain distinct provenance and freshness.

Example claim types include:

- Secure Boot state.
- measured-boot match.
- approved firmware version.
- disk-encryption state.
- console release digest.
- kernel state.
- package-manifest match.
- service-baseline match.
- firewall-profile match.
- unexpected listener count.
- certificate health.
- time health.
- logging health.
- endpoint-security health.
- local-state integrity.
- last successful update.
- rollback availability.
- management-recorder health.
- recent security isolation.
- unresolved critical fault episode.

## Claim structure

A claim includes:

- Evidence type.
- observed value.
- expected value or policy reference where applicable.
- observation time.
- expiration or maximum age.
- verification method.
- confidence.
- source identity.
- collector identity.
- workstation identity.
- console release.
- nonce, sequence, or anti-replay value.
- supporting evidence reference.
- contradiction references.
- classification.

## Freshness

Evidence freshness is policy specific.

Examples:

- Boot measurement may remain valid for the boot instance.
- endpoint protection health may require frequent refresh.
- firewall state may require event-driven and periodic observation.
- package and release integrity may be rechecked after update and periodically.
- SSH recorder health may be required before a new administrative session.
- local queue integrity may be evaluated continuously.

Expired evidence is not silently reused.

## Contradiction handling

Providers may disagree.

The trust provider must preserve contradictory claims rather than selecting whichever is most favorable.

A required claim that is:

- Missing.
- stale.
- contradictory.
- unverifiable.
- not evaluated.

must be presented to the Decision Engine using the defined failure-safe semantics.

## Workstation trust provider

The provider:

- Normalizes evidence.
- verifies source and freshness.
- preserves provenance.
- exposes contradictions.
- references baseline and policy versions.
- supplies evidence to the Foundation.
- records provider health.

The provider does not:

- Grant authorization.
- bypass approvals.
- issue unrestricted operator sessions.
- convert EDR health into universal trust.
- hide unevaluated evidence.

## Operation-specific decisions

A workstation may be sufficient for one operation and insufficient for another.

Examples:

- Read-only cached reference access may remain available.
- viewing restricted records may require fresher evidence.
- administrative release activation may require a separate management posture.
- a high-impact operational action may require current disk, release, endpoint, logging, and time evidence.

## Evidence protection

Evidence must be:

- Attributable.
- integrity protected.
- replay resistant.
- time correlated.
- exported off-host where required.
- retained according to policy.
- independently verifiable where practical.
- provider neutral.

## Baseline changes

A baseline change requires:

- Versioned proposal.
- security and operational review.
- package and service impact.
- communication-profile impact.
- performance impact.
- accessibility impact.
- validation.
- approval.
- release association.
- rollback path.

Manual local edits do not become the new baseline automatically.
