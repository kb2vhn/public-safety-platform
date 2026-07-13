-- ============================================================================
-- Migration: 075_controlled_authorization_api.sql
-- Title: Controlled Authorization API
-- Layer: Platform Foundation
-- Status: REVIEW CANDIDATE
-- Target: PostgreSQL 18
-- ============================================================================

-- Purpose:
-- Provide controlled functions for hashing Authorization Lease secrets,
-- verifying secret possession, validating complete lease context, consuming
-- lease uses atomically, and revoking leases.

-- Security boundaries:
-- - The pgcrypto digest function is schema-qualified as extensions.digest().
-- - Plaintext lease secrets are never stored.
-- - A secret match is not by itself an authorization result.
-- - Complete context verification uses one PostgreSQL statement timestamp.
-- - PUBLIC may not execute the controlled functions.

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '1min';
SET LOCAL idle_in_transaction_session_timeout = '1min';

SELECT pg_advisory_xact_lock(
    hashtext(current_database()),
    hashtext('platform-foundation-migrations')
);

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
    'Returns the SHA-256 digest used to store or compare a high-entropy Authorization Lease secret.';

REVOKE ALL
ON FUNCTION access_control.hash_lease_secret(text)
FROM PUBLIC;

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
          AND lease.lease_secret_hash =
              extensions.digest(
                  pg_catalog.convert_to(p_plaintext_secret, 'UTF8'),
                  'sha256'
              )
    );
$function$;

COMMENT ON FUNCTION access_control.verify_lease_secret(uuid, text) IS
    'Verifies only possession of the lease secret. It does not validate status, time, usage, identity, organization, session, service, purpose, operation, target, Governed Scope, classification, or policy. It is not an authorization decision.';

REVOKE ALL
ON FUNCTION access_control.verify_lease_secret(uuid, text)
FROM PUBLIC;

CREATE OR REPLACE FUNCTION access_control.verify_authorization_lease_context(
    p_authorization_lease_id uuid,
    p_plaintext_secret text,
    p_identity_id uuid,
    p_requester_organization_id uuid,
    p_session_id uuid,
    p_device_id uuid,
    p_service_id uuid,
    p_purpose_definition_id uuid,
    p_operation_definition_id uuid,
    p_protected_target_type text,
    p_protected_target_reference text,
    p_governed_scope_id uuid,
    p_classification_key text,
    p_authorization_policy_version_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
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
          AND lease.identity_id = p_identity_id
          AND lease.requester_organization_id
              IS NOT DISTINCT FROM p_requester_organization_id
          AND lease.session_id = p_session_id
          AND lease.device_id IS NOT DISTINCT FROM p_device_id
          AND lease.service_id IS NOT DISTINCT FROM p_service_id
          AND lease.purpose_definition_id
              IS NOT DISTINCT FROM p_purpose_definition_id
          AND lease.operation_definition_id
              IS NOT DISTINCT FROM p_operation_definition_id
          AND lease.protected_target_type
              IS NOT DISTINCT FROM p_protected_target_type
          AND lease.protected_target_reference
              IS NOT DISTINCT FROM p_protected_target_reference
          AND lease.governed_scope_id
              IS NOT DISTINCT FROM p_governed_scope_id
          AND lease.classification_key
              IS NOT DISTINCT FROM p_classification_key
          AND lease.authorization_policy_version_id =
              p_authorization_policy_version_id
          AND (
              lease.use_mode = 'REUSABLE'
              OR
              (
                  lease.use_mode = 'SINGLE_USE'
                  AND lease.successful_use_count = 0
              )
              OR
              (
                  lease.use_mode = 'LIMITED_USE'
                  AND lease.successful_use_count < lease.usage_limit
              )
          )
    );
$function$;

COMMENT ON FUNCTION access_control.verify_authorization_lease_context(
    uuid,
    text,
    uuid,
    uuid,
    uuid,
    uuid,
    uuid,
    uuid,
    uuid,
    text,
    text,
    uuid,
    text,
    uuid
) IS
    'Returns true only when secret, lifecycle, authoritative time, usage state, and every supplied authorization context field match the Authorization Lease.';

REVOKE ALL
ON FUNCTION access_control.verify_authorization_lease_context(
    uuid,
    text,
    uuid,
    uuid,
    uuid,
    uuid,
    uuid,
    uuid,
    uuid,
    text,
    text,
    uuid,
    text,
    uuid
)
FROM PUBLIC;

CREATE OR REPLACE FUNCTION access_control.consume_authorization_lease_use(
    p_authorization_lease_id uuid,
    p_plaintext_secret text,
    p_request_id uuid,
    p_identity_id uuid,
    p_requester_organization_id uuid,
    p_session_id uuid,
    p_device_id uuid,
    p_service_id uuid,
    p_purpose_definition_id uuid,
    p_operation_definition_id uuid,
    p_protected_target_type text,
    p_protected_target_reference text,
    p_governed_scope_id uuid,
    p_classification_key text,
    p_authorization_policy_version_id uuid,
    p_decision_reference uuid,
    p_correlation_id uuid
)
RETURNS integer
LANGUAGE plpgsql
SET search_path = pg_catalog, access_control
AS $function$
DECLARE
    v_evaluated_at timestamptz := pg_catalog.statement_timestamp();
    v_use_number integer;
BEGIN
    UPDATE access_control.authorization_leases AS lease
    SET
        successful_use_count = lease.successful_use_count + 1,
        status = CASE
            WHEN lease.use_mode = 'SINGLE_USE' THEN 'CONSUMED'
            WHEN lease.use_mode = 'LIMITED_USE'
                 AND lease.successful_use_count + 1 = lease.usage_limit
                THEN 'CONSUMED'
            ELSE lease.status
        END,
        consumed_at = CASE
            WHEN lease.use_mode = 'SINGLE_USE' THEN v_evaluated_at
            WHEN lease.use_mode = 'LIMITED_USE'
                 AND lease.successful_use_count + 1 = lease.usage_limit
                THEN v_evaluated_at
            ELSE lease.consumed_at
        END
    WHERE lease.authorization_lease_id = p_authorization_lease_id
      AND lease.status = 'ACTIVE'
      AND lease.revoked_at IS NULL
      AND lease.issued_at <= v_evaluated_at
      AND v_evaluated_at < lease.expires_at
      AND lease.lease_secret_hash =
          extensions.digest(
              pg_catalog.convert_to(p_plaintext_secret, 'UTF8'),
              'sha256'
          )
      AND lease.identity_id = p_identity_id
      AND lease.requester_organization_id
          IS NOT DISTINCT FROM p_requester_organization_id
      AND lease.session_id = p_session_id
      AND lease.device_id IS NOT DISTINCT FROM p_device_id
      AND lease.service_id IS NOT DISTINCT FROM p_service_id
      AND lease.purpose_definition_id
          IS NOT DISTINCT FROM p_purpose_definition_id
      AND lease.operation_definition_id
          IS NOT DISTINCT FROM p_operation_definition_id
      AND lease.protected_target_type
          IS NOT DISTINCT FROM p_protected_target_type
      AND lease.protected_target_reference
          IS NOT DISTINCT FROM p_protected_target_reference
      AND lease.governed_scope_id
          IS NOT DISTINCT FROM p_governed_scope_id
      AND lease.classification_key
          IS NOT DISTINCT FROM p_classification_key
      AND lease.authorization_policy_version_id =
          p_authorization_policy_version_id
      AND (
          lease.use_mode = 'REUSABLE'
          OR
          (
              lease.use_mode = 'SINGLE_USE'
              AND lease.successful_use_count = 0
          )
          OR
          (
              lease.use_mode = 'LIMITED_USE'
              AND lease.successful_use_count < lease.usage_limit
          )
      )
    RETURNING successful_use_count
    INTO v_use_number;

    IF v_use_number IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_authorization_specification',
                MESSAGE = 'Authorization Lease is unavailable',
                DETAIL = 'The lease did not satisfy the required secret, lifecycle, time, usage, or exact-context conditions.';
    END IF;

    INSERT INTO access_control.authorization_lease_use_events (
        authorization_lease_id,
        request_id,
        use_number,
        used_at,
        decision_reference,
        correlation_id
    )
    VALUES (
        p_authorization_lease_id,
        p_request_id,
        v_use_number,
        v_evaluated_at,
        p_decision_reference,
        p_correlation_id
    );

    RETURN v_use_number;
END;
$function$;

REVOKE ALL
ON FUNCTION access_control.consume_authorization_lease_use(
    uuid,
    text,
    uuid,
    uuid,
    uuid,
    uuid,
    uuid,
    uuid,
    uuid,
    uuid,
    text,
    text,
    uuid,
    text,
    uuid,
    uuid,
    uuid
)
FROM PUBLIC;

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
    SET
        status = 'REVOKED',
        revoked_at = pg_catalog.clock_timestamp(),
        revocation_reason = pg_catalog.btrim(p_reason)
    WHERE authorization_lease_id = p_authorization_lease_id
      AND status = 'ACTIVE'
      AND revoked_at IS NULL;

    v_revoked := FOUND;
    RETURN v_revoked;
END;
$function$;

REVOKE ALL
ON FUNCTION access_control.revoke_lease(uuid, text)
FROM PUBLIC;

SELECT foundation_meta.register_migration(
    p_migration_id => '075_controlled_authorization_api',
    p_migration_name => 'Controlled authorization API',
    p_migration_layer => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes => 'Created lease-secret hashing, secret-only verification, complete context verification, atomic lease-use consumption, and revocation functions.'
);

COMMIT;
