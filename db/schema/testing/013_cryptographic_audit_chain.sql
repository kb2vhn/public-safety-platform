-- ============================================================
-- 013_cryptographic_audit_chain.sql
--
-- Cryptographic Audit Integrity Layer
--
-- Purpose:
--   Creates an append-only cryptographic chain for all
--   security-sensitive events.
--
-- Design Principles:
--   - No user can alter historical events
--   - Every event depends on the previous event hash
--   - Tampering breaks the chain
--   - Audit writers are separated from readers
--
-- ============================================================


CREATE EXTENSION IF NOT EXISTS "pgcrypto";


-- ============================================================
-- Cryptographic audit event chain
-- ============================================================

CREATE TABLE cryptographic_audit_chain (

    audit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    sequence_number BIGSERIAL NOT NULL UNIQUE,

    event_time TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- Identity responsible for action
    actor_user_id UUID REFERENCES users(user_id),

    -- Device/session identity
    session_id UUID,

    device_id UUID,

    agency_id UUID REFERENCES agencies(agency_id),


    -- Event classification

    event_type VARCHAR(100) NOT NULL,

    event_category VARCHAR(50) NOT NULL,


    -- What occurred

    object_type VARCHAR(100),

    object_id UUID,

    action VARCHAR(100) NOT NULL,


    -- Security context

    source_ip INET,

    machine_certificate_fingerprint VARCHAR(128),

    user_certificate_fingerprint VARCHAR(128),


    -- Full event payload

    event_payload JSONB NOT NULL,


    -- Hash chain

    previous_hash BYTEA,

    event_hash BYTEA NOT NULL,


    -- Optional external signing

    signature BYTEA,


    created_at TIMESTAMPTZ NOT NULL DEFAULT now()

);



-- ============================================================
-- Prevent duplicate sequence insertion
-- ============================================================

CREATE UNIQUE INDEX idx_audit_sequence
ON cryptographic_audit_chain(sequence_number);



-- ============================================================
-- Fast forensic searches
-- ============================================================

CREATE INDEX idx_audit_actor
ON cryptographic_audit_chain(actor_user_id);


CREATE INDEX idx_audit_event_type
ON cryptographic_audit_chain(event_type);


CREATE INDEX idx_audit_time
ON cryptographic_audit_chain(event_time);



-- ============================================================
-- Calculate event hash
--
-- Hash includes:
--
-- previous event hash
-- event metadata
-- payload
--
-- Changing ANY value breaks the chain
-- ============================================================

CREATE OR REPLACE FUNCTION generate_audit_hash()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$

BEGIN

    NEW.event_hash :=
        digest(
            COALESCE(encode(NEW.previous_hash,'hex'),'') ||
            NEW.event_time::text ||
            COALESCE(NEW.actor_user_id::text,'') ||
            NEW.event_type ||
            NEW.action ||
            NEW.event_payload::text,
            'sha512'
        );


    RETURN NEW;

END;

$$;



CREATE TRIGGER trg_generate_audit_hash

BEFORE INSERT

ON cryptographic_audit_chain

FOR EACH ROW

EXECUTE FUNCTION generate_audit_hash();



-- ============================================================
-- Automatically link events together
-- ============================================================

CREATE OR REPLACE FUNCTION attach_previous_audit_hash()

RETURNS TRIGGER

LANGUAGE plpgsql

AS $$

DECLARE

    last_hash BYTEA;

BEGIN


    SELECT event_hash
    INTO last_hash

    FROM cryptographic_audit_chain

    ORDER BY sequence_number DESC

    LIMIT 1;



    NEW.previous_hash := last_hash;



    RETURN NEW;


END;

$$;



CREATE TRIGGER trg_attach_previous_hash

BEFORE INSERT

ON cryptographic_audit_chain

FOR EACH ROW

EXECUTE FUNCTION attach_previous_audit_hash();



-- ============================================================
-- Audit chain verification function
--
-- Used by security monitoring systems
--
-- Returns false if any event was altered
-- ============================================================


CREATE OR REPLACE FUNCTION verify_audit_chain()

RETURNS BOOLEAN

LANGUAGE plpgsql

AS $$


DECLARE

    current_record RECORD;

    expected_hash BYTEA;

    previous BYTEA := NULL;


BEGIN


FOR current_record IN

    SELECT *

    FROM cryptographic_audit_chain

    ORDER BY sequence_number


LOOP


    expected_hash :=
        digest(

            COALESCE(encode(previous,'hex'),'') ||
            current_record.event_time::text ||
            COALESCE(current_record.actor_user_id::text,'') ||
            current_record.event_type ||
            current_record.action ||
            current_record.event_payload::text,

            'sha512'

        );


    IF expected_hash <> current_record.event_hash THEN

        RETURN FALSE;

    END IF;



    previous := current_record.event_hash;


END LOOP;


RETURN TRUE;


END;

$$;



-- ============================================================
-- SECURITY HARDENING
--
-- Normal application users cannot modify audit history
-- ============================================================


REVOKE UPDATE, DELETE
ON cryptographic_audit_chain
FROM PUBLIC;



REVOKE UPDATE, DELETE
ON cryptographic_audit_chain
FROM application_users;



-- ============================================================
-- Dedicated audit writer role
-- ============================================================


CREATE ROLE audit_writer;


GRANT INSERT
ON cryptographic_audit_chain
TO audit_writer;



GRANT SELECT
ON cryptographic_audit_chain
TO audit_writer;



-- Readers can investigate but never modify

CREATE ROLE audit_reader;


GRANT SELECT
ON cryptographic_audit_chain
TO audit_reader;



-- Explicitly prevent destructive actions

REVOKE UPDATE, DELETE
ON cryptographic_audit_chain
FROM audit_writer;



REVOKE UPDATE, DELETE
ON cryptographic_audit_chain
FROM audit_reader;



-- ============================================================
-- Security event examples
--
-- Examples:
--
-- LOGIN_SUCCESS
-- LOGIN_FAILURE
-- PRIVILEGE_GRANTED
-- PRIVILEGE_REVOKED
-- SHIFT_APPROVED
-- CAD_RECORD_CREATED
-- CAD_RECORD_MODIFIED
-- ADMIN_ACCESS_REQUESTED
-- EMERGENCY_OVERRIDE_USED
--
-- ============================================================



COMMENT ON TABLE cryptographic_audit_chain IS

'Append-only SHA512 chained audit ledger. Any modification breaks cryptographic verification.';



COMMENT ON COLUMN cryptographic_audit_chain.event_hash IS

'SHA512 hash of event data and previous hash.';



COMMENT ON COLUMN cryptographic_audit_chain.previous_hash IS

'Hash pointer to previous audit event.';