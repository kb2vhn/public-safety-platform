# Workstation Trust Evidence Model

> **Status:** Draft normative architecture.
>
> **Implementation status:** Evidence contract proposed; providers and enforcement are not yet implemented.

## Purpose

The Workstation Trust Provider normalizes current endpoint evidence. The Foundation Decision Engine determines whether that evidence is sufficient for a specific operation.

## Evidence sources

Evidence may include:

- Hardware and TPM-backed device identity.
- Secure Boot and measured-boot state.
- Firmware policy and version.
- Disk-encryption state.
- Approved image and kernel state.
- Package and file-integrity state.
- Firewall and network-profile compliance.
- Configuration-baseline compliance.
- Certificate and trust-anchor health.
- EDR or endpoint-security health.
- Logging, monitoring, and time-synchronization health.
- Update, snapshot, and recovery posture.

## Vendor neutrality

CrowdStrike, Microsoft Defender for Endpoint, SentinelOne, or another approved product may provide evidence only where the selected product supports the approved workstation profile.

No product becomes the sole source of device trust. Provider integrations normalize evidence into a platform-owned contract and remain replaceable.

## Evidence contract

Each statement should identify:

- Statement and device identifiers.
- Evidence type and schema version.
- Collector and verifier identities.
- Observed value and supporting reference.
- Observation, issue, and expiry times.
- Policy or baseline version.
- Confidence and verification method.
- Nonce, sequence, or equivalent anti-replay context where required.
- Signature or protected transport context.

## Critical correction

Evidence providers should not self-assert a final `device_trusted: true` result as authoritative.

They report facts such as `secure_boot_enabled`, `edr_sensor_current`, or `package_manifest_matches`. The Decision Engine combines those facts with the requested operation, governed scope, policy, risk, session, and authorization context.

## Failure behavior

Stale, missing, contradictory, replayed, or unverifiable evidence must be treated explicitly. A required item that cannot be evaluated fails safely for the protected operation.

See [trust-evidence.example.yaml](examples/trust-evidence.example.yaml).
