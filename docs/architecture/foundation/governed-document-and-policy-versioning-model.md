# Governed Document and Policy Versioning Model

> **Document status:** Normative Platform Foundation architecture.
>
> **Implementation status:** The Foundation SQL migrations provide an initial structural implementation. A requirement described here is not considered fully enforced until the applicable database controls, deployment roles, runtime behavior, automated tests, and operational safeguards are in place.

## Purpose

Preserve authoritative, approved, effective-dated, and integrity-verifiable versions of policies, agreements, procedures, and other governed documents.

## Architectural Requirements

### Document Identity and Version

A governed document has a stable identity. Each revision is a separate immutable version with version label, content reference, digest, authoring context, approval state, and effective period.

### Lifecycle

Typical states include draft, submitted, approved, effective, superseded, withdrawn, and retired. State changes are attributable and historically preserved.

### Approval

A document cannot become effective without the approvals required by its document type and governing policy.

### Integrity

The authoritative content or canonical serialized representation is cryptographically hashed. External storage locations may be referenced, but the Foundation retains sufficient metadata to verify the exact content used in a decision.

### Decision Binding

A decision records the specific document and policy versions that were effective and evaluated. Later policy changes do not rewrite the historical basis of an earlier decision.

### Supersession

A new version supersedes rather than overwrites the old version. Effective intervals must not create ambiguous simultaneous authority unless explicitly allowed.

## SQL Implementation Mapping

Migration `086_governed_documents_and_policy_versions.sql` provides the principal structural implementation. Migrations `050`, `055`, `088–090`, and `092` reference governed versions.

The migration mapping identifies the current structural implementation. It does not, by itself, prove that every requirement in this document is operationally enforced.

## Validation Expectations

The Foundation SQL test framework must test the requirements that can be demonstrated at the database boundary. Runtime, deployment, recovery, and provider behavior must be tested in their respective layers.

## Related Documents

- [Lifecycle Versioning and Historical Lineage](lifecycle-versioning-and-historical-lineage-model.md)
- [Approval Framework](approval-framework.md)
- [Compliance Profile Versioning](compliance-profile-versioning-model.md)
