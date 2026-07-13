# Validation Tools

> **Owner:** Iron Signal Systems

Phase gates are retained under `tools/validation/phase-gates/`.

## Active Phase 4 Step 7 Gate

Complete validation:

```bash
./tools/validation/phase-gates/validate_phase4_step7.sh
```

Static repository and documentation validation only:

```bash
./tools/validation/phase-gates/validate_phase4_step7.sh --static-only
```

The gate verifies the accepted Step 6 boundary, migration `083`, 21 sequential
tests, 16 concurrency tests, seven new approval-race files, 84 new assertions,
request-chain serialization, Authority Grant revocation exclusion,
synchronized documentation, correctness totals, and the resource-observation
contract.

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
active Phase 4 Step 7 gate invokes it automatically before database execution.
