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


-- Phase -1 Foundation baseline integrity

ALTER TABLE identity.identities
    DROP CONSTRAINT identities_subject_ck,
    ADD CONSTRAINT identities_subject_ck
    CHECK (
        (
            identity_type = 'HUMAN'
            AND person_id IS NOT NULL
            AND service_device_id IS NULL
        )
        OR
        (
            identity_type = 'DEVICE'
            AND person_id IS NULL
            AND service_device_id IS NOT NULL
        )
        OR
        (
            identity_type IN ('SERVICE', 'WORKLOAD')
            AND person_id IS NULL
        )
    ),
    ADD CONSTRAINT identities_id_person_uq
    UNIQUE (identity_id, person_id);

COMMENT ON COLUMN identity.identities.service_device_id IS
    'Device subject for DEVICE identities and an optional execution-device reference for SERVICE or WORKLOAD identities. A future stable baseline may rename this column after runtime subject semantics are finalized.';

ALTER TABLE identity.provider_identity_mappings
    ADD CONSTRAINT provider_mapping_subject_nonempty_ck
    CHECK (btrim(provider_subject) <> '');

DO $remove_original_provider_mapping_unique$
DECLARE
    v_constraint_name name;
BEGIN
    SELECT constraint_record.conname
    INTO v_constraint_name
    FROM pg_constraint AS constraint_record
    WHERE constraint_record.conrelid =
        'identity.provider_identity_mappings'::regclass
      AND constraint_record.contype = 'u'
      AND pg_get_constraintdef(constraint_record.oid) =
        'UNIQUE (trust_provider_id, provider_subject)';

    IF v_constraint_name IS NULL THEN
        RAISE EXCEPTION
        USING
            ERRCODE = 'undefined_object',
            MESSAGE = 'Expected provider identity mapping unique constraint was not found';
    END IF;

    EXECUTE format(
        'ALTER TABLE identity.provider_identity_mappings DROP CONSTRAINT %I',
        v_constraint_name
    );
END;
$remove_original_provider_mapping_unique$;

ALTER TABLE identity.provider_identity_mappings
    ADD CONSTRAINT provider_mapping_history_uq
    UNIQUE (
        trust_provider_id,
        provider_subject,
        valid_from
    );

CREATE UNIQUE INDEX provider_identity_mappings_current_uq
    ON identity.provider_identity_mappings(
        trust_provider_id,
        provider_subject
    )
    WHERE
        valid_until IS NULL
        AND status IN ('ACTIVE', 'SUSPENDED');

SELECT foundation_meta.register_migration(
    p_migration_id       => '020_identity',
    p_migration_name     => 'Identity',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created identity objects.'
);

COMMIT;
