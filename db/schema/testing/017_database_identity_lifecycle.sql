/*
===============================================================================
018_database_identity_lifecycle.sql

Purpose:
    Tracks the complete lifecycle of temporary PostgreSQL identities created
    by the Go Authentication Service.

    The Go service is responsible for:
        • Authenticating the user
        • Validating workstation/device trust
        • Validating shift approval
        • Issuing ephemeral client certificates
        • Creating temporary PostgreSQL LOGIN roles
        • Removing those roles at logout or shift expiration

    This schema records those events for auditing and forensic analysis.
===============================================================================
*/

-- ============================================================================
-- Identity Lifecycle Status
-- ============================================================================

CREATE TYPE identity_session_status AS ENUM (
    'CREATED',
    'ACTIVE',
    'EXPIRED',
    'REVOKED',
    'TERMINATED'
);

-- ============================================================================
-- Database Identity Sessions
-- ============================================================================

CREATE TABLE database_identity_sessions (

    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    --------------------------------------------------------------------------
    -- Operational Identity
    --------------------------------------------------------------------------

    person_id UUID NOT NULL
        REFERENCES persons(person_id),

    identity_id UUID
        REFERENCES identities(identity_id),

    agency_id UUID NOT NULL
        REFERENCES agencies(agency_id),

    shift_id UUID
        REFERENCES shifts(shift_id),

    --------------------------------------------------------------------------
    -- PostgreSQL Login
    --------------------------------------------------------------------------

    database_role_name TEXT NOT NULL UNIQUE,

    --------------------------------------------------------------------------
    -- Certificate Information
    --------------------------------------------------------------------------

    certificate_serial TEXT NOT NULL,

    certificate_fingerprint TEXT NOT NULL,

    certificate_subject TEXT NOT NULL,

    certificate_issuer TEXT NOT NULL,

    valid_from TIMESTAMPTZ NOT NULL,

    valid_until TIMESTAMPTZ NOT NULL,

    --------------------------------------------------------------------------
    -- Session Information
    --------------------------------------------------------------------------

    workstation_id UUID
        REFERENCES devices(device_id),

    client_ip INET,

    application_version TEXT,

    go_instance TEXT,

    --------------------------------------------------------------------------
    -- Lifecycle
    --------------------------------------------------------------------------

    status identity_session_status
        NOT NULL DEFAULT 'CREATED',

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now(),

    activated_at TIMESTAMPTZ,

    expires_at TIMESTAMPTZ,

    revoked_at TIMESTAMPTZ,

    terminated_at TIMESTAMPTZ,

    termination_reason TEXT
);

-- ============================================================================
-- Performance
-- ============================================================================

CREATE INDEX idx_identity_session_person
ON database_identity_sessions(person_id);

CREATE INDEX idx_identity_session_shift
ON database_identity_sessions(shift_id);

CREATE INDEX idx_identity_session_role
ON database_identity_sessions(database_role_name);

CREATE INDEX idx_identity_session_status
ON database_identity_sessions(status);

CREATE INDEX idx_identity_session_valid_until
ON database_identity_sessions(valid_until);

-- ============================================================================
-- Integrity Constraints
-- ============================================================================

ALTER TABLE database_identity_sessions
ADD CONSTRAINT chk_valid_window
CHECK (valid_until > valid_from);

ALTER TABLE database_identity_sessions
ADD CONSTRAINT chk_expiration
CHECK (
    expires_at IS NULL
    OR expires_at >= activated_at
);

-- ============================================================================
-- Protect Audit Integrity
-- ============================================================================

REVOKE UPDATE, DELETE
ON database_identity_sessions
FROM PUBLIC;

REVOKE UPDATE, DELETE
ON database_identity_sessions
FROM cad_dispatcher;

REVOKE UPDATE, DELETE
ON database_identity_sessions
FROM cad_supervisor;

REVOKE UPDATE, DELETE
ON database_identity_sessions
FROM cad_admin;

GRANT INSERT, SELECT
ON database_identity_sessions
TO cad_authentication_service;

GRANT SELECT
ON database_identity_sessions
TO cad_auditor;

-- ============================================================================
-- Documentation
-- ============================================================================

COMMENT ON TABLE database_identity_sessions IS
'Immutable lifecycle record for temporary PostgreSQL login identities created by the Go authentication service.';