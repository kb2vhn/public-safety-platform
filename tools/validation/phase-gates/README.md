# Phase Gates

> **Owner:** Iron Signal Systems

This directory contains reproducible acceptance gates for completed and active
Foundation phases. Historical gates validate their own checkpoint trees.

Newest gate:

```text
validate_phase4_step7.sh
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
- Step 7 adds seven independent-connection approval concurrency files and
  84 assertions; its candidate target is 734 PASS, 0 FAIL, and
  3 understood WARN.

## Cross-Phase Static Standard

The active phase gate invokes the separate cross-phase migration timeout
standard before database execution:

```bash
./tools/validation/validate_foundation_migration_timeouts.sh
```

## Active Gate: Phase 4 Step 7

```bash
./tools/validation/phase-gates/validate_phase4_step7.sh
```

The gate validates 34 migrations, 21 sequential tests, 16 concurrency tests,
the accepted Step 6 behavior, deterministic request-chain serialization,
Authority Grant revocation exclusion, seven new concurrency files, the
734 PASS target, and observation-only resource telemetry.
