# Platform Documentation

> **Owner:** Iron Signal Systems
>
> **Current status:** Phase 4 Step 4 accepted; Phase 4 Step 5 incompatible-authority
> and duty-conflict enforcement candidate with observation-only resource telemetry
>
> **Status:** Pre-alpha; not ready for production use

## Start Here

- [Repository Overview](../README.md)
- [Architecture Index](architecture/README.md)
- [Platform Foundation Documentation](architecture/foundation/README.md)
- [Approval Independence and Separation of Duties](architecture/foundation/approval-independence-and-separation-of-duties-model.md)
- [Resource Telemetry and Performance-Regression Testing](architecture/foundation/resource-telemetry-and-performance-regression-testing-model.md)
- [Foundation Migration Timeout and Execution Performance Standard](architecture/foundation/foundation-migration-timeout-and-execution-performance-standard.md)
- [Phase 3 Authorization Acceptance](architecture/foundation/phase-3-authorization-decision-and-controlled-lease-acceptance.md)
- [Project Goals](goals/README.md)
- [Compliance Profiles](compliance-profiles/README.md)
- [Validation Tools](../tools/validation/README.md)

## Accepted Boundaries

- Phase 1 Authentication Assertions: `phase-1-authentication-assertion-complete-v1`
- Phase 2 Session Control: `phase-2-session-control-complete-v1`
- Phase 3 Authorization Decision and Controlled Lease Issuance:
  `phase-3-authorization-control-complete-v1`
- Phase 4 Step 4 approval independence enforcement:
  34 migrations, 19 sequential tests, 9 concurrency tests,
  540 PASS, 0 FAIL, 3 understood WARN

## Active Phase 4 Step 5

```text
sql/schema/migrations/foundation/
└── 083_postgresql_approval_independence_and_separation_of_duties.sql

test-framework/sql/tests/foundation/
├── 170_approval_independence_and_separation_of_duties_structure.sql
├── 180_controlled_approval_action_recording.sql
├── 190_approval_independence_enforcement.sql
└── 200_incompatible_authority_and_duty_conflict_enforcement.sql
```

The Step 5 candidate preserves the accepted Step 4 independence boundary and
adds delegated Authority Grant lineage, three explicit incompatible-authority
modes, immutable `APPROVE` duty recording, prohibited-duty evaluation, and
fail-closed treatment of an unavailable duty scope. Test `200` contributes
exactly 50 functional assertions.

Step 5 target:

```text
34 migrations
20 sequential tests
9 concurrency tests
590 PASS
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

## Foundation Migration Execution Standard

Ordinary clean-install Foundation migrations use transaction-local limits of
`5s` for lock waits, `1min` per statement, and `1min` for an idle open
transaction. Statements observed above ten seconds require investigation.

Static validation:

```bash
./tools/validation/validate_foundation_migration_timeouts.sh
```

The active Phase 4 Step 5 gate invokes this validator automatically. It can
also be run independently. The repository-policy check does not add SQL PASS
rows or activate a general performance-regression threshold.

## Phase 4 Step 6 Candidate

Phase 4 Step 5 is accepted at 590 PASS, 0 FAIL, 3 understood WARN results.
Phase 4 Step 6 implements current Approval Action derivation,
persisted policy-stage satisfaction, blocking-denial outcomes,
finalization-once Approval Requests, exact Decision Record stage links, and
later-use continuity for approval-backed Authorization Leases.

The Step 6 candidate target is:

```text
34 manifest migrations
34 registered migrations
21 sequential test files
9 concurrency test files
650 PASS
0 FAIL
3 understood WARN
Resource observation: RECORDED
Performance thresholds: NOT_EVALUATED
```

The active gate is
`tools/validation/phase-gates/validate_phase4_step6.sh`. Independent-
connection finalization races remain Phase 4 Step 7.
