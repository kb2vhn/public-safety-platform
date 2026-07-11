# Common Security Control Catalog

> **Document status:** Normative Platform Foundation architecture.
>
> **Implementation status:** The Foundation SQL migrations provide an initial structural implementation. A requirement described here is not considered fully enforced until the applicable database controls, deployment roles, runtime behavior, automated tests, and operational safeguards are in place.

## Purpose

Define reusable control outcomes that can be implemented once and mapped to many compliance or policy sources.

## Architectural Requirements

### Control Definition

A common control includes a stable identifier, title, objective, control statement, control family, ownership, applicability guidance, lifecycle state, and version.

### Reuse

One common control may support requirements from CJIS, HIPAA, IRS Publication 1075, state policy, local policy, or contractual sources. Mappings do not merge or erase the original requirement text.

### Versioning

Material changes create a new control version. Historical assessments and decisions remain linked to the exact control version evaluated.

### Control Types

Controls may address preventive, detective, corrective, deterrent, recovery, governance, privacy, resilience, or operational outcomes.

### Ownership

A control owner maintains the definition. Implementation owners remain responsible for scoped implementations. Assessors independently evaluate effectiveness where required.

### Status

Draft, approved, effective, superseded, withdrawn, and retired states must be explicitly governed.

## SQL Implementation Mapping

Migration `087_common_control_catalog.sql` provides the principal structural implementation.

The migration mapping identifies the current structural implementation. It does not, by itself, prove that every requirement in this document is operationally enforced.

## Validation Expectations

The Foundation SQL test framework must test the requirements that can be demonstrated at the database boundary. Runtime, deployment, recovery, and provider behavior must be tested in their respective layers.

## Related Documents

- [Compliance and Control Framework](compliance-and-control-framework.md)
- [Compliance Profile Versioning](compliance-profile-versioning-model.md)
- [Control Implementation and Assurance Artifact Model](control-implementation-and-assurance-artifact-model.md)
