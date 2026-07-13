# Phase 5 Step 4 — Least-Privileged Runtime Grants and Controlled Service APIs

> **Status:** Candidate implementation.
>
> **Predecessor:** Phase 5 Step 3 protected ownership and creator-specific
> default privileges.
>
> **Scope:** Runtime database connection, exact schema visibility, controlled
> routine execution, and bounded delivery APIs for the current production
> service identities.

## 1. Purpose

Allow the bounded production service identities to use only the database
capabilities required by their current responsibilities without restoring
direct protected-table access.

Step 4 does not grant a monolithic application role. Privileges flow through
the capability memberships created in migration `900`.

## 2. Database Connection Boundary

`issp_runtime` receives `CONNECT` on the active Iron Signal Platform database.

The three bounded service login roles inherit that capability:

```text
issp_service_authorization
issp_service_integration_delivery
issp_service_monitoring_delivery
```

They do not receive `TEMPORARY`.

The following roles remain unable to connect through the Step 4 runtime
contract:

```text
issp_migration_executor
issp_read_only_investigator
issp_audit_reader
issp_validation_reader
issp_break_glass
```

Owner roles retain only the ownership authority inherent in PostgreSQL.

## 3. Schema Visibility

Schema `USAGE` is granted only to the capability role that needs to resolve its
approved routines:

| Capability role | Schemas |
|---|---|
| `issp_writer_authentication_assertion` | `access_control` |
| `issp_writer_session_control` | `access_control` |
| `issp_writer_authorization_decision` | `access_control`, `decision` |
| `issp_writer_approval` | `approval`, `decision` |
| `issp_writer_integration_delivery` | `integration` |
| `issp_writer_monitoring_delivery` | `observability` |

No service login receives a direct schema grant.

## 4. Controlled Routine Boundary

Step 4 exposes exactly 31 routines:

```text
5  Authentication Assertion lifecycle routines
8  session-control routines
8  authorization-decision and Authorization Lease routines
4  approval and Decision Record linkage routines
3  integration-delivery routines
3  monitoring-delivery routines
```

Every exposed routine is:

- owned by `issp_foundation_owner`;
- `SECURITY DEFINER`;
- configured with a fixed `search_path` beginning with `pg_catalog`;
- revoked from `PUBLIC`;
- executable only through its bounded writer capability.

Internal helper functions and trigger functions remain unexposed.

## 5. Direct Relation Access

Step 4 grants no direct privileges on protected tables, views, materialized
views, sequences, or foreign tables to:

- `issp_runtime`;
- any service login;
- any controlled writer;
- any review role;
- the migration executor;
- break-glass.

The authorization service therefore uses only the already accepted controlled
Foundation routines. Step 4 does not invent direct write shortcuts for missing
future service workflows.

## 6. Integration Delivery API

The Foundation outbox tables existed before production runtime grants. Step 4
adds three bounded APIs:

```text
integration.claim_outbox_events(integer, interval)
integration.mark_outbox_event_delivered(uuid)
integration.reschedule_outbox_event(uuid, text, timestamptz)
```

The claim operation:

- uses PostgreSQL statement time;
- validates the contract is currently active;
- uses `FOR UPDATE SKIP LOCKED`;
- enforces a claim limit of 1 through 100;
- limits claim leases to no more than 15 minutes;
- atomically increments the attempt count;
- supports recovery of expired `IN_PROGRESS` claims;
- returns the approved contract and payload snapshot.

The completion and retry functions only transition a currently claimed row.

## 7. Monitoring Delivery API

Step 4 adds:

```text
observability.claim_monitoring_deliveries(integer, interval)
observability.mark_monitoring_delivery_delivered(uuid)
observability.reschedule_monitoring_delivery(uuid, text, timestamptz)
```

The claim operation:

- selects only active subscriptions;
- respects the configured retry limit;
- uses `FOR UPDATE SKIP LOCKED`;
- returns the destination and one approved health-event or metric payload;
- supports recovery of expired claims.

Rescheduling changes the row to `FAILED` when the configured retry limit has
been exhausted.

## 8. Cryptographic Dependency

Authorization Lease routines use `extensions.digest(bytea, text)`.

Because the exposed routines execute as `issp_foundation_owner`, Step 4 grants
that owner only:

```text
USAGE   ON SCHEMA extensions
EXECUTE ON FUNCTION extensions.digest(bytea, text)
```

No runtime or service role receives direct access to the extension schema.

## 9. Runtime Privilege Inventory

Migration `920` creates:

```text
deployment_meta.runtime_privilege_contract
```

The table is the exact runtime allowlist:

```text
1  database CONNECT row
8  schema USAGE rows
31 routine EXECUTE rows
40 total rows
```

Absence from the allowlist means the privilege is not approved.

## 10. Migration

Step 4 adds:

```text
sql/deployment/migrations/920_least_privileged_runtime_grants_and_controlled_service_apis.sql
```

The deployment manifest becomes:

```text
migrations/900_postgresql_role_topology_and_membership.sql
migrations/910_database_schema_and_object_ownership.sql
migrations/920_least_privileged_runtime_grants_and_controlled_service_apis.sql
```

## 11. Disposable-Cluster Testing

The Step 4 test:

- creates an isolated Unix-socket-only PostgreSQL cluster;
- applies all 34 accepted Foundation migrations;
- applies deployment migrations `900`, `910`, and `920`;
- reapplies the deployment manifest to prove checksum-based idempotence;
- proves inherited `CONNECT` and denial of `TEMPORARY`;
- verifies the 40-row privilege allowlist;
- verifies all 31 routines are protected `SECURITY DEFINER` functions;
- proves no canonical non-owner role has direct relation privileges;
- exercises integration and monitoring claim/completion operations as their
  actual service identities;
- proves cross-service calls and direct table access are denied;
- destroys the temporary cluster.

The shared development PostgreSQL cluster is not modified.

## 12. Explicit Non-Claims

Step 4 does not:

- provision passwords, certificates, or service secrets;
- apply deployment migrations to `dev_testing`;
- grant direct protected-table writes;
- expose every future lifecycle-root creation workflow;
- implement investigator, audit, or validation read surfaces;
- activate break-glass;
- resolve the PostgreSQL extension catalog-owner limitation;
- implement host hardening, off-host logging, or protected backups;
- make the platform production-ready.

## 13. Acceptance Criteria

Step 4 is accepted only when:

- the frozen Phase 4 `sql/schema` tree remains unchanged;
- the 34-migration, 734-PASS Foundation regression still passes;
- deployment migrations `900`, `910`, and `920` register with exact
  checksums;
- the runtime allowlist contains exactly 40 rows;
- the three service identities inherit database `CONNECT`;
- runtime identities lack `TEMPORARY`;
- review, migration, and break-glass roles remain disconnected;
- every exposed routine has the required owner, `SECURITY DEFINER`, fixed
  `search_path`, and `PUBLIC` denial;
- no canonical non-owner role has direct relation or sequence privileges;
- integration and monitoring delivery workflows succeed only through their
  controlled APIs;
- cross-service execution attempts fail;
- the disposable-cluster Step 4 test passes.

## 14. Next Step

Phase 5 Step 5 implements separately governed investigator, audit-reader, and
validation-reader access through approved review surfaces.
