# Host Software, Configuration, and Runtime-Integrity Model

> **Owner:** Iron Signal Systems
>
> **Scope:** Platform Foundation hosts, CAD service nodes, database nodes,
> Operational Workstations, integration nodes, build workers, recovery hosts,
> and other systems included in an accepted deployment profile
>
> **Document status:** Normative Platform architecture
>
> **Implementation status:** Integrity-baseline contract only

## Purpose

Establish a cryptographically verifiable record of the software, packages,
configuration objects, trust material, and critical runtime state installed on
an Iron Signal system.

An SBOM identifies components and relationships. It does not, by itself, prove
that the expected package artifact was installed, that the package manager and
its trust database were not altered, that a file under `/etc` remains unchanged,
or that the running host matches the accepted release.

This model therefore requires an immutable initial baseline, signed authorized
change records, continuous comparison, reputation evidence, and controlled
re-baselining.

## Governing Principles

1. The first accepted host state is preserved and never overwritten.
2. Every accepted change is appended as a new signed baseline generation.
3. Package identity and installed-file identity are both recorded.
4. The package manager, package database, trust store, boot chain, and integrity
   tooling are included in the baseline rather than trusted implicitly.
5. Every regular file under `/etc` receives a SHA-256 content digest unless an
   accepted technical limitation is explicitly recorded. The manifest records
   the algorithm identifier and may add a stronger approved digest without
   removing the comparable SHA-256 value.
6. Directories, symbolic links, devices, sockets, and other non-regular objects
   are recorded by type and security-relevant metadata.
7. External reputation checks submit hashes only by default.
8. Configuration files, credentials, keys, certificates, internal identifiers,
   and other host content are never uploaded automatically to an external
   service.
9. A missing reputation result is `UNKNOWN`, not trusted and not malicious.
10. Integrity alerts do not authorize automated destructive remediation of an
    operational CAD host.

## Initial Host Baseline

The initial baseline must be created after the accepted operating-system and
Platform installation is complete but before the host is admitted to an
accepted deployment pool.

The baseline must identify:

- Host identity and deployment role.
- Operating-system distribution, edition, version, and architecture.
- Kernel, boot loader, firmware, secure-boot state, and initramfs identity where
  applicable.
- Exact Platform release, deployment profile, and environment identity.
- Baseline generation identifier and parent generation.
- Collection tool name, version, configuration, and digest.
- Trusted time source and collection timestamps.
- Package repository configuration and enabled sources.
- Package-signing trust roots and current trust-database identity.
- Package-manager executable, libraries, configuration, hooks, database, cache,
  and verification tooling.
- Complete installed-package inventory.
- Complete applicable installed-file inventory.
- Complete `/etc` object inventory.
- Enabled services, sockets, timers, scheduled tasks, drivers, kernel modules,
  and startup entries.
- Local accounts, groups, privileged memberships, and accepted service
  identities without retaining credential secrets.
- Firewall, mandatory-access-control, audit, logging, time, certificate, and
  remote-management configuration identities.
- Baseline manifest digest and signature.

## Package Artifact and Installation Records

Every installed package is recorded individually, including diagnostic and
administrative packages. This includes packages that provide commands such as
`htop` and `top`, the package that owns each command, the package manager itself,
and all package-manager dependencies.

A package record must contain, where available:

```text
package name
package epoch, version, and release
architecture
supplier and repository
repository snapshot or metadata identity
package signing identity and verification result
package artifact SHA-256 digest
installation transaction identifier and time
reason: required | dependency | diagnostic | administrative | temporary
owning deployment profile or exception
installed-file manifest digest
package database record digest
vulnerability and reputation disposition
```

The package artifact SHA-256 digest must be calculated from the exact package
archive or transport artifact used for installation when it is retained or can
be deterministically retrieved from the accepted repository snapshot.

When the package artifact is not available after installation, the baseline must
record that limitation and retain the repository metadata, signature evidence,
transaction record, installed-file hashes, and other evidence needed to
reconstruct package identity. A package name and version alone are insufficient.

### Installed-File Records

For every package-owned regular file where collection is technically supported,
record:

- Absolute path.
- Owning package.
- SHA-256 content digest.
- File size.
- Object type.
- Owner and group.
- Permission mode.
- POSIX ACL and extended-attribute digest where applicable.
- Mandatory-access-control label where applicable.
- File capabilities.
- Package-declared configuration-file status.
- Package-supplied expected digest where available.
- Current installed digest.
- Modification and baseline timestamps.

This permits independent detection of:

- A substituted package artifact.
- A changed executable with an unchanged package database.
- A package database altered to conceal a file change.
- An unexpected local replacement.
- A legitimate configuration divergence requiring authorization.

## `/etc` Configuration Integrity Inventory

Every object under `/etc` must be enumerated recursively.

For every regular file, record:

- Absolute path.
- SHA-256 content digest.
- Size.
- Owner and group.
- Permission mode.
- ACL, extended-attribute, file-capability, and security-label digests where
  applicable.
- Owning package, or `LOCAL_UNOWNED` when no package owns it.
- Secret-bearing classification.
- Expected mutability classification.
- Accepted generator or management authority.
- Baseline generation and last accepted change record.

For non-regular objects, record the applicable object type and metadata. For a
symbolic link, include the link text and resolved-target identity without
silently replacing the link with the target file in the inventory.

The `/etc` inventory must include hidden files, drop-in directories, package
manager configuration, trust stores, service definitions, environment files,
scheduled tasks, network configuration, logging configuration, database and
service configuration, and local policy files.

Frequently changing machine-generated files require an explicit mutability
contract. They must not be silently excluded merely because they change often.
The contract must define the authorized writer, allowed fields or generation
pattern, comparison method, retention, and alert threshold.

## External Reputation and Malware Intelligence

Every eligible package artifact, package-owned executable or library, and
regular file under `/etc` must receive a reputation-check disposition. The
disposition records whether its SHA-256 digest was queried against VirusTotal or
another accepted reputable multi-engine or software-reputation service, or why
an external query was not performed.

Controlled disposition values include:

```text
QUERIED_FOUND
QUERIED_NOT_FOUND
QUERY_PROHIBITED_BY_POLICY
QUERY_DEFERRED_PROVIDER_UNAVAILABLE
QUERY_DEFERRED_RATE_LIMIT
LOCAL_INTELLIGENCE_ONLY
NOT_ELIGIBLE
```

A deferred disposition must be reconciled later or converted to an accepted
policy disposition. Missing disposition is not permitted.

Hash-only lookup is the default and must retain:

- Provider.
- Query time.
- Queried SHA-256 digest.
- Found or not-found state.
- Detection and engine counts where supplied.
- Reputation, signing, prevalence, and first-seen information where supplied.
- Provider response identity or digest where practical.
- Final Iron Signal disposition.

The external request must contain only the digest and provider-required protocol
metadata by default. It must not include the local path, hostname, deployment
role, organization, package reason, internal release name, or other host context
unless an accepted disclosure policy explicitly requires and authorizes it.
Because a hash can still reveal the presence of known content, providers,
network routes, logging, retention, and query brokerage require security and
privacy review. A central controlled lookup broker with caching and an auditable
query ledger is preferred over direct queries from operational hosts.

A hash lookup result is supporting evidence only:

- `NOT_FOUND` does not prove safety.
- A clean result does not replace package signature, provenance, vulnerability,
  or local integrity verification.
- A detection requires triage and must not be dismissed solely as a false
  positive.
- Reputation-service unavailability must not block safe boot or cause loss of
  CAD service; queued queries and later reconciliation are acceptable.

### Content-Submission Prohibition

The following must never be uploaded automatically to VirusTotal or another
external reputation service:

- Any file under `/etc`.
- Private keys, shared secrets, tokens, passwords, or credential material.
- Internal certificates or trust bundles not already intentionally public.
- Files containing internal hostnames, addresses, topology, account names, or
  operational configuration.
- CAD data, logs, evidence, database content, backups, or workstation caches.
- Proprietary Iron Signal artifacts unless a separately approved release and
  disclosure decision permits it.

Hashes of `/etc` regular files may be submitted for hash-only lookup. Because
most local configuration files are unique, `NOT_FOUND` is expected and does not
change the local comparison requirement.

Any upload of an unknown sample requires separate human authorization,
classification review, legal and disclosure review, secret scanning, and an
explicit record of what was released and why. Upload permission must never be
inferred from permission to perform hash lookup.

Where external lookup is prohibited or unavailable, use accepted local
anti-malware engines, internal reputation caches, package-signature validation,
known-good repository metadata, and offline intelligence feeds. Local scanning
results are retained with engine, signature-set, policy, time, and verdict.

## Baseline Generations and Authorized Change

The initial baseline is generation zero. It is immutable.

Every accepted package installation, removal, upgrade, downgrade, configuration
change, certificate rotation, key rotation, kernel change, service change, or
repair creates a new generation that records:

- Parent generation.
- Change request or incident identifier.
- Authorizing identity.
- Implementing identity or automation.
- Before and after object identities.
- Package transaction and repository snapshot.
- Updated SHA-256 records.
- Reputation and malware-scan results.
- Test and rolling-maintenance evidence.
- Required reboot or service restart.
- Rollback material and expiration.
- Collection-tool and manifest identity.
- Signature and acceptance authority.

A current baseline must never be produced by simply deleting evidence of an
unexpected difference and collecting again.

## Continuous and Event-Driven Verification

Verification must occur:

- At host admission.
- Before and after patching.
- Before and after reboot.
- Before and after a role promotion or planned role transition.
- Before and after release deployment or rollback.
- After recovery from backup or trusted rebuild.
- On a defined recurring schedule.
- When file-integrity monitoring reports a change.
- When compromise, unauthorized access, or supply-chain concern is suspected.

The verifier must compare the host against the exact accepted baseline
generation for its role and release.

Differences must be classified as:

```text
EXPECTED_AUTHORIZED_CHANGE
EXPECTED_MACHINE_GENERATED_CHANGE
UNAPPROVED_PACKAGE_CHANGE
UNAPPROVED_CONFIGURATION_CHANGE
PACKAGE_DATABASE_MISMATCH
PACKAGE_FILE_MISMATCH
METADATA_OR_PERMISSION_DRIFT
MISSING_OBJECT
UNEXPECTED_OBJECT
REPUTATION_CONCERN
MALWARE_DETECTION
BASELINE_OR_VERIFIER_FAILURE
UNKNOWN_DIFFERENCE
```

`UNKNOWN_DIFFERENCE`, package-manager integrity failure, unexplained executable
change, malware detection, or baseline-verification failure is never silently
accepted.

## Runtime Integrity Correlation

The deployed-runtime inventory must correlate:

- Running executable path and SHA-256 digest.
- Owning package and package artifact digest.
- Accepted release artifact and release-manifest digest.
- Loaded shared libraries where practical.
- Active configuration generation.
- Process identity, privileges, capabilities, and sandbox profile.
- Listening sockets and accepted network exposure.
- Service-manager unit or workstation-launch identity.
- Current host-baseline generation.

A signed artifact on disk does not establish runtime integrity when a different
binary, library, configuration, or service definition is active.

## Evidence Protection

Baseline manifests and change generations must be:

- Signed or authenticated.
- Stored off-host or in append-only protected evidence storage.
- Bound to the accepted release and deployment profile.
- Retained according to the assurance-record policy.
- Independently verifiable after host loss.
- Protected from alteration by ordinary runtime service identities.

The host being measured must not be the sole authority for deciding whether its
own integrity evidence is valid.

## Acceptance Failures

A host fails admission, patch acceptance, or continued qualification when:

- An installed package lacks required identity or transaction evidence.
- The package manager, package database, trust store, or verifier cannot be
  validated.
- A required package artifact or installed file differs without authorization.
- A regular file under `/etc` lacks the required comparable SHA-256 digest
  without an accepted technical limitation.
- An unexpected privileged executable, startup entry, service, timer, account,
  or network listener exists.
- External or local malware evidence lacks disposition.
- A baseline generation was overwritten, regenerated without change evidence,
  or cannot be independently verified.
- Reputation or scanning results were fabricated, omitted without explanation,
  or associated with the wrong digest.
- Secret or operational content was uploaded externally without explicit
  authorization.
- The running process, package, configuration, and accepted release cannot be
  correlated.
- An unresolved critical or high integrity finding remains.

## Relationship to Other Models

The [Software Supply-Chain and Release-Integrity Model](software-supply-chain-and-release-integrity-model.md)
governs source, dependency, build, provenance, signing, promotion, and release
identity.

This document governs the installed host and runtime realization of that
accepted release.

CAD rolling maintenance, availability, and HA evidence are governed by the
[CAD Operational Readiness and Production Acceptance Model](../../modules/CAD/docs/architecture/cad-operational-readiness-and-production-acceptance-model.md).
