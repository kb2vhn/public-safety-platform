-- ============================================================
-- 005_audit_event_stream.sql
--
-- Public Safety Platform
--
-- Immutable Audit Event Foundation
--
-- Principles:
--
--   - Every security-sensitive action creates an event
--   - Audit history is append only
--   - Writers cannot modify history
--   - Readers cannot alter history
--   - Database roles are separate from CAD roles
--
-- ============================================================


BEGIN;


------------------------------------------------------------
-- EXTENSIONS
------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";



------------------------------------------------------------
-- AUDIT EVENT TYPE
------------------------------------------------------------

DO $$
BEGIN

    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'audit_event_type'
    )
    THEN

        CREATE TYPE audit_event_type AS ENUM
        (

            'AUTHENTICATION',
            'AUTHORIZATION',
            'SESSION_START',
            'SESSION_END',

            'DEVICE_TRUST',
            'IDENTITY_CHANGE',

            'CREATE',
            'UPDATE',
            'DELETE',

            'SECURITY_ALERT',

            'ADMIN_ACTION',

            'SYSTEM_EVENT'

        );

    END IF;

END
$$;



------------------------------------------------------------
-- AUDIT EVENTS
--
-- Primary audit stream.
--
-- NEVER UPDATE.
-- NEVER DELETE.
--
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS audit_events
(

    audit_event_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),


    event_type audit_event_type
        NOT NULL,


    actor_person_id UUID
        REFERENCES persons(person_id),


    actor_identity_id UUID
        REFERENCES identities(identity_id),


    device_id UUID
        REFERENCES devices(device_id),


    session_id UUID,


    agency_id UUID
        REFERENCES agencies(agency_id),


    event_time TIMESTAMPTZ
        NOT NULL DEFAULT now(),


    event_data JSONB
        NOT NULL,


    previous_hash BYTEA,


    event_hash BYTEA
        NOT NULL,


    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()


);



------------------------------------------------------------
-- AUDIT INTEGRITY CHECKS
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS audit_integrity_checks
(

    check_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),


    first_event UUID
        REFERENCES audit_events(audit_event_id),


    last_event UUID
        REFERENCES audit_events(audit_event_id),


    calculated_hash BYTEA
        NOT NULL,


    validation_result BOOLEAN
        NOT NULL,


    checked_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- AUDIT RETENTION POLICY
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS audit_retention_policy
(

    policy_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),


    agency_id UUID
        REFERENCES agencies(agency_id),


    retention_days INTEGER
        NOT NULL,


    legal_basis TEXT,


    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



------------------------------------------------------------
-- DATABASE AUDIT ROLES
--
-- These are PostgreSQL security roles.
--
-- They are NOT CAD permissions.
--
------------------------------------------------------------


DO $$
BEGIN


IF NOT EXISTS (
    SELECT FROM pg_roles
    WHERE rolname='audit_owner'
)
THEN

    CREATE ROLE audit_owner NOLOGIN;

END IF;



IF NOT EXISTS (
    SELECT FROM pg_roles
    WHERE rolname='audit_writer'
)
THEN

    CREATE ROLE audit_writer NOLOGIN;

END IF;



IF NOT EXISTS (
    SELECT FROM pg_roles
    WHERE rolname='audit_reader'
)
THEN

    CREATE ROLE audit_reader NOLOGIN;

END IF;



IF NOT EXISTS (
    SELECT FROM pg_roles
    WHERE rolname='audit_break_glass'
)
THEN

    CREATE ROLE audit_break_glass NOLOGIN;

END IF;


END
$$;



------------------------------------------------------------
-- OWNERSHIP
------------------------------------------------------------

ALTER TABLE audit_events
OWNER TO audit_owner;


ALTER TABLE audit_integrity_checks
OWNER TO audit_owner;


ALTER TABLE audit_retention_policy
OWNER TO audit_owner;



------------------------------------------------------------
-- AUDIT PERMISSIONS
------------------------------------------------------------


REVOKE ALL
ON audit_events
FROM PUBLIC;


REVOKE ALL
ON audit_integrity_checks
FROM PUBLIC;


REVOKE ALL
ON audit_retention_policy
FROM PUBLIC;



------------------------------------------------------------
-- WRITER
------------------------------------------------------------

GRANT INSERT
ON audit_events
TO audit_writer;



------------------------------------------------------------
-- READER
------------------------------------------------------------

GRANT SELECT
ON audit_events,
   audit_integrity_checks,
   audit_retention_policy
TO audit_reader;



------------------------------------------------------------
-- BREAK GLASS
--
-- Emergency investigative access.
--
------------------------------------------------------------

GRANT SELECT
ON audit_events,
   audit_integrity_checks,
   audit_retention_policy
TO audit_break_glass;



------------------------------------------------------------
-- INDEXES
------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_audit_event_time
ON audit_events(event_time);



CREATE INDEX IF NOT EXISTS idx_audit_event_type
ON audit_events(event_type);



CREATE INDEX IF NOT EXISTS idx_audit_actor
ON audit_events(actor_person_id);



CREATE INDEX IF NOT EXISTS idx_audit_device
ON audit_events(device_id);



CREATE INDEX IF NOT EXISTS idx_audit_agency
ON audit_events(agency_id);



------------------------------------------------------------
-- PROTECT AUDIT HISTORY
------------------------------------------------------------


REVOKE UPDATE, DELETE
ON audit_events
FROM PUBLIC;


REVOKE UPDATE, DELETE
ON audit_integrity_checks
FROM PUBLIC;



COMMIT;
