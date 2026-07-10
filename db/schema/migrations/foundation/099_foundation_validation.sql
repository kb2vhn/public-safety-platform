-- ============================================================================
-- Migration: 099_foundation_validation.sql
-- Title: Foundation validation
-- Layer: Platform Foundation
-- Status: INITIAL REVIEW CANDIDATE
-- Target: PostgreSQL 18
-- Compatibility policy: prefer mature features supported before PostgreSQL 18.
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '10min';
SET LOCAL idle_in_transaction_session_timeout = '10min';

SELECT pg_advisory_xact_lock(
    hashtext(current_database()),
    hashtext('platform-foundation-migrations')
);

DO $dependency_check$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM foundation_meta.applied_migrations
        WHERE migration_id = '098_security_boundaries_and_role_separation'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
                  MESSAGE = 'Required migration 098_security_boundaries_and_role_separation is not registered';
    END IF;
END;
$dependency_check$;


CREATE VIEW security_validation.security_definer_functions AS
SELECT
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_userbyid(p.proowner) AS owner_name,
    p.proconfig
FROM pg_proc p
JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE p.prosecdef
  AND n.nspname IN ('foundation_meta','trust','identity','organization','service','attestation','approval','authorization','decision','governance','compliance','risk','resilience','performance','observability','integration');

CREATE VIEW security_validation.public_schema_privileges AS
SELECT
    n.nspname AS schema_name,
    has_schema_privilege('public', n.oid, 'USAGE') AS public_usage,
    has_schema_privilege('public', n.oid, 'CREATE') AS public_create
FROM pg_namespace n
WHERE n.nspname IN ('foundation_meta','trust','identity','organization','service','attestation','approval','authorization','decision','governance','compliance','risk','resilience','performance','observability','integration','security_validation');

CREATE VIEW security_validation.foundation_table_counts AS
SELECT schemaname, count(*)::bigint AS table_count
FROM pg_tables
WHERE schemaname IN ('foundation_meta','trust','identity','organization','service','attestation','approval','authorization','decision','governance','compliance','risk','resilience','performance','observability','integration')
GROUP BY schemaname;

CREATE VIEW security_validation.migration_summary AS
SELECT migration_id,migration_name,migration_layer,applied_at,applied_by,server_version_num
FROM foundation_meta.applied_migrations
ORDER BY migration_id;

SELECT foundation_meta.register_migration(
    p_migration_id       => '099_foundation_validation',
    p_migration_name     => 'Foundation validation',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created foundation validation objects.'
);

COMMIT;
