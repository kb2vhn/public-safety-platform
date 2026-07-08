-- ============================================================
-- 013_cryptographic_audit_chain.sql
--
-- Cryptographic Audit Integrity Layer
--
-- Public Safety Platform
--
-- ============================================================

BEGIN;


CREATE EXTENSION IF NOT EXISTS "pgcrypto";


-- ============================================================
-- Cryptographic audit event chain
-- ============================================================


CREATE TABLE IF NOT EXISTS cryptographic_audit_chain
(

    audit_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),


    sequence_number BIGSERIAL
        NOT NULL UNIQUE,


    event_time TIMESTAMPTZ
        NOT NULL DEFAULT now(),


    -- Identity responsible for action

    identity_id UUID
        REFERENCES identities(identity_id),


    person_id UUID
        REFERENCES persons(person_id),


    -- Session/device context

    session_id UUID
        REFERENCES sessions(session_id),


    device_id UUID
        REFERENCES devices(device_id),


    agency_id UUID
        REFERENCES agencies(agency_id),



    event_type VARCHAR(100)
        NOT NULL,


    event_category VARCHAR(50)
        NOT NULL,



    object_type VARCHAR(100),


    object_id UUID,


    action VARCHAR(100)
        NOT NULL,



    source_ip INET,


    machine_certificate_fingerprint VARCHAR(128),


    user_certificate_fingerprint VARCHAR(128),



    event_payload JSONB
        NOT NULL,



    previous_hash BYTEA,


    event_hash BYTEA
        NOT NULL,



    signature BYTEA,


    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



-- ============================================================
-- Indexes
-- ============================================================


CREATE INDEX IF NOT EXISTS idx_audit_identity
ON cryptographic_audit_chain(identity_id);



CREATE INDEX IF NOT EXISTS idx_audit_person
ON cryptographic_audit_chain(person_id);



CREATE INDEX IF NOT EXISTS idx_audit_event_type
ON cryptographic_audit_chain(event_type);



CREATE INDEX IF NOT EXISTS idx_audit_time
ON cryptographic_audit_chain(event_time);



-- ============================================================
-- Generate SHA512 hash
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

    COALESCE(NEW.identity_id::text,'') ||

    COALESCE(NEW.person_id::text,'') ||

    COALESCE(NEW.session_id::text,'') ||

    NEW.event_type ||

    NEW.action ||

    NEW.event_payload::text,


    'sha512'

);


RETURN NEW;


END;

$$;



CREATE OR REPLACE TRIGGER trg_generate_audit_hash

BEFORE INSERT

ON cryptographic_audit_chain

FOR EACH ROW

EXECUTE FUNCTION generate_audit_hash();



-- ============================================================
-- Attach previous hash
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



CREATE OR REPLACE TRIGGER trg_attach_previous_hash

BEFORE INSERT

ON cryptographic_audit_chain

FOR EACH ROW

EXECUTE FUNCTION attach_previous_audit_hash();



-- ============================================================
-- Verify chain integrity
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


expected_hash := digest(

COALESCE(encode(previous,'hex'),'') ||

current_record.event_time::text ||

COALESCE(current_record.identity_id::text,'') ||

COALESCE(current_record.person_id::text,'') ||

COALESCE(current_record.session_id::text,'') ||

current_record.event_type ||

current_record.action ||

current_record.event_payload::text,


'sha512'


);



IF expected_hash <> current_record.event_hash

THEN

RETURN FALSE;

END IF;



previous := current_record.event_hash;



END LOOP;


RETURN TRUE;


END;

$$;



-- ============================================================
-- Security hardening
-- ============================================================


REVOKE UPDATE, DELETE

ON cryptographic_audit_chain

FROM PUBLIC;



-- ============================================================
-- Audit roles
-- ============================================================


DO $$

BEGIN

IF NOT EXISTS
(
SELECT 1
FROM pg_roles
WHERE rolname='audit_writer'
)

THEN

CREATE ROLE audit_writer;

END IF;


IF NOT EXISTS
(
SELECT 1
FROM pg_roles
WHERE rolname='audit_reader'
)

THEN

CREATE ROLE audit_reader;

END IF;


END

$$;



GRANT INSERT, SELECT

ON cryptographic_audit_chain

TO audit_writer;



GRANT SELECT

ON cryptographic_audit_chain

TO audit_reader;



REVOKE UPDATE, DELETE

ON cryptographic_audit_chain

FROM audit_writer;



REVOKE UPDATE, DELETE

ON cryptographic_audit_chain

FROM audit_reader;



COMMENT ON TABLE cryptographic_audit_chain IS

'Append-only SHA512 chained audit ledger. Any modification breaks cryptographic verification.';



COMMENT ON COLUMN cryptographic_audit_chain.event_hash IS

'SHA512 hash of event data and previous hash.';



COMMENT ON COLUMN cryptographic_audit_chain.previous_hash IS

'Hash pointer to previous audit event.';



COMMIT;
