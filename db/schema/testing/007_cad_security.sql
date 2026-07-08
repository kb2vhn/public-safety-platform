-- ============================================================
-- 007_cad_security.sql
--
-- Public Safety Platform
--
-- CAD Security Enforcement Layer
--
-- Responsibilities:
--
--   - Create security schema
--   - Create session context foundation
--   - Create session helper functions
--   - Enforce CAD agency isolation
--   - Protect operational history
--
-- Identity binding enhancements happen in 011.
--
-- ============================================================


BEGIN;


-- ============================================================
-- SECURITY SCHEMA
-- ============================================================

CREATE SCHEMA IF NOT EXISTS security;



-- ============================================================
-- SESSION CONTEXT FOUNDATION
--
-- Populated by Go API after:
--
--   mTLS validation
--   device trust validation
--   authorization checks
--
-- ============================================================


CREATE TABLE IF NOT EXISTS security.session_context
(
    context_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    session_id UUID NOT NULL
        REFERENCES sessions(session_id),

    person_id UUID NOT NULL
        REFERENCES persons(person_id),

    agency_id UUID NOT NULL
        REFERENCES agencies(agency_id),

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()
);



CREATE INDEX IF NOT EXISTS idx_session_context_session
ON security.session_context(session_id);


CREATE INDEX IF NOT EXISTS idx_session_context_person
ON security.session_context(person_id);


CREATE INDEX IF NOT EXISTS idx_session_context_agency
ON security.session_context(agency_id);



-- ============================================================
-- SECURITY CONTEXT FUNCTIONS
-- ============================================================


CREATE OR REPLACE FUNCTION security.current_session()

RETURNS UUID

LANGUAGE sql

STABLE

AS $$

SELECT NULLIF(
    current_setting(
        'app.session_id',
        true
    ),
    ''
)::uuid;

$$;



CREATE OR REPLACE FUNCTION security.current_person()

RETURNS UUID

LANGUAGE sql

STABLE

AS $$

SELECT person_id

FROM security.session_context

WHERE session_id =
security.current_session();

$$;



CREATE OR REPLACE FUNCTION security.current_agency()

RETURNS UUID

LANGUAGE sql

STABLE

AS $$

SELECT agency_id

FROM security.session_context

WHERE session_id =
security.current_session();

$$;



-- ============================================================
-- CAD INCIDENTS
-- ============================================================


ALTER TABLE cad_incidents
ENABLE ROW LEVEL SECURITY;


ALTER TABLE cad_incidents
FORCE ROW LEVEL SECURITY;



DROP POLICY IF EXISTS cad_incident_agency_access
ON cad_incidents;


CREATE POLICY cad_incident_agency_access

ON cad_incidents

FOR SELECT

USING
(
    agency_id =
    security.current_agency()
);



DROP POLICY IF EXISTS cad_incident_create
ON cad_incidents;


CREATE POLICY cad_incident_create

ON cad_incidents

FOR INSERT

WITH CHECK
(
    agency_id =
    security.current_agency()
);



DROP POLICY IF EXISTS cad_incident_update
ON cad_incidents;


CREATE POLICY cad_incident_update

ON cad_incidents

FOR UPDATE

USING
(
    agency_id =
    security.current_agency()
)

WITH CHECK
(
    agency_id =
    security.current_agency()
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



-- ============================================================
-- PRIVILEGE REDUCTION
-- ============================================================


REVOKE DELETE
ON cad_incidents
FROM PUBLIC;



COMMIT;
