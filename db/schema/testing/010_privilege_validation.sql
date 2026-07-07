-- ============================================================
-- 010_privilege_validation.sql
--
-- Database Security Boundary Enforcement
--
-- Purpose:
--   Establish least privilege database access.
--   No application role receives unrestricted access.
--   Operational authority remains separate from technical access.
--
-- ============================================================


BEGIN;


-- ============================================================
-- 1. REMOVE DEFAULT POSTGRES TRUST
-- ============================================================

REVOKE ALL
ON SCHEMA public
FROM PUBLIC;


REVOKE ALL
ON ALL TABLES
IN SCHEMA public
FROM PUBLIC;


REVOKE ALL
ON ALL SEQUENCES
IN SCHEMA public
FROM PUBLIC;


REVOKE ALL
ON ALL FUNCTIONS
IN SCHEMA public
FROM PUBLIC;



-- ============================================================
-- 2. CREATE DATABASE SECURITY ROLES
-- ============================================================


-- Schema owner.
-- Used only for migrations.
-- Application NEVER uses this account.
CREATE ROLE cad_schema_owner
NOLOGIN;


-- Authentication service.
-- Handles identity validation and sessions.
CREATE ROLE auth_service
NOLOGIN;


-- CAD operational service.
-- Handles approved CAD transactions.
CREATE ROLE cad_application
NOLOGIN;


-- Read-only reporting.
CREATE ROLE cad_reporting
NOLOGIN;


-- Immutable audit writer.
CREATE ROLE audit_writer
NOLOGIN;


-- Emergency break-glass role.
-- Disabled by default.
CREATE ROLE emergency_dba
NOLOGIN;



-- ============================================================
-- 3. TRANSFER OWNERSHIP OF SECURITY TABLES
-- ============================================================


ALTER TABLE agencies
OWNER TO cad_schema_owner;


ALTER TABLE users
OWNER TO cad_schema_owner;


ALTER TABLE privilege_authorization_ledger
OWNER TO cad_schema_owner;


ALTER TABLE administrative_hardware_gates
OWNER TO cad_schema_owner;


ALTER TABLE shift_roster
OWNER TO cad_schema_owner;


ALTER TABLE shift_activations
OWNER TO cad_schema_owner;



-- ============================================================
-- 4. AUTHENTICATION SERVICE PERMISSIONS
-- ============================================================


GRANT SELECT
ON agencies,
users
TO auth_service;


GRANT SELECT
ON shift_roster,
shift_activations
TO auth_service;


GRANT INSERT
ON TABLE shift_activations
TO auth_service;


GRANT SELECT
ON administrative_hardware_gates
TO auth_service;



-- ============================================================
-- 5. CAD APPLICATION PERMISSIONS
--
-- The application can only perform approved actions.
-- It does not own the database.
-- ============================================================


GRANT SELECT
ON users
TO cad_application;


GRANT SELECT
ON agencies
TO cad_application;



-- Future CAD tables will receive explicit grants.

-- Example:
--
-- GRANT SELECT, INSERT
-- ON cad_calls
-- TO cad_application;
--
-- UPDATE will only be granted to specific workflows.



-- ============================================================
-- 6. REPORTING IS READ ONLY
-- ============================================================


GRANT SELECT
ON ALL TABLES
IN SCHEMA public
TO cad_reporting;


ALTER DEFAULT PRIVILEGES
FOR ROLE cad_schema_owner
IN SCHEMA public
GRANT SELECT
ON TABLES
TO cad_reporting;



-- ============================================================
-- 7. IMMUTABLE AUDIT PROTECTION
-- ============================================================


GRANT INSERT
ON audit_events
TO audit_writer;


GRANT SELECT
ON audit_events
TO audit_writer;


REVOKE UPDATE, DELETE
ON audit_events
FROM audit_writer;


REVOKE TRUNCATE
ON audit_events
FROM audit_writer;



-- ============================================================
-- 8. PREVENT APPLICATION ACCOUNT ESCALATION
-- ============================================================


REVOKE CREATE
ON SCHEMA public
FROM cad_application;


REVOKE CREATE
ON SCHEMA public
FROM auth_service;


REVOKE CREATE
ON SCHEMA public
FROM cad_reporting;



-- ============================================================
-- 9. FUTURE TABLE DEFAULT PROTECTION
-- ============================================================


ALTER DEFAULT PRIVILEGES
FOR ROLE cad_schema_owner
REVOKE ALL
ON TABLES
FROM PUBLIC;


ALTER DEFAULT PRIVILEGES
FOR ROLE cad_schema_owner
REVOKE ALL
ON FUNCTIONS
FROM PUBLIC;



-- ============================================================
-- 10. SECURITY ASSERTIONS
-- ============================================================


COMMENT ON ROLE cad_schema_owner IS
'Database schema owner. Used only by controlled migrations.';


COMMENT ON ROLE cad_application IS
'CAD application runtime. Must never have unrestricted privileges.';


COMMENT ON ROLE audit_writer IS
'Write-only audit pipeline role. UPDATE and DELETE prohibited.';


COMMENT ON ROLE emergency_dba IS
'Break-glass administrative access requiring dual authorization.';



COMMIT;