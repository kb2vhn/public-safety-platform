-- ============================================================================
-- 011_row_level_security.sql
--
-- PostgreSQL Row Level Security Enforcement
--
-- Public Safety Platform
--
-- Applies security boundaries to:
--
--   Identity
--   Agency
--   CAD Operations
--   Dispatch
--   Personnel
--   Device Trust
--
-- Design:
--
--   Authentication happens outside PostgreSQL.
--
--   Go API validates:
--
--       mTLS
--       device trust
--       session
--       authorization
--
--   Then establishes:
--
--       app.user_id
--       app.agency_id
--       app.role
--
--   PostgreSQL enforces:
--
--       Who can see what.
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

    SELECT NULLIF(
        current_setting('app.user_id', true),
        ''
    )::uuid;

$$;



CREATE OR REPLACE FUNCTION security.current_agency_id()

RETURNS UUID

LANGUAGE sql

STABLE

AS $$

    SELECT NULLIF(
        current_setting('app.agency_id', true),
        ''
    )::uuid;

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



-- ============================================================================
-- HELPER FUNCTIONS
--
-- These prevent duplicated policy logic.
-- ============================================================================


CREATE OR REPLACE FUNCTION security.is_sys_admin()

RETURNS BOOLEAN

LANGUAGE sql

STABLE

AS $$

    SELECT security.current_role()
    =
    'SYS_ADMIN';

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
        security.current_agency_id()

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



COMMIT;

-- ============================================================================
-- PERSON IDENTITY SECURITY
-- ============================================================================


ALTER TABLE persons
ENABLE ROW LEVEL SECURITY;


ALTER TABLE persons
FORCE ROW LEVEL SECURITY;


DROP POLICY IF EXISTS persons_agency_access
ON persons;


CREATE POLICY persons_agency_access

ON persons

FOR SELECT

USING
(
    security.is_sys_admin()

    OR

    person_id =
    security.current_user_id()

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
    person_id =
    security.current_user_id()

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
    user_id =
    security.current_user_id()

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



-- No deletion of CAD incidents

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
    security.current_user_id()

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

    created_by =
    security.current_user_id()

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
