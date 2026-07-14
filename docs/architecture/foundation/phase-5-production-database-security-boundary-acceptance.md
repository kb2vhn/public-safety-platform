# Phase 5 Production Database Security Boundary Acceptance

> **Layer:** Platform Foundation  
> **Phase:** 5 — Production Database Security Boundary  
> **Acceptance date:** 2026-07-14  
> **Status:** Accepted for the Phase 5 scope defined below  
> **Authoritative contract:** [Production Database Role, Ownership, and Runtime Privilege Model](production-database-role-ownership-and-runtime-privilege-model.md)  
> **Accepted release tag:** `phase-5-production-database-security-boundary-complete-v1`  
> **Accepted implementation commit:** `9f8dbf9d909ef157df72b12511b165a689559093`

## 1. Acceptance Decision

Phase 5 is accepted. This record defines the Accepted Phase 5 production database security boundary.

This decision means the PostgreSQL production role topology, protected-object ownership, creator-specific default privileges, least-privileged runtime access, governed review surfaces, disabled-at-rest break-glass lifecycle, credential-rotation controls, hostile-input rejection, and independent-connection role-race behavior satisfied the Phase 5 acceptance criteria on 2026-07-14.

It does not declare the complete Iron Signal Platform, production Go services, deployment hosts, external identity provider, backup system, off-host evidence collector, operational modules, user interfaces, or production operating organization ready for production use.

## 2. Authoritative Accepted Tree

The annotated Git tag is the durable identifier for the exact accepted implementation tree:

```text
phase-5-production-database-security-boundary-complete-v1
```

The tag dereferences to:

```text
9f8dbf9d909ef157df72b12511b165a689559093
```

The tag target is authoritative. This acceptance record is an administrative documentation commit created after the tag target. It must descend from the tag and must not alter the accepted deployment SQL, deployment runner, executable deployment tests, or Phase 5 implementation gates.

## 3. Accepted Deployment Boundary

The accepted deployment manifest contains exactly five migrations:

```text
900_postgresql_role_topology_and_membership.sql
910_database_schema_and_object_ownership.sql
920_least_privileged_runtime_grants_and_controlled_service_apis.sql
930_investigator_audit_and_validation_review_surfaces.sql
940_break_glass_and_credential_lifecycle.sql
```

No migration `950` is part of Phase 5.

The accepted implementation boundary includes:

- the exact deployment manifest and checksum-enforced deployment registry;
- the deployment runner and its authority preflight;
- 18 canonical PostgreSQL role shells;
- non-login database, Foundation, and extension ownership roles;
- bounded service-to-capability memberships;
- ownership transfer away from the bootstrap login;
- creator-specific default privileges;
- revocation of unapproved `PUBLIC` access;
- one inherited database `CONNECT` capability;
- eight exact runtime schema `USAGE` grants;
- 31 controlled runtime routine `EXECUTE` grants;
- zero direct protected relation or sequence grants to runtime services;
- two reduced-disclosure investigator views;
- eight audit-lineage views;
- 23 validation-posture views;
- exact view-only review-role privilege contracts;
- disabled-at-rest `issp_break_glass` posture;
- independent requester, two-approver, and activation-operator separation;
- activation windows from 5 minutes through 1 hour;
- a one-connection emergency boundary;
- temporary non-inheriting, `SET`-capable, non-admin owner memberships;
- forced session termination, membership revocation, `CONNECT` revocation, password clearing, and return to `NOLOGIN`;
- append-only emergency and credential-lifecycle evidence;
- mandatory off-host-export posture records;
- SCRAM verifier iteration-floor enforcement;
- cryptographic binding of the activated verifier to the independently approved fingerprint;
- prevention of activated credential-fingerprint reuse;
- deterministic hostile-condition and independent-connection role-race behavior.

## 4. Frozen Implementation Paths

The following implementation paths are frozen by this acceptance:

```text
sql/deployment/
test-framework/sql/deployment/
tools/validation/validate_foundation_database_parity.sh
tools/validation/phase-gates/validate_phase5_step1.sh
tools/validation/phase-gates/validate_phase5_step2.sh
tools/validation/phase-gates/validate_phase5_step3.sh
tools/validation/phase-gates/validate_phase5_step4.sh
tools/validation/phase-gates/validate_phase5_step5.sh
tools/validation/phase-gates/validate_phase5_step6.sh
tools/validation/phase-gates/validate_phase5_step7.sh
```

A later phase may add a separately governed deployment boundary, but it must not silently rewrite the accepted Phase 5 tree. Any required correction to a frozen path requires explicit reopening, documented impact analysis, complete Phase 5 revalidation, and a new acceptance tag.

## 5. Accepted Test and Gate Results

The accepted Foundation regression remained:

```text
34 manifest migrations
34 registered migrations
21 sequential test files
16 concurrency test files
734 PASS
0 FAIL
3 understood WARN
Correctness result: PASS
Resource observation: RECORDED
Performance thresholds: NOT_EVALUATED
```

The final Phase 5 hostile-condition and role-race execution completed with:

```text
PASS checks: 82
FAIL checks: 0
```

The complete Phase 5 Step 7 implementation gate completed with:

```text
PASS checks: 97
FAIL checks: 0
```

That result records 97 phase-gate PASS checks and 0 phase-gate FAIL checks and includes complete predecessor revalidation through the formally accepted Phase 4 Foundation boundary.

## 6. Adversarial and Concurrency Evidence

The accepted hostile-condition and independent-connection tests prove that:

- repeated requester or approver identities fail closed;
- invalid activation windows fail closed;
- weak, malformed, mismatched, or reused credential material fails closed;
- non-authorized roles cannot prepare, activate, record use, deactivate, or enforce expiration;
- concurrent preparation produces one valid prepared request;
- concurrent activation produces one valid active request;
- deactivation terminates an active emergency session;
- use recording versus deactivation leaves a valid attributable serial result;
- expiration versus deactivation writes exactly one closure event;
- no race leaves standing memberships, database `CONNECT`, a reusable password, an active session, or a partially enabled emergency role;
- every emergency event has exactly one corresponding off-host-export evidence record;
- emergency evidence remains append-only;
- runtime and review roles cannot cross their accepted privilege boundaries;
- `PUBLIC` cannot execute emergency-control routines.

## 7. Acceptance-Gate Requirements

Formal acceptance requires all of the following:

| Requirement | Result |
|---|---|
| Annotated Phase 5 tag identifies the exact accepted implementation commit | PASS |
| Current `dev` descends from the accepted tag | PASS |
| Frozen Phase 4 implementation tree remains unchanged | PASS |
| Frozen Phase 5 deployment and executable validation tree matches the tag | PASS |
| Deployment manifest contains exactly migrations 900 through 940 | PASS |
| No migration 950 exists | PASS |
| Step 7 focused hostile-condition and role-race test passes | PASS |
| Complete Step 7 gate passes | PASS |
| Foundation regression remains 734 PASS, 0 FAIL, 3 WARN | PASS |
| Resource observation remains recorded and observation-only | PASS |
| Acceptance documentation names the tag and implementation commit | PASS |
| No production credential or secret is stored in the repository | PASS |

## 8. Known Boundaries and Warnings

Phase 5 preserves the three understood Phase 4 warnings:

1. Foundation migration registry rows do not yet store enforced checksums.
2. Some Foundation-defined types retain direct `PUBLIC USAGE`, while containing-schema denial prevents reachability.
3. The Foundation applied-migration registry lacks an owner-resistant mutation trigger.

The Phase 5 deployment registry itself records SHA-256 checksums and rejects checksum drift. The remaining Foundation warnings require separately governed hardening and may not be silently changed inside the frozen Phase 4 or Phase 5 trees.

## 9. Explicit Non-Claims

Phase 5 acceptance does not prove or provide:

- production credentials or service account provisioning;
- production `pg_hba.conf`, TLS, certificate, or external identity-provider configuration;
- production application of the deployment manifest to a shared database;
- host compromise containment;
- operating-system package integrity or trusted rebuild automation;
- backup confidentiality, immutability, or restore validation;
- a deployed off-host evidence collector or external integrity anchor;
- secrets-manager availability or credential-delivery procedures;
- production monitoring, paging, or incident-command workflows;
- production Go service readiness;
- module-specific business workflows;
- multi-region database coordination;
- complete platform or CAD production readiness.

## 10. Revalidation Triggers

Phase 5 must be reopened and revalidated after any change to:

- the accepted deployment manifest;
- migrations 900, 910, 920, 930, or 940;
- the deployment runner or deployment registry;
- canonical role names, attributes, ownership, or memberships;
- runtime schema or routine allowlists;
- review-role contracts or review views;
- break-glass request, approval, activation, use, closure, or evidence semantics;
- credential fingerprint, SCRAM, expiration, or rotation policy;
- emergency-control routine ownership, search paths, or ACLs;
- the Phase 5 disposable-cluster tests;
- the Phase 5 implementation gates;
- the accepted implementation commit, annotated tag, or this acceptance record.

## 11. Final Decision

Phase 5 is formally accepted and frozen at:

```text
Tag:    phase-5-production-database-security-boundary-complete-v1
Commit: 9f8dbf9d909ef157df72b12511b165a689559093
```

Subsequent work must consume this production database security boundary as an accepted Foundation dependency rather than silently redefining it.
