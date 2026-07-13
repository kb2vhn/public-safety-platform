-- ============================================================================
-- Migration: 088_compliance_profiles_and_requirement_mappings.sql
-- Title: Compliance profiles and requirement mappings
-- Layer: Platform Foundation
-- Status: INITIAL REVIEW CANDIDATE
-- Target: PostgreSQL 18
-- Compatibility policy: prefer mature features supported before PostgreSQL 18.
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '1min';
SET LOCAL idle_in_transaction_session_timeout = '1min';

SELECT pg_advisory_xact_lock(
    hashtext(current_database()),
    hashtext('platform-foundation-migrations')
);

DO $dependency_check$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM foundation_meta.applied_migrations
        WHERE migration_id = '087_common_control_catalog'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
                  MESSAGE = 'Required migration 087_common_control_catalog is not registered';
    END IF;
END;
$dependency_check$;


CREATE TABLE compliance.compliance_profiles (
    compliance_profile_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_key text NOT NULL UNIQUE,
    title text NOT NULL,
    issuing_authority text NOT NULL,
    source_framework text NOT NULL
);

CREATE TABLE compliance.compliance_profile_versions (
    compliance_profile_version_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    compliance_profile_id uuid NOT NULL REFERENCES compliance.compliance_profiles(compliance_profile_id),
    source_version text NOT NULL,
    internal_version integer NOT NULL,
    status text NOT NULL DEFAULT 'DRAFT',
    approved_at timestamptz,
    effective_from timestamptz,
    effective_until timestamptz,
    content_hash bytea NOT NULL,
    UNIQUE(compliance_profile_id,internal_version)
);

CREATE TABLE compliance.profile_requirements (
    profile_requirement_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    compliance_profile_version_id uuid NOT NULL REFERENCES compliance.compliance_profile_versions(compliance_profile_version_id),
    external_requirement_key text NOT NULL,
    requirement_text text NOT NULL,
    source_clause text,
    UNIQUE(compliance_profile_version_id,external_requirement_key)
);

CREATE TABLE compliance.requirement_control_mappings (
    requirement_control_mapping_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_requirement_id uuid NOT NULL REFERENCES compliance.profile_requirements(profile_requirement_id),
    common_control_version_id uuid NOT NULL REFERENCES compliance.common_control_versions(common_control_version_id),
    mapping_type text NOT NULL DEFAULT 'SATISFIES',
    rationale text
);

SELECT foundation_meta.register_migration(
    p_migration_id       => '088_compliance_profiles_and_requirement_mappings',
    p_migration_name     => 'Compliance profiles and requirement mappings',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created compliance profiles and requirement mappings objects.'
);

COMMIT;
