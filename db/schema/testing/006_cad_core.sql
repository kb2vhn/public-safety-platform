-- ============================================================
-- 006_cad_core.sql
--
-- Public Safety Platform
--
-- CAD Operational Core
--
-- Design principles:
--
-- 1. Incidents are operational truth
-- 2. Events are append-only
-- 3. Human identity comes from persons
-- 4. Authentication comes from sessions
-- 5. Authorization is handled upstream
-- 6. Operational history is never destroyed
--
-- ============================================================


BEGIN;


------------------------------------------------------------
-- EXTENSIONS
------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;



------------------------------------------------------------
-- CALL PRIORITY
------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type
        WHERE typname='call_priority'
    )
    THEN

    CREATE TYPE call_priority AS ENUM
    (
        'EMERGENCY',
        'HIGH',
        'NORMAL',
        'LOW',
        'INFORMATIONAL'
    );

    END IF;
END
$$;



------------------------------------------------------------
-- CALL STATUS
------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type
        WHERE typname='call_status'
    )
    THEN

    CREATE TYPE call_status AS ENUM
    (
        'RECEIVED',
        'QUEUED',
        'DISPATCHED',
        'ENROUTE',
        'ON_SCENE',
        'TRANSPORTING',
        'CLEARED',
        'CLOSED'
    );

    END IF;
END
$$;



------------------------------------------------------------
-- INCIDENT TYPE
------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type
        WHERE typname='incident_type'
    )
    THEN

    CREATE TYPE incident_type AS ENUM
    (
        'LAW_ENFORCEMENT',
        'FIRE',
        'EMS',
        'RESCUE',
        'HAZMAT',
        'PUBLIC_SERVICE',
        'OTHER'
    );

    END IF;
END
$$;



------------------------------------------------------------
-- LOCATIONS
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS locations
(

    location_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    address_line1 VARCHAR(200),

    address_line2 VARCHAR(200),

    city VARCHAR(100),

    state VARCHAR(50),

    postal_code VARCHAR(20),

    latitude NUMERIC(10,7),

    longitude NUMERIC(10,7),

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- CALLERS
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS callers
(

    caller_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    first_name VARCHAR(100),

    last_name VARCHAR(100),

    phone_number VARCHAR(30),

    notes TEXT,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- CAD INCIDENT MASTER
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS cad_incidents
(

    incident_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    agency_id UUID NOT NULL
        REFERENCES agencies(agency_id),


    incident_number BIGSERIAL UNIQUE,


    incident_type incident_type NOT NULL,


    priority call_priority NOT NULL
        DEFAULT 'NORMAL',


    status call_status NOT NULL
        DEFAULT 'RECEIVED',


    location_id UUID
        REFERENCES locations(location_id),


    caller_id UUID
        REFERENCES callers(caller_id),


    received_at TIMESTAMPTZ
        NOT NULL DEFAULT now(),


    closed_at TIMESTAMPTZ,


    created_by UUID NOT NULL
        REFERENCES persons(person_id),


    created_session UUID
        REFERENCES sessions(session_id)

);



------------------------------------------------------------
-- INCIDENT ASSIGNMENTS
--
-- Units already exist from 002.
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS incident_assignments
(

    assignment_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    incident_id UUID NOT NULL
        REFERENCES cad_incidents(incident_id),


    unit_id UUID NOT NULL
        REFERENCES operational_units(unit_id),


    assigned_by UUID NOT NULL
        REFERENCES persons(person_id),


    assigned_session UUID
        REFERENCES sessions(session_id),


    assigned_at TIMESTAMPTZ
        NOT NULL DEFAULT now(),


    cleared_at TIMESTAMPTZ

);



------------------------------------------------------------
-- CAD EVENT TIMELINE
--
-- Immutable operational history
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS cad_event_timeline
(

    event_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    incident_id UUID NOT NULL
        REFERENCES cad_incidents(incident_id),


    event_type VARCHAR(100)
        NOT NULL,


    event_data JSONB
        NOT NULL,


    created_by UUID NOT NULL
        REFERENCES persons(person_id),


    created_session UUID
        REFERENCES sessions(session_id),


    previous_hash BYTEA,


    event_hash BYTEA NOT NULL,


    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- DISPATCH NOTES
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS dispatch_notes
(

    note_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    incident_id UUID NOT NULL
        REFERENCES cad_incidents(incident_id),


    author_id UUID NOT NULL
        REFERENCES persons(person_id),


    session_id UUID
        REFERENCES sessions(session_id),


    note_text TEXT NOT NULL,


    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- INDEXES
------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_incident_status
ON cad_incidents(status);


CREATE INDEX IF NOT EXISTS idx_incident_priority
ON cad_incidents(priority);


CREATE INDEX IF NOT EXISTS idx_incident_number
ON cad_incidents(incident_number);


CREATE INDEX IF NOT EXISTS idx_timeline_incident
ON cad_event_timeline
(
    incident_id,
    created_at
);


CREATE INDEX IF NOT EXISTS idx_assignment_incident
ON incident_assignments(incident_id);



------------------------------------------------------------
-- PROTECT OPERATIONAL HISTORY
------------------------------------------------------------

REVOKE UPDATE, DELETE
ON cad_event_timeline
FROM PUBLIC;


REVOKE UPDATE, DELETE
ON cad_incidents
FROM PUBLIC;


COMMIT;
