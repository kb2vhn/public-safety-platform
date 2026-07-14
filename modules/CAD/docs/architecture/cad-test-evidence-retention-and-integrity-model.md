# CAD Test Evidence Retention and Integrity Model

> **Owner:** Iron Signal Systems
>
> **Module:** Computer Aided Dispatch
>
> **Document status:** Normative CAD assurance architecture
>
> **Implementation status:** Evidence contract only
>
> **Production status:** Not accepted for production use

## Purpose

Ensure CAD test and acceptance evidence remains identifiable, verifiable,
reviewable, reproducible, protected, and available for the period in which a
claim depends on it.

A mutable log link without an exact identity and digest is not formal evidence.

## Evidence Principles

1. Every formal run has one evidence manifest.
2. Every retained artifact is bound to source, configuration, registries,
   environment, workload, and result.
3. Evidence integrity is verified at creation, transfer, restore, and review.
4. Sensitive test data is minimized and protected.
5. Acceptance summaries and underlying evidence remain distinguishable.
6. Raw telemetry may have a different retention class from acceptance records.
7. Deletion is governed and recorded.
8. A missing required artifact invalidates the affected claim.
9. Evidence must remain usable without relying on an unversioned dashboard.
10. Real protected operational data is prohibited unless explicitly authorized.

## Evidence Manifest

Every formal run must produce a machine-readable manifest containing:

```text
evidence manifest identifier
run and campaign identifiers
source commit and tag
source-tree digest where supported
artifact and image digests
registry file digests
schema and migration inventory
build provenance
SBOM references
configuration digest
environment fingerprint
workload profile
seed and corpus revisions
start and end time
controller and generator versions
test inventory
result counters
telemetry completeness
artifact list
artifact digests
sensitivity
retention class
storage locations
review status
acceptance-record reference
```

The manifest itself must be hashed and retained.

## Evidence Classes

### Acceptance Record

Compact human-readable decision and machine-readable summary.

Retention requirement:

- Retain for the supported life of the accepted release.
- Retain while any deployment, audit, warranty, investigation, exception,
  migration, or successor acceptance depends on it.
- Preserve historic accepted records after supersession.

### Release and Provenance Evidence

Includes source identity, build provenance, SBOM, signatures, artifact digests,
deployment package identity, and registry digests.

Retention requirement:

- Retain for every supported release.
- Retain through rollback and trusted-rebuild eligibility.
- Retain longer when an incident, vulnerability, or legal hold applies.

### Correctness and Campaign Evidence

Includes detailed test results, per-layer matrices, sequence ledgers, seeds,
failure classifications, side-effect checks, and campaign accounting.

Retention requirement:

- Retain for every accepted phase and release.
- Retain until no supported release depends on the behavior and no unresolved
  finding, exception, or investigation references the evidence.

### Permanent Regression Evidence

Includes minimized failures, malicious fixtures, prior defect cases, and
reproducible hostile corpus entries.

Retention requirement:

- Retain while the affected control, operation, parser, protocol, or descendant
  implementation exists.
- Preserve supersession lineage when a case is replaced.

### Resource and Performance Trend Evidence

Includes timing, CPU, memory, disk, PostgreSQL, WAL, queue, worker, and
workstation observations.

Retention requirement:

- Retain enough same-environment history to establish trends, normal variation,
  budgets, and regression analysis.
- Do not combine unlike environments without preserving their fingerprints.

### Availability and HA Evidence

Includes probes, outage ledgers, failover events, fencing evidence, authority
epochs, stable-primary behavior, queue drainage, and recovery reports.

Retention requirement:

- Retain for every production-readiness acceptance and material topology
  qualification.
- Retain through the supported life of the related topology and release.

### High-Volume Raw Telemetry

Includes detailed time series, packet-level test captures, verbose traces, and
raw event streams.

Retention requirement:

- Assign an exact duration before the run.
- Retain long enough for review, failure reduction, acceptance challenge, and
  incident investigation.
- Preserve summarized and digest-bound evidence before governed deletion.

### Sensitive Restricted Evidence

Includes secrets accidentally detected, security-sensitive fixtures,
vulnerability details, or authorized protected data.

Retention requirement:

- Restrict access.
- Encrypt in transit and at rest.
- Minimize content.
- Record every approved retention and deletion decision.
- Apply legal, contractual, and deployment-specific requirements.

## Retention Policy

Every artifact must identify one retention class and an exact disposition rule.

Until an accepted retention schedule exists, required formal evidence must not
be automatically deleted.

A deployment-specific policy may establish durations, but it may not delete
evidence while:

- A supported release depends on it.
- An exception or finding remains open.
- An investigation or legal hold applies.
- A rollback or trusted rebuild depends on it.
- The evidence is the only retained reproduction of a confirmed defect.
- Acceptance has not completed.

## Integrity

At minimum, every retained file must use SHA-256.

The evidence manifest should record:

```yaml
artifact:
  path: results/correctness-summary.json
  sha256: "<digest>"
  size_bytes: 0
  media_type: application/json
  sensitivity: INTERNAL
  retention_class: CORRECTNESS_CAMPAIGN
```

Formal release evidence should additionally use the platform's accepted signing
and provenance controls.

## Storage

Formal evidence must use storage that provides:

- Access control.
- Encryption in transit.
- Encryption at rest where sensitive or required.
- Off-host protection.
- Backup or replication appropriate to the claim.
- Integrity verification.
- Auditability of administrative changes.
- Recovery testing.
- Separation from the disposable environment that produced it.

A single local workstation directory is not sufficient formal retention.

The exact storage technology remains replaceable.

## Transfer and Verification

When evidence is copied, uploaded, restored, or migrated:

1. Verify the source manifest.
2. Transfer using an authenticated and integrity-protected method.
3. Recalculate artifact digests.
4. Compare every digest and size.
5. Record the destination.
6. Verify access controls.
7. Record the operator or automation identity.
8. Preserve the original manifest.
9. Fail the transfer when any artifact differs unexpectedly.

## Sensitive Data

Tests must use synthetic data by default.

Evidence generation must:

- Exclude credentials and private keys.
- Redact tokens and session secrets.
- Avoid real caller, patient, criminal-justice, protected-person, personnel,
  premise, and responder data.
- Bound payload capture.
- Identify classification and sensitivity.
- Preserve enough information to reproduce the behavior without exposing
  unnecessary content.

Redaction must be deterministic where evidence comparison depends on it.

## Evidence Completeness

A formal run must state:

```text
required artifacts
produced artifacts
missing artifacts
unsupported metrics
telemetry gaps
corrupt artifacts
unverified transfers
redaction failures
unknown outcomes
```

Required missing or corrupt evidence is a gate failure.

## Evidence Access and Review

Access must follow least privilege.

The evidence custodian, implementation author, and acceptance authority should
remain distinguishable for high-impact acceptance.

Review activity should record:

- Reviewer.
- Evidence manifest.
- Review date.
- Findings.
- Challenged assumptions.
- Reproduction attempts.
- Decision.
- Required remediation.

## Deletion

Deletion must:

- Be authorized by the applicable retention policy.
- Confirm no supported claim or hold depends on the artifact.
- Preserve the acceptance summary and deletion record where required.
- Record artifact identifiers and digests.
- Record actor, time, reason, and policy.
- Use a method appropriate to the storage medium and sensitivity.
- Not silently remove evidence referenced by an acceptance record.

## Acceptance

Formal CAD acceptance requires:

- A complete evidence manifest.
- Verified artifact digests.
- Complete required evidence.
- Exact retention and storage classification.
- No unexplained telemetry gaps.
- No unverified transfer.
- Independent review appropriate to consequence.
- A retained acceptance-record reference.
