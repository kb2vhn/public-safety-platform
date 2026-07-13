-- ============================================================================
-- Migration: 087_common_control_catalog.sql
-- Title: Common Control Catalog
-- Layer: Platform Foundation
-- Status: REVIEW CANDIDATE
-- Target: PostgreSQL 18
-- ============================================================================
--
-- Purpose:
--   Define a framework-neutral common control catalog and versioned control
--   requirements, including the assurance artifacts expected to support later
--   implementation and assessment activities.
--
-- Terminology boundary:
--   "Assurance artifact" refers to a document, log extract, configuration
--   snapshot, test result, attestation, scan result, or similar record used to
--   support control review. It does not refer to legal or investigative
--   evidence.
--
-- Dependencies:
--   - 086_governed_documents_and_policy_versions.sql
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
        WHERE migration_id = '086_governed_documents_and_policy_versions'
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'object_not_in_prerequisite_state',
                MESSAGE = 'Required migration 086_governed_documents_and_policy_versions is not registered';
    END IF;
END;
$dependency_check$;

CREATE TABLE compliance.control_families (
    control_family_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    family_key text NOT NULL UNIQUE,
    title text NOT NULL,
    description text NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE',
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_by_reference text NOT NULL,

    CONSTRAINT control_families_key_ck
        CHECK (family_key ~ '^[A-Z][A-Z0-9_]*$'),

    CONSTRAINT control_families_title_ck
        CHECK (btrim(title) <> ''),

    CONSTRAINT control_families_description_ck
        CHECK (btrim(description) <> ''),

    CONSTRAINT control_families_status_ck
        CHECK (status IN ('ACTIVE', 'SUSPENDED', 'RETIRED'))
);

COMMENT ON TABLE compliance.control_families IS
    'Framework-neutral groupings of related common controls.';

CREATE TABLE compliance.common_controls (
    common_control_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    control_family_id uuid NOT NULL
        REFERENCES compliance.control_families(control_family_id),
    control_key text NOT NULL UNIQUE,
    title text NOT NULL,
    objective text NOT NULL,
    control_type text NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE',
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_by_reference text NOT NULL,

    CONSTRAINT common_controls_key_ck
        CHECK (control_key ~ '^[A-Z][A-Z0-9_.-]*$'),

    CONSTRAINT common_controls_title_ck
        CHECK (btrim(title) <> ''),

    CONSTRAINT common_controls_objective_ck
        CHECK (btrim(objective) <> ''),

    CONSTRAINT common_controls_type_ck
        CHECK (control_type ~ '^[A-Z][A-Z0-9_]*$'),

    CONSTRAINT common_controls_status_ck
        CHECK (status IN ('ACTIVE', 'SUSPENDED', 'RETIRED'))
);

COMMENT ON TABLE compliance.common_controls IS
    'Stable framework-neutral control identities.';

CREATE INDEX common_controls_family_status_idx
    ON compliance.common_controls(control_family_id, status);

CREATE TABLE compliance.common_control_versions (
    common_control_version_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    common_control_id uuid NOT NULL
        REFERENCES compliance.common_controls(common_control_id),
    version_number integer NOT NULL,
    requirement_statement text NOT NULL,
    assurance_artifact_requirements text,
    assessment_procedure text,
    status text NOT NULL DEFAULT 'DRAFT',
    approved_at timestamptz,
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    content_hash bytea,
    supersedes_common_control_version_id uuid
        REFERENCES compliance.common_control_versions(common_control_version_id),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_by_reference text NOT NULL,

    CONSTRAINT common_control_versions_number_ck
        CHECK (version_number > 0),

    CONSTRAINT common_control_versions_requirement_ck
        CHECK (btrim(requirement_statement) <> ''),

    CONSTRAINT common_control_versions_status_ck
        CHECK (status IN ('DRAFT', 'APPROVED', 'ACTIVE', 'SUPERSEDED', 'RETIRED')),

    CONSTRAINT common_control_versions_validity_ck
        CHECK (valid_until IS NULL OR valid_until > valid_from),

    CONSTRAINT common_control_versions_approval_ck
        CHECK (
            status = 'DRAFT'
            OR approved_at IS NOT NULL
        ),

    CONSTRAINT common_control_versions_no_self_supersession_ck
        CHECK (
            supersedes_common_control_version_id IS NULL
            OR supersedes_common_control_version_id <> common_control_version_id
        ),

    UNIQUE(common_control_id, version_number)
);

COMMENT ON TABLE compliance.common_control_versions IS
    'Versioned common-control requirements and expected assurance artifacts.';

COMMENT ON COLUMN compliance.common_control_versions.assurance_artifact_requirements IS
    'Description of the assurance artifacts expected to support implementation or assessment. This is not legal evidence.';

CREATE INDEX common_control_versions_control_status_idx
    ON compliance.common_control_versions(common_control_id, status, valid_from, valid_until);

CREATE TABLE compliance.control_relationships (
    control_relationship_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_common_control_id uuid NOT NULL
        REFERENCES compliance.common_controls(common_control_id),
    target_common_control_id uuid NOT NULL
        REFERENCES compliance.common_controls(common_control_id),
    relationship_type text NOT NULL,
    rationale text,
    status text NOT NULL DEFAULT 'ACTIVE',
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_by_reference text NOT NULL,

    CONSTRAINT control_relationship_no_self_ck
        CHECK (source_common_control_id <> target_common_control_id),

    CONSTRAINT control_relationship_type_ck
        CHECK (
            relationship_type IN (
                'SUPPORTS',
                'DEPENDS_ON',
                'OVERLAPS',
                'ENHANCES',
                'ALTERNATIVE_TO'
            )
        ),

    CONSTRAINT control_relationship_status_ck
        CHECK (status IN ('ACTIVE', 'SUSPENDED', 'RETIRED')),

    UNIQUE(source_common_control_id, target_common_control_id, relationship_type)
);

COMMENT ON TABLE compliance.control_relationships IS
    'Explicit relationships between common controls.';

SELECT foundation_meta.register_migration(
    p_migration_id       => '087_common_control_catalog',
    p_migration_name     => 'Common control catalog',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created the versioned common control catalog and assurance artifact requirement terminology.'
);

COMMIT;

