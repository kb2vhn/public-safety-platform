-- 006_cad_core.sql
-- Public Safety CAD Operational Foundation
--
-- Design principles:
-- 1. Operational records are append-oriented
-- 2. Every action is tied to an authenticated user/session
-- 3. History is preserved through event timelines
-- 4. No "magic updates" that erase operational truth

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


------------------------------------------------------------
-- CALL PRIORITY
------------------------------------------------------------

CREATE TYPE call_priority AS ENUM (
    'EMERGENCY',
    'HIGH',
    'NORMAL',
    'LOW',
    'INFORMATIONAL'
);


------------------------------------------------------------
-- CALL STATUS
------------------------------------------------------------

CREATE TYPE call_status AS ENUM (
    'RECEIVED',
    'QUEUED',
    'DISPATCHED',
    'ENROUTE',
    'ON_SCENE',
    'TRANSPORTING',
    'CLEARED',
    'CLOSED'
);


------------------------------------------------------------
-- INCIDENT TYPE
------------------------------------------------------------

CREATE TYPE incident_type AS ENUM (
    'LAW_ENFORCEMENT',
    'FIRE',
    'EMS',
    'RESCUE',
    'HAZMAT',
    'PUBLIC_SERVICE',
    'OTHER'
);



------------------------------------------------------------
-- LOCATIONS
------------------------------------------------------------
-- Actual GIS expansion should use PostGIS later.
-- This keeps the initial relational foundation.

CREATE TABLE locations (

    location_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    address_line1 VARCHAR(200),
    address_line2 VARCHAR(200),

    city VARCHAR(100),
    state VARCHAR(50),
    postal_code VARCHAR(20),

    latitude NUMERIC(10,7),
    longitude NUMERIC(10,7),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- CALLER INFORMATION
------------------------------------------------------------

CREATE TABLE callers (

    caller_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    first_name VARCHAR(100),
    last_name VARCHAR(100),

    phone_number VARCHAR(30),

    notes TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- CAD INCIDENT MASTER RECORD
------------------------------------------------------------

CREATE TABLE cad_incidents (

    incident_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    agency_id UUID NOT NULL
        REFERENCES agencies(agency_id),

    incident_number BIGSERIAL UNIQUE,

    incident_type incident_type NOT NULL,

    priority call_priority NOT NULL DEFAULT 'NORMAL',

    status call_status NOT NULL DEFAULT 'RECEIVED',


    location_id UUID
        REFERENCES locations(location_id),


    caller_id UUID
        REFERENCES callers(caller_id),


    received_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    closed_at TIMESTAMPTZ,


    created_by UUID NOT NULL
        REFERENCES users(user_id),


    created_session UUID
        REFERENCES sessions(session_id)

);



------------------------------------------------------------
-- UNITS
------------------------------------------------------------
-- Patrol cars, ambulances, fire apparatus, etc.

CREATE TABLE operational_units (

    unit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    agency_id UUID NOT NULL
        REFERENCES agencies(agency_id),

    unit_identifier VARCHAR(50) NOT NULL,

    unit_type VARCHAR(50) NOT NULL,

    active BOOLEAN NOT NULL DEFAULT true,


    UNIQUE(
        agency_id,
        unit_identifier
    )

);



------------------------------------------------------------
-- INCIDENT ASSIGNMENTS
------------------------------------------------------------

CREATE TABLE incident_assignments (

    assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),


    incident_id UUID NOT NULL
        REFERENCES cad_incidents(incident_id),


    unit_id UUID NOT NULL
        REFERENCES operational_units(unit_id),


    assigned_by UUID NOT NULL
        REFERENCES users(user_id),


    assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),


    cleared_at TIMESTAMPTZ

);



------------------------------------------------------------
-- CAD EVENT TIMELINE
------------------------------------------------------------
-- THIS IS THE HEART OF THE SYSTEM
--
-- Never delete.
-- Never rewrite.
--
-- Every operational action becomes an event.

CREATE TABLE cad_event_timeline (

    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),


    incident_id UUID NOT NULL
        REFERENCES cad_incidents(incident_id),


    event_type VARCHAR(100) NOT NULL,


    event_data JSONB NOT NULL,


    created_by UUID NOT NULL
        REFERENCES users(user_id),


    created_session UUID
        REFERENCES sessions(session_id),


    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),


    previous_hash BYTEA,

    event_hash BYTEA NOT NULL

);



------------------------------------------------------------
-- DISPATCH NOTES
------------------------------------------------------------
-- Separate from timeline because notes need searching

CREATE TABLE dispatch_notes (

    note_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),


    incident_id UUID NOT NULL
        REFERENCES cad_incidents(incident_id),


    author_id UUID NOT NULL
        REFERENCES users(user_id),


    note_text TEXT NOT NULL,


    created_at TIMESTAMPTZ NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- INDEXES
------------------------------------------------------------

CREATE INDEX idx_incident_status
ON cad_incidents(status);


CREATE INDEX idx_incident_priority
ON cad_incidents(priority);


CREATE INDEX idx_incident_number
ON cad_incidents(incident_number);


CREATE INDEX idx_timeline_incident
ON cad_event_timeline(incident_id, created_at);


CREATE INDEX idx_assignment_incident
ON incident_assignments(incident_id);



------------------------------------------------------------
-- DATABASE PROTECTION
------------------------------------------------------------

-- Operational users should never modify history directly.

REVOKE UPDATE, DELETE
ON cad_event_timeline
FROM PUBLIC;


REVOKE UPDATE, DELETE
ON cad_incidents
FROM PUBLIC;


-- Future application roles will receive controlled access.

-- Example:
--
-- GRANT INSERT, SELECT
-- ON cad_event_timeline
-- TO cad_application_service;
