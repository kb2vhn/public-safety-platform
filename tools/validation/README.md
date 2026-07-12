# Validation Tools

> **Owner:** Iron Signal Systems

Phase gates are retained under `tools/validation/phase-gates/` so executable
validation scripts do not clutter the repository root.

Active Phase 4 Step 2 gate:

```bash
./tools/validation/phase-gates/validate_phase4_step2.sh
```

Phase 4 Step 1 contract checkpoint:

```bash
./tools/validation/phase-gates/validate_phase4_step1.sh
```

Formal Phase 3 acceptance checkpoint:

```bash
./tools/validation/phase-gates/validate_phase3_step7.sh
```

The Step 2 gate validates the accepted Phase 3 boundary, frozen Phase 4
contract, migration `083`, structural test `170`, authoritative manifests,
resource-aware wrapper, synchronized documentation, correctness totals, and
resource JSON contract.

The gate runs the resource-aware wrapper by default. `--static-only` skips
PostgreSQL and resource execution but retains repository, hash, manifest,
syntax, and documentation checks.
