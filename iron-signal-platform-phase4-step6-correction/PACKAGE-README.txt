Iron Signal Platform Phase 4 Step 6 correction
================================================

This correction addresses the runtime failure observed after the Step 6
static gate passed.

Corrections
-----------
1. Test 210 used uppercase 'PUBLIC' as the first argument to PostgreSQL
   privilege inquiry functions. PostgreSQL attempted to resolve it as an
   ordinary role and stopped with:

       ERROR: role "PUBLIC" does not exist

   The six checks now use lowercase 'public', matching the established
   Foundation security tests.

2. The renamed Iron Signal Platform test infrastructure still created
   disposable databases beginning with:

       psp_foundation_test_

   It now uses:

       issp_foundation_test_

   Temporary psp-* test files are also renamed to issp-*.

Files changed
-------------
test-framework/sql/tests/foundation/210_approval_stage_satisfaction_and_finalization.sql
test-framework/sql/schema/scripts/test_foundation.sh
test-framework/sql/schema/scripts/test_foundation_with_resources.sh

The Step 6 migration, documentation, assertion count, concurrency inventory,
timeout contract, and resource-observation model are unchanged.
