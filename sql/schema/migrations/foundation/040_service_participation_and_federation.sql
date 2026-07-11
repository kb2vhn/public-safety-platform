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


-- Phase -1 Foundation baseline integrity

ALTER TABLE service.participation_agreements
    ADD COLUMN version_number integer NOT NULL DEFAULT 1,
    ADD CONSTRAINT participation_agreements_key_format_ck
    CHECK (agreement_key ~ '^[a-z][a-z0-9_.-]*$'),
    ADD CONSTRAINT participation_agreements_version_positive_ck
    CHECK (version_number > 0),
    ADD CONSTRAINT participation_agreements_status_nonempty_ck
    CHECK (btrim(status) <> ''),
    ADD CONSTRAINT participation_agreements_validity_ck
    CHECK (
        valid_until IS NULL
        OR valid_until > valid_from
    );

DO $remove_original_participation_agreement_unique$
DECLARE
    v_constraint_name name;
BEGIN
    SELECT constraint_record.conname
    INTO v_constraint_name
    FROM pg_constraint AS constraint_record
    WHERE constraint_record.conrelid =
        'service.participation_agreements'::regclass
      AND constraint_record.contype = 'u'
      AND pg_get_constraintdef(constraint_record.oid) =
        'UNIQUE (service_id, participating_organization_id, agreement_key)';

    IF v_constraint_name IS NULL THEN
        RAISE EXCEPTION
        USING
            ERRCODE = 'undefined_object',
            MESSAGE = 'Expected participation agreement unique constraint was not found';
    END IF;

    EXECUTE format(
        'ALTER TABLE service.participation_agreements DROP CONSTRAINT %I',
        v_constraint_name
    );
END;
$remove_original_participation_agreement_unique$;

ALTER TABLE service.participation_agreements
    ADD CONSTRAINT participation_agreements_version_uq
    UNIQUE (
        service_id,
        participating_organization_id,
        agreement_key,
        version_number
    );

ALTER TABLE service.participation_scopes
    ADD CONSTRAINT participation_scopes_type_nonempty_ck
    CHECK (btrim(scope_type) <> ''),
    ADD CONSTRAINT participation_scopes_reference_nonempty_ck
    CHECK (btrim(scope_reference) <> ''),
    ADD CONSTRAINT participation_scopes_validity_ck
    CHECK (
        valid_until IS NULL
        OR valid_until > valid_from
    );

ALTER TABLE service.delegated_authorities
    ADD CONSTRAINT delegated_authorities_no_self_ck
    CHECK (
        delegating_organization_id <> receiving_organization_id
    ),
    ADD CONSTRAINT delegated_authorities_category_nonempty_ck
    CHECK (btrim(authority_category) <> ''),
    ADD CONSTRAINT delegated_authorities_scope_nonempty_ck
    CHECK (btrim(scope_reference) <> ''),
    ADD CONSTRAINT delegated_authorities_status_nonempty_ck
    CHECK (btrim(status) <> ''),
    ADD CONSTRAINT delegated_authorities_validity_ck
    CHECK (
        valid_until IS NULL
        OR valid_until > valid_from
    );

SELECT foundation_meta.register_migration(
    p_migration_id       => '040_service_participation_and_federation',
    p_migration_name     => 'Service participation and federation',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created service participation and federation objects.'
);

COMMIT;
