-- ============================================================================
-- Migration: 050_approval_framework.sql
-- Title: Approval framework
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
        WHERE migration_id = '045_attestations_and_access_eligibility'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
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
    UNIQUE(policy_key,version_number)
);

CREATE TABLE approval.approval_policy_stages (
    approval_policy_stage_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    approval_policy_id uuid NOT NULL REFERENCES approval.approval_policies(approval_policy_id),
    stage_order integer NOT NULL,
    stage_key text NOT NULL,
    minimum_approvals integer NOT NULL DEFAULT 1,
    independent_identity_required boolean NOT NULL DEFAULT true,
    independent_organization_required boolean NOT NULL DEFAULT false,
    authority_requirement text NOT NULL,
    UNIQUE(approval_policy_id,stage_order),
    UNIQUE(approval_policy_id,stage_key)
);

CREATE TABLE approval.approval_requests (
    approval_request_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    approval_policy_id uuid NOT NULL REFERENCES approval.approval_policies(approval_policy_id),
    requester_identity_id uuid NOT NULL REFERENCES identity.identities(identity_id),
    service_id uuid REFERENCES service.platform_services(service_id),
    requested_operation text NOT NULL,
    target_reference text NOT NULL,
    status text NOT NULL DEFAULT 'PENDING',
    requested_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    expires_at timestamptz,
    correlation_id uuid NOT NULL DEFAULT gen_random_uuid()
);

CREATE TABLE approval.approval_actions (
    approval_action_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    approval_request_id uuid NOT NULL REFERENCES approval.approval_requests(approval_request_id),
    approval_policy_stage_id uuid NOT NULL REFERENCES approval.approval_policy_stages(approval_policy_stage_id),
    acting_identity_id uuid NOT NULL REFERENCES identity.identities(identity_id),
    acting_organization_id uuid REFERENCES organization.organizations(organization_id),
    action_type text NOT NULL,
    action_reason text,
    action_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT approval_actions_type_ck CHECK (action_type IN ('APPROVE','DENY','ABSTAIN','WITHDRAW_APPROVAL','CANCEL_REQUEST','ESCALATE'))
);

SELECT foundation_meta.register_migration(
    p_migration_id       => '050_approval_framework',
    p_migration_name     => 'Approval framework',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created approval framework objects.'
);

COMMIT;
