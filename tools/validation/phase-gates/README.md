# Phase Gates

> **Owner:** Iron Signal Systems

This directory contains reproducible acceptance gates for completed and active
Foundation phases. Historical gates validate their own checkpoint trees.

Newest gate:

```text
validate_phase4_step4.sh
```

Phase 4 progression:

- Step 1 froze the approval-independence and separation-of-duties contract.
- Step 2 added migration `083`, structural test `170`, and resource telemetry.
- Step 3 added controlled Approval Action recording and test `180`; it is
  accepted at 500 PASS, 0 FAIL, and 3 understood WARN.
- Step 4 adds independence enforcement and test `190`; its candidate target is
  540 PASS, 0 FAIL, and 3 understood WARN.

Run the newest gate for the current repository state.
