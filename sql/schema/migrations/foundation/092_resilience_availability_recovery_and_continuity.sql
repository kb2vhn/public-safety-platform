-- ============================================================================
-- Migration: 092_resilience_availability_recovery_and_continuity.sql
-- Title: Resilience availability recovery and continuity
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
        WHERE migration_id = '091_threat_records_and_abuse_case_mappings'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
                  MESSAGE = 'Required migration 091_threat_records_and_abuse_case_mappings is not registered';
    END IF;
END;
$dependency_check$;


CREATE TABLE resilience.service_criticality_profiles (
    service_criticality_profile_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    service_id uuid NOT NULL REFERENCES service.platform_services(service_id),
    criticality text NOT NULL,
    maximum_tolerable_outage interval NOT NULL,
    recovery_time_objective interval NOT NULL,
    recovery_point_objective interval NOT NULL,
    minimum_operating_mode text NOT NULL,
    owner_reference text NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_until timestamptz
);

CREATE TABLE resilience.degraded_operating_modes (
    degraded_operating_mode_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    service_id uuid NOT NULL REFERENCES service.platform_services(service_id),
    mode_key text NOT NULL,
    permitted_operations text[] NOT NULL DEFAULT ARRAY[]::text[],
    prohibited_operations text[] NOT NULL DEFAULT ARRAY[]::text[],
    activation_conditions text NOT NULL,
    exit_conditions text NOT NULL,
    UNIQUE(service_id,mode_key)
);

CREATE TABLE resilience.recovery_events (
    recovery_event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    service_id uuid NOT NULL REFERENCES service.platform_services(service_id),
    event_type text NOT NULL,
    started_at timestamptz NOT NULL,
    completed_at timestamptz,
    initiated_by_reference text NOT NULL,
    status text NOT NULL,
    validation_summary text,
    decision_id uuid REFERENCES decision.decision_records(decision_id)
);

CREATE TABLE resilience.backup_records (
    backup_record_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    service_id uuid REFERENCES service.platform_services(service_id),
    backup_type text NOT NULL,
    created_at timestamptz NOT NULL,
    recovery_point_at timestamptz NOT NULL,
    storage_reference text NOT NULL,
    integrity_hash bytea,
    encryption_reference text,
    validation_state text NOT NULL DEFAULT 'UNVALIDATED'
);

SELECT foundation_meta.register_migration(
    p_migration_id       => '092_resilience_availability_recovery_and_continuity',
    p_migration_name     => 'Resilience availability recovery and continuity',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created resilience availability recovery and continuity objects.'
);

COMMIT;
