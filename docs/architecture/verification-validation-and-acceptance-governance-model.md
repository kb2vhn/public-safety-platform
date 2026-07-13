# Verification, Validation, and Acceptance-Governance Model

> **Owner:** Iron Signal Systems
>
> **Scope:** Platform Foundation and all modules
>
> **Document status:** Normative Platform architecture
>
> **Implementation status:** Governance contract only

## Purpose

Define who may create, verify, validate, review, except, release, and accept an
Iron Signal change.

Automated evidence is necessary but does not by itself constitute organizational
acceptance.

## Controlled Roles

### Implementer

Creates or changes architecture, code, SQL, tests, configuration, deployment, or
documentation.

### Verifier

Determines whether the implementation matches the accepted specification and
whether required evidence is complete.

### Operational Validator

Determines whether the accepted behavior supports the intended operational
workflow, degraded mode, recovery, accessibility, and human use.

### Security Reviewer

Reviews trust boundaries, hostile testing, failure mechanisms, data exposure,
least privilege, and security-control evidence.

### Database-Boundary Reviewer

Reviews role topology, ownership, privileges, controlled APIs, current-state
revalidation, transaction behavior, and direct bypass resistance.

### Accessibility Reviewer

Reviews automated and manual accessibility evidence and operational impact.

### Standards-Conformance Authority

Approves exact standards applicability, clause mappings, deviations, evidence,
and release-bound conformance claims. This role does not independently authorize
production deployment unless the same person also holds the separately recorded
Production Acceptance Authority role.

### Release Authority

Authorizes the exact release bundle and artifact digests for promotion.

### Production Acceptance Authority

Accepts the residual operational risk of an exact release in an exact deployment
profile.

### Exception Authority

Approves a bounded deviation with owner, compensating controls, review date, and
expiration.

### Assurance Reader or Auditor

Reads retained evidence without receiving implementation or production-write
authority merely because review access is granted.

## Separation of Duties

No individual may be the sole implementer, sole verifier, and sole acceptance
authority for a high-impact protected boundary.

At minimum, high-impact acceptance requires:

- Implementer attestation.
- Independent technical verification.
- Security or database-boundary review where applicable.
- Operational validation where human or mission workflow is affected.
- Release authority approval.
- Standards-conformance authority approval when a conformance claim is made.
- Production acceptance authority approval before production use.

During early project development, one person may perform several activities, but
the acceptance record must expose the overlap. Real public-safety production
entry requires independent review of high-impact boundaries.

## Self-Approval Restrictions

A person must not solely approve:

- Their own security exception.
- Their own production release.
- Their own change to approval or authorization logic.
- Their own change to database ownership or runtime privileges.
- Their own change to release signing or provenance controls.
- Their own change to the acceptance gate that evaluates the same change.

## Evidence-Bound Acceptance

Acceptance applies only to the recorded:

- Source commit and tree.
- Architecture and requirement versions.
- Build provenance.
- Artifact digests and signatures.
- SBOM.
- Migration inventory.
- Test and campaign evidence.
- Environment profile.
- Configuration profile.
- Deployment topology.
- Standards-conformance state and conformance-authority decision.
- Open exceptions and limitations.

A materially different artifact, migration, configuration, topology, or trust
boundary is not covered merely because it shares a version label.

## Decision States

```text
NOT_REVIEWED
REVIEW_ACTIVE
CHANGES_REQUIRED
VERIFIED
VALIDATED
ACCEPTED_WITH_EXCEPTIONS
ACCEPTED
REJECTED
SUPERSEDED
WITHDRAWN
```

`VERIFIED` does not mean operationally validated. `VALIDATED` does not authorize
a release. `ACCEPTED_WITH_EXCEPTIONS` must name every exception.

## Exception Contract

Every exception must contain:

- Stable identifier.
- Exact affected requirement and boundary.
- Reason.
- Risk and consequence.
- Scope.
- Compensating controls.
- Detection and monitoring.
- Owner.
- Approvers.
- Effective date.
- Review date.
- Expiration date.
- Remediation plan.
- Closure evidence.

Critical authority, acknowledged-commit loss, split-brain, hidden partial commit,
or inability to establish authoritative state must not be accepted as routine
exceptions for production.

## Change Impact and Reacceptance

Every material change must identify affected:

- Requirements and invariants.
- Threats and hazards.
- Controlled operations.
- Tests and hostile classes.
- Performance and availability budgets.
- Standards-conformance claims.
- Build and deployment controls.
- Recovery and rollback procedures.
- Prior acceptance records.

The reviewer must decide whether targeted regression, phase reacceptance,
availability requalification, or full production reacceptance is required.

## Acceptance Record

The record must include:

- Scope and exclusions.
- Exact identities and counts.
- PASS, FAIL, WARN, and NOT_EVALUATED totals.
- Correctness, security, resource, performance, accessibility, availability,
  supply-chain, standards, recovery, and deployment status separately.
- Reviewer roles and identity.
- Separation-of-duty status.
- Exceptions.
- Known limitations.
- Final decision.
- Supersession lineage.

## Governance Failure

Acceptance fails when:

- Required reviewers are absent.
- One person improperly self-approves a high-impact boundary.
- Evidence does not identify the exact artifact or environment.
- Required conflicts are hidden.
- An exception lacks owner or expiration.
- A failed control is relabeled as a warning without authority.
- A later material change relies on stale acceptance.
