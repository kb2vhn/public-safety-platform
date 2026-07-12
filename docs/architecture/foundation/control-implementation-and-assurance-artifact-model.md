# Control Implementation and Assurance Artifact Model

> **Document status:** Normative Platform Foundation architecture.
>
> **Implementation status:** The Foundation SQL migrations provide an initial structural implementation. A requirement described here is not considered fully enforced until the applicable database controls, deployment roles, runtime behavior, automated tests, and operational safeguards are in place.

## Purpose

Represent how a common control is implemented in a defined scope and what trustworthy artifacts may be used to assess that implementation.

## Architectural Requirements

### Terminology

The Foundation uses **assurance artifact** instead of the generic word **evidence**. This prevents confusion with the future public-safety Evidence and Property domain.

An assurance artifact is information used to support an assessment. It is not automatically proof that a control is effective.

### Control Implementation

A control implementation binds a specific common-control version to a defined scope, such as:

- Organization,
- Platform service,
- Application or module,
- Workload,
- Deployment,
- Infrastructure component,
- Provider integration,
- Policy or procedure.

The implementation records its owner, responsible parties, design description, operating procedure, inheritance, dependencies, implementation status, effective period, and supersession history.

### Inherited and Shared Controls

An implementation may inherit all or part of a control from a shared platform service or infrastructure provider. Inheritance must identify:

- The providing implementation,
- The consuming scope,
- The inherited portion,
- Residual responsibilities,
- Validity period,
- Conditions that invalidate inheritance.

A provider claim is not sufficient without an evaluated relationship and applicable assurance.

### Assurance Artifact

An artifact identifies:

- Artifact type and stable identifier,
- Producing system, process, person, or assessor,
- Collection time and covered period,
- Scope and applicable implementation,
- Storage location or content reference,
- Integrity digest,
- Classification and handling requirements,
- Retention and disposition requirements,
- Chain of custody or provenance where necessary,
- Review and expiration state.

Examples include configuration exports, test results, access reviews, recovery reports, signed attestations, scan output, policy approvals, logs, screenshots, tickets, or assessor workpapers.

### Provenance

The platform records who or what produced the artifact, how it was collected, whether it was transformed, and which source records support it.

Generated artifacts should identify the responsible workload, software version, collection parameters, and source time range.

### Integrity and Confidentiality

Artifact integrity is protected through digests, controlled write paths, immutable versions, storage protections, and off-host validation where the risk requires it.

Classification controls govern who may view, export, or deliver an artifact. An assessment summary must not expose restricted artifact content to unauthorized users.

### Freshness

Artifacts have collection and coverage periods. Policy may define maximum age. An expired or stale artifact remains historically available but must not silently satisfy a current assessment.

### Assessment Relationship

Assessors select applicable artifacts, record evaluation procedures, and determine design, implementation, and operating effectiveness.

An artifact may support multiple assessments only when its scope, period, provenance, and handling rules permit reuse.

### Findings

Missing, invalid, stale, contradictory, or insufficient artifacts may produce a finding. The artifact itself is not rewritten to remove the problem.

### Lifecycle

Implementations and artifacts use append-oriented versioning, supersession, withdrawal, and invalidation. Current-state views must preserve access to historical versions.

## SQL Implementation Mapping

Migration `089_control_implementations_and_assurance_artifacts.sql` provides the principal structural implementation. Migration `090` consumes implementations and artifacts during assessment, finding, remediation, exception, and risk workflows.

The migration mapping identifies the current structural implementation. It does not, by itself, prove that every requirement in this document is operationally enforced.

## Validation Expectations

The Foundation SQL test framework must test the requirements that can be demonstrated at the database boundary. Runtime, deployment, recovery, and provider behavior must be tested in their respective layers.

## Related Documents

- [Compliance and Control Framework](compliance-and-control-framework.md)
- [Common Security Control Catalog](common-security-control-catalog.md)
- [Security Finding, Exception, and Remediation](security-finding-exception-and-remediation-model.md)
- [Data Classification and Information Governance](data-classification-and-information-governance-model.md)
