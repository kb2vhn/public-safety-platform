# Schema Naming Conventions

> **Document status:** Normative Platform Foundation architecture.
>
> **Implementation status:** The Foundation SQL migrations provide an initial structural implementation. A requirement described here is not considered fully enforced until the applicable database controls, deployment roles, runtime behavior, automated tests, and operational safeguards are in place.

## Purpose

Keep PostgreSQL objects predictable, reviewable, and resistant to accidental ambiguity as the platform grows.

## Architectural Requirements

### General Form

- SQL identifiers use lowercase `snake_case`.
- Schema, table, column, constraint, index, sequence, view, and function names are descriptive.
- Avoid abbreviations unless they are established platform terms.
- Reserved words and quoted mixed-case identifiers are prohibited.
- Objects are schema-qualified in migrations and security-sensitive functions.

### Schemas

Schemas represent stable capability boundaries, not individual features or developers. Domain modules use their own schemas and do not place application objects in `public`.

### Tables and Views

Tables use plural nouns when they represent collections. Link tables describe both sides of the relationship. Views use names that describe the projection or validation question.

### Keys

Primary keys use `<entity>_id`. Foreign keys use the referenced entity name. Stable external identifiers and human-readable codes are separate from internal primary keys.

### Time

Use `timestamptz` for operational times. Names describe meaning, such as `issued_at`, `effective_from`, `effective_until`, `recorded_at`, `revoked_at`, or `superseded_at`.

Avoid ambiguous names such as `date`, `time`, or `timestamp`.

### Constraints and Indexes

Recommended patterns:

```text
pk_<table>
fk_<table>__<referenced_table>
uq_<table>__<columns>
ck_<table>__<rule>
ix_<table>__<columns>
```

Names may be shortened only when PostgreSQL's identifier limit requires it, while retaining unambiguous meaning.

### Functions

Functions use verb phrases that describe behavior. Assertions begin with `assert_`, verification functions with `verify_`, controlled mutations with an explicit action verb, and validation views or functions with `validate_` where appropriate.

### Migration Files

Foundation migration files use:

```text
NNN_descriptive_name.sql
```

The filename stem is the migration identifier recorded by the migration registry and listed in the manifest.

## SQL Implementation Mapping

Migration `000_platform_initialization.sql` establishes the initial schema set and migration registry. All Foundation migrations must follow these conventions or document a justified exception.

The migration mapping identifies the current structural implementation. It does not, by itself, prove that every requirement in this document is operationally enforced.

## Validation Expectations

The Foundation SQL test framework must test the requirements that can be demonstrated at the database boundary. Runtime, deployment, recovery, and provider behavior must be tested in their respective layers.

## Related Documents

- [SQL Migration Map](sql-migration-map.md)
- [Database Security](database-security-model.md)
- [PostgreSQL Architecture](../postgresql.md)
