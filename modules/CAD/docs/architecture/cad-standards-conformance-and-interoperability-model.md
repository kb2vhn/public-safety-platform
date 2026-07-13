# CAD Standards-Conformance and Interoperability Model

> **Owner:** Iron Signal Systems
>
> **Module:** Computer Aided Dispatch
>
> **Document status:** Normative CAD architecture
>
> **Implementation status:** Conformance-governance design only

## Architecture Ownership

This document is authoritative for identifying, versioning, implementing,
testing, evidencing, and claiming conformance with external CAD, emergency
communications, information-exchange, GIS, and interoperability standards.

The [Communications and External-Integration Model](communications-and-external-integration-model.md)
remains authoritative for canonical CAD records, provider independence,
delivery intent, retry, acknowledgment, and reconciliation.

The [CAD Testing and Acceptance Model](cad-testing-and-acceptance-model.md) is
authoritative for campaign execution, hostile testing, telemetry, and acceptance
evidence.

## Purpose

Prevent vague or unsupported statements such as:

- Standards compliant.
- APCO compliant.
- NENA compliant.
- NIEM compatible.
- Interoperable.

A valid conformance claim must identify the exact standard, edition, applicable
provisions, implementation boundary, test profile, evidence, deviations, and
accepted release.

## Standards Applicability Register

CAD must maintain one authoritative register containing, for each evaluated
standard or profile:

```text
standard_id
publisher
exact_title
edition_or_version
publication_date
status
source_reference
applicability
applicable_deployment_profiles
applicable_integrations
applicable_clauses
implementation_owner
test_profile_id
known_deviations
evidence_references
review_date
superseding_edition
acceptance_state
```

### Controlled Standard Status

```text
FINAL
CANDIDATE
DRAFT
RETIRED
SUPERSEDED
UNKNOWN
```

A candidate, draft, or proposed edition must not silently replace an accepted
final edition.

### Controlled Applicability

```text
REQUIRED
CONDITIONAL
OPTIONAL
NOT_APPLICABLE
NOT_EVALUATED
```

`NOT_APPLICABLE` requires a recorded reason. `NOT_EVALUATED` is not equivalent
to conformance.

### Controlled Conformance State

```text
NOT_EVALUATED
NOT_APPLICABLE
MAPPED
IMPLEMENTED
TESTED
PARTIALLY_CONFORMANT
CONFORMANT
CONFORMANT_WITH_GOVERNED_DEVIATIONS
SUPERSEDED
WITHDRAWN
```

## Initial Standards Families

The applicability register must evaluate, without automatically claiming, at
least:

- APCO Multi-Functional Multi-Discipline CAD Minimum Functional Requirements.
- APCO public-safety communications incident-handling standards.
- NENA i3 and Emergency Incident Data Object specifications where NG9-1-1
  exchange is in scope.
- NENA NG9-1-1 GIS data requirements where applicable.
- NIEM Information Exchange Package Documentation and applicable domain models.
- State and federal query-system requirements.
- State, regional, county, or agency 911, GIS, radio, records, retention, and
  message-switch profiles.
- Selected alarm, paging, station-alerting, AVL, mapping, routing, telephony,
  mutual-aid, and public-warning interface specifications.
- Applicable accessibility, security, cryptography, and software-supply-chain
  standards governed elsewhere in the Platform Foundation.

Evaluation does not imply applicability. Applicability depends on the exact
feature, deployment, jurisdiction, provider, and contract.

## Clause-Level Traceability

Every claimed applicable normative provision must map through:

```text
standard and exact edition
→ clause or requirement
→ applicability decision
→ Iron Signal requirement
→ architecture invariant
→ implementation boundary
→ controlled operation or exchange
→ positive test
→ malformed and hostile tests
→ interoperability test
→ evidence artifact
→ reviewer
→ conformance decision
```

A document-level claim without clause-level traceability is prohibited.

## Conformance Claim Rules

A release may claim `CONFORMANT` only when:

- The exact standard and edition are named.
- Every applicable mandatory provision is identified.
- Every mandatory provision has implementation and evidence mappings.
- Required conformance and interoperability tests pass.
- No unresolved mandatory deviation exists.
- The exact release, adapter, configuration, schema, and environment are bound
  to the claim.
- The designated conformance authority approves the claim.

`CONFORMANT_WITH_GOVERNED_DEVIATIONS` requires:

- Exact deviating clauses.
- Operational and interoperability impact.
- Compensating behavior where applicable.
- Owner.
- Review and expiration date.
- Customer or deployment disclosure where material.

The word `compatible` must not be used to imply conformance.

## Canonical and External Semantics

Iron Signal canonical CAD state must remain independent from any one external
standard or provider representation.

Every adapter must define:

- Canonical-to-external mapping.
- External-to-canonical mapping.
- Lossless, lossy, derived, omitted, and provider-only fields.
- Identifier preservation.
- Time and time-zone handling.
- Enumeration and code-list handling.
- Precision and truncation behavior.
- Unknown-value behavior.
- Version negotiation.
- Extension behavior.
- Security and classification mapping.
- Error and rejection mapping.
- Reconciliation behavior.

Transport success, schema validity, and provider acknowledgment do not establish
semantic interoperability or authoritative CAD success.

## Required Conformance Test Classes

Applicable tests must include:

- Official or accepted reference examples.
- Minimum and maximum values.
- Missing required content.
- Unknown optional content.
- Unknown enumerations and code values.
- Invalid encoding and character sets.
- International and accessibility-relevant text.
- Time-zone and daylight-saving transitions.
- Identifier collision and reuse.
- Duplicate, replayed, delayed, and reordered messages.
- Version upgrade and downgrade behavior.
- Extension acceptance and rejection.
- Authentication and authorization failure.
- Partial transport success.
- Provider disagreement.
- Round-trip semantic fidelity.
- Loss and precision analysis.
- Outage and reconciliation.
- Replacement-adapter compatibility.
- Cross-vendor test fixtures when available.
- Direct attempts to convert provider state into CAD authority.

## Interoperability Evidence

Interoperability is accepted only when evidence includes:

- Exact participating implementations and versions.
- Exact standards and profiles.
- Configuration and feature flags.
- Test dataset and message corpus.
- Direction of exchange.
- Expected and actual semantic result.
- Duplicate, retry, ordering, outage, and recovery behavior.
- Security and classification result.
- Unmapped or lossy content.
- Failure classifications.
- Retained logs and message-safe digests.
- Independent review.

A simulator is appropriate for contract development. At least one real
implementation or independently maintained conformance fixture is required
before a cross-vendor interoperability claim.

## Standards Change Management

When a standard changes:

1. Record the new edition without replacing the accepted edition.
2. Classify it as final, candidate, draft, retired, or superseding.
3. Perform applicability and impact analysis.
4. Identify changed, added, and removed provisions.
5. Update traceability.
6. Add or revise test fixtures.
7. Evaluate backward and forward compatibility.
8. Retest affected adapters and canonical mappings.
9. Update conformance claims only after accepted evidence exists.
10. Retain the prior claim and supersession lineage.

## Unsupported and Proprietary Contracts

A proprietary provider contract must receive the same version, mapping,
testing, evidence, and deviation discipline as a public standard.

A provider-specific feature must not become an undocumented CAD domain rule.
Provider exit and replacement behavior must remain explicit.

## Acceptance

Standards-conformance acceptance requires:

- Complete applicability register for the accepted scope.
- Exact standard editions.
- Clause-level mappings.
- Passing conformance and hostile tests.
- Passing semantic interoperability tests where claimed.
- Known deviations governed.
- Exact release and adapter identities.
- No provider acknowledgment treated as CAD commitment.
- No unresolved mandatory provision hidden by a broad compliance statement.
- Conformance authority approval.

## Reference Baselines

The register should begin from official publisher material, including current
APCO standards and standards-development status, NENA standards and i3/EIDO
material, and the NIEM IEPD specification. The register—not this paragraph—must
retain the exact edition actually accepted by Iron Signal Systems.
