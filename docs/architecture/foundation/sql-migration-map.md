# SQL Migration Map

> **Document status:** Normative Platform Foundation architecture.
>
> **Implementation status:** The Foundation SQL migrations provide an initial structural implementation. A requirement described here is not considered fully enforced until the applicable database controls, deployment roles, runtime behavior, automated tests, and operational safeguards are in place.

## Purpose

Map the normative Foundation architecture to the current manifest-driven SQL implementation.

## Architectural Requirements

### Range Allocation

| Range | Purpose |
|---|---|
| `000–099` | Platform Foundation |
| `100–199` | Operational Resources |
| `200–299` | CAD |
| `300–399` | RMS |
| `400–499` | Evidence and Property |
| `500–599` | Personnel extensions |
| `600–699` | Fleet extensions |
| `700–799` | Fire/EMS |
| `800–899` | Future modules |
| `900–999` | Deployment and bootstrap |

### Current Foundation Manifest

| ID | Migration | Principal purpose |
|---|---|---|
| `000` | `000_platform_initialization.sql` | Schemas, extension isolation, migration registry, baseline privilege hardening |
| `010` | `010_cryptographic_and_device_trust.sql` | Cryptographic identities, certificates, device trust, and revocation foundations |
| `020` | `020_identity.sql` | Human and service identity foundations |
| `025` | `025_identity_lifecycle.sql` | Identity lifecycle state and history |
| `030` | `030_organizations_and_jurisdictions.sql` | Organizations, jurisdictions, and scoped relationships |
| `035` | `035_platform_services_and_configuration.sql` | Platform services and governed configuration |
| `040` | `040_service_participation_and_federation.sql` | Organization participation and federation |
| `045` | `045_attestations_and_access_eligibility.sql` | Organizational attestations and eligibility |
| `050` | `050_approval_framework.sql` | Reusable approval requests and decisions |
| `055` | `055_authority_purpose_and_authorization_policy.sql` | Authority, purpose, and authorization-policy versions |
| `060` | `060_sessions.sql` | Operator and service sessions |
| `065` | `065_authorization_leases.sql` | Short-lived, revocable authorization capabilities |
| `070` | `070_postgresql_trust_gate.sql` | Database-side trust assertion gate |
| `075` | `075_controlled_authorization_api.sql` | Controlled Authorization Lease verification and protected API foundations |
| `080` | `080_decision_record_repository.sql` | Decision and evaluation records |
| `082` | `082_data_classification_and_governance.sql` | Classification and information-governance structures |
| `084` | `084_lifecycle_and_historical_lineage.sql` | General lifecycle, versioning, and lineage |
| `086` | `086_governed_documents_and_policy_versions.sql` | Governed documents and immutable policy versions |
| `087` | `087_common_control_catalog.sql` | Reusable common-control catalog |
| `088` | `088_compliance_profiles_and_requirement_mappings.sql` | Versioned profiles, requirements, and control mappings |
| `089` | `089_control_implementations_and_assurance_artifacts.sql` | Scoped implementations and assurance artifacts |
| `090` | `090_assessments_findings_remediation_exceptions_and_risk.sql` | Assessment, findings, remediation, exceptions, and risk |
| `091` | `091_threat_records_and_abuse_case_mappings.sql` | Threats, abuse cases, and control/risk mappings |
| `092` | `092_resilience_availability_recovery_and_continuity.sql` | Criticality, continuity, backup, failover, and recovery |
| `093` | `093_workload_registry_performance_budgets_and_resource_governance.sql` | Workload ownership, budgets, and resource governance |
| `094` | `094_client_and_deployment_performance_profiles.sql` | Client and deployment expectations |
| `095` | `095_observability_health_and_operational_telemetry.sql` | Canonical telemetry and health |
| `096` | `096_monitoring_subscriptions_and_provider_delivery_state.sql` | Provider-neutral subscriptions and delivery state |
| `097` | `097_provider_integration_outbox.sql` | Transactional integration outbox |
| `098` | `098_security_boundaries_and_role_separation.sql` | Role classes, incompatibility, and security-boundary posture |
| `099` | `099_foundation_validation.sql` | Catalog inventories and Foundation validation views |

### Authoritative Order

Migration order is defined by:

```text
sql/schema/manifests/foundation.manifest
```

The filesystem directory listing is not the migration-order authority.

### Operational Scripts

```text
sql/schema/scripts/apply_foundation.sh
sql/schema/scripts/validate_foundation.sh
```

### Test Framework

The test framework intentionally remains self-contained:

```text
sql/test-framework/
├── INSTALL.txt
├── Makefile
└── sql/
    ├── schema/scripts/test_foundation.sh
    ├── tests/
    └── test-results/
```

It reads the live manifest and migrations from `sql/schema/`, installs test-only objects in a disposable database, and writes reviewable log and summary files beneath `sql/test-framework/sql/test-results/`.

### Migration Completion Rule

A migration is not complete merely because it executes. It should:

1. Match the governing architecture,
2. Register successfully,
3. Install in manifest order on a clean database,
4. Preserve prior migration invariants,
5. Pass structural and security tests,
6. Add behavioral and negative tests where applicable,
7. Update this map and related documentation.

### Current Integrity Limitation

The migration registry supports checksums, but current migrations may still register `NULL` checksum values. File-digest population and enforcement must be completed before the Foundation is declared stable.

## SQL Implementation Mapping

This document maps all current Foundation migrations `000–099`. The manifest and migration files remain the implementation source of truth.

The migration mapping identifies the current structural implementation. It does not, by itself, prove that every requirement in this document is operationally enforced.

## Validation Expectations

The Foundation SQL test framework must test the requirements that can be demonstrated at the database boundary. Runtime, deployment, recovery, and provider behavior must be tested in their respective layers.

## Related Documents

- [Schema Naming Conventions](schema-naming-conventions.md)
- [Database Security](database-security-model.md)
- [Platform Boundaries](platform-boundaries.md)
