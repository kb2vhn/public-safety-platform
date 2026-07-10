-- ============================================================
-- 000_trust_foundation.sql
--
-- Public Safety Platform
--
-- Purpose:
-- Establish the foundational trust objects used by all future
-- authorization decisions.
--
-- Security Principle:
-- No single identity, administrator, device, or authority
-- is sufficient to grant operational access.
--
-- Access decisions are based on independent attestations.
--
-- This file owns:
--
--   agencies
--   persons
--   identities
--   trust authorities
--   devices
--   device certificates
--   trust attestations
--   trust events
--
-- ============================================================


BEGIN;


------------------------------------------------------------
-- EXTENSIONS
------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


------------------------------------------------------------
-- TRUST AUTHORITY TYPES
------------------------------------------------------------

CREATE TYPE trust_authority_type AS ENUM (

    'IDENTITY_AUTHORITY',
    'TECHNICAL_AUTHORITY',
    'OPERATIONAL_AUTHORITY',
    'SHIFT_AUTHORITY',
    'SECURITY_AUTHORITY'

);



------------------------------------------------------------
-- AGENCIES
------------------------------------------------------------

CREATE TABLE agencies (

    agency_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    agency_name VARCHAR(200)
        NOT NULL UNIQUE,

    ori_number VARCHAR(9)
        UNIQUE,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- PERSONS
--
-- Human identity.
--
-- NOT authentication.
-- NOT authorization.
-- NOT database login.
------------------------------------------------------------

CREATE TABLE persons (

    person_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    agency_id UUID NOT NULL
        REFERENCES agencies(agency_id),

    employee_number VARCHAR(100),

    legal_name VARCHAR(200)
        NOT NULL,

    employment_status VARCHAR(50)
        NOT NULL DEFAULT 'ACTIVE',

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now(),

    updated_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- EXTERNAL IDENTITIES
--
-- Authentication providers:
--
-- AD
-- LDAP
-- Entra
-- Future providers
------------------------------------------------------------

CREATE TABLE identities (

    identity_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    person_id UUID NOT NULL
        REFERENCES persons(person_id),

    provider_name VARCHAR(100)
        NOT NULL,

    provider_identifier VARCHAR(255)
        NOT NULL,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now(),

    UNIQUE(provider_name, provider_identifier)

);



------------------------------------------------------------
-- TRUST AUTHORITIES
------------------------------------------------------------

CREATE TABLE trust_authorities (

    authority_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    agency_id UUID NOT NULL
        REFERENCES agencies(agency_id),

    authority_type trust_authority_type
        NOT NULL,

    authority_name VARCHAR(200)
        NOT NULL,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- DEVICES
--
-- Represents a trusted workstation.
--
-- Device proves:
-- "I am CAD-CONSOLE-05"
--
-- Device does NOT prove:
-- "John may dispatch."
------------------------------------------------------------

CREATE TABLE devices (

    device_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    agency_id UUID NOT NULL
        REFERENCES agencies(agency_id),

    hostname VARCHAR(100)
        NOT NULL,

    device_serial VARCHAR(200),

    device_type VARCHAR(100),

    device_status VARCHAR(50)
        NOT NULL DEFAULT 'ACTIVE',

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now(),

    UNIQUE(agency_id, hostname)

);



------------------------------------------------------------
-- DEVICE CERTIFICATES
------------------------------------------------------------

CREATE TABLE device_certificates (

    certificate_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    device_id UUID NOT NULL
        REFERENCES devices(device_id),

    certificate_thumbprint VARCHAR(255)
        NOT NULL UNIQUE,

    issuer VARCHAR(255)
        NOT NULL,

    issued_at TIMESTAMPTZ
        NOT NULL,

    expires_at TIMESTAMPTZ
        NOT NULL,

    revoked BOOLEAN
        NOT NULL DEFAULT false,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now(),

    CONSTRAINT valid_certificate_dates
    CHECK (expires_at > issued_at)

);



------------------------------------------------------------
-- TRUST ATTESTATIONS
------------------------------------------------------------

CREATE TABLE trust_attestations (

    attestation_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    subject_person_id UUID
        REFERENCES persons(person_id),

    subject_device_id UUID
        REFERENCES devices(device_id),

    authority_id UUID NOT NULL
        REFERENCES trust_authorities(authority_id),

    statement_type VARCHAR(100)
        NOT NULL,

    statement_value JSONB
        NOT NULL,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- TRUST EVENTS
--
-- Append-only foundation security events.
------------------------------------------------------------

CREATE TABLE trust_events (

    event_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    previous_event_hash BYTEA,

    event_hash BYTEA
        NOT NULL,

    event_type VARCHAR(100)
        NOT NULL,

    actor_person_id UUID
        REFERENCES persons(person_id),

    device_id UUID
        REFERENCES devices(device_id),

    event_data JSONB
        NOT NULL,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- INDEXES
------------------------------------------------------------

CREATE INDEX idx_identity_provider
ON identities(provider_name, provider_identifier);


CREATE INDEX idx_device_certificate
ON device_certificates(certificate_thumbprint);


CREATE INDEX idx_attestation_person
ON trust_attestations(subject_person_id);


CREATE INDEX idx_attestation_device
ON trust_attestations(subject_device_id);


CREATE INDEX idx_events_time
ON trust_events(created_at);


CREATE INDEX idx_events_actor
ON trust_events(actor_person_id);


CREATE INDEX idx_events_device
ON trust_events(device_id);



COMMIT;
