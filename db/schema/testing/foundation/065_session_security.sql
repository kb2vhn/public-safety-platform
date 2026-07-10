-- ============================================================
-- 018_session_security_hardening.sql
--
-- Part 1
--
-- Session Security Foundation
--
-- Purpose:
--   Establish enhanced session security controls:
--
--   - Session lifecycle tracking
--   - Session revocation history
--   - Session risk assessment foundation
--   - Session validation event history
--
-- Design Principles:
--
--   CIA Triad:
--     Confidentiality:
--       Sessions are tied to verified identities/devices
--
--     Integrity:
--       Session changes are immutable events
--
--     Availability:
--       Expired/revoked sessions fail closed
--
-- ============================================================


BEGIN;


-- ============================================================
-- Session Lifecycle History
--
-- Tracks all session state transitions.
--
-- Sessions themselves represent the current state.
-- This table represents the historical record.
--
-- ============================================================


CREATE TABLE IF NOT EXISTS session_lifecycle_history
(
    lifecycle_event_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    session_id UUID NOT NULL
        REFERENCES sessions(session_id),

    previous_state session_state,

    new_state session_state NOT NULL,

    reason TEXT NOT NULL,

    performed_by UUID
        REFERENCES persons(person_id),

    performed_session UUID
        REFERENCES sessions(session_id),

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT now()
);


COMMENT ON TABLE session_lifecycle_history IS
'Immutable history of session lifecycle state changes.';



CREATE INDEX IF NOT EXISTS idx_session_lifecycle_history_session
ON session_lifecycle_history(session_id, created_at);



CREATE INDEX IF NOT EXISTS idx_session_lifecycle_history_state
ON session_lifecycle_history(new_state);



COMMIT;



-- ============================================================
-- Session Revocation Registry
--
-- Explicit record of revoked sessions.
--
-- Used for:
--   - Incident response
--   - Forced logout
--   - Credential compromise
--   - Administrative termination
--
-- ============================================================


BEGIN;


CREATE TABLE IF NOT EXISTS session_revocation_registry
(
    revocation_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    session_id UUID NOT NULL
        REFERENCES sessions(session_id),

    revoked_by UUID
        REFERENCES persons(person_id),

    revocation_reason TEXT NOT NULL,

    revoked_at TIMESTAMPTZ NOT NULL
        DEFAULT now(),

    source TEXT
);


COMMENT ON TABLE session_revocation_registry IS
'Records all explicitly revoked security sessions.';



CREATE INDEX IF NOT EXISTS idx_session_revocation_session
ON session_revocation_registry(session_id);



COMMIT;



-- ============================================================
-- Session Risk Assessments
--
-- Security scoring history.
--
-- Examples:
--   New device
--   Certificate mismatch
--   Impossible travel
--   Privilege escalation
--
-- ============================================================


BEGIN;


CREATE TABLE IF NOT EXISTS session_risk_assessments
(
    assessment_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    session_id UUID NOT NULL
        REFERENCES sessions(session_id),

    risk_score INTEGER NOT NULL
        CHECK (risk_score >= 0 AND risk_score <= 100),

    risk_level TEXT NOT NULL,

    assessment_reason TEXT NOT NULL,

    assessed_by UUID
        REFERENCES persons(person_id),

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT now()
);


COMMENT ON TABLE session_risk_assessments IS
'Historical security risk scoring associated with sessions.';



CREATE INDEX IF NOT EXISTS idx_session_risk_session
ON session_risk_assessments(session_id);



CREATE INDEX IF NOT EXISTS idx_session_risk_score
ON session_risk_assessments(risk_score);



COMMIT;



-- ============================================================
-- Session Validation Events
--
-- Records security validation checks.
--
-- Examples:
--   Identity validation
--   Device validation
--   Certificate validation
--   Authorization context validation
--
-- ============================================================


BEGIN;


CREATE TABLE IF NOT EXISTS session_validation_events
(
    validation_event_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    session_id UUID NOT NULL
        REFERENCES sessions(session_id),

    validation_type TEXT NOT NULL,

    validation_result BOOLEAN NOT NULL,

    failure_reason TEXT,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT now()
);


COMMENT ON TABLE session_validation_events IS
'Records session security validation results.';



CREATE INDEX IF NOT EXISTS idx_session_validation_session
ON session_validation_events(session_id, created_at);



CREATE INDEX IF NOT EXISTS idx_session_validation_result
ON session_validation_events(validation_result);



COMMIT;


-- ============================================================
-- End Part 1
-- ============================================================

-- ============================================================
-- 018_session_security_hardening.sql
--
-- Part 2
--
-- Session Lifecycle Security Functions
--
-- ============================================================


BEGIN;


-- ============================================================
-- Create Session Lifecycle Event Writer
--
-- Internal helper function.
--
-- ============================================================


CREATE OR REPLACE FUNCTION security.record_session_lifecycle_event
(
    p_session_id UUID,
    p_previous_state session_state,
    p_new_state session_state,
    p_reason TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$
BEGIN


    INSERT INTO session_lifecycle_history
    (
        session_id,
        previous_state,
        new_state,
        reason,
        performed_by,
        performed_session
    )
    VALUES
    (
        p_session_id,
        p_previous_state,
        p_new_state,
        p_reason,
        security.current_person(),
        security.current_session()
    );


END;
$$;


COMMENT ON FUNCTION security.record_session_lifecycle_event IS
'Writes immutable session lifecycle history records.';



COMMIT;



-- ============================================================
-- Activate Session
--
-- Moves REQUESTED -> ACTIVE
--
-- ============================================================


BEGIN;


CREATE OR REPLACE FUNCTION security.activate_session
(
    p_session_id UUID,
    p_reason TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$

DECLARE

    v_old_state session_state;


BEGIN


    SELECT state
    INTO v_old_state
    FROM sessions
    WHERE session_id = p_session_id
    FOR UPDATE;


    IF v_old_state IS NULL THEN
        RAISE EXCEPTION
        'Session does not exist';
    END IF;


    IF v_old_state <> 'REQUESTED' THEN
        RAISE EXCEPTION
        'Session cannot be activated from state %',
        v_old_state;
    END IF;


    UPDATE sessions
    SET
        state = 'ACTIVE'
    WHERE session_id = p_session_id;



    PERFORM security.record_session_lifecycle_event
    (
        p_session_id,
        v_old_state,
        'ACTIVE',
        p_reason
    );


END;

$$;



COMMENT ON FUNCTION security.activate_session IS
'Activates a requested security session.';



COMMIT;



-- ============================================================
-- Expire Session
--
-- ACTIVE -> EXPIRED
--
-- ============================================================


BEGIN;


CREATE OR REPLACE FUNCTION security.expire_session
(
    p_session_id UUID,
    p_reason TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$

DECLARE

    v_old_state session_state;


BEGIN


    SELECT state
    INTO v_old_state
    FROM sessions
    WHERE session_id = p_session_id
    FOR UPDATE;



    IF v_old_state IS NULL THEN
        RAISE EXCEPTION
        'Session does not exist';
    END IF;



    UPDATE sessions
    SET
        state = 'EXPIRED'
    WHERE session_id = p_session_id;



    PERFORM security.record_session_lifecycle_event
    (
        p_session_id,
        v_old_state,
        'EXPIRED',
        p_reason
    );


END;

$$;



COMMENT ON FUNCTION security.expire_session IS
'Expires a security session.';



COMMIT;



-- ============================================================
-- Revoke Session
--
-- Any state -> REVOKED
--
-- ============================================================


BEGIN;


CREATE OR REPLACE FUNCTION security.revoke_session
(
    p_session_id UUID,
    p_reason TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$

DECLARE

    v_old_state session_state;


BEGIN


    SELECT state
    INTO v_old_state
    FROM sessions
    WHERE session_id = p_session_id
    FOR UPDATE;



    IF v_old_state IS NULL THEN
        RAISE EXCEPTION
        'Session does not exist';
    END IF;



    UPDATE sessions
    SET
        state = 'REVOKED'
    WHERE session_id = p_session_id;



    INSERT INTO session_revocation_registry
    (
        session_id,
        revoked_by,
        revocation_reason
    )
    VALUES
    (
        p_session_id,
        security.current_person(),
        p_reason
    );



    PERFORM security.record_session_lifecycle_event
    (
        p_session_id,
        v_old_state,
        'REVOKED',
        p_reason
    );


END;

$$;



COMMENT ON FUNCTION security.revoke_session IS
'Revoke a security session immediately.';



COMMIT;



-- ============================================================
-- Terminate Session
--
-- Any state -> TERMINATED
--
-- ============================================================


BEGIN;


CREATE OR REPLACE FUNCTION security.terminate_session
(
    p_session_id UUID,
    p_reason TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$

DECLARE

    v_old_state session_state;


BEGIN


    SELECT state
    INTO v_old_state
    FROM sessions
    WHERE session_id = p_session_id
    FOR UPDATE;



    IF v_old_state IS NULL THEN
        RAISE EXCEPTION
        'Session does not exist';
    END IF;



    UPDATE sessions
    SET
        state = 'TERMINATED'
    WHERE session_id = p_session_id;



    PERFORM security.record_session_lifecycle_event
    (
        p_session_id,
        v_old_state,
        'TERMINATED',
        p_reason
    );


END;

$$;



COMMENT ON FUNCTION security.terminate_session IS
'Terminates a security session.';



COMMIT;



-- ============================================================
-- End Part 2
-- ============================================================

-- ============================================================
-- 018_session_security_hardening.sql
--
-- Part 3
--
-- Session Validation Engine
--
-- ============================================================


BEGIN;


-- ============================================================
-- Validate Session State
--
-- Internal validation helper.
--
-- ============================================================


CREATE OR REPLACE FUNCTION security.validate_session_state
(
    p_session_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$

DECLARE

    v_state session_state;


BEGIN


    SELECT state
    INTO v_state
    FROM sessions
    WHERE session_id = p_session_id;



    IF v_state IS NULL THEN

        RETURN FALSE;

    END IF;



    IF v_state <> 'ACTIVE' THEN

        RETURN FALSE;

    END IF;



    RETURN TRUE;


END;

$$;



COMMENT ON FUNCTION security.validate_session_state IS
'Confirms that a session exists and is active.';



COMMIT;



-- ============================================================
-- Validate Session Identity Binding
--
-- Ensures session identity still exists and is valid.
--
-- ============================================================


BEGIN;


CREATE OR REPLACE FUNCTION security.validate_session_identity
(
    p_session_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$

DECLARE

    v_identity UUID;


BEGIN


    SELECT identity_id
    INTO v_identity
    FROM sessions
    WHERE session_id = p_session_id;



    IF v_identity IS NULL THEN

        RETURN FALSE;

    END IF;



    RETURN security.validate_identity();



END;

$$;



COMMENT ON FUNCTION security.validate_session_identity IS
'Validates the identity attached to a session.';



COMMIT;



-- ============================================================
-- Validate Session Device
--
-- Confirms device trust remains valid.
--
-- ============================================================


BEGIN;


CREATE OR REPLACE FUNCTION security.validate_session_device
(
    p_session_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$

DECLARE

    v_device UUID;


BEGIN


    SELECT device_id
    INTO v_device
    FROM sessions
    WHERE session_id = p_session_id;



    IF v_device IS NULL THEN

        RETURN FALSE;

    END IF;



    RETURN security.validate_device();


END;

$$;



COMMENT ON FUNCTION security.validate_session_device IS
'Validates the trusted device associated with a session.';



COMMIT;



-- ============================================================
-- Record Session Validation Event
--
-- ============================================================


BEGIN;


CREATE OR REPLACE FUNCTION security.record_session_validation_event
(
    p_session_id UUID,
    p_validation_type TEXT,
    p_result BOOLEAN,
    p_failure_reason TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$

BEGIN


    INSERT INTO session_validation_events
    (
        session_id,
        validation_type,
        validation_result,
        failure_reason
    )
    VALUES
    (
        p_session_id,
        p_validation_type,
        p_result,
        p_failure_reason
    );


END;

$$;



COMMENT ON FUNCTION security.record_session_validation_event IS
'Records session validation results.';



COMMIT;



-- ============================================================
-- Full Session Security Validation
--
-- Primary validation API.
--
-- ============================================================


BEGIN;


CREATE OR REPLACE FUNCTION security.validate_active_session
(
    p_session_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$

DECLARE

    v_result BOOLEAN := FALSE;


BEGIN



    IF NOT security.validate_session_state(p_session_id) THEN


        PERFORM security.record_session_validation_event
        (
            p_session_id,
            'SESSION_STATE',
            FALSE,
            'Session is not active'
        );


        RETURN FALSE;

    END IF;



    IF NOT security.validate_session_identity(p_session_id) THEN


        PERFORM security.record_session_validation_event
        (
            p_session_id,
            'IDENTITY_VALIDATION',
            FALSE,
            'Identity validation failed'
        );


        RETURN FALSE;

    END IF;



    IF NOT security.validate_session_device(p_session_id) THEN


        PERFORM security.record_session_validation_event
        (
            p_session_id,
            'DEVICE_VALIDATION',
            FALSE,
            'Device validation failed'
        );


        RETURN FALSE;

    END IF;



    IF NOT security.validate_security_context() THEN


        PERFORM security.record_session_validation_event
        (
            p_session_id,
            'SECURITY_CONTEXT',
            FALSE,
            'Security context validation failed'
        );


        RETURN FALSE;

    END IF;



    v_result := TRUE;



    PERFORM security.record_session_validation_event
    (
        p_session_id,
        'COMPLETE_VALIDATION',
        TRUE,
        NULL
    );



    RETURN v_result;


END;

$$;



COMMENT ON FUNCTION security.validate_active_session IS
'Primary fail-closed session validation API.';



COMMIT;



-- ============================================================
-- End Part 3
-- ============================================================

-- ============================================================
-- 018_session_security_hardening.sql
--
-- Part 4
--
-- Session Audit Integration
--
-- ============================================================


BEGIN;


-- ============================================================
-- Write Session Audit Event
--
-- Internal helper for session security events.
--
-- ============================================================


CREATE OR REPLACE FUNCTION security.audit_session_event
(
    p_session_id UUID,
    p_event_type TEXT,
    p_action TEXT,
    p_payload JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$

DECLARE

    v_identity UUID;
    v_person UUID;
    v_device UUID;
    v_agency UUID;


BEGIN


    SELECT
        s.identity_id,
        i.person_id,
        s.device_id,
        s.agency_id

    INTO
        v_identity,
        v_person,
        v_device,
        v_agency

    FROM sessions s
    JOIN identities i
        ON i.identity_id = s.identity_id

    WHERE s.session_id = p_session_id;



    INSERT INTO cryptographic_audit_chain
    (
        identity_id,
        person_id,
        session_id,
        device_id,
        agency_id,

        event_type,
        event_category,

        object_type,
        object_id,

        action,

        event_payload
    )

    VALUES
    (
        v_identity,
        v_person,
        p_session_id,
        v_device,
        v_agency,

        p_event_type,
        'SESSION_SECURITY',

        'SESSION',
        p_session_id,

        p_action,

        p_payload
    );


END;

$$;



COMMENT ON FUNCTION security.audit_session_event IS
'Writes session security events into the cryptographic audit chain.';



COMMIT;



-- ============================================================
-- Enhance Lifecycle Writer
--
-- Adds cryptographic audit record.
--
-- ============================================================


BEGIN;


CREATE OR REPLACE FUNCTION security.record_session_lifecycle_event
(
    p_session_id UUID,
    p_previous_state session_state,
    p_new_state session_state,
    p_reason TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$

BEGIN


    INSERT INTO session_lifecycle_history
    (
        session_id,
        previous_state,
        new_state,
        reason,
        performed_by,
        performed_session
    )

    VALUES
    (
        p_session_id,
        p_previous_state,
        p_new_state,
        p_reason,
        security.current_person(),
        security.current_session()
    );



    PERFORM security.audit_session_event
    (
        p_session_id,

        'SESSION_STATE_CHANGE',

        'STATE_TRANSITION',

        jsonb_build_object
        (
            'previous_state',
            p_previous_state,

            'new_state',
            p_new_state,

            'reason',
            p_reason
        )
    );


END;

$$;



COMMENT ON FUNCTION security.record_session_lifecycle_event IS
'Records lifecycle history and cryptographic audit entry.';



COMMIT;



-- ============================================================
-- Enhance Validation Event Writer
--
-- Adds failed validation auditing.
--
-- ============================================================


BEGIN;


CREATE OR REPLACE FUNCTION security.record_session_validation_event
(
    p_session_id UUID,
    p_validation_type TEXT,
    p_result BOOLEAN,
    p_failure_reason TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$

BEGIN


    INSERT INTO session_validation_events
    (
        session_id,
        validation_type,
        validation_result,
        failure_reason
    )

    VALUES
    (
        p_session_id,
        p_validation_type,
        p_result,
        p_failure_reason
    );



    PERFORM security.audit_session_event
    (
        p_session_id,

        'SESSION_VALIDATION',

        CASE
            WHEN p_result
            THEN 'VALIDATION_SUCCESS'
            ELSE 'VALIDATION_FAILURE'
        END,


        jsonb_build_object
        (
            'validation_type',
            p_validation_type,

            'result',
            p_result,

            'failure_reason',
            p_failure_reason
        )
    );


END;

$$;



COMMENT ON FUNCTION security.record_session_validation_event IS
'Records validation events and audit chain entries.';



COMMIT;



-- ============================================================
-- Session Revocation Audit Wrapper
--
-- ============================================================


BEGIN;


CREATE OR REPLACE FUNCTION security.audit_session_revocation
(
    p_session_id UUID,
    p_reason TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS
$$

BEGIN


    PERFORM security.audit_session_event
    (
        p_session_id,

        'SESSION_REVOCATION',

        'SESSION_REVOKED',

        jsonb_build_object
        (
            'reason',
            p_reason
        )
    );


END;

$$;



COMMENT ON FUNCTION security.audit_session_revocation IS
'Audits session revocation actions.';



COMMIT;



-- ============================================================
-- End Part 4
-- ============================================================

-- ============================================================
-- 018_session_security_hardening.sql
--
-- Part 5
--
-- Session Security Access Control
--
-- ============================================================


BEGIN;


-- ============================================================
-- Session Security Tables
--
-- Remove broad privileges.
--
-- ============================================================


REVOKE ALL
ON TABLE session_lifecycle_history
FROM PUBLIC;


REVOKE ALL
ON TABLE session_revocation_registry
FROM PUBLIC;


REVOKE ALL
ON TABLE session_risk_assessments
FROM PUBLIC;


REVOKE ALL
ON TABLE session_validation_events
FROM PUBLIC;



-- ============================================================
-- Security Ownership
--
-- Session security data belongs to the security boundary.
--
-- ============================================================


ALTER TABLE session_lifecycle_history
OWNER TO cad_security;


ALTER TABLE session_revocation_registry
OWNER TO cad_security;


ALTER TABLE session_risk_assessments
OWNER TO cad_security;


ALTER TABLE session_validation_events
OWNER TO cad_security;



COMMIT;



-- ============================================================
-- Security Administration Access
--
-- ============================================================


BEGIN;


GRANT SELECT, INSERT, UPDATE
ON TABLE session_lifecycle_history
TO cad_security;



GRANT SELECT, INSERT
ON TABLE session_revocation_registry
TO cad_security;



GRANT SELECT, INSERT
ON TABLE session_risk_assessments
TO cad_security;



GRANT SELECT, INSERT
ON TABLE session_validation_events
TO cad_security;



COMMIT;



-- ============================================================
-- Audit Access
--
-- Auditors can view session history.
--
-- No modification rights.
--
-- ============================================================


BEGIN;


GRANT SELECT
ON TABLE session_lifecycle_history
TO cad_auditor;



GRANT SELECT
ON TABLE session_revocation_registry
TO cad_auditor;



GRANT SELECT
ON TABLE session_risk_assessments
TO cad_auditor;



GRANT SELECT
ON TABLE session_validation_events
TO cad_auditor;



COMMIT;



-- ============================================================
-- Read Only Access
--
-- Operational reporting only.
--
-- ============================================================


BEGIN;


GRANT SELECT
ON TABLE session_lifecycle_history
TO cad_readonly;



GRANT SELECT
ON TABLE session_risk_assessments
TO cad_readonly;



GRANT SELECT
ON TABLE session_validation_events
TO cad_readonly;



COMMIT;



-- ============================================================
-- Application Restrictions
--
-- Applications must use security APIs.
--
-- ============================================================


BEGIN;


REVOKE INSERT,
UPDATE,
DELETE
ON TABLE session_lifecycle_history
FROM cad_application;



REVOKE INSERT,
UPDATE,
DELETE
ON TABLE session_revocation_registry
FROM cad_application;



REVOKE INSERT,
UPDATE,
DELETE
ON TABLE session_risk_assessments
FROM cad_application;



REVOKE INSERT,
UPDATE,
DELETE
ON TABLE session_validation_events
FROM cad_application;



COMMIT;



-- ============================================================
-- Function Execution Permissions
--
-- Security APIs only.
--
-- ============================================================


BEGIN;


REVOKE ALL
ON FUNCTION security.activate_session(UUID,TEXT)
FROM PUBLIC;


REVOKE ALL
ON FUNCTION security.expire_session(UUID,TEXT)
FROM PUBLIC;


REVOKE ALL
ON FUNCTION security.revoke_session(UUID,TEXT)
FROM PUBLIC;


REVOKE ALL
ON FUNCTION security.terminate_session(UUID,TEXT)
FROM PUBLIC;



GRANT EXECUTE
ON FUNCTION security.activate_session(UUID,TEXT)
TO cad_security;



GRANT EXECUTE
ON FUNCTION security.expire_session(UUID,TEXT)
TO cad_security;



GRANT EXECUTE
ON FUNCTION security.revoke_session(UUID,TEXT)
TO cad_security;



GRANT EXECUTE
ON FUNCTION security.terminate_session(UUID,TEXT)
TO cad_security;



COMMIT;



-- ============================================================
-- End Part 5
-- ============================================================

-- ============================================================
-- 018_session_security_hardening.sql
--
-- Part 6
--
-- SECURITY DEFINER Hardening
--
-- ============================================================


BEGIN;



-- ============================================================
-- Transfer ownership
--
-- SECURITY DEFINER functions must belong to security owner.
--
-- ============================================================


ALTER FUNCTION security.validate_session()
OWNER TO cad_security;


ALTER FUNCTION security.validate_security_context()
OWNER TO cad_security;


ALTER FUNCTION security.current_session()
OWNER TO cad_security;


ALTER FUNCTION security.current_context()
OWNER TO cad_security;



-- ============================================================
-- Lock execution environment
--
-- Prevent search_path hijacking.
--
-- ============================================================


ALTER FUNCTION security.validate_session()
SET search_path = security, public;


ALTER FUNCTION security.validate_security_context()
SET search_path = security, public;


ALTER FUNCTION security.current_session()
SET search_path = security, public;


ALTER FUNCTION security.current_context()
SET search_path = security, public;



-- ============================================================
-- Remove unrestricted execution
--
-- ============================================================


REVOKE EXECUTE ON FUNCTION security.validate_session()
FROM PUBLIC;


REVOKE EXECUTE ON FUNCTION security.validate_security_context()
FROM PUBLIC;


REVOKE EXECUTE ON FUNCTION security.current_session()
FROM PUBLIC;


REVOKE EXECUTE ON FUNCTION security.current_context()
FROM PUBLIC;



-- ============================================================
-- Grant controlled execution
--
-- ============================================================


GRANT EXECUTE ON FUNCTION security.validate_session()
TO cad_application;


GRANT EXECUTE ON FUNCTION security.validate_security_context()
TO cad_application;


GRANT EXECUTE ON FUNCTION security.current_session()
TO cad_application;


GRANT EXECUTE ON FUNCTION security.current_context()
TO cad_application;



COMMIT;



-- ============================================================
-- End Part 6
-- ============================================================
