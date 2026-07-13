# Database Security Model

> **Document status:** Normative Platform Foundation architecture.
>
> **Implementation status:** The Foundation SQL migrations provide an initial structural implementation. A requirement described here is not considered fully enforced until the applicable database controls, deployment roles, runtime behavior, automated tests, and operational safeguards are in place.

## Purpose

Define PostgreSQL as an independent security boundary rather than a passive datastore.

## Architectural Requirements

### Role Classes

Production deployment must separate non-login ownership roles, migration roles, runtime roles, controlled writers, read-only investigators, audit readers, and validation readers.

Login roles must not own protected schemas or tables.

### Controlled Access

End-user applications do not receive direct table access. Protected actions use narrowly scoped functions or repository roles with only the required privileges.

### Function Security

Security-sensitive functions must:

- Use schema-qualified object references,
- Set a controlled `search_path`,
- Revoke execution from `PUBLIC`,
- Validate all caller-supplied identifiers and scope,
- Return minimal information,
- Avoid dynamic SQL unless it is strictly bounded,
- Use the least powerful owner compatible with the requirement.

### Table Security

The database uses constraints, foreign keys, unique rules, check constraints, privileges, row policies where appropriate, and immutable or append-oriented write models.

Row-level security is an additional boundary, not a substitute for correct grants and controlled APIs.

### No Unrestricted Platform Account

No application or ordinary administrator account may accumulate universal read, write, approval, authorization, and audit-rewrite authority.

The PostgreSQL superuser and operating-system administrator remain unavoidable infrastructure trust boundaries. Their activity must be constrained by operational procedure, off-host logging, protected backups, and trusted recovery.

### Secret Handling

Runtime secrets are not stored in source code. Lease secrets and tokens must be high entropy, transmitted only over protected channels, stored as verifiers when possible, and never written to general logs.

### Time Consistency

Authorization checks should use a documented statement- or transaction-consistent time source unless wall-clock variation within a statement is explicitly required.

## Phase 5 Step 1 Role and Ownership Contract

Phase 5 Step 1 freezes the production database role, ownership, migration,
runtime privilege, investigation, audit, validation, default-privilege, and
break-glass boundary.

The governing contract is:

- [Production Database Role, Ownership, and Runtime Privilege Model](production-database-role-ownership-and-runtime-privilege-model.md)

Step 1 does not create cluster roles or transfer ownership. Those changes begin
only after the contract is accepted and a separate deployment manifest is
defined in the reserved `900–999` range.

## SQL Implementation Mapping

Migration `000` establishes initial schema and privilege posture. Migrations `070` and `075` introduce controlled trust and authorization APIs. Migration `098` models role separation and security boundaries. Migration `099` provides validation inventories.

Final deployment roles, ownership transfers, immutable write controls, and production grants remain deployment work.

The migration mapping identifies the current structural implementation. It does not, by itself, prove that every requirement in this document is operationally enforced.

## Validation Expectations

The Foundation SQL test framework must test the requirements that can be demonstrated at the database boundary. Runtime, deployment, recovery, and provider behavior must be tested in their respective layers.

## Related Documents

- [PostgreSQL Architecture](../postgresql.md)
- [Authentication and Authorization Evaluation](authentication-and-authorization-evaluation-model.md)
- [Decision Record Repository](decision-record-repository.md)
- [SQL Migration Map](sql-migration-map.md)

## Phase 5 Step 2 Role Topology

The approved role and ownership contract now has a concrete deployment tree
and PostgreSQL role topology. Canonical owner, migration, runtime, writer,
review, service, and disabled break-glass role shells are created by migration
900.

Object ownership and least-privileged object grants remain deferred.

See:

- [Phase 5 Step 2 — Deployment Manifest and PostgreSQL Role Topology](phase-5-step-2-deployment-role-topology.md)

## Phase 5 Step 3 Ownership Implementation

Deployment migration `910_database_schema_and_object_ownership.sql` transfers
the database, Foundation schemas, deployment metadata, extension schema,
relations, routines, and standalone types to approved non-login owners.

It also revokes `PUBLIC` database and protected-object access and establishes
creator-specific default privileges. Least-privileged runtime grants remain
Phase 5 Step 4 work.

## Phase 5 Step 4 Runtime Grant Implementation

Deployment migration `920` implements the least-privileged runtime allowlist.

The current allowlist contains one database connection privilege, eight schema
usage privileges, and 31 controlled routine execution privileges. Every
exposed routine is Foundation-owned, `SECURITY DEFINER`, fixed-search-path,
and revoked from `PUBLIC`.

No canonical non-owner role receives direct relation or sequence privileges.
