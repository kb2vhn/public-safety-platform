# Software Package Governance

> **Status:** Draft normative architecture.
>
> **Implementation status:** Manifest format proposed; approved package set not yet selected.

## Purpose

Every package included in a production workstation image must have a complete, reviewable record. Nothing is installed merely because it may be useful later.

## Package record

Each explicit and transitive package must identify:

- Package name and version.
- Package source and repository snapshot.
- Package checksum or other integrity reference.
- Upstream project and license.
- Explicit or dependency inclusion reason.
- Requiring package, service, control, or workflow.
- Runtime, build, maintenance, recovery, or accessibility classification.
- Optional features enabled or disabled.
- Services, sockets, timers, kernel modules, hooks, or scheduled jobs introduced.
- Listening ports and outbound communication requirements.
- Filesystem paths and configuration owned.
- Users, groups, capabilities, and privileges introduced.
- CPU, memory, disk, startup, and update impact.
- Security and vulnerability-review requirements.
- Removal impact and replacement path.
- Owner, approval state, and last review date.

## Admission process

Before inclusion:

1. A current requirement identifies the package's purpose.
2. Existing approved components are evaluated first.
3. The complete dependency tree is reviewed.
4. Optional dependencies and features are minimized.
5. Build-only dependencies are excluded from production images.
6. Security, performance, network, and lifecycle impacts are recorded.
7. The package is tested on the lowest supported profile.
8. The approved manifest and release snapshot are updated.

## Production package rules

- Production systems do not install packages interactively outside an approved recovery procedure.
- Production systems do not select package versions independently from the approved release set.
- Unused packages are removed.
- Orphaned dependencies are reviewed rather than blindly retained or removed.
- A package manager database mismatch is a trust and drift event.
- Local or third-party packages require the same provenance and approval controls as repository packages.

## Guiding rule

> If a package does not have a current, documented purpose, it does not belong on the workstation.

See [approved-packages.example.yaml](examples/approved-packages.example.yaml) for a non-production record example.
