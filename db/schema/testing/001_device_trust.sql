-- ============================================================
-- 001_device_trust.sql
--
-- Public Safety Platform
--
-- Purpose:
-- Establish trusted machine identity and device attestation.
--
-- Security Principle:
--
-- A trusted device is not a trusted user.
--
-- Device certificates prove:
--     "This machine is authorized."
--
-- They do NOT prove:
--     "This person may access CAD."
--
-- Human authorization occurs separately.
--
-- Dependencies:
--     000_trust_foundation.sql
--
-- ============================================================


------------------------------------------------------------
-- DEVICE STATES
------------------------------------------------------------

CREATE TYPE device_status AS ENUM (
    'PENDING',
    'ACTIVE',
    'QUARANTINED',
    'DISABLED',
    'RETIRED'
);



------------------------------------------------------------
-- DEVICE TYPES
--
-- Allows policy decisions based on function.
--
-- Examples:
--
-- CAD_CONSOLE
-- SUPERVISOR_TERMINAL
-- ADMIN_WORKSTATION
-- SERVER
-- JUMP_HOST
-- MOBILE_COMMAND
--
------------------------------------------------------------

CREATE TABLE device_types (

    device_type_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    type_name VARCHAR(100) NOT NULL UNIQUE,

    description TEXT NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- DEVICES
--
-- Represents a physical/logical endpoint.
--
-- Examples:
--
-- CAD-OPS-01
-- CAD-OPS-02
-- ADMIN-JUMP-01
--
------------------------------------------------------------

CREATE TABLE devices (

    device_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    agency_id UUID NOT NULL
        REFERENCES agencies(agency_id),

    device_type_id UUID NOT NULL
        REFERENCES device_types(device_type_id),

    hostname VARCHAR(100) NOT NULL,

    asset_tag VARCHAR(100),

    serial_number VARCHAR(200),

    status device_status NOT NULL DEFAULT 'PENDING',

    location VARCHAR(200),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE(agency_id, hostname)

);



------------------------------------------------------------
-- DEVICE CERTIFICATE AUTHORITY
--
-- Tracks which CA issued machine certificates.
--
-- Supports:
--
-- Internal Microsoft CA
-- Linux CA
-- Hardware security module backed CA
--
------------------------------------------------------------

CREATE TABLE certificate_authorities (

    ca_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    agency_id UUID NOT NULL
        REFERENCES agencies(agency_id),

    ca_name VARCHAR(200) NOT NULL,

    issuer_subject TEXT NOT NULL,

    fingerprint VARCHAR(255) NOT NULL UNIQUE,

    trusted BOOLEAN NOT NULL DEFAULT true,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- DEVICE CERTIFICATES
--
-- Machine identity.
--
-- Example:
--
-- CAD-OPS-01 certificate
--
-- Valid:
-- 30 days
--
-- Auto-renewed:
-- Yes
--
------------------------------------------------------------

CREATE TABLE device_certificates (

    certificate_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    device_id UUID NOT NULL
        REFERENCES devices(device_id),

    ca_id UUID NOT NULL
        REFERENCES certificate_authorities(ca_id),

    certificate_subject TEXT NOT NULL,

    certificate_thumbprint VARCHAR(255)
        NOT NULL UNIQUE,

    issued_at TIMESTAMPTZ NOT NULL,

    expires_at TIMESTAMPTZ NOT NULL,

    revoked BOOLEAN NOT NULL DEFAULT false,

    revoked_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),


    CONSTRAINT certificate_validity_check
    CHECK (expires_at > issued_at)

);



------------------------------------------------------------
-- DEVICE NETWORK TRUST
--
-- Optional additional validation.
--
-- Example:
--
-- CAD consoles must originate from:
--
-- 10.20.30.0/24
--
------------------------------------------------------------

CREATE TABLE device_network_assignments (

    network_assignment_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    device_id UUID NOT NULL
        REFERENCES devices(device_id),

    allowed_network CIDR NOT NULL,

    description VARCHAR(200),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- DEVICE OWNERSHIP / ASSIGNMENT
--
-- Tracks responsibility.
--
-- NOT authorization.
--
-- Example:
--
-- This terminal belongs to Communications.
--
------------------------------------------------------------

CREATE TABLE device_assignments (

    assignment_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    device_id UUID NOT NULL
        REFERENCES devices(device_id),

    assigned_unit VARCHAR(200),

    assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    retired_at TIMESTAMPTZ

);



------------------------------------------------------------
-- DEVICE ATTESTATIONS
--
-- Proof statements about the device.
--
-- Examples:
--
-- "Certificate valid"
-- "EDR healthy"
-- "OS patched"
-- "Located on CAD network"
--
------------------------------------------------------------

CREATE TABLE device_attestations (

    attestation_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    device_id UUID NOT NULL
        REFERENCES devices(device_id),

    authority_id UUID NOT NULL
        REFERENCES trust_authorities(authority_id),

    attestation_type VARCHAR(100) NOT NULL,

    attestation_data JSONB NOT NULL,

    valid_from TIMESTAMPTZ NOT NULL,

    valid_until TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- DEVICE POLICY REQUIREMENTS
--
-- Defines what a device must satisfy.
--
-- Example:
--
-- CAD Console:
--     certificate required
--     EDR required
--     network restricted
--
------------------------------------------------------------

CREATE TABLE device_security_requirements (

    requirement_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    device_type_id UUID NOT NULL
        REFERENCES device_types(device_type_id),

    requirement_name VARCHAR(150) NOT NULL,

    requirement_value JSONB NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- DEVICE EVENTS
--
-- Lifecycle tracking.
--
-- Enrollment
-- Certificate Renewal
-- Disable
-- Revoke
--
------------------------------------------------------------

CREATE TABLE device_events (

    event_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    device_id UUID NOT NULL
        REFERENCES devices(device_id),

    event_type VARCHAR(100) NOT NULL,

    event_data JSONB NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- INDEXES
------------------------------------------------------------


CREATE INDEX idx_device_hostname
ON devices(hostname);


CREATE INDEX idx_device_status
ON devices(status);


CREATE INDEX idx_certificate_thumbprint
ON device_certificates(certificate_thumbprint);


CREATE INDEX idx_certificate_expiration
ON device_certificates(expires_at);


CREATE INDEX idx_device_attestation_lookup
ON device_attestations(device_id, valid_until);