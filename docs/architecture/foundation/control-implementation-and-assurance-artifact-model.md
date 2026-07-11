# Control Implementation and Assurance Artifact Model

**Document status:** Foundation architecture baseline  
**Architecture layer:** Platform Foundation  
**Primary SQL migration:** `089_control_implementations_and_assurance_artifacts.sql`  
**Primary schema:** `compliance`  
**Applies to:** Platform-wide control implementation, validation, assessment, audit support, and compliance review

---

## 1. Purpose

This document defines how the Platform Foundation represents:

- versioned implementations of common controls;
- records that describe how a control is implemented at a particular scope;
- assurance artifacts used to support implementation, validation, assessment, audit, or compliance review;
- validation history for assurance artifacts;
- assessments of control effectiveness;
- relationships between implementations, assessments, and assurance artifacts;
- integrity, provenance, retention, classification, and lifecycle expectations for those records.

The model is intentionally domain-neutral. It supports public safety, finance, human resources, records management, fleet, permitting, and other municipal services without embedding the terminology or workflow of any one operational domain.

The model does not determine whether a system is compliant merely because an artifact exists. Control effectiveness and compliance are conclusions reached through governed assessment and decision processes.

---

## 2. Terminology Boundary

### 2.1 Assurance Artifact

An **assurance artifact** is a controlled record used to support one or more of the following:

- description of a control implementation;
- validation of a technical or procedural condition;
- assessment of control effectiveness;
- internal audit;
- external audit;
- compliance review;
- risk review;
- operational assurance;
- historical explanation of why a conclusion was reached.

Examples include:

- configuration snapshots;
- system-generated reports;
- log extracts;
- database query results;
- scan results;
- test results;
- approved attestations;
- policy or procedure documents;
- screenshots;
- exported platform health records;
- deployment manifests;
- cryptographic verification reports.

An assurance artifact is not, by itself, proof that a control is effective or that the platform is compliant.

### 2.2 Legal or Investigative Evidence

Assurance artifacts are **not legal evidence, investigative evidence, property-room evidence, or chain-of-custody evidence**.

A future legal-evidence capability must use separate:

- schemas;
- tables;
- terminology;
- permissions;
- chain-of-custody records;
- storage controls;
- disposition procedures;
- legal holds;
- disclosure rules;
- retention policies;
- audit requirements.

The Platform Foundation must not reuse `compliance.control_assurance_artifacts` as a substitute for a legal-evidence system.

### 2.3 Supporting Record

A **supporting record** is a broader platform concept used by the Decision Record Repository. An assurance artifact may be referenced as a supporting record, but not every supporting record is an assurance artifact.

### 2.4 Control Implementation

A **control implementation** describes how a specific version of a common control is implemented for a defined scope and time period.

### 2.5 Control Assessment

A **control assessment** is an append-only conclusion about the effectiveness of a specific versioned control implementation, reached using an identified assessment procedure and assessor.

### 2.6 Artifact Validation

An **artifact validation** is an append-only determination about the current validity, integrity, freshness, or usability of an assurance artifact.

Artifact validation does not determine control effectiveness. It only determines whether the artifact is suitable for consideration.

---

## 3. Design Principles

The model follows these principles.

### 3.1 Historical Explainability

The platform must be able to answer:

- Which control version applied?
- Which implementation version applied?
- What was the implementation state at that time?
- Which artifacts supported the implementation?
- Which artifacts were used in an assessment?
- Were those artifacts valid at the time?
- Which assessment procedure was used?
- Who performed the assessment?
- What conclusion was reached?
- Which decision record authorized or accepted the result?

Historical records must remain explainable after policies, implementations, configurations, personnel, and systems change.

### 3.2 Versioning Instead of Destructive Replacement

Control implementations are versioned and effective-dated. A new implementation version supersedes an earlier version rather than overwriting it.

Assurance artifacts may supersede older artifacts, but the older artifact record remains.

Validation results and assessments are append-only. Corrections are represented by later records rather than destructive edits.

### 3.3 Artifact Existence Does Not Equal Compliance

The following conclusions are invalid:

- “A screenshot exists, therefore the control is effective.”
- “A scan completed, therefore the system is compliant.”
- “A policy document exists, therefore the policy is followed.”
- “An artifact hash matches, therefore the artifact proves the control.”
- “An assessor linked an artifact, therefore the artifact is sufficient.”

An assurance artifact is an input to review. It is not the review conclusion.

### 3.4 Integrity and Provenance

Every assurance artifact must have:

- a stable artifact key;
- a recorded artifact type;
- a collection timestamp;
- a controlled storage reference;
- a SHA-256 integrity value;
- an attributed creator or collector reference;
- enough source information to understand where it came from;
- classification and retention references when applicable.

### 3.5 Controlled Storage

Artifact bytes do not belong in the Foundation’s core relational tables.

The database stores:

- metadata;
- integrity values;
- controlled storage references;
- provenance;
- applicability;
- relationships;
- validation history;
- decision references.

Artifact content belongs in storage designed for:

- object durability;
- access control;
- retention;
- encryption;
- backup;
- malware scanning;
- integrity verification;
- legal and regulatory requirements;
- size and throughput appropriate to the artifact type.

### 3.6 Scope Must Be Explicit

A control implementation must identify exactly one supported scope:

- platform;
- organization;
- service;
- deployment;
- service participation.

Ambiguous or multiple simultaneous scope targets are rejected.

### 3.7 Separation of Collection, Validation, and Assessment

The model separates:

1. collection of an artifact;
2. validation of the artifact;
3. linkage of the artifact to an implementation;
4. use of the artifact in an assessment;
5. assessment of control effectiveness;
6. risk, exception, remediation, or authorization decisions.

This prevents a collection process from silently becoming an assessment authority.

### 3.8 No Hidden Mutation

Records used to explain historical control decisions must not be silently rewritten.

Where correction is necessary, the model uses:

- supersession;
- new validation records;
- new implementation versions;
- new assessment records;
- explicit decision references.

### 3.9 Domain Neutrality

The Foundation describes controls, implementations, artifacts, and assessments without embedding:

- law-enforcement case terminology;
- finance-specific workflow;
- human-resources case handling;
- permitting terminology;
- fleet maintenance terminology;
- records-disclosure terminology.

Domain systems may reference Foundation records without redefining Foundation semantics.

---

## 4. Architectural Context

The assurance-artifact model sits between the common control catalog and the broader risk and compliance lifecycle.

```text
Common Control Catalog
        |
        v
Versioned Control Implementation
        |
        +------------------------------+
        |                              |
        v                              v
Implementation-to-Artifact Link   Control Assessment
        |                              |
        v                              v
Assurance Artifact <---------- Assessment-to-Artifact Link
        |
        v
Append-Only Artifact Validation History
```

Related Foundation capabilities include:

- `compliance.common_controls`
- `compliance.common_control_versions`
- compliance profiles and requirement mappings;
- Decision Record Repository records;
- risk assessments;
- findings;
- remediation plans;
- exceptions;
- governance classifications;
- governed documents and policy versions;
- observability and telemetry records.

---

## 5. Control Implementation Model

### 5.1 Purpose

`compliance.control_implementations` stores versioned descriptions of how a specific common-control version is implemented.

A control implementation is not the control definition. It is the platform’s scoped realization of that control.

### 5.2 Identity

Each implementation has:

- `control_implementation_id` — immutable database identifier;
- `implementation_key` — stable logical identifier;
- `version_number` — version of the implementation;
- `common_control_version_id` — exact version of the common control being implemented.

The pair:

```text
implementation_key + version_number
```

is unique.

### 5.3 Supported Scopes

The model supports these scope types:

| Scope type | Meaning |
|---|---|
| `PLATFORM` | Applies to the Platform Foundation or entire platform |
| `ORGANIZATION` | Applies to one participating organization |
| `SERVICE` | Applies to one platform service |
| `DEPLOYMENT` | Applies to one deployment of a service |
| `SERVICE_PARTICIPATION` | Applies to one organization’s participation in a service |

Exactly one compatible scope target may be populated.

Examples:

```text
PLATFORM
  No organization, service, deployment, or participation target

ORGANIZATION
  organization_id only

SERVICE
  service_id only

DEPLOYMENT
  deployment_id only

SERVICE_PARTICIPATION
  participation_agreement_id only
```

This avoids records that ambiguously claim to apply to several unrelated scopes.

### 5.4 Implementation States

Supported states are:

- `PLANNED`
- `PARTIALLY_IMPLEMENTED`
- `IMPLEMENTED`
- `OPERATING`
- `SUSPENDED`
- `RETIRED`

These states describe implementation maturity and operational condition. They do not replace an assessment result.

For example:

```text
implementation_state = OPERATING
```

means the implementation is in operation. It does not mean an assessor concluded that the control is effective.

### 5.5 Effective Dating

Each implementation includes:

- `valid_from`
- `valid_until`
- `review_at`

`valid_until` must be later than `valid_from`.

`review_at` must not precede `valid_from`.

Effective dating supports questions such as:

- Which implementation applied on a given date?
- Was the implementation still active?
- Was a review overdue?
- Did an assessment evaluate the implementation version that was actually in effect?

### 5.6 Supersession

`supersedes_control_implementation_id` connects a new version to an earlier implementation.

Supersession must not delete or rewrite the earlier record.

A later enforcement phase should ensure:

- the superseded record uses the same `implementation_key`;
- the new `version_number` is greater;
- supersession does not create a cycle;
- overlapping effective periods are governed;
- only approved workflows may publish an effective implementation version.

### 5.7 Decision Binding

`decision_id` may bind an implementation version to the Decision Record Repository.

This should be used when publication, approval, suspension, retirement, or supersession requires an attributable governed decision.

### 5.8 Ownership Reference

`responsible_owner_reference` identifies the accountable operational owner.

It is not PostgreSQL object ownership. It is a platform-level accountability reference.

A later implementation should resolve this reference to a governed identity, organization, service role, or responsibility assignment rather than relying indefinitely on free text.

---

## 6. Assurance Artifact Model

### 6.1 Purpose

`compliance.control_assurance_artifacts` stores immutable metadata for assurance artifacts.

The table does not store the artifact bytes.

### 6.2 Artifact Identity

Each artifact has:

- `control_assurance_artifact_id`
- `artifact_key`
- `artifact_type`

`artifact_key` must be stable and unique.

A useful artifact key should remain meaningful across systems and exports without exposing sensitive data.

Examples:

```text
config-snapshot:cad-api:2026-07-11T090000Z
scan-result:db-boundary:2026-Q3
test-result:foundation-schema-security:run-1842
attestation:shift-supervisor:assignment-8831
```

### 6.3 Artifact Types

The SQL baseline supports:

- `ATTESTATION`
- `CONFIGURATION_SNAPSHOT`
- `DOCUMENT`
- `LOG_EXTRACT`
- `QUERY_RESULT`
- `REPORT`
- `SCAN_RESULT`
- `SCREENSHOT`
- `TEST_RESULT`
- `OTHER`

`OTHER` should be used sparingly. Repeated use of the same unrecognized type should trigger a controlled schema or catalog extension rather than indefinite free-form classification.

### 6.4 Source Provenance

The model provides:

- `source_system_reference`
- `source_record_reference`

These fields describe where the artifact originated.

Examples:

```text
source_system_reference = "postgresql:dev_testing"
source_record_reference = "security_validation.foundation_review_summary"

source_system_reference = "graylog:production"
source_record_reference = "search:foundation-auth-failures:2026-07-01/2026-07-07"

source_system_reference = "github:kb2vhn/public-safety-platform"
source_record_reference = "commit:8229dce"
```

A future provider-neutral provenance model may replace free-form references with governed provider, source, and export records.

### 6.5 Storage Reference

`storage_reference` points to controlled storage.

It must not be interpreted as an unrestricted URL.

A storage reference may identify:

- an object-store key;
- a document repository identifier;
- a governed file record;
- an immutable export package;
- a content-addressed storage record;
- an archive object;
- a platform-managed artifact service record.

A storage reference should be opaque to ordinary clients. Access should occur through a controlled service that enforces authorization, classification, retention, and audit requirements.

### 6.6 Integrity Hash

`sha256_hash` stores exactly 32 bytes.

The hash applies to the collected artifact bytes in a defined canonical form.

The collection process must define:

- which bytes were hashed;
- whether compression occurred before or after hashing;
- whether container metadata was included;
- whether line endings or encoding were normalized;
- whether the artifact was encrypted before storage;
- how revalidation retrieves the same byte sequence.

A hash match demonstrates byte integrity relative to the recorded digest. It does not prove:

- the source was trustworthy;
- the artifact was complete;
- the artifact was collected correctly;
- the artifact supports the claimed control;
- the control was effective.

### 6.7 Collection and Applicability Time

The model distinguishes:

- `collected_at`
- `applicable_from`
- `applicable_until`

`collected_at` records when the artifact was collected.

The applicability interval describes the period the artifact is intended to represent.

Examples:

- a point-in-time configuration snapshot may have only `applicable_from`;
- a monthly report may apply from the first through the last day of the month;
- a policy document may apply for its effective period;
- a test result may apply only to a particular build or deployment.

Applicability must not be inferred solely from collection time.

### 6.8 Size and Media Type

Optional metadata includes:

- `media_type`
- `size_bytes`

`media_type` should use a recognized media type where possible.

`size_bytes` supports storage validation, transfer checks, and anomaly detection.

### 6.9 Classification and Retention

The model provides:

- `classification_reference`
- `retention_reference`

These values should eventually reference governed classification and retention records rather than remain unrestricted free text.

An assurance artifact may contain:

- security-sensitive configuration;
- identity information;
- personnel information;
- audit data;
- operational data;
- regulated information;
- secrets accidentally included by a collector.

Collection does not reduce the sensitivity of the source data.

### 6.10 Artifact Supersession

`supersedes_control_assurance_artifact_id` connects a newer artifact to an older artifact.

Examples:

- a corrected export supersedes a malformed export;
- a complete report supersedes an incomplete report;
- a new configuration baseline supersedes an earlier baseline.

Supersession does not erase the earlier artifact.

A later enforcement phase should prevent:

- self-supersession;
- cycles;
- supersession across unrelated artifact identities;
- silent replacement of an invalid artifact without a validation record explaining the problem.

### 6.11 Decision Binding

`decision_id` may bind artifact acceptance, correction, supersession, or governed collection to a Decision Record.

Routine automated artifact collection may not require an individual decision for each artifact. The collection policy, collector identity, and authorization path must still be attributable.

---

## 7. Artifact Validation Model

### 7.1 Purpose

`compliance.control_assurance_artifact_validations` records append-only validation results for an assurance artifact.

### 7.2 Validation Results

Supported results are:

- `VALID`
- `INVALID`
- `STALE`

Meanings:

| Result | Meaning |
|---|---|
| `VALID` | The artifact passed the stated validation method at the stated time |
| `INVALID` | The artifact failed the stated validation method |
| `STALE` | The artifact may remain intact but is no longer sufficiently current or applicable |

A `VALID` result is scoped to the validation method. It is not universal approval.

### 7.3 Validation Method

`validation_method` must describe the method used.

Examples:

```text
SHA-256 digest matched retrieved object bytes
Collector signature verified against active provider key
Source record still exists and matches exported identifier
Configuration snapshot schema validated
Report date range matched assessment period
Artifact classification and retention references resolved
```

Validation methods should become governed, versioned procedures when they influence important decisions.

### 7.4 Validator Attribution

`validated_by_reference` identifies the validating actor or service.

The model must distinguish:

- automated validator;
- human reviewer;
- service identity;
- organization;
- assessment team;
- independent auditor.

A future normalized actor-reference mechanism should replace unrestricted text.

### 7.5 Validation Supersession

`supersedes_validation_id` allows a later validation record to correct or replace the interpretation of an earlier validation without deleting it.

Examples:

- an artifact initially marked valid is later found incomplete;
- a stale artifact is refreshed and revalidated;
- a validation method is found defective;
- a source-system outage prevented a complete check.

### 7.6 Current Validation View

`compliance.current_control_assurance_artifact_validations` returns the most recently recorded validation result for each artifact.

This view is a convenience, not the historical source of truth.

Historical questions must query the append-only validation table using the appropriate point in time.

### 7.7 Freshness Is Contextual

An artifact may be cryptographically intact but operationally stale.

Freshness may depend on:

- control requirements;
- assessment procedure;
- system volatility;
- profile requirements;
- risk level;
- collection frequency;
- deployment lifecycle;
- incident state.

The validation table records the conclusion. The policy that determines required freshness belongs in governed control, profile, assessment, or monitoring definitions.

---

## 8. Implementation-to-Artifact Relationships

### 8.1 Purpose

`compliance.control_implementation_assurance_artifacts` connects assurance artifacts to versioned control implementations.

One artifact may support multiple implementations.

One implementation may be supported by multiple artifacts.

### 8.2 Relationship Types

Supported relationships are:

- `SUPPORTS`
- `DEMONSTRATES`
- `TESTS`
- `EXPLAINS`
- `CORROBORATES`

These terms describe intended use, not sufficiency.

Examples:

```text
CONFIGURATION_SNAPSHOT DEMONSTRATES an implementation setting

TEST_RESULT TESTS an implementation behavior

DOCUMENT EXPLAINS an operating procedure

LOG_EXTRACT CORROBORATES that the procedure operated during a period

ATTESTATION SUPPORTS an organizational responsibility assignment
```

### 8.3 Required for Assessment

`required_for_assessment` identifies artifacts expected by an assessment procedure or implementation review.

It does not guarantee that the artifact is valid, current, or sufficient.

### 8.4 Link Attribution

Each link records:

- `linked_at`
- `linked_by_reference`
- optional `applicability_notes`

The link itself is a governed historical assertion: someone or some service claimed the artifact was relevant to the implementation.

A later hardening phase should make these relationships append-only or correction-controlled.

---

## 9. Control Assessment Model

### 9.1 Purpose

`compliance.control_assessments` records append-only assessment results for a specific versioned control implementation.

### 9.2 Assessment Identity

Each assessment has:

- `control_assessment_id`
- `assessment_key`
- `control_implementation_id`

The assessment must always point to the implementation version actually assessed.

### 9.3 Assessment Procedure

`assessment_procedure_version` identifies the exact procedure used.

This is essential because assessment conclusions can change when:

- test steps change;
- sampling requirements change;
- thresholds change;
- profile requirements change;
- assessment tools change;
- interpretation guidance changes.

A future enhancement should replace free text with a foreign key to a governed document or assessment-procedure version.

### 9.4 Assessment Results

Supported results are:

- `EFFECTIVE`
- `PARTIALLY_EFFECTIVE`
- `INEFFECTIVE`
- `NOT_ASSESSED`

The distinction between `NOT_ASSESSED` and absent data is important.

`NOT_ASSESSED` is an explicit result. It means the assessment process recorded that no effectiveness conclusion was reached.

### 9.5 Confidence Levels

Optional confidence levels are:

- `LOW`
- `MODERATE`
- `HIGH`

Confidence reflects the assessor’s confidence in the conclusion, not the severity or importance of the control.

A confidence level should be supported by the assessment procedure, sample quality, artifact quality, and assessor rationale.

### 9.6 Assessment Timing

The model records:

- `assessed_at`
- `next_review_at`

`next_review_at` must be later than `assessed_at`.

Assessment validity may end earlier because of:

- implementation change;
- control-version change;
- deployment change;
- security incident;
- invalidated artifact;
- exception approval;
- organizational change;
- threat change;
- provider compromise.

### 9.7 Decision Binding

`decision_id` may bind the assessment conclusion to the Decision Record Repository.

Important conclusions—especially acceptance, exception, risk treatment, or authorization decisions—should be linked to a persistent decision record.

### 9.8 Append-Only Requirement

Assessment rows must not be silently changed.

A corrected or later conclusion should be a new assessment record.

A future enhancement may add explicit supersession between assessment records if the correction workflow requires it.

---

## 10. Assessment-to-Artifact Relationships

### 10.1 Purpose

`compliance.assessment_assurance_artifacts` records which assurance artifacts were used in a control assessment.

This is separate from artifacts generally linked to the implementation.

An implementation may have many available artifacts, while an assessor may use only a subset.

### 10.2 Usage Types

Supported usage types are:

- `INPUT`
- `SUPPORTING`
- `CONTRADICTING`
- `OUTPUT`

Examples:

```text
INPUT
  An artifact examined by the assessor

SUPPORTING
  An artifact that supports the assessment conclusion

CONTRADICTING
  An artifact that conflicts with other information or the proposed conclusion

OUTPUT
  A report or result created by the assessment process
```

The `CONTRADICTING` relationship is important. The model must not hide artifacts merely because they weaken an expected conclusion.

### 10.3 Attribution

Each relationship records:

- `linked_at`
- `linked_by_reference`
- optional `assessor_notes`

A later hardening phase should prevent destructive changes to assessment-artifact relationships.

---

## 11. Immutability and Controlled Correction

### 11.1 Records Expected to Be Append-Only

At minimum, the following should be append-only or correction-controlled:

- `compliance.control_assurance_artifacts`
- `compliance.control_assurance_artifact_validations`
- `compliance.control_implementation_assurance_artifacts`
- `compliance.control_assessments`
- `compliance.assessment_assurance_artifacts`

Control implementations are versioned rather than treated as a simple mutable current-state table.

### 11.2 Database Enforcement

Production enforcement should not depend only on application behavior.

The database design should eventually provide:

- no direct `UPDATE` or `DELETE` grants to runtime roles;
- controlled functions for insert, supersession, validation, and linkage;
- ownership by non-login roles;
- explicit grants to narrow runtime roles;
- triggers only where they provide clear defense-in-depth value;
- append-only validation tests;
- monitoring for unauthorized changes;
- off-host audit export;
- backup and restore procedures that preserve history.

### 11.3 Correction Pattern

A correction should follow this pattern:

```text
Original record remains
        |
        v
New record identifies correction or supersession
        |
        v
Decision or reason is recorded
        |
        v
Current-state view selects the latest applicable record
```

Silent updates are not an acceptable correction mechanism for historical assurance records.

---

## 12. Access-Control Model

### 12.1 Least Privilege

No ordinary runtime identity should receive broad write access to the `compliance` schema.

Expected role separation includes:

- schema owner;
- migration executor;
- artifact collector;
- artifact validator;
- control implementation manager;
- assessor;
- compliance reviewer;
- read-only auditor;
- retention or storage service;
- security monitor;
- break-glass administrator.

These are database and application responsibilities, not necessarily one-to-one job titles.

### 12.2 Collector Restrictions

A collector may be allowed to:

- register an artifact;
- provide provenance;
- provide integrity metadata;
- link the artifact to an authorized collection job.

A collector should not automatically be allowed to:

- mark its own artifact valid;
- assess the control;
- approve an exception;
- change retention;
- erase the artifact;
- alter an assessment conclusion.

### 12.3 Validator Restrictions

A validator may be allowed to:

- retrieve an artifact through controlled storage;
- verify integrity;
- record a validation result.

A validator should not automatically be allowed to:

- alter artifact metadata;
- rewrite prior validation results;
- change the control implementation;
- issue a compliance conclusion.

### 12.4 Assessor Restrictions

An assessor may be allowed to:

- view authorized implementations and artifacts;
- link artifacts to an assessment;
- record an assessment result.

An assessor should not automatically be allowed to:

- modify source artifacts;
- modify validation history;
- approve their own exception;
- alter the common control catalog;
- alter the assessment procedure version after the fact.

### 12.5 Row-Level Security

RLS may be appropriate where records are partitioned logically by:

- organization;
- service;
- deployment;
- participation agreement;
- assessment authority;
- classification;
- tenant or jurisdiction.

RLS must not be introduced merely because it is available.

Before enabling RLS, the design must define:

- the authoritative session context;
- how an Authorization Lease is presented;
- how organization and service scope are derived;
- how background jobs operate;
- how auditors receive cross-scope access;
- how owners and superusers are constrained operationally;
- how `FORCE ROW LEVEL SECURITY` affects controlled functions;
- how failures are tested.

RLS supplements ownership, grants, controlled APIs, and decision enforcement. It does not replace them.

---

## 13. Classification, Retention, and Disposal

### 13.1 Classification

An assurance artifact inherits the sensitivity of its contents and source.

Examples:

- a configuration snapshot may reveal security architecture;
- a log extract may contain identity or operational data;
- a screenshot may expose credentials or protected information;
- a report may aggregate otherwise low-risk data into sensitive information.

Collectors must minimize unnecessary sensitive content.

### 13.2 Retention

Retention must be policy-driven.

Retention may depend on:

- control requirements;
- compliance profile;
- audit cycle;
- organization policy;
- litigation hold;
- incident status;
- risk acceptance period;
- implementation lifetime;
- supersession;
- contractual obligations.

`retention_reference` identifies the governing retention rule.

### 13.3 Disposal

Deleting artifact bytes must not silently erase the historical database record.

A disposal workflow should record:

- authorization;
- applicable retention rule;
- disposal time;
- disposal method;
- actor;
- storage result;
- decision reference;
- whether metadata remains;
- whether the digest remains;
- whether a legal hold prevented disposal.

A legal-evidence system may have entirely different disposal requirements and must remain separate.

---

## 14. Storage and Retrieval Requirements

Controlled artifact storage should provide:

- encryption in transit;
- encryption at rest where required;
- authenticated service access;
- authorization checks;
- integrity verification;
- durable object identifiers;
- retention controls;
- deletion controls;
- backup;
- recovery testing;
- malware scanning where applicable;
- object immutability where justified;
- versioning where justified;
- audit logs;
- capacity monitoring;
- export capability;
- provider-independent metadata.

The database must not assume that a storage reference is permanently reachable.

Validation records should expose storage failures, missing objects, digest mismatches, or stale content.

---

## 15. Relationship to Decision Records

The Decision Record Repository remains the canonical explanation of authorization and governed conclusions.

Assurance artifacts may support a Decision Record, but the artifact is not the decision.

A complete Justification Chain may include:

```text
Common control version
    ->
Control implementation version
    ->
Applicable assurance artifacts
    ->
Artifact validation records
    ->
Control assessment
    ->
Finding, exception, remediation, or risk record
    ->
Decision Record
```

Each step should remain independently attributable.

---

## 16. Relationship to Findings, Remediation, Exceptions, and Risk

Assessment outcomes may lead to:

- findings;
- remediation plans;
- exceptions;
- risk records;
- authorization restrictions;
- control suspension;
- implementation supersession;
- additional monitoring.

These later records should reference the assessment or Decision Record rather than duplicate its content.

An `INEFFECTIVE` assessment should not automatically create an exception.

A `VALID` artifact should not automatically close a finding.

A remediation record should not erase the assessment that identified the weakness.

---

## 17. Automated Collection

Automated collectors are expected for many artifact types.

Examples:

- database boundary validation;
- schema privilege reports;
- function security reports;
- backup verification;
- restore-test results;
- endpoint configuration snapshots;
- vulnerability scans;
- source-control commit records;
- CI test results;
- deployment manifests;
- monitoring health reports;
- certificate inventory;
- provider-delivery status.

Automated collection must record:

- collector identity;
- collection policy or job;
- source system;
- source record;
- collection time;
- artifact hash;
- storage reference;
- failures;
- partial collection;
- retry behavior.

A collector must fail explicitly when it cannot establish the required artifact properties.

---

## 18. Manual Artifacts and Attestations

Manual artifacts may be necessary, but they require stronger provenance controls.

Examples:

- signed management attestation;
- approved operating procedure;
- assessor worksheet;
- meeting approval record;
- third-party report.

Manual collection should record:

- submitting identity;
- originating organization;
- document version;
- signature or approval reference where applicable;
- collection method;
- source document identifier;
- hash;
- storage reference;
- classification;
- retention.

An attestation remains an assertion by an identified party. It is not automatically an independent verification.

---

## 19. Validation and Assessment Failure Modes

The model must support explicit failure states.

### 19.1 Collection Failures

Examples:

- source unavailable;
- partial export;
- malformed output;
- storage failure;
- hash calculation failure;
- unknown media type;
- classification unresolved;
- retention unresolved;
- collector unauthorized.

A failed collection must not create a record that appears complete.

### 19.2 Validation Failures

Examples:

- hash mismatch;
- storage object missing;
- signature invalid;
- source record unavailable;
- applicability period inconsistent;
- artifact stale;
- artifact incomplete;
- collector identity revoked;
- validation method obsolete.

The failure should be recorded as an append-only validation result where an artifact record already exists.

### 19.3 Assessment Failures

Examples:

- required artifacts missing;
- artifacts invalid;
- artifacts stale;
- conflicting artifacts unresolved;
- assessment procedure incomplete;
- assessor unauthorized;
- implementation version changed during assessment;
- scope could not be established.

When no effectiveness conclusion can be reached, use `NOT_ASSESSED` rather than manufacturing a positive or negative result.

---

## 20. Performance and Scale

The model is designed for modest hardware and should avoid unnecessary database bloat.

### 20.1 Database Content

Store metadata in PostgreSQL, not large artifact bodies.

### 20.2 Index Discipline

Indexes should support:

- implementation lookup by control and scope;
- current implementation selection;
- artifact lookup by type and collection time;
- validation history by artifact and time;
- assessment lookup by implementation and time;
- reverse lookup from artifact to implementations or assessments.

Indexes must be justified by actual query patterns.

### 20.3 Append-Only Growth

Append-only tables will grow continuously.

Operational planning should address:

- expected artifact rate;
- validation frequency;
- assessment frequency;
- index growth;
- vacuum behavior;
- archive strategy;
- backup size;
- restore time;
- historical query needs.

Partitioning should not be introduced until volume and maintenance evidence justify it.

### 20.4 Artifact Storage Capacity

Artifact storage capacity must be governed separately from PostgreSQL capacity.

The platform should track:

- object count;
- bytes stored;
- collection rate;
- retention horizon;
- failed deletions;
- orphaned storage objects;
- database records with missing objects;
- objects without database records.

---

## 21. SQL Object Map

Migration `089_control_implementations_and_assurance_artifacts.sql` defines:

### Tables

```text
compliance.control_implementations
compliance.control_assurance_artifacts
compliance.control_assurance_artifact_validations
compliance.control_implementation_assurance_artifacts
compliance.control_assessments
compliance.assessment_assurance_artifacts
```

### View

```text
compliance.current_control_assurance_artifact_validations
```

### Primary Relationships

```text
compliance.control_implementations.common_control_version_id
    -> compliance.common_control_versions.common_control_version_id

compliance.control_implementations.organization_id
    -> organization.organizations.organization_id

compliance.control_implementations.service_id
    -> service.platform_services.service_id

compliance.control_implementations.deployment_id
    -> service.deployments.deployment_id

compliance.control_implementations.participation_agreement_id
    -> service.participation_agreements.participation_agreement_id

compliance.control_implementations.decision_id
    -> decision.decision_records.decision_id

compliance.control_assurance_artifacts.decision_id
    -> decision.decision_records.decision_id

compliance.control_assurance_artifact_validations.control_assurance_artifact_id
    -> compliance.control_assurance_artifacts.control_assurance_artifact_id

compliance.control_assurance_artifact_validations.decision_id
    -> decision.decision_records.decision_id

compliance.control_implementation_assurance_artifacts.control_implementation_id
    -> compliance.control_implementations.control_implementation_id

compliance.control_implementation_assurance_artifacts.control_assurance_artifact_id
    -> compliance.control_assurance_artifacts.control_assurance_artifact_id

compliance.control_assessments.control_implementation_id
    -> compliance.control_implementations.control_implementation_id

compliance.control_assessments.decision_id
    -> decision.decision_records.decision_id

compliance.assessment_assurance_artifacts.control_assessment_id
    -> compliance.control_assessments.control_assessment_id

compliance.assessment_assurance_artifacts.control_assurance_artifact_id
    -> compliance.control_assurance_artifacts.control_assurance_artifact_id
```

---

## 22. Required Controlled APIs

Direct runtime writes should eventually be replaced by narrow database or service APIs.

Candidate operations include:

```text
create_control_implementation_version
publish_control_implementation
suspend_control_implementation
retire_control_implementation

register_control_assurance_artifact
supersede_control_assurance_artifact
record_control_assurance_artifact_validation

link_artifact_to_control_implementation
unlink_artifact_through_controlled_correction

record_control_assessment
link_artifact_to_control_assessment
record_assessment_correction
```

Each operation should:

- validate caller authority;
- validate scope;
- validate effective time;
- validate referenced objects;
- reject self-approval where prohibited;
- create or reference a Decision Record when required;
- use PostgreSQL time for authoritative timestamps;
- produce auditable outcomes;
- avoid granting broad table modification rights.

---

## 23. Validation Expectations

Foundation validation should check at least:

- assurance-artifact tables exist;
- every table has a primary key;
- `PUBLIC` has no privileges;
- runtime roles do not receive direct `UPDATE`, `DELETE`, or `TRUNCATE` on append-only tables;
- artifact hashes are exactly 32 bytes;
- storage references are nonblank;
- invalid applicability ranges are rejected;
- self-supersession is rejected;
- validation results use approved values;
- assessment results use approved values;
- append-only controls are installed;
- owner roles cannot log in;
- controlled functions use fixed `search_path`;
- RLS state matches the approved design;
- migration checksums are recorded;
- artifacts identified as current can still be historically reconstructed.

---

## 24. Example Lifecycle

### 24.1 Implementation Creation

```text
1. Common control version is approved.
2. A scoped implementation version is drafted.
3. Responsible owner and procedure references are assigned.
4. Approval workflow reaches a decision.
5. The implementation becomes effective.
```

### 24.2 Artifact Collection

```text
1. Authorized collector retrieves source data.
2. Collector creates a canonical artifact.
3. SHA-256 is calculated.
4. Artifact bytes are stored in controlled storage.
5. Immutable artifact metadata is registered.
6. Artifact is linked to the implementation.
```

### 24.3 Artifact Validation

```text
1. Validator retrieves the controlled object.
2. Validator confirms digest and required provenance.
3. Validator checks freshness and applicability.
4. Append-only validation result is recorded.
```

### 24.4 Control Assessment

```text
1. Assessor selects the exact implementation version.
2. Required artifacts are identified.
3. Current and historical validations are reviewed.
4. Supporting and contradicting artifacts are linked.
5. Assessment procedure is executed.
6. Append-only assessment result is recorded.
7. A Decision Record is created or referenced when required.
8. Findings, remediation, exceptions, or risk records follow as needed.
```

### 24.5 Correction

```text
1. A defect is identified in an artifact or assessment.
2. Existing records remain unchanged.
3. A new artifact, validation, or assessment record is created.
4. Supersession or correction relationship is recorded.
5. Decision and reason are retained.
6. Current-state views expose the latest applicable result.
```

---

## 25. Non-Goals

This model does not provide:

- legal evidence management;
- property-room management;
- criminal case evidence handling;
- chain-of-custody workflows;
- discovery or disclosure processing;
- digital forensics;
- document-content storage inside PostgreSQL;
- automatic compliance certification;
- automatic risk acceptance;
- automatic exception approval;
- unrestricted auditor access;
- provider-specific storage implementation;
- final runtime role definitions;
- final RLS policies;
- final append-only trigger or function enforcement.

---

## 26. Future Hardening Work

Before production use, the Foundation must complete:

1. non-login ownership roles;
2. migration and deployment roles;
3. runtime collector, validator, assessor, and reviewer roles;
4. controlled insert and supersession APIs;
5. append-only enforcement;
6. correction workflows;
7. normalized actor references;
8. governed artifact-type catalog if extension is needed;
9. governed validation-method versions;
10. governed assessment-procedure versions;
11. classification and retention foreign keys;
12. storage-provider registry and controlled retrieval;
13. orphan detection between database and artifact storage;
14. RLS where scope isolation requires it;
15. migration checksums;
16. off-host audit export;
17. backup and restore testing;
18. integrity verification after restoration;
19. break-glass access controls;
20. trusted rebuild and recovery procedures.

---

## 27. Architectural Decisions

The following decisions are normative for the Foundation baseline:

- Use **assurance artifact**, not **evidence**, for compliance-support records.
- Reserve **evidence** for future legal or investigative domain models.
- Store artifact metadata in PostgreSQL and artifact bytes in controlled storage.
- Require a SHA-256 digest for every assurance artifact.
- Keep artifact validation history append-only.
- Keep control assessment history append-only.
- Version and effective-date control implementations.
- Allow one artifact to support multiple implementations and assessments.
- Preserve contradicting artifacts rather than filtering them out.
- Do not infer compliance from artifact existence.
- Do not infer control effectiveness from artifact validity.
- Bind important conclusions to Decision Records.
- Enforce least privilege at both the service and PostgreSQL layers.
- Preserve historical explainability over convenience.

---

## 28. Summary

The assurance-artifact model provides a durable boundary between:

- control definition;
- control implementation;
- artifact collection;
- artifact validation;
- control assessment;
- compliance conclusion;
- risk treatment;
- legal evidence.

That separation prevents ambiguous terminology, reduces the chance of overstating what a record proves, and preserves the historical Justification Chain needed to explain platform decisions years after the original systems, personnel, and policies have changed.

