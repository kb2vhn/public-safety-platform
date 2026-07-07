-- 008_cad_dispatch.sql
--
-- CAD Dispatch Operations
--
-- Provides:
--   - Unit management
--   - Dispatch queue
--   - Unit status tracking
--   - AVL location tracking
--   - Acknowledgements
--   - Officer safety events
--
-- Design:
-- Current State + Immutable History


------------------------------------------------------------
-- UNIT OPERATIONAL STATUS
------------------------------------------------------------

CREATE TYPE unit_status AS ENUM (

    'AVAILABLE',

    'ASSIGNED',

    'ENROUTE',

    'ON_SCENE',

    'TRANSPORTING',

    'BUSY',

    'OUT_OF_SERVICE',

    'EMERGENCY'

);



------------------------------------------------------------
-- DISPATCH ACTION TYPES
------------------------------------------------------------

CREATE TYPE dispatch_action AS ENUM (

    'ASSIGN_UNIT',

    'CANCEL_ASSIGNMENT',

    'ACKNOWLEDGE',

    'ENROUTE',

    'ARRIVED',

    'CLEAR',

    'REQUEST_BACKUP',

    'EMERGENCY_BUTTON'

);



------------------------------------------------------------
-- UNIT STATUS CURRENT STATE
------------------------------------------------------------
--
-- This is the fast lookup table.
--
-- History belongs in dispatch_events.

CREATE TABLE unit_current_status (

    unit_id UUID PRIMARY KEY
        REFERENCES operational_units(unit_id),


    status unit_status NOT NULL
        DEFAULT 'AVAILABLE',


    current_incident_id UUID
        REFERENCES cad_incidents(incident_id),


    updated_by UUID
        REFERENCES users(user_id),


    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT now()

);



------------------------------------------------------------
-- DISPATCH QUEUE
------------------------------------------------------------
--
-- Calls waiting for assignment.

CREATE TABLE dispatch_queue (

    queue_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


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
-- UNIT DISPATCH EVENTS
------------------------------------------------------------
--
-- Every radio/action event.
--
-- Never overwrite.

CREATE TABLE dispatch_events (

    dispatch_event_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    incident_id UUID NOT NULL
        REFERENCES cad_incidents(incident_id),


    unit_id UUID NOT NULL
        REFERENCES operational_units(unit_id),


    action dispatch_action NOT NULL,


    created_by UUID NOT NULL
        REFERENCES users(user_id),


    event_data JSONB NOT NULL,


    created_at TIMESTAMPTZ NOT NULL
        DEFAULT now(),


    previous_hash BYTEA,

    event_hash BYTEA NOT NULL

);



------------------------------------------------------------
-- UNIT ASSIGNMENT HISTORY
------------------------------------------------------------
--
-- Tracks who assigned what and when.

CREATE TABLE unit_assignment_history (

    history_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    unit_id UUID NOT NULL
        REFERENCES operational_units(unit_id),


    incident_id UUID NOT NULL
        REFERENCES cad_incidents(incident_id),


    assigned_by UUID NOT NULL
        REFERENCES users(user_id),


    assigned_at TIMESTAMPTZ NOT NULL
        DEFAULT now(),


    cleared_at TIMESTAMPTZ

);



------------------------------------------------------------
-- AVL LOCATION TRACKING
------------------------------------------------------------
--
-- Future PostGIS expansion.
--
-- Designed for:
--   - GPS
--   - MDT location
--   - Vehicle telemetry

CREATE TABLE unit_locations (

    location_event_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


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
--
-- Examples:
--
-- Emergency button
-- Man down
-- No movement timer
-- Backup request

CREATE TABLE officer_safety_events (

    safety_event_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    unit_id UUID NOT NULL
        REFERENCES operational_units(unit_id),


    incident_id UUID
        REFERENCES cad_incidents(incident_id),


    event_type VARCHAR(100) NOT NULL,


    severity call_priority NOT NULL,


    acknowledged BOOLEAN NOT NULL
        DEFAULT false,


    acknowledged_by UUID
        REFERENCES users(user_id),


    created_at TIMESTAMPTZ NOT NULL
        DEFAULT now()

);



------------------------------------------------------------
-- DISPATCHER NOTES / RADIO LOG
------------------------------------------------------------
--
-- Separate high-volume operational feed.

CREATE TABLE radio_log_events (

    radio_event_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    incident_id UUID
        REFERENCES cad_incidents(incident_id),


    unit_id UUID
        REFERENCES operational_units(unit_id),


    sender_id UUID
        REFERENCES users(user_id),


    message TEXT NOT NULL,


    created_at TIMESTAMPTZ NOT NULL
        DEFAULT now()

);



------------------------------------------------------------
-- INDEXES
------------------------------------------------------------

CREATE INDEX idx_dispatch_queue_priority
ON dispatch_queue(priority, queued_at);



CREATE INDEX idx_unit_status
ON unit_current_status(status);



CREATE INDEX idx_dispatch_events_incident
ON dispatch_events(incident_id, created_at);



CREATE INDEX idx_avl_unit_time
ON unit_locations(unit_id, recorded_at);



CREATE INDEX idx_safety_active
ON officer_safety_events(acknowledged)
WHERE acknowledged = false;



------------------------------------------------------------
-- SECURITY HARDENING
------------------------------------------------------------


REVOKE UPDATE, DELETE
ON dispatch_events
FROM PUBLIC;


REVOKE DELETE
ON officer_safety_events
FROM PUBLIC;


REVOKE DELETE
ON radio_log_events
FROM PUBLIC;



------------------------------------------------------------
-- APPLICATION ACCESS
------------------------------------------------------------

GRANT SELECT, INSERT, UPDATE
ON unit_current_status
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