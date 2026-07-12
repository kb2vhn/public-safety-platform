# Risk Assessment and Treatment Model

> **Document status:** Normative Platform Foundation architecture.
>
> **Implementation status:** The Foundation SQL migrations provide an initial structural implementation. A requirement described here is not considered fully enforced until the applicable database controls, deployment roles, runtime behavior, automated tests, and operational safeguards are in place.

## Purpose

Represent risk consistently enough to support accountable treatment, exception, acceptance, and prioritization decisions.

## Architectural Requirements

### Risk Context

A risk record identifies the affected organization, service, asset, process, data classification, threat or abuse case, vulnerability or condition, and business or operational impact.

### Assessment

Risk assessment records the method, assessor, assumptions, likelihood, impact, existing controls, residual risk, assessment period, and governing criteria.

### Treatment

Treatment options include avoid, reduce, transfer, accept, or another governed response. A treatment plan identifies owners, actions, target state, deadlines, dependencies, and validation.

### Acceptance

Risk acceptance is a material authorization decision. It is scoped, effective-dated, time-bounded where practical, approved by the appropriate authority, and linked to the applicable finding, exception, or treatment plan.

### Reassessment

Material change, control failure, new threat information, incident experience, or expiration requires reassessment.

### Reporting

Risk summaries must preserve traceability to the underlying assessment without exposing restricted details beyond authorized audiences.

## SQL Implementation Mapping

Migration `090` provides assessment, exception, treatment, and risk structures. Migration `091` adds threats and abuse-case context.

The migration mapping identifies the current structural implementation. It does not, by itself, prove that every requirement in this document is operationally enforced.

## Validation Expectations

The Foundation SQL test framework must test the requirements that can be demonstrated at the database boundary. Runtime, deployment, recovery, and provider behavior must be tested in their respective layers.

## Related Documents

- [Threat and Abuse Case](threat-and-abuse-case-model.md)
- [Security Finding, Exception, and Remediation](security-finding-exception-and-remediation-model.md)
- [Approval Framework](approval-framework.md)
