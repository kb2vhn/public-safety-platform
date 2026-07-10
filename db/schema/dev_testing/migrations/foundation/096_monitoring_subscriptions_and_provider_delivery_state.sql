-- ============================================================================
-- Migration: 096_monitoring_subscriptions_and_provider_delivery_state.sql
-- Title: Monitoring subscriptions and provider delivery state
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
        WHERE migration_id = '095_observability_health_and_operational_telemetry'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
                  MESSAGE = 'Required migration 095_observability_health_and_operational_telemetry is not registered';
    END IF;
END;
$dependency_check$;


CREATE TABLE observability.monitoring_subscriptions (
    monitoring_subscription_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_key text NOT NULL UNIQUE,
    provider_type text NOT NULL,
    provider_reference text NOT NULL,
    event_filter jsonb NOT NULL DEFAULT '{}'::jsonb,
    status text NOT NULL DEFAULT 'ACTIVE',
    max_retry_count integer NOT NULL DEFAULT 5,
    max_queue_depth integer NOT NULL DEFAULT 10000,
    created_by_reference text NOT NULL
);

CREATE TABLE observability.monitoring_delivery_state (
    monitoring_delivery_state_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    monitoring_subscription_id uuid NOT NULL REFERENCES observability.monitoring_subscriptions(monitoring_subscription_id),
    health_event_id uuid REFERENCES observability.health_events(health_event_id),
    metric_sample_id bigint REFERENCES observability.metric_samples(metric_sample_id),
    delivery_status text NOT NULL DEFAULT 'PENDING',
    attempt_count integer NOT NULL DEFAULT 0,
    next_attempt_at timestamptz,
    last_error text,
    delivered_at timestamptz,
    CONSTRAINT monitoring_delivery_one_payload_ck CHECK (num_nonnulls(health_event_id,metric_sample_id)=1)
);
CREATE INDEX monitoring_delivery_pending_idx ON observability.monitoring_delivery_state(delivery_status,next_attempt_at);

SELECT foundation_meta.register_migration(
    p_migration_id       => '096_monitoring_subscriptions_and_provider_delivery_state',
    p_migration_name     => 'Monitoring subscriptions and provider delivery state',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created monitoring subscriptions and provider delivery state objects.'
);

COMMIT;
