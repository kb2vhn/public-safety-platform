-- ============================================================================
-- Migration: 065_authorization_leases.sql
-- Title: Authorization leases
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
        WHERE migration_id = '060_sessions'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
                  MESSAGE = 'Required migration 060_sessions is not registered';
    END IF;
END;
$dependency_check$;


CREATE TABLE access_control.authorization_leases (
    authorization_lease_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    lease_secret_hash bytea NOT NULL,
    session_id uuid NOT NULL REFERENCES access_control.sessions(session_id),
    identity_id uuid NOT NULL REFERENCES identity.identities(identity_id),
    device_id uuid REFERENCES trust.devices(device_id),
    service_id uuid REFERENCES service.platform_services(service_id),
    purpose_definition_id uuid REFERENCES access_control.purpose_definitions(purpose_definition_id),
    scope_reference text NOT NULL,
    issued_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    expires_at timestamptz NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE',
    revoked_at timestamptz,
    revocation_reason text,
    correlation_id uuid NOT NULL,
    CONSTRAINT authorization_leases_validity_ck CHECK (expires_at > issued_at)
);
CREATE UNIQUE INDEX authorization_leases_secret_hash_uq ON access_control.authorization_leases(lease_secret_hash);
CREATE INDEX authorization_leases_active_idx ON access_control.authorization_leases(identity_id,service_id,status,expires_at);

CREATE TABLE access_control.lease_authority_grants (
    authorization_lease_id uuid NOT NULL REFERENCES access_control.authorization_leases(authorization_lease_id),
    authority_grant_id uuid NOT NULL REFERENCES access_control.authority_grants(authority_grant_id),
    PRIMARY KEY(authorization_lease_id,authority_grant_id)
);

SELECT foundation_meta.register_migration(
    p_migration_id       => '065_authorization_leases',
    p_migration_name     => 'Authorization leases',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created authorization leases objects.'
);

COMMIT;
