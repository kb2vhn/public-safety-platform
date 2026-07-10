-- ============================================================================
-- Migration: 035_platform_services_and_configuration.sql
-- Title: Platform services and configuration
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
        WHERE migration_id = '030_organizations_and_jurisdictions'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
                  MESSAGE = 'Required migration 030_organizations_and_jurisdictions is not registered';
    END IF;
END;
$dependency_check$;


CREATE TABLE service.platform_services (
    service_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    service_key text NOT NULL UNIQUE,
    display_name text NOT NULL,
    service_type text NOT NULL,
    service_owner_organization_id uuid REFERENCES organization.organizations(organization_id),
    status text NOT NULL DEFAULT 'PLANNED',
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    created_by_reference text NOT NULL
);

CREATE TABLE service.deployments (
    deployment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    service_id uuid NOT NULL REFERENCES service.platform_services(service_id),
    deployment_key text NOT NULL,
    environment_key text NOT NULL,
    platform_operator_organization_id uuid REFERENCES organization.organizations(organization_id),
    status text NOT NULL DEFAULT 'PLANNED',
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    UNIQUE(service_id,deployment_key)
);

CREATE TABLE service.configuration_items (
    configuration_item_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    service_id uuid REFERENCES service.platform_services(service_id),
    deployment_id uuid REFERENCES service.deployments(deployment_id),
    configuration_key text NOT NULL,
    configuration_value jsonb NOT NULL,
    classification_key text,
    version_number integer NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    approved_by_reference text NOT NULL,
    UNIQUE(service_id,deployment_id,configuration_key,version_number)
);

SELECT foundation_meta.register_migration(
    p_migration_id       => '035_platform_services_and_configuration',
    p_migration_name     => 'Platform services and configuration',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created platform services and configuration objects.'
);

COMMIT;
