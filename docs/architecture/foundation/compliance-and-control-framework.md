# Compliance and Control Framework

> **Document status:** Normative Platform Foundation architecture.
>
> **Implementation status:** The Foundation SQL migrations provide an initial structural implementation. A requirement described here is not considered fully enforced until the applicable database controls, deployment roles, runtime behavior, automated tests, and operational safeguards are in place.

## Purpose

Represent reusable controls and map them to external or internal requirements without treating a framework name as proof of security or compliance.

## Architectural Requirements

### Framework-Neutral Layers

The model separates:

1. Common control definitions,
2. Compliance profiles and requirement versions,
3. Requirement-to-control mappings,
4. Scoped control implementations,
5. Assurance artifacts,
6. Assessments,
7. Findings and remediation,
8. Exceptions and risk decisions.

### Common Controls

A common control states an intended security, privacy, resilience, governance, or operational outcome. It is not tied to one external framework.

### Requirement Mapping

A requirement from a specific source and version maps to one or more common controls with a documented relationship and rationale.

### Implementation

A control implementation explains how a particular organization, service, system, workload, or deployment satisfies the control.

### Assurance

Assurance artifacts support evaluation but do not automatically prove effectiveness. Assessments determine whether the implementation is suitably designed, implemented, and operating as required.

### Compliance Claims

A compliance status or certification claim is outside the meaning of a simple mapping. Any claim must identify scope, source version, assessor, period, exceptions, and governing authority.

## SQL Implementation Mapping

Migrations `087–090` provide the principal structural implementation for control catalogs, compliance profiles, mappings, implementations, assurance artifacts, assessments, findings, remediation, exceptions, and risk.

The migration mapping identifies the current structural implementation. It does not, by itself, prove that every requirement in this document is operationally enforced.

## Validation Expectations

The Foundation SQL test framework must test the requirements that can be demonstrated at the database boundary. Runtime, deployment, recovery, and provider behavior must be tested in their respective layers.

## Related Documents

- [Common Security Control Catalog](common-security-control-catalog.md)
- [Compliance Profile Versioning](compliance-profile-versioning-model.md)
- [Control Implementation and Assurance Artifact Model](control-implementation-and-assurance-artifact-model.md)
- [Security Finding, Exception, and Remediation](security-finding-exception-and-remediation-model.md)
