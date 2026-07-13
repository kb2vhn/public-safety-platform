# Phase Gates

> **Owner:** Iron Signal Systems

This directory contains reproducible acceptance gates for completed and active
Foundation phases. Historical gates validate their own checkpoint trees.

Newest gate:

```text
validate_phase4_step8.sh
```

Phase 4 progression:

- Step 1 froze the approval-independence and separation-of-duties contract.
- Step 2 added migration `083`, structural test `170`, and resource telemetry.
- Step 3 added controlled Approval Action recording and test `180`; accepted
  at 500 PASS, 0 FAIL, and 3 understood WARN.
- Step 4 added independence enforcement and test `190`; accepted at
  540 PASS, 0 FAIL, and 3 understood WARN.
- Step 5 added delegated-grant lineage, incompatible-authority and prohibited-
  duty enforcement, and test `200`; accepted at 590 PASS, 0 FAIL, and
  3 understood WARN.
- Step 6 added current-action derivation, stage satisfaction, finalization,
  Decision Record stage links, and approval continuity; accepted at
  650 PASS, 0 FAIL, and 3 understood WARN.
- Step 7 added seven independent-connection approval concurrency files and
  84 assertions; accepted at 734 PASS, 0 FAIL, and 3 understood WARN.
- Step 8 records formal Phase 4 acceptance and verifies the annotated tag,
  accepted tree, documentation, correctness result, and resource observation.

## Cross-Phase Static Standard

The active phase gate invokes the separate cross-phase migration timeout
standard before database execution:

```bash
./tools/validation/validate_foundation_migration_timeouts.sh
```

## Active Gate: Phase 4 Step 8

```bash
./tools/validation/phase-gates/validate_phase4_step8.sh
```

The gate validates the annotated tag `phase-4-approval-independence-and-separation-of-duties-complete-v1`, 34 migrations, 21 sequential
tests, 16 concurrency tests, the accepted SQL and executable test tree, the
734 PASS result, synchronized acceptance documentation, and observation-only
resource telemetry.

## Phase 5 Step 1

`validate_phase5_step1.sh` freezes the production database role, ownership,
migration, runtime privilege, investigation, audit, validation,
default-privilege, and break-glass contract.

Step 1 is documentation and validation only. It preserves the accepted Phase 4
implementation and uses `validate_phase4_step8.sh` as its regression
predecessor.

## Phase 5 Step 2

`validate_phase5_step2.sh` validates the separate deployment tree, migration
900, canonical role inventory, membership semantics, documentation, accepted
Foundation regression, and isolated disposable-cluster role behavior.
