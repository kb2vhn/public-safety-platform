-- ============================================================================
-- Migration: 070_postgresql_authentication_assertion_gate.sql
-- Title: PostgreSQL Authentication Assertion Gate
-- Layer: Platform Foundation
-- Status: REVIEW CANDIDATE
-- Target: PostgreSQL 18
-- ============================================================================
--
-- Purpose:
--   Store externally issued Authentication Assertions received from configured trust providers and provide a database-side,
--   single-use consumption function.
--
-- Security boundaries:
--   - A Authentication Assertion is an input to authorization, not authorization itself.
--   - Assertions are audience-bound, environment-bound, time-bound, and
--     single-use.
--   - PostgreSQL time is authoritative for assertion expiration.
--   - The function uses the access_control schema, not the former
--     authorization schema name.
--   - PUBLIC may not execute the consumption function.
--
-- Important:
--   Signature verification is not implemented in this migration. A later
--   trust-provider-specific authentication verification component must validate the signed assertion
--   before inserting it with status RECEIVED.
--
-- Dependencies:
--   - 065_authorization_leases.sql
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '10min';
SET LOCAL idle_in_transaction_session_timeout = '10min';

SELECT pg_advisory_xact_lock(
    hashtext(current_database()),
    hashtext('platform-foundation-migrations')
);

-- ============================================================================
-- Dependency validation
-- ============================================================================

DO $dependency_check$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM foundation_meta.applied_migrations
        WHERE migration_id = '065_authorization_leases'
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'object_not_in_prerequisite_state',
                MESSAGE = 'Required migration 065_authorization_leases is not registered';
    END IF;
END;
$dependency_check$;

-- ============================================================================
-- Authentication Assertions
-- ============================================================================

CREATE TABLE access_control.authentication_assertions (
    authentication_assertion_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    assertion_id text NOT NULL UNIQUE,

    trust_provider_id uuid NOT NULL
        REFERENCES trust.trust_providers (
            trust_provider_id
        ),

    identity_id uuid NOT NULL
        REFERENCES identity.identities (
            identity_id
        ),

    device_id uuid
        REFERENCES trust.devices (
            device_id
        ),

    session_id uuid
        REFERENCES access_control.sessions (
            session_id
        ),

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

    CONSTRAINT authentication_assertions_assertion_id_ck
        CHECK (
            btrim(assertion_id) <> ''
        ),

    CONSTRAINT authentication_assertions_audience_ck
        CHECK (
            btrim(audience) <> ''
        ),

    CONSTRAINT authentication_assertions_environment_key_ck
        CHECK (
            environment_key ~ '^[a-z][a-z0-9_-]*$'
        ),

    CONSTRAINT authentication_assertions_signature_algorithm_ck
        CHECK (
            btrim(signature_algorithm) <> ''
        ),

    CONSTRAINT authentication_assertions_validity_ck
        CHECK (
            expires_at > issued_at
        ),

    CONSTRAINT authentication_assertions_status_ck
        CHECK (
            status IN (
                'RECEIVED',
                'CONSUMED',
                'REJECTED',
                'EXPIRED',
                'REVOKED'
            )
        ),

    CONSTRAINT authentication_assertions_consumption_state_ck
        CHECK (
            (
                status = 'CONSUMED'
                AND consumed_at IS NOT NULL
            )
            OR
            (
                status <> 'CONSUMED'
                AND consumed_at IS NULL
            )
        ),

    CONSTRAINT authentication_assertions_received_after_issue_ck
        CHECK (
            received_at >= issued_at
        )
);

COMMENT ON TABLE access_control.authentication_assertions IS
    'Externally issued, audience-bound, environment-bound, time-bound Authentication Assertions received from configured trust providers. Assertions do not grant authority by themselves.';

COMMENT ON COLUMN access_control.authentication_assertions.nonce_hash IS
    'Digest of the source authentication assertion nonce used to prevent replay.';

COMMENT ON COLUMN access_control.authentication_assertions.payload_hash IS
    'Digest of the canonical signed assertion payload.';

COMMENT ON COLUMN access_control.authentication_assertions.signature_value IS
    'Signature bytes supplied with the Authentication Assertion and retained for controlled verification and authorized audit review.';

CREATE UNIQUE INDEX authentication_assertions_nonce_hash_uq
    ON access_control.authentication_assertions (
        nonce_hash
    );

CREATE INDEX authentication_assertions_status_expiry_idx
    ON access_control.authentication_assertions (
        status,
        expires_at
    );

CREATE INDEX authentication_assertions_identity_received_idx
    ON access_control.authentication_assertions (
        identity_id,
        received_at DESC
    );

CREATE INDEX authentication_assertions_session_idx
    ON access_control.authentication_assertions (
        session_id
    )
    WHERE session_id IS NOT NULL;

-- ============================================================================
-- Single-use Authentication Assertion consumption
-- ============================================================================

CREATE FUNCTION access_control.consume_authentication_assertion(
    p_assertion_id text
)
RETURNS uuid
LANGUAGE plpgsql
STRICT
SET search_path = pg_catalog, access_control
AS $function$
DECLARE
    v_authentication_assertion_id uuid;
BEGIN
    UPDATE access_control.authentication_assertions
       SET status = 'CONSUMED',
           consumed_at = pg_catalog.clock_timestamp()
     WHERE assertion_id = p_assertion_id
       AND status = 'RECEIVED'
       AND issued_at <= pg_catalog.clock_timestamp()
       AND pg_catalog.clock_timestamp() < expires_at
     RETURNING authentication_assertion_id
          INTO v_authentication_assertion_id;

    IF v_authentication_assertion_id IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_authorization_specification',
                MESSAGE = 'Authentication Assertion is unavailable',
                DETAIL = 'The assertion was not found, is not in RECEIVED state, is not yet valid, has expired, or was already consumed.',
                HINT = 'Obtain and verify a new Authentication Assertion.';
    END IF;

    RETURN v_authentication_assertion_id;
END;
$function$;

COMMENT ON FUNCTION access_control.consume_authentication_assertion(text) IS
    'Atomically consumes one currently valid Authentication Assertion and returns its identifier. PostgreSQL time is authoritative.';

REVOKE ALL
ON FUNCTION access_control.consume_authentication_assertion(text)
FROM PUBLIC;

-- ============================================================================
-- Register migration
-- ============================================================================

SELECT foundation_meta.register_migration(
    p_migration_id       => '070_postgresql_authentication_assertion_gate',
    p_migration_name     => 'PostgreSQL authentication assertion gate',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created Authentication Assertions, replay protections, lifecycle constraints, supporting indexes, and a single-use database consumption function using the access_control schema.'
);

COMMIT;

