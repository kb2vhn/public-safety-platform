# Validation Tools

> **Owner:** Iron Signal Systems

Phase gates are retained under `tools/validation/phase-gates/` so
executable validation scripts do not clutter the repository root.

Run a gate from the repository root.

Formal Phase 3 acceptance record:

```bash
./tools/validation/phase-gates/validate_phase3_step7.sh
```

Accepted Phase 3 implementation gate:

```bash
./tools/validation/phase-gates/validate_phase3_step6.sh
```

Each current gate performs a complete dependency preflight, validates
its accepted boundaries, and runs the complete Foundation suite unless
`--static-only` is explicitly supplied. Historical gates remain for
reproducibility.
