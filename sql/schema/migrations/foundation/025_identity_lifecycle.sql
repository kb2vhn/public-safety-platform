-- ============================================================================
-- Migration: 025_identity_lifecycle.sql
-- Title: Identity lifecycle
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
        WHERE migration_id = '020_identity'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
                  MESSAGE = 'Required migration 020_identity is not registered';
    END IF;
END;
$dependency_check$;


CREATE TABLE identity.identity_lifecycle_events (
    identity_lifecycle_event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    identity_id uuid NOT NULL REFERENCES identity.identities(identity_id),
    event_type text NOT NULL,
    previous_status text,
    new_status text NOT NULL,
    valid_at timestamptz NOT NULL,
    recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    recorded_by_reference text NOT NULL,
    reason_code text NOT NULL,
    reason_detail text
);
CREATE INDEX identity_lifecycle_identity_idx ON identity.identity_lifecycle_events(identity_id,valid_at,recorded_at);

CREATE TABLE identity.identity_suspensions (
    identity_suspension_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    identity_id uuid NOT NULL REFERENCES identity.identities(identity_id),
    reason_code text NOT NULL,
    reason_detail text,
    effective_at timestamptz NOT NULL,
    expires_at timestamptz,
    released_at timestamptz,
    recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    recorded_by_reference text NOT NULL,
    CONSTRAINT identity_suspension_period_ck CHECK (expires_at IS NULL OR expires_at > effective_at)
);
CREATE INDEX identity_suspensions_active_idx ON identity.identity_suspensions(identity_id,effective_at,expires_at,released_at);


-- Phase -1 Foundation baseline integrity

ALTER TABLE identity.identity_lifecycle_events
    ADD CONSTRAINT identity_lifecycle_event_type_nonempty_ck
    CHECK (btrim(event_type) <> ''),
    ADD CONSTRAINT identity_lifecycle_previous_status_ck
    CHECK (
        previous_status IS NULL
        OR previous_status IN (
            'PENDING',
            'ACTIVE',
            'SUSPENDED',
            'DISABLED',
            'RETIRED',
            'ARCHIVED'
        )
    ),
    ADD CONSTRAINT identity_lifecycle_new_status_ck
    CHECK (
        new_status IN (
            'PENDING',
            'ACTIVE',
            'SUSPENDED',
            'DISABLED',
            'RETIRED',
            'ARCHIVED'
        )
    ),
    ADD CONSTRAINT identity_lifecycle_reason_code_nonempty_ck
    CHECK (btrim(reason_code) <> '');

ALTER TABLE identity.identity_suspensions
    ADD CONSTRAINT identity_suspension_reason_code_nonempty_ck
    CHECK (btrim(reason_code) <> ''),
    ADD CONSTRAINT identity_suspension_release_period_ck
    CHECK (
        released_at IS NULL
        OR released_at >= effective_at
    );

SELECT foundation_meta.register_migration(
    p_migration_id       => '025_identity_lifecycle',
    p_migration_name     => 'Identity lifecycle',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created identity lifecycle objects.'
);

COMMIT;
