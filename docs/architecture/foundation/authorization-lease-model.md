# Authorization Lease Model

> **Document status:** Normative Platform Foundation architecture.
>
> **Implementation status:** The Foundation SQL migrations provide an initial structural implementation. A requirement described here is not considered fully enforced until the applicable database controls, deployment roles, runtime behavior, automated tests, and operational safeguards are in place.

## Purpose

Represent a short-lived, revocable, operation-bound capability issued only after a successful authorization decision.

## Architectural Requirements

### Lease Properties

An Authorization Lease binds:

- Authorized identity and account,
- Organization and service,
- Session and trusted device context,
- Purpose,
- Operation and resource scope,
- Jurisdiction and classification limits,
- Governing policy and decision record,
- Issue, activation, and expiration times,
- Revocation and consumption state.

### Secret

When a lease uses a bearer secret, the secret must be cryptographically random and high entropy. PostgreSQL stores only a verifier when possible. Secrets must not appear in logs, decision explanations, URLs, or general telemetry.

### Verification

A controlled operation verifies the lease secret, audience, scope, current time, revocation, session, and any single-use or consumption requirement.

Time evaluation must use a documented statement- or transaction-consistent clock unless a different behavior is explicitly justified.

### Lifetime

Leases are short-lived and renewable only through a new decision or a narrowly defined renewal policy. Expiration is automatic and cannot be bypassed by client clock values.

### Revocation

Security action, session termination, identity ineligibility, device distrust, policy change, or explicit administrative revocation may invalidate a lease.

### Fail Closed

Missing, expired, revoked, consumed, wrong-audience, wrong-operation, or wrong-scope leases deny the operation without revealing secret-verification detail.

## SQL Implementation Mapping

Migration `065_authorization_leases.sql` establishes the lease model. Migration `075_controlled_authorization_api.sql` provides the initial controlled verification API.

The migration mapping identifies the current structural implementation. It does not, by itself, prove that every requirement in this document is operationally enforced.

## Validation Expectations

The Foundation SQL test framework must test the requirements that can be demonstrated at the database boundary. Runtime, deployment, recovery, and provider behavior must be tested in their respective layers.

## Related Documents

- [Authority and Authorization](authority-and-authorization-model.md)
- [Database Security](database-security-model.md)
- [Decision Record Repository](decision-record-repository.md)
