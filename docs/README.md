# Platform Documentation

> **Owner:** Iron Signal Systems
>
> **Current status:** Phase 4 Step 3 accepted; Phase 4 Step 4 independence
> enforcement candidate with observation-only resource telemetry
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

- Phase 1 Authentication Assertions: `phase-1-authentication-assertion-complete-v1`
- Phase 2 Session Control: `phase-2-session-control-complete-v1`
- Phase 3 Authorization Decision and Controlled Lease Issuance:
  `phase-3-authorization-control-complete-v1`
- Phase 4 Step 3 controlled Approval Action recording:
  34 migrations, 18 sequential tests, 9 concurrency tests,
  500 PASS, 0 FAIL, 3 understood WARN

## Active Phase 4 Step 4

```text
sql/schema/migrations/foundation/
└── 083_postgresql_approval_independence_and_separation_of_duties.sql

test-framework/sql/tests/foundation/
├── 170_approval_independence_and_separation_of_duties_structure.sql
├── 180_controlled_approval_action_recording.sql
└── 190_approval_independence_enforcement.sql
```

The Step 4 candidate extends the controlled Approval Action API with
self-approval, directly affected identity, duplicate effective actor, distinct
organization, Authority Grant origin, and explicit reciprocal-chain checks.
Test `190` contributes exactly 40 functional assertions.

Step 4 target:

```text
34 migrations
19 sequential tests
9 concurrency tests
540 PASS
0 FAIL
3 understood WARN
Resource observation: RECORDED
Performance thresholds: NOT_EVALUATED
```

## Documentation Synchronization Rule

A phase step is not complete until the root README, documentation indexes,
architecture status, test documentation, validation documentation, active gate,
counts, terminology, and next-step statement all describe the same accepted
repository state.
