-- ============================================================================
-- 012_row_level_security.sql
--
-- PostgreSQL Row Level Security Enforcement
--
-- Public Safety Platform
--
-- Depends on:
--
--   007_cad_security.sql
--   011_identity_database_binding.sql
--
-- Security model:
--
--   Go API authenticates:
--       mTLS
--       device trust
--       session
--       authorization
--
--   Application sets:
--       app.session_id
--
--   PostgreSQL resolves:
--       identity
--       person
--       agency
--
-- ============================================================================


BEGIN;


-- ============================================================================
-- SECURITY CONTEXT FUNCTIONS
-- ============================================================================


CREATE OR REPLACE FUNCTION security.current_user_id()

RETURNS UUID

LANGUAGE sql

STABLE

AS $$

    SELECT security.current_person();

$$;



CREATE OR REPLACE FUNCTION security.current_role()

RETURNS TEXT

LANGUAGE sql

STABLE

AS $$

    SELECT current_setting(
        'app.role',
        true
    );

$$;



CREATE OR REPLACE FUNCTION security.is_sys_admin()

RETURNS BOOLEAN

LANGUAGE sql

STABLE

AS $$

    SELECT security.current_role() = 'SYS_ADMIN';

$$;



CREATE OR REPLACE FUNCTION security.same_agency(
    target_agency UUID
)

RETURNS BOOLEAN

LANGUAGE sql

STABLE

AS $$

    SELECT
        target_agency =
        security.current_agency()

        OR

        security.is_sys_admin();

$$;



-- ============================================================================
-- AGENCIES
-- ============================================================================


ALTER TABLE agencies
ENABLE ROW LEVEL SECURITY;


ALTER TABLE agencies
FORCE ROW LEVEL SECURITY;


DROP POLICY IF EXISTS agency_access
ON agencies;


CREATE POLICY agency_access

ON agencies

FOR SELECT

USING
(
    security.same_agency(
        agency_id
    )
);



-- ============================================================================
-- PERSONS
-- ============================================================================


ALTER TABLE persons
ENABLE ROW LEVEL SECURITY;


ALTER TABLE persons
FORCE ROW LEVEL SECURITY;


DROP POLICY IF EXISTS persons_self_access
ON persons;


CREATE POLICY persons_self_access

ON persons

FOR SELECT

USING
(
    person_id =
    security.current_person()

    OR

    security.is_sys_admin()
);



-- ============================================================================
-- IDENTITIES
-- ============================================================================


ALTER TABLE identities
ENABLE ROW LEVEL SECURITY;


ALTER TABLE identities
FORCE ROW LEVEL SECURITY;


DROP POLICY IF EXISTS identities_self_access
ON identities;


CREATE POLICY identities_self_access

ON identities

FOR SELECT

USING
(
    identity_id =
    security.current_identity()

    OR

    security.is_sys_admin()
);



-- ============================================================================
-- SESSIONS
-- ============================================================================


ALTER TABLE sessions
ENABLE ROW LEVEL SECURITY;


ALTER TABLE sessions
FORCE ROW LEVEL SECURITY;


DROP POLICY IF EXISTS sessions_owner_access
ON sessions;


CREATE POLICY sessions_owner_access

ON sessions

FOR SELECT

USING
(
    identity_id =
    security.current_identity()

    OR

    security.is_sys_admin()
);



-- ============================================================================
-- CAD INCIDENTS
-- ============================================================================


ALTER TABLE cad_incidents
ENABLE ROW LEVEL SECURITY;


ALTER TABLE cad_incidents
FORCE ROW LEVEL SECURITY;


DROP POLICY IF EXISTS cad_incident_access
ON cad_incidents;


CREATE POLICY cad_incident_access

ON cad_incidents

FOR SELECT

USING
(
    security.same_agency(
        agency_id
    )
);



DROP POLICY IF EXISTS cad_incident_create
ON cad_incidents;


CREATE POLICY cad_incident_create

ON cad_incidents

FOR INSERT

WITH CHECK
(
    security.same_agency(
        agency_id
    )
);



DROP POLICY IF EXISTS cad_incident_no_delete
ON cad_incidents;


CREATE POLICY cad_incident_no_delete

ON cad_incidents

FOR DELETE

USING
(
    false
);



-- ============================================================================
-- INCIDENT ASSIGNMENTS
-- ============================================================================


ALTER TABLE incident_assignments
ENABLE ROW LEVEL SECURITY;


ALTER TABLE incident_assignments
FORCE ROW LEVEL SECURITY;


DROP POLICY IF EXISTS incident_assignment_access
ON incident_assignments;


CREATE POLICY incident_assignment_access

ON incident_assignments

FOR SELECT

USING
(
    security.is_sys_admin()

    OR

    assigned_by =
    security.current_person()
);



-- ============================================================================
-- DISPATCH NOTES
-- ============================================================================


ALTER TABLE dispatch_notes
ENABLE ROW LEVEL SECURITY;


ALTER TABLE dispatch_notes
FORCE ROW LEVEL SECURITY;


DROP POLICY IF EXISTS dispatch_notes_access
ON dispatch_notes;


CREATE POLICY dispatch_notes_access

ON dispatch_notes

FOR SELECT

USING
(
    security.is_sys_admin()

    OR

    author_id =
    security.current_person()
);



-- ============================================================================
-- CAD EVENT TIMELINE
-- ============================================================================


ALTER TABLE cad_event_timeline
ENABLE ROW LEVEL SECURITY;


ALTER TABLE cad_event_timeline
FORCE ROW LEVEL SECURITY;


DROP POLICY IF EXISTS cad_event_read
ON cad_event_timeline;


CREATE POLICY cad_event_read

ON cad_event_timeline

FOR SELECT

USING
(
    security.is_sys_admin()

    OR

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



DROP POLICY IF EXISTS cad_event_no_delete
ON cad_event_timeline;


CREATE POLICY cad_event_no_delete

ON cad_event_timeline

FOR DELETE

USING
(
    false
);



COMMIT;

