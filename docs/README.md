# Platform Documentation

> **Owner:** Iron Signal Systems
>
> **Current status:** Phase 4 Step 2 — approval-independence structural
> extension and baseline resource observation
>
> **Status:** Pre-alpha; not ready for production use

## Start Here

- [Repository Overview](../README.md)
- [Architecture Index](architecture/README.md)
- [Platform Foundation Documentation](architecture/foundation/README.md)
- [Approval Independence and Separation of Duties](architecture/foundation/approval-independence-and-separation-of-duties-model.md)
- [Resource Telemetry and Performance-Regression Testing](architecture/foundation/resource-telemetry-and-performance-regression-testing-model.md)
- [Phase 3 Authorization Acceptance](architecture/foundation/phase-3-authorization-decision-and-controlled-lease-acceptance.md)
- [Project Goals](goals/README.md)
- [Compliance Profiles](compliance-profiles/README.md)
- [Validation Tools](../tools/validation/README.md)

## Accepted Boundaries

- Phase 1 Authentication Assertions:
  `phase-1-authentication-assertion-complete-v1`
- Phase 2 Session Control:
  `phase-2-session-control-complete-v1`
- Phase 3 Authorization Decision and Controlled Lease Issuance:
  `phase-3-authorization-control-complete-v1`

## Active Phase 4 Step 2

Functional structure:

```text
sql/schema/migrations/foundation/
└── 083_postgresql_approval_independence_and_separation_of_duties.sql

test-framework/sql/tests/foundation/
└── 170_approval_independence_and_separation_of_duties_structure.sql
```

Resource-observation infrastructure:

```text
test-framework/sql/schema/scripts/
└── test_foundation_with_resources.sh
```

The SQL test contributes 37 functional assertions. The resource wrapper adds no
SQL PASS rows and enforces no performance threshold.

Step 2 target:

```text
34 migrations
17 sequential tests
9 concurrency tests
445 PASS
0 FAIL
3 understood WARN
Resource observation: RECORDED
Performance thresholds: NOT_EVALUATED
```

## Change Discipline

A material Foundation change normally updates the governing architecture, SQL
migration, authoritative manifests, positive and negative tests, concurrency
tests when applicable, phase gate, testing documentation, and resource
observation contract when execution cost can change.
