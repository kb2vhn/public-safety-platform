# Validation Tools

> **Owner:** Iron Signal Systems

Phase gates are retained under `tools/validation/phase-gates/`.

Active Phase 4 Step 4 gate:

```bash
./tools/validation/phase-gates/validate_phase4_step4.sh
```

Static repository and documentation validation only:

```bash
./tools/validation/phase-gates/validate_phase4_step4.sh --static-only
```

The gate verifies the accepted Step 3 baseline, migration `083`, tests `170`,
`180`, and `190`, authoritative manifests, exact Step 4 reason codes, 40 new
assertions, synchronized status documentation, correctness totals, and the
resource-observation contract.

Historical gates remain available for their own checkpoint trees.
