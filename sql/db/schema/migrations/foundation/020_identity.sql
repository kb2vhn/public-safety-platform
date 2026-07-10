-- ============================================================================
-- Migration: 020_identity.sql
-- Title: Identity
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
        WHERE migration_id = '010_cryptographic_and_device_trust'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
                  MESSAGE = 'Required migration 010_cryptographic_and_device_trust is not registered';
    END IF;
END;
$dependency_check$;


CREATE TABLE identity.persons (
    person_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    person_key text NOT NULL UNIQUE,
    display_name text NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE',
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_by_reference text NOT NULL,
    CONSTRAINT persons_status_ck CHECK (status IN ('PENDING','ACTIVE','SUSPENDED','SEPARATED','RETIRED','DECEASED','ARCHIVED'))
);

CREATE TABLE identity.identities (
    identity_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    identity_key text NOT NULL UNIQUE,
    identity_type text NOT NULL,
    person_id uuid REFERENCES identity.persons(person_id),
    service_device_id uuid REFERENCES trust.devices(device_id),
    status text NOT NULL DEFAULT 'PENDING',
    assurance_level text NOT NULL DEFAULT 'UNSPECIFIED',
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_by_reference text NOT NULL,
    CONSTRAINT identities_type_ck CHECK (identity_type IN ('HUMAN','SERVICE','DEVICE','WORKLOAD')),
    CONSTRAINT identities_subject_ck CHECK (
        (identity_type='HUMAN' AND person_id IS NOT NULL AND service_device_id IS NULL)
        OR (identity_type IN ('SERVICE','DEVICE','WORKLOAD') AND person_id IS NULL)
    ),
    CONSTRAINT identities_status_ck CHECK (status IN ('PENDING','ACTIVE','SUSPENDED','DISABLED','RETIRED','ARCHIVED')),
    CONSTRAINT identities_validity_ck CHECK (valid_until IS NULL OR valid_until > valid_from)
);

CREATE TABLE identity.provider_identity_mappings (
    provider_identity_mapping_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    identity_id uuid NOT NULL REFERENCES identity.identities(identity_id),
    trust_provider_id uuid NOT NULL REFERENCES trust.trust_providers(trust_provider_id),
    provider_subject text NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    status text NOT NULL DEFAULT 'ACTIVE',
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_by_reference text NOT NULL,
    UNIQUE(trust_provider_id, provider_subject),
    CONSTRAINT provider_mapping_status_ck CHECK (status IN ('ACTIVE','SUSPENDED','REVOKED','EXPIRED','SUPERSEDED')),
    CONSTRAINT provider_mapping_validity_ck CHECK (valid_until IS NULL OR valid_until > valid_from)
);
CREATE INDEX identities_person_idx ON identity.identities(person_id) WHERE person_id IS NOT NULL;

SELECT foundation_meta.register_migration(
    p_migration_id       => '020_identity',
    p_migration_name     => 'Identity',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created identity objects.'
);

COMMIT;
