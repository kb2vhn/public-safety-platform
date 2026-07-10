-- ============================================================================
-- Migration: 087_common_control_catalog.sql
-- Title: Common control catalog
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
        WHERE migration_id = '086_governed_documents_and_policy_versions'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
                  MESSAGE = 'Required migration 086_governed_documents_and_policy_versions is not registered';
    END IF;
END;
$dependency_check$;


CREATE TABLE compliance.control_families (
    control_family_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    family_key text NOT NULL UNIQUE,
    title text NOT NULL,
    description text NOT NULL
);

CREATE TABLE compliance.common_controls (
    common_control_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    control_family_id uuid NOT NULL REFERENCES compliance.control_families(control_family_id),
    control_key text NOT NULL UNIQUE,
    title text NOT NULL,
    objective text NOT NULL,
    control_type text NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE'
);

CREATE TABLE compliance.common_control_versions (
    common_control_version_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    common_control_id uuid NOT NULL REFERENCES compliance.common_controls(common_control_id),
    version_number integer NOT NULL,
    requirement_statement text NOT NULL,
    evidence_requirements text,
    assessment_procedure text,
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    content_hash bytea,
    UNIQUE(common_control_id,version_number)
);

CREATE TABLE compliance.control_relationships (
    control_relationship_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_common_control_id uuid NOT NULL REFERENCES compliance.common_controls(common_control_id),
    target_common_control_id uuid NOT NULL REFERENCES compliance.common_controls(common_control_id),
    relationship_type text NOT NULL,
    CONSTRAINT control_relationship_no_self_ck CHECK (source_common_control_id<>target_common_control_id)
);

SELECT foundation_meta.register_migration(
    p_migration_id       => '087_common_control_catalog',
    p_migration_name     => 'Common control catalog',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created common control catalog objects.'
);

COMMIT;
