-- ============================================================================
-- Migration: 080_decision_record_repository.sql
-- Title: Decision Record Repository
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
        WHERE migration_id = '075_controlled_authorization_api'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
                  MESSAGE = 'Required migration 075_controlled_authorization_api is not registered';
    END IF;
END;
$dependency_check$;


CREATE TABLE decision.decision_records (
    decision_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_decision_id uuid REFERENCES decision.decision_records(decision_id),
    correlation_id uuid NOT NULL,
    requested_operation text NOT NULL,
    target_reference text NOT NULL,
    final_result text NOT NULL,
    identity_id uuid REFERENCES identity.identities(identity_id),
    device_id uuid REFERENCES trust.devices(device_id),
    session_id uuid REFERENCES authorization.sessions(session_id),
    authorization_lease_id uuid REFERENCES authorization.authorization_leases(authorization_lease_id),
    service_id uuid REFERENCES service.platform_services(service_id),
    organization_id uuid REFERENCES organization.organizations(organization_id),
    requested_at timestamptz NOT NULL,
    decided_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    engine_name text NOT NULL,
    engine_version text NOT NULL,
    database_schema_version text NOT NULL,
    context_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
    record_hash bytea,
    previous_record_hash bytea,
    CONSTRAINT decision_result_ck CHECK (final_result IN ('ALLOW','DENY','PENDING','ESCALATED'))
);

CREATE TABLE decision.evaluation_records (
    evaluation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    decision_id uuid NOT NULL REFERENCES decision.decision_records(decision_id),
    parent_evaluation_id uuid REFERENCES decision.evaluation_records(evaluation_id),
    evaluation_order integer NOT NULL,
    evaluation_key text NOT NULL,
    required boolean NOT NULL,
    result text NOT NULL,
    reason_code text NOT NULL,
    explanation text,
    evaluated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    duration_microseconds bigint,
    supporting_context jsonb NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT evaluation_result_ck CHECK (result IN ('PASS','FAIL','NOT_REQUIRED','NOT_EVALUATED')),
    UNIQUE(decision_id,evaluation_order)
);

CREATE TABLE decision.supporting_records (
    supporting_record_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    evaluation_id uuid NOT NULL REFERENCES decision.evaluation_records(evaluation_id),
    record_type text NOT NULL,
    record_id text NOT NULL,
    record_version text,
    record_hash bytea,
    effective_from timestamptz,
    effective_until timestamptz
);
CREATE INDEX evaluations_decision_idx ON decision.evaluation_records(decision_id,evaluation_order);

SELECT foundation_meta.register_migration(
    p_migration_id       => '080_decision_record_repository',
    p_migration_name     => 'Decision Record Repository',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created decision record repository objects.'
);

COMMIT;
