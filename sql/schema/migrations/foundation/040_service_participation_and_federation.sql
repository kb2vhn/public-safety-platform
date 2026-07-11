-- ============================================================================
-- Migration: 040_service_participation_and_federation.sql
-- Title: Service participation and federation
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
        WHERE migration_id = '035_platform_services_and_configuration'
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'object_not_in_prerequisite_state',
                MESSAGE = 'Required migration 035_platform_services_and_configuration is not registered';
    END IF;
END;
$dependency_check$;

CREATE TABLE service.participation_agreements (
    participation_agreement_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    service_id uuid NOT NULL
        REFERENCES service.platform_services(service_id),
    participating_organization_id uuid NOT NULL
        REFERENCES organization.organizations(organization_id),
    service_owner_organization_id uuid
        REFERENCES organization.organizations(organization_id),
    platform_operator_organization_id uuid
        REFERENCES organization.organizations(organization_id),
    agreement_key text NOT NULL,
    version_number integer NOT NULL,
    status text NOT NULL DEFAULT 'DRAFT',
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    governing_document_reference text NOT NULL,
    governing_document_version text NOT NULL,
    created_by_reference text NOT NULL,
    CONSTRAINT participation_agreements_key_ck
        CHECK (agreement_key ~ '^[a-z][a-z0-9_.-]*$'),
    CONSTRAINT participation_agreements_version_ck
        CHECK (version_number > 0),
    CONSTRAINT participation_agreements_status_ck
        CHECK (
            status IN (
                'DRAFT',
                'ACTIVE',
                'SUSPENDED',
                'SUPERSEDED',
                'TERMINATED',
                'EXPIRED'
            )
        ),
    CONSTRAINT participation_agreements_validity_ck
        CHECK (valid_until IS NULL OR valid_until > valid_from),
    CONSTRAINT participation_agreements_history_uq
        UNIQUE (
            service_id,
            participating_organization_id,
            agreement_key,
            version_number
        )
);

CREATE TABLE service.participation_scopes (
    participation_scope_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    participation_agreement_id uuid NOT NULL
        REFERENCES service.participation_agreements(participation_agreement_id),
    governed_scope_id uuid
        REFERENCES organization.governed_scopes(governed_scope_id),
    applies_to_all_governed_scopes boolean NOT NULL DEFAULT false,
    allowed boolean NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    scope_reference text,
    CONSTRAINT participation_scopes_boundary_ck
        CHECK (
            governed_scope_id IS NOT NULL
            OR applies_to_all_governed_scopes
            OR NULLIF(btrim(scope_reference), '') IS NOT NULL
        ),
    CONSTRAINT participation_scopes_all_scope_ck
        CHECK (
            NOT (
                governed_scope_id IS NOT NULL
                AND applies_to_all_governed_scopes
            )
        ),
    CONSTRAINT participation_scopes_validity_ck
        CHECK (valid_until IS NULL OR valid_until > valid_from)
);

COMMENT ON COLUMN service.participation_scopes.scope_reference IS
    'Deprecated compatibility field. New records must use governed_scope_id or applies_to_all_governed_scopes. Remove before the first stable migration baseline.';

CREATE TABLE service.delegated_authorities (
    delegated_authority_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    delegating_organization_id uuid NOT NULL
        REFERENCES organization.organizations(organization_id),
    receiving_organization_id uuid NOT NULL
        REFERENCES organization.organizations(organization_id),
    service_id uuid
        REFERENCES service.platform_services(service_id),
    authority_category text NOT NULL,
    governed_scope_id uuid
        REFERENCES organization.governed_scopes(governed_scope_id),
    applies_to_all_governed_scopes boolean NOT NULL DEFAULT false,
    scope_reference text,
    redelegation_allowed boolean NOT NULL DEFAULT false,
    status text NOT NULL DEFAULT 'ACTIVE',
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    created_by_reference text NOT NULL,
    CONSTRAINT delegated_authorities_no_self_delegation_ck
        CHECK (delegating_organization_id <> receiving_organization_id),
    CONSTRAINT delegated_authorities_category_ck
        CHECK (authority_category ~ '^[A-Z][A-Z0-9_]*$'),
    CONSTRAINT delegated_authorities_boundary_ck
        CHECK (
            governed_scope_id IS NOT NULL
            OR applies_to_all_governed_scopes
            OR NULLIF(btrim(scope_reference), '') IS NOT NULL
        ),
    CONSTRAINT delegated_authorities_all_scope_ck
        CHECK (
            NOT (
                governed_scope_id IS NOT NULL
                AND applies_to_all_governed_scopes
            )
        ),
    CONSTRAINT delegated_authorities_status_ck
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
    CONSTRAINT delegated_authorities_validity_ck
        CHECK (valid_until IS NULL OR valid_until > valid_from)
);

COMMENT ON COLUMN service.delegated_authorities.scope_reference IS
    'Deprecated compatibility field. New records must use governed_scope_id or applies_to_all_governed_scopes. Remove before the first stable migration baseline.';

CREATE INDEX participation_scopes_governed_scope_idx
    ON service.participation_scopes(
        governed_scope_id,
        allowed,
        valid_from
    )
    WHERE governed_scope_id IS NOT NULL;

CREATE INDEX delegated_authorities_scope_idx
    ON service.delegated_authorities(
        service_id,
        governed_scope_id,
        status,
        valid_until
    );

SELECT foundation_meta.register_migration(
    p_migration_id => '040_service_participation_and_federation',
    p_migration_name => 'Service participation and federation',
    p_migration_layer => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes => 'Created versioned service participation agreements and explicit Governed Scope boundaries for participation and delegated authority.'
);

COMMIT;
