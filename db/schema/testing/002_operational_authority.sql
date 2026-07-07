-- ============================================================
-- 002_operational_authority.sql
--
-- Public Safety Platform
--
-- Purpose:
-- Defines operational authority within the organization.
--
-- This schema answers:
--
-- "What operational responsibilities has this person
-- been approved to perform?"
--
-- This schema DOES NOT:
--
-- - authenticate users
-- - create accounts
-- - issue credentials
-- - create sessions
--
-- It creates operational facts that are evaluated by
-- the authorization engine.
--
-- Security Principle:
--
-- A person's job title does not grant access.
-- Operational authority must be explicitly assigned,
-- approved, and auditable.
--
-- Dependencies:
--
-- 000_trust_foundation.sql
--
-- ============================================================


CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


------------------------------------------------------------
-- OPERATIONAL ROLE DEFINITIONS
--
-- Examples:
--
-- Dispatcher I
-- Dispatcher II
-- Shift Supervisor
-- Training Officer
-- Emergency Manager
-- CAD Administrator
--
-- These are operational responsibilities.
------------------------------------------------------------

CREATE TABLE operational_roles (

    role_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    role_name VARCHAR(100)
        NOT NULL UNIQUE,

    description TEXT
        NOT NULL,

    requires_shift_assignment BOOLEAN
        NOT NULL DEFAULT false,

    requires_supervisor_attestation BOOLEAN
        NOT NULL DEFAULT false,

    requires_dual_authorization BOOLEAN
        NOT NULL DEFAULT false,

    active BOOLEAN
        NOT NULL DEFAULT true,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- OPERATIONAL UNITS
--
-- Represents organizational structure.
--
-- Examples:
--
-- Agency
-- Communications Center
-- Police Dispatch
-- Fire Dispatch
-- EMS Dispatch
-- Platoon A
-- Platoon B
--
------------------------------------------------------------

CREATE TABLE operational_units (

    unit_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    agency_id UUID NOT NULL
        REFERENCES agencies(agency_id),

    parent_unit_id UUID
        REFERENCES operational_units(unit_id),

    unit_name VARCHAR(150)
        NOT NULL,

    unit_type VARCHAR(100)
        NOT NULL,

    description TEXT,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- PERSON OPERATIONAL AUTHORITY
--
-- This states:
--
-- "John is authorized operationally as Dispatcher II."
--
-- It does NOT state:
--
-- "John can log in."
--
------------------------------------------------------------

CREATE TABLE operational_authority_assignments (

    authority_assignment_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    person_id UUID NOT NULL
        REFERENCES persons(person_id),

    role_id UUID NOT NULL
        REFERENCES operational_roles(role_id),

    unit_id UUID NOT NULL
        REFERENCES operational_units(unit_id),

    approved_by_authority UUID NOT NULL
        REFERENCES trust_authorities(authority_id),

    effective_start TIMESTAMPTZ
        NOT NULL,

    effective_end TIMESTAMPTZ,

    assignment_status VARCHAR(50)
        NOT NULL DEFAULT 'ACTIVE',

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- COMMAND STRUCTURE
--
-- Implements:
--
-- "Check-Left Only"
--
-- A supervisor may affect users below them.
--
-- A supervisor cannot modify:
--
-- - themselves
-- - peers
-- - supervisors above them
--
------------------------------------------------------------

CREATE TABLE command_relationships (

    relationship_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    supervisor_person_id UUID NOT NULL
        REFERENCES persons(person_id),

    subordinate_person_id UUID NOT NULL
        REFERENCES persons(person_id),

    unit_id UUID NOT NULL
        REFERENCES operational_units(unit_id),

    effective_start TIMESTAMPTZ
        NOT NULL,

    effective_end TIMESTAMPTZ,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now(),


    CONSTRAINT no_self_supervision
    CHECK (
        supervisor_person_id <> subordinate_person_id
    )

);



------------------------------------------------------------
-- OPERATIONAL QUALIFICATIONS
--
-- Separates role from capability.
--
-- Example:
--
-- Role:
-- Dispatcher II
--
-- Qualifications:
-- NCIC Certified
-- Police Dispatch Certified
-- Fire Dispatch Certified
--
------------------------------------------------------------

CREATE TABLE operational_qualifications (

    qualification_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    qualification_name VARCHAR(150)
        NOT NULL UNIQUE,

    description TEXT
        NOT NULL,

    expiration_required BOOLEAN
        NOT NULL DEFAULT false,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- PERSON QUALIFICATIONS
------------------------------------------------------------

CREATE TABLE person_qualifications (

    person_qualification_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    person_id UUID NOT NULL
        REFERENCES persons(person_id),

    qualification_id UUID NOT NULL
        REFERENCES operational_qualifications(qualification_id),

    issued_by_authority UUID NOT NULL
        REFERENCES trust_authorities(authority_id),

    issued_date DATE
        NOT NULL,

    expiration_date DATE,

    qualification_status VARCHAR(50)
        NOT NULL DEFAULT 'ACTIVE',

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- OPERATIONAL CAPABILITIES
--
-- Actions a role may perform.
--
-- Examples:
--
-- CREATE_INCIDENT
-- MODIFY_INCIDENT
-- DISPATCH_UNIT
-- VIEW_HISTORY
-- RUN_CJIS_QUERY
--
------------------------------------------------------------

CREATE TABLE operational_capabilities (

    capability_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    capability_name VARCHAR(150)
        NOT NULL UNIQUE,

    description TEXT
        NOT NULL,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- ROLE CAPABILITY MAPPING
--
-- Defines what a role may do.
--
-- Example:
--
-- Dispatcher II
--      CREATE_INCIDENT
--      UPDATE_INCIDENT
--      DISPATCH_UNIT
--
------------------------------------------------------------

CREATE TABLE role_capabilities (

    role_id UUID NOT NULL
        REFERENCES operational_roles(role_id),

    capability_id UUID NOT NULL
        REFERENCES operational_capabilities(capability_id),

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now(),

    PRIMARY KEY (
        role_id,
        capability_id
    )

);



------------------------------------------------------------
-- AUTHORITY HISTORY
--
-- Never delete operational assignments.
--
-- Reassignments create history.
--
------------------------------------------------------------

CREATE TABLE operational_authority_events (

    event_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),

    person_id UUID NOT NULL
        REFERENCES persons(person_id),

    event_type VARCHAR(100)
        NOT NULL,

    previous_assignment UUID,

    new_assignment UUID,

    performed_by UUID NOT NULL
        REFERENCES persons(person_id),

    reason TEXT
        NOT NULL,

    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- INDEXES
------------------------------------------------------------

CREATE INDEX idx_operational_assignment_person
ON operational_authority_assignments(person_id);


CREATE INDEX idx_operational_assignment_role
ON operational_authority_assignments(role_id);


CREATE INDEX idx_operational_unit_parent
ON operational_units(parent_unit_id);


CREATE INDEX idx_command_supervisor
ON command_relationships(supervisor_person_id);


CREATE INDEX idx_command_subordinate
ON command_relationships(subordinate_person_id);


CREATE INDEX idx_person_qualification
ON person_qualifications(person_id);