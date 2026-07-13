# Phase Gates

> **Owner:** Iron Signal Systems

This directory contains reproducible acceptance gates for completed and active
Foundation phases. Historical gates validate their own checkpoint trees.

Newest gate:

```text
validate_phase4_step5.sh
```

Phase 4 progression:

- Step 1 froze the approval-independence and separation-of-duties contract.
- Step 2 added migration `083`, structural test `170`, and resource telemetry.
- Step 3 added controlled Approval Action recording and test `180`; it is
  accepted at 500 PASS, 0 FAIL, and 3 understood WARN.
- Step 4 added independence enforcement and test `190`; it is accepted at
  540 PASS, 0 FAIL, and 3 understood WARN.
- Step 5 adds delegated-grant lineage, incompatible-authority and prohibited-
  duty enforcement, and test `200`; its candidate target is 590 PASS, 0 FAIL,
  and 3 understood WARN.

Run the newest gate for the current repository state.


## Cross-Phase Static Standard

The active phase gate remains the authority for the current Phase 4 candidate.
It invokes the separate cross-phase migration timeout standard before database
execution. The validator can also be run independently:

```bash
./tools/validation/validate_foundation_migration_timeouts.sh
```

Run the independent command for focused review. Future phase gates must continue
to invoke or reproduce this static contract before database execution.

## Active Gate: Phase 4 Step 6

```bash
./tools/validation/phase-gates/validate_phase4_step6.sh
```

This gate validates 34 migrations, 21 sequential tests, 9 concurrency tests,
60 Step 6 assertions, the 650 PASS target, resource telemetry, exact
Decision Record approval-stage linkage, and later-use approval continuity.
