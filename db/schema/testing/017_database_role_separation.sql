/*
===============================================================================
017_database_role_separation.sql

Purpose:
    Implements least-privilege database architecture.

Principles:
    • No application God account
    • No shared write account
    • Default deny
    • Explicit grants only
    • Separation of ownership from execution
===============================================================================
*/

BEGIN;

------------------------------------------------------------------------------
-- Runtime Roles
------------------------------------------------------------------------------

CREATE ROLE cad_runtime NOLOGIN;
CREATE ROLE cad_readonly NOLOGIN;
CREATE ROLE cad_dispatch NOLOGIN;
CREATE ROLE cad_supervisor NOLOGIN;
CREATE ROLE cad_reporting NOLOGIN;
CREATE ROLE cad_audit_reader NOLOGIN;

------------------------------------------------------------------------------
-- Schema Owner
------------------------------------------------------------------------------

CREATE ROLE cad_schema_owner NOLOGIN;

------------------------------------------------------------------------------
-- Migration Role
------------------------------------------------------------------------------

CREATE ROLE cad_migration NOLOGIN;

GRANT cad_schema_owner TO cad_migration;

------------------------------------------------------------------------------
-- Remove Public Access
------------------------------------------------------------------------------

REVOKE ALL
ON SCHEMA public
FROM PUBLIC;

REVOKE ALL
ON DATABASE cad
FROM PUBLIC;

------------------------------------------------------------------------------
-- Schema Permissions
------------------------------------------------------------------------------

GRANT USAGE
ON SCHEMA public
TO
    cad_runtime,
    cad_readonly,
    cad_dispatch,
    cad_supervisor,
    cad_reporting,
    cad_audit_reader;

------------------------------------------------------------------------------
-- Table Permissions
------------------------------------------------------------------------------

REVOKE ALL
ON ALL TABLES
IN SCHEMA public
FROM PUBLIC;

------------------------------------------------------------------------------
-- Sequence Permissions
------------------------------------------------------------------------------

REVOKE ALL
ON ALL SEQUENCES
IN SCHEMA public
FROM PUBLIC;

------------------------------------------------------------------------------
-- Function Permissions
------------------------------------------------------------------------------

REVOKE ALL
ON ALL FUNCTIONS
IN SCHEMA public
FROM PUBLIC;

------------------------------------------------------------------------------
-- Default Privileges
------------------------------------------------------------------------------

ALTER DEFAULT PRIVILEGES
FOR ROLE cad_schema_owner
IN SCHEMA public
REVOKE ALL
ON TABLES
FROM PUBLIC;

ALTER DEFAULT PRIVILEGES
FOR ROLE cad_schema_owner
IN SCHEMA public
REVOKE ALL
ON SEQUENCES
FROM PUBLIC;

ALTER DEFAULT PRIVILEGES
FOR ROLE cad_schema_owner
IN SCHEMA public
REVOKE ALL
ON FUNCTIONS
FROM PUBLIC;

------------------------------------------------------------------------------
-- Read Only
------------------------------------------------------------------------------

GRANT SELECT
ON ALL TABLES
IN SCHEMA public
TO cad_readonly;

------------------------------------------------------------------------------
-- Audit Reader
------------------------------------------------------------------------------

GRANT SELECT
ON audit_events,
   audit_hash_chain,
   security_events
TO cad_audit_reader;

------------------------------------------------------------------------------
-- Reporting
------------------------------------------------------------------------------

GRANT SELECT
ON ALL TABLES
IN SCHEMA public
TO cad_reporting;

------------------------------------------------------------------------------
-- Runtime
------------------------------------------------------------------------------

GRANT EXECUTE
ON ALL FUNCTIONS
IN SCHEMA public
TO cad_runtime;

------------------------------------------------------------------------------
-- Dispatch
------------------------------------------------------------------------------

GRANT
SELECT,
INSERT,
UPDATE
ON
    calls,
    call_events,
    unit_assignments
TO cad_dispatch;

------------------------------------------------------------------------------
-- Supervisor
------------------------------------------------------------------------------

GRANT
SELECT,
UPDATE
ON
    shifts,
    shift_activations
TO cad_supervisor;

------------------------------------------------------------------------------
-- Explicit Denials
------------------------------------------------------------------------------

REVOKE DELETE
ON ALL TABLES
IN SCHEMA public
FROM
    cad_runtime,
    cad_dispatch,
    cad_supervisor,
    cad_reporting,
    cad_readonly;

------------------------------------------------------------------------------
-- Nobody except schema owner may alter schema
------------------------------------------------------------------------------

REVOKE
CREATE
ON SCHEMA public
FROM
    cad_runtime,
    cad_dispatch,
    cad_supervisor,
    cad_reporting,
    cad_readonly,
    cad_audit_reader;

------------------------------------------------------------------------------
-- Ownership
------------------------------------------------------------------------------

ALTER TABLE agencies OWNER TO cad_schema_owner;
ALTER TABLE persons OWNER TO cad_schema_owner;
ALTER TABLE identities OWNER TO cad_schema_owner;
ALTER TABLE devices OWNER TO cad_schema_owner;
ALTER TABLE certificates OWNER TO cad_schema_owner;
ALTER TABLE shifts OWNER TO cad_schema_owner;
ALTER TABLE calls OWNER TO cad_schema_owner;
ALTER TABLE call_events OWNER TO cad_schema_owner;
ALTER TABLE audit_events OWNER TO cad_schema_owner;

------------------------------------------------------------------------------
-- Safety
------------------------------------------------------------------------------

REVOKE ALL
ON DATABASE cad
FROM cad_runtime;

GRANT CONNECT
ON DATABASE cad
TO
    cad_runtime,
    cad_dispatch,
    cad_supervisor,
    cad_reporting,
    cad_readonly,
    cad_audit_reader;

COMMIT;