-- ============================================================================
-- Migration: 060_sessions.sql
-- Title: Sessions
-- Layer: Platform Foundation
-- Status: REVIEW CANDIDATE
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
            USING
                ERRCODE = 'object_not_in_prerequisite_state',
                MESSAGE = 'Required migration 055_authority_purpose_and_authorization_policy is not registered';
    END IF;
END;
$dependency_check$;

CREATE TABLE access_control.sessions (
    session_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    identity_id uuid NOT NULL
        REFERENCES identity.identities(identity_id),
    organization_id uuid
        REFERENCES organization.organizations(organization_id),
    device_id uuid
        REFERENCES trust.devices(device_id),
    trust_provider_id uuid
        REFERENCES trust.trust_providers(trust_provider_id),
    service_id uuid
        REFERENCES service.platform_services(service_id),
    status text NOT NULL DEFAULT 'ACTIVE',
    authenticated_at timestamptz NOT NULL,
    expires_at timestamptz NOT NULL,
    inactivity_timeout interval,
    last_activity_at timestamptz,
    locked_at timestamptz,
    revoked_at timestamptz,
    terminated_at timestamptz,
    correlation_id uuid NOT NULL DEFAULT gen_random_uuid(),
    CONSTRAINT sessions_status_ck
        CHECK (
            status IN (
                'ACTIVE',
                'LOCKED',
                'EXPIRED',
                'REVOKED',
                'TERMINATED'
            )
        ),
    CONSTRAINT sessions_validity_ck
        CHECK (expires_at > authenticated_at),
    CONSTRAINT sessions_inactivity_timeout_ck
        CHECK (
            inactivity_timeout IS NULL
            OR inactivity_timeout > interval '0 seconds'
        ),
    CONSTRAINT sessions_activity_ck
        CHECK (
            last_activity_at IS NULL
            OR last_activity_at >= authenticated_at
        ),
    CONSTRAINT sessions_state_timestamp_ck
        CHECK (
            (status = 'LOCKED' AND locked_at IS NOT NULL)
            OR (status = 'REVOKED' AND revoked_at IS NOT NULL)
            OR (status = 'TERMINATED' AND terminated_at IS NOT NULL)
            OR status IN ('ACTIVE', 'EXPIRED')
        )
);

CREATE TABLE access_control.session_events (
    session_event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id uuid NOT NULL
        REFERENCES access_control.sessions(session_id),
    event_type text NOT NULL,
    event_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    acting_identity_id uuid
        REFERENCES identity.identities(identity_id),
    reason_code text,
    details jsonb NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT session_events_type_ck
        CHECK (
            event_type IN (
                'CREATED',
                'ACTIVITY_RECORDED',
                'STEP_UP_COMPLETED',
                'LOCKED',
                'UNLOCKED',
                'REVOKED',
                'TERMINATED',
                'EXPIRED'
            )
        ),
    CONSTRAINT session_events_reason_code_ck
        CHECK (
            reason_code IS NULL
            OR reason_code ~ '^[A-Z][A-Z0-9_]*$'
        )
);

ALTER TABLE approval.approval_requests
    ADD CONSTRAINT approval_requests_requester_session_fk
    FOREIGN KEY (requester_session_id)
    REFERENCES access_control.sessions(session_id);

CREATE INDEX sessions_identity_active_idx
    ON access_control.sessions(
        identity_id,
        service_id,
        status,
        expires_at
    );

CREATE INDEX session_events_session_idx
    ON access_control.session_events(
        session_id,
        event_at
    );

SELECT foundation_meta.register_migration(
    p_migration_id => '060_sessions',
    p_migration_name => 'Sessions',
    p_migration_layer => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes => 'Created context-bound sessions, explicit lifecycle state, append-oriented session events, and approval-request session linkage.'
);

COMMIT;
