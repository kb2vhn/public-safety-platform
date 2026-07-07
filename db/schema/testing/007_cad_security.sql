-- 007_cad_security.sql
--
-- CAD Security Enforcement Layer
--
-- Implements:
--   - Row Level Security
--   - Agency isolation
--   - Operational visibility rules
--   - Supervisor authority boundaries
--   - Immutable operational protections
--
-- Security Model:
--
-- User Identity
--       |
--       v
-- PostgreSQL SESSION_USER
--       |
--       v
-- RLS Policies
--       |
--       v
-- Authorized Rows Only


------------------------------------------------------------
-- SECURITY CONTEXT STORAGE
------------------------------------------------------------
-- The Go API will set these values after mTLS authentication.
--
-- Example:
--
-- SET LOCAL app.user_id='uuid';
-- SET LOCAL app.agency_id='uuid';
-- SET LOCAL app.role='DISPATCHER';


CREATE SCHEMA IF NOT EXISTS security;



------------------------------------------------------------
-- ACTIVE SESSION CONTEXT
------------------------------------------------------------

CREATE TABLE security.session_context (

    context_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    session_id UUID NOT NULL
        REFERENCES sessions(session_id),

    user_id UUID NOT NULL
        REFERENCES users(user_id),

    agency_id UUID NOT NULL
        REFERENCES agencies(agency_id),

    role platform_role NOT NULL,

    created_at TIMESTAMPTZ DEFAULT now()

);



------------------------------------------------------------
-- ENABLE ROW LEVEL SECURITY
------------------------------------------------------------

ALTER TABLE cad_incidents
ENABLE ROW LEVEL SECURITY;


ALTER TABLE cad_event_timeline
ENABLE ROW LEVEL SECURITY;


ALTER TABLE incident_assignments
ENABLE ROW LEVEL SECURITY;


ALTER TABLE dispatch_notes
ENABLE ROW LEVEL SECURITY;



------------------------------------------------------------
-- HELPER FUNCTION
------------------------------------------------------------
-- Returns the authenticated agency from the session.

CREATE OR REPLACE FUNCTION security.current_agency()
RETURNS UUID
LANGUAGE sql
STABLE
AS $$

    SELECT agency_id
    FROM security.session_context
    WHERE session_id =
        current_setting('app.session_id')::uuid;

$$;



------------------------------------------------------------
-- HELPER FUNCTION
------------------------------------------------------------
-- Returns current user role

CREATE OR REPLACE FUNCTION security.current_role()
RETURNS platform_role
LANGUAGE sql
STABLE
AS $$

    SELECT role
    FROM security.session_context
    WHERE session_id =
        current_setting('app.session_id')::uuid;

$$;



------------------------------------------------------------
-- INCIDENT VISIBILITY POLICY
------------------------------------------------------------
--
-- Agency isolation:
--
-- Every user only sees their own agency.
--
-- Supervisors and above may see additional operational data.

CREATE POLICY incident_agency_isolation
ON cad_incidents
FOR SELECT
USING (

    agency_id =
    security.current_agency()

);



------------------------------------------------------------
-- INCIDENT INSERT POLICY
------------------------------------------------------------

CREATE POLICY incident_create_policy
ON cad_incidents
FOR INSERT
WITH CHECK (

    agency_id =
    security.current_agency()

);



------------------------------------------------------------
-- INCIDENT UPDATE POLICY
------------------------------------------------------------
--
-- Dispatchers can update active calls.
--
-- Closed incidents require supervisor authority.

CREATE POLICY incident_update_policy
ON cad_incidents
FOR UPDATE
USING (

    agency_id =
    security.current_agency()

    AND

    (
        security.current_role()
        IN
        (
            'SHIFT_SUPERVISOR',
            'SYS_ADMIN'
        )

        OR

        status NOT IN
        (
            'CLOSED'
        )
    )

);



------------------------------------------------------------
-- TIMELINE SECURITY
------------------------------------------------------------
--
-- Timeline is append-only.
--
-- Nobody updates history.

CREATE POLICY timeline_insert_only
ON cad_event_timeline
FOR INSERT
WITH CHECK (

    EXISTS (

        SELECT 1
        FROM cad_incidents c

        WHERE c.incident_id =
              cad_event_timeline.incident_id

        AND c.agency_id =
              security.current_agency()

    )

);



CREATE POLICY timeline_read_policy
ON cad_event_timeline
FOR SELECT
USING (

    EXISTS (

        SELECT 1
        FROM cad_incidents c

        WHERE c.incident_id =
              cad_event_timeline.incident_id

        AND c.agency_id =
              security.current_agency()

    )

);



------------------------------------------------------------
-- ASSIGNMENT SECURITY
------------------------------------------------------------

CREATE POLICY assignment_security
ON incident_assignments
FOR ALL
USING (

    EXISTS (

        SELECT 1
        FROM cad_incidents c

        WHERE c.incident_id =
              incident_assignments.incident_id

        AND c.agency_id =
              security.current_agency()

    )

);



------------------------------------------------------------
-- NOTES SECURITY
------------------------------------------------------------

CREATE POLICY dispatch_note_security
ON dispatch_notes
FOR ALL
USING (

    EXISTS (

        SELECT 1
        FROM cad_incidents c

        WHERE c.incident_id =
              dispatch_notes.incident_id

        AND c.agency_id =
              security.current_agency()

    )

);



------------------------------------------------------------
-- PREVENT DIRECT TABLE OWNERSHIP ABUSE
------------------------------------------------------------

REVOKE ALL
ON cad_incidents
FROM PUBLIC;


REVOKE ALL
ON cad_event_timeline
FROM PUBLIC;


REVOKE ALL
ON incident_assignments
FROM PUBLIC;


REVOKE ALL
ON dispatch_notes
FROM PUBLIC;



------------------------------------------------------------
-- APPLICATION ROLE
------------------------------------------------------------
-- This role does not bypass RLS.
-- It can only execute approved operations.

CREATE ROLE cad_application
NOINHERIT;


GRANT USAGE ON SCHEMA public
TO cad_application;


GRANT SELECT, INSERT
ON cad_event_timeline
TO cad_application;


GRANT SELECT, INSERT, UPDATE
ON cad_incidents
TO cad_application;


GRANT SELECT, INSERT, UPDATE
ON incident_assignments
TO cad_application;


GRANT SELECT, INSERT
ON dispatch_notes
TO cad_application;



------------------------------------------------------------
-- FORCE RLS EVEN FOR TABLE OWNER
------------------------------------------------------------
-- Critical:
-- prevents a privileged application account from bypassing policies.

ALTER TABLE cad_incidents
FORCE ROW LEVEL SECURITY;


ALTER TABLE cad_event_timeline
FORCE ROW LEVEL SECURITY;


ALTER TABLE incident_assignments
FORCE ROW LEVEL SECURITY;


ALTER TABLE dispatch_notes
FORCE ROW LEVEL SECURITY;