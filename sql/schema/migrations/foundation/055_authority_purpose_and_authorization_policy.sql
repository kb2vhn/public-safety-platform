-- ============================================================================
-- Migration: 055_authority_purpose_and_authorization_policy.sql
-- Title: Authority, purpose, operation, and authorization policy
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
        WHERE migration_id = '050_approval_framework'
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'object_not_in_prerequisite_state',
                MESSAGE = 'Required migration 050_approval_framework is not registered';
    END IF;
END;
$dependency_check$;

CREATE TABLE access_control.authority_definitions (
    authority_definition_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    authority_key text NOT NULL UNIQUE,
    title text NOT NULL,
    description text NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE',
    delegation_allowed boolean NOT NULL DEFAULT false,
    CONSTRAINT authority_definitions_key_ck
        CHECK (authority_key ~ '^[a-z][a-z0-9_.-]*$'),
    CONSTRAINT authority_definitions_status_ck
        CHECK (status IN ('DRAFT', 'ACTIVE', 'SUSPENDED', 'RETIRED'))
);

CREATE TABLE access_control.purpose_definitions (
    purpose_definition_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    purpose_key text NOT NULL UNIQUE,
    title text NOT NULL,
    description text NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE',
    CONSTRAINT purpose_definitions_key_ck
        CHECK (purpose_key ~ '^[a-z][a-z0-9_.-]*$'),
    CONSTRAINT purpose_definitions_status_ck
        CHECK (status IN ('DRAFT', 'ACTIVE', 'SUSPENDED', 'RETIRED'))
);

CREATE TABLE access_control.operation_definitions (
    operation_definition_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    operation_key text NOT NULL UNIQUE,
    title text NOT NULL,
    description text NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE',
    CONSTRAINT operation_definitions_key_ck
        CHECK (operation_key ~ '^[a-z][a-z0-9_.-]*$'),
    CONSTRAINT operation_definitions_status_ck
        CHECK (status IN ('DRAFT', 'ACTIVE', 'SUSPENDED', 'RETIRED'))
);

-- Bind approval-request snapshot keys to authoritative definition identifiers.
-- The Foundation baseline is pre-stable and is installed into a fresh database,
-- so these columns may be added as required before any module data exists.
ALTER TABLE access_control.purpose_definitions
    ADD CONSTRAINT purpose_definitions_id_key_uq
    UNIQUE (purpose_definition_id, purpose_key);

ALTER TABLE access_control.operation_definitions
    ADD CONSTRAINT operation_definitions_id_key_uq
    UNIQUE (operation_definition_id, operation_key);

ALTER TABLE approval.approval_requests
    ADD COLUMN purpose_definition_id uuid,
    ADD COLUMN operation_definition_id uuid NOT NULL,
    ADD CONSTRAINT approval_requests_purpose_pair_ck
        CHECK (
            (
                purpose_definition_id IS NULL
                AND purpose_key IS NULL
            )
            OR
            (
                purpose_definition_id IS NOT NULL
                AND purpose_key IS NOT NULL
            )
        ),
    ADD CONSTRAINT approval_requests_purpose_definition_fk
        FOREIGN KEY (purpose_definition_id, purpose_key)
        REFERENCES access_control.purpose_definitions(
            purpose_definition_id,
            purpose_key
        ),
    ADD CONSTRAINT approval_requests_operation_definition_fk
        FOREIGN KEY (operation_definition_id, operation_key)
        REFERENCES access_control.operation_definitions(
            operation_definition_id,
            operation_key
        );

DROP INDEX approval.approval_requests_context_idx;

CREATE INDEX approval_requests_context_idx
    ON approval.approval_requests(
        requester_identity_id,
        service_id,
        operation_definition_id,
        governed_scope_id,
        status,
        expires_at
    );

CREATE TABLE access_control.authority_grants (
    authority_grant_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    identity_id uuid NOT NULL
        REFERENCES identity.identities(identity_id),
    authority_definition_id uuid NOT NULL
        REFERENCES access_control.authority_definitions(authority_definition_id),
    purpose_definition_id uuid
        REFERENCES access_control.purpose_definitions(purpose_definition_id),
    operation_definition_id uuid
        REFERENCES access_control.operation_definitions(operation_definition_id),
    service_id uuid
        REFERENCES service.platform_services(service_id),
    organization_id uuid
        REFERENCES organization.organizations(organization_id),
    governed_scope_id uuid
        REFERENCES organization.governed_scopes(governed_scope_id),
    applies_to_all_governed_scopes boolean NOT NULL DEFAULT false,
    protected_target_type text,
    protected_target_reference text,
    applies_to_all_targets boolean NOT NULL DEFAULT false,
    scope_reference text,
    status text NOT NULL DEFAULT 'PENDING',
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    granted_by_identity_id uuid
        REFERENCES identity.identities(identity_id),
    approval_request_id uuid
        REFERENCES approval.approval_requests(approval_request_id),
    CONSTRAINT authority_grants_scope_ck
        CHECK (
            governed_scope_id IS NOT NULL
            OR applies_to_all_governed_scopes
            OR NULLIF(btrim(scope_reference), '') IS NOT NULL
        ),
    CONSTRAINT authority_grants_scope_exclusive_ck
        CHECK (
            NOT (
                governed_scope_id IS NOT NULL
                AND applies_to_all_governed_scopes
            )
        ),
    CONSTRAINT authority_grants_target_pair_ck
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
    CONSTRAINT authority_grants_target_requirement_ck
        CHECK (
            applies_to_all_targets
            OR protected_target_type IS NOT NULL
            OR NULLIF(btrim(scope_reference), '') IS NOT NULL
        ),
    CONSTRAINT authority_grants_target_exclusive_ck
        CHECK (
            NOT (
                applies_to_all_targets
                AND protected_target_type IS NOT NULL
            )
        ),
    CONSTRAINT authority_grants_status_ck
        CHECK (
            status IN (
                'PENDING',
                'ACTIVE',
                'SUSPENDED',
                'REVOKED',
                'EXPIRED',
                'SUPERSEDED'
            )
        ),
    CONSTRAINT authority_grants_validity_ck
        CHECK (valid_until IS NULL OR valid_until > valid_from)
);

COMMENT ON COLUMN access_control.authority_grants.scope_reference IS
    'Deprecated compatibility field. New records must use governed_scope_id plus protected_target_type and protected_target_reference.';

CREATE TABLE access_control.authorization_policies (
    authorization_policy_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_key text NOT NULL UNIQUE,
    title text NOT NULL,
    description text NOT NULL,
    status text NOT NULL DEFAULT 'DRAFT',
    CONSTRAINT authorization_policies_key_ck
        CHECK (policy_key ~ '^[a-z][a-z0-9_.-]*$'),
    CONSTRAINT authorization_policies_status_ck
        CHECK (status IN ('DRAFT', 'ACTIVE', 'SUSPENDED', 'RETIRED'))
);

CREATE TABLE access_control.authorization_policy_versions (
    authorization_policy_version_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    authorization_policy_id uuid NOT NULL
        REFERENCES access_control.authorization_policies(authorization_policy_id),
    version_number integer NOT NULL,
    decision_class text NOT NULL,
    service_id uuid
        REFERENCES service.platform_services(service_id),
    purpose_definition_id uuid
        REFERENCES access_control.purpose_definitions(purpose_definition_id),
    operation_definition_id uuid
        REFERENCES access_control.operation_definitions(operation_definition_id),
    governed_scope_required boolean NOT NULL DEFAULT false,
    protected_target_required boolean NOT NULL DEFAULT true,
    authentication_assertion_required boolean NOT NULL DEFAULT false,
    device_required boolean NOT NULL DEFAULT false,
    session_required boolean NOT NULL DEFAULT true,
    eligibility_required boolean NOT NULL DEFAULT true,
    approval_policy_id uuid
        REFERENCES approval.approval_policies(approval_policy_id),
    lease_use_mode text NOT NULL DEFAULT 'REUSABLE',
    lease_lifetime interval NOT NULL,
    lease_usage_limit integer,
    status text NOT NULL DEFAULT 'DRAFT',
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    governing_document_reference text NOT NULL,
    governing_document_version text NOT NULL,
    CONSTRAINT authorization_policy_versions_number_ck
        CHECK (version_number > 0),
    CONSTRAINT authorization_policy_versions_decision_class_ck
        CHECK (
            decision_class IN (
                'SESSION_ESTABLISHMENT',
                'SESSION_STEP_UP',
                'LEASE_ISSUANCE',
                'LEASE_RENEWAL',
                'PROTECTED_OPERATION',
                'SECURITY_REVOCATION'
            )
        ),
    CONSTRAINT authorization_policy_versions_use_mode_ck
        CHECK (lease_use_mode IN ('REUSABLE', 'SINGLE_USE', 'LIMITED_USE')),
    CONSTRAINT authorization_policy_versions_lifetime_ck
        CHECK (lease_lifetime > interval '0 seconds'),
    CONSTRAINT authorization_policy_versions_usage_ck
        CHECK (
            (lease_use_mode = 'REUSABLE' AND lease_usage_limit IS NULL)
            OR
            (lease_use_mode = 'SINGLE_USE' AND lease_usage_limit = 1)
            OR
            (lease_use_mode = 'LIMITED_USE' AND lease_usage_limit > 1)
        ),
    CONSTRAINT authorization_policy_versions_status_ck
        CHECK (
            status IN (
                'DRAFT',
                'ACTIVE',
                'SUSPENDED',
                'SUPERSEDED',
                'RETIRED'
            )
        ),
    CONSTRAINT authorization_policy_versions_validity_ck
        CHECK (valid_until IS NULL OR valid_until > valid_from),
    UNIQUE (authorization_policy_id, version_number)
);

CREATE TABLE access_control.authorization_policy_stage_requirements (
    authorization_policy_stage_requirement_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    authorization_policy_version_id uuid NOT NULL
        REFERENCES access_control.authorization_policy_versions(authorization_policy_version_id),
    stage_order integer NOT NULL,
    stage_key text NOT NULL,
    required boolean NOT NULL,
    CONSTRAINT authorization_policy_stage_order_ck
        CHECK (stage_order > 0),
    CONSTRAINT authorization_policy_stage_key_ck
        CHECK (stage_key ~ '^[A-Z][A-Z0-9_]*$'),
    UNIQUE (authorization_policy_version_id, stage_order),
    UNIQUE (authorization_policy_version_id, stage_key)
);

CREATE TABLE access_control.incompatible_authority_sets (
    incompatible_authority_set_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    set_key text NOT NULL UNIQUE,
    title text NOT NULL,
    description text NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE',
    CONSTRAINT incompatible_authority_sets_key_ck
        CHECK (set_key ~ '^[a-z][a-z0-9_.-]*$'),
    CONSTRAINT incompatible_authority_sets_status_ck
        CHECK (status IN ('DRAFT', 'ACTIVE', 'SUSPENDED', 'RETIRED'))
);

CREATE TABLE access_control.incompatible_authority_members (
    incompatible_authority_set_id uuid NOT NULL
        REFERENCES access_control.incompatible_authority_sets(incompatible_authority_set_id),
    authority_definition_id uuid NOT NULL
        REFERENCES access_control.authority_definitions(authority_definition_id),
    PRIMARY KEY (
        incompatible_authority_set_id,
        authority_definition_id
    )
);

CREATE INDEX authority_grants_context_idx
    ON access_control.authority_grants(
        identity_id,
        service_id,
        operation_definition_id,
        governed_scope_id,
        status,
        valid_until
    );

CREATE INDEX authorization_policy_versions_lookup_idx
    ON access_control.authorization_policy_versions(
        service_id,
        purpose_definition_id,
        operation_definition_id,
        decision_class,
        status,
        valid_from,
        valid_until
    );

SELECT foundation_meta.register_migration(
    p_migration_id => '055_authority_purpose_and_authorization_policy',
    p_migration_name => 'Authority purpose operation and authorization policy',
    p_migration_layer => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes => 'Created authority, Governed Purpose, Governed Operation, approval-request definition binding, Authorization Policy Version, stage requirement, and separation-of-duties objects.'
);

COMMIT;
