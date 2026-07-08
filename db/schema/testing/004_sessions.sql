-- ============================================================
-- 004_sessions.sql
--
-- Public Safety Platform
--
-- Purpose:
-- Creates short-lived operational sessions after successful
-- authorization evaluation.
--
-- Security Principle:
--
-- Authentication proves identity.
-- Authorization proves permission.
-- Session issuance creates temporary operational access.
--
-- Sessions are:
--
-- - short lived
-- - device bound
-- - auditable
-- - revocable
--
-- Dependencies:
--
-- 000_trust_foundation.sql
-- 001_device_trust.sql
-- 002_operational_authority.sql
-- 003_authorization.sql
--
-- ============================================================


CREATE EXTENSION IF NOT EXISTS "uuid-ossp";



------------------------------------------------------------
-- SESSION STATES
------------------------------------------------------------

CREATE TYPE session_state AS ENUM (

    'REQUESTED',

    'ACTIVE',

    'EXPIRED',

    'REVOKED',

    'TERMINATED'

);



------------------------------------------------------------
-- ACTIVE SESSIONS
--
-- Represents a live operational session.
--
-- Example:
--
-- John Smith
-- CAD Console 12
-- Dispatcher II
-- Shift B
--
-- Valid:
-- 18:00 - 06:00
--
------------------------------------------------------------

CREATE TABLE active_sessions (

    session_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),


    person_id UUID NOT NULL
        REFERENCES persons(person_id),


    device_id UUID NOT NULL
        REFERENCES devices(device_id),


    authorization_decision_id UUID NOT NULL
        REFERENCES authorization_decisions(
            decision_id
        ),


    session_state session_state
        NOT NULL DEFAULT 'REQUESTED',


    issued_at TIMESTAMPTZ
        NOT NULL DEFAULT now(),


    expires_at TIMESTAMPTZ
        NOT NULL,


    last_validation TIMESTAMPTZ
        NOT NULL DEFAULT now(),


    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now(),



    CONSTRAINT session_expiration_check
    CHECK (expires_at > issued_at)

);



------------------------------------------------------------
-- SESSION TOKENS
--
-- Stores references to short-lived credentials.
--
-- Do NOT store raw tokens.
--
-- Store hashes.
--
------------------------------------------------------------

CREATE TABLE session_tokens (

    token_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),


    session_id UUID NOT NULL
        REFERENCES active_sessions(session_id),


    token_hash BYTEA NOT NULL,


    token_type VARCHAR(100)
        NOT NULL,


    issued_at TIMESTAMPTZ
        NOT NULL DEFAULT now(),


    expires_at TIMESTAMPTZ
        NOT NULL,


    revoked BOOLEAN
        NOT NULL DEFAULT false,


    revoked_at TIMESTAMPTZ,


    UNIQUE(token_hash)

);



------------------------------------------------------------
-- SESSION CERTIFICATES
--
-- Optional certificate-backed session identity.
--
-- This supports your idea:
--
-- Machine certificate:
-- "This is CAD Console 5"
--
-- Session certificate:
-- "John is authorized on CAD Console 5 right now"
--
------------------------------------------------------------

CREATE TABLE session_certificates (

    session_certificate_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),


    session_id UUID NOT NULL
        REFERENCES active_sessions(session_id),


    certificate_thumbprint VARCHAR(255)
        NOT NULL UNIQUE,


    issuer VARCHAR(255)
        NOT NULL,


    issued_at TIMESTAMPTZ
        NOT NULL,


    expires_at TIMESTAMPTZ
        NOT NULL,


    revoked BOOLEAN
        NOT NULL DEFAULT false

);



------------------------------------------------------------
-- SESSION VALIDATION EVENTS
--
-- Continuous validation.
--
-- Examples:
--
-- User still logged in
-- Device still healthy
-- Certificate valid
-- Shift still active
--
------------------------------------------------------------

CREATE TABLE session_validation_events (

    validation_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),


    session_id UUID NOT NULL
        REFERENCES active_sessions(session_id),


    validation_type VARCHAR(100)
        NOT NULL,


    validation_result VARCHAR(50)
        NOT NULL,


    validation_data JSONB NOT NULL,


    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- SESSION REVOCATION
--
-- Emergency shutdown.
--
-- Security can revoke.
-- IT can revoke.
-- Supervisors may request.
--
-- Revocation is permanent history.
--
------------------------------------------------------------

CREATE TABLE session_revocations (

    revocation_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),


    session_id UUID NOT NULL
        REFERENCES active_sessions(session_id),


    revoked_by UUID NOT NULL
        REFERENCES persons(person_id),


    revocation_reason TEXT NOT NULL,


    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- SESSION RISK ASSESSMENTS
--
-- Allows continuous trust evaluation.
--
-- Example:
--
-- Initial score:
-- 95
--
-- Later:
-- Device unhealthy
-- Score drops
--
-- Session terminated.
--
------------------------------------------------------------

CREATE TABLE session_risk_assessments (

    risk_assessment_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),


    session_id UUID NOT NULL
        REFERENCES active_sessions(session_id),


    risk_score INTEGER NOT NULL,


    risk_factors JSONB NOT NULL,


    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);

------------------------------------------------------------
-- CANONICAL USER SESSIONS
--
-- This is the authoritative runtime identity session.
--
-- A session represents:
--
--   Who
--   Authenticated how
--   From what device
--   When
--
-- CAD operations reference this table.
--
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS sessions
(

    session_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),


    identity_id UUID NOT NULL
        REFERENCES identities(identity_id),


    device_id UUID
        REFERENCES devices(device_id),


    session_state session_state NOT NULL
        DEFAULT 'ACTIVE',


    authentication_method VARCHAR(100)
        NOT NULL,


    started_at TIMESTAMPTZ
        NOT NULL DEFAULT now(),


    expires_at TIMESTAMPTZ,


    ended_at TIMESTAMPTZ,


    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now(),


    CONSTRAINT valid_session_dates
    CHECK
    (
        expires_at IS NULL
        OR expires_at > started_at
    )

);



------------------------------------------------------------
-- SESSION INDEXES
------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_sessions_identity
ON sessions(identity_id);



CREATE INDEX IF NOT EXISTS idx_sessions_device
ON sessions(device_id);



CREATE INDEX IF NOT EXISTS idx_sessions_state
ON sessions(session_state);



------------------------------------------------------------
-- SESSION PROTECTION
------------------------------------------------------------

REVOKE UPDATE, DELETE
ON sessions
FROM PUBLIC;

------------------------------------------------------------
-- INDEXES
------------------------------------------------------------


CREATE INDEX idx_active_sessions_person
ON active_sessions(person_id);


CREATE INDEX idx_active_sessions_device
ON active_sessions(device_id);


CREATE INDEX idx_active_sessions_state
ON active_sessions(session_state);


CREATE INDEX idx_session_expiration
ON active_sessions(expires_at);


CREATE INDEX idx_session_tokens_hash
ON session_tokens(token_hash);


CREATE INDEX idx_validation_session
ON session_validation_events(session_id);
