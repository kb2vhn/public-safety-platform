-- ============================================================================
-- Migration: 060_sessions.sql
-- Title: Sessions
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
        WHERE migration_id = '055_authority_purpose_and_authorization_policy'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
                  MESSAGE = 'Required migration 055_authority_purpose_and_authorization_policy is not registered';
    END IF;
END;
$dependency_check$;


CREATE TABLE access_control.sessions (
    session_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    identity_id uuid NOT NULL REFERENCES identity.identities(identity_id),
    device_id uuid REFERENCES trust.devices(device_id),
    trust_provider_id uuid REFERENCES trust.trust_providers(trust_provider_id),
    service_id uuid REFERENCES service.platform_services(service_id),
    status text NOT NULL DEFAULT 'ACTIVE',
    authenticated_at timestamptz NOT NULL,
    expires_at timestamptz NOT NULL,
    last_activity_at timestamptz,
    revoked_at timestamptz,
    correlation_id uuid NOT NULL DEFAULT gen_random_uuid(),
    CONSTRAINT sessions_validity_ck CHECK (expires_at > authenticated_at)
);
CREATE INDEX sessions_identity_active_idx ON access_control.sessions(identity_id,status,expires_at);

SELECT foundation_meta.register_migration(
    p_migration_id       => '060_sessions',
    p_migration_name     => 'Sessions',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created sessions objects.'
);

COMMIT;
