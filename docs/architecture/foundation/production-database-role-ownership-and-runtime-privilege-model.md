# Production Database Role, Ownership, and Runtime Privilege Model

> **Document status:** Normative Platform Foundation and deployment architecture.
>
> **Phase status:** Phase 5 Step 1 contract freeze.
>
> **Implementation status:** Contract only. Phase 5 Step 1 does not create
> PostgreSQL cluster roles, transfer object ownership, or grant production
> runtime privileges.
>
> **Accepted predecessor:** Phase 4 approval independence and separation of
> duties at
> `phase-4-approval-independence-and-separation-of-duties-complete-v1`.

## 1. Purpose

Define the production PostgreSQL identity, ownership, migration, runtime,
investigation, validation, audit, and break-glass boundaries required before
the Iron Signal Platform can expose its controlled database APIs to production
Go services.

PostgreSQL remains an independent security boundary. Application compromise
must not automatically become unrestricted ownership, unrestricted table
access, approval authority, audit-rewrite authority, or migration authority.

## 2. Scope

This model governs:

- PostgreSQL cluster roles used by the Iron Signal Platform;
- database and schema ownership;
- extension ownership;
- migration execution;
- runtime service identities;
- controlled writer capabilities;
- investigation and audit access;
- validation access;
- default privileges;
- role membership;
- `SET ROLE` boundaries;
- credential and secret separation;
- emergency database access;
- deployment validation and rollback expectations.

This model does not define:

- operating-system administrator controls;
- PostgreSQL superuser governance in full;
- host hardening;
- backup encryption;
- off-host logging transport;
- production Go service implementation;
- module-owned business permissions;
- organization-level operational authority;
- user-facing application roles.

Those controls remain required, but they are governed in later Phase 5 steps
or later deployment-security work.

## 3. Non-Negotiable Boundary

No production login role may own protected Platform Foundation schemas,
tables, sequences, views, types, or security-sensitive routines.

No ordinary runtime identity may:

- own protected objects;
- create or alter protected schemas;
- grant itself additional privileges;
- become a migration identity;
- become an ownership role;
- bypass row-level security;
- create roles;
- create databases;
- initiate replication;
- execute unapproved routines;
- write directly to protected base tables;
- rewrite Decision Records, Approval Action Records, session history,
  Authorization Lease history, or other append-oriented records.

Ownership, migration, runtime use, investigation, audit review, validation,
and emergency access are separate authorities.

## 4. Canonical Role Classes

Concrete deployment roles must map to one and only one primary role class.
A deployment may add narrower service-specific roles, but it must not merge
the following authorities merely for convenience.

### 4.1 Database Owner

Canonical role:

```text
issp_database_owner
```

Required properties:

- `NOLOGIN`;
- owns the Iron Signal Platform database;
- does not perform routine migrations;
- is not granted to runtime, investigator, audit, or validation logins;
- does not act as an application service identity.

The database owner is a durable ownership anchor, not an operating account.

### 4.2 Foundation Object Owner

Canonical role:

```text
issp_foundation_owner
```

Required properties:

- `NOLOGIN`;
- owns Foundation schemas and ordinary Foundation objects;
- owns security-sensitive Foundation routines unless a narrower owner is
  required;
- establishes Foundation default privileges;
- is not granted to runtime identities;
- is not used for ordinary application connections.

### 4.3 Extension Owner

Canonical role:

```text
issp_extension_owner
```

Required properties:

- `NOLOGIN`;
- owns approved extension installations where PostgreSQL permits separate
  extension ownership;
- is not a general Foundation object owner;
- is not granted to runtime services;
- cannot be used to introduce unapproved extensions.

Where PostgreSQL or an extension requires a stronger installation identity,
that exception must be explicit, temporary, and recorded.

### 4.4 Migration Executor

Canonical deployment identity:

```text
issp_migration_executor
```

Required properties:

- authenticated only through a controlled deployment path;
- not used by production runtime services;
- `NOINHERIT` unless a later accepted implementation proves another posture
  is safer;
- receives only the temporary role transitions required for an approved
  deployment;
- does not retain standing runtime authority;
- cannot silently become a break-glass identity;
- cannot modify production data outside an approved migration or repair
  procedure.

A migration executor may temporarily exercise an owner role only through an
explicit, attributable, time-bounded deployment procedure.

### 4.5 Runtime Capability Role

Canonical role:

```text
issp_runtime
```

Required properties:

- `NOLOGIN`;
- provides the minimum common connection capability for production services;
- receives no object ownership;
- receives no direct write authority over protected base tables;
- receives no `SUPERUSER`, `CREATEDB`, `CREATEROLE`, `REPLICATION`, or
  `BYPASSRLS`;
- cannot assume owner, migration, audit-rewrite, or break-glass roles.

### 4.6 Service Login Roles

Canonical naming pattern:

```text
issp_service_<service_key>
```

Required properties:

- `LOGIN`;
- one bounded identity per deployed service or independently governed worker;
- no object ownership;
- no direct membership in owner or migration roles;
- no shared credentials between unrelated services;
- receives only approved capability-role memberships;
- connection limits and timeouts are defined by deployment policy;
- credentials are managed outside source control.

A monolithic application login with universal Foundation and module access is
prohibited.

### 4.7 Controlled Writer Roles

Canonical naming pattern:

```text
issp_writer_<bounded_capability>
```

Required properties:

- `NOLOGIN`;
- grants only execution of approved controlled APIs or narrowly scoped
  repository operations;
- does not grant blanket `INSERT`, `UPDATE`, or `DELETE` over protected
  schemas;
- is assigned only to service logins that require the bounded capability;
- cannot grant itself to another role.

Controlled writer roles are capability boundaries, not broad application
roles.

### 4.8 Read-Only Investigator

Canonical role:

```text
issp_read_only_investigator
```

Required properties:

- `NOLOGIN`;
- read-only;
- no ownership;
- no mutation;
- no execution of routines that change state;
- access only to approved review views or explicitly approved relations;
- disclosure remains bounded by classification and purpose.

Direct access to sensitive base tables is not assumed merely because the role
is read-only.

### 4.9 Audit Reader

Canonical role:

```text
issp_audit_reader
```

Required properties:

- `NOLOGIN`;
- may read approved audit, Decision Record, approval, lifecycle, and security
  review surfaces;
- cannot modify or supersede reviewed records;
- cannot exercise runtime protected operations;
- cannot become a migration or owner role.

Audit review authority is not operational authority.

### 4.10 Validation Reader

Canonical role:

```text
issp_validation_reader
```

Required properties:

- `NOLOGIN`;
- may read security-validation views, catalog posture, migration state, and
  approved health surfaces;
- does not automatically receive protected business-row access;
- cannot mutate schema or data;
- cannot execute protected operations.

Validation access proves posture; it does not create authority.

### 4.11 Break-Glass Role

Canonical role:

```text
issp_break_glass
```

Required at-rest posture:

- `NOLOGIN`;
- no routine credential available to services or ordinary administrators;
- no ordinary role membership path;
- activation requires an explicit emergency procedure;
- activation, use, and deactivation must be attributable;
- credentials must be short-lived or immediately rotated;
- use must produce protected, off-host review records;
- the role must return to `NOLOGIN` after the declared event.

Break-glass access is not a substitute for correct runtime grants or migration
procedures.

## 5. Role Membership Rules

The role-membership graph must be acyclic and reviewable.

The following memberships are prohibited:

- runtime to database owner;
- runtime to Foundation owner;
- runtime to extension owner;
- runtime to migration executor;
- investigator to any writer;
- audit reader to any writer;
- validation reader to any writer;
- service login to break-glass;
- migration executor to ordinary runtime capability;
- any role membership that permits a service login to grant itself broader
  authority.

Membership administration must be performed by a separately governed
deployment authority.

## 6. Ownership Rules

### 6.1 Database Ownership

The production database is owned by `issp_database_owner`.

Ordinary runtime and migration login identities do not own the database.

### 6.2 Schema Ownership

Foundation schemas are owned by `issp_foundation_owner` unless a narrower
accepted owner is explicitly required.

Module schemas will use module-specific non-login owner roles in their
allocated migration ranges. A module owner does not become the Foundation
owner.

### 6.3 Object Ownership

Tables, sequences, types, views, and ordinary routines inherit the approved
non-login owner for their layer.

Security-sensitive routines may use a narrower non-login owner when doing so
reduces the authority available to the function owner.

### 6.4 Extension Ownership

Approved extensions are isolated from ordinary application schemas and owned
through the extension-owner boundary where supported.

Extension ownership must not be used as a path to unrestricted Foundation
object creation.

## 7. Runtime Privilege Contract

Production service logins receive:

- `CONNECT` only to approved databases;
- `USAGE` only on required schemas;
- `EXECUTE` only on approved controlled routines;
- `SELECT` only on approved views or narrowly approved relations;
- sequence access only where a controlled API genuinely requires it;
- no blanket privileges over all existing or future objects.

Protected writes must use controlled routines or a separately accepted,
narrow repository boundary.

Granting direct base-table writes to make application development easier is
not an acceptable reason.

## 8. Default Privileges

Default privileges must be established for every role that can create
deployable objects.

Default privilege posture must:

- revoke implicit access from `PUBLIC`;
- avoid granting runtime roles blanket access to future objects;
- grant future routine execution only through approved capability roles;
- preserve separation between Foundation, shared-resource, module, and
  deployment layers;
- be tested under the identity that will actually create production objects.

Default privileges configured for the wrong creator role do not protect
objects created by another owner or migration identity.

## 9. SECURITY DEFINER Contract

A security-sensitive `SECURITY DEFINER` routine must:

- be owned by an approved non-login owner;
- use schema-qualified object references;
- set a controlled `search_path` beginning with `pg_catalog`;
- exclude `public`, `pg_temp`, and `$user` from its trusted path;
- revoke execution from `PUBLIC`;
- validate caller-supplied identifiers and scope;
- expose minimal output;
- avoid unbounded dynamic SQL;
- not rely solely on caller role membership for protected authorization;
- preserve the accepted Decision Record and authorization contracts.

Changing a routine owner changes the security boundary and requires
revalidation.

## 10. Credential and Connection Separation

Production credentials must not be committed to the repository.

Each login identity requires:

- an independent credential or certificate;
- an attributable secret-management record;
- bounded rotation and revocation;
- protected transport;
- an explicit connection purpose;
- a documented owner;
- a defined disablement procedure.

Shared passwords across migration, runtime, audit, validation, and emergency
identities are prohibited.

## 11. Deployment Migration Range

Deployment and bootstrap SQL belongs in the reserved `900–999` range.

The planned implementation order is:

```text
900 PostgreSQL role topology and membership
910 database, schema, extension, and object ownership
920 default privileges and least-privileged runtime grants
930 investigator, audit, and validation access
940 break-glass posture and deployment validation
```

Exact filenames and manifest structure will be frozen before implementation.

Phase 5 deployment SQL must remain separate from the accepted
`000–099` Foundation migration history. Environment-specific secrets and
credentials must not appear in deployment migrations.

## 12. Validation Requirements

Later Phase 5 steps must prove at least:

- owner roles are `NOLOGIN`;
- login roles own no protected objects;
- runtime roles lack prohibited PostgreSQL attributes;
- runtime services cannot write protected tables directly;
- controlled APIs remain executable only by approved capability roles;
- investigators, audit readers, and validation readers cannot mutate state;
- role memberships contain no prohibited accumulation or cycles;
- default privileges protect newly created objects;
- `PUBLIC` has no Foundation or approved-extension access;
- migration authority is absent from ordinary runtime identities;
- break-glass is disabled at rest;
- the accepted Phase 4 SQL and behavior remain unchanged.

Tests that create cluster roles must use a disposable PostgreSQL cluster or a
strictly isolated test environment. A database-only disposable test must not
silently modify shared development-cluster role state.

## 13. Phase 5 Step Plan

### Step 1 — Contract Freeze

Freeze this role, ownership, migration, runtime, investigation, validation,
audit, default-privilege, and break-glass boundary.

No production role SQL is created in Step 1.

### Step 2 — Deployment Manifest and Role Topology

Create the deployment migration structure and implement non-login owner and
capability roles plus bounded login roles.

### Step 3 — Ownership and Default Privileges

Transfer database, schema, extension, and object ownership and establish
creator-specific default privileges.

### Step 4 — Least-Privileged Runtime Grants

Grant only the controlled routines, approved views, and narrow repository
capabilities required by production services.

### Step 5 — Review and Validation Roles

Implement investigator, audit-reader, and validation-reader boundaries.

### Step 6 — Break-Glass and Credential Lifecycle

Implement disabled-at-rest emergency access, activation evidence, expiration,
deactivation, and credential rotation requirements.

### Step 7 — Hostile-Condition and Role-Race Validation

Prove privilege denial, membership boundaries, creator-specific defaults,
ownership separation, and safe concurrent deployment behavior.

### Step 8 — Formal Acceptance

Create the Phase 5 acceptance record and annotated implementation tag.

## 14. Step 1 Acceptance Criteria

Phase 5 Step 1 is accepted only when:

- Phase 4 remains formally accepted and revalidates completely;
- this normative contract exists;
- status and validation documentation identify Phase 5 Step 1;
- no accepted Foundation migration or executable test is changed;
- no deployment role SQL is introduced prematurely;
- the Phase 5 Step 1 static gate passes;
- the complete gate preserves:
  - 34 Foundation migrations;
  - 21 sequential test files;
  - 16 concurrency test files;
  - 734 PASS;
  - 0 FAIL;
  - 3 understood WARN;
  - correctness `PASS`;
  - resource observation `RECORDED`;
  - performance thresholds `NOT_EVALUATED`.

## 15. Explicit Non-Claims

Phase 5 Step 1 does not claim:

- production roles exist;
- production ownership has been transferred;
- runtime grants are deployed;
- service credentials are provisioned;
- break-glass is operational;
- host compromise is contained;
- backups are protected;
- off-host integrity anchoring exists;
- production Go services are ready.

It freezes the contract against which those later implementations will be
built and tested.

## Phase 5 Step 2 Implementation Status

Phase 5 Step 2 implements the deployment manifest and canonical PostgreSQL
role topology defined by this contract in the separate `sql/deployment` tree.

Implemented in Step 2:

- exact deployment migration registry and SHA-256 recording;
- 18 canonical role shells;
- four bounded login roles with null passwords;
- nine service-to-capability memberships using `INHERIT TRUE`, `SET FALSE`,
  and `ADMIN FALSE`;
- disabled-at-rest `issp_break_glass` shell;
- disposable-cluster role validation.

Still deferred:

- object ownership transfer and creator-specific default privileges;
- protected object grants;
- approved review surfaces;
- credential provisioning;
- break-glass activation lifecycle.

## Phase 5 Step 4 Implementation Status

Phase 5 Step 4 implements the current production runtime allowlist:

```text
1  inherited database CONNECT capability
8  exact schema USAGE privileges
31 controlled routine EXECUTE privileges
0  direct protected relation or sequence privileges
```

The authorization service receives only the accepted controlled Foundation
APIs. Integration and monitoring delivery workers receive bounded
claim/completion/retry APIs that execute as `issp_foundation_owner`.

Investigator, audit-reader, validation-reader, migration, and break-glass
access remains deferred.

<!-- ISSP_PHASE5_STEP5_REVIEW_AND_VALIDATION_ROLES -->

## Phase 5 Step 5 Implementation Status

Phase 5 Step 5 implements separate `NOLOGIN` investigator, audit-reader, and validation-reader capabilities through an exact 40-row view-only privilege contract. The implementation adds two reduced-disclosure investigator views, eight audit-lineage views, and 23 validation-posture views. No review role receives direct protected base-table, sequence, mutation, routine-execution, schema-creation, or temporary-object authority. Phase 5 Step 6 may implement disabled-at-rest break-glass activation and credential lifecycle controls.

## Phase 5 Step 6 Implementation Status

Phase 5 Step 6 implements disabled-at-rest `issp_break_glass` activation,
independent approval evidence, bounded expiration, forced deactivation,
append-only emergency evidence, off-host-export requirements, and external
credential lifecycle policy through deployment migration
`940_break_glass_and_credential_lifecycle.sql`. Credentials, private keys,
tokens, and passwords remain outside the repository and database. Phase 5 Step
7 may perform hostile-condition and role-race validation.

## Phase 5 Step 7 — Hostile-Condition and Role-Race Validation

Phase 5 Step 7 adds hostile-input and PostgreSQL role-race validation plus one pre-freeze hardening correction to deployment migration `940_break_glass_and_credential_lifecycle.sql`: an activated SCRAM verifier must use at least 4096 iterations and cryptographically match the independently approved fingerprint. It introduces no new deployment migration or authority. Concurrent preparation, activation, live-session deactivation, use-versus-closure, and expiration-versus-deactivation must remain deterministic, attributable, and fail-closed before Phase 5 formal acceptance.
