-- ============================================================================
-- Migration: 030_organizations_and_jurisdictions.sql
-- Title: Organizations and jurisdictions
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
        WHERE migration_id = '025_identity_lifecycle'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
                  MESSAGE = 'Required migration 025_identity_lifecycle is not registered';
    END IF;
END;
$dependency_check$;


CREATE TABLE organization.organizations (
    organization_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_key text NOT NULL UNIQUE,
    legal_name text NOT NULL,
    display_name text NOT NULL,
    organization_type text NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE',
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_by_reference text NOT NULL,
    CONSTRAINT organizations_status_ck CHECK (status IN ('PENDING','ACTIVE','SUSPENDED','DISSOLVED','SUPERSEDED','RETIRED')),
    CONSTRAINT organizations_validity_ck CHECK (valid_until IS NULL OR valid_until > valid_from)
);

CREATE TABLE organization.organizational_units (
    organizational_unit_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES organization.organizations(organization_id),
    parent_unit_id uuid REFERENCES organization.organizational_units(organizational_unit_id),
    unit_key text NOT NULL,
    display_name text NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE',
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    UNIQUE(organization_id, unit_key),
    CONSTRAINT org_units_validity_ck CHECK (valid_until IS NULL OR valid_until > valid_from)
);

CREATE TABLE organization.organization_relationships (
    organization_relationship_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_organization_id uuid NOT NULL REFERENCES organization.organizations(organization_id),
    target_organization_id uuid NOT NULL REFERENCES organization.organizations(organization_id),
    relationship_type text NOT NULL,
    scope_description text,
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    status text NOT NULL DEFAULT 'ACTIVE',
    created_by_reference text NOT NULL,
    CONSTRAINT org_relationship_no_self_ck CHECK (source_organization_id <> target_organization_id),
    CONSTRAINT org_relationship_validity_ck CHECK (valid_until IS NULL OR valid_until > valid_from)
);

CREATE TABLE organization.jurisdictions (
    jurisdiction_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    jurisdiction_key text NOT NULL UNIQUE,
    display_name text NOT NULL,
    jurisdiction_type text NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE',
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    created_by_reference text NOT NULL
);

CREATE TABLE organization.jurisdiction_authorities (
    jurisdiction_authority_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES organization.organizations(organization_id),
    jurisdiction_id uuid NOT NULL REFERENCES organization.jurisdictions(jurisdiction_id),
    authority_purpose text NOT NULL,
    priority integer NOT NULL DEFAULT 100,
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    status text NOT NULL DEFAULT 'ACTIVE',
    created_by_reference text NOT NULL,
    UNIQUE(organization_id,jurisdiction_id,authority_purpose,valid_from)
);

SELECT foundation_meta.register_migration(
    p_migration_id       => '030_organizations_and_jurisdictions',
    p_migration_name     => 'Organizations and jurisdictions',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created organizations and jurisdictions objects.'
);

COMMIT;
