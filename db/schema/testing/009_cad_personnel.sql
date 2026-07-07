-- 009_cad_personnel.sql
--
-- CAD Personnel Operational Authority
--
-- Defines:
--   - Personnel records
--   - Ranks
--   - Assignments
--   - Certifications
--   - Training
--   - Qualifications
--   - Supervisor relationships
--
-- Security Principle:
--
-- Identity != Authority != Qualification
--
-- A valid login does not automatically grant operational capability.


------------------------------------------------------------
-- PERSONNEL STATUS
------------------------------------------------------------

CREATE TYPE personnel_status AS ENUM (

    'ACTIVE',

    'INACTIVE',

    'SUSPENDED',

    'RETIRED',

    'ON_LEAVE'

);



------------------------------------------------------------
-- DUTY STATUS
------------------------------------------------------------

CREATE TYPE duty_status AS ENUM (

    'OFF_DUTY',

    'ON_DUTY',

    'BUSY',

    'UNAVAILABLE',

    'EMERGENCY_ASSIGNMENT'

);



------------------------------------------------------------
-- RANK TABLE
------------------------------------------------------------

CREATE TABLE personnel_ranks (

    rank_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    agency_id UUID NOT NULL
        REFERENCES agencies(agency_id),


    rank_name VARCHAR(100) NOT NULL,


    rank_level INTEGER NOT NULL,


    UNIQUE(
        agency_id,
        rank_name
    )

);



------------------------------------------------------------
-- PERSONNEL MASTER RECORD
------------------------------------------------------------
--
-- Links to identity.
--
-- Does not replace users table.

CREATE TABLE personnel (

    personnel_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    user_id UUID NOT NULL UNIQUE
        REFERENCES users(user_id),


    agency_id UUID NOT NULL
        REFERENCES agencies(agency_id),


    employee_number VARCHAR(50) NOT NULL,


    rank_id UUID
        REFERENCES personnel_ranks(rank_id),


    status personnel_status NOT NULL
        DEFAULT 'ACTIVE',


    hired_date DATE,


    created_at TIMESTAMPTZ NOT NULL
        DEFAULT now(),


    UNIQUE(
        agency_id,
        employee_number
    )

);



------------------------------------------------------------
-- SUPERVISOR CHAIN
------------------------------------------------------------
--
-- Organizational authority.
--
-- Example:
--
-- Chief
--   |
-- Captain
--   |
-- Sergeant
--   |
-- Officer


CREATE TABLE personnel_supervision (

    relationship_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    supervisor_id UUID NOT NULL
        REFERENCES personnel(personnel_id),


    subordinate_id UUID NOT NULL
        REFERENCES personnel(personnel_id),


    effective_start DATE NOT NULL,


    effective_end DATE,


    active BOOLEAN NOT NULL
        DEFAULT true

);



------------------------------------------------------------
-- DUTY ASSIGNMENTS
------------------------------------------------------------
--
-- Where the person is assigned.

CREATE TABLE personnel_assignments (

    assignment_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    personnel_id UUID NOT NULL
        REFERENCES personnel(personnel_id),


    assignment_name VARCHAR(100) NOT NULL,


    assignment_type VARCHAR(100) NOT NULL,


    start_date DATE NOT NULL,


    end_date DATE,


    active BOOLEAN NOT NULL
        DEFAULT true

);



------------------------------------------------------------
-- CURRENT DUTY STATE
------------------------------------------------------------

CREATE TABLE personnel_duty_status (

    personnel_id UUID PRIMARY KEY
        REFERENCES personnel(personnel_id),


    status duty_status NOT NULL
        DEFAULT 'OFF_DUTY',


    current_unit_id UUID
        REFERENCES operational_units(unit_id),


    updated_by UUID
        REFERENCES users(user_id),


    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT now()

);



------------------------------------------------------------
-- CERTIFICATION TYPES
------------------------------------------------------------

CREATE TABLE certification_types (

    certification_type_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    certification_name VARCHAR(150) NOT NULL,


    issuing_authority VARCHAR(150),


    renewal_required BOOLEAN NOT NULL
        DEFAULT true

);



------------------------------------------------------------
-- PERSONNEL CERTIFICATIONS
------------------------------------------------------------

CREATE TABLE personnel_certifications (

    certification_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    personnel_id UUID NOT NULL
        REFERENCES personnel(personnel_id),


    certification_type_id UUID NOT NULL
        REFERENCES certification_types(certification_type_id),


    certificate_number VARCHAR(100),


    issued_date DATE NOT NULL,


    expiration_date DATE,


    verified_by UUID
        REFERENCES users(user_id),


    verified_at TIMESTAMPTZ

);



------------------------------------------------------------
-- TRAINING RECORDS
------------------------------------------------------------

CREATE TABLE personnel_training (

    training_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    personnel_id UUID NOT NULL
        REFERENCES personnel(personnel_id),


    training_name VARCHAR(150) NOT NULL,


    completed_date DATE NOT NULL,


    expiration_date DATE,


    instructor VARCHAR(150),


    verified_by UUID
        REFERENCES users(user_id)

);



------------------------------------------------------------
-- EQUIPMENT QUALIFICATIONS
------------------------------------------------------------
--
-- Firearms, vehicles, specialized equipment, etc.

CREATE TABLE equipment_qualifications (

    qualification_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    personnel_id UUID NOT NULL
        REFERENCES personnel(personnel_id),


    equipment_type VARCHAR(150) NOT NULL,


    qualified_date DATE NOT NULL,


    expiration_date DATE,


    approved_by UUID
        REFERENCES users(user_id)

);



------------------------------------------------------------
-- SPECIAL CAPABILITIES
------------------------------------------------------------
--
-- SWAT
-- K9
-- Bomb Squad
-- Crisis Negotiator
-- Tactical Medic

CREATE TABLE personnel_capabilities (

    capability_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    personnel_id UUID NOT NULL
        REFERENCES personnel(personnel_id),


    capability_name VARCHAR(150) NOT NULL,


    active BOOLEAN NOT NULL
        DEFAULT true,


    granted_by UUID
        REFERENCES users(user_id),


    granted_at TIMESTAMPTZ NOT NULL
        DEFAULT now()

);



------------------------------------------------------------
-- INDEXES
------------------------------------------------------------

CREATE INDEX idx_personnel_agency
ON personnel(agency_id);



CREATE INDEX idx_personnel_status
ON personnel(status);



CREATE INDEX idx_cert_expiration
ON personnel_certifications(expiration_date);



CREATE INDEX idx_training_expiration
ON personnel_training(expiration_date);



CREATE INDEX idx_duty_status
ON personnel_duty_status(status);



------------------------------------------------------------
-- SECURITY HARDENING
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



------------------------------------------------------------
-- APPLICATION ACCESS
------------------------------------------------------------

GRANT SELECT, INSERT, UPDATE
ON personnel
TO cad_application;


GRANT SELECT, INSERT, UPDATE
ON personnel_duty_status
TO cad_application;


GRANT SELECT, INSERT
ON personnel_certifications
TO cad_application;


GRANT SELECT, INSERT
ON personnel_training
TO cad_application;


GRANT SELECT
ON personnel_capabilities
TO cad_application;