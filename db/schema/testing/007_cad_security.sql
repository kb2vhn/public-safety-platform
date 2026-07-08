-- ============================================================
-- 007_cad_security.sql
--
-- Public Safety Platform
--
-- CAD Security Enforcement Layer
--
-- Purpose:
--   Enforce operational data boundaries.
--
-- Security Principles:
--
--   1. Agency isolation
--   2. Session aware access
--   3. No cross-agency visibility
--   4. Operational history is immutable
--   5. Authorization happens before operation
--
-- ============================================================


BEGIN;


------------------------------------------------------------
-- SECURITY SCHEMA
------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS security;



------------------------------------------------------------
-- SESSION CONTEXT
--
-- Application sets these values after authentication.
--
-- Example:
--
-- SET LOCAL app.person_id='uuid';
-- SET LOCAL app.agency_id='uuid';
-- SET LOCAL app.session_id='uuid';
--
------------------------------------------------------------


CREATE TABLE IF NOT EXISTS security.session_context
(

    context_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    session_id UUID
        REFERENCES sessions(session_id),

    person_id UUID
        REFERENCES persons(person_id),

    agency_id UUID
        REFERENCES agencies(agency_id),

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- CURRENT AGENCY FUNCTION
------------------------------------------------------------

CREATE OR REPLACE FUNCTION security.current_agency()

RETURNS UUID

LANGUAGE sql

STABLE

AS $$

    SELECT current_setting(
        'app.agency_id',
        true
    )::UUID;

$$;



------------------------------------------------------------
-- CURRENT PERSON FUNCTION
------------------------------------------------------------

CREATE OR REPLACE FUNCTION security.current_person()

RETURNS UUID

LANGUAGE sql

STABLE

AS $$

    SELECT current_setting(
        'app.person_id',
        true
    )::UUID;

$$;



------------------------------------------------------------
-- CURRENT SESSION FUNCTION
------------------------------------------------------------

CREATE OR REPLACE FUNCTION security.current_session()

RETURNS UUID

LANGUAGE sql

STABLE

AS $$

    SELECT current_setting(
        'app.session_id',
        true
    )::UUID;

$$;



------------------------------------------------------------
-- ENABLE ROW LEVEL SECURITY
------------------------------------------------------------

ALTER TABLE cad_incidents
ENABLE ROW LEVEL SECURITY;


ALTER TABLE incident_assignments
ENABLE ROW LEVEL SECURITY;


ALTER TABLE dispatch_notes
ENABLE ROW LEVEL SECURITY;


ALTER TABLE cad_event_timeline
ENABLE ROW LEVEL SECURITY;



------------------------------------------------------------
-- INCIDENT ACCESS
------------------------------------------------------------


DROP POLICY IF EXISTS cad_incident_agency_access
ON cad_incidents;


CREATE POLICY cad_incident_agency_access

ON cad_incidents

FOR SELECT

USING
(
    agency_id = security.current_agency()
);



------------------------------------------------------------
-- INCIDENT CREATION
------------------------------------------------------------


DROP POLICY IF EXISTS cad_incident_create
ON cad_incidents;


CREATE POLICY cad_incident_create

ON cad_incidents

FOR INSERT

WITH CHECK
(
    agency_id = security.current_agency()
);



------------------------------------------------------------
-- INCIDENT UPDATE
------------------------------------------------------------

DROP POLICY IF EXISTS cad_incident_update
ON cad_incidents;


CREATE POLICY cad_incident_update

ON cad_incidents

FOR UPDATE

USING
(
    agency_id = security.current_agency()
)

WITH CHECK
(
    agency_id = security.current_agency()
);



------------------------------------------------------------
-- INCIDENT DELETE BLOCK
------------------------------------------------------------

DROP POLICY IF EXISTS cad_incident_no_delete
ON cad_incidents;


CREATE POLICY cad_incident_no_delete

ON cad_incidents

FOR DELETE

USING
(
    false
);



------------------------------------------------------------
-- ASSIGNMENT ACCESS
------------------------------------------------------------


DROP POLICY IF EXISTS cad_assignment_access
ON incident_assignments;


CREATE POLICY cad_assignment_access

ON incident_assignments

FOR ALL

USING
(
    EXISTS
    (
        SELECT 1
        FROM cad_incidents c
        WHERE c.incident_id =
              incident_assignments.incident_id

        AND c.agency_id =
              security.current_agency()
    )
)

WITH CHECK
(
    EXISTS
    (
        SELECT 1
        FROM cad_incidents c
        WHERE c.incident_id =
              incident_assignments.incident_id

        AND c.agency_id =
              security.current_agency()
    )
);



------------------------------------------------------------
-- DISPATCH NOTES
------------------------------------------------------------


DROP POLICY IF EXISTS cad_notes_access
ON dispatch_notes;


CREATE POLICY cad_notes_access

ON dispatch_notes

FOR ALL

USING
(
    EXISTS
    (
        SELECT 1
        FROM cad_incidents c
        WHERE c.incident_id =
              dispatch_notes.incident_id

        AND c.agency_id =
              security.current_agency()
    )
)

WITH CHECK
(
    EXISTS
    (
        SELECT 1
        FROM cad_incidents c
        WHERE c.incident_id =
              dispatch_notes.incident_id

        AND c.agency_id =
              security.current_agency()
    )
);



------------------------------------------------------------
-- CAD EVENT TIMELINE
--
-- READ:
--   Agency controlled
--
-- INSERT:
--   Agency controlled
--
-- UPDATE:
--   Forbidden
--
-- DELETE:
--   Forbidden
------------------------------------------------------------


DROP POLICY IF EXISTS cad_event_access
ON cad_event_timeline;


CREATE POLICY cad_event_access

ON cad_event_timeline

FOR SELECT

USING
(
    EXISTS
    (
        SELECT 1
        FROM cad_incidents c
        WHERE c.incident_id =
              cad_event_timeline.incident_id

        AND c.agency_id =
              security.current_agency()
    )
);



DROP POLICY IF EXISTS cad_event_insert_control
ON cad_event_timeline;


CREATE POLICY cad_event_insert_control

ON cad_event_timeline

FOR INSERT

WITH CHECK
(
    EXISTS
    (
        SELECT 1
        FROM cad_incidents c
        WHERE c.incident_id =
              cad_event_timeline.incident_id

        AND c.agency_id =
              security.current_agency()
    )
);



DROP POLICY IF EXISTS cad_event_update_block
ON cad_event_timeline;


CREATE POLICY cad_event_update_block

ON cad_event_timeline

FOR UPDATE

USING
(
    false
);



DROP POLICY IF EXISTS cad_event_delete_block
ON cad_event_timeline;


CREATE POLICY cad_event_delete_block

ON cad_event_timeline

FOR DELETE

USING
(
    false
);



------------------------------------------------------------
-- PRIVILEGE REDUCTION
------------------------------------------------------------

REVOKE UPDATE, DELETE
ON cad_event_timeline
FROM PUBLIC;


REVOKE DELETE
ON cad_incidents
FROM PUBLIC;


REVOKE DELETE
ON dispatch_notes
FROM PUBLIC;


REVOKE DELETE
ON incident_assignments
FROM PUBLIC;



------------------------------------------------------------
-- SERVICE ROLE PLACEHOLDER
------------------------------------------------------------

DO $$

BEGIN

IF NOT EXISTS
(
    SELECT 1
    FROM pg_roles
    WHERE rolname='cad_application'
)

THEN

CREATE ROLE cad_application
NOLOGIN;

END IF;

END

$$;



GRANT SELECT, INSERT, UPDATE
ON cad_incidents
TO cad_application;


GRANT SELECT, INSERT, UPDATE
ON incident_assignments
TO cad_application;


GRANT SELECT, INSERT
ON dispatch_notes
TO cad_application;


GRANT SELECT, INSERT
ON cad_event_timeline
TO cad_application;



COMMIT;
