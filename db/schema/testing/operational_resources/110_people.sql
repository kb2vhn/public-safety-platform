-- ============================================================================
-- 009_cad_personnel.sql
--
-- Public Safety Personnel Management
--
-- Depends On:
--   000_trust_foundation.sql
--   001_device_trust.sql
--   002_operational_authority.sql
--   003_authoization.sql
--   004_sessions.sql
--   005_audit_event_stream.sql
--   006_cad_core.sql
--   007_cad_security.sql
--   008_cad_dispatch.sql
--
-- Design Goals
--
-- • Every employee is a Person
-- • Agencies employ Persons
-- • Qualifications are historical
-- • Duty status is historical
-- • Certifications are historical
-- • Current status is cached while history is immutable
-- ============================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

------------------------------------------------------------
-- PERSONNEL STATUS
------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'personnel_status'
    ) THEN

        CREATE TYPE personnel_status AS ENUM (

            'ACTIVE',

            'ON_DUTY',

            'OFF_DUTY',

            'TRAINING',

            'LEAVE',

            'SUSPENDED',

            'RETIRED',

            'TERMINATED'

        );

    END IF;
END
$$;


------------------------------------------------------------
-- CERTIFICATION STATUS
------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'certification_status'
    ) THEN

        CREATE TYPE certification_status AS ENUM (

            'ACTIVE',

            'EXPIRED',

            'SUSPENDED',

            'REVOKED'

        );

    END IF;
END
$$;


------------------------------------------------------------
-- PERSONNEL
--
-- Links a Person to an Agency.
-- A Person may eventually belong to multiple agencies.
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS personnel (

    personnel_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    person_id UUID NOT NULL
        REFERENCES persons(person_id),

    agency_id UUID NOT NULL
        REFERENCES agencies(agency_id),

    employee_number VARCHAR(50),

    hire_date DATE NOT NULL,

    separation_date DATE,

    status personnel_status
        NOT NULL
        DEFAULT 'ACTIVE',

    badge_number VARCHAR(30),

    radio_identifier VARCHAR(30),

    created_at TIMESTAMPTZ
        NOT NULL
        DEFAULT now(),

    created_by UUID
        REFERENCES persons(person_id),

    created_session UUID
        REFERENCES sessions(session_id),

    UNIQUE (agency_id, employee_number),

    UNIQUE (agency_id, badge_number)

);

------------------------------------------------------------
-- CURRENT DUTY STATUS
--
-- Fast lookup table.
-- History is stored separately.
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS personnel_duty_status (

    duty_status_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    personnel_id UUID NOT NULL
        REFERENCES personnel(personnel_id)
        ON DELETE CASCADE,

    status personnel_status
        NOT NULL,

    assigned_unit_id UUID
        REFERENCES operational_units(unit_id),

    current_incident_id UUID
        REFERENCES cad_incidents(incident_id),

    updated_at TIMESTAMPTZ
        NOT NULL
        DEFAULT now(),

    updated_by UUID
        REFERENCES persons(person_id),

    updated_session UUID
        REFERENCES sessions(session_id)

);

------------------------------------------------------------
-- DUTY STATUS HISTORY
--
-- Immutable audit history.
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS personnel_status_history (

    history_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),

    personnel_id UUID NOT NULL
        REFERENCES personnel(personnel_id)
        ON DELETE CASCADE,

    previous_status personnel_status,

    new_status personnel_status
        NOT NULL,

    changed_at TIMESTAMPTZ
        NOT NULL
        DEFAULT now(),

    changed_by UUID
        REFERENCES persons(person_id),

    changed_session UUID
        REFERENCES sessions(session_id),

    reason TEXT

);

------------------------------------------------------------
-- PERSONNEL CERTIFICATIONS
--
-- Operational qualifications that may grant capability.
--
-- Examples:
--   EMT
--   Paramedic
--   Hazmat Technician
--   Firearms Qualification
--   EVOC
--   Instructor
--
-- Certifications are never deleted.
-- Status changes preserve history.
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS personnel_certifications (

    certification_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    personnel_id UUID NOT NULL
        REFERENCES personnel(personnel_id)
        ON DELETE CASCADE,


    certification_name VARCHAR(200)
        NOT NULL,


    issuing_authority VARCHAR(200),


    certificate_number VARCHAR(100),


    issued_date DATE
        NOT NULL,


    expiration_date DATE,


    status certification_status
        NOT NULL
        DEFAULT 'ACTIVE',


    verified BOOLEAN
        NOT NULL
        DEFAULT false,


    verified_by UUID
        REFERENCES persons(person_id),


    verified_at TIMESTAMPTZ,


    created_at TIMESTAMPTZ
        NOT NULL
        DEFAULT now()

);



------------------------------------------------------------
-- PERSONNEL TRAINING
--
-- Completed education and required courses.
--
-- Examples:
--   ICS-100
--   ICS-200
--   CJIS Awareness
--   Active Threat Response
--   Annual Policy Review
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS personnel_training (

    training_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    personnel_id UUID NOT NULL
        REFERENCES personnel(personnel_id)
        ON DELETE CASCADE,


    course_name VARCHAR(200)
        NOT NULL,


    provider VARCHAR(200),


    completion_date DATE
        NOT NULL,


    expiration_date DATE,


    certificate_number VARCHAR(100),


    instructor VARCHAR(200),


    training_hours NUMERIC(6,2),


    created_at TIMESTAMPTZ
        NOT NULL
        DEFAULT now()

);



------------------------------------------------------------
-- PERSONNEL SPECIALTIES
--
-- Capabilities that are not necessarily certifications.
--
-- Examples:
--   K9 Handler
--   Drone Operator
--   Dive Team
--   Negotiator
--   Crime Scene
--   SWAT
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS personnel_specialties (

    specialty_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    agency_id UUID NOT NULL
        REFERENCES agencies(agency_id),


    specialty_name VARCHAR(150)
        NOT NULL,


    description TEXT,


    active BOOLEAN
        NOT NULL
        DEFAULT true,


    created_at TIMESTAMPTZ
        NOT NULL
        DEFAULT now(),


    UNIQUE (
        agency_id,
        specialty_name
    )

);



------------------------------------------------------------
-- PERSONNEL SPECIALTY ASSIGNMENTS
--
-- Many-to-many relationship.
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS personnel_specialty_assignments (

    assignment_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    personnel_id UUID NOT NULL
        REFERENCES personnel(personnel_id)
        ON DELETE CASCADE,


    specialty_id UUID NOT NULL
        REFERENCES personnel_specialties(specialty_id)
        ON DELETE CASCADE,


    qualified_date DATE
        NOT NULL,


    expiration_date DATE,


    active BOOLEAN
        NOT NULL
        DEFAULT true,


    created_at TIMESTAMPTZ
        NOT NULL
        DEFAULT now(),


    UNIQUE(
        personnel_id,
        specialty_id
    )

);

------------------------------------------------------------
-- PERSONNEL RANKS
--
-- Rank structures vary by agency.
--
-- Examples:
--   Police Officer
--   Sergeant
--   Lieutenant
--   Captain
--   Firefighter
--   Battalion Chief
--   Paramedic
--
-- Stored as data instead of enums.
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS personnel_ranks (

    rank_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    agency_id UUID NOT NULL
        REFERENCES agencies(agency_id),


    rank_name VARCHAR(100)
        NOT NULL,


    rank_code VARCHAR(50),


    rank_order INTEGER
        NOT NULL
        DEFAULT 0,


    supervisory BOOLEAN
        NOT NULL
        DEFAULT false,


    active BOOLEAN
        NOT NULL
        DEFAULT true,


    created_at TIMESTAMPTZ
        NOT NULL
        DEFAULT now(),


    UNIQUE(
        agency_id,
        rank_name
    )

);



------------------------------------------------------------
-- PERSONNEL RANK HISTORY
--
-- Tracks promotions and demotions.
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS personnel_rank_history (

    rank_history_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    personnel_id UUID NOT NULL
        REFERENCES personnel(personnel_id)
        ON DELETE CASCADE,


    rank_id UUID NOT NULL
        REFERENCES personnel_ranks(rank_id),


    effective_date DATE
        NOT NULL,


    end_date DATE,


    changed_by UUID
        REFERENCES persons(person_id),


    changed_session UUID
        REFERENCES sessions(session_id),


    reason TEXT,


    created_at TIMESTAMPTZ
        NOT NULL
        DEFAULT now()

);



------------------------------------------------------------
-- SHIFT DEFINITIONS
--
-- Agency controlled schedules.
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS personnel_shifts (

    shift_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    agency_id UUID NOT NULL
        REFERENCES agencies(agency_id),


    shift_name VARCHAR(100)
        NOT NULL,


    start_time TIME,


    end_time TIME,


    active BOOLEAN
        NOT NULL
        DEFAULT true,


    created_at TIMESTAMPTZ
        NOT NULL
        DEFAULT now(),


    UNIQUE(
        agency_id,
        shift_name
    )

);



------------------------------------------------------------
-- PERSONNEL SHIFT ASSIGNMENTS
--
-- Historical assignment of personnel to shifts.
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS personnel_shift_assignments (

    shift_assignment_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    personnel_id UUID NOT NULL
        REFERENCES personnel(personnel_id)
        ON DELETE CASCADE,


    shift_id UUID NOT NULL
        REFERENCES personnel_shifts(shift_id),


    start_date DATE
        NOT NULL,


    end_date DATE,


    assigned_by UUID
        REFERENCES persons(person_id),


    assigned_session UUID
        REFERENCES sessions(session_id),


    created_at TIMESTAMPTZ
        NOT NULL
        DEFAULT now()

);



------------------------------------------------------------
-- PERSONNEL UNIT ASSIGNMENTS
--
-- Historical relationship between people and units.
--
-- Current dispatch availability belongs to 008.
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS personnel_unit_assignments (

    assignment_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    personnel_id UUID NOT NULL
        REFERENCES personnel(personnel_id)
        ON DELETE CASCADE,


    unit_id UUID NOT NULL
        REFERENCES operational_units(unit_id),


    assignment_role VARCHAR(100),


    start_date DATE
        NOT NULL,


    end_date DATE,


    assigned_by UUID
        REFERENCES persons(person_id),


    assigned_session UUID
        REFERENCES sessions(session_id),


    created_at TIMESTAMPTZ
        NOT NULL
        DEFAULT now()

);

------------------------------------------------------------
-- INDEXES
------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_personnel_agency
ON personnel(agency_id);


CREATE INDEX IF NOT EXISTS idx_personnel_status
ON personnel(status);


CREATE INDEX IF NOT EXISTS idx_personnel_certifications_person
ON personnel_certifications(personnel_id);


CREATE INDEX IF NOT EXISTS idx_personnel_certifications_expiration
ON personnel_certifications(expiration_date);


CREATE INDEX IF NOT EXISTS idx_personnel_training_person
ON personnel_training(personnel_id);


CREATE INDEX IF NOT EXISTS idx_personnel_specialty_assignments_person
ON personnel_specialty_assignments(personnel_id);


CREATE INDEX IF NOT EXISTS idx_personnel_specialty_assignments_specialty
ON personnel_specialty_assignments(specialty_id);


CREATE INDEX IF NOT EXISTS idx_rank_history_person
ON personnel_rank_history(personnel_id, effective_date);


CREATE INDEX IF NOT EXISTS idx_shift_assignments_person
ON personnel_shift_assignments(personnel_id);


CREATE INDEX IF NOT EXISTS idx_unit_assignments_person
ON personnel_unit_assignments(personnel_id);


CREATE INDEX IF NOT EXISTS idx_unit_assignments_unit
ON personnel_unit_assignments(unit_id);



------------------------------------------------------------
-- DATA INTEGRITY CHECKS
------------------------------------------------------------

ALTER TABLE personnel_certifications
DROP CONSTRAINT IF EXISTS valid_certification_dates;


ALTER TABLE personnel_certifications
ADD CONSTRAINT valid_certification_dates
CHECK (
    expiration_date IS NULL
    OR expiration_date >= issued_date
);



ALTER TABLE personnel_training
DROP CONSTRAINT IF EXISTS valid_training_dates;


ALTER TABLE personnel_training
ADD CONSTRAINT valid_training_dates
CHECK (
    expiration_date IS NULL
    OR expiration_date >= completion_date
);



ALTER TABLE personnel_rank_history
DROP CONSTRAINT IF EXISTS valid_rank_dates;


ALTER TABLE personnel_rank_history
ADD CONSTRAINT valid_rank_dates
CHECK (
    end_date IS NULL
    OR end_date >= effective_date
);



ALTER TABLE personnel_shift_assignments
DROP CONSTRAINT IF EXISTS valid_shift_dates;


ALTER TABLE personnel_shift_assignments
ADD CONSTRAINT valid_shift_dates
CHECK (
    end_date IS NULL
    OR end_date >= start_date
);



ALTER TABLE personnel_unit_assignments
DROP CONSTRAINT IF EXISTS valid_unit_assignment_dates;


ALTER TABLE personnel_unit_assignments
ADD CONSTRAINT valid_unit_assignment_dates
CHECK (
    end_date IS NULL
    OR end_date >= start_date
);



------------------------------------------------------------
-- ROW LEVEL SECURITY
--
-- Enforcement is completed by 011.
--
-- Enable here only.
------------------------------------------------------------

ALTER TABLE personnel
ENABLE ROW LEVEL SECURITY;


ALTER TABLE personnel_certifications
ENABLE ROW LEVEL SECURITY;


ALTER TABLE personnel_training
ENABLE ROW LEVEL SECURITY;


ALTER TABLE personnel_specialties
ENABLE ROW LEVEL SECURITY;


ALTER TABLE personnel_specialty_assignments
ENABLE ROW LEVEL SECURITY;


ALTER TABLE personnel_rank_history
ENABLE ROW LEVEL SECURITY;


ALTER TABLE personnel_shift_assignments
ENABLE ROW LEVEL SECURITY;


ALTER TABLE personnel_unit_assignments
ENABLE ROW LEVEL SECURITY;

ALTER TABLE personnel_duty_status
ENABLE ROW LEVEL SECURITY;


ALTER TABLE personnel_status_history
ENABLE ROW LEVEL SECURITY;


ALTER TABLE personnel_ranks
ENABLE ROW LEVEL SECURITY;


ALTER TABLE personnel_shifts
ENABLE ROW LEVEL SECURITY;

------------------------------------------------------------
-- OPERATIONAL SECURITY
------------------------------------------------------------

REVOKE DELETE
ON personnel
FROM PUBLIC;


REVOKE DELETE
ON personnel_certifications
FROM PUBLIC;


REVOKE DELETE
ON personnel_training
FROM PUBLIC;


REVOKE DELETE
ON personnel_rank_history
FROM PUBLIC;


REVOKE DELETE
ON personnel_unit_assignments
FROM PUBLIC;



------------------------------------------------------------
-- APPLICATION ACCESS
------------------------------------------------------------

GRANT SELECT, INSERT, UPDATE
ON personnel
TO cad_application;


GRANT SELECT, INSERT, UPDATE
ON personnel_certifications
TO cad_application;


GRANT SELECT, INSERT, UPDATE
ON personnel_training
TO cad_application;


GRANT SELECT, INSERT, UPDATE
ON personnel_specialties
TO cad_application;


GRANT SELECT, INSERT, UPDATE
ON personnel_specialty_assignments
TO cad_application;


GRANT SELECT, INSERT, UPDATE
ON personnel_rank_history
TO cad_application;


GRANT SELECT, INSERT, UPDATE
ON personnel_shift_assignments
TO cad_application;


GRANT SELECT, INSERT, UPDATE
ON personnel_unit_assignments
TO cad_application;



------------------------------------------------------------
-- COMPLETE
------------------------------------------------------------

COMMIT;


