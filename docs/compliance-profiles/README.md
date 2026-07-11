# Compliance Profiles

## Purpose

Compliance profiles map external and internal requirements to reusable Platform Foundation controls.

Potential profiles include:

- FBI CJIS Security Policy,
- HIPAA and applicable healthcare privacy and security requirements,
- IRS Publication 1075,
- PCI DSS,
- State statutes and regulations,
- Local policy,
- Contractual requirements,
- Organization-specific control baselines.

## Foundation Neutrality

The Platform Foundation remains framework-neutral. It defines common controls, implementations, assurance artifacts, assessments, findings, remediation, exceptions, and risk records without making a framework name a security boundary.

A compliance profile:

1. Identifies a source authority and source version.
2. Preserves individual requirement identifiers and text references.
3. Maps requirements to one or more common controls.
4. Defines applicability and scope.
5. Is versioned, approved, effective-dated, and historically preserved.
6. Never claims compliance solely because a mapping or product feature exists.

## Evidence Terminology

Within the Foundation, proof used to evaluate a control is called an **assurance artifact**. This avoids confusion with the future public-safety Evidence and Property domain.

## Current Status

This directory currently contains the profile architecture index only. Concrete CJIS, HIPAA, IRS Publication 1075, or other profiles will be added after their sources, versions, ownership, review process, and mapping rules are formally established.

The supporting SQL model is introduced by migrations `087–090`.

## Related Documents

- [Compliance and Control Framework](../architecture/foundation/compliance-and-control-framework.md)
- [Common Security Control Catalog](../architecture/foundation/common-security-control-catalog.md)
- [Compliance Profile Versioning](../architecture/foundation/compliance-profile-versioning-model.md)
- [Control Implementation and Assurance Artifact Model](../architecture/foundation/control-implementation-and-assurance-artifact-model.md)
