# Platform Documentation

> **Owner:** Iron Signal Systems
>
> **Current status:** Phase 4 Step 6 accepted; Phase 4 Step 7
> independent-connection approval concurrency candidate
>
> **Status:** Pre-alpha; not ready for production use

## Start Here

- [Repository Overview](../README.md)
- [Architecture Index](architecture/README.md)
- [Platform Foundation Documentation](architecture/foundation/README.md)
- [Approval Independence and Separation of Duties](architecture/foundation/approval-independence-and-separation-of-duties-model.md)
- [Backend Services Architecture](architecture/backend-services/README.md)
- [Communications Architecture](architecture/communications/README.md)
- [GIS and Mapping Architecture](architecture/gis-and-mapping/README.md)
- [Operational Workstation Architecture](architecture/operational-workstation/README.md)
- [User-Interface Architecture](architecture/user-interface/README.md)
- [Resource Telemetry and Performance-Regression Testing](architecture/foundation/resource-telemetry-and-performance-regression-testing-model.md)
- [Foundation Migration Timeout and Execution Performance Standard](architecture/foundation/foundation-migration-timeout-and-execution-performance-standard.md)
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
- Phase 4 Step 5 incompatible-authority and duty-conflict enforcement:
  34 migrations, 20 sequential tests, 9 concurrency tests,
  590 PASS, 0 FAIL, 3 understood WARN
- Phase 4 Step 6 stage satisfaction and finalization:
  34 migrations, 21 sequential tests, 9 concurrency tests,
  650 PASS, 0 FAIL, 3 understood WARN,
  correctness PASS, resource observation RECORDED

## Active Phase 4 Step 7

```text
sql/schema/migrations/foundation/
└── 083_postgresql_approval_independence_and_separation_of_duties.sql

test-framework/sql/tests/concurrency/
├── 190_approval_duplicate_actor_race.sh
├── 200_approval_stage_finalized_evaluation_race.sh
├── 210_approval_request_finalization_race.sh
├── 220_approval_last_approval_finalization_race.sh
├── 230_approval_withdrawal_finalization_race.sh
├── 240_approval_authority_revocation_race.sh
└── 250_approval_reciprocal_approval_race.sh
```

Step 7 preserves the accepted Step 6 state model and adds stable request-chain
serialization, Authority Grant revocation exclusion, and seven
independent-connection proofs. Each new concurrency file contributes exactly
12 assertions, for 84 new assertions.

Step 7 target:

```text
34 manifest migrations
34 registered migrations
21 sequential test files
16 concurrency test files
734 PASS
0 FAIL
3 understood WARN
Correctness result: PASS
Resource observation: RECORDED
Performance thresholds: NOT_EVALUATED
```

## Module-Idea Boundary

The backend-service, communications, GIS and mapping, operational-workstation,
and user-interface documents are downstream architecture areas. Step 7 does
not move their domain-specific records, presentation state, live transport,
map rendering, or workstation behavior into the domain-neutral Foundation.

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

The active Phase 4 Step 7 gate invokes this validator automatically. It can
also be run independently. The repository-policy check does not add SQL PASS
rows or activate a general performance-regression threshold.
