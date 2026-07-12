-- ============================================================================
-- Migration: 030_organizations_and_governed_scopes.sql
-- Title: Organizations and governed scopes
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

CREATE TABLE organization.governed_scopes (
    governed_scope_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    governed_scope_key text NOT NULL UNIQUE,
    display_name text NOT NULL,
    governed_scope_type text NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE',
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    created_by_reference text NOT NULL
);

CREATE TABLE organization.governed_scope_authorities (
    governed_scope_authority_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES organization.organizations(organization_id),
    governed_scope_id uuid NOT NULL REFERENCES organization.governed_scopes(governed_scope_id),
    authority_purpose text NOT NULL,
    priority integer NOT NULL DEFAULT 100,
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    status text NOT NULL DEFAULT 'ACTIVE',
    created_by_reference text NOT NULL,
    UNIQUE(organization_id,governed_scope_id,authority_purpose,valid_from)
);


-- Phase -1 Foundation baseline integrity

ALTER TABLE organization.organizations
    ADD CONSTRAINT organizations_key_format_ck
    CHECK (organization_key ~ '^[a-z][a-z0-9_.-]*$'),
    ADD CONSTRAINT organizations_type_nonempty_ck
    CHECK (btrim(organization_type) <> '');

ALTER TABLE organization.organizational_units
    ADD CONSTRAINT organizational_units_org_id_unit_id_uq
    UNIQUE (organization_id, organizational_unit_id),
    ADD CONSTRAINT organizational_units_key_format_ck
    CHECK (unit_key ~ '^[a-z][a-z0-9_.-]*$'),
    ADD CONSTRAINT organizational_units_status_nonempty_ck
    CHECK (btrim(status) <> ''),
    ADD CONSTRAINT organizational_units_parent_not_self_ck
    CHECK (
        parent_unit_id IS NULL
        OR parent_unit_id <> organizational_unit_id
    ),
    ADD CONSTRAINT organizational_units_parent_same_org_fk
    FOREIGN KEY (organization_id, parent_unit_id)
    REFERENCES organization.organizational_units(
        organization_id,
        organizational_unit_id
    );

ALTER TABLE organization.organization_relationships
    ADD CONSTRAINT organization_relationship_type_nonempty_ck
    CHECK (btrim(relationship_type) <> ''),
    ADD CONSTRAINT organization_relationship_status_nonempty_ck
    CHECK (btrim(status) <> '');

ALTER TABLE organization.governed_scopes
    ADD CONSTRAINT governed_scopes_key_format_ck
    CHECK (governed_scope_key ~ '^[a-z][a-z0-9_.-]*$'),
    ADD CONSTRAINT governed_scopes_type_nonempty_ck
    CHECK (btrim(governed_scope_type) <> ''),
    ADD CONSTRAINT governed_scopes_status_nonempty_ck
    CHECK (btrim(status) <> ''),
    ADD CONSTRAINT governed_scopes_validity_ck
    CHECK (
        valid_until IS NULL
        OR valid_until > valid_from
    );

ALTER TABLE organization.governed_scope_authorities
    ADD CONSTRAINT governed_scope_authority_purpose_nonempty_ck
    CHECK (btrim(authority_purpose) <> ''),
    ADD CONSTRAINT governed_scope_authority_priority_positive_ck
    CHECK (priority > 0),
    ADD CONSTRAINT governed_scope_authority_status_nonempty_ck
    CHECK (btrim(status) <> ''),
    ADD CONSTRAINT governed_scope_authority_validity_ck
    CHECK (
        valid_until IS NULL
        OR valid_until > valid_from
    );

-- Domain-neutral governed-scope definitions
COMMENT ON TABLE organization.governed_scopes IS
    'A domain-neutral legal, administrative, geographic, organizational, contractual, data, or service boundary used by policy and authority evaluation. Modules specialize governed_scope_type.';

COMMENT ON COLUMN organization.governed_scopes.governed_scope_type IS
    'A governed type key. JURISDICTION may be used by a module, but it is not the universal Foundation meaning.';

COMMENT ON TABLE organization.governed_scope_authorities IS
    'Effective-dated organizational authority within one governed scope and purpose.';

SELECT foundation_meta.register_migration(
    p_migration_id       => '030_organizations_and_governed_scopes',
    p_migration_name     => 'Organizations and governed scopes',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created organizations and governed scopes objects.'
);

COMMIT;
