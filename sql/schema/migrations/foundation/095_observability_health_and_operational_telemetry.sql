-- ============================================================================
-- Migration: 095_observability_health_and_operational_telemetry.sql
-- Title: Observability health and operational telemetry
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
        WHERE migration_id = '094_client_and_deployment_performance_profiles'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
                  MESSAGE = 'Required migration 094_client_and_deployment_performance_profiles is not registered';
    END IF;
END;
$dependency_check$;


CREATE TABLE observability.components (
    component_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    service_id uuid REFERENCES service.platform_services(service_id),
    deployment_id uuid REFERENCES service.deployments(deployment_id),
    component_key text NOT NULL,
    component_type text NOT NULL,
    application_version text,
    owner_reference text NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE',
    UNIQUE(deployment_id,component_key)
);

CREATE TABLE observability.health_events (
    health_event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    component_id uuid NOT NULL REFERENCES observability.components(component_id),
    workload_definition_id uuid REFERENCES performance.workload_definitions(workload_definition_id),
    event_type text NOT NULL,
    severity text NOT NULL,
    status text NOT NULL,
    first_observed_at timestamptz NOT NULL,
    last_observed_at timestamptz NOT NULL,
    resource_name text,
    current_value numeric,
    threshold_value numeric,
    unit text,
    query_fingerprint text,
    correlation_id uuid,
    user_impact text,
    recommended_action text,
    owner_reference text NOT NULL
);

CREATE TABLE observability.metric_samples (
    metric_sample_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    component_id uuid NOT NULL REFERENCES observability.components(component_id),
    metric_key text NOT NULL,
    sampled_at timestamptz NOT NULL,
    metric_value double precision NOT NULL,
    labels jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX metric_samples_component_time_idx ON observability.metric_samples(component_id,sampled_at);

SELECT foundation_meta.register_migration(
    p_migration_id       => '095_observability_health_and_operational_telemetry',
    p_migration_name     => 'Observability health and operational telemetry',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created observability health and operational telemetry objects.'
);

COMMIT;
