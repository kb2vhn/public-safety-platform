-- ============================================================
-- 012_identity_database_binding.sql
--
-- Identity to Database Session Binding
--
-- Purpose:
--   Bind authenticated cryptographic identities to database
--   sessions and prevent arbitrary privilege escalation.
--
-- Security Model:
--
--   User Certificate
--        |
--        v
--   Go mTLS Authentication Service
--        |
--        v
--   PostgreSQL Role Mapping
--        |
--        v
--   Row Level Security
--
-- ============================================================


BEGIN;



-- ============================================================
-- 1. CERTIFICATE IDENTITY MAPPING
--
-- Maps issued certificates to platform identities.
--
-- The certificate fingerprint is the cryptographic anchor.
--
-- ============================================================


CREATE TABLE identity_certificate_bindings
(
    binding_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(user_id),

    certificate_fingerprint VARCHAR(128)
        NOT NULL UNIQUE,

    certificate_subject TEXT NOT NULL,

    certificate_issuer TEXT NOT NULL,

    valid_from TIMESTAMPTZ NOT NULL,

    valid_until TIMESTAMPTZ NOT NULL,

    revoked BOOLEAN NOT NULL DEFAULT false,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),


    CONSTRAINT valid_certificate_period
    CHECK(valid_until > valid_from)
);



COMMENT ON TABLE identity_certificate_bindings IS
'Maps cryptographic certificates to authorized platform identities.';



-- ============================================================
-- 2. DATABASE ROLE MAPPING
--
-- A person does not directly become a PostgreSQL superuser.
--
-- They assume a restricted application role.
--
-- ============================================================


CREATE TABLE identity_role_bindings
(
    binding_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL
        REFERENCES users(user_id),


    database_role VARCHAR(100)
        NOT NULL,


    platform_role platform_role
        NOT NULL,


    approved_by UUID
        REFERENCES users(user_id),


    approved_at TIMESTAMPTZ,


    active BOOLEAN NOT NULL DEFAULT true,


    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);



COMMENT ON TABLE identity_role_bindings IS
'Controls which PostgreSQL runtime role an authenticated user may assume.';



-- ============================================================
-- 3. SESSION IDENTITY TABLE
--
-- Tracks active cryptographic sessions.
--
-- This is the bridge between Go and PostgreSQL.
--
-- ============================================================


CREATE TABLE identity_sessions
(
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),


    user_id UUID NOT NULL
        REFERENCES users(user_id),


    certificate_fingerprint VARCHAR(128)
        NOT NULL
        REFERENCES identity_certificate_bindings
        (certificate_fingerprint),


    database_role VARCHAR(100)
        NOT NULL,


    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),


    expires_at TIMESTAMPTZ NOT NULL,


    revoked BOOLEAN NOT NULL DEFAULT false,


    client_address INET,


    device_id UUID
        REFERENCES devices(device_id)
);



COMMENT ON TABLE identity_sessions IS
'Tracks active certificate-backed database sessions.';



-- ============================================================
-- 4. SESSION VALIDATION FUNCTION
--
-- Used by RLS policies.
--
-- A session must:
--   - exist
--   - not be revoked
--   - not expire
--
-- ============================================================


CREATE OR REPLACE FUNCTION identity_session_valid()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$

SELECT EXISTS
(
    SELECT 1

    FROM identity_sessions

    WHERE session_id =
        current_setting
        (
            'app.session_id',
            true
        )::uuid

    AND revoked = false

    AND now() < expires_at
);

$$;



-- ============================================================
-- 5. PREVENT EXPIRED SESSION ACCESS
--
-- Every protected table can now reference this.
--
-- ============================================================


CREATE OR REPLACE FUNCTION enforce_identity_session()
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$

BEGIN

    IF identity_session_valid()
    THEN
        RETURN true;
    END IF;


    RETURN false;

END;

$$;



-- ============================================================
-- 6. PROTECT CERTIFICATE RECORDS
--
-- Users cannot modify their own certificates.
--
-- ============================================================


ALTER TABLE identity_certificate_bindings
ENABLE ROW LEVEL SECURITY;


CREATE POLICY certificate_read_policy
ON identity_certificate_bindings
FOR SELECT
USING
(
    user_id = current_app_user()
    OR
    current_app_role() = 'SYS_ADMIN'
);



CREATE POLICY certificate_admin_policy
ON identity_certificate_bindings
FOR INSERT
WITH CHECK
(
    current_app_role()
    =
    'SYS_ADMIN'
);



ALTER TABLE identity_certificate_bindings
FORCE ROW LEVEL SECURITY;



-- ============================================================
-- 7. PROTECT SESSION RECORDS
--
-- User sees only their own sessions.
--
-- ============================================================


ALTER TABLE identity_sessions
ENABLE ROW LEVEL SECURITY;



CREATE POLICY session_visibility
ON identity_sessions
FOR SELECT
USING
(
    user_id = current_app_user()
    OR
    current_app_role()
    =
    'SYS_ADMIN'
);



CREATE POLICY session_creation
ON identity_sessions
FOR INSERT
WITH CHECK
(
    user_id = current_app_user()
);



ALTER TABLE identity_sessions
FORCE ROW LEVEL SECURITY;



-- ============================================================
-- 8. INDEXES
--
-- Fast authentication checks.
--
-- ============================================================


CREATE INDEX idx_certificate_lookup
ON identity_certificate_bindings
(
    certificate_fingerprint
)
WHERE revoked = false;



CREATE INDEX idx_session_validation
ON identity_sessions
(
    session_id,
    expires_at
)
WHERE revoked = false;



-- ============================================================
-- 9. SECURITY COMMENTS
-- ============================================================


COMMENT ON FUNCTION identity_session_valid()
IS
'Validates active cryptographic session before database access.';



COMMIT;