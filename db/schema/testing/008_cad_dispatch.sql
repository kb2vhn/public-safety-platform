-- ============================================================
-- 008_cad_dispatch.sql
--
-- Public Safety CAD Dispatch Operations
--
-- Depends on:
--
-- 000_trust_foundation
-- 001_device_trust
-- 002_operational_authority
-- 003_authorization
-- 004_sessions
-- 005_audit_event_stream
-- 006_cad_core
-- 007_cad_security
--
-- Design:
--
-- Current State + Immutable Operational History
--
-- Principles:
--
-- 1. Dispatch actions are attributable
-- 2. Agency isolation enforced
-- 3. Historical events are append only
-- 4. Current state optimized for speed
-- 5. Future PostGIS/AVL expansion supported
--
-- ============================================================


BEGIN;


------------------------------------------------------------
-- EXTENSIONS
------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS pgcrypto;



------------------------------------------------------------
-- ENUMS
------------------------------------------------------------


DO $$
BEGIN

IF NOT EXISTS
(
    SELECT 1
    FROM pg_type
    WHERE typname = 'unit_status'
)
THEN

CREATE TYPE unit_status AS ENUM
(
    'AVAILABLE',
    'ASSIGNED',
    'ENROUTE',
    'ON_SCENE',
    'TRANSPORTING',
    'BUSY',
    'OUT_OF_SERVICE',
    'EMERGENCY'
);

END IF;

END
$$;



DO $$
BEGIN

IF NOT EXISTS
(
    SELECT 1
    FROM pg_type
    WHERE typname = 'dispatch_action'
)
THEN

CREATE TYPE dispatch_action AS ENUM
(
    'ASSIGN_UNIT',
    'CANCEL_ASSIGNMENT',
    'ACKNOWLEDGE',
    'ENROUTE',
    'ARRIVED',
    'CLEAR',
    'REQUEST_BACKUP',
    'EMERGENCY_BUTTON'
);

END IF;

END
$$;



------------------------------------------------------------
-- CURRENT UNIT STATUS
--
-- Fast lookup table.
--
-- History stored separately.
------------------------------------------------------------


CREATE TABLE IF NOT EXISTS unit_current_status
(

    unit_status_id UUID
        PRIMARY KEY
        DEFAULT gen_random_uuid(),


    agency_id UUID NOT NULL
        REFERENCES agencies(agency_id),


    unit_id UUID NOT NULL
        UNIQUE
        REFERENCES operational_units(unit_id),


    status unit_status NOT NULL
        DEFAULT 'AVAILABLE',


    current_incident_id UUID
        REFERENCES cad_incidents(incident_id),


    updated_by UUID
        REFERENCES persons(person_id),


    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT now()

);



------------------------------------------------------------
-- DISPATCH QUEUE
--
-- Incidents waiting for assignment.
------------------------------------------------------------


CREATE TABLE IF NOT EXISTS dispatch_queue
(

    queue_id UUID
        PRIMARY KEY
        DEFAULT gen_random_uuid(),


    agency_id UUID NOT NULL
        REFERENCES agencies(agency_id),


    incident_id UUID NOT NULL
        REFERENCES cad_incidents(incident_id),


    priority call_priority NOT NULL,


    queued_at TIMESTAMPTZ NOT NULL
        DEFAULT now(),


    assigned BOOLEAN NOT NULL
        DEFAULT false,


    assigned_at TIMESTAMPTZ

);



------------------------------------------------------------
-- DISPATCH EVENTS
--
-- Immutable operational timeline.
--
-- Radio/actions/assignments.
------------------------------------------------------------


CREATE TABLE IF NOT EXISTS dispatch_events
(

    dispatch_event_id UUID
        PRIMARY KEY
        DEFAULT gen_random_uuid(),


    agency_id UUID NOT NULL
        REFERENCES agencies(agency_id),


    incident_id UUID NOT NULL
        REFERENCES cad_incidents(incident_id),


    unit_id UUID NOT NULL
        REFERENCES operational_units(unit_id),


    action dispatch_action NOT NULL,


    created_by UUID NOT NULL
        REFERENCES persons(person_id),


    created_session UUID
        REFERENCES sessions(session_id),


    event_data JSONB NOT NULL,


    created_at TIMESTAMPTZ NOT NULL
        DEFAULT now(),


    previous_hash BYTEA,


    event_hash BYTEA NOT NULL

);



------------------------------------------------------------
-- ASSIGNMENT HISTORY
--
-- Never overwrite.
------------------------------------------------------------


CREATE TABLE IF NOT EXISTS unit_assignment_history
(

    history_id UUID
        PRIMARY KEY
        DEFAULT gen_random_uuid(),


    agency_id UUID NOT NULL
        REFERENCES agencies(agency_id),


    unit_id UUID NOT NULL
        REFERENCES operational_units(unit_id),


    incident_id UUID NOT NULL
        REFERENCES cad_incidents(incident_id),


    assigned_by UUID NOT NULL
        REFERENCES persons(person_id),


    assigned_session UUID
        REFERENCES sessions(session_id),


    assigned_at TIMESTAMPTZ NOT NULL
        DEFAULT now(),


    cleared_at TIMESTAMPTZ

);



------------------------------------------------------------
-- AVL LOCATION HISTORY
--
-- Future PostGIS expansion.
------------------------------------------------------------


CREATE TABLE IF NOT EXISTS unit_locations
(

    location_event_id UUID
        PRIMARY KEY
        DEFAULT gen_random_uuid(),


    agency_id UUID NOT NULL
        REFERENCES agencies(agency_id),


    unit_id UUID NOT NULL
        REFERENCES operational_units(unit_id),


    latitude NUMERIC(10,7) NOT NULL,


    longitude NUMERIC(10,7) NOT NULL,


    accuracy_meters NUMERIC(8,2),


    recorded_at TIMESTAMPTZ NOT NULL
        DEFAULT now()

);



------------------------------------------------------------
-- OFFICER SAFETY EVENTS
------------------------------------------------------------


CREATE TABLE IF NOT EXISTS officer_safety_events
(

    safety_event_id UUID
        PRIMARY KEY
        DEFAULT gen_random_uuid(),


    agency_id UUID NOT NULL
        REFERENCES agencies(agency_id),


    unit_id UUID NOT NULL
        REFERENCES operational_units(unit_id),


    incident_id UUID
        REFERENCES cad_incidents(incident_id),


    event_type VARCHAR(100) NOT NULL,


    severity call_priority NOT NULL,


    acknowledged BOOLEAN NOT NULL
        DEFAULT false,


    acknowledged_by UUID
        REFERENCES persons(person_id),


    acknowledged_at TIMESTAMPTZ,


    created_at TIMESTAMPTZ NOT NULL
        DEFAULT now()

);



------------------------------------------------------------
-- RADIO LOG
------------------------------------------------------------


CREATE TABLE IF NOT EXISTS radio_log_events
(

    radio_event_id UUID
        PRIMARY KEY
        DEFAULT gen_random_uuid(),


    agency_id UUID NOT NULL
        REFERENCES agencies(agency_id),


    incident_id UUID
        REFERENCES cad_incidents(incident_id),


    unit_id UUID
        REFERENCES operational_units(unit_id),


    sender_id UUID
        REFERENCES persons(person_id),


    message TEXT NOT NULL,


    created_at TIMESTAMPTZ NOT NULL
        DEFAULT now()

);



------------------------------------------------------------
-- INDEXES
------------------------------------------------------------


CREATE INDEX IF NOT EXISTS idx_dispatch_queue_priority
ON dispatch_queue(priority, queued_at);



CREATE INDEX IF NOT EXISTS idx_dispatch_events_incident
ON dispatch_events(incident_id, created_at);



CREATE INDEX IF NOT EXISTS idx_dispatch_unit
ON dispatch_events(unit_id);



CREATE INDEX IF NOT EXISTS idx_unit_locations_history
ON unit_locations(unit_id, recorded_at);



CREATE INDEX IF NOT EXISTS idx_safety_active
ON officer_safety_events(acknowledged)
WHERE acknowledged = false;



------------------------------------------------------------
-- ENABLE RLS
------------------------------------------------------------


ALTER TABLE unit_current_status ENABLE ROW LEVEL SECURITY;

ALTER TABLE dispatch_queue ENABLE ROW LEVEL SECURITY;

ALTER TABLE dispatch_events ENABLE ROW LEVEL SECURITY;

ALTER TABLE unit_assignment_history ENABLE ROW LEVEL SECURITY;

ALTER TABLE unit_locations ENABLE ROW LEVEL SECURITY;

ALTER TABLE officer_safety_events ENABLE ROW LEVEL SECURITY;

ALTER TABLE radio_log_events ENABLE ROW LEVEL SECURITY;



------------------------------------------------------------
-- RLS POLICIES
------------------------------------------------------------


CREATE POLICY dispatch_unit_status_access
ON unit_current_status
FOR ALL
USING
(
    agency_id = security.current_agency()
)
WITH CHECK
(
    agency_id = security.current_agency()
);



CREATE POLICY dispatch_queue_access
ON dispatch_queue
FOR ALL
USING
(
    agency_id = security.current_agency()
)
WITH CHECK
(
    agency_id = security.current_agency()
);



CREATE POLICY dispatch_events_access
ON dispatch_events
FOR SELECT
USING
(
    agency_id = security.current_agency()
);



CREATE POLICY dispatch_events_insert
ON dispatch_events
FOR INSERT
WITH CHECK
(
    agency_id = security.current_agency()
);



CREATE POLICY assignment_history_access
ON unit_assignment_history
FOR SELECT
USING
(
    agency_id = security.current_agency()
);



CREATE POLICY location_access
ON unit_locations
FOR SELECT
USING
(
    agency_id = security.current_agency()
);



CREATE POLICY safety_event_access
ON officer_safety_events
FOR ALL
USING
(
    agency_id = security.current_agency()
)
WITH CHECK
(
    agency_id = security.current_agency()
);



CREATE POLICY radio_event_access
ON radio_log_events
FOR SELECT
USING
(
    agency_id = security.current_agency()
);



------------------------------------------------------------
-- IMMUTABILITY
------------------------------------------------------------


REVOKE UPDATE, DELETE
ON dispatch_events
FROM PUBLIC;


REVOKE DELETE
ON unit_assignment_history
FROM PUBLIC;


REVOKE DELETE
ON unit_locations
FROM PUBLIC;


------------------------------------------------------------
-- APPLICATION ACCESS
------------------------------------------------------------


GRANT SELECT, INSERT, UPDATE
ON unit_current_status
TO cad_application;


GRANT SELECT, INSERT
ON dispatch_queue
TO cad_application;


GRANT SELECT, INSERT
ON dispatch_events
TO cad_application;


GRANT SELECT, INSERT
ON unit_assignment_history
TO cad_application;


GRANT SELECT, INSERT
ON unit_locations
TO cad_application;


GRANT SELECT, INSERT, UPDATE
ON officer_safety_events
TO cad_application;


GRANT SELECT, INSERT
ON radio_log_events
TO cad_application;



COMMIT;
