-- ============================================================================
-- Migration: 089_control_implementations_and_assurance_artifacts.sql
-- Title: Control Implementations and Assurance Artifacts
-- Layer: Platform Foundation
-- Status: REVIEW CANDIDATE
-- Target: PostgreSQL 18
-- ============================================================================
--
-- Purpose:
--   Define versioned control implementations, immutable assurance-artifact
--   records, append-only artifact validation records, implementation-to-
--   artifact relationships, control assessments, and assessment-to-artifact
--   relationships.
--
-- Terminology boundary:
--   An assurance artifact is a record used to support control implementation,
--   validation, assessment, audit, or compliance review. Examples include
--   configuration snapshots, log extracts, test results, scan outputs,
--   attestations, reports, and query results.
--
--   Assurance artifacts are not legal or investigative evidence. A future
--   legal-evidence module will use separate schemas, tables, access controls,
--   chain-of-custody records, retention rules, and terminology.
--
-- Design principles:
--   - Control implementations are versioned and effective-dated.
--   - Assurance-artifact metadata is immutable after insertion.
--   - Artifact validation is recorded as append-only validation records.
--   - Artifact bytes remain in controlled storage rather than core tables.
--   - Every artifact has a SHA-256 integrity value.
--   - One assurance artifact may support multiple implementations or
--     assessments.
--   - Collection or validation does not establish control effectiveness or
--     system compliance by itself.
--
-- Dependencies:
--   - 088_compliance_profiles_and_requirement_mappings.sql
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
        WHERE migration_id = '088_compliance_profiles_and_requirement_mappings'
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'object_not_in_prerequisite_state',
                MESSAGE = 'Required migration 088_compliance_profiles_and_requirement_mappings is not registered';
    END IF;
END;
$dependency_check$;

-- ============================================================================
-- Versioned control implementations
-- ============================================================================

CREATE TABLE compliance.control_implementations (
    control_implementation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    implementation_key text NOT NULL,
    version_number integer NOT NULL,

    common_control_version_id uuid NOT NULL
        REFERENCES compliance.common_control_versions(common_control_version_id),

    scope_type text NOT NULL,

    organization_id uuid
        REFERENCES organization.organizations(organization_id),

    service_id uuid
        REFERENCES service.platform_services(service_id),

    deployment_id uuid
        REFERENCES service.deployments(deployment_id),

    participation_agreement_id uuid
        REFERENCES service.participation_agreements(participation_agreement_id),

    scope_detail text,
    implementation_description text NOT NULL,
    implementation_state text NOT NULL DEFAULT 'PLANNED',
    responsible_owner_reference text NOT NULL,
    operating_procedure_reference text,

    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    review_at timestamptz,

    supersedes_control_implementation_id uuid
        REFERENCES compliance.control_implementations(control_implementation_id),

    decision_id uuid
        REFERENCES decision.decision_records(decision_id),

    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_by_reference text NOT NULL,

    CONSTRAINT control_implementations_key_ck
        CHECK (implementation_key ~ '^[a-z][a-z0-9_.-]*$'),

    CONSTRAINT control_implementations_version_ck
        CHECK (version_number > 0),

    CONSTRAINT control_implementations_scope_type_ck
        CHECK (
            scope_type IN (
                'PLATFORM',
                'ORGANIZATION',
                'SERVICE',
                'DEPLOYMENT',
                'SERVICE_PARTICIPATION'
            )
        ),

    CONSTRAINT control_implementations_scope_target_ck
        CHECK (
            (
                scope_type = 'PLATFORM'
                AND num_nonnulls(
                    organization_id,
                    service_id,
                    deployment_id,
                    participation_agreement_id
                ) = 0
            )
            OR
            (
                scope_type = 'ORGANIZATION'
                AND organization_id IS NOT NULL
                AND num_nonnulls(
                    service_id,
                    deployment_id,
                    participation_agreement_id
                ) = 0
            )
            OR
            (
                scope_type = 'SERVICE'
                AND service_id IS NOT NULL
                AND num_nonnulls(
                    organization_id,
                    deployment_id,
                    participation_agreement_id
                ) = 0
            )
            OR
            (
                scope_type = 'DEPLOYMENT'
                AND deployment_id IS NOT NULL
                AND num_nonnulls(
                    organization_id,
                    service_id,
                    participation_agreement_id
                ) = 0
            )
            OR
            (
                scope_type = 'SERVICE_PARTICIPATION'
                AND participation_agreement_id IS NOT NULL
                AND num_nonnulls(
                    organization_id,
                    service_id,
                    deployment_id
                ) = 0
            )
        ),

    CONSTRAINT control_implementations_description_ck
        CHECK (btrim(implementation_description) <> ''),

    CONSTRAINT control_implementations_state_ck
        CHECK (
            implementation_state IN (
                'PLANNED',
                'PARTIALLY_IMPLEMENTED',
                'IMPLEMENTED',
                'OPERATING',
                'SUSPENDED',
                'RETIRED'
            )
        ),

    CONSTRAINT control_implementations_owner_ck
        CHECK (btrim(responsible_owner_reference) <> ''),

    CONSTRAINT control_implementations_validity_ck
        CHECK (valid_until IS NULL OR valid_until > valid_from),

    CONSTRAINT control_implementations_review_ck
        CHECK (review_at IS NULL OR review_at >= valid_from),

    CONSTRAINT control_implementations_no_self_supersession_ck
        CHECK (
            supersedes_control_implementation_id IS NULL
            OR supersedes_control_implementation_id <> control_implementation_id
        ),

    UNIQUE(implementation_key, version_number)
);

COMMENT ON TABLE compliance.control_implementations IS
    'Versioned, effective-dated implementations of common controls at a platform, organization, service, deployment, or participation scope.';

CREATE INDEX control_implementations_control_scope_idx
    ON compliance.control_implementations(
        common_control_version_id,
        scope_type,
        implementation_state,
        valid_from,
        valid_until
    );

CREATE INDEX control_implementations_organization_idx
    ON compliance.control_implementations(organization_id)
    WHERE organization_id IS NOT NULL;

CREATE INDEX control_implementations_service_idx
    ON compliance.control_implementations(service_id)
    WHERE service_id IS NOT NULL;

CREATE INDEX control_implementations_deployment_idx
    ON compliance.control_implementations(deployment_id)
    WHERE deployment_id IS NOT NULL;

CREATE INDEX control_implementations_participation_idx
    ON compliance.control_implementations(participation_agreement_id)
    WHERE participation_agreement_id IS NOT NULL;

-- ============================================================================
-- Immutable assurance-artifact records
-- ============================================================================

CREATE TABLE compliance.control_assurance_artifacts (
    control_assurance_artifact_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    artifact_key text NOT NULL UNIQUE,
    artifact_type text NOT NULL,

    source_system_reference text,
    source_record_reference text,
    storage_reference text NOT NULL,

    collected_at timestamptz NOT NULL,
    applicable_from timestamptz,
    applicable_until timestamptz,

    sha256_hash bytea NOT NULL,
    media_type text,
    size_bytes bigint,

    classification_reference text,
    retention_reference text,

    supersedes_control_assurance_artifact_id uuid
        REFERENCES compliance.control_assurance_artifacts(control_assurance_artifact_id),

    decision_id uuid
        REFERENCES decision.decision_records(decision_id),

    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_by_reference text NOT NULL,

    CONSTRAINT control_assurance_artifacts_key_ck
        CHECK (artifact_key ~ '^[a-zA-Z0-9][a-zA-Z0-9_.:-]*$'),

    CONSTRAINT control_assurance_artifacts_type_ck
        CHECK (
            artifact_type IN (
                'ATTESTATION',
                'CONFIGURATION_SNAPSHOT',
                'DOCUMENT',
                'LOG_EXTRACT',
                'QUERY_RESULT',
                'REPORT',
                'SCAN_RESULT',
                'SCREENSHOT',
                'TEST_RESULT',
                'OTHER'
            )
        ),

    CONSTRAINT control_assurance_artifacts_storage_ck
        CHECK (btrim(storage_reference) <> ''),

    CONSTRAINT control_assurance_artifacts_applicability_ck
        CHECK (
            applicable_until IS NULL
            OR (
                applicable_from IS NOT NULL
                AND applicable_until > applicable_from
            )
        ),

    CONSTRAINT control_assurance_artifacts_sha256_ck
        CHECK (octet_length(sha256_hash) = 32),

    CONSTRAINT control_assurance_artifacts_size_ck
        CHECK (size_bytes IS NULL OR size_bytes >= 0),

    CONSTRAINT control_assurance_artifacts_created_by_ck
        CHECK (btrim(created_by_reference) <> ''),

    CONSTRAINT control_assurance_artifacts_no_self_supersession_ck
        CHECK (
            supersedes_control_assurance_artifact_id IS NULL
            OR supersedes_control_assurance_artifact_id <> control_assurance_artifact_id
        )
);

COMMENT ON TABLE compliance.control_assurance_artifacts IS
    'Immutable metadata and storage references for artifacts used in control implementation, validation, assessment, audit, or compliance assurance. These are not legal evidence records.';

COMMENT ON COLUMN compliance.control_assurance_artifacts.storage_reference IS
    'Reference to controlled storage. Artifact bytes are not embedded in this table.';

COMMENT ON COLUMN compliance.control_assurance_artifacts.sha256_hash IS
    'SHA-256 digest of the collected artifact bytes for integrity verification.';

CREATE INDEX control_assurance_artifacts_type_collected_idx
    ON compliance.control_assurance_artifacts(
        artifact_type,
        collected_at DESC
    );

CREATE INDEX control_assurance_artifacts_applicability_idx
    ON compliance.control_assurance_artifacts(
        applicable_from,
        applicable_until
    );

CREATE INDEX control_assurance_artifacts_supersedes_idx
    ON compliance.control_assurance_artifacts(
        supersedes_control_assurance_artifact_id
    )
    WHERE supersedes_control_assurance_artifact_id IS NOT NULL;

-- ============================================================================
-- Append-only assurance-artifact validations
-- ============================================================================

CREATE TABLE compliance.control_assurance_artifact_validations (
    control_assurance_artifact_validation_id uuid
        PRIMARY KEY DEFAULT gen_random_uuid(),

    control_assurance_artifact_id uuid NOT NULL
        REFERENCES compliance.control_assurance_artifacts(control_assurance_artifact_id),

    validation_result text NOT NULL,
    validation_method text NOT NULL,
    validated_at timestamptz NOT NULL,
    validated_by_reference text NOT NULL,
    validation_notes text,

    supersedes_validation_id uuid
        REFERENCES compliance.control_assurance_artifact_validations(
            control_assurance_artifact_validation_id
        ),

    decision_id uuid
        REFERENCES decision.decision_records(decision_id),

    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),

    CONSTRAINT control_assurance_artifact_validations_result_ck
        CHECK (validation_result IN ('VALID', 'INVALID', 'STALE')),

    CONSTRAINT control_assurance_artifact_validations_method_ck
        CHECK (btrim(validation_method) <> ''),

    CONSTRAINT control_assurance_artifact_validations_validator_ck
        CHECK (btrim(validated_by_reference) <> ''),

    CONSTRAINT control_assurance_artifact_validations_no_self_supersession_ck
        CHECK (
            supersedes_validation_id IS NULL
            OR supersedes_validation_id
                <> control_assurance_artifact_validation_id
        )
);

COMMENT ON TABLE compliance.control_assurance_artifact_validations IS
    'Append-only validation results for assurance artifacts. Artifact validity does not establish control effectiveness or compliance.';

CREATE INDEX control_assurance_artifact_validations_artifact_time_idx
    ON compliance.control_assurance_artifact_validations(
        control_assurance_artifact_id,
        validated_at DESC,
        created_at DESC
    );

CREATE INDEX control_assurance_artifact_validations_result_idx
    ON compliance.control_assurance_artifact_validations(
        validation_result,
        validated_at DESC
    );

CREATE VIEW compliance.current_control_assurance_artifact_validations AS
SELECT DISTINCT ON (validation.control_assurance_artifact_id)
    validation.control_assurance_artifact_validation_id,
    validation.control_assurance_artifact_id,
    validation.validation_result,
    validation.validation_method,
    validation.validated_at,
    validation.validated_by_reference,
    validation.validation_notes,
    validation.supersedes_validation_id,
    validation.decision_id,
    validation.created_at
FROM compliance.control_assurance_artifact_validations AS validation
ORDER BY
    validation.control_assurance_artifact_id,
    validation.validated_at DESC,
    validation.created_at DESC,
    validation.control_assurance_artifact_validation_id DESC;

COMMENT ON VIEW compliance.current_control_assurance_artifact_validations IS
    'Most recently recorded validation result for each assurance artifact. Historical validation rows remain unchanged.';

-- ============================================================================
-- Implementation-to-artifact relationships
-- ============================================================================

CREATE TABLE compliance.control_implementation_assurance_artifacts (
    control_implementation_id uuid NOT NULL
        REFERENCES compliance.control_implementations(control_implementation_id),

    control_assurance_artifact_id uuid NOT NULL
        REFERENCES compliance.control_assurance_artifacts(control_assurance_artifact_id),

    relationship_type text NOT NULL DEFAULT 'SUPPORTS',
    required_for_assessment boolean NOT NULL DEFAULT false,
    applicability_notes text,
    linked_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    linked_by_reference text NOT NULL,

    CONSTRAINT control_implementation_artifacts_type_ck
        CHECK (
            relationship_type IN (
                'SUPPORTS',
                'DEMONSTRATES',
                'TESTS',
                'EXPLAINS',
                'CORROBORATES'
            )
        ),

    CONSTRAINT control_implementation_artifacts_linked_by_ck
        CHECK (btrim(linked_by_reference) <> ''),

    PRIMARY KEY(
        control_implementation_id,
        control_assurance_artifact_id,
        relationship_type
    )
);

COMMENT ON TABLE compliance.control_implementation_assurance_artifacts IS
    'Many-to-many relationships between versioned control implementations and assurance artifacts.';

CREATE INDEX control_implementation_artifacts_artifact_idx
    ON compliance.control_implementation_assurance_artifacts(
        control_assurance_artifact_id,
        control_implementation_id
    );

-- ============================================================================
-- Append-only control assessments
-- ============================================================================

CREATE TABLE compliance.control_assessments (
    control_assessment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    assessment_key text NOT NULL UNIQUE,

    control_implementation_id uuid NOT NULL
        REFERENCES compliance.control_implementations(control_implementation_id),

    assessor_reference text NOT NULL,
    assessment_procedure_version text NOT NULL,
    assessment_scope text,
    assessed_at timestamptz NOT NULL,
    result text NOT NULL,
    confidence_level text,
    assessment_summary text,
    next_review_at timestamptz,

    decision_id uuid
        REFERENCES decision.decision_records(decision_id),

    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_by_reference text NOT NULL,

    CONSTRAINT control_assessments_key_ck
        CHECK (assessment_key ~ '^[a-zA-Z0-9][a-zA-Z0-9_.:-]*$'),

    CONSTRAINT control_assessments_assessor_ck
        CHECK (btrim(assessor_reference) <> ''),

    CONSTRAINT control_assessments_procedure_ck
        CHECK (btrim(assessment_procedure_version) <> ''),

    CONSTRAINT control_assessments_result_ck
        CHECK (
            result IN (
                'EFFECTIVE',
                'PARTIALLY_EFFECTIVE',
                'INEFFECTIVE',
                'NOT_ASSESSED'
            )
        ),

    CONSTRAINT control_assessments_confidence_ck
        CHECK (
            confidence_level IS NULL
            OR confidence_level IN ('LOW', 'MODERATE', 'HIGH')
        ),

    CONSTRAINT control_assessments_next_review_ck
        CHECK (next_review_at IS NULL OR next_review_at > assessed_at),

    CONSTRAINT control_assessments_created_by_ck
        CHECK (btrim(created_by_reference) <> '')
);

COMMENT ON TABLE compliance.control_assessments IS
    'Append-only assessment results for a specific versioned control implementation.';

CREATE INDEX control_assessments_implementation_time_idx
    ON compliance.control_assessments(
        control_implementation_id,
        assessed_at DESC
    );

CREATE INDEX control_assessments_result_review_idx
    ON compliance.control_assessments(
        result,
        next_review_at
    );

-- ============================================================================
-- Assessment-to-artifact relationships
-- ============================================================================

CREATE TABLE compliance.assessment_assurance_artifacts (
    control_assessment_id uuid NOT NULL
        REFERENCES compliance.control_assessments(control_assessment_id),

    control_assurance_artifact_id uuid NOT NULL
        REFERENCES compliance.control_assurance_artifacts(control_assurance_artifact_id),

    usage_type text NOT NULL DEFAULT 'SUPPORTING',
    assessor_notes text,
    linked_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    linked_by_reference text NOT NULL,

    CONSTRAINT assessment_assurance_artifacts_usage_ck
        CHECK (
            usage_type IN (
                'INPUT',
                'SUPPORTING',
                'CONTRADICTING',
                'OUTPUT'
            )
        ),

    CONSTRAINT assessment_assurance_artifacts_linked_by_ck
        CHECK (btrim(linked_by_reference) <> ''),

    PRIMARY KEY(
        control_assessment_id,
        control_assurance_artifact_id,
        usage_type
    )
);

COMMENT ON TABLE compliance.assessment_assurance_artifacts IS
    'Many-to-many relationships between control assessments and assurance artifacts.';

CREATE INDEX assessment_assurance_artifacts_artifact_idx
    ON compliance.assessment_assurance_artifacts(
        control_assurance_artifact_id,
        control_assessment_id
    );

SELECT foundation_meta.register_migration(
    p_migration_id       => '089_control_implementations_and_assurance_artifacts',
    p_migration_name     => 'Control implementations and assurance artifacts',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created versioned control implementations, immutable assurance artifacts, append-only artifact validations, many-to-many artifact relationships, and append-only control assessments.'
);

COMMIT;

