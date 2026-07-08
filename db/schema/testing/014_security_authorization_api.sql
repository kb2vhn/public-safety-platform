-- ============================================================================
--
-- 014_security_authorization_api.sql
--
-- Public Safety Platform
--
-- Security Authorization Decision API
--
-- Part 1 - Authorization Result Framework
--
-- ============================================================================
--
-- Purpose:
--
-- This migration creates the foundation for the PostgreSQL security decision
-- engine.
--
-- The database is not responsible for authentication.
--
-- Authentication occurs through the application security layer:
--
--     - Device authentication
--     - Certificate validation
--     - Identity verification
--     - MFA
--     - Session creation
--
-- PostgreSQL is responsible for authorization decisions:
--
--     "Is this action allowed in this security context?"
--
-- The primary interface will become:
--
--     security.is_authorized(action_name)
--
-- Returning:
--
--     - Allow / Deny decision
--     - Decision code
--     - Reason
--     - Evaluation timestamp
--
-- This design prevents applications from implementing their own security
-- logic and creates a single authorization decision point.
--
-- ============================================================================


BEGIN;


-- ============================================================================
-- Security Schema
--
-- The security schema contains database security functions and enforcement
-- logic.
--
-- Existing objects are preserved.
--
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS security;


COMMENT ON SCHEMA security IS

'Database security decision framework. Contains authorization APIs,
security context resolution, and enforcement functions.';


-- ============================================================================
-- Authorization Decision Result Type
--
-- Every authorization decision returns a structured response.
--
-- Example:
--
-- authorized:
--     false
--
-- decision_code:
--     DENY
--
-- reason:
--     DEVICE_CERTIFICATE_EXPIRED
--
-- ============================================================================


DO
$$
BEGIN

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_type
        WHERE typname = 'authorization_result'
        AND typnamespace =
            (
                SELECT oid
                FROM pg_namespace
                WHERE nspname = 'security'
            )
    )

    THEN

        CREATE TYPE security.authorization_result AS
        (
            authorized BOOLEAN,

            decision_code VARCHAR(100),

            reason TEXT,

            evaluated_at TIMESTAMPTZ
        );

    END IF;

END;
$$;



COMMENT ON TYPE security.authorization_result IS

'Structured result returned by security.is_authorized().
Contains authorization decision, reason, and evaluation timestamp.';



-- ============================================================================
-- Authorization Decision Codes
--
-- These codes become stable values used by:
--
--     Application logic
--     Audit events
--     Security monitoring
--     Incident response
--
-- ============================================================================


COMMENT ON TYPE security.authorization_result IS

'Authorization response contract.

Examples:

ALLOW

DENY_SESSION_INVALID

DENY_DEVICE_UNTRUSTED

DENY_CERTIFICATE_EXPIRED

DENY_IDENTITY_INVALID

DENY_PERSON_INACTIVE

DENY_NO_ASSIGNMENT

DENY_CAPABILITY_MISSING

DENY_AUTHORIZATION_REVOKED

';


COMMIT;

-- ============================================================================
--
-- 014_security_authorization_api.sql
--
-- Public Safety Platform
--
-- Security Authorization Decision API
--
-- Part 2 - Security Context Resolution
--
-- ============================================================================
--
-- Purpose:
--
-- Provides secure access to the current PostgreSQL security context.
--
-- The application establishes context after authentication:
--
--     app.session_id
--     app.identity_id
--     app.person_id
--     app.device_id
--     app.agency_id
--
-- These functions provide a single trusted method for retrieving that context.
--
-- No application code should directly parse session variables.
--
-- ============================================================================


BEGIN;


-- ============================================================================
-- Current Session
--
-- Returns the active database security session.
--
-- Source:
--
--     sessions
--
-- ============================================================================


CREATE OR REPLACE FUNCTION security.current_session()

RETURNS UUID

LANGUAGE sql

STABLE

SECURITY DEFINER

SET search_path = pg_catalog, security

AS
$$

SELECT NULLIF
(
    current_setting(
        'app.session_id',
        true
    ),
    ''
)::uuid;

$$;



COMMENT ON FUNCTION security.current_session() IS

'Returns the current authenticated application session identifier.';



-- ============================================================================
-- Current Identity
--
-- Returns the authenticated identity.
--
-- Source:
--
--     identities
--
-- ============================================================================


CREATE OR REPLACE FUNCTION security.current_identity()

RETURNS UUID

LANGUAGE sql

STABLE

SECURITY DEFINER

SET search_path = pg_catalog, security

AS
$$

SELECT NULLIF
(
    current_setting(
        'app.identity_id',
        true
    ),
    ''
)::uuid;

$$;



COMMENT ON FUNCTION security.current_identity() IS

'Returns the current authenticated identity identifier.';



-- ============================================================================
-- Current Person
--
-- Returns the operational person linked to the identity.
--
-- Source:
--
--     persons
--
-- ============================================================================


CREATE OR REPLACE FUNCTION security.current_person()

RETURNS UUID

LANGUAGE sql

STABLE

SECURITY DEFINER

SET search_path = pg_catalog, security

AS
$$

SELECT NULLIF
(
    current_setting(
        'app.person_id',
        true
    ),
    ''
)::uuid;

$$;



COMMENT ON FUNCTION security.current_person() IS

'Returns the current operational person identifier.';



-- ============================================================================
-- Current Device
--
-- Returns the device used for authentication.
--
-- Source:
--
--     devices
--
-- ============================================================================


CREATE OR REPLACE FUNCTION security.current_device()

RETURNS UUID

LANGUAGE sql

STABLE

SECURITY DEFINER

SET search_path = pg_catalog, security

AS
$$

SELECT NULLIF
(
    current_setting(
        'app.device_id',
        true
    ),
    ''
)::uuid;

$$;



COMMENT ON FUNCTION security.current_device() IS

'Returns the authenticated workstation/device identifier.';



-- ============================================================================
-- Current Agency
--
-- Returns the agency security boundary.
--
-- Source:
--
--     security.session_context
--
-- ============================================================================


CREATE OR REPLACE FUNCTION security.current_agency()

RETURNS UUID

LANGUAGE sql

STABLE

SECURITY DEFINER

SET search_path = pg_catalog, security

AS
$$

SELECT sc.agency_id

FROM security.session_context sc

WHERE sc.session_id = security.current_session();

$$;



COMMENT ON FUNCTION security.current_agency() IS

'Returns the agency security boundary for the current session.';



-- ============================================================================
-- Current Session Context
--
-- Returns complete security context.
--
-- Useful for debugging and auditing.
--
-- ============================================================================


CREATE OR REPLACE FUNCTION security.current_context()

RETURNS TABLE
(
    session_id UUID,
    identity_id UUID,
    person_id UUID,
    device_id UUID,
    agency_id UUID
)

LANGUAGE sql

STABLE

SECURITY DEFINER

SET search_path = pg_catalog, security

AS
$$

SELECT

    security.current_session(),

    security.current_identity(),

    security.current_person(),

    security.current_device(),

    security.current_agency();

$$;



COMMENT ON FUNCTION security.current_context() IS

'Returns complete current security context used for authorization evaluation.';



-- ============================================================================
-- Function Permissions
--
-- Remove default public execution.
--
-- Application access will be granted later after the complete API exists.
--
-- ============================================================================


REVOKE ALL
ON FUNCTION security.current_session()
FROM PUBLIC;


REVOKE ALL
ON FUNCTION security.current_identity()
FROM PUBLIC;


REVOKE ALL
ON FUNCTION security.current_person()
FROM PUBLIC;


REVOKE ALL
ON FUNCTION security.current_device()
FROM PUBLIC;


REVOKE ALL
ON FUNCTION security.current_agency()
FROM PUBLIC;


REVOKE ALL
ON FUNCTION security.current_context()
FROM PUBLIC;



COMMIT;

-- ============================================================================
--
-- 014_security_authorization_api.sql
--
-- Public Safety Platform
--
-- Security Authorization Decision API
--
-- Part 3 - Security Context Validation
--
-- ============================================================================
--
-- Purpose:
--
-- Validates that the current security context is legitimate before any
-- authorization decision is made.
--
-- Authorization must never begin with:
--
--     "Does this user have a role?"
--
-- It must begin with:
--
--     "Can I trust this session?"
--
-- Validation chain:
--
--     Session
--        |
--     Identity
--        |
--     Person
--        |
--     Device
--        |
--     Agency
--
-- ============================================================================


BEGIN;


-- ============================================================================
-- Validate Session
--
-- Confirms:
--
--     - Session exists
--     - Session matches current context
--     - Session is active
--     - Session has not expired
--
-- ============================================================================


CREATE OR REPLACE FUNCTION security.validate_session()

RETURNS BOOLEAN

LANGUAGE plpgsql

STABLE

SECURITY DEFINER

SET search_path = pg_catalog, public, security

AS
$$

BEGIN


    RETURN EXISTS
    (

        SELECT 1

        FROM sessions s

        JOIN security.session_context sc

            ON sc.session_id = s.session_id


        WHERE s.session_id = security.current_session()

          AND s.identity_id = security.current_identity()

          AND s.session_state = 'ACTIVE'

          AND sc.identity_id = security.current_identity()

          AND sc.person_id = security.current_person()

          AND sc.agency_id = security.current_agency()

          AND
          (
              s.expires_at IS NULL

              OR

              s.expires_at > now()
          )

    );


END;

$$;



COMMENT ON FUNCTION security.validate_session() IS

'Validates that the current security session exists, is active, and matches
the established security context.';



-- ============================================================================
-- Validate Identity
--
-- Confirms identity ownership of session.
--
-- ============================================================================


CREATE OR REPLACE FUNCTION security.validate_identity()

RETURNS BOOLEAN

LANGUAGE sql

STABLE

SECURITY DEFINER

SET search_path = pg_catalog, public, security

AS
$$


SELECT EXISTS
(

    SELECT 1

    FROM sessions s

    WHERE s.session_id = security.current_session()

      AND s.identity_id = security.current_identity()

);


$$;



COMMENT ON FUNCTION security.validate_identity() IS

'Confirms that the authenticated identity owns the current session.';



-- ============================================================================
-- Validate Person
--
-- Confirms the operational person belongs to current identity context.
--
-- ============================================================================


CREATE OR REPLACE FUNCTION security.validate_person()

RETURNS BOOLEAN

LANGUAGE sql

STABLE

SECURITY DEFINER

SET search_path = pg_catalog, public, security

AS
$$


SELECT EXISTS
(

    SELECT 1

    FROM security.session_context sc

    WHERE sc.session_id = security.current_session()

      AND sc.person_id = security.current_person()

);


$$;



COMMENT ON FUNCTION security.validate_person() IS

'Confirms the current person is attached to the active security session.';



-- ============================================================================
-- Validate Device
--
-- Confirms:
--
--     - Device exists
--     - Device belongs to agency
--     - Device is active
--
-- Certificate validation will be added later using:
--
--     device_certificates
--     device_certificate_validations
--
-- ============================================================================


CREATE OR REPLACE FUNCTION security.validate_device()

RETURNS BOOLEAN

LANGUAGE sql

STABLE

SECURITY DEFINER

SET search_path = pg_catalog, public, security

AS
$$


SELECT EXISTS
(

    SELECT 1

    FROM devices d

    WHERE d.device_id = security.current_device()

      AND d.agency_id = security.current_agency()

      AND d.device_status = 'ACTIVE'

);


$$;



COMMENT ON FUNCTION security.validate_device() IS

'Confirms the authenticated workstation exists and belongs to the agency.';



-- ============================================================================
-- Validate Complete Security Context
--
-- This becomes the first gate for authorization.
--
-- ============================================================================


CREATE OR REPLACE FUNCTION security.validate_security_context()

RETURNS BOOLEAN

LANGUAGE plpgsql

STABLE

SECURITY DEFINER

SET search_path = pg_catalog, public, security

AS
$$

BEGIN


    RETURN

        security.validate_session()

        AND

        security.validate_identity()

        AND

        security.validate_person()

        AND

        security.validate_device();


END;

$$;



COMMENT ON FUNCTION security.validate_security_context() IS

'Validates the complete security context before authorization evaluation.';



-- ============================================================================
-- Security Hardening
-- ============================================================================


REVOKE ALL
ON FUNCTION security.validate_session()
FROM PUBLIC;


REVOKE ALL
ON FUNCTION security.validate_identity()
FROM PUBLIC;


REVOKE ALL
ON FUNCTION security.validate_person()
FROM PUBLIC;


REVOKE ALL
ON FUNCTION security.validate_device()
FROM PUBLIC;


REVOKE ALL
ON FUNCTION security.validate_security_context()
FROM PUBLIC;



COMMIT;
-- ============================================================================
--
-- 014_security_authorization_api.sql
--
-- Public Safety Platform
--
-- Security Authorization Decision API
--
-- Part 4 - Operational Authority Resolution
--
-- ============================================================================
--
-- Purpose:
--
-- Determines whether the current person has an approved operational authority
-- assignment.
--
-- Authority is not derived from:
--
--     - Job title
--     - Department membership
--     - Database administrator status
--     - Application role flags
--
-- Authority is derived from:
--
--     operational_authority_assignments
--
-- which requires:
--
--     - Person
--     - Operational role
--     - Unit assignment
--     - Trust authority approval
--
-- ============================================================================


BEGIN;


-- ============================================================================
-- Check Active Operational Assignment
--
-- Determines whether the current person has an active operational assignment.
--
-- ============================================================================


CREATE OR REPLACE FUNCTION security.has_active_assignment()

RETURNS BOOLEAN

LANGUAGE sql

STABLE

SECURITY DEFINER

SET search_path = pg_catalog, public, security

AS
$$


SELECT EXISTS
(

    SELECT 1

    FROM operational_authority_assignments oaa


    JOIN operational_roles orole

        ON orole.role_id = oaa.role_id


    JOIN trust_authorities ta

        ON ta.authority_id = oaa.approved_by_authority


    WHERE oaa.person_id = security.current_person()


      AND oaa.assignment_status = 'ACTIVE'


      AND orole.active = true


      AND
      (
          oaa.effective_start <= now()
      )


      AND
      (
          oaa.effective_end IS NULL

          OR

          oaa.effective_end >= now()
      )


);


$$;



COMMENT ON FUNCTION security.has_active_assignment() IS

'Determines whether the current person has an active approved operational
assignment.';



-- ============================================================================
-- Check Specific Role
--
-- Used internally by authorization decisions.
--
-- Example:
--
--     security.has_role('SHIFT SUPERVISOR')
--
-- ============================================================================


CREATE OR REPLACE FUNCTION security.has_role(
    requested_role TEXT
)

RETURNS BOOLEAN

LANGUAGE sql

STABLE

SECURITY DEFINER

SET search_path = pg_catalog, public, security

AS
$$


SELECT EXISTS
(

    SELECT 1

    FROM operational_authority_assignments oaa


    JOIN operational_roles r

        ON r.role_id = oaa.role_id


    JOIN trust_authorities ta

        ON ta.authority_id = oaa.approved_by_authority


    WHERE oaa.person_id = security.current_person()


      AND lower(r.role_name) = lower(requested_role)


      AND oaa.assignment_status = 'ACTIVE'


      AND r.active = true


      AND oaa.effective_start <= now()


      AND
      (
          oaa.effective_end IS NULL

          OR

          oaa.effective_end >= now()
      )

);


$$;



COMMENT ON FUNCTION security.has_role(TEXT) IS

'Checks whether the current person holds a specific approved operational role.';



-- ============================================================================
-- Current Operational Roles
--
-- Provides visibility into active assignments.
--
-- Useful for:
--
--     - Audit
--     - Security investigations
--     - Administrative review
--
-- ============================================================================


CREATE OR REPLACE FUNCTION security.current_roles()

RETURNS TABLE
(
    role_id UUID,
    role_name VARCHAR(100),
    unit_id UUID,
    approved_by_authority UUID,
    effective_start TIMESTAMPTZ,
    effective_end TIMESTAMPTZ
)

LANGUAGE sql

STABLE

SECURITY DEFINER

SET search_path = pg_catalog, public, security

AS
$$


SELECT

    r.role_id,

    r.role_name,

    oaa.unit_id,

    oaa.approved_by_authority,

    oaa.effective_start,

    oaa.effective_end


FROM operational_authority_assignments oaa


JOIN operational_roles r

    ON r.role_id = oaa.role_id


WHERE oaa.person_id = security.current_person()


AND oaa.assignment_status = 'ACTIVE'


AND r.active = true


AND oaa.effective_start <= now()


AND
(
    oaa.effective_end IS NULL

    OR

    oaa.effective_end >= now()
);



$$;



COMMENT ON FUNCTION security.current_roles() IS

'Returns currently active operational authority assignments.';



-- ============================================================================
-- Require Active Role
--
-- Helper function for future authorization functions.
--
-- Unlike has_role(), this fails closed.
--
-- ============================================================================


CREATE OR REPLACE FUNCTION security.require_role(
    requested_role TEXT
)

RETURNS VOID

LANGUAGE plpgsql

SECURITY DEFINER

SET search_path = pg_catalog, public, security

AS
$$

BEGIN


    IF NOT security.has_role(requested_role)

    THEN

        RAISE EXCEPTION

        'SECURITY_DENIED: Required role % not assigned',

        requested_role;


    END IF;


END;

$$;



COMMENT ON FUNCTION security.require_role(TEXT) IS

'Stops execution when the current person lacks the required operational role.';



-- ============================================================================
-- Hardening
-- ============================================================================


REVOKE ALL
ON FUNCTION security.has_active_assignment()
FROM PUBLIC;


REVOKE ALL
ON FUNCTION security.has_role(TEXT)
FROM PUBLIC;


REVOKE ALL
ON FUNCTION security.current_roles()
FROM PUBLIC;


REVOKE ALL
ON FUNCTION security.require_role(TEXT)
FROM PUBLIC;



COMMIT;


-- ============================================================================
--
-- 014_security_authorization_api.sql
--
-- Public Safety Platform
--
-- Security Authorization Decision API
--
-- Part 5 - Capability Resolution Engine
--
-- ============================================================================
--
-- Purpose:
--
-- Resolves what actions an operational role is allowed to perform.
--
-- Roles identify responsibility.
--
-- Capabilities identify permitted actions.
--
-- Authorization decisions must be capability based.
--
-- Example:
--
--     SHIFT_SUPERVISOR
--
--          |
--          +--> CAD.INCIDENT.VIEW
--          |
--          +--> CAD.UNIT.ASSIGN
--
-- ============================================================================


BEGIN;


-- ============================================================================
-- Check Capability
--
-- Determines whether the current person has a specific capability through
-- an active operational role.
--
-- ============================================================================


CREATE OR REPLACE FUNCTION security.has_capability(
    requested_capability TEXT
)

RETURNS BOOLEAN

LANGUAGE sql

STABLE

SECURITY DEFINER

SET search_path = pg_catalog, public, security

AS
$$


SELECT EXISTS
(

    SELECT 1


    FROM operational_authority_assignments oaa


    JOIN operational_roles r

        ON r.role_id = oaa.role_id


    JOIN role_capabilities rc

        ON rc.role_id = r.role_id


    JOIN operational_capabilities c

        ON c.capability_id = rc.capability_id


    WHERE oaa.person_id = security.current_person()


      AND oaa.assignment_status = 'ACTIVE'


      AND r.active = true


      AND lower(c.capability_name) = lower(requested_capability)


      AND oaa.effective_start <= now()


      AND
      (
          oaa.effective_end IS NULL

          OR

          oaa.effective_end >= now()
      )

);


$$;



COMMENT ON FUNCTION security.has_capability(TEXT) IS

'Determines whether the current person possesses a capability through an active
operational role assignment.';



-- ============================================================================
-- List Current Capabilities
--
-- Used for:
--
--     - Security review
--     - Auditing
--     - Troubleshooting
--
-- This does not grant access.
--
-- It only exposes calculated authority.
--
-- ============================================================================


CREATE OR REPLACE FUNCTION security.current_capabilities()

RETURNS TABLE
(
    capability_id UUID,
    capability_name VARCHAR(150),
    role_id UUID,
    role_name VARCHAR(100)
)

LANGUAGE sql

STABLE

SECURITY DEFINER

SET search_path = pg_catalog, public, security

AS
$$


SELECT DISTINCT

    c.capability_id,

    c.capability_name,

    r.role_id,

    r.role_name


FROM operational_authority_assignments oaa


JOIN operational_roles r

    ON r.role_id = oaa.role_id


JOIN role_capabilities rc

    ON rc.role_id = r.role_id


JOIN operational_capabilities c

    ON c.capability_id = rc.capability_id


WHERE oaa.person_id = security.current_person()


AND oaa.assignment_status = 'ACTIVE'


AND r.active = true


AND oaa.effective_start <= now()


AND
(
    oaa.effective_end IS NULL

    OR

    oaa.effective_end >= now()
);



$$;



COMMENT ON FUNCTION security.current_capabilities() IS

'Returns calculated capabilities derived from active operational roles.';



-- ============================================================================
-- Require Capability
--
-- Fails closed.
--
-- Used by sensitive database operations.
--
-- ============================================================================


CREATE OR REPLACE FUNCTION security.require_capability(
    requested_capability TEXT
)

RETURNS VOID

LANGUAGE plpgsql

SECURITY DEFINER

SET search_path = pg_catalog, public, security

AS
$$

BEGIN


    IF NOT security.has_capability(requested_capability)

    THEN


        RAISE EXCEPTION

        'SECURITY_DENIED: Required capability % not assigned',

        requested_capability;


    END IF;


END;

$$;



COMMENT ON FUNCTION security.require_capability(TEXT) IS

'Stops execution when the current security context lacks the required
capability.';



-- ============================================================================
-- Capability Ownership Check
--
-- Used internally by future authorization decision engine.
--
-- Provides explicit separation between:
--
--     Role assignment
--     Capability ownership
--
-- ============================================================================


CREATE OR REPLACE FUNCTION security.role_has_capability(
    check_role UUID,
    check_capability UUID
)

RETURNS BOOLEAN

LANGUAGE sql

STABLE

SECURITY DEFINER

SET search_path = pg_catalog, public, security

AS
$$


SELECT EXISTS
(

    SELECT 1

    FROM role_capabilities rc


    WHERE rc.role_id = check_role

      AND rc.capability_id = check_capability

);



$$;



COMMENT ON FUNCTION security.role_has_capability(UUID,UUID) IS

'Determines whether a role is mapped to a capability.';



-- ============================================================================
-- Hardening
-- ============================================================================


REVOKE ALL
ON FUNCTION security.has_capability(TEXT)
FROM PUBLIC;


REVOKE ALL
ON FUNCTION security.current_capabilities()
FROM PUBLIC;


REVOKE ALL
ON FUNCTION security.require_capability(TEXT)
FROM PUBLIC;


REVOKE ALL
ON FUNCTION security.role_has_capability(UUID,UUID)
FROM PUBLIC;



COMMIT;

-- ============================================================================
--
-- 014_security_authorization_api.sql
--
-- Public Safety Platform
--
-- Security Authorization Decision API
--
-- Part 6 - Authorization Decision Engine
--
-- ============================================================================
--
-- Purpose:
--
-- Provides the primary security decision interface.
--
-- Applications should never implement authorization logic themselves.
--
-- They should ask:
--
--     security.is_authorized(action)
--
-- and enforce the result.
--
-- ============================================================================


BEGIN;


-- ============================================================================
-- Authorization Decision Function
--
-- This is the primary security API.
--
-- Evaluation order matters.
--
-- The system fails closed.
--
-- First failure becomes the security reason.
--
-- ============================================================================


CREATE OR REPLACE FUNCTION security.is_authorized(
    requested_action TEXT
)

RETURNS security.authorization_result

LANGUAGE plpgsql

STABLE

SECURITY DEFINER

SET search_path = pg_catalog, public, security

AS
$$

DECLARE

    result security.authorization_result;


BEGIN


    result.evaluated_at := now();



    -- ========================================================================
    -- Step 1
    --
    -- Validate complete security context
    --
    -- ========================================================================


    IF NOT security.validate_security_context()

    THEN


        result.authorized := false;

        result.decision_code := 'DENY';

        result.reason := 'SECURITY_CONTEXT_INVALID';


        RETURN result;


    END IF;



    -- ========================================================================
    -- Step 2
    --
    -- Confirm operational assignment
    --
    -- A valid login does not equal operational authority.
    --
    -- ========================================================================


    IF NOT security.has_active_assignment()

    THEN


        result.authorized := false;

        result.decision_code := 'DENY';

        result.reason := 'NO_ACTIVE_OPERATIONAL_ASSIGNMENT';


        RETURN result;


    END IF;



    -- ========================================================================
    -- Step 3
    --
    -- Capability validation
    --
    -- Roles do not grant authority.
    --
    -- Capabilities grant authority.
    --
    -- ========================================================================


    IF NOT security.has_capability(requested_action)

    THEN


        result.authorized := false;

        result.decision_code := 'DENY';

        result.reason :=
            'CAPABILITY_NOT_ASSIGNED';


        RETURN result;


    END IF;



    -- ========================================================================
    -- Authorization successful
    -- ========================================================================


    result.authorized := true;

    result.decision_code := 'ALLOW';

    result.reason := 'AUTHORIZED';


    RETURN result;



END;

$$;



COMMENT ON FUNCTION security.is_authorized(TEXT) IS

'Primary authorization decision engine. Returns a structured allow or deny
decision based on validated security context, operational authority, and
capability assignment.';



-- ============================================================================
-- Convenience Function
--
-- Boolean wrapper for simple checks.
--
-- Use cases:
--
--     Row level security
--     Database policies
--
-- ============================================================================


CREATE OR REPLACE FUNCTION security.is_allowed(
    requested_action TEXT
)

RETURNS BOOLEAN

LANGUAGE sql

STABLE

SECURITY DEFINER

SET search_path = pg_catalog, public, security

AS
$$


SELECT

    (security.is_authorized(requested_action)).authorized;


$$;



COMMENT ON FUNCTION security.is_allowed(TEXT) IS

'Boolean authorization wrapper intended for row level security policies.';



-- ============================================================================
-- Authorization Reason Helper
--
-- Allows operational visibility without exposing internals.
--
-- ============================================================================


CREATE OR REPLACE FUNCTION security.authorization_reason(
    requested_action TEXT
)

RETURNS TEXT

LANGUAGE sql

STABLE

SECURITY DEFINER

SET search_path = pg_catalog, public, security

AS
$$


SELECT

    (security.is_authorized(requested_action)).reason;


$$;



COMMENT ON FUNCTION security.authorization_reason(TEXT) IS

'Returns the reason associated with an authorization decision.';



-- ============================================================================
-- Hardening
-- ============================================================================


REVOKE ALL
ON FUNCTION security.is_authorized(TEXT)
FROM PUBLIC;


REVOKE ALL
ON FUNCTION security.is_allowed(TEXT)
FROM PUBLIC;


REVOKE ALL
ON FUNCTION security.authorization_reason(TEXT)
FROM PUBLIC;



COMMIT;


-- ============================================================================
-- End Part 6
-- ============================================================================

-- ============================================================================
--
-- 014_security_authorization_api.sql
--
-- Public Safety Platform
--
-- Security Authorization Decision API
--
-- Part 7 - Authorization Audit Integration
--
-- ============================================================================
--
-- Purpose:
--
-- Records authorization decisions into the cryptographic audit chain.
--
-- Every authorization decision becomes a permanent security event.
--
-- This supports:
--
--     - CJIS accountability
--     - Incident investigation
--     - Insider threat detection
--     - Administrative review
--
-- ============================================================================


BEGIN;


-- ============================================================================
-- Audit Authorization Decision
--
-- Writes authorization outcomes into:
--
--     cryptographic_audit_chain
--
-- The existing audit triggers provide:
--
--     - Previous hash linking
--     - Event hashing
--     - Chain integrity
--
-- ============================================================================


CREATE OR REPLACE FUNCTION security.audit_authorization_decision(
    requested_action TEXT,
    authorization_result security.authorization_result
)

RETURNS VOID

LANGUAGE plpgsql

SECURITY DEFINER

SET search_path = pg_catalog, public, security

AS
$$

BEGIN


    INSERT INTO cryptographic_audit_chain
    (
        identity_id,
        person_id,
        session_id,
        device_id,
        agency_id,

        event_type,
        event_category,

        action,

        event_payload
    )

    VALUES
    (

        security.current_identity(),

        security.current_person(),

        security.current_session(),

        security.current_device(),

        security.current_agency(),


        'AUTHORIZATION_DECISION',

        'SECURITY',


        requested_action,


        jsonb_build_object
        (

            'authorized',
            authorization_result.authorized,


            'decision_code',
            authorization_result.decision_code,


            'reason',
            authorization_result.reason,


            'evaluated_at',
            authorization_result.evaluated_at

        )

    );


END;

$$;



COMMENT ON FUNCTION security.audit_authorization_decision(TEXT,security.authorization_result) IS

'Writes authorization decisions into the cryptographic audit chain.';



-- ============================================================================
-- Audited Authorization Wrapper
--
-- This becomes the preferred API for security-sensitive operations.
--
-- It evaluates authorization and immediately records the decision.
--
-- ============================================================================


CREATE OR REPLACE FUNCTION security.is_authorized_audited(
    requested_action TEXT
)

RETURNS security.authorization_result

LANGUAGE plpgsql

SECURITY DEFINER

SET search_path = pg_catalog, public, security

AS
$$

DECLARE

    decision security.authorization_result;


BEGIN


    decision :=
        security.is_authorized(requested_action);



    PERFORM
        security.audit_authorization_decision(
            requested_action,
            decision
        );



    RETURN decision;


END;

$$;



COMMENT ON FUNCTION security.is_authorized_audited(TEXT) IS

'Authorization decision API that automatically records the result in the
cryptographic audit chain.';



-- ============================================================================
-- Security Hardening
-- ============================================================================


REVOKE ALL
ON FUNCTION security.audit_authorization_decision(TEXT,security.authorization_result)
FROM PUBLIC;


REVOKE ALL
ON FUNCTION security.is_authorized_audited(TEXT)
FROM PUBLIC;



COMMIT;


-- ============================================================================
-- End Part 7
-- ============================================================================

-- ============================================================================
--
-- 014_security_authorization_api.sql
--
-- Public Safety Platform
--
-- Security Authorization API
--
-- Part 8 - Security Hardening
--
-- ============================================================================
--
-- Purpose:
--
-- Final security controls for the authorization API.
--
-- This migration:
--
--     - Removes unsafe execution paths
--     - Validates SECURITY DEFINER functions
--     - Locks search paths
--     - Documents ownership expectations
--
-- ============================================================================


BEGIN;


-- ============================================================================
-- Remove Public Execution
--
-- PostgreSQL functions are executable by PUBLIC by default.
--
-- This is dangerous for security functions.
--
-- ============================================================================


REVOKE EXECUTE

ON ALL FUNCTIONS IN SCHEMA security

FROM PUBLIC;



-- ============================================================================
-- Restore Required Internal Execution
--
-- Functions remain callable internally through SECURITY DEFINER.
--
-- Application role grants are intentionally handled later in:
--
--     016_database_role_separation.sql
--
-- ============================================================================



-- ============================================================================
-- Verify SECURITY DEFINER Hardening
--
-- SECURITY DEFINER functions must not execute with attacker-controlled paths.
--
-- ============================================================================


DO
$$

DECLARE

    unsafe_function RECORD;


BEGIN


    FOR unsafe_function IN

        SELECT

            n.nspname,

            p.proname


        FROM pg_proc p


        JOIN pg_namespace n

            ON n.oid = p.pronamespace


        WHERE n.nspname = 'security'


        AND p.prosecdef = true


        AND NOT EXISTS

        (

            SELECT 1

            FROM unnest(
                coalesce(
                    p.proconfig,
                    ARRAY[]::text[]
                )
            ) configuration


            WHERE configuration LIKE 'search_path=%'

        )


    LOOP


        RAISE EXCEPTION

        'SECURITY FAILURE: Function %.% is SECURITY DEFINER without fixed search_path',

        unsafe_function.nspname,

        unsafe_function.proname;


    END LOOP;



END;

$$;



-- ============================================================================
-- Function Documentation
--
-- These comments make security intent visible during review.
--
-- ============================================================================


COMMENT ON SCHEMA security IS

'Public Safety Platform security enforcement API. Contains trusted functions
for session validation, authorization decisions, capability resolution, and
audit integration.';



COMMENT ON FUNCTION security.is_authorized(TEXT) IS

'Primary authorization decision engine. All sensitive operations should query
this API before execution. Decisions fail closed.';



COMMENT ON FUNCTION security.is_authorized_audited(TEXT) IS

'Audited authorization interface. Every authorization decision is recorded into
the cryptographic audit chain.';



-- ============================================================================
-- Ownership Reminder
--
-- SECURITY DEFINER functions must never be owned by normal application users.
--
-- Recommended ownership:
--
--     Database Security Administrator Role
--
-- Example:
--
--     ALTER FUNCTION security.is_authorized(TEXT)
--     OWNER TO cad_security_admin;
--
-- Applied later after role creation.
--
-- ============================================================================



-- ============================================================================
-- Final Validation
-- ============================================================================


DO
$$

BEGIN


    IF NOT EXISTS
    (

        SELECT 1

        FROM pg_namespace

        WHERE nspname = 'security'

    )

    THEN


        RAISE EXCEPTION

        'Security schema missing';



    END IF;



END;

$$;



COMMIT;


-- ============================================================================
-- End Part 8
-- ============================================================================

-- CAD Application
--                       |
--                       |
--                       v
--             security.is_authorized_audited()
--                       |
--                       |
--        +--------------+--------------+
--        |                             |
--        v                             v
-- Session Validation            Capability Engine
--        |                             |
--        v                             v
-- Device / Identity            Operational Roles
-- Trust                         |
--        |                      v
--        +-------------> Operational Authority
--                                      |
--                                      v
--                           Authorization Decision
--                                      |
--                                      v
--                         Cryptographic Audit Chain
