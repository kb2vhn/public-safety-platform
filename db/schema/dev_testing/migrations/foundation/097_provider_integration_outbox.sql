-- ============================================================================
-- Migration: 097_provider_integration_outbox.sql
-- Title: Provider integration outbox
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
        WHERE migration_id = '096_monitoring_subscriptions_and_provider_delivery_state'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
                  MESSAGE = 'Required migration 096_monitoring_subscriptions_and_provider_delivery_state is not registered';
    END IF;
END;
$dependency_check$;


CREATE TABLE integration.provider_contracts (
    provider_contract_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    contract_key text NOT NULL UNIQUE,
    provider_name text NOT NULL,
    adapter_name text NOT NULL,
    adapter_version text NOT NULL,
    source_of_truth_role text NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE',
    valid_from timestamptz NOT NULL,
    valid_until timestamptz
);

CREATE TABLE integration.outbox_events (
    outbox_event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_contract_id uuid NOT NULL REFERENCES integration.provider_contracts(provider_contract_id),
    event_type text NOT NULL,
    aggregate_type text NOT NULL,
    aggregate_id text NOT NULL,
    payload jsonb NOT NULL,
    classification_reference text,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    available_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    status text NOT NULL DEFAULT 'PENDING',
    attempt_count integer NOT NULL DEFAULT 0,
    next_attempt_at timestamptz,
    last_error text
);
CREATE INDEX outbox_pending_idx ON integration.outbox_events(status,available_at,next_attempt_at);

SELECT foundation_meta.register_migration(
    p_migration_id       => '097_provider_integration_outbox',
    p_migration_name     => 'Provider integration outbox',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created provider integration outbox objects.'
);

COMMIT;
