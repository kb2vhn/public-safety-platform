# Software Supply-Chain and Release-Integrity Model

> **Owner:** Iron Signal Systems
>
> **Scope:** Platform Foundation, modules, services, workstations, migrations,
> tools, deployment artifacts, and supporting build systems
>
> **Document status:** Normative Platform architecture
>
> **Implementation status:** Release-integrity contract only

## Purpose

Establish a continuous integrity chain from authorized source through the exact
artifact running in an accepted deployment.

A release is not accepted merely because the source repository is trusted or a
binary was built successfully.

Installed-host and runtime integrity are separately governed by the
[Host Software, Configuration, and Runtime-Integrity Model](host-software-configuration-and-runtime-integrity-model.md).
The release SBOM and manifest must be reconcilable with that host baseline.

## Required Integrity Chain

```text
authorized source
→ reviewed change
→ protected source reference
→ controlled dependency resolution
→ isolated build
→ test and assurance evidence
→ SBOM
→ provenance
→ signed release manifest and artifacts
→ release authorization
→ promotion by digest
→ deployment verification
→ runtime inventory
→ vulnerability response
→ governed rollback or retirement
```

## Source Integrity

Production source must have:

- Version control.
- Protected accepted branches or tags.
- Reviewed material changes.
- Exact commit and tree identity.
- No production build from an uncommitted or unexplained dirty tree.
- No mutable external source reference.
- Pinned automation and build actions.
- Retained review and gate evidence.
- Separate experimental and accepted production paths.

Emergency changes may reduce scheduling delay, but they must not bypass source
identity, review evidence, testing of the affected boundary, provenance,
artifact signing, or rollback readiness.

## Dependency Governance

Every direct and transitive dependency, build tool, CI action, database
extension, workstation component, and deployment package must be discoverable.

Required dependency metadata includes:

- Name and ecosystem.
- Exact version.
- Source.
- Cryptographic digest where available.
- License.
- Supplier or maintainer.
- Reason for use.
- Direct or transitive status.
- Update policy.
- Known vulnerability state.
- Supported-platform impact.
- Replacement or removal path.
- Last review date.

Production builds must not use floating tags or unconstrained versions.

For operating-system and deployment packages, the accepted record must also
bind the exact package artifact SHA-256 digest, repository and signing identity,
package transaction, package-manager identity, and installed-file manifest. The
exact package artifact must be staged in an accepted controlled cache or
immutable repository snapshot before installation, signature-verified, hashed,
and retained or independently retrievable by immutable identity. A package name
and version without artifact and installation evidence is not a complete
supply-chain record.

A dependency addition requires review. A dependency must not be added for
trivial functionality when a simple maintained implementation is safer and more
understandable.

Abandoned dependencies require replacement, isolation, maintained fork,
explicit ownership, or governed exception.

## SBOM

The project must generate and retain applicable:

- Source-resolution SBOM.
- Built-artifact SBOM.
- Deployment-package SBOM.
- Workstation-package SBOM.
- Database extension and migration inventory.
- Deployed-runtime inventory.
- Material build-toolchain inventory.

Each SBOM must identify:

- Exact artifact digest.
- Release identifier.
- Source commit and tree.
- Build identity.
- Generation tool and version.
- Target platform.
- Component relationships.
- Completeness status.
- Generation time.
- Authentication or signature state.

An SBOM is evidence, not acceptance. Gates must detect missing dependencies,
undeclared binaries, unapproved licenses, dependency drift, artifact mismatch,
and vulnerabilities requiring disposition.

## Build Isolation and Provenance

Candidate and production builds must use controlled build workers.

Formal releases should target controls equivalent to the SLSA Build Level 3
properties current at the time of adoption:

- Hosted or centrally controlled build execution.
- Build-platform-generated authenticated provenance.
- Isolation between build runs.
- Build steps cannot access provenance-signing secret material.
- Downstream authenticity verification.

Iron Signal must not claim a formal SLSA level until the exact specification,
builder, provenance, and verification evidence establish that claim.

Build provenance must identify:

- Builder identity.
- Build definition.
- Source inputs.
- Dependency inputs.
- Parameters.
- Start and completion time.
- Resulting artifact digests.
- Build platform.
- Invocation and environment details safe to retain.

## Reproducibility and Hermeticity

Formal release builds must prove or document:

- Pinned toolchain.
- Enumerated inputs.
- Controlled time, locale, architecture, and environment effects.
- Network access denied or explicitly allowlisted.
- No hidden retrieval of mutable dependencies.
- Generated files reproducible.
- Migration bundles identical to those tested.
- No embedded developer paths, usernames, secrets, or uncontrolled timestamps.
- Independent clean-worker rebuild result.

When byte-for-byte reproducibility is not possible, the release must identify
all accepted nondeterministic fields and prove normalized equivalence.

## Release Bundle

The accepted release bundle must contain or reference:

- Application binaries.
- Workstation packages.
- Database migrations and manifests.
- Configuration schema.
- SBOMs.
- Provenance statements.
- Artifact signatures.
- Signed release manifest.
- Compatibility declaration.
- Deployment profile.
- Test and assurance summary.
- Standards-conformance status.
- Known limitations.
- Vulnerability disposition.
- Upgrade, rollback, recovery, and retirement procedures.
- Support dates.
- Initial host-software and configuration baseline requirements.
- Accepted package, `/etc`, and runtime-integrity manifest schemas.

The signed release manifest must bind every included artifact by digest.

## Signing and Trust

Signing must use:

- Protected signing identities.
- Separation between ordinary build steps and signing authority.
- Defined key custody.
- Rotation.
- Revocation.
- Compromise response.
- Verification at promotion and deployment.

A valid signature does not make a malicious or incorrect artifact acceptable;
it proves only the signer and integrity properties established by the accepted
signing process.

## Promotion by Digest

Artifacts must be built once, tested, accepted, and promoted by digest.

```text
built once
→ tested
→ accepted
→ promoted
→ deployed
```

Production must not receive an untracked rebuild from nominally equivalent
source.

## Deployment Verification

Before installation and startup, verify:

- Artifact digest.
- Signature.
- Provenance authenticity.
- Release authorization.
- SBOM and release-manifest binding.
- Configuration compatibility.
- Migration compatibility.
- Trust roots and revocation state.
- Deployment profile.
- Absence of unauthorized substitution.
- Package-manager, package-database, trust-store, and host-baseline identity.
- Installed package artifact, installed-file, `/etc`, and runtime correlation.

Runtime inventory must make the actually deployed version and digest observable.

## Vulnerability and Compromise Response

The model must define:

- Vulnerability intake.
- Component exposure analysis.
- Exploitability and consequence assessment.
- VEX or equivalent status where used.
- Remediation priority.
- Emergency build and release path.
- Affected-release identification.
- Operator notification.
- Artifact revocation.
- Signing-key compromise response.
- Source-control compromise response.
- Build-system compromise response.
- Trusted rebuild.
- Regression additions.
- Root-cause and recurrence-prevention evidence.

## Release Gate

A production release fails when:

- Source identity is unknown.
- The tree is dirty or unexplained.
- Required review is absent.
- A dependency is unpinned or unaccounted.
- SBOM is missing or does not match the artifact.
- Provenance is missing, invalid, or unverifiable.
- Artifact signature is missing or invalid.
- Release manifest does not bind every required artifact.
- Test evidence applies to a different artifact.
- A critical vulnerability lacks accepted disposition.
- Migration or configuration compatibility is unknown.
- Rollback and trusted rebuild are unavailable.
- The release cannot generate a signed initial package and host-configuration baseline.
- The installed package, `/etc`, and runtime state cannot be reconciled to the
  release manifest.
- Required package, executable, library, and configuration reputation-policy
  dispositions are absent, associated with the wrong digest, or unresolved
  without an accepted policy reason.
- Sensitive configuration hashes or content were disclosed to an external
  reputation provider without explicit authorization.

## External Baselines

The implementation should map this model to the accepted final version of NIST
SP 800-218 Secure Software Development Framework, applicable CISA SBOM minimum
elements, and the selected SLSA specification. Exact versions and mappings must
be retained in the Platform compliance and traceability records.
