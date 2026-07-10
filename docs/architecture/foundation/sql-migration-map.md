# Platform Foundation SQL Migration Map

## Purpose

This document maps accepted Foundation architecture to the future SQL rewrite.

The SQL rewrite begins only after the documentation is accepted.

## Proposed Sequence

```text
000 platform initialization
010 cryptographic and device trust
020 identity
025 identity lifecycle
030 organizations and jurisdictions
035 platform services and configuration
040 service participation and federation
045 attestations and access eligibility
050 approval framework
055 authority, purpose, and authorization policy
060 sessions
065 authorization leases
070 PostgreSQL trust gate
075 controlled authorization API
080 Decision Record Repository
082 data classification and governance
084 lifecycle and historical lineage
086 governed documents and policy versions
087 common control catalog
088 compliance profiles and requirement mappings
089 control implementations and evidence
090 assessments, findings, remediation, exceptions, and risk
091 threat records and abuse-case mappings
092 resilience, availability, recovery, and continuity records
093 workload registry, performance budgets, capacity, and resource governance
094 client experience and deployment performance profiles
095 canonical health, observability, and operational telemetry
096 monitoring subscriptions and provider delivery state
097 provider integration outbox
098 row-level security, role separation, incompatible-authority controls, and foundation validation
```

## Migration Rules

- Every migration identifier is unique.
- Load order is explicit.
- Foundation migrations do not reference domain tables.
- Compliance profiles and domain migrations may depend on Foundation contracts.
- Every migration documents ownership, dependencies, invariants, and non-responsibilities.
- Security validation verifies grants, owners, `search_path`, RLS, incompatible role combinations, unrestricted access paths, and immutable Decision Record boundaries.
- No application role receives God Access.
- Infrastructure-superuser use remains outside ordinary application operation.
- Compliance status is derived from normalized records, not unsupported Boolean fields.
- Threat and resilience objects must be versioned and effective-dated.
- Availability controls must not bypass confidentiality or integrity controls.
- Performance and client requirements must be represented as governed, measurable records where applicable.
- No schema or service may assume high-end client or server hardware as a correctness requirement.
- Every workload and database connection must be attributable to a versioned component and workload class.
- Monitoring-provider failure must not affect core transactions.
- Temporary-resource limits and workload isolation must be enforceable by role or workload class.

## Existing SQL Review

Every existing object must be classified:

```text
KEEP
MOVE
SPLIT
RENAME
REDESIGN
REMOVE
```

## Rewrite Principle

Existing SQL remains source material, but architecture controls the rewrite.
