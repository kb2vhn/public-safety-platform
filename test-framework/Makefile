.PHONY: test-sql test-sql-keep test-sql-drop-failed

test-sql:
	./sql/schema/scripts/test_foundation.sh

test-sql-keep:
	KEEP_TEST_DB=1 ./sql/schema/scripts/test_foundation.sh

test-sql-drop-failed:
	DROP_TEST_DB_ON_FAILURE=1 ./sql/schema/scripts/test_foundation.sh
