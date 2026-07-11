-- ============================================================================
-- Migration: 045_attestations_and_access_eligibility.sql
-- Title: Attestations and access eligibility
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
        WHERE migration_id = '040_service_participation_and_federation'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
                  MESSAGE = 'Required migration 040_service_participation_and_federation is not registered';
    END IF;
END;
$dependency_check$;


CREATE TABLE attestation.attestation_authorities (
    attestation_authority_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    authority_category text NOT NULL,
    authorizing_organization_id uuid NOT NULL REFERENCES organization.organizations(organization_id),
    attesting_organization_id uuid NOT NULL REFERENCES organization.organizations(organization_id),
    service_id uuid REFERENCES service.platform_services(service_id),
    authorized_identity_id uuid REFERENCES identity.identities(identity_id),
    scope_reference text NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE',
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    created_by_reference text NOT NULL
);

CREATE TABLE attestation.organizational_attestations (
    organizational_attestation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    attestation_authority_id uuid NOT NULL REFERENCES attestation.attestation_authorities(attestation_authority_id),
    subject_identity_id uuid NOT NULL REFERENCES identity.identities(identity_id),
    subject_person_id uuid REFERENCES identity.persons(person_id),
    attestation_category text NOT NULL,
    attestation_value jsonb NOT NULL,
    scope_reference text NOT NULL,
    status text NOT NULL DEFAULT 'VALID',
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    review_at timestamptz,
    recorded_by_identity_id uuid REFERENCES identity.identities(identity_id),
    reason text
);

CREATE TABLE attestation.access_eligibility_grants (
    access_eligibility_grant_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    identity_id uuid NOT NULL REFERENCES identity.identities(identity_id),
    person_id uuid REFERENCES identity.persons(person_id),
    service_id uuid NOT NULL REFERENCES service.platform_services(service_id),
    participating_organization_id uuid NOT NULL REFERENCES organization.organizations(organization_id),
    eligibility_key text NOT NULL,
    scope_reference text NOT NULL,
    status text NOT NULL DEFAULT 'PENDING',
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    review_at timestamptz,
    created_by_reference text NOT NULL,
    UNIQUE(identity_id,service_id,eligibility_key,valid_from)
);

CREATE TABLE attestation.eligibility_supporting_attestations (
    access_eligibility_grant_id uuid NOT NULL REFERENCES attestation.access_eligibility_grants(access_eligibility_grant_id),
    organizational_attestation_id uuid NOT NULL REFERENCES attestation.organizational_attestations(organizational_attestation_id),
    required boolean NOT NULL DEFAULT true,
    PRIMARY KEY(access_eligibility_grant_id,organizational_attestation_id)
);


-- Phase -1 Foundation baseline integrity

ALTER TABLE attestation.attestation_authorities
    ADD CONSTRAINT attestation_authorities_category_nonempty_ck
    CHECK (btrim(authority_category) <> ''),
    ADD CONSTRAINT attestation_authorities_scope_nonempty_ck
    CHECK (btrim(scope_reference) <> ''),
    ADD CONSTRAINT attestation_authorities_status_nonempty_ck
    CHECK (btrim(status) <> ''),
    ADD CONSTRAINT attestation_authorities_validity_ck
    CHECK (
        valid_until IS NULL
        OR valid_until > valid_from
    );

ALTER TABLE attestation.organizational_attestations
    ADD CONSTRAINT organizational_attestations_identity_person_fk
    FOREIGN KEY (subject_identity_id, subject_person_id)
    REFERENCES identity.identities(identity_id, person_id),
    ADD CONSTRAINT organizational_attestations_category_nonempty_ck
    CHECK (btrim(attestation_category) <> ''),
    ADD CONSTRAINT organizational_attestations_scope_nonempty_ck
    CHECK (btrim(scope_reference) <> ''),
    ADD CONSTRAINT organizational_attestations_status_nonempty_ck
    CHECK (btrim(status) <> ''),
    ADD CONSTRAINT organizational_attestations_validity_ck
    CHECK (
        valid_until IS NULL
        OR valid_until > valid_from
    ),
    ADD CONSTRAINT organizational_attestations_review_ck
    CHECK (
        review_at IS NULL
        OR review_at >= valid_from
    );

ALTER TABLE attestation.access_eligibility_grants
    ADD CONSTRAINT access_eligibility_identity_person_fk
    FOREIGN KEY (identity_id, person_id)
    REFERENCES identity.identities(identity_id, person_id),
    ADD CONSTRAINT access_eligibility_key_format_ck
    CHECK (eligibility_key ~ '^[a-z][a-z0-9_.-]*$'),
    ADD CONSTRAINT access_eligibility_scope_nonempty_ck
    CHECK (btrim(scope_reference) <> ''),
    ADD CONSTRAINT access_eligibility_status_nonempty_ck
    CHECK (btrim(status) <> ''),
    ADD CONSTRAINT access_eligibility_validity_ck
    CHECK (
        valid_until IS NULL
        OR valid_until > valid_from
    ),
    ADD CONSTRAINT access_eligibility_review_ck
    CHECK (
        review_at IS NULL
        OR review_at >= valid_from
    );

CREATE INDEX access_eligibility_current_lookup_idx
    ON attestation.access_eligibility_grants(
        identity_id,
        service_id,
        participating_organization_id,
        status,
        valid_until
    );

SELECT foundation_meta.register_migration(
    p_migration_id       => '045_attestations_and_access_eligibility',
    p_migration_name     => 'Attestations and access eligibility',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created attestations and access eligibility objects.'
);

COMMIT;
