-- ============================================================================
-- Migration: 075_controlled_authorization_api.sql
-- Title: Controlled authorization API
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
        WHERE migration_id = '070_postgresql_trust_gate'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
                  MESSAGE = 'Required migration 070_postgresql_trust_gate is not registered';
    END IF;
END;
$dependency_check$;


CREATE FUNCTION access_control.verify_lease_secret(
    p_authorization_lease_id uuid,
    p_plaintext_secret text
)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = pg_catalog, authorization
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM access_control.authorization_leases l
        WHERE l.authorization_lease_id = p_authorization_lease_id
          AND l.status = 'ACTIVE'
          AND clock_timestamp() < l.expires_at
          AND l.lease_secret_hash = digest(p_plaintext_secret, 'sha256')
    );
$$;

CREATE FUNCTION access_control.revoke_lease(
    p_authorization_lease_id uuid,
    p_reason text
)
RETURNS void
LANGUAGE plpgsql
SET search_path = pg_catalog, authorization
AS $$
BEGIN
    UPDATE access_control.authorization_leases
       SET status='REVOKED',
           revoked_at=clock_timestamp(),
           revocation_reason=p_reason
     WHERE authorization_lease_id=p_authorization_lease_id
       AND status='ACTIVE';
END;
$$;

SELECT foundation_meta.register_migration(
    p_migration_id       => '075_controlled_authorization_api',
    p_migration_name     => 'Controlled authorization API',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created controlled authorization api objects.'
);

COMMIT;
