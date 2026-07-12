# Data Classification and Information Governance Model

> **Document status:** Normative Platform Foundation architecture.
>
> **Implementation status:** The Foundation SQL migrations provide an initial structural implementation. A requirement described here is not considered fully enforced until the applicable database controls, deployment roles, runtime behavior, automated tests, and operational safeguards are in place.

## Purpose

Make classification and handling requirements first-class inputs to access, storage, disclosure, retention, and integration decisions.

## Architectural Requirements

### Classification Scheme

A governed scheme defines classification levels, categories, caveats, handling rules, owners, versions, and effective periods.

Examples may include public, internal, sensitive, CJIS-related, PHI-related, tax information, credentials, security telemetry, or organization-defined categories. The Foundation does not hard-code one regulatory vocabulary.

### Assignment

Classification may be assigned to a record, document, field group, attachment, event, or resource. The assignment identifies the authority, source, confidence or basis where applicable, and effective period.

### Handling Rules

Classification may affect:

- Authorization,
- Encryption,
- Display and masking,
- Export and provider delivery,
- Retention and disposition,
- Backup location,
- Logging and telemetry,
- Cross-organization sharing,
- Incident response.

### Inheritance and Conflict

Derived records inherit classifications according to governed rules. When multiple applicable classifications conflict, the more restrictive handling requirement applies unless a documented rule resolves the conflict.

### History

Classification changes do not erase prior handling context. Decisions retain the classification version used at the time.

## SQL Implementation Mapping

Migration `082_data_classification_and_governance.sql` provides the principal structural implementation. Migrations `086`, `088–090`, `095–097`, and future domain migrations consume classification rules.

The migration mapping identifies the current structural implementation. It does not, by itself, prove that every requirement in this document is operationally enforced.

## Validation Expectations

The Foundation SQL test framework must test the requirements that can be demonstrated at the database boundary. Runtime, deployment, recovery, and provider behavior must be tested in their respective layers.

## Related Documents

- [Governed Document and Policy Versioning](governed-document-and-policy-versioning-model.md)
- [Decision Record Repository](decision-record-repository.md)
- [Compliance and Control Framework](compliance-and-control-framework.md)
