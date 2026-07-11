-- ============================================================================
-- Migration: 010_cryptographic_and_device_trust.sql
-- Title: Cryptographic and device trust
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
        WHERE migration_id = '000_platform_initialization'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
                  MESSAGE = 'Required migration 000_platform_initialization is not registered';
    END IF;
END;
$dependency_check$;


CREATE TABLE trust.trust_providers (
    trust_provider_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_key text NOT NULL UNIQUE,
    display_name text NOT NULL,
    provider_type text NOT NULL,
    environment_key text NOT NULL,
    status text NOT NULL DEFAULT 'PENDING',
    valid_from timestamptz NOT NULL,
    valid_until timestamptz,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_by_reference text NOT NULL,
    notes text,
    CONSTRAINT trust_providers_key_ck CHECK (provider_key ~ '^[a-z][a-z0-9_.-]*$'),
    CONSTRAINT trust_providers_type_ck CHECK (provider_type IN ('INTERNAL_PKI','EXTERNAL_PKI','IDENTITY_PROVIDER','SERVICE_PROVIDER')),
    CONSTRAINT trust_providers_status_ck CHECK (status IN ('PENDING','ACTIVE','SUSPENDED','REVOKED','EXPIRED','RETIRED')),
    CONSTRAINT trust_providers_validity_ck CHECK (valid_until IS NULL OR valid_until > valid_from)
);

CREATE TABLE trust.certificate_authorities (
    certificate_authority_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    trust_provider_id uuid NOT NULL REFERENCES trust.trust_providers(trust_provider_id),
    authority_key text NOT NULL,
    subject_distinguished_name text NOT NULL,
    issuer_distinguished_name text,
    serial_number_hex text NOT NULL,
    sha256_fingerprint text NOT NULL UNIQUE,
    public_key_algorithm text NOT NULL,
    public_key_size_bits integer,
    signature_algorithm text NOT NULL,
    is_root_authority boolean NOT NULL,
    status text NOT NULL DEFAULT 'PENDING',
    valid_from timestamptz NOT NULL,
    valid_until timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_by_reference text NOT NULL,
    UNIQUE(trust_provider_id, authority_key),
    CONSTRAINT ca_fingerprint_ck CHECK (sha256_fingerprint ~ '^[0-9a-f]{64}$'),
    CONSTRAINT ca_status_ck CHECK (status IN ('PENDING','ACTIVE','SUSPENDED','REVOKED','EXPIRED','RETIRED')),
    CONSTRAINT ca_validity_ck CHECK (valid_until > valid_from)
);

CREATE TABLE trust.devices (
    device_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    device_key text NOT NULL UNIQUE,
    device_type text NOT NULL,
    manufacturer text,
    model text,
    serial_number text,
    asset_identifier text,
    operating_system_family text,
    status text NOT NULL DEFAULT 'PENDING',
    enrolled_at timestamptz,
    trusted_from timestamptz,
    trusted_until timestamptz,
    retired_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_by_reference text NOT NULL,
    CONSTRAINT devices_type_ck CHECK (device_type IN ('WORKSTATION','LAPTOP','MOBILE_DATA_TERMINAL','TABLET','MOBILE_DEVICE','SERVER','VIRTUAL_MACHINE','APPLIANCE','SERVICE_INSTANCE')),
    CONSTRAINT devices_status_ck CHECK (status IN ('PENDING','ENROLLED','TRUSTED','SUSPENDED','REVOKED','RETIRED','DISPOSED')),
    CONSTRAINT devices_trust_ck CHECK (trusted_until IS NULL OR (trusted_from IS NOT NULL AND trusted_until > trusted_from))
);

CREATE UNIQUE INDEX devices_serial_uq ON trust.devices(serial_number) WHERE serial_number IS NOT NULL;
CREATE UNIQUE INDEX devices_asset_uq ON trust.devices(asset_identifier) WHERE asset_identifier IS NOT NULL;

CREATE TABLE trust.device_certificates (
    device_certificate_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id uuid NOT NULL REFERENCES trust.devices(device_id),
    certificate_authority_id uuid NOT NULL REFERENCES trust.certificate_authorities(certificate_authority_id),
    certificate_role text NOT NULL,
    subject_distinguished_name text NOT NULL,
    subject_alternative_names text[] NOT NULL DEFAULT ARRAY[]::text[],
    serial_number_hex text NOT NULL,
    sha256_fingerprint text NOT NULL UNIQUE,
    public_key_algorithm text NOT NULL,
    public_key_size_bits integer,
    signature_algorithm text NOT NULL,
    status text NOT NULL DEFAULT 'PENDING',
    valid_from timestamptz NOT NULL,
    valid_until timestamptz NOT NULL,
    first_seen_at timestamptz,
    last_seen_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_by_reference text NOT NULL,
    UNIQUE(certificate_authority_id, serial_number_hex),
    CONSTRAINT device_cert_role_ck CHECK (certificate_role IN ('DEVICE_IDENTITY','CLIENT_AUTHENTICATION','SERVER_AUTHENTICATION','SERVICE_AUTHENTICATION','SIGNING')),
    CONSTRAINT device_cert_fingerprint_ck CHECK (sha256_fingerprint ~ '^[0-9a-f]{64}$'),
    CONSTRAINT device_cert_status_ck CHECK (status IN ('PENDING','ACTIVE','SUSPENDED','REVOKED','EXPIRED','SUPERSEDED')),
    CONSTRAINT device_cert_validity_ck CHECK (valid_until > valid_from)
);

CREATE TABLE trust.revocations (
    revocation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    object_type text NOT NULL,
    trust_provider_id uuid REFERENCES trust.trust_providers(trust_provider_id),
    certificate_authority_id uuid REFERENCES trust.certificate_authorities(certificate_authority_id),
    device_id uuid REFERENCES trust.devices(device_id),
    device_certificate_id uuid REFERENCES trust.device_certificates(device_certificate_id),
    reason_code text NOT NULL,
    reason_detail text,
    effective_at timestamptz NOT NULL,
    expires_at timestamptz,
    recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    recorded_by_reference text NOT NULL,
    CONSTRAINT revocations_type_ck CHECK (object_type IN ('TRUST_PROVIDER','CERTIFICATE_AUTHORITY','DEVICE','DEVICE_CERTIFICATE')),
    CONSTRAINT revocations_one_target_ck CHECK (num_nonnulls(trust_provider_id,certificate_authority_id,device_id,device_certificate_id)=1),
    CONSTRAINT revocations_validity_ck CHECK (expires_at IS NULL OR expires_at > effective_at)
);

CREATE TABLE trust.trust_lifecycle_events (
    trust_lifecycle_event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    object_type text NOT NULL,
    object_id uuid NOT NULL,
    event_type text NOT NULL,
    previous_status text,
    new_status text NOT NULL,
    effective_at timestamptz NOT NULL,
    recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    recorded_by_reference text NOT NULL,
    reason_code text NOT NULL,
    reason_detail text,
    CONSTRAINT trust_lifecycle_object_ck CHECK (object_type IN ('TRUST_PROVIDER','CERTIFICATE_AUTHORITY','DEVICE','DEVICE_CERTIFICATE'))
);

CREATE INDEX trust_revocations_device_idx ON trust.revocations(device_id,effective_at) WHERE device_id IS NOT NULL;
CREATE INDEX trust_revocations_cert_idx ON trust.revocations(device_certificate_id,effective_at) WHERE device_certificate_id IS NOT NULL;
CREATE INDEX trust_lifecycle_object_idx ON trust.trust_lifecycle_events(object_type,object_id,effective_at);


-- Phase -1 Foundation baseline integrity

ALTER TABLE trust.certificate_authorities
    ADD CONSTRAINT ca_public_key_size_positive_ck
    CHECK (
        public_key_size_bits IS NULL
        OR public_key_size_bits > 0
    );

ALTER TABLE trust.device_certificates
    ADD CONSTRAINT device_cert_public_key_size_positive_ck
    CHECK (
        public_key_size_bits IS NULL
        OR public_key_size_bits > 0
    ),
    ADD CONSTRAINT device_cert_observation_period_ck
    CHECK (
        last_seen_at IS NULL
        OR (
            first_seen_at IS NOT NULL
            AND last_seen_at >= first_seen_at
        )
    );

ALTER TABLE trust.revocations
    ADD CONSTRAINT revocations_type_target_ck
    CHECK (
        (
            object_type = 'TRUST_PROVIDER'
            AND trust_provider_id IS NOT NULL
            AND num_nonnulls(
                certificate_authority_id,
                device_id,
                device_certificate_id
            ) = 0
        )
        OR
        (
            object_type = 'CERTIFICATE_AUTHORITY'
            AND certificate_authority_id IS NOT NULL
            AND num_nonnulls(
                trust_provider_id,
                device_id,
                device_certificate_id
            ) = 0
        )
        OR
        (
            object_type = 'DEVICE'
            AND device_id IS NOT NULL
            AND num_nonnulls(
                trust_provider_id,
                certificate_authority_id,
                device_certificate_id
            ) = 0
        )
        OR
        (
            object_type = 'DEVICE_CERTIFICATE'
            AND device_certificate_id IS NOT NULL
            AND num_nonnulls(
                trust_provider_id,
                certificate_authority_id,
                device_id
            ) = 0
        )
    );

ALTER TABLE trust.trust_lifecycle_events
    ADD COLUMN trust_provider_id uuid
        REFERENCES trust.trust_providers(trust_provider_id),
    ADD COLUMN certificate_authority_id uuid
        REFERENCES trust.certificate_authorities(certificate_authority_id),
    ADD COLUMN device_id uuid
        REFERENCES trust.devices(device_id),
    ADD COLUMN device_certificate_id uuid
        REFERENCES trust.device_certificates(device_certificate_id),
    ADD CONSTRAINT trust_lifecycle_type_target_ck
    CHECK (
        (
            object_type = 'TRUST_PROVIDER'
            AND trust_provider_id IS NOT NULL
            AND object_id = trust_provider_id
            AND num_nonnulls(
                certificate_authority_id,
                device_id,
                device_certificate_id
            ) = 0
        )
        OR
        (
            object_type = 'CERTIFICATE_AUTHORITY'
            AND certificate_authority_id IS NOT NULL
            AND object_id = certificate_authority_id
            AND num_nonnulls(
                trust_provider_id,
                device_id,
                device_certificate_id
            ) = 0
        )
        OR
        (
            object_type = 'DEVICE'
            AND device_id IS NOT NULL
            AND object_id = device_id
            AND num_nonnulls(
                trust_provider_id,
                certificate_authority_id,
                device_certificate_id
            ) = 0
        )
        OR
        (
            object_type = 'DEVICE_CERTIFICATE'
            AND device_certificate_id IS NOT NULL
            AND object_id = device_certificate_id
            AND num_nonnulls(
                trust_provider_id,
                certificate_authority_id,
                device_id
            ) = 0
        )
    ),
    ADD CONSTRAINT trust_lifecycle_event_type_nonempty_ck
    CHECK (btrim(event_type) <> ''),
    ADD CONSTRAINT trust_lifecycle_new_status_nonempty_ck
    CHECK (btrim(new_status) <> ''),
    ADD CONSTRAINT trust_lifecycle_reason_code_nonempty_ck
    CHECK (btrim(reason_code) <> '');

CREATE INDEX trust_revocations_provider_idx
    ON trust.revocations(trust_provider_id, effective_at)
    WHERE trust_provider_id IS NOT NULL;

CREATE INDEX trust_revocations_ca_idx
    ON trust.revocations(certificate_authority_id, effective_at)
    WHERE certificate_authority_id IS NOT NULL;

SELECT foundation_meta.register_migration(
    p_migration_id       => '010_cryptographic_and_device_trust',
    p_migration_name     => 'Cryptographic and device trust',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created trust providers, authorities, devices, certificates, revocations, and lifecycle events.'
);

COMMIT;
