-- ============================================================
-- 005_audit.sql
--
-- Public Safety Platform
--
-- Purpose:
--
-- Provides immutable, cryptographically verifiable audit
-- logging for all security and operational events.
--
-- Security Principle:
--
-- If an action cannot be proven, it did not happen.
--
-- Every security-relevant action must be:
--
-- - attributable
-- - timestamped
-- - associated with identity
-- - associated with device
-- - associated with session
-- - cryptographically chained
--
--
-- Audit records are append-only.
--
-- They are never updated.
-- They are never deleted.
--
--
-- Dependencies:
--
-- 000_trust_foundation.sql
-- 001_device_trust.sql
-- 002_operational_authority.sql
-- 003_authorization.sql
-- 004_sessions.sql
--
-- ============================================================


CREATE EXTENSION IF NOT EXISTS "uuid-ossp";



-- ============================================================
-- EVENT TYPES
-- ============================================================


CREATE TYPE audit_event_type AS ENUM (

    -- Identity

    'PERSON_CREATED',
    'IDENTITY_VERIFIED',
    'ACCOUNT_CREATED',
    'ACCOUNT_DISABLED',


    -- Device

    'DEVICE_REGISTERED',
    'DEVICE_CERTIFICATE_CREATED',
    'DEVICE_CERTIFICATE_REVOKED',
    'DEVICE_ATTESTATION_FAILED',


    -- Authorization

    'ACCESS_REQUEST_CREATED',
    'ACCESS_APPROVED',
    'ACCESS_DENIED',
    'ACCESS_REVOKED',


    -- Operational

    'ROLE_ASSIGNED',
    'ROLE_REMOVED',
    'SHIFT_ACTIVATED',
    'SHIFT_TERMINATED',


    -- Sessions

    'SESSION_CREATED',
    'SESSION_RENEWED',
    'SESSION_EXPIRED',
    'SESSION_REVOKED',


    -- Security

    'FAILED_AUTHENTICATION',
    'FAILED_CERTIFICATE_VALIDATION',
    'POLICY_VIOLATION',
    'PRIVILEGE_ESCALATION_ATTEMPT',
    'AUDIT_TAMPERING_ATTEMPT'

);



-- ============================================================
-- IMMUTABLE AUDIT EVENT LEDGER
--
-- IMPORTANT:
--
-- INSERT ONLY
--
-- No UPDATE
-- No DELETE
--
-- ============================================================


CREATE TABLE audit_events (

    event_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),


    event_type audit_event_type
        NOT NULL,


    event_time TIMESTAMPTZ
        NOT NULL DEFAULT now(),


    -- Person performing action

    actor_person_id UUID
        REFERENCES persons(person_id),


    -- Device used

    device_id UUID
        REFERENCES devices(device_id),


    -- Active session

    session_id UUID
        REFERENCES active_sessions(session_id),


    -- Object affected

    target_type VARCHAR(100),

    target_id UUID,


    -- Description

    event_description TEXT
        NOT NULL,


    -- Additional structured information

    event_data JSONB
        NOT NULL,


    -- Cryptographic chain

    previous_event_hash BYTEA,

    event_hash BYTEA
        NOT NULL,


    -- Certificate identity

    signer_certificate_thumbprint VARCHAR(255),


    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



-- ============================================================
-- SECURITY ALERTS
--
-- Events requiring investigation
-- ============================================================


CREATE TABLE security_alerts (

    alert_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),


    event_id UUID NOT NULL
        REFERENCES audit_events(event_id),


    severity VARCHAR(50)
        NOT NULL,


    status VARCHAR(50)
        NOT NULL DEFAULT 'OPEN',


    assigned_to UUID
        REFERENCES persons(person_id),


    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



-- ============================================================
-- HASH VALIDATION RECORDS
--
-- Periodically validates integrity of audit chain.
--
-- ============================================================


CREATE TABLE audit_integrity_checks (

    check_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),


    first_event UUID NOT NULL
        REFERENCES audit_events(event_id),


    last_event UUID NOT NULL
        REFERENCES audit_events(event_id),


    events_checked INTEGER
        NOT NULL,


    integrity_status VARCHAR(50)
        NOT NULL,


    verification_details JSONB
        NOT NULL,


    checked_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



-- ============================================================
-- RETENTION POLICY
--
-- Retention varies by jurisdiction.
-- ============================================================


CREATE TABLE audit_retention_policy (

    policy_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),


    event_type audit_event_type
        NOT NULL,


    retention_days INTEGER
        NOT NULL,


    legal_reference TEXT,


    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



-- ============================================================
-- DATABASE SECURITY BOUNDARY
--
-- The application is NOT the owner of audit data.
--
-- ============================================================


CREATE ROLE audit_owner NOLOGIN;

CREATE ROLE audit_writer NOLOGIN;

CREATE ROLE audit_reader NOLOGIN;

CREATE ROLE audit_break_glass NOLOGIN;



-- Ownership would be assigned by deployment process:
--
-- ALTER TABLE audit_events OWNER TO audit_owner;



-- ============================================================
-- APPLICATION AUDIT WRITER
--
-- Application can create history.
--
-- Application cannot rewrite history.
-- ============================================================


GRANT INSERT, SELECT
ON audit_events
TO audit_writer;


REVOKE UPDATE, DELETE
ON audit_events
FROM audit_writer;



-- ============================================================
-- AUDITOR ACCESS
-- ============================================================


GRANT SELECT
ON audit_events
TO audit_reader;


REVOKE INSERT, UPDATE, DELETE
ON audit_events
FROM audit_reader;



-- ============================================================
-- BREAK GLASS
--
-- Emergency investigation only.
--
-- Requires:
--
-- - MFA
-- - approval
-- - alert generation
-- - time limit
--
-- ============================================================


GRANT SELECT
ON audit_events
TO audit_break_glass;



-- ============================================================
-- INDEXES
-- ============================================================


CREATE INDEX idx_audit_events_time
ON audit_events(event_time);


CREATE INDEX idx_audit_events_actor
ON audit_events(actor_person_id);


CREATE INDEX idx_audit_events_device
ON audit_events(device_id);


CREATE INDEX idx_audit_events_session
ON audit_events(session_id);


CREATE INDEX idx_audit_events_type
ON audit_events(event_type);



CREATE INDEX idx_security_alerts_status
ON security_alerts(status);



-- ============================================================
-- PROTECTION AGAINST ACCIDENTAL DAMAGE
--
-- These should be applied by deployment owner.
--
-- Application roles should never own these tables.
--
-- ============================================================


REVOKE UPDATE, DELETE
ON audit_events
FROM PUBLIC;


REVOKE TRUNCATE
ON audit_events
FROM PUBLIC;