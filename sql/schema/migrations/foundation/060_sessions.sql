-- ============================================================================
-- Migration: 060_sessions.sql
-- Title: Sessions
-- Layer: Platform Foundation
-- Status: PHASE 2 IMPLEMENTATION CANDIDATE
-- Target: PostgreSQL 18
-- Compatibility policy: prefer mature features supported before PostgreSQL 18.
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '1min';
SET LOCAL idle_in_transaction_session_timeout = '1min';

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

-- Session structure is defined before Authentication Assertions. Migration 072
-- adds the assertion-linkage columns and foreign keys after migration 070 exists.
CREATE TABLE access_control.sessions (
    session_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    identity_id uuid NOT NULL
        REFERENCES identity.identities(identity_id),
    organization_id uuid
        REFERENCES organization.organizations(organization_id),
    device_id uuid
        REFERENCES trust.devices(device_id),
    trust_provider_id uuid NOT NULL
        REFERENCES trust.trust_providers(trust_provider_id),
    service_id uuid
        REFERENCES service.platform_services(service_id),
    status text NOT NULL DEFAULT 'ACTIVE',
    authenticated_at timestamptz NOT NULL,
    expires_at timestamptz NOT NULL,
    inactivity_timeout interval,
    last_activity_at timestamptz,
    last_step_up_at timestamptz,
    locked_at timestamptz,
    expired_at timestamptz,
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
            OR (
                inactivity_timeout > interval '0 seconds'
                AND inactivity_timeout <= (expires_at - authenticated_at)
            )
        ),

    CONSTRAINT sessions_activity_chronology_ck
        CHECK (
            last_activity_at IS NULL
            OR (
                last_activity_at >= authenticated_at
                AND last_activity_at < expires_at
            )
        ),

    CONSTRAINT sessions_step_up_chronology_ck
        CHECK (
            last_step_up_at IS NULL
            OR (
                last_step_up_at >= authenticated_at
                AND last_step_up_at < expires_at
            )
        ),

    CONSTRAINT sessions_locked_chronology_ck
        CHECK (
            locked_at IS NULL
            OR locked_at >= authenticated_at
        ),

    CONSTRAINT sessions_expired_chronology_ck
        CHECK (
            expired_at IS NULL
            OR expired_at >= authenticated_at
        ),

    CONSTRAINT sessions_revoked_chronology_ck
        CHECK (
            revoked_at IS NULL
            OR revoked_at >= authenticated_at
        ),

    CONSTRAINT sessions_terminated_chronology_ck
        CHECK (
            terminated_at IS NULL
            OR terminated_at >= authenticated_at
        ),

    CONSTRAINT sessions_state_shape_ck
        CHECK (
            (
                status = 'ACTIVE'
                AND locked_at IS NULL
                AND expired_at IS NULL
                AND revoked_at IS NULL
                AND terminated_at IS NULL
            )
            OR
            (
                status = 'LOCKED'
                AND locked_at IS NOT NULL
                AND expired_at IS NULL
                AND revoked_at IS NULL
                AND terminated_at IS NULL
            )
            OR
            (
                status = 'EXPIRED'
                AND locked_at IS NULL
                AND expired_at IS NOT NULL
                AND revoked_at IS NULL
                AND terminated_at IS NULL
            )
            OR
            (
                status = 'REVOKED'
                AND locked_at IS NULL
                AND expired_at IS NULL
                AND revoked_at IS NOT NULL
                AND terminated_at IS NULL
            )
            OR
            (
                status = 'TERMINATED'
                AND locked_at IS NULL
                AND expired_at IS NULL
                AND revoked_at IS NULL
                AND terminated_at IS NOT NULL
            )
        )
);

COMMENT ON TABLE access_control.sessions IS
    'Server-side authenticated-continuity records. A session is not durable authority and does not independently authorize a Protected Operation.';

COMMENT ON COLUMN access_control.sessions.organization_id IS
    'Optional selected organization context. This selection does not prove membership, eligibility, authority, or service participation.';

COMMENT ON COLUMN access_control.sessions.inactivity_timeout IS
    'Optional inactivity lifetime. Equality with the computed inactivity deadline is expired.';

COMMENT ON COLUMN access_control.sessions.last_step_up_at IS
    'Most recent successfully completed step-up time. Step-up evidence does not grant permanent elevation or operation authority.';

CREATE TABLE access_control.session_events (
    session_event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id uuid NOT NULL
        REFERENCES access_control.sessions(session_id),
    event_type text NOT NULL,
    event_at timestamptz NOT NULL DEFAULT statement_timestamp(),
    acting_identity_id uuid
        REFERENCES identity.identities(identity_id),
    actor_reference text,
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
                'EXPIRED',
                'REVOKED',
                'TERMINATED'
            )
        ),

    CONSTRAINT session_events_actor_reference_ck
        CHECK (
            actor_reference IS NULL
            OR btrim(actor_reference) <> ''
        ),

    CONSTRAINT session_events_actor_shape_ck
        CHECK (
            num_nonnulls(acting_identity_id, actor_reference) <= 1
        ),

    CONSTRAINT session_events_reason_code_ck
        CHECK (
            reason_code IS NULL
            OR reason_code ~ '^[A-Z][A-Z0-9_]*$'
        ),

    CONSTRAINT session_events_details_object_ck
        CHECK (jsonb_typeof(details) = 'object')
);

COMMENT ON TABLE access_control.session_events IS
    'Append-oriented material session transition history. Session and event mutations must commit or roll back together through controlled workflows.';

COMMENT ON COLUMN access_control.session_events.actor_reference IS
    'Non-human system, service, or administrative actor reference when acting_identity_id is not appropriate.';

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

CREATE INDEX sessions_device_active_idx
    ON access_control.sessions(
        device_id,
        status,
        expires_at
    )
    WHERE device_id IS NOT NULL;

CREATE INDEX sessions_provider_active_idx
    ON access_control.sessions(
        trust_provider_id,
        status,
        expires_at
    );

CREATE INDEX session_events_session_idx
    ON access_control.session_events(
        session_id,
        event_at,
        session_event_id
    );

SELECT foundation_meta.register_migration(
    p_migration_id => '060_sessions',
    p_migration_name => 'Sessions',
    p_migration_layer => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes => 'Created context-bound sessions with complete lifecycle state shape, chronology constraints, step-up timestamps, append-oriented session events, and approval-request session linkage.'
);

COMMIT;
