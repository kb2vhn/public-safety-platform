# Phase 5 Step 3 — Ownership and Creator-Specific Default Privileges

> **Status:** Candidate implementation.
>
> **Predecessor:** Phase 5 Step 2 deployment manifest and PostgreSQL role
> topology.
>
> **Scope:** Production database ownership, protected schema and object
> ownership, existing PUBLIC privilege removal, and creator-specific default
> privileges.

## 1. Purpose

Move protected PostgreSQL ownership away from the login-capable bootstrap
identity and into the non-login owner roles frozen by Phase 5 Step 1 and
created by Phase 5 Step 2.

Step 3 establishes who owns the database and protected objects. It does not
grant production service identities permission to use those objects. Runtime
`CONNECT`, `USAGE`, `SELECT`, `EXECUTE`, and controlled writer grants remain
Phase 5 Step 4 work.

## 2. Ownership Assignment

The ownership boundary is:

| Scope | Owner |
|---|---|
| Current Iron Signal Platform database | `issp_database_owner` |
| `deployment_meta` schema and objects | `issp_database_owner` |
| Platform Foundation schemas and objects | `issp_foundation_owner` |
| `extensions` schema and extension member objects | `issp_extension_owner` |

The protected Foundation schema set is:

```text
foundation_meta
trust
identity
organization
service
attestation
approval
access_control
decision
governance
compliance
risk
resilience
performance
observability
integration
security_validation
```

Tables, partitioned tables, views, materialized views, sequences, foreign
tables, routines, domains, and standalone user-defined types in those schemas
move to the approved non-login owner for the scope.

## 3. Login-Owner Prohibition

After Step 3, no login-capable canonical role may own:

- the active Iron Signal Platform database;
- a protected Foundation schema;
- a protected Foundation relation;
- a protected Foundation routine;
- a protected standalone type;
- the `extensions` schema or its member objects;
- the `deployment_meta` schema or its objects.

Service logins, the migration executor, runtime capabilities, writer
capabilities, review roles, and break-glass remain non-owners.

## 4. Existing PUBLIC Access

Step 3 removes `PUBLIC` access from:

- the active database;
- protected schemas;
- protected tables and views;
- protected sequences;
- protected routines.

Revoking database `CONNECT` and `TEMPORARY` from `PUBLIC` intentionally leaves
the canonical service login roles unable to connect until Phase 5 Step 4 grants
the minimum approved runtime access.

## 5. Creator-Specific Default Privileges

Default privileges are established for:

```text
issp_database_owner
issp_foundation_owner
issp_extension_owner
issp_migration_executor
```

For objects created by those roles, implicit `PUBLIC` access is removed for:

- schemas;
- tables and views;
- sequences;
- routines;
- types and domains;
- large objects.

These defaults apply to the role that is the current creator at object
creation time. They are not inherited merely because a login is a member of
another role. Future deployment procedures must therefore create objects while
acting as the intended owner role.

## 6. PostgreSQL Extension Catalog-Owner Limitation

PostgreSQL 18 has no supported `ALTER EXTENSION ... OWNER TO` form.

Migration `000_platform_initialization.sql` created `pgcrypto` before the Phase
5 role topology existed. Step 3 therefore:

1. transfers ownership of the `extensions` schema to
   `issp_extension_owner`;
2. transfers the extension member objects in that schema to
   `issp_extension_owner`;
3. leaves the `pg_extension.extowner` catalog record with the controlled
   bootstrap identity;
4. records the limitation in
   `deployment_meta.ownership_exceptions`;
5. requires review before production acceptance.

Direct catalog modification is prohibited. It would require coordinated
changes to PostgreSQL shared-dependency metadata and is not an acceptable
deployment mechanism.

A future clean production bootstrap may create approved extensions while
already acting as the intended extension owner. Step 3 does not rewrite the
accepted Foundation migration history to achieve that outcome retroactively.

## 7. Migration

Step 3 adds:

```text
sql/deployment/migrations/910_database_schema_and_object_ownership.sql
```

The deployment manifest becomes:

```text
migrations/900_postgresql_role_topology_and_membership.sql
migrations/910_database_schema_and_object_ownership.sql
```

Migration `910` requires:

- PostgreSQL 18 or newer;
- a superuser-controlled deployment session;
- all 34 accepted Foundation migrations;
- registered deployment migration `900`;
- all 18 canonical Step 2 roles;
- owner roles that remain `NOLOGIN`.

## 8. Disposable-Cluster Testing

The Step 3 test creates an isolated Unix-socket-only PostgreSQL cluster and:

- applies all 34 Foundation migrations;
- applies deployment migrations `900` and `910`;
- reapplies the deployment manifest to prove exact idempotence;
- verifies the database owner;
- verifies all protected schema owners;
- verifies relation, routine, and standalone-type owners;
- proves that no login-capable role owns protected objects;
- verifies the `pgcrypto` extension-owner limitation record;
- creates probe objects as each approved owner;
- proves creator-specific defaults deny `PUBLIC`;
- proves runtime and service roles receive no object privileges;
- destroys the temporary cluster.

The shared development PostgreSQL cluster is not modified.

## 9. Explicit Non-Claims

Step 3 does not:

- provision passwords or certificates;
- grant service roles database `CONNECT`;
- grant runtime schema `USAGE`;
- grant controlled routine `EXECUTE`;
- grant approved view `SELECT`;
- grant direct table writes;
- implement investigator, audit, or validation read surfaces;
- activate break-glass;
- resolve the PostgreSQL extension catalog-owner limitation;
- make the platform production-ready.

## 10. Acceptance Criteria

Step 3 is accepted only when:

- the Phase 4 `sql/schema` tree remains unchanged;
- the accepted 34-migration, 734-PASS Foundation regression still passes;
- deployment migrations `900` and `910` register with exact checksums;
- the database is owned by `issp_database_owner`;
- protected Foundation objects are owned by `issp_foundation_owner`;
- extension schema/member objects are owned by `issp_extension_owner`;
- deployment metadata is owned by `issp_database_owner`;
- no login-capable role owns protected objects;
- `PUBLIC` lacks database and protected-object access;
- creator-specific default privileges are proven with newly created objects;
- the extension catalog-owner limitation is recorded and remains reviewable;
- the disposable-cluster Step 3 test passes.

## 11. Next Step

Phase 5 Step 4 grants only the minimum approved database `CONNECT`, schema
`USAGE`, controlled routine `EXECUTE`, approved view `SELECT`, and narrow
repository privileges needed by each production service identity.
