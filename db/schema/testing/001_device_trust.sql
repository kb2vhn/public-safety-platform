-- ============================================================
-- 001_device_trust.sql
--
-- Public Safety Platform
--
-- Device Trust Enhancement Layer
--
-- Depends on:
--
-- 000_trust_foundation.sql
--
-- Purpose:
--
-- Extend the foundational device identity model.
--
-- A device identity proves:
--
-- "This is an approved CAD workstation."
--
-- It does NOT prove:
--
-- "This user may perform this action."
--
-- Authorization happens elsewhere.
--
-- ============================================================


BEGIN;


CREATE EXTENSION IF NOT EXISTS "uuid-ossp";



-- ============================================================
-- DEVICE TRUST STATES
-- ============================================================


DO $$
BEGIN

IF NOT EXISTS
(
    SELECT 1
    FROM pg_type
    WHERE typname = 'device_trust_state'
)
THEN

CREATE TYPE device_trust_state AS ENUM
(
    'UNKNOWN',
    'PENDING',
    'TRUSTED',
    'QUARANTINED',
    'REVOKED'
);

END IF;

END
$$;



-- ============================================================
-- DEVICE TRUST PROFILE
--
-- Additional security posture information.
--
-- ============================================================


CREATE TABLE IF NOT EXISTS device_trust_profile
(

    device_id UUID PRIMARY KEY
        REFERENCES devices(device_id)
        ON DELETE CASCADE,


    trust_state device_trust_state
        NOT NULL DEFAULT 'UNKNOWN',


    operating_system VARCHAR(100),


    operating_system_version VARCHAR(100),


    security_agent_present BOOLEAN
        NOT NULL DEFAULT false,


    encryption_enabled BOOLEAN
        NOT NULL DEFAULT false,


    last_attestation TIMESTAMPTZ,


    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now(),


    updated_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



-- ============================================================
-- DEVICE CERTIFICATE VALIDATION HISTORY
--
-- Certificates prove machine identity.
--
-- This records every validation attempt.
--
-- ============================================================


CREATE TABLE IF NOT EXISTS device_certificate_validations
(

    validation_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),


    device_id UUID NOT NULL
        REFERENCES devices(device_id),


    certificate_id UUID
        REFERENCES device_certificates(certificate_id),


    validation_result VARCHAR(50)
        NOT NULL,


    validation_reason TEXT,


    validated_by VARCHAR(255),


    validation_time TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



-- ============================================================
-- DEVICE SECURITY EVENTS
--
-- Operational security telemetry.
--
-- Examples:
--
-- Certificate rejected
-- Malware detected
-- Device removed
-- Trust revoked
--
-- ============================================================


CREATE TABLE IF NOT EXISTS device_security_events
(

    event_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),


    device_id UUID NOT NULL
        REFERENCES devices(device_id),


    event_type VARCHAR(100)
        NOT NULL,


    severity VARCHAR(50)
        NOT NULL,


    event_data JSONB
        NOT NULL,


    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



-- ============================================================
-- DEVICE TRUST CHANGE HISTORY
--
-- Append-only history of trust state changes.
--
-- ============================================================


CREATE TABLE IF NOT EXISTS device_trust_history
(

    history_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),


    device_id UUID NOT NULL
        REFERENCES devices(device_id),


    previous_state device_trust_state,


    new_state device_trust_state
        NOT NULL,


    changed_by UUID
        REFERENCES persons(person_id),


    change_reason TEXT
        NOT NULL,


    changed_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



-- ============================================================
-- INDEXES
-- ============================================================


CREATE INDEX IF NOT EXISTS idx_device_trust_state
ON device_trust_profile(trust_state);



CREATE INDEX IF NOT EXISTS idx_device_validation_device
ON device_certificate_validations(device_id);



CREATE INDEX IF NOT EXISTS idx_device_security_events_device
ON device_security_events(device_id);



CREATE INDEX IF NOT EXISTS idx_device_security_events_time
ON device_security_events(created_at);



CREATE INDEX IF NOT EXISTS idx_device_trust_history_device
ON device_trust_history(device_id);



-- ============================================================
-- SECURITY
--
-- Application does not own trust.
--
-- ============================================================


REVOKE UPDATE, DELETE
ON device_security_events
FROM PUBLIC;


REVOKE UPDATE, DELETE
ON device_trust_history
FROM PUBLIC;



COMMIT;
