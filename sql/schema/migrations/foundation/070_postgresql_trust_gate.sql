-- ============================================================================
-- Migration: 070_postgresql_trust_gate.sql
-- Title: PostgreSQL trust gate
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
        WHERE migration_id = '065_authorization_leases'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
                  MESSAGE = 'Required migration 065_authorization_leases is not registered';
    END IF;
END;
$dependency_check$;


CREATE TABLE access_control.trust_assertions (
    trust_assertion_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    assertion_id text NOT NULL UNIQUE,
    trust_provider_id uuid NOT NULL REFERENCES trust.trust_providers(trust_provider_id),
    identity_id uuid NOT NULL REFERENCES identity.identities(identity_id),
    device_id uuid REFERENCES trust.devices(device_id),
    session_id uuid REFERENCES access_control.sessions(session_id),
    audience text NOT NULL,
    environment_key text NOT NULL,
    issued_at timestamptz NOT NULL,
    expires_at timestamptz NOT NULL,
    nonce_hash bytea NOT NULL,
    payload_hash bytea NOT NULL,
    signature_algorithm text NOT NULL,
    signature_value bytea NOT NULL,
    received_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    consumed_at timestamptz,
    status text NOT NULL DEFAULT 'RECEIVED',
    CONSTRAINT trust_assertions_validity_ck CHECK (expires_at > issued_at)
);
CREATE UNIQUE INDEX trust_assertions_nonce_uq ON access_control.trust_assertions(nonce_hash);
CREATE INDEX trust_assertions_status_expiry_idx ON access_control.trust_assertions(status,expires_at);

CREATE FUNCTION access_control.assert_trust_assertion_available(p_assertion_id text)
RETURNS uuid
LANGUAGE plpgsql
SET search_path = pg_catalog, authorization
AS $$
DECLARE
    v_id uuid;
BEGIN
    UPDATE access_control.trust_assertions
       SET status='CONSUMED', consumed_at=clock_timestamp()
     WHERE assertion_id=p_assertion_id
       AND status='RECEIVED'
       AND issued_at <= clock_timestamp()
       AND clock_timestamp() < expires_at
     RETURNING trust_assertion_id INTO v_id;

    IF v_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE='invalid_authorization_specification',
            MESSAGE='Trust Assertion is unavailable, expired, or already consumed';
    END IF;
    RETURN v_id;
END;
$$;

SELECT foundation_meta.register_migration(
    p_migration_id       => '070_postgresql_trust_gate',
    p_migration_name     => 'PostgreSQL trust gate',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created postgresql trust gate objects.'
);

COMMIT;
