# Threat and Abuse Case Model

> **Document status:** Normative Platform Foundation architecture.
>
> **Implementation status:** The Foundation SQL migrations provide an initial structural implementation. A requirement described here is not considered fully enforced until the applicable database controls, deployment roles, runtime behavior, automated tests, and operational safeguards are in place.

## Purpose

Make anticipated threats, misuse, insider actions, and failure modes explicit inputs to control design and risk assessment.

## Architectural Requirements

### Threat Record

A threat record describes a source, capability, motivation, target, preconditions, affected services or classifications, potential impact, and lifecycle state.

### Abuse Case

An abuse case describes a concrete sequence in which an actor, compromised component, or operational failure could misuse platform capability.

Examples include:

- Self-approval or circular approval,
- Role accumulation creating unrestricted authority,
- Reuse of an expired or consumed authentication assertion,
- Lease theft or wrong-audience use,
- Silent decision-record alteration,
- Cross-organization access without current participation,
- Provider outage causing lost delivery intent,
- Recovery from an untrusted backup,
- Resource exhaustion against critical workflows.

### Mapping

Threats and abuse cases map to common controls, control implementations, tests, findings, risk records, and incident experience.

### Validation

A threat is not considered addressed merely because it is mapped to a control. The implementation and its assurance must be evaluated.

### Evolution

New incidents, vulnerabilities, architectural changes, and operational exercises may create or revise threat and abuse-case versions.

## SQL Implementation Mapping

Migration `091_threat_records_and_abuse_case_mappings.sql` provides the principal structural implementation.

The migration mapping identifies the current structural implementation. It does not, by itself, prove that every requirement in this document is operationally enforced.

## Validation Expectations

The Foundation SQL test framework must test the requirements that can be demonstrated at the database boundary. Runtime, deployment, recovery, and provider behavior must be tested in their respective layers.

## Related Documents

- [Risk Assessment and Treatment](risk-assessment-and-treatment-model.md)
- [Common Security Control Catalog](common-security-control-catalog.md)
- [Authentication and Authorization Evaluation](authentication-and-authorization-evaluation-model.md)
