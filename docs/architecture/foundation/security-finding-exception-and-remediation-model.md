# Security Finding, Exception, and Remediation Model

> **Document status:** Normative Platform Foundation architecture.
>
> **Implementation status:** The Foundation SQL migrations provide an initial structural implementation. A requirement described here is not considered fully enforced until the applicable database controls, deployment roles, runtime behavior, automated tests, and operational safeguards are in place.

## Purpose

Preserve attributable findings, corrective work, bounded exceptions, and closure decisions without hiding unresolved risk.

## Architectural Requirements

### Finding

A finding identifies the affected scope, control or requirement, assessment source, condition, expected state, severity, risk context, discovery time, owner, and lifecycle state.

A finding is not deleted because it was corrected. Closure records the basis and verification.

### Remediation

A remediation plan defines responsible owner, actions, dependencies, milestones, target date, validation criteria, and status.

Individual remediation actions are attributable and historically preserved.

### Exception

An exception is a formally approved, time-bounded deviation from a requirement or control. It identifies scope, rationale, compensating controls, risk, approvers, effective period, review date, and expiration.

An exception does not rewrite the requirement or declare the control satisfied.

### Risk Acceptance

Residual risk acceptance requires an authorized decision maker, explicit scope, reason, expiration or review period, and recorded decision.

### Reopening

A closed finding may be reopened by a new record when validation fails, conditions recur, or the remediation no longer operates effectively.

## SQL Implementation Mapping

Migration `090_assessments_findings_remediation_exceptions_and_risk.sql` provides the principal structural implementation.

The migration mapping identifies the current structural implementation. It does not, by itself, prove that every requirement in this document is operationally enforced.

## Validation Expectations

The Foundation SQL test framework must test the requirements that can be demonstrated at the database boundary. Runtime, deployment, recovery, and provider behavior must be tested in their respective layers.

## Related Documents

- [Risk Assessment and Treatment](risk-assessment-and-treatment-model.md)
- [Control Implementation and Assurance Artifact Model](control-implementation-and-assurance-artifact-model.md)
- [Decision Record Repository](decision-record-repository.md)
