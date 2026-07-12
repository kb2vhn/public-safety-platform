# Platform Documentation

> **Owner:** Iron Signal Systems
>
> **Current status:** Phase 4 Step 3 — controlled Approval Action recording
> with observation-only resource telemetry
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

## Active Phase 4 Step 3

Functional implementation:

```text
sql/schema/migrations/foundation/
└── 083_postgresql_approval_independence_and_separation_of_duties.sql

test-framework/sql/tests/foundation/
├── 170_approval_independence_and_separation_of_duties_structure.sql
└── 180_controlled_approval_action_recording.sql
```

Migration `083` now includes the controlled Approval Action API, exact current
request/policy/stage/actor/session/organization/Authority Grant validation,
typed action-lineage rules, and append-only mutation guards. Test `180`
contributes 55 functional assertions.

Resource-observation infrastructure remains:

```text
test-framework/sql/schema/scripts/
└── test_foundation_with_resources.sh
```

Step 3 target:

```text
34 migrations
18 sequential tests
9 concurrency tests
500 PASS
0 FAIL
3 understood WARN
Resource observation: RECORDED
Performance thresholds: NOT_EVALUATED
```

The resource wrapper contributes no SQL PASS rows and enforces no performance
threshold.

## Change Discipline

A material Foundation change normally updates the governing architecture, SQL
migration, authoritative manifests, positive and negative tests, concurrency
tests when applicable, phase gate, testing documentation, and resource
observation contract when execution cost can change.
