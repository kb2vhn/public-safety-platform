-- ============================================================================
-- Migration: 040_service_participation_and_federation.sql
-- Title: Service participation and federation
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
        WHERE migration_id = '035_platform_services_and_configuration'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
                  MESSAGE = 'Required migration 035_platform_services_and_configuration is not registered';
    END IF;
END;
$dependency_check$;


CREATE TABLE service.participation_agreements (
    participation_agreement_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    service_id uuid NOT NULL REFERENCES service.platform_services(service_id),
    participating_organization_id uuid NOT NULL REFERENCES organization.organizations(organization_id),
    service_owner_organization_id uuid REFERENCES organization.organizations(organization_id),
    platform_operator_organization_id uuid REFERENCES organization.organizations(organization_id),
    agreement_key text NOT NULL,
    status text NOT NULL DEFAULT 'DRAFT',
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    governing_document_reference text NOT NULL,
    governing_document_version text NOT NULL,
    created_by_reference text NOT NULL,
    UNIQUE(service_id,participating_organization_id,agreement_key)
);

CREATE TABLE service.participation_scopes (
    participation_scope_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    participation_agreement_id uuid NOT NULL REFERENCES service.participation_agreements(participation_agreement_id),
    scope_type text NOT NULL,
    scope_reference text NOT NULL,
    allowed boolean NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_until timestamptz
);

CREATE TABLE service.delegated_authorities (
    delegated_authority_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    delegating_organization_id uuid NOT NULL REFERENCES organization.organizations(organization_id),
    receiving_organization_id uuid NOT NULL REFERENCES organization.organizations(organization_id),
    service_id uuid REFERENCES service.platform_services(service_id),
    authority_category text NOT NULL,
    scope_reference text NOT NULL,
    redelegation_allowed boolean NOT NULL DEFAULT false,
    status text NOT NULL DEFAULT 'ACTIVE',
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    created_by_reference text NOT NULL
);

SELECT foundation_meta.register_migration(
    p_migration_id       => '040_service_participation_and_federation',
    p_migration_name     => 'Service participation and federation',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created service participation and federation objects.'
);

COMMIT;
