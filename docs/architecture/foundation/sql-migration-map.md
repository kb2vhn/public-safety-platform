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
| `100–199` | Shared resources and cross-module capabilities |
| `200–899` | Module-owned migrations allocated by an approved module-range decision |
| `900–999` | Deployment and bootstrap |

### Current Foundation Manifest

| ID | Migration | Principal purpose |
|---|---|---|
| `000` | `000_platform_initialization.sql` | Schemas, extension isolation, migration registry, baseline privilege hardening |
| `010` | `010_cryptographic_and_device_trust.sql` | Cryptographic identities, certificates, device trust, and revocation foundations |
| `020` | `020_identity.sql` | Human and service identity foundations |
| `025` | `025_identity_lifecycle.sql` | Identity lifecycle state and history |
| `030` | `030_organizations_and_governed_scopes.sql` | Organizations, governed scopes, and scoped relationships |
| `035` | `035_platform_services_and_configuration.sql` | Platform services and governed configuration |
| `040` | `040_service_participation_and_federation.sql` | Organization participation and federation |
| `045` | `045_attestations_and_access_eligibility.sql` | Organizational attestations and eligibility |
| `050` | `050_approval_framework.sql` | Reusable approval requests and decisions |
| `055` | `055_authority_purpose_and_authorization_policy.sql` | Authority, purpose, and authorization-policy versions |
| `060` | `060_sessions.sql` | Operator and service sessions |
| `065` | `065_authorization_leases.sql` | Short-lived, revocable authorization capabilities |
| `070` | `070_postgresql_authentication_assertion_gate.sql` | Authentication Assertion state machine, local verification gate, rejection, expiration, revocation, and exact-context single-use consumption |
| `072` | `072_postgresql_session_control.sql` | Authentication Assertion linkage, current-trust revalidation, atomic session establishment and step-up completion, controlled activity, lock, administrative unlock, expiration, revocation, termination, and same-transaction events |
| `075` | `075_controlled_authorization_api.sql` | Controlled Authorization Lease verification and protected API foundations |
| `080` | `080_decision_record_repository.sql` | Decision and evaluation records |
| `081` | `081_postgresql_authorization_decision_and_lease_issuance.sql` | Typed policy applicability, policy-stage mapping, lease-request Decision Record fields, one issuing-decision/one issued-lease cardinality, core decision-to-lease binding, lease chronology and state shape, and authority/use evidence binding |
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
| `096` | `096_monitoring_subscriptions_and_delivery_state.sql` | Provider-neutral subscriptions and delivery state |
| `097` | `097_external_integration_outbox.sql` | Transactional integration outbox |
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
test-framework/
├── INSTALL.txt
├── Makefile
└── sql/
    ├── schema/scripts/test_foundation.sh
    ├── tests/
    │   ├── foundation-tests.manifest
    │   ├── foundation-concurrency-tests.manifest
    │   ├── foundation/
    │   └── concurrency/
    └── test-results/
```

It reads the live manifest and migrations from `sql/schema/`, installs
test-only objects in a disposable database, runs both sequential SQL tests and
Bash-orchestrated multi-connection concurrency tests, and writes reviewable
log and summary files beneath `test-framework/sql/test-results/`.

### Accepted Phase 1 Mapping

The Authentication Assertion Phase 1 boundary is implemented principally by:

```text
sql/schema/migrations/foundation/070_postgresql_authentication_assertion_gate.sql
test-framework/sql/tests/foundation/090_authentication_assertion_behavior.sql
test-framework/sql/tests/foundation/100_authentication_assertion_phase1_behavior.sql
test-framework/sql/tests/concurrency/100_authentication_assertion_single_use.sh
```

Accepted evidence:

```text
31 manifest migrations
31 registered migrations
10 sequential test files
1 concurrency test file
135 PASS
0 FAIL
3 understood WARN
```

See
[Phase 1 Authentication Assertion Acceptance](phase-1-authentication-assertion-acceptance.md).

### Accepted Phase 2 Mapping

Phase 2 is governed by
[Session Establishment, Step-Up, and Lifecycle Model](session-establishment-step-up-and-lifecycle-model.md).

The planned migration ownership is:

| Migration | Phase 2 responsibility |
|---|---|
| `060_sessions.sql` | Session and session-event structure, state constraints, chronology, and indexes |
| `070_postgresql_authentication_assertion_gate.sql` | Accepted Phase 1 assertion verification and single-use consumption boundary; unchanged unless revalidation is required |
| `072_postgresql_session_control.sql` | Assertion linkage, current local trust revalidation, atomic session establishment and step-up completion, controlled activity and lifecycle APIs, and same-transaction session events |
| `075_controlled_authorization_api.sql` | Later controlled authorization boundary; not the owner of session lifecycle |

Migration `072` was added by Phase 2 Step 2 after `070` and before `075`.
Step 2 is accepted for assertion linkage, current local trust revalidation,
atomic session establishment, and atomic step-up completion.

Step 3 added controlled activity and lifecycle APIs and passed the normal
clean-install and accepted regression path with 147 passes, zero failures, and
three understood warnings.

Step 4 added and validated the complete sequential lifecycle behavior test:

```text
test-framework/sql/tests/foundation/120_session_lifecycle_behavior.sql
```

The authoritative sequential manifest contains 12 test files. The accepted
Step 4 run completed with 188 passes, zero failures, and three understood
warnings.

Step 5 adds three multi-connection session concurrency proofs while retaining
the accepted Phase 1 assertion-consumption race:

```text
test-framework/sql/tests/concurrency/100_authentication_assertion_single_use.sh
test-framework/sql/tests/concurrency/110_session_establishment_single_use.sh
test-framework/sql/tests/concurrency/120_session_step_up_single_use.sh
test-framework/sql/tests/concurrency/130_session_terminal_transition_race.sh
```

The authoritative concurrency manifest contains four tests. The accepted
Step 5 run completed with 213 passes, zero failures, and three understood
warnings.

Phase 2 acceptance is recorded in:

```text
docs/architecture/foundation/phase-2-session-establishment-step-up-and-lifecycle-acceptance.md
```

The exact accepted repository tree is identified by annotated tag
`phase-2-session-control-complete-v1`. A later change to migrations `060`, `070`, or `072`; the
session tables; controlled assertion or session functions; either test
manifest; the sequential tests; the concurrency tests; or the runner requires
fresh Phase 2 revalidation.

### Active Phase 3 Mapping

Phase 3 is governed by
[Authorization Decision and Lease Issuance Model](authorization-decision-and-lease-issuance-model.md).

Phase 3 preserves the accepted Phase 1 and Phase 2 migrations and adds:

```text
sql/schema/migrations/foundation/
081_postgresql_authorization_decision_and_lease_issuance.sql
```

Step 2 places migration `081` after `080_decision_record_repository.sql` and
before `082_data_classification_and_governance.sql`.

| Migration | Phase 3 responsibility |
|---|---|
| `055_authority_purpose_and_authorization_policy.sql` | Existing authority, purpose, operation, and policy-version structures; unchanged unless a separately revalidated structural defect is found |
| `060_sessions.sql` | Accepted session structure and context; unchanged |
| `065_authorization_leases.sql` | Existing lease and lease-to-authority structures; retained as the structural base |
| `070_postgresql_authentication_assertion_gate.sql` | Accepted Phase 1 assertion boundary; unchanged |
| `072_postgresql_session_control.sql` | Accepted Phase 2 session boundary; unchanged |
| `075_controlled_authorization_api.sql` | Existing lease hashing, baseline verification, and revocation API |
| `080_decision_record_repository.sql` | Existing Decision Record, evaluation, and supporting-record structures |
| `081_postgresql_authorization_decision_and_lease_issuance.sql` | Step 2 typed structure plus Step 3 deterministic policy resolution, controlled policy binding, stage closure, supporting-evidence enforcement, finalization-once behavior, and caller-result rejection; Step 4 adds lease behavior |

Migration `081` is part of the Foundation manifest during Step 2.

The Step 2 structural regression test is:

```text
test-framework/sql/tests/foundation/
130_authorization_decision_and_lease_structure.sql
```

The Step 2 clean-install and regression target is:

```text
33 manifest migrations
33 registered migrations
13 sequential test files
4 concurrency test files
273 PASS
0 FAIL
3 understood WARN
```

Phase 3 implementation sequence:

1. Step 1 — normative contract and migration ownership freeze,
2. Step 2 — migration `081` structure and manifest integration,
3. Step 3 — controlled decision finalization,
4. Step 4 — controlled lease issuance and verification,
5. Step 5 — complete sequential behavior tests,
6. Step 6 — independent-connection concurrency proofs,
7. Step 7 — formal acceptance record and annotated release tag.

Step 1 froze the architecture contract. Step 2 adds migration `081`, one
structural SQL test, and manifest integration while preserving all accepted
Phase 1 and Phase 2 migrations, tests, and concurrency proofs.

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
- [Authentication Assertion Verification and Consumption Model](authentication-assertion-verification-and-consumption-model.md)
- [Phase 1 Authentication Assertion Acceptance](phase-1-authentication-assertion-acceptance.md)
- [Phase 2 Session Establishment, Step-Up, and Lifecycle Acceptance](phase-2-session-establishment-step-up-and-lifecycle-acceptance.md)
- [Session Establishment, Step-Up, and Lifecycle Model](session-establishment-step-up-and-lifecycle-model.md)
- [Authorization Decision and Lease Issuance Model](authorization-decision-and-lease-issuance-model.md)

### Phase 3 Step 3 Result Target

```text
33 manifest migrations
33 registered migrations
14 sequential test files
4 concurrency test files
297 PASS
0 FAIL
3 understood WARN
```

Step 3 behavior is tested by
`140_authorization_policy_selection_and_decision_finalization.sql`.
Authorization Lease issuance remains Step 4.

### Phase 3 Step 4 Result Target

Migration `081` now includes controlled lease issuance and use behavior in
addition to the accepted Step 2 structure and Step 3 finalization routines.

```text
33 manifest migrations
33 registered migrations
15 sequential test files
4 concurrency test files
329 PASS
0 FAIL
3 understood WARN
```

The Step 4 behavioral test is:

```text
test-framework/sql/tests/foundation/
150_authorization_lease_issuance_and_use.sql
```

The phase gate is:

```text
tools/validation/phase-gates/validate_phase3_step4.sh
```
