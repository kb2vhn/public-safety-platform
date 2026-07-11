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


-- Phase -1 Foundation baseline integrity

ALTER TABLE service.platform_services
    ADD CONSTRAINT platform_services_key_format_ck
    CHECK (service_key ~ '^[a-z][a-z0-9_.-]*$'),
    ADD CONSTRAINT platform_services_type_nonempty_ck
    CHECK (btrim(service_type) <> ''),
    ADD CONSTRAINT platform_services_status_nonempty_ck
    CHECK (btrim(status) <> ''),
    ADD CONSTRAINT platform_services_validity_ck
    CHECK (
        valid_until IS NULL
        OR valid_until > valid_from
    );

ALTER TABLE service.deployments
    ADD CONSTRAINT deployments_key_format_ck
    CHECK (deployment_key ~ '^[a-z][a-z0-9_.-]*$'),
    ADD CONSTRAINT deployments_environment_key_format_ck
    CHECK (environment_key ~ '^[a-z][a-z0-9_.-]*$'),
    ADD CONSTRAINT deployments_status_nonempty_ck
    CHECK (btrim(status) <> ''),
    ADD CONSTRAINT deployments_validity_ck
    CHECK (
        valid_until IS NULL
        OR valid_until > valid_from
    );

ALTER TABLE service.configuration_items
    ADD COLUMN configuration_scope text NOT NULL,
    ADD CONSTRAINT configuration_items_scope_ck
    CHECK (
        (
            configuration_scope = 'PLATFORM'
            AND service_id IS NULL
            AND deployment_id IS NULL
        )
        OR
        (
            configuration_scope = 'SERVICE'
            AND service_id IS NOT NULL
            AND deployment_id IS NULL
        )
        OR
        (
            configuration_scope = 'DEPLOYMENT'
            AND service_id IS NULL
            AND deployment_id IS NOT NULL
        )
    ),
    ADD CONSTRAINT configuration_items_key_format_ck
    CHECK (configuration_key ~ '^[a-z][a-z0-9_.-]*$'),
    ADD CONSTRAINT configuration_items_classification_nonempty_ck
    CHECK (
        classification_key IS NULL
        OR btrim(classification_key) <> ''
    ),
    ADD CONSTRAINT configuration_items_version_positive_ck
    CHECK (version_number > 0),
    ADD CONSTRAINT configuration_items_validity_ck
    CHECK (
        valid_until IS NULL
        OR valid_until > valid_from
    );

CREATE UNIQUE INDEX configuration_items_platform_version_uq
    ON service.configuration_items(
        configuration_key,
        version_number
    )
    WHERE configuration_scope = 'PLATFORM';

CREATE UNIQUE INDEX configuration_items_service_version_uq
    ON service.configuration_items(
        service_id,
        configuration_key,
        version_number
    )
    WHERE configuration_scope = 'SERVICE';

CREATE UNIQUE INDEX configuration_items_deployment_version_uq
    ON service.configuration_items(
        deployment_id,
        configuration_key,
        version_number
    )
    WHERE configuration_scope = 'DEPLOYMENT';

SELECT foundation_meta.register_migration(
    p_migration_id       => '035_platform_services_and_configuration',
    p_migration_name     => 'Platform services and configuration',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created platform services and configuration objects.'
);

COMMIT;
