# Compliance Profile Versioning Model

> **Document status:** Normative Platform Foundation architecture.
>
> **Implementation status:** The Foundation SQL migrations provide an initial structural implementation. A requirement described here is not considered fully enforced until the applicable database controls, deployment roles, runtime behavior, automated tests, and operational safeguards are in place.

## Purpose

Preserve the exact external or internal requirement set used for control mapping, assessment, and compliance reporting.

## Architectural Requirements

### Profile Identity

A profile represents a governed source or baseline, such as a specific CJIS Security Policy release, HIPAA-derived baseline, IRS Publication 1075 edition, state requirement set, contract, or local policy.

### Profile Version

Every source revision is a separate version with source identifier, publication or adoption date, effective period, approval, lifecycle state, and integrity metadata.

### Requirements

Individual requirements retain source identifiers, hierarchy, citations, applicability, and source-version relationship.

### Mapping

Mappings connect a requirement version to one or more common-control versions with relationship type, rationale, coverage, and review state.

### Historical Accuracy

An assessment or decision records the profile, requirement, control, and implementation versions evaluated at that time.

### Update Process

A new source release does not overwrite the prior profile. Differences are reviewed, mappings are re-evaluated, and affected implementations are identified.

## SQL Implementation Mapping

Migration `088_compliance_profiles_and_requirement_mappings.sql` provides the principal structural implementation.

The migration mapping identifies the current structural implementation. It does not, by itself, prove that every requirement in this document is operationally enforced.

## Validation Expectations

The Foundation SQL test framework must test the requirements that can be demonstrated at the database boundary. Runtime, deployment, recovery, and provider behavior must be tested in their respective layers.

## Related Documents

- [Compliance and Control Framework](compliance-and-control-framework.md)
- [Common Security Control Catalog](common-security-control-catalog.md)
- [Governed Document and Policy Versioning](governed-document-and-policy-versioning-model.md)
