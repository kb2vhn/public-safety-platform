# Operational Workstation Architecture

> **Status:** Normative architecture under active refinement.
>
> **Implementation status:** Design scaffold; no production workstation profile is yet accepted.

## Purpose

This directory defines the operator workstation as a managed, verifiable operational appliance rather than a general-purpose desktop.

The architecture is domain-neutral. Public safety is the first demanding operational profile, but the workstation boundary must remain usable by future municipal, school, and institutional modules.

## Documents

- [Operational Workstation Architecture](operational-workstation-architecture.md)
- [Human Factors and Interaction Model](human-factors-and-interaction-model.md)
- [Desktop Environment and Workspace Model](desktop-environment-and-workspace-model.md)
- [Software Package Governance](software-package-governance.md)
- [Workstation Baseline Manifest Model](workstation-baseline-manifest-model.md)
- [Network Communication Profile](network-communication-profile.md)
- [Workstation Trust Evidence Model](workstation-trust-evidence-model.md)
- [Lifecycle, Snapshot, Backup, and Update Model](lifecycle-snapshot-backup-and-update-model.md)
- [Remote Management Model](remote-management-model.md)
- [Provisioning and Rebuild Model](provisioning-and-rebuild-model.md)
- [Performance Budget](performance-budget.md)
- [Degraded Operation Model](degraded-operation-model.md)

## Related architecture

- [Location Service Architecture](../backend-services/location-service-architecture.md)
- [Resource Subscription and Live Update Model](../communications/resource-subscription-and-live-update-model.md)
- [Map Rendering and Data Delivery Architecture](../gis-and-mapping/map-rendering-and-data-delivery-architecture.md)
- [Platform Engineering Principles](../platform-engineering-principles.md)

## Examples

The `examples/` directory contains non-production YAML examples for future machine-readable governance artifacts. They contain placeholders and must not be deployed unchanged.
