-- ============================================================
-- 999_security_bootstrap.sql
--
-- Final security hardening layer
--
-- Purpose:
--   Establish PostgreSQL security boundaries.
--
-- Principles:
--   - No God accounts
--   - Application cannot bypass authorization
--   - Audit cannot be modified
--   - Runtime accounts have minimum privilege
--   - Users are authorized through operational identity
--
-- ============================================================


BEGIN;


---------------------------------------------------------------
-- 1. Required Extensions
---------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE EXTENSION IF NOT EXISTS pgcrypto;



---------------------------------------------------------------
-- 2. Create Security Roles
--
-- PostgreSQL roles are NOT CAD roles.
-- CAD authorization exists in application tables.
---------------------------------------------------------------


-- Database owner
-- No login.
-- Used for object ownership.

DO $$
BEGIN

    IF NOT EXISTS (
        SELECT FROM pg_roles
        WHERE rolname='cad_database_owner'
    )
    THEN

        CREATE ROLE cad_database_owner NOLOGIN;

    END IF;

END
$$;



-- Read executor

DO $$
BEGIN

    IF NOT EXISTS (
        SELECT FROM pg_roles
        WHERE rolname='cad_read_executor'
    )
    THEN

        CREATE ROLE cad_read_executor NOLOGIN;

    END IF;

END
$$;



-- Write executor

DO $$
BEGIN

    IF NOT EXISTS (
        SELECT FROM pg_roles
        WHERE rolname='cad_write_executor'
    )
    THEN

        CREATE ROLE cad_write_executor NOLOGIN;

    END IF;

END
$$;



-- Audit writer

DO $$
BEGIN

    IF NOT EXISTS (
        SELECT FROM pg_roles
        WHERE rolname='cad_audit_writer'
    )
    THEN

        CREATE ROLE cad_audit_writer NOLOGIN;

    END IF;

END
$$;



-- Migration role

DO $$
BEGIN

    IF NOT EXISTS (
        SELECT FROM pg_roles
        WHERE rolname='cad_migration'
    )
    THEN

        CREATE ROLE cad_migration LOGIN;

    END IF;

END
$$;



---------------------------------------------------------------
-- 3. Application API Identity
--
-- Authenticated by certificate.
-- No passwords.
---------------------------------------------------------------


DO $$
BEGIN

    IF NOT EXISTS (
        SELECT FROM pg_roles
        WHERE rolname='cad_api_gateway'
    )
    THEN

        CREATE ROLE cad_api_gateway
        LOGIN
        NOSUPERUSER
        NOCREATEDB
        NOCREATEROLE
        NOINHERIT;

    END IF;

END
$$;



---------------------------------------------------------------
-- 4. Remove Default PostgreSQL Trust
---------------------------------------------------------------


DO $$
BEGIN

    EXECUTE format(
        'REVOKE ALL ON DATABASE %I FROM PUBLIC',
        current_database()
    );

END
$$;



---------------------------------------------------------------
-- 5. Database Ownership Boundary
--
-- Database owned by NOLOGIN role.
--
---------------------------------------------------------------


DO $$
BEGIN

    EXECUTE format(
        'ALTER DATABASE %I OWNER TO cad_database_owner',
        current_database()
    );

END
$$;



---------------------------------------------------------------
-- 6. Application Permissions
---------------------------------------------------------------


GRANT cad_read_executor
TO cad_api_gateway;


GRANT cad_write_executor
TO cad_api_gateway;


GRANT cad_audit_writer
TO cad_api_gateway;



---------------------------------------------------------------
-- 7. Public Schema Protection
---------------------------------------------------------------


REVOKE ALL
ON SCHEMA public
FROM PUBLIC;



ALTER SCHEMA public
OWNER TO cad_database_owner;



---------------------------------------------------------------
-- 8. Audit Protection
--
-- Application cannot rewrite history.
---------------------------------------------------------------


DO $$
BEGIN

IF EXISTS
(
    SELECT
    FROM pg_tables
    WHERE tablename='audit_events'
)

THEN


    REVOKE UPDATE, DELETE
    ON audit_events
    FROM cad_api_gateway;



    GRANT INSERT, SELECT
    ON audit_events
    TO cad_audit_writer;


END IF;


END
$$;



---------------------------------------------------------------
-- 9. Default Privilege Protection
--
-- Future objects inherit security.
---------------------------------------------------------------


ALTER DEFAULT PRIVILEGES
FOR ROLE cad_database_owner

REVOKE ALL
ON TABLES
FROM PUBLIC;



ALTER DEFAULT PRIVILEGES
FOR ROLE cad_database_owner

GRANT SELECT
ON TABLES
TO cad_read_executor;



ALTER DEFAULT PRIVILEGES
FOR ROLE cad_database_owner

GRANT USAGE, SELECT
ON SEQUENCES
TO cad_read_executor;



---------------------------------------------------------------
-- 10. Function Protection
--
-- Prevent arbitrary function execution.
---------------------------------------------------------------


REVOKE EXECUTE
ON ALL FUNCTIONS
IN SCHEMA public
FROM PUBLIC;



---------------------------------------------------------------
-- 11. Database Security Events
--
-- Records PostgreSQL security events.
---------------------------------------------------------------


CREATE TABLE IF NOT EXISTS security_database_events
(

    event_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    event_time TIMESTAMPTZ
        NOT NULL DEFAULT now(),


    database_user TEXT
        NOT NULL DEFAULT current_user,


    client_address INET,


    event_type TEXT
        NOT NULL,


    event_detail JSONB


);



ALTER TABLE security_database_events
OWNER TO cad_database_owner;



REVOKE UPDATE, DELETE
ON security_database_events
FROM PUBLIC;



GRANT INSERT
ON security_database_events
TO cad_audit_writer;



---------------------------------------------------------------
-- 12. Final Protection
---------------------------------------------------------------


REVOKE TRUNCATE
ON ALL TABLES
IN SCHEMA public
FROM PUBLIC;



COMMIT;
