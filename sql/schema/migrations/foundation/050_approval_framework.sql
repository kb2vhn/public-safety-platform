-- ============================================================================
-- Migration: 050_approval_framework.sql
-- Title: Approval framework
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
        WHERE migration_id = '045_attestations_and_access_eligibility'
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'object_not_in_prerequisite_state',
                MESSAGE = 'Required migration 045_attestations_and_access_eligibility is not registered';
    END IF;
END;
$dependency_check$;

CREATE TABLE approval.approval_policies (
    approval_policy_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_key text NOT NULL,
    version_number integer NOT NULL,
    title text NOT NULL,
    status text NOT NULL DEFAULT 'DRAFT',
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    self_approval_allowed boolean NOT NULL DEFAULT false,
    created_by_reference text NOT NULL,
    CONSTRAINT approval_policies_key_ck
        CHECK (policy_key ~ '^[a-z][a-z0-9_.-]*$'),
    CONSTRAINT approval_policies_version_ck
        CHECK (version_number > 0),
    CONSTRAINT approval_policies_status_ck
        CHECK (
            status IN (
                'DRAFT',
                'ACTIVE',
                'SUSPENDED',
                'SUPERSEDED',
                'RETIRED'
            )
        ),
    CONSTRAINT approval_policies_validity_ck
        CHECK (valid_until IS NULL OR valid_until > valid_from),
    CONSTRAINT approval_policies_history_uq
        UNIQUE (policy_key, version_number)
);

CREATE TABLE approval.approval_policy_stages (
    approval_policy_stage_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    approval_policy_id uuid NOT NULL
        REFERENCES approval.approval_policies(approval_policy_id),
    stage_order integer NOT NULL,
    stage_key text NOT NULL,
    minimum_approvals integer NOT NULL DEFAULT 1,
    independent_identity_required boolean NOT NULL DEFAULT true,
    independent_organization_required boolean NOT NULL DEFAULT false,
    authority_requirement text NOT NULL,
    CONSTRAINT approval_policy_stages_order_ck
        CHECK (stage_order > 0),
    CONSTRAINT approval_policy_stages_key_ck
        CHECK (stage_key ~ '^[A-Z][A-Z0-9_]*$'),
    CONSTRAINT approval_policy_stages_minimum_ck
        CHECK (minimum_approvals > 0),
    UNIQUE (approval_policy_id, stage_order),
    UNIQUE (approval_policy_id, stage_key)
);

CREATE TABLE approval.approval_requests (
    approval_request_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    approval_policy_id uuid NOT NULL
        REFERENCES approval.approval_policies(approval_policy_id),
    requester_identity_id uuid NOT NULL
        REFERENCES identity.identities(identity_id),
    requester_organization_id uuid
        REFERENCES organization.organizations(organization_id),
    requester_session_id uuid,
    service_id uuid
        REFERENCES service.platform_services(service_id),
    -- The definition tables are created in migration 055. These stable keys
    -- are bound to their authoritative definition identifiers there.
    purpose_key text,
    operation_key text NOT NULL,
    protected_target_type text NOT NULL,
    protected_target_reference text NOT NULL,
    governed_scope_id uuid
        REFERENCES organization.governed_scopes(governed_scope_id),
    classification_key text,
    status text NOT NULL DEFAULT 'PENDING',
    requested_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    expires_at timestamptz,
    correlation_id uuid NOT NULL DEFAULT gen_random_uuid(),
    CONSTRAINT approval_requests_purpose_key_ck
        CHECK (
            purpose_key IS NULL
            OR purpose_key ~ '^[a-z][a-z0-9_.-]*$'
        ),
    CONSTRAINT approval_requests_operation_key_ck
        CHECK (operation_key ~ '^[a-z][a-z0-9_.-]*$'),
    CONSTRAINT approval_requests_target_type_ck
        CHECK (protected_target_type ~ '^[A-Z][A-Z0-9_]*$'),
    CONSTRAINT approval_requests_target_reference_ck
        CHECK (btrim(protected_target_reference) <> ''),
    CONSTRAINT approval_requests_classification_key_ck
        CHECK (
            classification_key IS NULL
            OR classification_key ~ '^[A-Z][A-Z0-9_]*$'
        ),
    CONSTRAINT approval_requests_status_ck
        CHECK (
            status IN (
                'PENDING',
                'APPROVED',
                'DENIED',
                'CANCELLED',
                'EXPIRED',
                'ESCALATED'
            )
        ),
    CONSTRAINT approval_requests_validity_ck
        CHECK (expires_at IS NULL OR expires_at > requested_at)
);

CREATE TABLE approval.approval_actions (
    approval_action_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    approval_request_id uuid NOT NULL
        REFERENCES approval.approval_requests(approval_request_id),
    approval_policy_stage_id uuid NOT NULL
        REFERENCES approval.approval_policy_stages(approval_policy_stage_id),
    acting_identity_id uuid NOT NULL
        REFERENCES identity.identities(identity_id),
    acting_organization_id uuid
        REFERENCES organization.organizations(organization_id),
    action_type text NOT NULL,
    action_reason text,
    action_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT approval_actions_type_ck
        CHECK (
            action_type IN (
                'APPROVE',
                'DENY',
                'ABSTAIN',
                'WITHDRAW_APPROVAL',
                'CANCEL_REQUEST',
                'ESCALATE',
                'CORRECT',
                'SUPERSEDE'
            )
        )
);

CREATE INDEX approval_requests_context_idx
    ON approval.approval_requests(
        requester_identity_id,
        service_id,
        operation_key,
        governed_scope_id,
        status,
        expires_at
    );

CREATE INDEX approval_actions_request_idx
    ON approval.approval_actions(
        approval_request_id,
        approval_policy_stage_id,
        action_at
    );

SELECT foundation_meta.register_migration(
    p_migration_id => '050_approval_framework',
    p_migration_name => 'Approval framework',
    p_migration_layer => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes => 'Created versioned approval policies, approval request context pending definition binding in migration 055, and append-oriented approval actions.'
);

COMMIT;
