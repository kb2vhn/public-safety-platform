-- ============================================================================
-- Migration: 070_postgresql_authentication_assertion_gate.sql
-- Title: PostgreSQL Authentication Assertion Gate
-- Layer: Platform Foundation
-- Status: REVIEW CANDIDATE
-- Target: PostgreSQL 18
-- ============================================================================

-- Purpose:
-- Store externally issued Authentication Assertions received from configured
-- Trust Providers, record controlled verification, and provide exact-context,
-- single-use consumption.

-- Security boundaries:
-- - An Authentication Assertion is an authentication input, not authorization.
-- - RECEIVED assertions are not consumable.
-- - Only VERIFIED assertions are consumable.
-- - Assertions are purpose-bound, identity-bound, context-bound, time-bound,
--   and single-use.
-- - PostgreSQL time is authoritative for validity checks.
-- - Function execution is revoked from PUBLIC.

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
            USING
                ERRCODE = 'object_not_in_prerequisite_state',
                MESSAGE = 'Required migration 065_authorization_leases is not registered';
    END IF;
END;
$dependency_check$;

CREATE TABLE access_control.authentication_assertions (
    authentication_assertion_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    assertion_id text NOT NULL UNIQUE,
    assertion_purpose text NOT NULL,
    trust_provider_id uuid NOT NULL
        REFERENCES trust.trust_providers(trust_provider_id),
    identity_id uuid NOT NULL
        REFERENCES identity.identities(identity_id),
    device_id uuid
        REFERENCES trust.devices(device_id),
    session_id uuid
        REFERENCES access_control.sessions(session_id),
    service_id uuid
        REFERENCES service.platform_services(service_id),
    audience text NOT NULL,
    environment_key text NOT NULL,
    issued_at timestamptz NOT NULL,
    expires_at timestamptz NOT NULL,
    nonce_hash bytea NOT NULL,
    payload_hash bytea NOT NULL,
    signature_algorithm text NOT NULL,
    signature_value bytea NOT NULL,
    received_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    verified_at timestamptz,
    verified_by_reference text,
    verification_method text,
    consumed_at timestamptz,
    status text NOT NULL DEFAULT 'RECEIVED',
    CONSTRAINT authentication_assertions_assertion_id_ck
        CHECK (btrim(assertion_id) <> ''),
    CONSTRAINT authentication_assertions_purpose_ck
        CHECK (
            assertion_purpose IN (
                'SESSION_ESTABLISHMENT',
                'SESSION_STEP_UP'
            )
        ),
    CONSTRAINT authentication_assertions_session_purpose_ck
        CHECK (
            (
                assertion_purpose = 'SESSION_ESTABLISHMENT'
                AND session_id IS NULL
            )
            OR
            (
                assertion_purpose = 'SESSION_STEP_UP'
                AND session_id IS NOT NULL
            )
        ),
    CONSTRAINT authentication_assertions_audience_ck
        CHECK (btrim(audience) <> ''),
    CONSTRAINT authentication_assertions_environment_key_ck
        CHECK (environment_key ~ '^[a-z][a-z0-9_-]*$'),
    CONSTRAINT authentication_assertions_signature_algorithm_ck
        CHECK (btrim(signature_algorithm) <> ''),
    CONSTRAINT authentication_assertions_validity_ck
        CHECK (expires_at > issued_at),
    CONSTRAINT authentication_assertions_received_after_issue_ck
        CHECK (received_at >= issued_at),
    CONSTRAINT authentication_assertions_status_ck
        CHECK (
            status IN (
                'RECEIVED',
                'VERIFIED',
                'CONSUMED',
                'REJECTED',
                'EXPIRED',
                'REVOKED'
            )
        ),
    CONSTRAINT authentication_assertions_verification_state_ck
        CHECK (
            (
                status IN ('VERIFIED', 'CONSUMED')
                AND verified_at IS NOT NULL
                AND NULLIF(btrim(verified_by_reference), '') IS NOT NULL
                AND NULLIF(btrim(verification_method), '') IS NOT NULL
            )
            OR
            (
                status IN ('RECEIVED', 'REJECTED', 'EXPIRED', 'REVOKED')
                AND verified_at IS NULL
                AND verified_by_reference IS NULL
                AND verification_method IS NULL
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
    CONSTRAINT authentication_assertions_verified_chronology_ck
        CHECK (
            verified_at IS NULL
            OR (
                verified_at >= received_at
                AND verified_at < expires_at
            )
        ),
    CONSTRAINT authentication_assertions_consumed_chronology_ck
        CHECK (
            consumed_at IS NULL
            OR (
                verified_at IS NOT NULL
                AND consumed_at >= verified_at
                AND consumed_at < expires_at
            )
        )
);

COMMENT ON TABLE access_control.authentication_assertions IS
    'Externally issued authentication claims received from configured Trust Providers. Assertions do not grant authority by themselves.';

CREATE UNIQUE INDEX authentication_assertions_nonce_hash_uq
    ON access_control.authentication_assertions(nonce_hash);

CREATE INDEX authentication_assertions_status_expiry_idx
    ON access_control.authentication_assertions(status, expires_at);

CREATE INDEX authentication_assertions_identity_received_idx
    ON access_control.authentication_assertions(
        identity_id,
        received_at DESC
    );

CREATE INDEX authentication_assertions_session_idx
    ON access_control.authentication_assertions(session_id)
    WHERE session_id IS NOT NULL;

CREATE FUNCTION access_control.mark_authentication_assertion_verified(
    p_authentication_assertion_id uuid,
    p_verified_by_reference text,
    p_verification_method text
)
RETURNS boolean
LANGUAGE plpgsql
STRICT
SET search_path = pg_catalog, access_control
AS $function$
DECLARE
    v_evaluated_at timestamptz := pg_catalog.statement_timestamp();
BEGIN
    IF pg_catalog.btrim(p_verified_by_reference) = '' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Verifier reference must not be empty';
    END IF;

    IF pg_catalog.btrim(p_verification_method) = '' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Verification method must not be empty';
    END IF;

    UPDATE access_control.authentication_assertions
    SET
        status = 'VERIFIED',
        verified_at = v_evaluated_at,
        verified_by_reference = pg_catalog.btrim(p_verified_by_reference),
        verification_method = pg_catalog.btrim(p_verification_method)
    WHERE authentication_assertion_id = p_authentication_assertion_id
      AND status = 'RECEIVED'
      AND issued_at <= v_evaluated_at
      AND v_evaluated_at < expires_at;

    RETURN FOUND;
END;
$function$;

COMMENT ON FUNCTION access_control.mark_authentication_assertion_verified(uuid, text, text) IS
    'Performs the controlled lifecycle transition from RECEIVED to VERIFIED after Trust-Provider-specific cryptographic and claim validation has completed.';

REVOKE ALL
ON FUNCTION access_control.mark_authentication_assertion_verified(uuid, text, text)
FROM PUBLIC;

CREATE FUNCTION access_control.consume_authentication_assertion(
    p_assertion_id text,
    p_assertion_purpose text,
    p_trust_provider_id uuid,
    p_identity_id uuid,
    p_device_id uuid,
    p_session_id uuid,
    p_service_id uuid,
    p_audience text,
    p_environment_key text
)
RETURNS uuid
LANGUAGE plpgsql
SET search_path = pg_catalog, access_control
AS $function$
DECLARE
    v_evaluated_at timestamptz := pg_catalog.statement_timestamp();
    v_authentication_assertion_id uuid;
BEGIN
    UPDATE access_control.authentication_assertions
    SET
        status = 'CONSUMED',
        consumed_at = v_evaluated_at
    WHERE assertion_id = p_assertion_id
      AND assertion_purpose = p_assertion_purpose
      AND trust_provider_id = p_trust_provider_id
      AND identity_id = p_identity_id
      AND device_id IS NOT DISTINCT FROM p_device_id
      AND session_id IS NOT DISTINCT FROM p_session_id
      AND service_id IS NOT DISTINCT FROM p_service_id
      AND audience = p_audience
      AND environment_key = p_environment_key
      AND status = 'VERIFIED'
      AND issued_at <= v_evaluated_at
      AND v_evaluated_at < expires_at
    RETURNING authentication_assertion_id
    INTO v_authentication_assertion_id;

    IF v_authentication_assertion_id IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_authorization_specification',
                MESSAGE = 'Authentication Assertion is unavailable',
                DETAIL = 'The supplied assertion did not satisfy the required verified, context, time, or single-use conditions.',
                HINT = 'Obtain and verify a new Authentication Assertion for the exact request context.';
    END IF;

    RETURN v_authentication_assertion_id;
END;
$function$;

COMMENT ON FUNCTION access_control.consume_authentication_assertion(
    text,
    text,
    uuid,
    uuid,
    uuid,
    uuid,
    uuid,
    text,
    text
) IS
    'Atomically consumes one VERIFIED Authentication Assertion only when all supplied context matches exactly. PostgreSQL statement time is authoritative.';

REVOKE ALL
ON FUNCTION access_control.consume_authentication_assertion(
    text,
    text,
    uuid,
    uuid,
    uuid,
    uuid,
    uuid,
    text,
    text
)
FROM PUBLIC;

SELECT foundation_meta.register_migration(
    p_migration_id => '070_postgresql_authentication_assertion_gate',
    p_migration_name => 'PostgreSQL authentication assertion gate',
    p_migration_layer => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes => 'Created purpose-bound Authentication Assertions, controlled verification, exact-context matching, authoritative-time checks, and atomic single-use consumption.'
);

COMMIT;
