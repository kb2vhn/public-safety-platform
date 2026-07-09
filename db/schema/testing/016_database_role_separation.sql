-- ============================================================
-- 016_database_role_separation.sql
--
-- Database Role Separation Layer
--
-- Purpose:
--
-- Enforce separation between:
--
--   CAD Application
--        |
--        v
--   Security API Functions
--        |
--        v
--   Database Protected Objects
--
-- Principles:
--
--   - Application never owns security objects
--   - Application never receives direct table modification rights
--   - Security functions execute controlled authorization paths
--   - Administrative access is separate from operational access
--
-- ============================================================


BEGIN;


-- ============================================================
-- Create database roles
--
-- These are PostgreSQL roles, not operational identities.
--
-- Operational identity:
--     persons / identities
--
-- Database identity:
--     PostgreSQL role
--
-- ============================================================



DO
$$
BEGIN


    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'cad_application'
    )
    THEN

        CREATE ROLE cad_application
        NOLOGIN;

    END IF;



    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'cad_security'
    )
    THEN

        CREATE ROLE cad_security
        NOLOGIN;

    END IF;



    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'cad_audit'
    )
    THEN

        CREATE ROLE cad_audit
        NOLOGIN;

    END IF;



    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'cad_operator'
    )
    THEN

        CREATE ROLE cad_operator
        NOLOGIN;

    END IF;



    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'cad_database_admin'
    )
    THEN

        CREATE ROLE cad_database_admin
        NOLOGIN;

    END IF;



END
$$;



-- ============================================================
-- Role descriptions
-- ============================================================


COMMENT ON ROLE cad_application IS

'CAD application runtime role. Executes approved security APIs only.';



COMMENT ON ROLE cad_security IS

'Security enforcement role. Owns authorization validation functions.';



COMMENT ON ROLE cad_audit IS

'Audit subsystem role. Owns cryptographic audit chain functions and objects.';



COMMENT ON ROLE cad_operator IS

'Operational support role. Performs approved operational workflows.';



COMMENT ON ROLE cad_database_admin IS

'Database administration role. Schema maintenance and migrations only.';



COMMIT;



-- ============================================================
-- End Part 1
-- ============================================================
-- ============================================================
-- 016_database_role_separation.sql
--
-- Part 2
--
-- Object Ownership Separation
--
-- ============================================================


BEGIN;


-- ============================================================
-- Security schema ownership
-- ============================================================


ALTER SCHEMA security
OWNER TO cad_security;



-- ============================================================
-- Audit chain ownership
-- ============================================================


ALTER TABLE cryptographic_audit_chain
OWNER TO audit_owner;



ALTER SEQUENCE cryptographic_audit_chain_sequence_number_seq
OWNER TO audit_owner;



-- ============================================================
-- Authorization ownership
-- ============================================================


ALTER TABLE authorization_requests
OWNER TO cad_security;


ALTER TABLE authorization_decisions
OWNER TO cad_security;


ALTER TABLE authorization_approval_events
OWNER TO cad_security;


ALTER TABLE authorization_revocations
OWNER TO cad_security;


ALTER TABLE authorization_signatures
OWNER TO cad_security;


ALTER TABLE authorization_scope
OWNER TO cad_security;

-- ============================================================
-- Session security ownership
-- ============================================================


ALTER TABLE public.sessions
OWNER TO cad_security;


ALTER TABLE public.active_sessions
OWNER TO cad_security;


ALTER TABLE security.session_context
OWNER TO cad_security;

-- ============================================================
-- Device trust ownership
-- ============================================================


ALTER TABLE devices
OWNER TO cad_security;


ALTER TABLE device_trust_profile
OWNER TO cad_security;


ALTER TABLE device_trust_history
OWNER TO cad_security;



COMMIT;



-- ============================================================
-- End Part 2
-- ============================================================
-- ============================================================
-- 016_database_role_separation.sql
--
-- Part 3
--
-- Application Permission Boundary
--
-- ============================================================


BEGIN;


-- ============================================================
-- Remove direct table access
--
-- CAD application must use controlled APIs.
--
-- ============================================================


REVOKE ALL
ON ALL TABLES IN SCHEMA public
FROM cad_application;


REVOKE ALL
ON ALL TABLES IN SCHEMA security
FROM cad_application;



-- ============================================================
-- Remove sequence access
--
-- Prevent uncontrolled record creation.
--
-- ============================================================


REVOKE ALL
ON ALL SEQUENCES IN SCHEMA public
FROM cad_application;


REVOKE ALL
ON ALL SEQUENCES IN SCHEMA security
FROM cad_application;



-- ============================================================
-- Authorization API boundary
--
-- This is the approved decision path.
--
-- ============================================================


GRANT EXECUTE
ON FUNCTION security.is_authorized(text)
TO cad_application;



GRANT EXECUTE
ON FUNCTION security.is_authorized_audited(text)
TO cad_application;



-- ============================================================
-- Supporting validation functions
--
-- Required by security API execution.
--
-- ============================================================


GRANT EXECUTE
ON FUNCTION security.validate_security_context()
TO cad_security;



GRANT EXECUTE
ON FUNCTION security.validate_session()
TO cad_security;



GRANT EXECUTE
ON FUNCTION security.validate_identity()
TO cad_security;



GRANT EXECUTE
ON FUNCTION security.validate_person()
TO cad_security;



GRANT EXECUTE
ON FUNCTION security.validate_device()
TO cad_security;



-- ============================================================
-- Audit protection
--
-- Direct audit writes prohibited.
--
-- ============================================================


REVOKE INSERT, UPDATE, DELETE
ON cryptographic_audit_chain
FROM cad_application;



-- ============================================================
-- Controlled audit writer
--
-- ============================================================


GRANT INSERT
ON cryptographic_audit_chain
TO audit_writer;



-- ============================================================
-- Explicit role isolation
--
-- ============================================================


ALTER ROLE cad_application
NOINHERIT;


ALTER ROLE cad_operator
NOINHERIT;


ALTER ROLE cad_security
NOINHERIT;



COMMIT;


-- ============================================================
-- End Part 3
-- ============================================================

-- ============================================================
-- 016_database_role_separation.sql
--
-- Part 4
--
-- SECURITY DEFINER Hardening
--
-- ============================================================


BEGIN;



-- ============================================================
-- Transfer security API ownership
--
-- SECURITY DEFINER functions must not belong to humans.
--
-- ============================================================


ALTER FUNCTION security.is_authorized(text)
OWNER TO cad_security;



ALTER FUNCTION security.is_authorized_audited(text)
OWNER TO cad_security;



ALTER FUNCTION security.is_allowed(text)
OWNER TO cad_security;



ALTER FUNCTION security.require_capability(text)
OWNER TO cad_security;



ALTER FUNCTION security.require_role(text)
OWNER TO cad_security;



ALTER FUNCTION security.validate_security_context()
OWNER TO cad_security;



ALTER FUNCTION security.validate_session()
OWNER TO cad_security;



ALTER FUNCTION security.validate_identity()
OWNER TO cad_security;



ALTER FUNCTION security.validate_person()
OWNER TO cad_security;



ALTER FUNCTION security.validate_device()
OWNER TO cad_security;



ALTER FUNCTION security.has_capability(text)
OWNER TO cad_security;



ALTER FUNCTION security.has_role(text)
OWNER TO cad_security;



ALTER FUNCTION security.has_active_assignment()
OWNER TO cad_security;



-- ============================================================
-- Lock function execution environment
--
-- Prevent malicious search_path manipulation.
--
-- ============================================================


ALTER FUNCTION security.is_authorized(text)
SET search_path = security, public;



ALTER FUNCTION security.is_authorized_audited(text)
SET search_path = security, public;



ALTER FUNCTION security.is_allowed(text)
SET search_path = security, public;



ALTER FUNCTION security.require_capability(text)
SET search_path = security, public;



ALTER FUNCTION security.require_role(text)
SET search_path = security, public;



ALTER FUNCTION security.validate_security_context()
SET search_path = security, public;



ALTER FUNCTION security.validate_session()
SET search_path = security, public;



ALTER FUNCTION security.validate_identity()
SET search_path = security, public;



ALTER FUNCTION security.validate_person()
SET search_path = security, public;



ALTER FUNCTION security.validate_device()
SET search_path = security, public;



COMMIT;



-- ============================================================
-- End Part 4
-- ============================================================

-- ============================================================
-- 016_database_role_separation.sql
--
-- Part 5
--
-- Application Role Privilege Boundary
--
-- Purpose:
--   Prevent direct application table access.
--   Force controlled execution paths.
--
-- ============================================================


BEGIN;



-- ============================================================
-- Remove default privileges
--
-- Application must never inherit accidental access.
--
-- ============================================================


REVOKE ALL
ON ALL TABLES IN SCHEMA public
FROM cad_application;


REVOKE ALL
ON ALL TABLES IN SCHEMA security
FROM cad_application;


REVOKE ALL
ON ALL SEQUENCES IN SCHEMA public
FROM cad_application;


REVOKE ALL
ON ALL SEQUENCES IN SCHEMA security
FROM cad_application;



-- ============================================================
-- Explicit application execution rights
--
-- Application may execute approved security interfaces.
--
-- ============================================================


GRANT USAGE
ON SCHEMA security
TO cad_application;



GRANT EXECUTE
ON FUNCTION security.is_authorized(text)
TO cad_application;



GRANT EXECUTE
ON FUNCTION security.is_authorized_audited(text)
TO cad_application;



GRANT EXECUTE
ON FUNCTION security.validate_security_context()
TO cad_application;



GRANT EXECUTE
ON FUNCTION security.current_context()
TO cad_application;



GRANT EXECUTE
ON FUNCTION security.current_person()
TO cad_application;



GRANT EXECUTE
ON FUNCTION security.current_identity()
TO cad_application;



GRANT EXECUTE
ON FUNCTION security.current_device()
TO cad_application;



GRANT EXECUTE
ON FUNCTION security.current_session()
TO cad_application;



-- ============================================================
-- Read execution role
--
-- Controlled read operations.
--
-- ============================================================


REVOKE INSERT,
UPDATE,
DELETE
ON ALL TABLES IN SCHEMA public
FROM cad_read_executor;



REVOKE INSERT,
UPDATE,
DELETE
ON ALL TABLES IN SCHEMA security
FROM cad_read_executor;



-- ============================================================
-- Write execution role
--
-- Controlled modification path.
--
-- ============================================================


REVOKE SELECT,
INSERT,
UPDATE,
DELETE
ON ALL TABLES IN SCHEMA public
FROM cad_write_executor;



REVOKE SELECT,
INSERT,
UPDATE,
DELETE
ON ALL TABLES IN SCHEMA security
FROM cad_write_executor;



-- ============================================================
-- Function execution inheritance
--
-- Write operations occur through SECURITY DEFINER functions.
--
-- ============================================================


GRANT USAGE
ON SCHEMA public
TO cad_write_executor;



GRANT USAGE
ON SCHEMA security
TO cad_write_executor;



-- ============================================================
-- Prevent role escalation
--
-- Application roles cannot manage privileges.
--
-- ============================================================


REVOKE CREATE
ON SCHEMA public
FROM cad_application;



REVOKE CREATE
ON SCHEMA security
FROM cad_application;



REVOKE CREATE
ON SCHEMA public
FROM cad_read_executor;



REVOKE CREATE
ON SCHEMA public
FROM cad_write_executor;



-- ============================================================
-- Default future object protection
--
-- New tables do not automatically become accessible.
--
-- ============================================================


ALTER DEFAULT PRIVILEGES
IN SCHEMA public
REVOKE ALL
ON TABLES
FROM cad_application;



ALTER DEFAULT PRIVILEGES
IN SCHEMA public
REVOKE ALL
ON SEQUENCES
FROM cad_application;



ALTER DEFAULT PRIVILEGES
IN SCHEMA security
REVOKE ALL
ON TABLES
FROM cad_application;



ALTER DEFAULT PRIVILEGES
IN SCHEMA security
REVOKE ALL
ON FUNCTIONS
FROM PUBLIC;



COMMIT;



-- ============================================================
-- End Part 5
-- ============================================================

-- ============================================================
-- 016_database_role_separation.sql
--
-- Part 6
--
-- Audit and Cryptographic Chain Protection
--
-- Purpose:
--   Protect forensic evidence.
--   Prevent audit modification.
--   Preserve chain of custody.
--
-- ============================================================


BEGIN;



-- ============================================================
-- Transfer audit ownership
--
-- Audit structures must not belong to human accounts.
--
-- ============================================================


ALTER TABLE audit_events
OWNER TO cad_audit;



ALTER TABLE cryptographic_audit_chain
OWNER TO cad_audit;



ALTER TABLE authorization_decisions
OWNER TO cad_audit;



ALTER TABLE authorization_approval_events
OWNER TO cad_audit;



ALTER TABLE authorization_revocations
OWNER TO cad_audit;



-- ============================================================
-- Remove direct modification rights
--
-- Audit history is append-only.
--
-- ============================================================


REVOKE UPDATE,
DELETE
ON audit_events
FROM PUBLIC;



REVOKE UPDATE,
DELETE
ON cryptographic_audit_chain
FROM PUBLIC;



REVOKE UPDATE,
DELETE
ON authorization_decisions
FROM PUBLIC;



REVOKE UPDATE,
DELETE
ON authorization_approval_events
FROM PUBLIC;



REVOKE UPDATE,
DELETE
ON authorization_revocations
FROM PUBLIC;



-- ============================================================
-- Application cannot directly write audit tables
--
-- Audit writes occur through controlled functions.
--
-- ============================================================


REVOKE INSERT,
UPDATE,
DELETE
ON audit_events
FROM cad_application;



REVOKE INSERT,
UPDATE,
DELETE
ON cryptographic_audit_chain
FROM cad_application;



REVOKE INSERT,
UPDATE,
DELETE
ON authorization_decisions
FROM cad_application;



REVOKE INSERT,
UPDATE,
DELETE
ON authorization_approval_events
FROM cad_application;



REVOKE INSERT,
UPDATE,
DELETE
ON authorization_revocations
FROM cad_application;



-- ============================================================
-- Audit writer function access
--
-- Application receives execution only.
--
-- ============================================================


GRANT EXECUTE
ON FUNCTION security.audit_authorization_decision(
    text,
    security.authorization_result
)
TO cad_application;



-- ============================================================
-- Audit reader separation
--
-- Investigators receive read-only access.
--
-- ============================================================


GRANT USAGE
ON SCHEMA public
TO audit_reader;



GRANT SELECT
ON audit_events
TO audit_reader;



GRANT SELECT
ON cryptographic_audit_chain
TO audit_reader;



GRANT SELECT
ON authorization_decisions
TO audit_reader;



GRANT SELECT
ON authorization_approval_events
TO audit_reader;



GRANT SELECT
ON authorization_revocations
TO audit_reader;



-- ============================================================
-- Audit writer restrictions
--
-- Writer can append but never alter history.
--
-- ============================================================


GRANT INSERT
ON audit_events
TO cad_audit_writer;



GRANT INSERT
ON cryptographic_audit_chain
TO cad_audit_writer;



REVOKE UPDATE,
DELETE
ON audit_events
FROM cad_audit_writer;



REVOKE UPDATE,
DELETE
ON cryptographic_audit_chain
FROM cad_audit_writer;



-- ============================================================
-- Break glass separation
--
-- Emergency access is isolated.
--
-- ============================================================


REVOKE ALL
ON audit_events
FROM audit_break_glass;



REVOKE ALL
ON cryptographic_audit_chain
FROM audit_break_glass;



COMMIT;



-- ============================================================
-- End Part 6
-- ============================================================
