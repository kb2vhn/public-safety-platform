# Phase 5 Step 2 — Deployment Manifest and PostgreSQL Role Topology

> **Status:** Accepted implementation.
>
> **Predecessor:** Phase 5 Step 1 production database role, ownership, and
> runtime-privilege contract.
>
> **Scope:** PostgreSQL cluster-role shells, bounded capability memberships,
> deployment migration metadata, and disposable-cluster validation.

## 1. Purpose

Implement the first production database security boundary without transferring
object ownership or granting access to protected Foundation objects.

Step 2 makes the PostgreSQL role topology concrete while preserving the
accepted Phase 4 SQL and executable test tree.

## 2. Deployment Manifest

The authoritative deployment order is:

```text
sql/deployment/manifests/deployment.manifest
```

The first deployment migration is:

```text
migrations/900_postgresql_role_topology_and_membership.sql
```

Deployment migrations are separate from the accepted Foundation
`000–099` history. They use the reserved `900–999` range and have an exact
SHA-256 registry in `deployment_meta.applied_deployment_migrations`.

## 3. Canonical Role Inventory

Step 2 creates 18 canonical PostgreSQL roles.

### Ownership Anchors

```text
issp_database_owner
issp_foundation_owner
issp_extension_owner
```

These roles are `NOLOGIN` and receive no standing members.

### Controlled Migration Identity

```text
issp_migration_executor
```

This role can log in but has no repository-provisioned password, no owner-role
membership, and a connection limit of two.

### Common Runtime Capability

```text
issp_runtime
```

This is a `NOLOGIN` capability role. Step 2 grants it no object privileges.

### Controlled Writer Capabilities

```text
issp_writer_authentication_assertion
issp_writer_session_control
issp_writer_authorization_decision
issp_writer_approval
issp_writer_integration_delivery
issp_writer_monitoring_delivery
```

These are `NOLOGIN` capability roles. Object-level `EXECUTE`, `SELECT`, or
narrow repository privileges are deferred to Phase 5 Step 4.

### Review Capability Shells

```text
issp_read_only_investigator
issp_audit_reader
issp_validation_reader
```

These roles are created as `NOLOGIN` shells. Their approved read surfaces are
deferred to Phase 5 Step 5.

### Break-Glass Shell

```text
issp_break_glass
```

The role remains `NOLOGIN`, has no members, and receives no privileges. Its
activation, evidence, expiration, deactivation, and credential lifecycle are
deferred to Phase 5 Step 6.

### Bounded Service Logins

```text
issp_service_authorization
issp_service_integration_delivery
issp_service_monitoring_delivery
```

Each service identity is independent, has no repository-provisioned password,
and receives only capability memberships relevant to its service boundary.

## 4. Membership Semantics

Every Step 2 service-to-capability membership is created with:

```text
INHERIT TRUE
SET FALSE
ADMIN FALSE
```

This provides capability inheritance while preventing a service identity from
becoming the capability role or administering membership in that role.

The authorization service receives:

- `issp_runtime`;
- `issp_writer_authentication_assertion`;
- `issp_writer_session_control`;
- `issp_writer_authorization_decision`;
- `issp_writer_approval`.

The integration-delivery service receives:

- `issp_runtime`;
- `issp_writer_integration_delivery`.

The monitoring-delivery service receives:

- `issp_runtime`;
- `issp_writer_monitoring_delivery`.

No membership is created for owner roles, the migration executor, review
roles, or break-glass.

## 5. PostgreSQL Attributes

Every canonical role is explicitly denied:

```text
SUPERUSER
CREATEDB
CREATEROLE
REPLICATION
BYPASSRLS
```

The three service logins and migration executor are created with `NOINHERIT` at
the role level. Membership inheritance is enabled only on the exact approved
capability grants.

## 6. Credential State

Step 2 creates login roles with `PASSWORD NULL`.

Repository SQL does not provision passwords, certificates, tokens, private
keys, or any other environment secret. Credential provisioning remains a
separate deployment process.

## 7. Ownership and Privilege Non-Claims

Step 2 does not:

- transfer database ownership;
- transfer schema ownership;
- transfer extension ownership;
- transfer relation or routine ownership;
- establish owner-role membership for the migration executor;
- grant table, sequence, schema, or routine privileges to runtime roles;
- create production credentials;
- activate break-glass.

Those boundaries are implemented in later Phase 5 steps.

## 8. Disposable-Cluster Testing

PostgreSQL roles are cluster-global. A disposable database inside the shared
development cluster is not sufficient isolation.

Step 2 therefore adds:

```text
test-framework/sql/deployment/scripts/test_phase5_step2_role_topology.sh
```

The test creates a temporary PostgreSQL cluster with Unix-socket-only access,
applies all 34 Foundation migrations, applies the deployment manifest twice,
proves exact idempotence, validates role attributes and memberships, checks
expected denial behavior, then destroys the cluster.

The test does not create canonical Step 2 roles in the user's shared Arch
PostgreSQL cluster.

## 9. Application Boundary

The deployment manifest runner is:

```text
sql/deployment/scripts/apply_deployment.sh
```

It requires:

- PostgreSQL 18 or newer;
- a target database with all 34 accepted Foundation migrations;
- a PostgreSQL superuser for the initial role-topology bootstrap;
- exact deployment migration checksums;
- the canonical deployment manifest.

Ordinary application and runtime identities cannot run deployment migrations.

## 10. Step 2 Acceptance Criteria

Step 2 is accepted only when:

- Phase 5 Step 1 revalidates completely;
- the deployment manifest contains exactly migration 900;
- migration 900 creates all 18 canonical role shells;
- all login roles have null passwords at Step 2;
- nine service-to-capability memberships use `INHERIT TRUE`, `SET FALSE`, and
  `ADMIN FALSE`;
- owner, migration, review, and break-glass roles have no standing membership;
- no canonical role receives a prohibited PostgreSQL attribute;
- no object ownership or object privilege transfer occurs;
- the disposable-cluster role test passes;
- the accepted 34-migration, 734 PASS Foundation regression remains unchanged.

## 11. Next Step

Phase 5 Step 3 transfers database, schema, extension, relation, and routine
ownership to the approved non-login owners and establishes creator-specific
default privileges.
