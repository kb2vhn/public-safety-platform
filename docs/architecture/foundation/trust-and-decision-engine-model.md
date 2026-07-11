# Trust and Decision Engine Model

> **Document status:** Normative Platform Foundation architecture.
>
> **Implementation status:** The Foundation SQL migrations provide an initial structural implementation. A requirement described here is not considered fully enforced until the applicable database controls, deployment roles, runtime behavior, automated tests, and operational safeguards are in place.

## Purpose

Define a fail-closed, explainable decision process for protected platform operations.

## Architectural Requirements

### Decision Inputs

A protected decision may evaluate:

- Device and cryptographic trust,
- Identity and account state,
- Organization and service participation,
- Current eligibility and attestations,
- Session validity,
- Purpose and requested operation,
- Jurisdiction and data classification,
- Required approvals,
- Authorization policy,
- Existing Authorization Lease,
- Risk or security restrictions.

### Stage Results

Each stage returns exactly one of:

- `PASS`
- `FAIL`
- `NOT_REQUIRED`
- `NOT_EVALUATED`

A required stage returning `FAIL` or `NOT_EVALUATED` denies the operation.

`NOT_REQUIRED` is valid only when the governing policy explicitly makes the stage inapplicable. It must not be used as a generic success value.

### Decision Output

A decision includes the final result, reason codes, evaluated policy versions, actor and organization context, target and operation context, timestamps, stage results, and correlation identifiers.

### Independent Verification

The runtime service may gather decision inputs and evaluate complex policy. PostgreSQL independently verifies the minimum protected conditions before performing a controlled database operation.

### Revocation and Freshness

Trust and authority are time-sensitive. A decision must evaluate expiration, revocation, replacement, and audience binding using a consistent transaction or statement time model.

### Explainability

A denial must be understandable without exposing secrets. A success must retain enough context to show why it was permitted.

## SQL Implementation Mapping

The principal migrations are `010`, `045`, `055`, `060`, `065`, `070`, `075`, and `080`.

The migration mapping identifies the current structural implementation. It does not, by itself, prove that every requirement in this document is operationally enforced.

## Validation Expectations

The Foundation SQL test framework must test the requirements that can be demonstrated at the database boundary. Runtime, deployment, recovery, and provider behavior must be tested in their respective layers.

## Related Documents

- [Database Security](database-security-model.md)
- [Authorization Lease](authorization-lease-model.md)
- [Decision Record Repository](decision-record-repository.md)
- [Approval Framework](approval-framework.md)
