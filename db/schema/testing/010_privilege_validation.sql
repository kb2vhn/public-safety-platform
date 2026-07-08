-- ============================================================================
-- 010_privilege_validation.sql
--
-- Privilege Model Validation
--
-- Goals:
--   - Create application roles
--   - Establish least privilege
--   - Validate access boundaries
--   - Support repeatable schema rebuilds
--
-- Depends On:
--   000-009
--
-- ============================================================================

BEGIN;


------------------------------------------------------------
-- ROLES
------------------------------------------------------------

DO $$
BEGIN

    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'cad_application'
    )
    THEN

        CREATE ROLE cad_application
        NOLOGIN;

    END IF;


    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'cad_readonly'
    )
    THEN

        CREATE ROLE cad_readonly
        NOLOGIN;

    END IF;


    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'cad_auditor'
    )
    THEN

        CREATE ROLE cad_auditor
        NOLOGIN;

    END IF;


END
$$;


------------------------------------------------------------
-- REMOVE PUBLIC ACCESS
------------------------------------------------------------

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



------------------------------------------------------------
-- APPLICATION ROLE
------------------------------------------------------------

GRANT USAGE
ON SCHEMA public
TO cad_application;


GRANT SELECT, INSERT, UPDATE
ON personnel
TO cad_application;


GRANT SELECT, INSERT, UPDATE
ON personnel_certifications
TO cad_application;


GRANT SELECT, INSERT, UPDATE
ON personnel_training
TO cad_application;


GRANT SELECT, INSERT, UPDATE
ON personnel_specialties
TO cad_application;


GRANT SELECT, INSERT, UPDATE
ON personnel_specialty_assignments
TO cad_application;


GRANT SELECT, INSERT, UPDATE
ON personnel_duty_status
TO cad_application;


GRANT SELECT, INSERT
ON dispatch_events
TO cad_application;


GRANT SELECT, INSERT
ON radio_log_events
TO cad_application;


GRANT SELECT, INSERT
ON unit_locations
TO cad_application;


GRANT SELECT, INSERT, UPDATE
ON officer_safety_events
TO cad_application;



------------------------------------------------------------
-- READ ONLY ROLE
------------------------------------------------------------

GRANT USAGE
ON SCHEMA public
TO cad_readonly;


GRANT SELECT
ON ALL TABLES
IN SCHEMA public
TO cad_readonly;



------------------------------------------------------------
-- AUDITOR ROLE
------------------------------------------------------------

GRANT USAGE
ON SCHEMA public
TO cad_auditor;


GRANT SELECT
ON audit_events
TO cad_auditor;


GRANT SELECT
ON audit_integrity_checks
TO cad_auditor;


GRANT SELECT
ON audit_retention_policy
TO cad_auditor;



------------------------------------------------------------
-- DEFAULT PRIVILEGES
------------------------------------------------------------

ALTER DEFAULT PRIVILEGES
IN SCHEMA public
GRANT SELECT
ON TABLES
TO cad_readonly;


ALTER DEFAULT PRIVILEGES
IN SCHEMA public
GRANT SELECT
ON TABLES
TO cad_auditor;



------------------------------------------------------------
-- SECURITY VALIDATION
------------------------------------------------------------

DO $$
DECLARE

    missing_count INTEGER;

BEGIN

    SELECT COUNT(*)
    INTO missing_count
    FROM pg_roles
    WHERE rolname IN
    (
        'cad_application',
        'cad_readonly',
        'cad_auditor'
    );


    IF missing_count <> 3 THEN

        RAISE EXCEPTION
        'Privilege validation failed: expected roles missing';

    END IF;


END
$$;



COMMIT;
