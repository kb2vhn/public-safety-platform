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
```

Historical gates validate their own checkpoint trees and are not expected to
accept later-phase files. Step 6 validates the accepted implementation. Step 7
validates the formal Phase 3 acceptance record and proves that its SQL and
test tree remains identical to the annotated acceptance tag.
