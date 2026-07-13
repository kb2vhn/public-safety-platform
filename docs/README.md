# Platform Documentation

> **Owner:** Iron Signal Systems
>
> **Current status:** Phase 4 approval independence and separation of duties
> formally accepted
>
> **Accepted tag:** `phase-4-approval-independence-and-separation-of-duties-complete-v1`
>
> **Status:** Pre-alpha; not ready for production use

## Start Here

- [Repository Overview](../README.md)
- [Architecture Index](architecture/README.md)
- [Platform Foundation Documentation](architecture/foundation/README.md)
- [Approval Independence and Separation of Duties](architecture/foundation/approval-independence-and-separation-of-duties-model.md)
- [Phase 4 Approval Independence and Separation of Duties Acceptance](architecture/foundation/phase-4-approval-independence-and-separation-of-duties-acceptance.md)
- [Backend Services Architecture](architecture/backend-services/README.md)
- [Communications Architecture](architecture/communications/README.md)
- [GIS and Mapping Architecture](architecture/gis-and-mapping/README.md)
- [Operational Workstation Architecture](../modules/CAD/docs/architecture/operational-workstation/README.md)
- [User-Interface Architecture](../modules/CAD/docs/architecture/user-interface/README.md)
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
- Phase 4 Approval Independence and Separation of Duties:
  `phase-4-approval-independence-and-separation-of-duties-complete-v1`

Accepted Phase 4 result:

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
159 phase-gate PASS checks
0 phase-gate FAIL checks
```

## Accepted Phase 4 Scope

The accepted boundary includes controlled Approval Action recording, exact
actor/session/Authority Grant context, approval independence, delegated-grant
lineage, incompatible-authority and prohibited-duty enforcement, stage
satisfaction, finalization-once Approval Requests, Decision Record stage
linkage, later-use approval continuity, and independent-connection concurrency
proofs.

The seven Phase 4 concurrency files contribute 84 assertions and increase the
complete concurrency inventory from 9 to 16.

## Module-Idea Boundary

The backend-service, communications, GIS and mapping, operational-workstation,
and user-interface documents are downstream architecture areas. Phase 4 does
not move their domain-specific records, presentation state, live transport,
map rendering, or workstation behavior into the domain-neutral Foundation.

## Documentation Synchronization Rule

A phase is not complete until the root README, documentation indexes,
architecture status, test documentation, validation documentation, acceptance
record, counts, terminology, accepted tag, and next-work statement describe
the same repository state.

## Foundation Migration Execution Standard

Ordinary clean-install Foundation migrations use transaction-local limits of
`5s` for lock waits, `1min` per statement, and `1min` for an idle open
transaction. Statements observed above ten seconds require investigation.

Static validation:

```bash
./tools/validation/validate_foundation_migration_timeouts.sh
```

The Phase 4 formal-acceptance gate invokes this validator automatically. The
repository-policy check does not add SQL PASS rows or activate a general
performance-regression threshold.

## Phase 4 Revalidation

Run the formal acceptance gate with:

```bash
./tools/validation/phase-gates/validate_phase4_step8.sh
```

## Active Phase 5 Step 1

Phase 5 Step 1 freezes the production PostgreSQL role, ownership, migration,
runtime privilege, investigation, audit, validation, default-privilege, and
break-glass contract without changing the accepted Phase 4 SQL or executable
test tree.

- [Production Database Role, Ownership, and Runtime Privilege Model](architecture/foundation/production-database-role-ownership-and-runtime-privilege-model.md)

Active gate:

```bash
./tools/validation/phase-gates/validate_phase5_step1.sh
```
