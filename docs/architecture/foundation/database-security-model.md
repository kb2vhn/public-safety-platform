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
