
# Validation Tools

> **Owner:** Iron Signal Systems

Phase gates are retained under `tools/validation/phase-gates/` so executable
validation scripts do not clutter the repository root.

Run a gate from the repository root.

Active Phase 4 contract gate:

```bash
./tools/validation/phase-gates/validate_phase4_step1.sh
```

Formal Phase 3 acceptance checkpoint:

```bash
./tools/validation/phase-gates/validate_phase3_step7.sh
```

Accepted Phase 3 implementation checkpoint:

```bash
./tools/validation/phase-gates/validate_phase3_step6.sh
```

The Phase 4 Step 1 gate verifies that the current branch descends from the
accepted Phase 3 tag, that SQL and SQL tests remain identical to the accepted
tree, and that the Phase 4 contract is complete and internally consistent.

Current gates perform a complete dependency preflight and run the complete
Foundation suite unless `--static-only` is explicitly supplied. Historical
gates remain for checkpoint reproducibility and are not expected to accept
later documentation trees.
