# Deployment and Bootstrap Migrations

This directory contains environment-facing migrations in the reserved
`900–999` range.

Deployment migrations are separate from the accepted Platform Foundation
`000–099` history. They may create PostgreSQL cluster roles, transfer
ownership, establish default privileges, and configure deployment-specific
security boundaries.

## Safety Rules

- Apply these migrations only through `sql/deployment/scripts/apply_deployment.sh`.
- A controlled PostgreSQL bootstrap identity is required.
- Never place passwords, private keys, tokens, or environment secrets in these
  files.
- Cluster-role tests must use a disposable PostgreSQL cluster.
- Ordinary Foundation test databases do not isolate cluster-global roles.

## Current Inventory

- `900_postgresql_role_topology_and_membership.sql`
  - creates canonical role shells;
  - creates bounded service-to-capability memberships;
  - leaves passwords unprovisioned;
  - leaves ownership and object privileges unchanged;
  - records exact SHA-256 deployment migration metadata.

## Phase 5 Step 3

`910_database_schema_and_object_ownership.sql` transfers the active database
and protected objects to approved non-login owners, removes existing `PUBLIC`
database and protected-object access, establishes creator-specific default
privileges, and records the PostgreSQL extension catalog-owner limitation.

Runtime object grants remain deferred to migration `920` and Phase 5 Step 4.

## Phase 5 Step 4

`920_least_privileged_runtime_grants_and_controlled_service_apis.sql` grants
inherited runtime connection, exact capability schema visibility, and
controlled routine execution. It also creates bounded integration and
monitoring delivery APIs.

It grants no direct protected relation or sequence privileges.

<!-- ISSP_PHASE5_STEP5_REVIEW_AND_VALIDATION_ROLES -->

## Phase 5 Step 5

Migration `930_investigator_audit_and_validation_review_surfaces.sql` creates the `security_review` view boundary, deployment-posture views, and the exact investigator, audit-reader, and validation-reader privilege contract. Runtime grants remain those accepted in migration `920`; break-glass remains disabled at rest.

## Phase 5 Step 6 Implementation Status

Phase 5 Step 6 implements disabled-at-rest `issp_break_glass` activation,
independent approval evidence, bounded expiration, forced deactivation,
append-only emergency evidence, off-host-export requirements, and external
credential lifecycle policy through deployment migration
`940_break_glass_and_credential_lifecycle.sql`. Credentials, private keys,
tokens, and passwords remain outside the repository and database. Phase 5 Step
7 may perform hostile-condition and role-race validation.
