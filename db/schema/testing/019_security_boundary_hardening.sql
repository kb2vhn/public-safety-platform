/*
================================================================================
019_security_boundary_hardening.sql

Purpose:
    Harden the PostgreSQL security execution boundary.

Security Model:
    This migration enforces the principle that privileged database functions
    must execute in a controlled namespace and never inherit caller-controlled
    object resolution.

Controls Implemented:

    1. SECURITY DEFINER search_path enforcement
       --------------------------------------
       All SECURITY DEFINER functions in the security schema are assigned:

           search_path = security, public, pg_catalog

       This prevents:
           - schema hijacking
           - malicious object shadowing
           - unsafe function resolution

    2. Security function inventory validation
       --------------------------------------
       Every security function is reviewed to ensure:

           - SECURITY DEFINER functions have pinned search paths
           - privileged execution cannot be influenced by callers

    3. Role boundary preservation
       ---------------------------
       Security execution remains isolated through:

           cad_security
           cad_audit
           cad_application

       These roles are NOLOGIN service identities.

Validation:

    Expected result:

        security_functions          > 0
        missing_search_path         = 0

================================================================================
*/

-- ============================================================
-- 019_security_boundary_hardening.sql
--
-- Part 1
--
-- SECURITY DEFINER Ownership Normalization
--
-- Move security API functions from developer ownership
-- to dedicated security owner.
--
-- ============================================================


BEGIN;


-- ============================================================
-- Session lifecycle functions
-- ============================================================


ALTER FUNCTION security.activate_session(uuid, text)
OWNER TO cad_security;


ALTER FUNCTION security.expire_session(uuid, text)
OWNER TO cad_security;


ALTER FUNCTION security.revoke_session(uuid, text)
OWNER TO cad_security;


ALTER FUNCTION security.terminate_session(uuid, text)
OWNER TO cad_security;


ALTER FUNCTION security.validate_active_session(uuid)
OWNER TO cad_security;



-- ============================================================
-- Session auditing functions
-- ============================================================


ALTER FUNCTION security.audit_session_event(uuid, text, text, jsonb)
OWNER TO cad_security;


ALTER FUNCTION security.audit_session_revocation(uuid, text)
OWNER TO cad_security;



-- ============================================================
-- Session validation helpers
-- ============================================================


ALTER FUNCTION security.validate_session_identity(uuid)
OWNER TO cad_security;


ALTER FUNCTION security.validate_session_device(uuid)
OWNER TO cad_security;


ALTER FUNCTION security.validate_session_state(uuid)
OWNER TO cad_security;


-- ============================================================
-- Context helpers
-- ============================================================


ALTER FUNCTION security.current_identity()
OWNER TO cad_security;


ALTER FUNCTION security.current_person()
OWNER TO cad_security;


ALTER FUNCTION security.current_device()
OWNER TO cad_security;


ALTER FUNCTION security.current_agency()
OWNER TO cad_security;



COMMIT;


-- ============================================================
-- End Part 1
-- ============================================================

-- ============================================================
-- 019_security_boundary_hardening.sql
--
-- Part 2
--
-- AUDIT OWNERSHIP BOUNDARY NORMALIZATION
--
-- Purpose:
--
-- SECURITY DEFINER functions execute with the privileges of
-- their owning role. Audit-writing functions must not remain
-- owned by a developer account because ownership determines the
-- privilege boundary used during execution.
--
-- This migration moves audit-related security functions from
-- the deployment/developer account to the dedicated audit owner:
--
--      cad_audit
--
-- Design model:
--
--      cad_application
--              |
--              v
--       security API layer
--              |
--              +----------------+
--              |                |
--              v                v
--       cad_security       cad_audit
--       authentication     immutable audit
--
--
-- The audit subsystem owns the ability to create audit records.
-- The security subsystem owns identity/session authorization.
--
-- This separation supports:
--
--   - Least privilege
--   - Separation of duties
--   - Reduced blast radius
--   - Stronger audit integrity
--   - Future compliance requirements
--
-- ============================================================


BEGIN;



-- ============================================================
-- Transfer authorization audit ownership
--
-- Writes authorization decisions into the cryptographic
-- audit chain.
--
-- Previous owner:
--
--      jwood
--
-- New owner:
--
--      cad_audit
--
-- ============================================================


ALTER FUNCTION security.audit_authorization_decision(
    text,
    security.authorization_result
)
OWNER TO cad_audit;



-- ============================================================
-- Transfer session lifecycle audit ownership
--
-- Records session state transitions:
--
--      REQUESTED
--      ACTIVE
--      EXPIRED
--      REVOKED
--      TERMINATED
--
-- These records become part of the security audit history.
--
-- ============================================================


ALTER FUNCTION security.record_session_lifecycle_event(
    uuid,
    session_state,
    session_state,
    text
)
OWNER TO cad_audit;



-- ============================================================
-- Transfer session validation audit ownership
--
-- Records security validation attempts including:
--
--      - successful validation
--      - failed validation
--      - failure reason
--
-- This allows security monitoring without granting broader
-- application privileges.
--
-- ============================================================


ALTER FUNCTION security.record_session_validation_event(
    uuid,
    text,
    boolean,
    text
)
OWNER TO cad_audit;



-- ============================================================
-- Commit ownership boundary changes
--
-- ============================================================


COMMIT;



-- ============================================================
-- End Part 2
-- ============================================================

-- ============================================================
-- 019_security_boundary_hardening.sql
--
-- Part 3
--
-- SECURITY DEFINER EXECUTION BOUNDARY HARDENING
--
-- Purpose:
--
-- SECURITY DEFINER functions execute with the privileges of
-- their owner. This migration reduces unintended execution
-- paths by:
--
--   1. Removing PUBLIC EXECUTE privileges
--   2. Granting execution only to approved security roles
--   3. Locking function search_path resolution
--
--
-- Security model:
--
--       cad_application
--              |
--              v
--       security API functions
--              |
--              v
--       cad_security / cad_audit owners
--
--
-- No untrusted database role should be able to execute these
-- functions directly.
--
-- ============================================================


BEGIN;



-- ============================================================
-- Session management functions
--
-- These functions control authentication session lifecycle.
--
-- Remove default PostgreSQL PUBLIC execution.
-- Grant only application access.
--
-- ============================================================


REVOKE EXECUTE
ON FUNCTION security.activate_session(uuid,text)
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION security.activate_session(uuid,text)
TO cad_application;



REVOKE EXECUTE
ON FUNCTION security.expire_session(uuid,text)
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION security.expire_session(uuid,text)
TO cad_application;



REVOKE EXECUTE
ON FUNCTION security.revoke_session(uuid,text)
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION security.revoke_session(uuid,text)
TO cad_application;



REVOKE EXECUTE
ON FUNCTION security.terminate_session(uuid,text)
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION security.terminate_session(uuid,text)
TO cad_application;



REVOKE EXECUTE
ON FUNCTION security.validate_active_session(uuid)
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION security.validate_active_session(uuid)
TO cad_application;



-- ============================================================
-- Context lookup functions
--
-- These expose authenticated security context.
-- Application access only.
--
-- ============================================================


REVOKE EXECUTE
ON FUNCTION security.current_identity()
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION security.current_identity()
TO cad_application;



REVOKE EXECUTE
ON FUNCTION security.current_person()
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION security.current_person()
TO cad_application;



REVOKE EXECUTE
ON FUNCTION security.current_device()
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION security.current_device()
TO cad_application;



REVOKE EXECUTE
ON FUNCTION security.current_agency()
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION security.current_agency()
TO cad_application;



-- ============================================================
-- Audit functions
--
-- Only the audit subsystem should write audit records.
--
-- ============================================================


REVOKE EXECUTE
ON FUNCTION security.audit_authorization_decision(
    text,
    security.authorization_result
)
FROM PUBLIC;


GRANT EXECUTE
ON FUNCTION security.audit_authorization_decision(
    text,
    security.authorization_result
)
TO cad_security;



REVOKE EXECUTE
ON FUNCTION security.record_session_lifecycle_event(
    uuid,
    session_state,
    session_state,
    text
)
FROM PUBLIC;


GRANT EXECUTE
ON FUNCTION security.record_session_lifecycle_event(
    uuid,
    session_state,
    session_state,
    text
)
TO cad_security;



REVOKE EXECUTE
ON FUNCTION security.record_session_validation_event(
    uuid,
    text,
    boolean,
    text
)
FROM PUBLIC;


GRANT EXECUTE
ON FUNCTION security.record_session_validation_event(
    uuid,
    text,
    boolean,
    text
)
TO cad_security;



COMMIT;



-- ============================================================
-- End Part 3
-- ============================================================

-- ============================================================
-- 019_security_boundary_hardening.sql
--
-- Part 4
--
-- SECURITY DEFINER SEARCH PATH HARDENING
--
-- Purpose:
--
-- SECURITY DEFINER functions execute with elevated privileges.
-- This migration prevents object resolution attacks by forcing
-- security functions to use a controlled search_path.
--
--
-- Design rule:
--
-- SECURITY DEFINER functions must never depend on the caller's
-- search_path.
--
--
-- Execution model:
--
--      Caller
--        |
--        v
--  SECURITY DEFINER function
--        |
--        v
-- search_path = security, public, pg_catalog
--
--
-- ============================================================


BEGIN;



-- ============================================================
-- Session security functions
-- ============================================================


ALTER FUNCTION security.activate_session(uuid,text)
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.expire_session(uuid,text)
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.revoke_session(uuid,text)
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.terminate_session(uuid,text)
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.validate_active_session(uuid)
SET search_path = security, public, pg_catalog;



-- ============================================================
-- Security context functions
-- ============================================================


ALTER FUNCTION security.current_identity()
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.current_person()
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.current_device()
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.current_agency()
SET search_path = security, public, pg_catalog;



-- ============================================================
-- Authorization functions
-- ============================================================


ALTER FUNCTION security.is_authorized(text)
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.is_allowed(text)
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.require_role(text)
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.require_capability(text)
SET search_path = security, public, pg_catalog;



-- ============================================================
-- Audit boundary functions
-- ============================================================


ALTER FUNCTION security.audit_authorization_decision(
    text,
    security.authorization_result
)
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.record_session_lifecycle_event(
    uuid,
    session_state,
    session_state,
    text
)
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.record_session_validation_event(
    uuid,
    text,
    boolean,
    text
)
SET search_path = security, public, pg_catalog;



COMMIT;



-- ============================================================
-- End Part 4
-- ============================================================

-- ============================================================
-- 019_security_boundary_hardening.sql
--
-- Part 4B
--
-- Complete SECURITY DEFINER SEARCH PATH NORMALIZATION
--
-- Purpose:
--
-- Normalize remaining SECURITY DEFINER functions so every
-- privileged function executes with a controlled namespace.
--
-- ============================================================


BEGIN;


-- Identity lifecycle functions

ALTER FUNCTION security.activate_identity(uuid,text)
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.change_identity_lifecycle_state(
    uuid,
    identity_lifecycle_state,
    text
)
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.lock_identity(uuid,text)
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.retire_identity(uuid,text)
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.revoke_identity(uuid,text)
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.suspend_identity(uuid,text)
SET search_path = security, public, pg_catalog;



-- Validation functions

ALTER FUNCTION security.validate_device()
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.validate_identity()
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.validate_person()
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.validate_security_context()
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.validate_session()
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.validate_session_device(uuid)
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.validate_session_identity(uuid)
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.validate_session_state(uuid)
SET search_path = security, public, pg_catalog;



-- Authorization helpers

ALTER FUNCTION security.authorization_reason(text)
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.current_capabilities()
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.current_roles()
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.has_active_assignment()
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.has_capability(text)
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.has_role(text)
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.role_has_capability(uuid,uuid)
SET search_path = security, public, pg_catalog;



-- Remaining audit/session functions

ALTER FUNCTION security.audit_session_event(
    uuid,
    text,
    text,
    jsonb
)
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.audit_session_revocation(
    uuid,
    text
)
SET search_path = security, public, pg_catalog;



-- Operational record controls

ALTER FUNCTION security.finalize_operational_record(
    text,
    uuid
)
SET search_path = security, public, pg_catalog;


ALTER FUNCTION security.seal_operational_record(
    text,
    uuid
)
SET search_path = security, public, pg_catalog;



COMMIT;


-- ============================================================
-- End Part 4B
-- ============================================================

-- ============================================================
-- 019_security_boundary_hardening.sql
--
-- PART 4c
--
-- Purpose:
--     Normalize remaining security schema functions that do not
--     currently define an explicit search_path.
--
-- Security Model:
--
--     The security schema is responsible for:
--
--       * identity validation
--       * authorization decisions
--       * session security
--       * operational record protection
--
--     All security functions must have deterministic object
--     resolution.
--
-- Threat Mitigation:
--
--     PostgreSQL resolves unqualified objects using search_path.
--
--     Without an explicit search_path a malicious user with
--     CREATE privileges in a searched schema could introduce
--     shadow objects.
--
--     This migration ensures every security function resolves
--     objects only from:
--
--          security
--          public
--          pg_catalog
--
-- ============================================================


BEGIN;


-- ============================================================
-- current_role()
--
-- Purpose:
--     Returns the current operational role associated with the
--     active security context.
--
-- Security Boundary:
--     Used by authorization checks.
--
-- Change:
--     Explicit search_path enforcement.
-- ============================================================

ALTER FUNCTION security.current_role()
SET search_path = security, public, pg_catalog;



-- ============================================================
-- current_user_id()
--
-- Purpose:
--     Returns the authenticated database/application identity.
--
-- Security Boundary:
--     Prevents authorization checks from relying on raw database
--     users.
--
-- Change:
--     Explicit search_path enforcement.
-- ============================================================

ALTER FUNCTION security.current_user_id()
SET search_path = security, public, pg_catalog;



-- ============================================================
-- is_sys_admin()
--
-- Purpose:
--     Determines whether the current security context possesses
--     system administrator authority.
--
-- Security Boundary:
--     Used by privileged operations.
--
-- Change:
--     Explicit search_path enforcement.
-- ============================================================

ALTER FUNCTION security.is_sys_admin()
SET search_path = security, public, pg_catalog;



-- ============================================================
-- prevent_sealed_record_change()
--
-- Purpose:
--     Trigger protection function preventing modification of
--     sealed operational records.
--
-- Security Boundary:
--     Protects chain-of-custody and immutable records.
--
-- Change:
--     Explicit search_path enforcement.
-- ============================================================

ALTER FUNCTION security.prevent_sealed_record_change()
SET search_path = security, public, pg_catalog;



-- ============================================================
-- same_agency(uuid)
--
-- Purpose:
--     Determines whether the current security context and the
--     target agency belong to the same authorization boundary.
--
-- Security Boundary:
--     Prevents unauthorized cross-agency access.
--
-- Change:
--     Explicit search_path enforcement.
-- ============================================================

ALTER FUNCTION security.same_agency(uuid)
SET search_path = security, public, pg_catalog;



COMMIT;



-- ============================================================
-- Validation
--
-- Expected Result:
--
-- security_functions            = 49
-- security_definer_functions    = 44
-- missing_search_path           = 0
--
-- ============================================================


SELECT
    count(*) AS security_functions,
    count(*) FILTER (WHERE prosecdef = true)
        AS security_definer_functions,
    count(*) FILTER (WHERE proconfig IS NULL)
        AS missing_search_path
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname='security';



-- ============================================================
-- Detailed verification
--
-- Expected:
--
-- No rows returned.
--
-- ============================================================


SELECT
    n.nspname,
    p.proname,
    pg_get_function_identity_arguments(p.oid)
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname='security'
AND p.proconfig IS NULL
ORDER BY p.proname;


/*
===============================================================================
019_security_boundary_hardening.sql

PART 5
FUNCTION OWNERSHIP BOUNDARY ENFORCEMENT

Purpose:
    Ensure security functions are owned only by protected security roles.

Security Model:
    cad_application
        - May EXECUTE approved functions
        - May NOT alter security logic

    cad_security
        - Owns identity/session/security enforcement functions

    cad_audit
        - Owns audit integrity functions

    jwood/admin users
        - Must not own security boundary functions

===============================================================================
*/


BEGIN;


-------------------------------------------------------------------------------
-- Ensure security functions are owned by cad_security
-------------------------------------------------------------------------------

DO
$$
DECLARE
    r record;
BEGIN

    FOR r IN
        SELECT
            n.nspname,
            p.proname,
            pg_get_function_identity_arguments(p.oid) AS args
        FROM pg_proc p
        JOIN pg_namespace n
            ON n.oid = p.pronamespace
        WHERE n.nspname = 'security'
        AND p.prosecdef = true
    LOOP

        EXECUTE format(
            'ALTER FUNCTION %I.%I(%s) OWNER TO cad_security',
            r.nspname,
            r.proname,
            r.args
        );

    END LOOP;

END;
$$;


-------------------------------------------------------------------------------
-- Explicit ownership correction for audit functions
-------------------------------------------------------------------------------

ALTER FUNCTION security.audit_session_event(
    uuid,
    text,
    text,
    jsonb
)
OWNER TO cad_audit;


ALTER FUNCTION security.audit_session_revocation(
    uuid,
    text
)
OWNER TO cad_audit;


ALTER FUNCTION security.audit_authorization_decision(
    text,
    security.authorization_result
)
OWNER TO cad_audit;



-------------------------------------------------------------------------------
-- Remove dangerous implicit privileges
-------------------------------------------------------------------------------

REVOKE ALL
ON ALL FUNCTIONS IN SCHEMA security
FROM PUBLIC;



-------------------------------------------------------------------------------
-- Restore controlled execution access
-------------------------------------------------------------------------------

GRANT EXECUTE
ON ALL FUNCTIONS IN SCHEMA security
TO cad_application;



-------------------------------------------------------------------------------
-- Prevent application role inheritance escalation
-------------------------------------------------------------------------------

REVOKE cad_security FROM cad_application;

REVOKE cad_audit FROM cad_application;



-------------------------------------------------------------------------------
-- Verification record
-------------------------------------------------------------------------------

COMMENT ON SCHEMA security IS
'Security enforcement boundary. Functions are owned by protected roles and executed through controlled privileges.';



COMMIT;


/*
================================================================================
019_security_boundary_hardening.sql
PART 6 - SECURITY FUNCTION OWNERSHIP HARDENING

Purpose:
    Remove human ownership from security boundary functions.

Security Model:

    cad_security
        Owns:
            - authentication context functions
            - authorization helper functions
            - integrity enforcement functions
            - security validation functions


    cad_audit
        Owns:
            - audit recording functions


    jwood
        Must NOT own security enforcement logic.

Reason:

    Ownership is a security boundary in PostgreSQL.

    A role that owns a function can:
        - replace the function body
        - alter behavior
        - bypass intended controls

Therefore security enforcement functions must be owned
by controlled service roles.

================================================================================
*/


BEGIN;


-------------------------------------------------------------------------------
-- PART 6.1
-- Transfer remaining security boundary functions
-------------------------------------------------------------------------------

ALTER FUNCTION security.current_role()
OWNER TO cad_security;


ALTER FUNCTION security.current_user_id()
OWNER TO cad_security;


ALTER FUNCTION security.is_sys_admin()
OWNER TO cad_security;


ALTER FUNCTION security.prevent_sealed_record_change()
OWNER TO cad_security;


ALTER FUNCTION security.same_agency(uuid)
OWNER TO cad_security;



-------------------------------------------------------------------------------
-- PART 6.2
-- Document security boundary functions
-------------------------------------------------------------------------------


COMMENT ON FUNCTION security.current_role()
IS
'Security boundary function.

Returns the active role associated with the current
security context.

Ownership:
    cad_security

Used by:
    - authorization checks
    - role validation
    - policy evaluation

This function is not intended for direct application use.';


COMMENT ON FUNCTION security.current_user_id()
IS
'Security boundary function.

Returns the authenticated identity identifier
from the active security context.

Ownership:
    cad_security

Used for:
    - identity attribution
    - authorization decisions
    - audit correlation

Must execute only through controlled security paths.';



COMMENT ON FUNCTION security.is_sys_admin()
IS
'Security boundary authorization function.

Determines whether the current security context
has system administrator authority.

Ownership:
    cad_security

Used for:
    - privileged administrative checks
    - protected operations

This function must never be controlled by application users.';



COMMENT ON FUNCTION security.prevent_sealed_record_change()
IS
'Security integrity trigger function.

Prevents modification of sealed operational records.

Ownership:
    cad_security

Purpose:
    Protect immutable operational records after sealing.

This function is part of the operational record
integrity boundary.';



COMMENT ON FUNCTION security.same_agency(uuid)
IS
'Security boundary authorization function.

Determines whether the target agency matches
the current security context agency.

Ownership:
    cad_security

Used for:
    - agency isolation
    - multi-agency authorization enforcement
    - tenant boundary validation.';



-------------------------------------------------------------------------------
-- PART 6.3
-- Security ownership verification
-------------------------------------------------------------------------------

DO
$$
DECLARE
    remaining integer;
BEGIN

    SELECT count(*)
    INTO remaining
    FROM pg_proc p
    JOIN pg_namespace n
        ON n.oid = p.pronamespace
    WHERE n.nspname = 'security'
    AND pg_get_userbyid(p.proowner) = 'jwood';


    IF remaining > 0 THEN
        RAISE EXCEPTION
        'Security boundary still contains % functions owned by jwood',
        remaining;
    END IF;


END;
$$;



-------------------------------------------------------------------------------
-- PART 6.4
-- Final documentation marker
-------------------------------------------------------------------------------

COMMENT ON SCHEMA security
IS
'Security boundary schema.

Contains controlled security enforcement logic.

Ownership rules:

    cad_security
        owns security enforcement functions.

    cad_audit
        owns audit recording functions.

    Human accounts must not own
    security boundary objects.

This separation protects:
    - confidentiality
    - integrity
    - authorization correctness
    - audit reliability.';



COMMIT;


/*
================================================================================
PART 6 COMPLETE

Verification:

Run:

SELECT
    p.proname,
    pg_get_userbyid(p.proowner)
FROM pg_proc p
JOIN pg_namespace n
ON n.oid=p.pronamespace
WHERE n.nspname='security'
ORDER BY p.proname;


Expected:

    cad_security
    cad_audit

No jwood ownership should remain.

================================================================================
*/

/*
================================================================================
019_security_boundary_hardening.sql
PART 7 - SECURITY FUNCTION EXECUTION PRIVILEGE HARDENING

Purpose:

    Remove unrestricted EXECUTE access from PUBLIC.

Security Model:

    Ownership controls who can modify functions.

    EXECUTE privileges control who can call functions.

Both controls are required.

Rules:

    PUBLIC
        Must not execute security boundary functions.

    cad_security
        Owns and executes security functions.

    cad_audit
        Owns and executes audit functions.

    cad_application
        Receives only explicitly approved execution paths.

================================================================================
*/


BEGIN;



-------------------------------------------------------------------------------
-- PART 7.1
-- Remove PUBLIC execution from all security functions
--
-- This closes the default PostgreSQL EXECUTE exposure.
-------------------------------------------------------------------------------

DO
$$
DECLARE
    r record;
BEGIN

    FOR r IN
        SELECT
            n.nspname,
            p.proname,
            pg_get_function_identity_arguments(p.oid) AS args
        FROM pg_proc p
        JOIN pg_namespace n
            ON n.oid = p.pronamespace
        WHERE n.nspname = 'security'
    LOOP

        EXECUTE format(
            'REVOKE EXECUTE ON FUNCTION %I.%I(%s) FROM PUBLIC',
            r.nspname,
            r.proname,
            r.args
        );

    END LOOP;

END;
$$;



-------------------------------------------------------------------------------
-- PART 7.2
-- Restore internal security execution rights
-------------------------------------------------------------------------------

GRANT EXECUTE
ON ALL FUNCTIONS IN SCHEMA security
TO cad_security;



-------------------------------------------------------------------------------
-- PART 7.3
-- Restore audit execution rights
--
-- Audit functions are separated from security logic.
-------------------------------------------------------------------------------

GRANT EXECUTE
ON FUNCTION security.audit_authorization_decision(
    text,
    security.authorization_result
)
TO cad_audit;


GRANT EXECUTE
ON FUNCTION security.audit_session_event(
    uuid,
    text,
    text,
    jsonb
)
TO cad_audit;


GRANT EXECUTE
ON FUNCTION security.audit_session_revocation(
    uuid,
    text
)
TO cad_audit;



-------------------------------------------------------------------------------
-- PART 7.4
-- Document privilege boundary
-------------------------------------------------------------------------------

COMMENT ON SCHEMA security
IS
'Security boundary schema.

Privilege model:

Ownership:
    cad_security
        owns security enforcement functions.

    cad_audit
        owns audit recording functions.


Execution:

    PUBLIC
        denied execution.

    cad_security
        executes security boundary functions.

    cad_audit
        executes audit recording functions.

    Application access must be provided
    through explicit approved interfaces.

Purpose:

Prevent unauthorized invocation,
modification, or bypass of security controls.';



-------------------------------------------------------------------------------
-- PART 7.5
-- Verification
-------------------------------------------------------------------------------

DO
$$
DECLARE
    public_exec integer;
BEGIN

    SELECT count(*)
    INTO public_exec
    FROM information_schema.routine_privileges
    WHERE routine_schema='security'
    AND grantee='PUBLIC'
    AND privilege_type='EXECUTE';


    IF public_exec > 0 THEN

        RAISE EXCEPTION
        'Security schema still has % PUBLIC EXECUTE privileges',
        public_exec;

    END IF;


END;
$$;



COMMIT;


/*
================================================================================
PART 7 COMPLETE

Validation:

Run:

SELECT
    grantee,
    count(*)
FROM information_schema.routine_privileges
WHERE routine_schema='security'
AND privilege_type='EXECUTE'
GROUP BY grantee
ORDER BY grantee;


Expected:

cad_security   49
cad_audit       3

PUBLIC          0


================================================================================
*/

BEGIN;


/*
===============================================================================
019_security_boundary_hardening.sql
PART 7A - APPLICATION EXECUTION BOUNDARY CORRECTION

Purpose:

Remove broad security function execution from the application role.

The application must not directly execute the entire security engine.

Only explicitly approved API functions should later be granted.

===============================================================================
*/


REVOKE EXECUTE
ON ALL FUNCTIONS IN SCHEMA security
FROM cad_application;



COMMENT ON ROLE cad_application
IS
'Application execution role.

Security model:

- Cannot own security objects.
- Cannot modify security functions.
- Cannot execute internal security engine functions.

Application access must be provided through
explicit approved interfaces only.';



COMMIT;

/*
================================================================================
019_security_boundary_hardening.sql

PART 8 - FINAL SECURITY BOUNDARY VALIDATION
AND SELF DOCUMENTATION

Purpose:

Create permanent security validation reporting.

This section does not grant additional privileges.

It provides an internal audit capability proving that
the security boundary remains intact.

Security Principles:

1. Least privilege
2. Separation of duties
3. Explicit ownership
4. Explicit execution rights
5. SECURITY DEFINER protection
6. Row Level Security enforcement
7. Audit isolation

================================================================================
*/


BEGIN;



-------------------------------------------------------------------------------
-- PART 8.1
-- Create security validation schema
--
-- This schema contains only administrative validation views.
-------------------------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS security_validation;


COMMENT ON SCHEMA security_validation
IS
'Administrative security validation schema.

Contains read-only security posture reports.

Purpose:

Provide continuous verification of:

- ownership boundaries
- execution privileges
- SECURITY DEFINER hardening
- RLS deployment
- role isolation

This schema does not contain application data.
';



-------------------------------------------------------------------------------
-- PART 8.2
-- Security function ownership report
-------------------------------------------------------------------------------

CREATE OR REPLACE VIEW security_validation.function_ownership
AS
SELECT
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid)
        AS arguments,
    pg_get_userbyid(p.proowner)
        AS owner,
    p.prosecdef
        AS security_definer
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname='security';



COMMENT ON VIEW security_validation.function_ownership
IS
'Reports ownership of security schema functions.

Expected:

cad_security owns security enforcement functions.

cad_audit owns audit functions.

Human accounts should own zero security functions.
';



-------------------------------------------------------------------------------
-- PART 8.3
-- SECURITY DEFINER hardening report
-------------------------------------------------------------------------------

CREATE OR REPLACE VIEW security_validation.security_definer_hardening
AS
SELECT
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid)
        AS arguments,
    p.prosecdef AS security_definer,
    p.proconfig AS configuration
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid=p.pronamespace
WHERE n.nspname='security';



COMMENT ON VIEW security_validation.security_definer_hardening
IS
'Reports SECURITY DEFINER functions.

All SECURITY DEFINER functions must have
explicit search_path configuration.

Expected:

missing search_path = 0
';



-------------------------------------------------------------------------------
-- PART 8.4
-- Function execution privilege report
-------------------------------------------------------------------------------

CREATE OR REPLACE VIEW security_validation.function_execution_privileges
AS
SELECT
    grantee,
    routine_schema,
    routine_name,
    privilege_type
FROM information_schema.routine_privileges
WHERE routine_schema='security';



COMMENT ON VIEW security_validation.function_execution_privileges
IS
'Reports execution rights against security functions.

Expected:

PUBLIC:
    zero privileges

cad_application:
    zero unrestricted security execution

cad_security:
    security execution

cad_audit:
    audit execution
';



-------------------------------------------------------------------------------
-- PART 8.5
-- RLS enforcement report
-------------------------------------------------------------------------------

CREATE OR REPLACE VIEW security_validation.row_security_status
AS
SELECT
    n.nspname AS schema_name,
    c.relname AS table_name,
    c.relrowsecurity AS rls_enabled,
    c.relforcerowsecurity AS rls_forced
FROM pg_class c
JOIN pg_namespace n
    ON n.oid=c.relnamespace
WHERE n.nspname IN ('public','security')
AND c.relkind='r';



COMMENT ON VIEW security_validation.row_security_status
IS
'Reports Row Level Security deployment.

Used to verify that sensitive operational tables
maintain tenant and authorization boundaries.
';



-------------------------------------------------------------------------------
-- PART 8.6
-- Role membership isolation report
-------------------------------------------------------------------------------

CREATE OR REPLACE VIEW security_validation.role_membership_boundary
AS
SELECT
    member.rolname AS member,
    parent.rolname AS granted_role
FROM pg_auth_members m
JOIN pg_roles parent
    ON parent.oid=m.roleid
JOIN pg_roles member
    ON member.oid=m.member
WHERE member.rolname IN
(
    'cad_application',
    'cad_security',
    'cad_audit'
);



COMMENT ON VIEW security_validation.role_membership_boundary
IS
'Reports security role inheritance.

Expected:

No implicit membership between:

cad_application
cad_security
cad_audit

All access must be explicit.
';



-------------------------------------------------------------------------------
-- PART 8.7
-- Final security boundary summary
-------------------------------------------------------------------------------

CREATE OR REPLACE VIEW security_validation.security_boundary_summary
AS

SELECT
    'Security Functions' AS check_name,
    count(*)::text AS result
FROM pg_proc p
JOIN pg_namespace n
ON n.oid=p.pronamespace
WHERE n.nspname='security'


UNION ALL


SELECT
    'Security Definer Functions',
    count(*)::text
FROM pg_proc p
JOIN pg_namespace n
ON n.oid=p.pronamespace
WHERE n.nspname='security'
AND p.prosecdef=true


UNION ALL


SELECT
    'Functions Missing Search Path',
    count(*)::text
FROM pg_proc p
JOIN pg_namespace n
ON n.oid=p.pronamespace
WHERE n.nspname='security'
AND p.proconfig IS NULL;


COMMENT ON VIEW security_validation.security_boundary_summary
IS
'High level security boundary verification.

Healthy expected values:

Security Functions:
    49

Security Definer Functions:
    44

Functions Missing Search Path:
    0
';



-------------------------------------------------------------------------------
-- PART 8.8
-- Final documentation
-------------------------------------------------------------------------------

COMMENT ON DATABASE cad_testing
IS
'Public Safety CAD Security Architecture.

Implemented security boundary:

Ownership:

    cad_security
        Owns security enforcement logic.

    cad_audit
        Owns audit recording logic.


Execution:

    PUBLIC
        No security execution rights.

    cad_application
        No unrestricted security execution rights.

    Explicit interfaces only.


Function Protection:

    SECURITY DEFINER functions use
    explicit search_path.


Authorization Model:

    Identity
        |
    Session
        |
    Device
        |
    Role
        |
    Capability
        |
    Authorization Decision
        |
    Audit Record


Designed for:

CIA Triad:

Confidentiality:
    Access controlled by identity,
    role, capability, and RLS.

Integrity:
    Ownership separation,
    immutable audit paths.

Availability:
    Controlled execution paths
    and predictable authorization behavior.
';



COMMIT;



/*
================================================================================
019 COMPLETE

FINAL VALIDATION COMMANDS:

SELECT * FROM security_validation.security_boundary_summary;

SELECT * FROM security_validation.function_ownership;

SELECT * FROM security_validation.security_definer_hardening;

SELECT * FROM security_validation.function_execution_privileges;

SELECT * FROM security_validation.row_security_status;

SELECT * FROM security_validation.role_membership_boundary;


Expected:

- No PUBLIC security execution
- No human owned security functions
- No missing SECURITY DEFINER search paths
- No implicit role inheritance
- RLS deployed where required


================================================================================
*/
