-- ============================================================
-- 015_operational_integrity.sql
--
-- Public Safety Operational Data Integrity Layer
--
-- Protects:
--   CAD incidents
--   Dispatch operations
--   Timeline history
--   Operational records
--
-- Design principles:
--
--   - No silent modification
--   - No destructive history changes
--   - Finalized records become immutable
--   - Corrections use append-only amendments
--   - Every security decision is auditable
--
-- Depends on:
--
--   000_trust_foundation.sql
--   001_device_trust.sql
--   002_operational_authority.sql
--   003_authorization.sql
--   004_sessions.sql
--   005_audit_event_stream.sql
--   006_cad_core.sql
--   007_cad_security.sql
--   012_row_level_security.sql
--   013_cryptographic_audit_chain.sql
--
-- ============================================================


BEGIN;


-- ============================================================
-- Required cryptographic functions
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;



-- ============================================================
-- Operational Record State
--
-- Defines the lifecycle of protected records
--
-- DRAFT
--     Record being created
--
-- ACTIVE
--     Operational use
--
-- PENDING_REVIEW
--     Awaiting supervisor/review process
--
-- FINALIZED
--     Operationally complete
--
-- SEALED
--     Immutable record
--
-- ARCHIVED
--     Long term retention
--
-- ============================================================


DO $$

BEGIN

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_type
        WHERE typname = 'operational_record_state'
    )

    THEN

        CREATE TYPE operational_record_state AS ENUM
        (
            'DRAFT',
            'ACTIVE',
            'PENDING_REVIEW',
            'FINALIZED',
            'SEALED',
            'ARCHIVED'
        );

    END IF;

END

$$;



COMMENT ON TYPE operational_record_state IS

'Lifecycle state for protected public safety operational records';



-- ============================================================
-- Operational Record Integrity
--
-- This table provides integrity metadata for protected objects.
--
-- Examples:
--
-- object_type:
--      CAD_INCIDENT
--      DISPATCH_EVENT
--      REPORT
--      EVIDENCE_REFERENCE
--
-- object_id:
--      UUID of protected object
--
-- ============================================================


CREATE TABLE IF NOT EXISTS operational_record_integrity
(

    integrity_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),



    object_type VARCHAR(100)
        NOT NULL,



    object_id UUID
        NOT NULL,



    record_state operational_record_state
        NOT NULL DEFAULT 'ACTIVE',



    created_person UUID
        REFERENCES persons(person_id),



    created_session UUID
        REFERENCES sessions(session_id),



    finalized_person UUID
        REFERENCES persons(person_id),



    finalized_session UUID
        REFERENCES sessions(session_id),



    finalized_at TIMESTAMPTZ,



    sealed_person UUID
        REFERENCES persons(person_id),



    sealed_session UUID
        REFERENCES sessions(session_id),



    sealed_at TIMESTAMPTZ,



    record_hash BYTEA,



    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()



);



COMMENT ON TABLE operational_record_integrity IS

'Tracks integrity state and lifecycle of protected operational records';



COMMENT ON COLUMN operational_record_integrity.object_type IS

'Logical object type being protected';



COMMENT ON COLUMN operational_record_integrity.object_id IS

'UUID of protected operational object';



COMMENT ON COLUMN operational_record_integrity.record_hash IS

'Cryptographic hash of protected record state';



-- ============================================================
-- Indexes
-- ============================================================


CREATE INDEX IF NOT EXISTS idx_operational_integrity_object

ON operational_record_integrity
(
    object_type,
    object_id
);



CREATE INDEX IF NOT EXISTS idx_operational_integrity_state

ON operational_record_integrity
(
    record_state
);



CREATE INDEX IF NOT EXISTS idx_operational_integrity_created

ON operational_record_integrity
(
    created_at
);



COMMIT;

-- ============================================================
-- Immutable Operational Timeline Events
--
-- Public safety records are historical facts.
--
-- Corrections are new events.
-- Existing events are never changed.
--
-- ============================================================


CREATE TABLE IF NOT EXISTS operational_timeline_events
(

    event_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),



    object_type VARCHAR(100)
        NOT NULL,



    object_id UUID
        NOT NULL,



    event_time TIMESTAMPTZ
        NOT NULL DEFAULT now(),



    event_type VARCHAR(100)
        NOT NULL,



    description TEXT
        NOT NULL,



    created_person UUID
        REFERENCES persons(person_id),



    created_session UUID
        REFERENCES sessions(session_id),



    source_system VARCHAR(50)
        NOT NULL DEFAULT 'CAD',



    previous_event_hash BYTEA,



    event_hash BYTEA
        NOT NULL,



    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()

);



COMMENT ON TABLE operational_timeline_events IS

'Immutable operational history. Events are append-only and cannot be modified';



COMMENT ON COLUMN operational_timeline_events.previous_event_hash IS

'Hash of previous event creating a tamper evident event chain';



COMMENT ON COLUMN operational_timeline_events.event_hash IS

'Cryptographic hash of this event';



-- ============================================================
-- Timeline indexes
-- ============================================================


CREATE INDEX IF NOT EXISTS idx_operational_timeline_object

ON operational_timeline_events
(
    object_type,
    object_id,
    event_time
);



CREATE INDEX IF NOT EXISTS idx_operational_timeline_person

ON operational_timeline_events
(
    created_person
);



CREATE INDEX IF NOT EXISTS idx_operational_timeline_session

ON operational_timeline_events
(
    created_session
);

-- ============================================================
-- Operational Timeline Cryptographic Hashing
--
-- Creates a tamper evident chain:
--
-- Event 1
--   hash = SHA512(data)
--
-- Event 2
--   hash = SHA512(event1.hash + data)
--
-- Event 3
--   hash = SHA512(event2.hash + data)
--
-- Any modification breaks the chain.
--
-- ============================================================


CREATE OR REPLACE FUNCTION generate_operational_timeline_hash()

RETURNS TRIGGER

LANGUAGE plpgsql

AS $$

BEGIN


    NEW.event_hash :=
        digest
        (
            COALESCE
            (
                encode(NEW.previous_event_hash,'hex'),
                ''
            )
            ||
            NEW.object_type
            ||
            NEW.object_id::text
            ||
            NEW.event_time::text
            ||
            NEW.event_type
            ||
            NEW.description
            ||
            COALESCE(NEW.created_person::text,'')
            ||
            COALESCE(NEW.created_session::text,''),

            'sha512'
        );


    RETURN NEW;


END;

$$;



COMMENT ON FUNCTION generate_operational_timeline_hash() IS

'Automatically generates SHA-512 integrity hash for operational timeline events';



-- ============================================================
-- Automatically attach previous event hash
--
-- Each object maintains its own chain.
--
-- Example:
--
-- CAD_INCIDENT
-- UUID-123
--
-- Event A
-- Event B -> references A
-- Event C -> references B
--
-- ============================================================


CREATE OR REPLACE FUNCTION attach_previous_operational_event_hash()

RETURNS TRIGGER

LANGUAGE plpgsql

AS $$

DECLARE

    last_hash BYTEA;


BEGIN


    SELECT event_hash

    INTO last_hash

    FROM operational_timeline_events

    WHERE object_type = NEW.object_type

    AND object_id = NEW.object_id

    ORDER BY event_time DESC, created_at DESC

    LIMIT 1;



    NEW.previous_event_hash := last_hash;



    RETURN NEW;


END;

$$;



COMMENT ON FUNCTION attach_previous_operational_event_hash() IS

'Links new timeline events to previous event creating an integrity chain';



-- ============================================================
-- Timeline insert triggers
-- ============================================================


DROP TRIGGER IF EXISTS trg_attach_previous_operational_hash

ON operational_timeline_events;



CREATE TRIGGER trg_attach_previous_operational_hash

BEFORE INSERT

ON operational_timeline_events

FOR EACH ROW

EXECUTE FUNCTION attach_previous_operational_event_hash();




DROP TRIGGER IF EXISTS trg_generate_operational_timeline_hash

ON operational_timeline_events;



CREATE TRIGGER trg_generate_operational_timeline_hash

BEFORE INSERT

ON operational_timeline_events

FOR EACH ROW

EXECUTE FUNCTION generate_operational_timeline_hash();

-- ============================================================
-- Prevent Timeline Modification
--
-- Operational history is immutable.
--
-- UPDATE and DELETE are forbidden.
--
-- Corrections must be new events.
--
-- ============================================================


CREATE OR REPLACE FUNCTION prevent_operational_timeline_modification()

RETURNS TRIGGER

LANGUAGE plpgsql

AS $$

BEGIN


    RAISE EXCEPTION

    'Operational timeline records are immutable. Create an amendment event instead.';



END;

$$;



COMMENT ON FUNCTION prevent_operational_timeline_modification() IS

'Blocks modification or deletion of operational timeline history';



-- ============================================================
-- Block UPDATE
-- ============================================================


DROP TRIGGER IF EXISTS trg_block_operational_timeline_update

ON operational_timeline_events;



CREATE TRIGGER trg_block_operational_timeline_update

BEFORE UPDATE

ON operational_timeline_events

FOR EACH ROW

EXECUTE FUNCTION prevent_operational_timeline_modification();



-- ============================================================
-- Block DELETE
-- ============================================================


DROP TRIGGER IF EXISTS trg_block_operational_timeline_delete

ON operational_timeline_events;



CREATE TRIGGER trg_block_operational_timeline_delete

BEFORE DELETE

ON operational_timeline_events

FOR EACH ROW

EXECUTE FUNCTION prevent_operational_timeline_modification();

-- ============================================================
-- Operational Record Finalization
--
-- Lifecycle:
--
-- ACTIVE
--    |
--    v
-- FINALIZED
--    |
--    v
-- SEALED
--
-- SEALED records cannot be modified.
--
-- ============================================================



CREATE OR REPLACE FUNCTION finalize_operational_record

(

    target_object_type VARCHAR(100),

    target_object_id UUID

)

RETURNS VOID

LANGUAGE plpgsql

SECURITY DEFINER


AS $$


DECLARE

    current_person_id UUID;

    current_session_id UUID;


BEGIN


    current_person_id := security.current_person();

    current_session_id := security.current_session();



    IF current_person_id IS NULL THEN

        RAISE EXCEPTION

        'Unable to finalize record without authenticated person';


    END IF;



    IF current_session_id IS NULL THEN

        RAISE EXCEPTION

        'Unable to finalize record without authenticated session';


    END IF;



    UPDATE operational_record_integrity

    SET

        record_state = 'FINALIZED',

        finalized_person = current_person_id,

        finalized_session = current_session_id,

        finalized_at = now()


    WHERE object_type = target_object_type

    AND object_id = target_object_id;



    IF NOT FOUND THEN

        RAISE EXCEPTION

        'Operational integrity record not found: %.%',

        target_object_type,

        target_object_id;


    END IF;



    INSERT INTO cryptographic_audit_chain

    (

        person_id,

        session_id,

        event_type,

        event_category,

        object_type,

        object_id,

        action,

        event_payload

    )

    VALUES

    (

        current_person_id,

        current_session_id,

        'OPERATIONAL_RECORD_FINALIZED',

        'OPERATIONAL_INTEGRITY',

        target_object_type,

        target_object_id,

        'FINALIZE',

        jsonb_build_object

        (

            'object_type',

            target_object_type,


            'object_id',

            target_object_id

        )

    );



END;

$$;



COMMENT ON FUNCTION finalize_operational_record(VARCHAR,UUID) IS

'Finalizes operational records and records the trusted actor session';



-- ============================================================
-- Seal Operational Record
--
-- Sealing is the final state.
--
-- ============================================================


CREATE OR REPLACE FUNCTION seal_operational_record

(

    target_object_type VARCHAR(100),

    target_object_id UUID,

    supplied_hash BYTEA

)

RETURNS VOID

LANGUAGE plpgsql

SECURITY DEFINER


AS $$


DECLARE

    current_person_id UUID;

    current_session_id UUID;


BEGIN


    current_person_id := security.current_person();

    current_session_id := security.current_session();



    UPDATE operational_record_integrity

    SET

        record_state = 'SEALED',

        sealed_person = current_person_id,

        sealed_session = current_session_id,

        sealed_at = now(),

        record_hash = supplied_hash


    WHERE object_type = target_object_type

    AND object_id = target_object_id

    AND record_state = 'FINALIZED';



    IF NOT FOUND THEN

        RAISE EXCEPTION

        'Record must be FINALIZED before sealing';


    END IF;



    INSERT INTO cryptographic_audit_chain

    (

        person_id,

        session_id,

        event_type,

        event_category,

        object_type,

        object_id,

        action,

        event_payload

    )

    VALUES

    (

        current_person_id,

        current_session_id,

        'OPERATIONAL_RECORD_SEALED',

        'OPERATIONAL_INTEGRITY',

        target_object_type,

        target_object_id,

        'SEAL',

        jsonb_build_object

        (

            'object_type',

            target_object_type,


            'object_id',

            target_object_id

        )

    );


END;

$$;



COMMENT ON FUNCTION seal_operational_record(VARCHAR,UUID,BYTEA) IS

'Seals finalized operational records making them immutable';
-- ============================================================
-- Operational Amendment Requests
--
-- Historical records are never overwritten.
--
-- Corrections require an approved amendment.
--
-- ============================================================


CREATE TABLE IF NOT EXISTS operational_amendments

(

    amendment_id UUID PRIMARY KEY
        DEFAULT gen_random_uuid(),



    object_type VARCHAR(100)
        NOT NULL,



    object_id UUID
        NOT NULL,



    requested_by UUID
        REFERENCES persons(person_id)
        NOT NULL,



    requested_session UUID
        REFERENCES sessions(session_id),



    reason TEXT
        NOT NULL,



    previous_value JSONB,



    proposed_value JSONB
        NOT NULL,



    authorization_request_id UUID
        REFERENCES authorization_requests(authorization_request_id),



    approved_by UUID
        REFERENCES persons(person_id),



    approved_session UUID
        REFERENCES sessions(session_id),



    approved_at TIMESTAMPTZ,



    created_at TIMESTAMPTZ
        NOT NULL DEFAULT now()


);



COMMENT ON TABLE operational_amendments IS

'Controlled correction requests for immutable operational records';



CREATE INDEX IF NOT EXISTS idx_operational_amendment_object

ON operational_amendments

(
    object_type,
    object_id
);



CREATE INDEX IF NOT EXISTS idx_operational_amendment_request

ON operational_amendments

(
    authorization_request_id
);



-- ============================================================
-- Submit amendment request
--
-- Does not modify original record.
--
-- Creates a request only.
--
-- ============================================================


CREATE OR REPLACE FUNCTION request_operational_amendment

(

    target_object_type VARCHAR(100),

    target_object_id UUID,

    amendment_reason TEXT,

    old_value JSONB,

    new_value JSONB,

    auth_request UUID

)

RETURNS UUID

LANGUAGE plpgsql

SECURITY DEFINER


AS $$


DECLARE

    amendment UUID;

BEGIN



    INSERT INTO operational_amendments

    (

        object_type,

        object_id,

        requested_by,

        requested_session,

        reason,

        previous_value,

        proposed_value,

        authorization_request_id

    )

    VALUES

    (

        target_object_type,

        target_object_id,

        security.current_person(),

        security.current_session(),

        amendment_reason,

        old_value,

        new_value,

        auth_request

    )


    RETURNING amendment_id

    INTO amendment;



    INSERT INTO cryptographic_audit_chain

    (

        person_id,

        session_id,

        event_type,

        event_category,

        object_type,

        object_id,

        action,

        event_payload

    )

    VALUES

    (

        security.current_person(),

        security.current_session(),

        'OPERATIONAL_AMENDMENT_REQUESTED',

        'OPERATIONAL_INTEGRITY',

        target_object_type,

        target_object_id,

        'REQUEST_AMENDMENT',

        jsonb_build_object

        (

            'amendment_id',

            amendment

        )

    );



    RETURN amendment;


END;

$$;



COMMENT ON FUNCTION request_operational_amendment(VARCHAR,UUID,TEXT,JSONB,JSONB,UUID) IS

'Creates amendment request without modifying immutable operational records';

-- ============================================================
-- Operational Integrity Security Boundary
--
-- Application accounts do not receive direct write access.
--
-- All sensitive actions occur through controlled functions.
--
-- ============================================================



-- ============================================================
-- Remove direct modification rights
-- ============================================================


REVOKE UPDATE, DELETE

ON operational_timeline_events

FROM PUBLIC;



REVOKE UPDATE, DELETE

ON operational_record_integrity

FROM PUBLIC;



REVOKE UPDATE, DELETE

ON operational_amendments

FROM PUBLIC;



-- ============================================================
-- Remove direct table access from CAD application
--
-- The application must use API functions.
--
-- ============================================================


REVOKE ALL

ON operational_timeline_events

FROM cad_application;



REVOKE ALL

ON operational_record_integrity

FROM cad_application;



REVOKE ALL

ON operational_amendments

FROM cad_application;



-- ============================================================
-- Controlled API functions
-- ============================================================


GRANT EXECUTE

ON FUNCTION finalize_operational_record(VARCHAR,UUID)

TO cad_application;



GRANT EXECUTE

ON FUNCTION seal_operational_record(VARCHAR,UUID,BYTEA)

TO cad_application;



GRANT EXECUTE

ON FUNCTION request_operational_amendment
(
    VARCHAR,
    UUID,
    TEXT,
    JSONB,
    JSONB,
    UUID
)

TO cad_application;



-- ============================================================
-- Audit table protection
--
-- No user/application modifies audit history.
--
-- ============================================================


REVOKE UPDATE, DELETE

ON cryptographic_audit_chain

FROM PUBLIC;

-- ============================================================
-- Operational Record Lifecycle Control
--
-- Rules:
--
-- ACTIVE
--   |
--   v
-- FINALIZED
--   |
--   v
-- SEALED
--
-- SEALED records cannot be modified.
--
-- ============================================================


CREATE OR REPLACE FUNCTION security.finalize_operational_record
(
    p_object_type TEXT,
    p_object_id UUID
)

RETURNS VOID

LANGUAGE plpgsql

SECURITY DEFINER

AS $$

DECLARE

    current_person_id UUID;
    current_session_id UUID;

BEGIN


    current_person_id :=
        security.current_person();


    current_session_id :=
        security.current_session();



    IF current_person_id IS NULL THEN

        RAISE EXCEPTION
        'No authenticated operational identity';

    END IF;



    UPDATE operational_record_integrity

    SET

        record_state = 'FINALIZED',

        finalized_person =
            current_person_id,

        finalized_session =
            current_session_id,

        finalized_at =
            now()

    WHERE object_type = p_object_type

    AND object_id = p_object_id

    AND record_state = 'ACTIVE';



    IF NOT FOUND THEN

        RAISE EXCEPTION
        'Record cannot be finalized or does not exist';

    END IF;



    PERFORM security_write_audit
    (
        'OPERATIONAL_RECORD_FINALIZED',

        'INTEGRITY_CONTROL',

        jsonb_build_object
        (
            'object_type',
            p_object_type,

            'object_id',
            p_object_id
        )

    );


END;

$$;



COMMENT ON FUNCTION security.finalize_operational_record(TEXT,UUID)

IS

'Moves operational records from ACTIVE to FINALIZED state. Requires authenticated session.';



-- ============================================================
-- Seal operational record
--
-- Final authority action
--
-- ============================================================


CREATE OR REPLACE FUNCTION security.seal_operational_record
(
    p_object_type TEXT,
    p_object_id UUID
)

RETURNS VOID

LANGUAGE plpgsql

SECURITY DEFINER


AS $$


DECLARE

    current_person_id UUID;

    current_session_id UUID;


BEGIN


    current_person_id :=
        security.current_person();


    current_session_id :=
        security.current_session();



    IF current_person_id IS NULL THEN

        RAISE EXCEPTION
        'No authenticated operational identity';

    END IF;



    UPDATE operational_record_integrity

    SET


        record_state = 'SEALED',


        sealed_person =
            current_person_id,


        sealed_session =
            current_session_id,


        sealed_at =
            now()



    WHERE object_type = p_object_type

    AND object_id = p_object_id

    AND record_state = 'FINALIZED';



    IF NOT FOUND THEN


        RAISE EXCEPTION

        'Only FINALIZED records may be sealed';


    END IF;



    PERFORM security_write_audit
    (

        'OPERATIONAL_RECORD_SEALED',

        'INTEGRITY_CONTROL',

        jsonb_build_object

        (

            'object_type',
            p_object_type,


            'object_id',
            p_object_id

        )

    );


END;

$$;



COMMENT ON FUNCTION security.seal_operational_record(TEXT,UUID)

IS

'Permanently seals finalized operational records.';



-- ============================================================
-- Prevent modification of sealed records
-- ============================================================


CREATE OR REPLACE FUNCTION security.prevent_sealed_record_change()

RETURNS TRIGGER

LANGUAGE plpgsql

AS $$


BEGIN


    IF OLD.record_state = 'SEALED' THEN


        RAISE EXCEPTION

        'SEALED operational records are immutable';


    END IF;


    RETURN NEW;


END;


$$;



DROP TRIGGER IF EXISTS trg_prevent_sealed_integrity_change

ON operational_record_integrity;



CREATE TRIGGER trg_prevent_sealed_integrity_change

BEFORE UPDATE

ON operational_record_integrity

FOR EACH ROW

EXECUTE FUNCTION security.prevent_sealed_record_change();



-- ============================================================
-- Permissions
-- ============================================================


REVOKE ALL

ON FUNCTION security.finalize_operational_record(TEXT,UUID)

FROM PUBLIC;



REVOKE ALL

ON FUNCTION security.seal_operational_record(TEXT,UUID)

FROM PUBLIC;



GRANT EXECUTE

ON FUNCTION security.finalize_operational_record(TEXT,UUID)

TO cad_application;



GRANT EXECUTE

ON FUNCTION security.seal_operational_record(TEXT,UUID)

TO cad_application;
