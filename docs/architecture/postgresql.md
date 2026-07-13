# PostgreSQL Architecture

> **Status:** Adopted architectural direction with an active Foundation migration implementation.

## Decision

PostgreSQL is the authoritative transactional database for the Platform Foundation and future operational modules.

The platform uses PostgreSQL for more than persistence. PostgreSQL independently verifies selected trust and authorization conditions so that application compromise does not automatically become unrestricted database authority.

## Design Principles

1. **The application does not receive unrestricted table access.**
2. **Protected writes use controlled database functions or narrowly scoped repository roles.**
3. **Constraints, foreign keys, privileges, row policies, and functions enforce invariants close to the data.**
4. **Security-sensitive functions use schema-qualified references and controlled `search_path` settings.**
5. **Ownership is separated from runtime login roles.**
6. **Historical and decision records use append-oriented correction and supersession models.**
7. **Migration order is explicit and manifest-driven.**
8. **Every migration must install on a clean database and pass automated validation.**
9. **Database features should be simple, mature, and well understood.**

## Version and Feature Policy

The active development target is PostgreSQL 18.

Except where a newer feature is the only sound solution, the platform should prefer PostgreSQL features that were supported by at least one prior major release. This reduces unnecessary novelty and makes future upgrades and troubleshooting easier.

Extensions must be justified, explicitly installed, and isolated. The current Foundation uses `pgcrypto` for cryptographic primitives and stores extension objects outside the application schemas.

## Access Pattern

End-user clients must not connect directly to PostgreSQL.

The intended path is:

```text
User or system
      ↓
Authenticated platform service
      ↓
Trust and authorization evaluation
      ↓
Controlled PostgreSQL API
      ↓
Protected data
```

The future Go backend will use prepared statements, bounded transactions, context cancellation, timeouts, and narrowly scoped credentials.

## Migration Layout

```text
sql/schema/manifests/foundation.manifest
sql/schema/migrations/foundation/
sql/schema/scripts/apply_foundation.sh
sql/schema/scripts/validate_foundation.sh
```

Foundation migrations occupy `000–099`. Later ranges are reserved for shared resources, CAD, RMS, Evidence and Property, personnel, fleet, Fire/EMS, future modules, and deployment/bootstrap work.

## Testing

The SQL test framework remains intentionally separate from deployable migrations:

```text
test-framework/
```

It creates a disposable database, applies the live Foundation manifest, runs test-only assertions, and writes reviewable logs.

## Active Phase 5 Database Security Work

Phase 5 Step 1 freezes the production PostgreSQL role, ownership, migration,
runtime privilege, default-privilege, investigation, audit, validation, and
break-glass contract.

The accepted direction requires non-login ownership roles, service-specific
login identities, controlled migration authority, no direct protected-table
writes for ordinary runtime services, and creator-specific default privileges.

See:

- [Production Database Role, Ownership, and Runtime Privilege Model](foundation/production-database-role-ownership-and-runtime-privilege-model.md)

## Current Limitations

The schema is still pre-alpha. Final deployment roles, ownership transfers, complete append-only enforcement, populated migration checksums, off-host integrity anchoring, production backup protection, and the production Go data-access layer remain future work.
