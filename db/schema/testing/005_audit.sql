-- ============================================================
-- 005_audit_event_stream.sql
--
-- Public Safety Platform
--
-- Purpose:
--
-- Unified immutable forensic event stream.
--
-- Combines:
--
--   1. Security Audit
--   2. Application Execution Trace
--   3. Performance Telemetry
--   4. Incident Reconstruction
--
--
-- Security Principle:
--
-- If an action cannot be proven,
-- it did not happen.
--
--
-- Every event must be:
--
--   - attributable
--   - timestamped
--   - identity bound
--   - device bound
--   - session bound
--   - cryptographically chained
--   - execution traceable
--
--
-- Records are append only.
--
-- NEVER:
--
-- UPDATE
-- DELETE
-- TRUNCATE
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

    ------------------------------------------------------------
    -- Application Lifecycle
    ------------------------------------------------------------

    'APPLICATION_STARTED',
    'APPLICATION_STOPPED',
    'SYSTEM_FAILURE',
    'SYSTEM_RECOVERY',


    ------------------------------------------------------------
    -- Execution Trace
    ------------------------------------------------------------

    'REQUEST_RECEIVED',
    'REQUEST_COMPLETED',

    'FUNCTION_STARTED',
    'FUNCTION_COMPLETED',
    'FUNCTION_FAILED',


    ------------------------------------------------------------
    -- Identity
    ------------------------------------------------------------

    'PERSON_CREATED',
    'IDENTITY_VERIFIED',

    'ACCOUNT_CREATED',
    'ACCOUNT_DISABLED',


    ------------------------------------------------------------
    -- Device Trust
    ------------------------------------------------------------

    'DEVICE_REGISTERED',

    'DEVICE_CERTIFICATE_CREATED',
    'DEVICE_CERTIFICATE_REVOKED',

    'DEVICE_ATTESTATION_FAILED',


    ------------------------------------------------------------
    -- Authentication
    ------------------------------------------------------------

    'LOGIN_REQUEST',

    'TLS_HANDSHAKE_COMPLETE',

    'CERTIFICATE_VALIDATED',

    'FAILED_AUTHENTICATION',

    'FAILED_CERTIFICATE_VALIDATION',


    ------------------------------------------------------------
    -- Authorization
    ------------------------------------------------------------

    'ACCESS_REQUEST_CREATED',

    'ACCESS_APPROVED',

    'ACCESS_DENIED',

    'ACCESS_REVOKED',

    'PRIVILEGE_ESCALATION_ATTEMPT',



    ------------------------------------------------------------
    -- Operational Authority
    ------------------------------------------------------------

    'ROLE_ASSIGNED',

    'ROLE_REMOVED',

    'SHIFT_ACTIVATED',

    'SHIFT_TERMINATED',

    'SUPERVISOR_APPROVAL',



    ------------------------------------------------------------
    -- Session Management
    ------------------------------------------------------------

    'SESSION_CREATED',

    'SESSION_RENEWED',

    'SESSION_EXPIRED',

    'SESSION_REVOKED',



    ------------------------------------------------------------
    -- PKI
    ------------------------------------------------------------

    'CERTIFICATE_GENERATED',

    'CERTIFICATE_EXPIRED',

    'CERTIFICATE_REVOKED',



    ------------------------------------------------------------
    -- Database Security
    ------------------------------------------------------------

    'DATABASE_CONNECTION_CREATED',

    'DATABASE_ROLE_CREATED',

    'DATABASE_ROLE_REMOVED',

    'DATABASE_QUERY_EXECUTED',



    ------------------------------------------------------------
    -- Policy
    ------------------------------------------------------------

    'POLICY_VIOLATION',

    'CONFIGURATION_CHANGED',

    'AUDIT_TAMPERING_ATTEMPT'

);



-- ============================================================
-- IMMUTABLE FORENSIC EVENT STREAM
--
-- Application execution and security events live together.
--
-- ============================================================


CREATE TABLE audit_events (

    event_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),



    ------------------------------------------------------------
    -- TRACE CORRELATION
    --
    -- Allows reconstruction of complete workflows
    ------------------------------------------------------------

    trace_id UUID NOT NULL,

    request_id UUID NOT NULL,



    ------------------------------------------------------------
    -- EVENT TIME
    ------------------------------------------------------------

    event_time TIMESTAMPTZ
        NOT NULL DEFAULT now(),



    ------------------------------------------------------------
    -- APPLICATION EXECUTION CONTEXT
    --
    -- Tracks exact Go execution location
    ------------------------------------------------------------

    service_name VARCHAR(100)
        NOT NULL,


    package_name VARCHAR(255),


    function_name VARCHAR(255),


    source_file VARCHAR(255),


    source_line INTEGER,



    ------------------------------------------------------------
    -- CLASSIFICATION
    ------------------------------------------------------------

    event_type audit_event_type
        NOT NULL,


    event_category VARCHAR(50)
        NOT NULL,


    severity VARCHAR(20)
        NOT NULL DEFAULT 'INFO',



    ------------------------------------------------------------
    -- SECURITY IDENTITY
    ------------------------------------------------------------

    actor_person_id UUID
        REFERENCES persons(person_id),


    device_id UUID
        REFERENCES devices(device_id),


    session_id UUID
        REFERENCES active_sessions(session_id),



    ------------------------------------------------------------
    -- Cryptographic Identity
    ------------------------------------------------------------

    signer_certificate_thumbprint VARCHAR(255),


    database_role VARCHAR(255),



    ------------------------------------------------------------
    -- TARGET OBJECT
    ------------------------------------------------------------

    target_type VARCHAR(100),


    target_id UUID,



    ------------------------------------------------------------
    -- EXECUTION RESULT
    ------------------------------------------------------------

    success BOOLEAN
        NOT NULL,


    error_code VARCHAR(100),


    error_message TEXT,



    ------------------------------------------------------------
    -- PERFORMANCE
    ------------------------------------------------------------

    execution_time_ms INTEGER,



    ------------------------------------------------------------
    -- EXTENDED EVENT DATA
    --
    -- Examples:
    --
    -- LDAP server
    -- certificate serial
    -- IP address
    -- SQL operation
    -- security decisions
    -- hardware validation
    --
    ------------------------------------------------------------

    event_data JSONB
        NOT NULL,



    ------------------------------------------------------------
    -- CRYPTOGRAPHIC HASH CHAIN
    --
    -- Each event proves previous history existed.
    --
    ------------------------------------------------------------

    previous_event_hash BYTEA,


    event_hash BYTEA
        NOT NULL,



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


    analyst_notes TEXT,


    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



-- ============================================================
-- HASH VALIDATION
--
-- Periodically validates the audit chain.
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
-- Jurisdiction controlled retention
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
-- DATABASE SECURITY ROLES
--
-- Application never owns audit data.
-- ============================================================


CREATE ROLE audit_owner NOLOGIN;

CREATE ROLE audit_writer NOLOGIN;

CREATE ROLE audit_reader NOLOGIN;

CREATE ROLE audit_break_glass NOLOGIN;



-- ============================================================
-- OWNERSHIP
--
-- Assigned during deployment:
--
-- ALTER TABLE audit_events OWNER TO audit_owner;
--
-- ============================================================



-- ============================================================
-- APPLICATION WRITER
--
-- Can create history.
-- Cannot modify history.
-- ============================================================


GRANT INSERT
ON audit_events
TO audit_writer;


REVOKE UPDATE, DELETE, TRUNCATE
ON audit_events
FROM audit_writer;



-- ============================================================
-- AUDITOR
-- ============================================================


GRANT SELECT
ON audit_events
TO audit_reader;


REVOKE INSERT, UPDATE, DELETE, TRUNCATE
ON audit_events
FROM audit_reader;



-- ============================================================
-- BREAK GLASS ACCESS
--
-- Emergency only.
--
-- Requires:
--
-- MFA
-- approval
-- alert creation
-- time limit
--
-- ============================================================


GRANT SELECT
ON audit_events
TO audit_break_glass;



-- ============================================================
-- INDEXES
-- ============================================================


CREATE INDEX idx_audit_event_time
ON audit_events(event_time);



CREATE INDEX idx_audit_trace
ON audit_events(trace_id);



CREATE INDEX idx_audit_request
ON audit_events(request_id);



CREATE INDEX idx_audit_actor
ON audit_events(actor_person_id);



CREATE INDEX idx_audit_device
ON audit_events(device_id);



CREATE INDEX idx_audit_session
ON audit_events(session_id);



CREATE INDEX idx_audit_function
ON audit_events(function_name);



CREATE INDEX idx_audit_type
ON audit_events(event_type);



CREATE INDEX idx_audit_failures
ON audit_events(success)
WHERE success = false;



CREATE INDEX idx_security_alert_status
ON security_alerts(status);



-- ============================================================
-- FINAL PROTECTION
--
-- Application accounts cannot destroy evidence.
-- ============================================================


REVOKE UPDATE, DELETE, TRUNCATE
ON audit_events
FROM PUBLIC;