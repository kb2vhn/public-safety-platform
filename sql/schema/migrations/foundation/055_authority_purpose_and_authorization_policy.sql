-- ============================================================================
-- Migration: 055_authority_purpose_and_authorization_policy.sql
-- Title: Authority purpose and authorization policy
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
        WHERE migration_id = '050_approval_framework'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
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
    delegation_allowed boolean NOT NULL DEFAULT false
);

CREATE TABLE access_control.purpose_definitions (
    purpose_definition_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    purpose_key text NOT NULL UNIQUE,
    title text NOT NULL,
    description text NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE'
);

CREATE TABLE access_control.authority_grants (
    authority_grant_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    identity_id uuid NOT NULL REFERENCES identity.identities(identity_id),
    authority_definition_id uuid NOT NULL REFERENCES access_control.authority_definitions(authority_definition_id),
    purpose_definition_id uuid REFERENCES access_control.purpose_definitions(purpose_definition_id),
    service_id uuid REFERENCES service.platform_services(service_id),
    organization_id uuid REFERENCES organization.organizations(organization_id),
    jurisdiction_id uuid REFERENCES organization.jurisdictions(jurisdiction_id),
    scope_reference text NOT NULL,
    status text NOT NULL DEFAULT 'PENDING',
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    granted_by_identity_id uuid REFERENCES identity.identities(identity_id),
    approval_request_id uuid REFERENCES approval.approval_requests(approval_request_id)
);

CREATE TABLE access_control.incompatible_authority_sets (
    incompatible_authority_set_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    set_key text NOT NULL UNIQUE,
    title text NOT NULL,
    description text NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE'
);

CREATE TABLE access_control.incompatible_authority_members (
    incompatible_authority_set_id uuid NOT NULL REFERENCES access_control.incompatible_authority_sets(incompatible_authority_set_id),
    authority_definition_id uuid NOT NULL REFERENCES access_control.authority_definitions(authority_definition_id),
    PRIMARY KEY(incompatible_authority_set_id,authority_definition_id)
);

SELECT foundation_meta.register_migration(
    p_migration_id       => '055_authority_purpose_and_authorization_policy',
    p_migration_name     => 'Authority purpose and authorization policy',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created authority purpose and authorization policy objects.'
);

COMMIT;
