# Phase 5 Step 5 — Review and Validation Roles

> **Document status:** Phase 5 Step 5 implementation contract and validation record.
>
> **Phase status:** Candidate until the complete disposable-cluster gate passes.
>
> **Accepted predecessor:** Phase 5 Step 4 least-privileged runtime grants.

## 1. Purpose

Phase 5 Step 5 implements separate PostgreSQL review capabilities for:

- reduced-disclosure investigation;
- append-oriented audit review;
- Foundation and deployment posture validation.

The implementation uses the existing canonical `NOLOGIN` roles:

```text
issp_read_only_investigator
issp_audit_reader
issp_validation_reader
```

These roles are capability boundaries. They are not user identities, do not
contain credentials, and have no standing membership path in this step.

## 2. Exact Privilege Contract

Migration `930_investigator_audit_and_validation_review_surfaces.sql` records a
**40-row review privilege contract** in
`deployment_meta.review_privilege_contract`:

| Role | CONNECT | Schema USAGE | View SELECT | Total |
| --- | ---: | ---: | ---: | ---: |
| `issp_read_only_investigator` | 1 | 1 | 2 | 4 |
| `issp_audit_reader` | 1 | 1 | 8 | 10 |
| `issp_validation_reader` | 1 | 2 | 23 | 26 |
| **Total** | **3** | **4** | **33** | **40** |

Absence from the contract means the privilege is not approved.

## 3. Investigator Boundary

The investigator role receives **2 reduced-disclosure investigator views**:

```text
security_review.investigator_decision_summary
security_review.investigator_approval_summary
```

These surfaces omit direct actor identifiers, device and session identifiers,
raw protected-target references, raw Decision Record context, and record-hash
material. The purpose is bounded operational review without silently turning a
read-only investigator into a universal data reader.

The role does not receive audit-only lineage views or Foundation validation
views.

## 4. Audit Boundary

The audit role receives **8 audit-lineage views**:

```text
security_review.audit_decision_records
security_review.audit_decision_evaluations
security_review.audit_approval_requests
security_review.audit_approval_actions
security_review.audit_approval_stage_evaluations
security_review.audit_session_events
security_review.audit_authorization_lease_events
security_review.audit_lifecycle_events
```

The views expose attributable identifiers, statuses, reason codes, chronology,
and approved lineage needed for independent review. They deliberately exclude:

- Authorization Lease secret hashes;
- Decision Record `context_snapshot` values;
- evaluation `supporting_context` values;
- session-event `details` JSON;
- authentication signature values, nonce hashes, and payload bytes.

Audit review authority remains separate from operational authority.

## 5. Validation Boundary

The validation role receives **23 validation-posture views**:

- all 19 accepted `security_validation` views created by Foundation migration
  `099`;
- four deployment-posture views:

```text
deployment_meta.deployment_migration_status
deployment_meta.canonical_role_posture
deployment_meta.canonical_membership_posture
deployment_meta.review_privilege_contract_summary
```

The deployment views expose migration checksums, non-secret canonical role
attributes, membership options, and exact privilege-contract summaries. They do
not expose password hashes or protected business rows.

## 6. View Execution Boundary

Every Step 5-created view uses `security_barrier` and is owned by the approved
non-login owner for its layer:

- `security_review` views are owned by `issp_foundation_owner`;
- `deployment_meta` posture views are owned by `issp_database_owner`.

`PUBLIC` receives no access. The review roles receive only exact `SELECT`
grants on the approved views.

## 7. Explicit Denials

No review role receives direct protected base-table access, including read-only
access. No review role receives:

- table `INSERT`, `UPDATE`, `DELETE`, or `TRUNCATE`;
- sequence access;
- protected routine `EXECUTE`;
- schema `CREATE`;
- database `TEMPORARY`;
- object ownership;
- role membership;
- `LOGIN`, `SUPERUSER`, `CREATEDB`, `CREATEROLE`, `REPLICATION`, or
  `BYPASSRLS`.

Service login roles receive no review-role membership and no direct review-view
grants.

## 8. Classification and Purpose Boundary

The investigator views are intentionally reduced because a PostgreSQL role by
itself does not prove case assignment, purpose, classification eligibility, or
organization scope. Future environment-specific login assignment must remain
separately governed and attributable.

The audit views expose broader lineage for independent review, but that access
still requires an approved audit identity and purpose outside repository SQL.

## 9. Validation Requirements

The disposable-cluster test must prove:

- all 34 accepted Foundation migrations still apply;
- deployment migrations `900`, `910`, `920`, and `930` apply in order;
- exact deployment reapplication is idempotent;
- the contract contains exactly 40 rows;
- all 33 approved view grants work;
- investigator, audit, and validation roles remain mutually separated;
- protected base-table reads and all mutations are denied;
- temporary-table creation is denied;
- protected routine execution is denied;
- runtime service identities cannot read review views;
- `PUBLIC` cannot read Step 5 views;
- the Phase 4 SQL tree remains frozen.

Tests that create canonical cluster roles run only in a disposable PostgreSQL
cluster.

## 10. Deferred Work

Phase 5 Step 5 does not:

- provision investigator, auditor, or validator login credentials;
- assign human identities to capability roles;
- implement legal-evidence access or chain of custody;
- activate break-glass;
- implement off-host protected review records;
- replace application-level classification and purpose enforcement.

**Phase 5 Step 6** implements disabled-at-rest break-glass activation,
attributable activation evidence, automatic expiration, deactivation, and
credential lifecycle controls.
