-- ============================================================================
-- Migration: 065_authorization_leases.sql
-- Title: Authorization Leases
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
        WHERE migration_id = '060_sessions'
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'object_not_in_prerequisite_state',
                MESSAGE = 'Required migration 060_sessions is not registered';
    END IF;
END;
$dependency_check$;

CREATE TABLE access_control.authorization_leases (
    authorization_lease_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id uuid NOT NULL,
    lease_secret_hash bytea NOT NULL,
    session_id uuid NOT NULL
        REFERENCES access_control.sessions(session_id),
    identity_id uuid NOT NULL
        REFERENCES identity.identities(identity_id),
    requester_organization_id uuid
        REFERENCES organization.organizations(organization_id),
    device_id uuid
        REFERENCES trust.devices(device_id),
    service_id uuid
        REFERENCES service.platform_services(service_id),
    purpose_definition_id uuid
        REFERENCES access_control.purpose_definitions(purpose_definition_id),
    operation_definition_id uuid
        REFERENCES access_control.operation_definitions(operation_definition_id),
    protected_target_type text,
    protected_target_reference text,
    governed_scope_id uuid
        REFERENCES organization.governed_scopes(governed_scope_id),
    classification_key text,
    authorization_policy_version_id uuid NOT NULL
        REFERENCES access_control.authorization_policy_versions(authorization_policy_version_id),
    approval_request_id uuid
        REFERENCES approval.approval_requests(approval_request_id),
    issuing_decision_id uuid,
    scope_reference text,
    use_mode text NOT NULL,
    usage_limit integer,
    successful_use_count integer NOT NULL DEFAULT 0,
    issued_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    expires_at timestamptz NOT NULL,
    consumed_at timestamptz,
    status text NOT NULL DEFAULT 'ACTIVE',
    revoked_at timestamptz,
    revocation_reason text,
    correlation_id uuid NOT NULL,
    CONSTRAINT authorization_leases_request_uq
        UNIQUE (request_id),
    CONSTRAINT authorization_leases_target_pair_ck
        CHECK (
            (
                protected_target_type IS NULL
                AND protected_target_reference IS NULL
            )
            OR
            (
                protected_target_type ~ '^[A-Z][A-Z0-9_]*$'
                AND btrim(protected_target_reference) <> ''
            )
        ),
    CONSTRAINT authorization_leases_context_ck
        CHECK (
            protected_target_type IS NOT NULL
            OR governed_scope_id IS NOT NULL
            OR NULLIF(btrim(scope_reference), '') IS NOT NULL
        ),
    CONSTRAINT authorization_leases_classification_key_ck
        CHECK (
            classification_key IS NULL
            OR classification_key ~ '^[A-Z][A-Z0-9_]*$'
        ),
    CONSTRAINT authorization_leases_use_mode_ck
        CHECK (use_mode IN ('REUSABLE', 'SINGLE_USE', 'LIMITED_USE')),
    CONSTRAINT authorization_leases_usage_limit_ck
        CHECK (
            (use_mode = 'REUSABLE' AND usage_limit IS NULL)
            OR
            (use_mode = 'SINGLE_USE' AND usage_limit = 1)
            OR
            (use_mode = 'LIMITED_USE' AND usage_limit > 1)
        ),
    CONSTRAINT authorization_leases_usage_count_ck
        CHECK (
            successful_use_count >= 0
            AND (
                usage_limit IS NULL
                OR successful_use_count <= usage_limit
            )
        ),
    CONSTRAINT authorization_leases_status_ck
        CHECK (
            status IN (
                'ACTIVE',
                'CONSUMED',
                'REVOKED',
                'EXPIRED'
            )
        ),
    CONSTRAINT authorization_leases_validity_ck
        CHECK (expires_at > issued_at),
    CONSTRAINT authorization_leases_revocation_state_ck
        CHECK (
            (status = 'REVOKED' AND revoked_at IS NOT NULL)
            OR
            (status <> 'REVOKED' AND revoked_at IS NULL)
        ),
    CONSTRAINT authorization_leases_consumption_state_ck
        CHECK (
            (status = 'CONSUMED' AND consumed_at IS NOT NULL)
            OR
            (status <> 'CONSUMED' AND consumed_at IS NULL)
        )
);

COMMENT ON COLUMN access_control.authorization_leases.scope_reference IS
    'Deprecated compatibility field. New records must use protected_target_type, protected_target_reference, and governed_scope_id.';

CREATE UNIQUE INDEX authorization_leases_secret_hash_uq
    ON access_control.authorization_leases(lease_secret_hash);

CREATE INDEX authorization_leases_active_context_idx
    ON access_control.authorization_leases(
        identity_id,
        requester_organization_id,
        service_id,
        operation_definition_id,
        governed_scope_id,
        status,
        expires_at
    );

CREATE TABLE access_control.lease_authority_grants (
    authorization_lease_id uuid NOT NULL
        REFERENCES access_control.authorization_leases(authorization_lease_id),
    authority_grant_id uuid NOT NULL
        REFERENCES access_control.authority_grants(authority_grant_id),
    PRIMARY KEY (
        authorization_lease_id,
        authority_grant_id
    )
);

CREATE TABLE access_control.authorization_lease_use_events (
    authorization_lease_use_event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    authorization_lease_id uuid NOT NULL
        REFERENCES access_control.authorization_leases(authorization_lease_id),
    request_id uuid NOT NULL,
    use_number integer NOT NULL,
    used_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    decision_reference uuid,
    correlation_id uuid NOT NULL,
    CONSTRAINT authorization_lease_use_events_number_ck
        CHECK (use_number > 0),
    UNIQUE (authorization_lease_id, use_number),
    UNIQUE (authorization_lease_id, request_id)
);

SELECT foundation_meta.register_migration(
    p_migration_id => '065_authorization_leases',
    p_migration_name => 'Authorization Leases',
    p_migration_layer => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes => 'Created context-bound Authorization Leases, use modes, atomic-use state, authority linkage, and append-oriented use events.'
);

COMMIT;
