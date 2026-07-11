-- ============================================================================
-- Migration: 075_controlled_authorization_api.sql
-- Title: Controlled Authorization API
-- Layer: Platform Foundation
-- Status: REVIEW CANDIDATE
-- Target: PostgreSQL 18
-- Compatibility policy:
--   Prefer mature PostgreSQL features supported before PostgreSQL 18.
-- ============================================================================
--
-- Purpose:
--   Provide controlled database functions for hashing Authorization Lease
--   secrets, verifying active leases, and revoking leases.
--
-- Security boundaries:
--   - The pgcrypto digest function is schema-qualified as extensions.digest().
--   - The public schema is not added to any trusted function search path.
--   - Lease plaintext secrets are never stored.
--   - A lease must be ACTIVE and unexpired according to PostgreSQL time.
--   - Function execution is revoked from PUBLIC.
--
-- Dependencies:
--   - 000_platform_initialization.sql
--   - 065_authorization_leases.sql
--   - 070_postgresql_authentication_assertion_gate.sql
--   - pgcrypto installed in the extensions schema
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
DECLARE
    v_pgcrypto_schema name;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM foundation_meta.applied_migrations
        WHERE migration_id = '070_postgresql_authentication_assertion_gate'
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'object_not_in_prerequisite_state',
                MESSAGE = 'Required migration 070_postgresql_authentication_assertion_gate is not registered';
    END IF;

    SELECT n.nspname
      INTO v_pgcrypto_schema
      FROM pg_extension AS e
      JOIN pg_namespace AS n
        ON n.oid = e.extnamespace
     WHERE e.extname = 'pgcrypto';

    IF v_pgcrypto_schema IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'undefined_object',
                MESSAGE = 'Required pgcrypto extension is not installed';
    END IF;

    IF v_pgcrypto_schema <> 'extensions' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'object_not_in_prerequisite_state',
                MESSAGE = 'pgcrypto must be installed in the extensions schema',
                DETAIL = format(
                    'pgcrypto is currently installed in schema %I.',
                    v_pgcrypto_schema
                ),
                HINT = 'Move pgcrypto with: ALTER EXTENSION pgcrypto SET SCHEMA extensions;';
    END IF;
END;
$dependency_check$;

-- ============================================================================
-- Authorization Lease secret hashing
-- ============================================================================

CREATE OR REPLACE FUNCTION access_control.hash_lease_secret(
    p_plaintext_secret text
)
RETURNS bytea
LANGUAGE sql
IMMUTABLE
STRICT
PARALLEL SAFE
SET search_path = pg_catalog, access_control
AS $function$
    SELECT extensions.digest(
        pg_catalog.convert_to(p_plaintext_secret, 'UTF8'),
        'sha256'
    );
$function$;

COMMENT ON FUNCTION access_control.hash_lease_secret(text) IS
    'Returns the SHA-256 digest used to store or compare a high-entropy Authorization Lease secret. The plaintext secret is not stored.';

REVOKE ALL
ON FUNCTION access_control.hash_lease_secret(text)
FROM PUBLIC;

-- ============================================================================
-- Phase -1 Foundation baseline integrity
-- The STABLE verifier uses statement_timestamp() so one statement evaluates a lease against one authoritative time.

-- Authorization Lease verification
-- ============================================================================

CREATE OR REPLACE FUNCTION access_control.verify_lease_secret(
    p_authorization_lease_id uuid,
    p_plaintext_secret text
)
RETURNS boolean
LANGUAGE sql
STABLE
STRICT
PARALLEL SAFE
SET search_path = pg_catalog, access_control
AS $function$
    SELECT EXISTS (
        SELECT 1
        FROM access_control.authorization_leases AS lease
        WHERE lease.authorization_lease_id = p_authorization_lease_id
          AND lease.status = 'ACTIVE'
          AND lease.revoked_at IS NULL
          AND lease.issued_at <= pg_catalog.statement_timestamp()
          AND pg_catalog.statement_timestamp() < lease.expires_at
          AND lease.lease_secret_hash =
              extensions.digest(
                  pg_catalog.convert_to(p_plaintext_secret, 'UTF8'),
                  'sha256'
              )
    );
$function$;

COMMENT ON FUNCTION access_control.verify_lease_secret(uuid, text) IS
    'Returns true only when the supplied secret matches an active, unrevoked, and unexpired Authorization Lease. PostgreSQL time is authoritative.';

REVOKE ALL
ON FUNCTION access_control.verify_lease_secret(uuid, text)
FROM PUBLIC;

-- ============================================================================
-- Authorization Lease revocation
-- ============================================================================

CREATE OR REPLACE FUNCTION access_control.revoke_lease(
    p_authorization_lease_id uuid,
    p_reason text
)
RETURNS boolean
LANGUAGE plpgsql
SET search_path = pg_catalog, access_control
AS $function$
DECLARE
    v_revoked boolean;
BEGIN
    IF p_reason IS NULL OR pg_catalog.btrim(p_reason) = '' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Authorization Lease revocation reason must not be empty';
    END IF;

    UPDATE access_control.authorization_leases
       SET status = 'REVOKED',
           revoked_at = pg_catalog.clock_timestamp(),
           revocation_reason = pg_catalog.btrim(p_reason)
     WHERE authorization_lease_id = p_authorization_lease_id
       AND status = 'ACTIVE'
       AND revoked_at IS NULL;

    v_revoked := FOUND;

    RETURN v_revoked;
END;
$function$;

COMMENT ON FUNCTION access_control.revoke_lease(uuid, text) IS
    'Revokes an active Authorization Lease. Returns true when a lease was revoked and false when it was already inactive, revoked, expired by status, or not found.';

REVOKE ALL
ON FUNCTION access_control.revoke_lease(uuid, text)
FROM PUBLIC;

-- ============================================================================
-- Register migration
-- ============================================================================

SELECT foundation_meta.register_migration(
    p_migration_id       => '075_controlled_authorization_api',
    p_migration_name     => 'Controlled authorization API',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created controlled Authorization Lease hashing, verification, and revocation functions using schema-qualified pgcrypto functions.'
);

COMMIT;


