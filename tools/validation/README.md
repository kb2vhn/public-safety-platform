# Validation Tools

> **Owner:** Iron Signal Systems

Phase gates are retained under `tools/validation/phase-gates/`.

Active Phase 4 Step 5 gate:

```bash
./tools/validation/phase-gates/validate_phase4_step5.sh
```

Static repository and documentation validation only:

```bash
./tools/validation/phase-gates/validate_phase4_step5.sh --static-only
```

The gate verifies the accepted Step 4 baseline, migration `083`, tests `170`
through `200`, authoritative manifests, exact Step 5 delegation, incompatible-
authority, and duty-conflict reason codes, 50 new assertions, synchronized
status documentation, correctness totals, and the resource-observation contract.

Historical gates remain available for their own checkpoint trees.


## Cross-Phase Foundation Migration Timeout Contract

Validate every migration listed in the authoritative Foundation manifest:

```bash
./tools/validation/validate_foundation_migration_timeouts.sh
```

The validator enforces one transaction-local header in each migration:

```sql
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '1min';
SET LOCAL idle_in_transaction_session_timeout = '1min';
```

It is a static repository-policy check and contributes no SQL PASS rows. The
active Phase 4 Step 5 gate invokes it automatically before database execution;
it remains independently runnable for focused migration review.
