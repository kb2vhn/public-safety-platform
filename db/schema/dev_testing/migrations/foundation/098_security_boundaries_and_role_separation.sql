-- ============================================================================
-- Migration: 098_security_boundaries_and_role_separation.sql
-- Title: Security boundaries and role separation
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
        WHERE migration_id = '097_provider_integration_outbox'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
                  MESSAGE = 'Required migration 097_provider_integration_outbox is not registered';
    END IF;
END;
$dependency_check$;


CREATE TABLE foundation_meta.database_role_classes (
    database_role_class_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    role_class_key text NOT NULL UNIQUE,
    title text NOT NULL,
    description text NOT NULL,
    login_allowed boolean NOT NULL,
    ownership_allowed boolean NOT NULL,
    operational_use_allowed boolean NOT NULL
);

CREATE TABLE foundation_meta.incompatible_database_role_classes (
    incompatible_database_role_class_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    first_role_class_id uuid NOT NULL REFERENCES foundation_meta.database_role_classes(database_role_class_id),
    second_role_class_id uuid NOT NULL REFERENCES foundation_meta.database_role_classes(database_role_class_id),
    reason text NOT NULL,
    CONSTRAINT incompatible_role_classes_no_self_ck CHECK (first_role_class_id<>second_role_class_id)
);

REVOKE ALL ON ALL TABLES IN SCHEMA foundation_meta,trust,identity,organization,service,attestation,approval,authorization,decision,governance,compliance,risk,resilience,performance,observability,integration FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA foundation_meta,trust,identity,organization,service,attestation,approval,authorization,decision,governance,compliance,risk,resilience,performance,observability,integration FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA foundation_meta,trust,identity,organization,service,attestation,approval,authorization,decision,governance,compliance,risk,resilience,performance,observability,integration FROM PUBLIC;

ALTER DEFAULT PRIVILEGES REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES REVOKE ALL ON SEQUENCES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES REVOKE ALL ON FUNCTIONS FROM PUBLIC;

SELECT foundation_meta.register_migration(
    p_migration_id       => '098_security_boundaries_and_role_separation',
    p_migration_name     => 'Security boundaries and role separation',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created security boundaries and role separation objects.'
);

COMMIT;
