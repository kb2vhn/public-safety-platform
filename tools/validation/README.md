# Validation Tools

> **Owner:** Iron Signal Systems

Phase gates are retained under `tools/validation/phase-gates/`.

## Phase 4 Formal-Acceptance Gate

Complete validation:

```bash
./tools/validation/phase-gates/validate_phase4_step8.sh
```

Static repository, tag, implementation-tree, and documentation validation:

```bash
./tools/validation/phase-gates/validate_phase4_step8.sh --static-only
```

The gate verifies the annotated Phase 4 tag, the accepted implementation
commit, unchanged SQL and executable test trees, 34 migrations, 21 sequential
tests, 16 concurrency tests, 734 PASS, zero failed assertions, three understood
warnings, synchronized acceptance documentation, and the resource-observation
contract.

Historical gates remain available for their own checkpoint trees. The Step 7
gate is the implementation gate for the tagged Phase 4 tree.

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
Phase 4 formal-acceptance gate invokes it automatically before database
execution.

## Phase 5 Step 1 Gate

Run the production database role and ownership contract gate:

```bash
./tools/validation/phase-gates/validate_phase5_step1.sh
```

Static repository and contract validation only:

```bash
./tools/validation/phase-gates/validate_phase5_step1.sh --static-only
```

The complete gate re-runs the formally accepted Phase 4 gate and confirms that
Step 1 did not alter the accepted Foundation SQL or executable test tree.

## Foundation Repository/Database Parity

The accepted Phase 4 review script remains frozen under `sql/schema`.
Repository/database migration parity is checked separately with:

```bash
./tools/validation/validate_foundation_database_parity.sh dev_testing
```

## Phase 5 Step 2 Gate

Run the complete deployment-role topology gate:

```bash
./tools/validation/phase-gates/validate_phase5_step2.sh
```

Run static validation only:

```bash
./tools/validation/phase-gates/validate_phase5_step2.sh --static-only
```
