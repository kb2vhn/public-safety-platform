-- ============================================================================
-- Migration: 084_lifecycle_and_historical_lineage.sql
-- Title: Lifecycle and historical lineage
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
        WHERE migration_id = '082_data_classification_and_governance'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
                  MESSAGE = 'Required migration 082_data_classification_and_governance is not registered';
    END IF;
END;
$dependency_check$;


CREATE TABLE governance.object_versions (
    object_version_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    object_type text NOT NULL,
    stable_object_id uuid NOT NULL,
    version_number integer NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    recorded_by_identity_id uuid REFERENCES identity.identities(identity_id),
    content_hash bytea,
    decision_id uuid REFERENCES decision.decision_records(decision_id),
    UNIQUE(object_type,stable_object_id,version_number)
);

CREATE TABLE governance.object_version_relationships (
    object_version_relationship_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_object_version_id uuid NOT NULL REFERENCES governance.object_versions(object_version_id),
    target_object_version_id uuid NOT NULL REFERENCES governance.object_versions(object_version_id),
    relationship_type text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT object_version_relationship_no_self_ck CHECK (source_object_version_id<>target_object_version_id)
);

CREATE TABLE governance.lifecycle_events (
    lifecycle_event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    object_type text NOT NULL,
    stable_object_id uuid NOT NULL,
    event_type text NOT NULL,
    valid_at timestamptz NOT NULL,
    recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    previous_state text,
    new_state text NOT NULL,
    reason text,
    decision_id uuid REFERENCES decision.decision_records(decision_id)
);

SELECT foundation_meta.register_migration(
    p_migration_id       => '084_lifecycle_and_historical_lineage',
    p_migration_name     => 'Lifecycle and historical lineage',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created lifecycle and historical lineage objects.'
);

COMMIT;
