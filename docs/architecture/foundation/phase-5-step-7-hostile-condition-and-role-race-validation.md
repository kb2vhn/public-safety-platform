# Phase 5 Step 7 — Hostile-Condition and Role-Race Validation

## Status

Phase 5 Step 7 is accepted as the final implementation and adversarial-validation step for the Phase 5 production database security boundary.

This step adds adversarial and concurrency validation for the production database security boundary through migration `940_break_glass_and_credential_lifecycle.sql` and applies one pre-freeze hardening correction: the activated SCRAM verifier must cryptographically match the independently approved credential fingerprint and must use at least 4096 iterations. It does not add a deployment migration, change the frozen Phase 4 schema tree, or grant any new authority.

## Purpose

The ordinary success path is not enough for emergency authority. Step 7 validates that the accepted controls remain deterministic when requests, activation, use recording, deactivation, and expiration are attempted concurrently or with hostile inputs.

The validation must prove that contention cannot create duplicate active authority, duplicate closure evidence, reused emergency credentials, standing memberships, or a partially disabled break-glass role.

## Accepted Deployment Prefix

Step 7 tests exactly these deployment migrations:

1. `900_postgresql_role_topology_and_membership.sql`
2. `910_database_schema_and_object_ownership.sql`
3. `920_least_privileged_runtime_grants_and_controlled_service_apis.sql`
4. `930_investigator_audit_and_validation_review_surfaces.sql`
5. `940_break_glass_and_credential_lifecycle.sql`

No migration `950` is introduced by this step; the not-yet-frozen migration `940` candidate is hardened in place and must pass the complete Step 6 predecessor gate again. Future deployment migrations must not silently change the Step 7 predecessor boundary.

## Pre-Freeze Credential-Binding Hardening

Hostile analysis identified that a syntactically valid SCRAM verifier could otherwise be activated without proving that it matched the fingerprint approved with the request. Before Phase 5 is frozen, migration `940` is corrected to hash the supplied verifier with SHA-256, compare it with the request fingerprint, and reject SCRAM iteration counts below 4096. The Step 6 focused test is synchronized to derive request fingerprints from its ephemeral verifiers. No stored or shared deployment has received migration `940`, so the candidate migration can be corrected before formal acceptance.

## Hostile-Condition Coverage

The disposable-cluster test verifies rejection of:

- non-superuser preparation, activation, use recording, deactivation, and expiration enforcement;
- repeated requester or approver identities;
- activation windows shorter than 5 minutes or longer than 1 hour;
- malformed credential fingerprints, non-SCRAM activation material, weak iteration counts, and verifiers that do not match the approved fingerprint;
- an activation operator who is also the requester or an approver;
- direct protected-table writes by runtime or review roles;
- direct role mutation or membership administration by the migration executor;
- repeated activation, repeated deactivation, and reuse of a fingerprint that reached `ACTIVATED`;
- evidence mutation through ordinary SQL paths;
- emergency-control execution by `PUBLIC`, runtime roles, service roles, and review roles.

## Role-Race Coverage

The test starts competing PostgreSQL sessions against the same isolated database and verifies stable outcomes for:

### Concurrent preparation

Two independently formed requests are released at the same time. Exactly one may reach `REQUESTED`; the other must observe the serialized lifecycle state and fail. The winning request must have one request event and one matching off-host evidence record.

### Concurrent activation

Two activation operators compete for the same request. Exactly one activation may succeed. The role must receive one temporary credential state, one set of three non-inheriting owner memberships, one database `CONNECT` grant, and one `ACTIVATED` event.

### Session termination during deactivation

A live password-authenticated break-glass session is held open while controlled deactivation runs. The session must be terminated, temporary authority must be revoked, and the role must return to `NOLOGIN` with no verifier.

### Use recording versus deactivation

Use recording and closure are released concurrently. Serialization may permit the use record immediately before closure or reject it after closure, but deactivation must succeed exactly once and the final posture must always be disabled.

### Expiration versus deactivation

Forced expiration and operator deactivation compete for the same active request. Exactly one closure event may be written. The other operation may observe the already-closed state or return zero expired requests, but it may not create a second closure or leave active authority behind.

## Evidence Invariants

After every hostile and race scenario:

- each break-glass event has exactly one off-host evidence record;
- evidence identifiers remain unique;
- request, activation, use, closure, and credential lifecycle records remain attributable;
- no plaintext password or SCRAM verifier is stored in evidence tables;
- review roles remain limited to their approved security-barrier views;
- runtime and service roles remain unable to read emergency evidence or execute emergency controls.

## PostgreSQL Owner and Superuser Boundary

Step 7 does not claim that in-database controls can defeat a hostile PostgreSQL superuser or an actor currently exercising a database-owner role. Those authorities can alter database objects by design. The accepted control is therefore layered:

- emergency owner authority is short-lived and attributable;
- use and closure are recorded;
- evidence is marked `off_host_export_required`;
- production operations must export evidence promptly to a separately administered destination;
- host, backup, logging, and trusted-rebuild controls must protect evidence outside the database authority boundary.

## Isolation and Safety

The test initializes a Unix-socket-only disposable PostgreSQL cluster under a temporary directory. It does not use the shared development cluster, does not apply deployment migrations to `dev_testing`, does not retain generated passwords or SCRAM verifiers, and destroys the cluster at completion.

## Acceptance Rule

Step 7 is accepted only when:

- the focused hostile-condition and role-race test reports zero failures;
- the complete Step 6 predecessor gate still passes;
- the frozen Phase 4 SQL and executable Foundation test tree remains unchanged;
- the deployment manifest still has the exact accepted five-migration prefix;
- no new database authority or deployment migration was introduced;
- the complete Step 7 gate reports zero failures.

After acceptance, Phase 5 Step 8 may perform formal production-database security-boundary acceptance, freeze the accepted deployment and validation boundary, and record the release tag and evidence.

## Formal Acceptance

Phase 5 Step 7 completed with 82 PASS and 0 FAIL in the focused hostile-condition and role-race test and 97 PASS and 0 FAIL in the complete implementation gate. Phase 5 Step 8 formally accepts the resulting tree at `phase-5-production-database-security-boundary-complete-v1` targeting `9f8dbf9d909ef157df72b12511b165a689559093`.
