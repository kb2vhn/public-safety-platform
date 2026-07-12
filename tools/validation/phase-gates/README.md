
# Phase Gates

> **Owner:** Iron Signal Systems

This directory contains reproducible acceptance gates for completed and active
Foundation phases.

```text
validate_phase2_step3.sh
validate_phase2_step4.sh
validate_phase2_step5.sh
validate_phase2_step6.sh
validate_phase3_step1.sh
validate_phase3_step2.sh
validate_phase3_step3.sh
validate_phase3_step4.sh
validate_phase3_step5.sh
validate_phase3_step6.sh
validate_phase3_step7.sh
validate_phase4_step1.sh
validate_phase4_step2.sh
validate_phase4_step3.sh
```

Historical gates validate their own checkpoint trees and are not expected to
accept later-phase documentation.

- Step 6 validates the accepted Phase 3 implementation.
- Step 7 validates the formal Phase 3 acceptance record.
- Phase 4 Step 1 validates the frozen approval-independence and
  separation-of-duties contract.
- Phase 4 Step 2 validates migration `083`, structural test `170`, the
  unchanged nine-test concurrency boundary, and observation-only resource
  telemetry without applying a performance threshold.

Run the newest gate for the current repository state.
