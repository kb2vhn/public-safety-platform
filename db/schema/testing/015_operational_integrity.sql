-- ============================================================
-- 015_operational_integrity.sql
--
-- Public Safety Operational Data Integrity Layer
--
-- Protects:
--   CAD calls
--   Incident timelines
--   Reports
--   Evidence references
--   Officer actions
--
-- Principles:
--   - No silent modification
--   - Closed records immutable
--   - Corrections are append-only
--   - Every action audited
--
-- ============================================================


CREATE EXTENSION IF NOT EXISTS pgcrypto;



-- ============================================================
-- Operational record state
-- ============================================================


CREATE TYPE operational_record_state AS ENUM
(
    'DRAFT',
    'ACTIVE',
    'PENDING_REVIEW',
    'FINALIZED',
    'SEALED',
    'ARCHIVED'
);



-- ============================================================
-- Operational integrity metadata
--
-- Attached to important records
-- ============================================================


CREATE TABLE operational_record_integrity
(

    integrity_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    table_name TEXT NOT NULL,


    record_id UUID NOT NULL,


    current_state operational_record_state
        NOT NULL DEFAULT 'DRAFT',


    created_by UUID
        REFERENCES users(user_id),


    finalized_by UUID
        REFERENCES users(user_id),


    finalized_at TIMESTAMPTZ,


    sealed_by UUID
        REFERENCES users(user_id),


    sealed_at TIMESTAMPTZ,


    record_hash BYTEA,


    created_at TIMESTAMPTZ
        DEFAULT now()

);



CREATE INDEX idx_operational_integrity_record
ON operational_record_integrity(table_name, record_id);



-- ============================================================
-- Immutable timeline events
--
-- CAD timeline should NEVER be overwritten
-- ============================================================


CREATE TABLE operational_timeline_events
(

    event_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    incident_id UUID NOT NULL,


    event_time TIMESTAMPTZ NOT NULL DEFAULT now(),


    event_type VARCHAR(100) NOT NULL,


    description TEXT NOT NULL,


    created_by UUID
        REFERENCES users(user_id),


    source_system VARCHAR(50)
        DEFAULT 'CAD',


    event_hash BYTEA NOT NULL,


    previous_event_hash BYTEA,


    created_at TIMESTAMPTZ DEFAULT now()

);



CREATE INDEX idx_timeline_incident
ON operational_timeline_events(incident_id,event_time);



-- ============================================================
-- Timeline hash generation
-- ============================================================


CREATE OR REPLACE FUNCTION generate_timeline_hash()

RETURNS TRIGGER

LANGUAGE plpgsql

AS $$

BEGIN


NEW.event_hash := digest(

    COALESCE(encode(NEW.previous_event_hash,'hex'),'')
    ||
    NEW.incident_id::text
    ||
    NEW.event_time::text
    ||
    NEW.event_type
    ||
    NEW.description,


    'sha512'

);


RETURN NEW;


END;

$$;



CREATE TRIGGER trg_timeline_hash

BEFORE INSERT

ON operational_timeline_events

FOR EACH ROW

EXECUTE FUNCTION generate_timeline_hash();



-- ============================================================
-- Prevent timeline modification
-- ============================================================


CREATE OR REPLACE FUNCTION prevent_timeline_modification()

RETURNS TRIGGER

LANGUAGE plpgsql

AS $$

BEGIN


RAISE EXCEPTION

'Operational timeline records are immutable';


END;

$$;



CREATE TRIGGER trg_block_timeline_update

BEFORE UPDATE OR DELETE

ON operational_timeline_events

FOR EACH ROW

EXECUTE FUNCTION prevent_timeline_modification();



-- ============================================================
-- Record finalization
--
-- Once sealed:
--   no changes allowed
--
-- ============================================================


CREATE OR REPLACE FUNCTION finalize_operational_record

(

target_table TEXT,

target_record UUID

)

RETURNS VOID

LANGUAGE plpgsql

SECURITY DEFINER


AS $$


DECLARE

current_user_id UUID;


BEGIN


SELECT user_id

INTO current_user_id

FROM users

WHERE username = CURRENT_USER;



UPDATE operational_record_integrity


SET

current_state = 'SEALED',

sealed_by = current_user_id,

sealed_at = now()


WHERE table_name = target_table

AND record_id = target_record;



PERFORM security_write_audit(

'RECORD_SEALED',

'OPERATIONAL_FINALIZATION',

jsonb_build_object(

'table',
target_table,

'record',
target_record

)

);


END;

$$;



-- ============================================================
-- Amendment system
--
-- Never edit history.
-- Add corrections.
-- ============================================================


CREATE TABLE operational_amendments
(

amendment_id UUID PRIMARY KEY
    DEFAULT gen_random_uuid(),


table_name TEXT NOT NULL,


record_id UUID NOT NULL,


requested_by UUID
    REFERENCES users(user_id),


reason TEXT NOT NULL,


previous_value JSONB,


new_value JSONB,


approved_by UUID
    REFERENCES users(user_id),


approved_at TIMESTAMPTZ,


created_at TIMESTAMPTZ DEFAULT now()

);



CREATE INDEX idx_operational_amendments_record

ON operational_amendments(record_id);



-- ============================================================
-- Amendment approval requirement
-- ============================================================


CREATE OR REPLACE FUNCTION approve_operational_amendment

(

amendment UUID

)

RETURNS VOID

LANGUAGE plpgsql

SECURITY DEFINER


AS $$


DECLARE

approver UUID;


BEGIN


SELECT user_id

INTO approver

FROM users

WHERE username = CURRENT_USER;



UPDATE operational_amendments

SET

approved_by = approver,

approved_at = now()


WHERE amendment_id = amendment;



PERFORM security_write_audit(

'AMENDMENT_APPROVED',

'OPERATIONAL_CHANGE',

jsonb_build_object(

'amendment_id',
amendment

)

);



END;

$$;



-- ============================================================
-- Security permissions
-- ============================================================


REVOKE UPDATE, DELETE

ON operational_timeline_events

FROM PUBLIC;



REVOKE UPDATE, DELETE

ON operational_record_integrity

FROM PUBLIC;



-- Application only executes functions

REVOKE ALL

ON operational_timeline_events

FROM cad_application;



REVOKE ALL

ON operational_record_integrity

FROM cad_application;



GRANT EXECUTE

ON FUNCTION finalize_operational_record(TEXT,UUID)

TO cad_application;



GRANT EXECUTE

ON FUNCTION approve_operational_amendment(UUID)

TO cad_application;



-- ============================================================
-- End
-- ============================================================