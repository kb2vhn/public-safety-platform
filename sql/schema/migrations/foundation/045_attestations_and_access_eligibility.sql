-- ============================================================================
-- Migration: 045_attestations_and_access_eligibility.sql
-- Title: Attestations and access eligibility
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
        WHERE migration_id = '040_service_participation_and_federation'
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'object_not_in_prerequisite_state',
                MESSAGE = 'Required migration 040_service_participation_and_federation is not registered';
    END IF;
END;
$dependency_check$;

CREATE TABLE attestation.attestation_authorities (
    attestation_authority_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    authority_category text NOT NULL,
    authorizing_organization_id uuid NOT NULL
        REFERENCES organization.organizations(organization_id),
    attesting_organization_id uuid NOT NULL
        REFERENCES organization.organizations(organization_id),
    service_id uuid
        REFERENCES service.platform_services(service_id),
    authorized_identity_id uuid
        REFERENCES identity.identities(identity_id),
    governed_scope_id uuid
        REFERENCES organization.governed_scopes(governed_scope_id),
    applies_to_all_governed_scopes boolean NOT NULL DEFAULT false,
    scope_reference text,
    status text NOT NULL DEFAULT 'ACTIVE',
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    created_by_reference text NOT NULL,
    CONSTRAINT attestation_authorities_category_ck
        CHECK (authority_category ~ '^[A-Z][A-Z0-9_]*$'),
    CONSTRAINT attestation_authorities_boundary_ck
        CHECK (
            governed_scope_id IS NOT NULL
            OR applies_to_all_governed_scopes
            OR NULLIF(btrim(scope_reference), '') IS NOT NULL
        ),
    CONSTRAINT attestation_authorities_all_scope_ck
        CHECK (
            NOT (
                governed_scope_id IS NOT NULL
                AND applies_to_all_governed_scopes
            )
        ),
    CONSTRAINT attestation_authorities_status_ck
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
    CONSTRAINT attestation_authorities_validity_ck
        CHECK (valid_until IS NULL OR valid_until > valid_from)
);

CREATE TABLE attestation.organizational_attestations (
    organizational_attestation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    attestation_authority_id uuid NOT NULL
        REFERENCES attestation.attestation_authorities(attestation_authority_id),
    subject_identity_id uuid NOT NULL,
    subject_person_id uuid,
    attestation_category text NOT NULL,
    attestation_value jsonb NOT NULL,
    governed_scope_id uuid
        REFERENCES organization.governed_scopes(governed_scope_id),
    applies_to_all_governed_scopes boolean NOT NULL DEFAULT false,
    scope_reference text,
    status text NOT NULL DEFAULT 'VALID',
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    review_at timestamptz,
    recorded_by_identity_id uuid
        REFERENCES identity.identities(identity_id),
    reason text,
    CONSTRAINT organizational_attestations_identity_person_fk
        FOREIGN KEY (subject_identity_id, subject_person_id)
        REFERENCES identity.identities(identity_id, person_id),
    CONSTRAINT organizational_attestations_category_ck
        CHECK (attestation_category ~ '^[A-Z][A-Z0-9_]*$'),
    CONSTRAINT organizational_attestations_boundary_ck
        CHECK (
            governed_scope_id IS NOT NULL
            OR applies_to_all_governed_scopes
            OR NULLIF(btrim(scope_reference), '') IS NOT NULL
        ),
    CONSTRAINT organizational_attestations_all_scope_ck
        CHECK (
            NOT (
                governed_scope_id IS NOT NULL
                AND applies_to_all_governed_scopes
            )
        ),
    CONSTRAINT organizational_attestations_status_ck
        CHECK (
            status IN (
                'VALID',
                'SUSPENDED',
                'REVOKED',
                'EXPIRED',
                'SUPERSEDED'
            )
        ),
    CONSTRAINT organizational_attestations_validity_ck
        CHECK (valid_until IS NULL OR valid_until > valid_from)
);

CREATE TABLE attestation.access_eligibility_grants (
    access_eligibility_grant_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    identity_id uuid NOT NULL,
    person_id uuid,
    service_id uuid NOT NULL
        REFERENCES service.platform_services(service_id),
    participating_organization_id uuid NOT NULL
        REFERENCES organization.organizations(organization_id),
    eligibility_key text NOT NULL,
    governed_scope_id uuid
        REFERENCES organization.governed_scopes(governed_scope_id),
    applies_to_all_governed_scopes boolean NOT NULL DEFAULT false,
    scope_reference text,
    status text NOT NULL DEFAULT 'PENDING',
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    review_at timestamptz,
    created_by_reference text NOT NULL,
    CONSTRAINT access_eligibility_identity_person_fk
        FOREIGN KEY (identity_id, person_id)
        REFERENCES identity.identities(identity_id, person_id),
    CONSTRAINT access_eligibility_key_ck
        CHECK (eligibility_key ~ '^[a-z][a-z0-9_.-]*$'),
    CONSTRAINT access_eligibility_boundary_ck
        CHECK (
            governed_scope_id IS NOT NULL
            OR applies_to_all_governed_scopes
            OR NULLIF(btrim(scope_reference), '') IS NOT NULL
        ),
    CONSTRAINT access_eligibility_all_scope_ck
        CHECK (
            NOT (
                governed_scope_id IS NOT NULL
                AND applies_to_all_governed_scopes
            )
        ),
    CONSTRAINT access_eligibility_status_ck
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
    CONSTRAINT access_eligibility_validity_ck
        CHECK (valid_until IS NULL OR valid_until > valid_from),
    CONSTRAINT access_eligibility_history_uq
        UNIQUE (
            identity_id,
            service_id,
            eligibility_key,
            valid_from
        )
);

CREATE TABLE attestation.eligibility_supporting_attestations (
    access_eligibility_grant_id uuid NOT NULL
        REFERENCES attestation.access_eligibility_grants(access_eligibility_grant_id),
    organizational_attestation_id uuid NOT NULL
        REFERENCES attestation.organizational_attestations(organizational_attestation_id),
    required boolean NOT NULL DEFAULT true,
    PRIMARY KEY (
        access_eligibility_grant_id,
        organizational_attestation_id
    )
);

COMMENT ON COLUMN attestation.attestation_authorities.scope_reference IS
    'Deprecated compatibility field. New records must use governed_scope_id or applies_to_all_governed_scopes.';
COMMENT ON COLUMN attestation.organizational_attestations.scope_reference IS
    'Deprecated compatibility field. New records must use governed_scope_id or applies_to_all_governed_scopes.';
COMMENT ON COLUMN attestation.access_eligibility_grants.scope_reference IS
    'Deprecated compatibility field. New records must use governed_scope_id or applies_to_all_governed_scopes.';

CREATE INDEX access_eligibility_current_idx
    ON attestation.access_eligibility_grants(
        identity_id,
        service_id,
        governed_scope_id,
        status,
        valid_until
    );

SELECT foundation_meta.register_migration(
    p_migration_id => '045_attestations_and_access_eligibility',
    p_migration_name => 'Attestations and access eligibility',
    p_migration_layer => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes => 'Created organizational attestation and Access Eligibility objects with explicit identity-person consistency and Governed Scope boundaries.'
);

COMMIT;
