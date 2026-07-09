-- ============================================================
-- 017_database_identity_lifecycle.sql
--
-- Part 1
--
-- Identity Lifecycle Foundation
--
-- ============================================================


BEGIN;


-- ============================================================
-- Identity lifecycle states
-- ============================================================


DO $$

BEGIN

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_type
        WHERE typname = 'identity_lifecycle_state'
    )

    THEN

        CREATE TYPE identity_lifecycle_state AS ENUM
        (
            'PENDING',
            'ACTIVE',
            'SUSPENDED',
            'LOCKED',
            'REVOKED',
            'RETIRED'
        );

    END IF;

END

$$;



COMMENT ON TYPE identity_lifecycle_state IS
'Lifecycle states for operational identities.';



-- ============================================================
-- Identity lifecycle current state
-- ============================================================


CREATE TABLE IF NOT EXISTS identity_lifecycle
(

    lifecycle_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),


    identity_id UUID NOT NULL
        REFERENCES identities(identity_id),


    lifecycle_state identity_lifecycle_state
        NOT NULL
        DEFAULT 'PENDING',


    created_by UUID
        REFERENCES persons(person_id),


    created_session UUID
        REFERENCES sessions(session_id),


    updated_by UUID
        REFERENCES persons(person_id),


    updated_session UUID
        REFERENCES sessions(session_id),


    updated_at TIMESTAMPTZ
        NOT NULL
        DEFAULT now(),


    created_at TIMESTAMPTZ
        NOT NULL
        DEFAULT now(),


    CONSTRAINT unique_identity_lifecycle
        UNIQUE(identity_id)

);



COMMENT ON TABLE identity_lifecycle IS
'Current lifecycle state for each operational identity.';



CREATE INDEX IF NOT EXISTS idx_identity_lifecycle_state

ON identity_lifecycle
(
    lifecycle_state
);



CREATE INDEX IF NOT EXISTS idx_identity_lifecycle_identity

ON identity_lifecycle
(
    identity_id
);



COMMIT;


-- ============================================================
-- End Part 1
-- ============================================================

-- ============================================================
-- 017_database_identity_lifecycle.sql
--
-- Part 2
--
-- Immutable Identity Lifecycle Events
--
-- ============================================================


BEGIN;



-- ============================================================
-- Identity lifecycle event history
--
-- Append-only record of every identity state transition
--
-- ============================================================


CREATE TABLE IF NOT EXISTS identity_lifecycle_events
(

    event_id UUID PRIMARY KEY
        DEFAULT uuid_generate_v4(),


    identity_id UUID NOT NULL
        REFERENCES identities(identity_id),


    previous_state identity_lifecycle_state,


    new_state identity_lifecycle_state
        NOT NULL,


    reason TEXT NOT NULL,


    performed_by UUID
        REFERENCES persons(person_id),


    performed_session UUID
        REFERENCES sessions(session_id),


    event_hash BYTEA NOT NULL,


    previous_event_hash BYTEA,


    created_at TIMESTAMPTZ
        NOT NULL
        DEFAULT now()

);



COMMENT ON TABLE identity_lifecycle_events IS
'Immutable append-only history of identity lifecycle transitions.';



COMMENT ON COLUMN identity_lifecycle_events.event_hash IS
'Cryptographic hash of this lifecycle event.';



COMMENT ON COLUMN identity_lifecycle_events.previous_event_hash IS
'Hash of the previous lifecycle event for chain validation.';



-- ============================================================
-- Indexes
-- ============================================================


CREATE INDEX IF NOT EXISTS idx_identity_lifecycle_events_identity

ON identity_lifecycle_events
(
    identity_id,
    created_at
);



CREATE INDEX IF NOT EXISTS idx_identity_lifecycle_events_state

ON identity_lifecycle_events
(
    new_state
);



COMMIT;



-- ============================================================
-- End Part 2
-- ============================================================
-- ============================================================
-- 017_database_identity_lifecycle.sql
--
-- Part 3
--
-- Identity Lifecycle Cryptographic Integrity
--
-- ============================================================


BEGIN;



-- ============================================================
-- Attach previous lifecycle event hash
--
-- Creates a chained history
--
-- ============================================================


CREATE OR REPLACE FUNCTION attach_previous_identity_lifecycle_hash()

RETURNS TRIGGER

LANGUAGE plpgsql

AS $$

DECLARE

    last_hash BYTEA;


BEGIN


    SELECT event_hash

    INTO last_hash

    FROM identity_lifecycle_events

    WHERE identity_id = NEW.identity_id

    ORDER BY created_at DESC

    LIMIT 1;



    NEW.previous_event_hash := last_hash;



    RETURN NEW;


END;

$$;



COMMENT ON FUNCTION attach_previous_identity_lifecycle_hash()

IS

'Attaches the previous lifecycle event hash to maintain an integrity chain.';



-- ============================================================
-- Generate lifecycle event hash
--
-- ============================================================


CREATE OR REPLACE FUNCTION generate_identity_lifecycle_hash()

RETURNS TRIGGER

LANGUAGE plpgsql

AS $$

BEGIN


    NEW.event_hash := digest

    (

        COALESCE
        (
            encode(NEW.previous_event_hash,'hex'),
            ''
        )

        ||

        NEW.identity_id::text

        ||

        COALESCE(NEW.previous_state::text,'')

        ||

        NEW.new_state::text

        ||

        NEW.reason

        ||

        NEW.created_at::text,


        'sha512'

    );


    RETURN NEW;


END;

$$;



COMMENT ON FUNCTION generate_identity_lifecycle_hash()

IS

'Generates SHA-512 integrity hash for identity lifecycle events.';



-- ============================================================
-- Triggers
--
-- Order matters:
--
-- 1. Attach previous hash
-- 2. Generate current hash
--
-- ============================================================


DROP TRIGGER IF EXISTS trg_attach_previous_identity_lifecycle_hash

ON identity_lifecycle_events;



CREATE TRIGGER trg_attach_previous_identity_lifecycle_hash

BEFORE INSERT

ON identity_lifecycle_events

FOR EACH ROW

EXECUTE FUNCTION attach_previous_identity_lifecycle_hash();



DROP TRIGGER IF EXISTS trg_generate_identity_lifecycle_hash

ON identity_lifecycle_events;



CREATE TRIGGER trg_generate_identity_lifecycle_hash

BEFORE INSERT

ON identity_lifecycle_events

FOR EACH ROW

EXECUTE FUNCTION generate_identity_lifecycle_hash();



-- ============================================================
-- Prevent history modification
--
-- Lifecycle history is immutable
--
-- ============================================================


CREATE OR REPLACE FUNCTION prevent_identity_lifecycle_event_change()

RETURNS TRIGGER

LANGUAGE plpgsql

AS $$

BEGIN


    RAISE EXCEPTION

    'Identity lifecycle history is immutable';



END;

$$;



DROP TRIGGER IF EXISTS trg_block_identity_lifecycle_update

ON identity_lifecycle_events;



CREATE TRIGGER trg_block_identity_lifecycle_update

BEFORE UPDATE

ON identity_lifecycle_events

FOR EACH ROW

EXECUTE FUNCTION prevent_identity_lifecycle_event_change();



DROP TRIGGER IF EXISTS trg_block_identity_lifecycle_delete

ON identity_lifecycle_events;



CREATE TRIGGER trg_block_identity_lifecycle_delete

BEFORE DELETE

ON identity_lifecycle_events

FOR EACH ROW

EXECUTE FUNCTION prevent_identity_lifecycle_event_change();



COMMIT;



-- ============================================================
-- End Part 3
-- ============================================================
-- ============================================================
-- 017_database_identity_lifecycle.sql
--
-- Part 4
--
-- Identity Lifecycle Transition API
--
-- ============================================================


BEGIN;



-- ============================================================
-- Internal lifecycle transition function
--
-- All lifecycle changes flow through this function
--
-- ============================================================


CREATE OR REPLACE FUNCTION security.change_identity_lifecycle_state

(
    p_identity_id UUID,
    p_new_state identity_lifecycle_state,
    p_reason TEXT
)

RETURNS VOID

LANGUAGE plpgsql

SECURITY DEFINER

SET search_path = security, public


AS $$


DECLARE

    current_state identity_lifecycle_state;

    actor UUID;

    session UUID;



BEGIN



    actor := security.current_person();

    session := security.current_session();



    IF actor IS NULL THEN

        RAISE EXCEPTION
        'No authenticated operational identity';

    END IF;



    SELECT lifecycle_state

    INTO current_state

    FROM identity_lifecycle

    WHERE identity_id = p_identity_id;



    IF NOT FOUND THEN

        INSERT INTO identity_lifecycle
        (
            identity_id,
            lifecycle_state,
            created_by,
            created_session,
            updated_by,
            updated_session
        )

        VALUES
        (
            p_identity_id,
            p_new_state,
            actor,
            session,
            actor,
            session
        );


    ELSE


        UPDATE identity_lifecycle

        SET

            lifecycle_state = p_new_state,

            updated_by = actor,

            updated_session = session,

            updated_at = now()


        WHERE identity_id = p_identity_id;



    END IF;



    INSERT INTO identity_lifecycle_events
    (

        identity_id,

        previous_state,

        new_state,

        reason,

        performed_by,

        performed_session

    )

    VALUES

    (

        p_identity_id,

        current_state,

        p_new_state,

        p_reason,

        actor,

        session

    );



    PERFORM security_write_audit

    (

        'IDENTITY_LIFECYCLE_CHANGE',

        'IDENTITY_SECURITY',

        jsonb_build_object

        (

            'identity_id',
            p_identity_id,

            'previous_state',
            current_state,

            'new_state',
            p_new_state

        )

    );



END;

$$;



COMMENT ON FUNCTION security.change_identity_lifecycle_state(UUID,identity_lifecycle_state,TEXT)

IS

'Central API for controlled identity lifecycle state transitions.';



COMMIT;



-- ============================================================
-- End Part 4
-- ============================================================
-- ============================================================
-- 017_database_identity_lifecycle.sql
--
-- Part 5
--
-- Identity Lifecycle Public API
--
-- ============================================================


BEGIN;



-- ============================================================
-- Activate identity
--
-- ============================================================


CREATE OR REPLACE FUNCTION security.activate_identity

(
    p_identity_id UUID,
    p_reason TEXT
)

RETURNS VOID

LANGUAGE plpgsql

SECURITY DEFINER

SET search_path = security, public


AS $$

BEGIN


    PERFORM security.change_identity_lifecycle_state

    (

        p_identity_id,

        'ACTIVE',

        p_reason

    );


END;

$$;



COMMENT ON FUNCTION security.activate_identity(UUID,TEXT)

IS

'Activates an operational identity after approval.';



-- ============================================================
-- Suspend identity
--
-- ============================================================


CREATE OR REPLACE FUNCTION security.suspend_identity

(
    p_identity_id UUID,
    p_reason TEXT
)

RETURNS VOID

LANGUAGE plpgsql

SECURITY DEFINER

SET search_path = security, public


AS $$

BEGIN


    PERFORM security.change_identity_lifecycle_state

    (

        p_identity_id,

        'SUSPENDED',

        p_reason

    );


END;

$$;



COMMENT ON FUNCTION security.suspend_identity(UUID,TEXT)

IS

'Suspends an operational identity.';



-- ============================================================
-- Lock identity
--
-- ============================================================


CREATE OR REPLACE FUNCTION security.lock_identity

(
    p_identity_id UUID,
    p_reason TEXT
)

RETURNS VOID

LANGUAGE plpgsql

SECURITY DEFINER

SET search_path = security, public


AS $$

BEGIN


    PERFORM security.change_identity_lifecycle_state

    (

        p_identity_id,

        'LOCKED',

        p_reason

    );


END;

$$;



COMMENT ON FUNCTION security.lock_identity(UUID,TEXT)

IS

'Locks an identity due to security concerns.';



-- ============================================================
-- Revoke identity
--
-- ============================================================


CREATE OR REPLACE FUNCTION security.revoke_identity

(
    p_identity_id UUID,
    p_reason TEXT
)

RETURNS VOID

LANGUAGE plpgsql

SECURITY DEFINER

SET search_path = security, public


AS $$

BEGIN


    PERFORM security.change_identity_lifecycle_state

    (

        p_identity_id,

        'REVOKED',

        p_reason

    );


END;

$$;



COMMENT ON FUNCTION security.revoke_identity(UUID,TEXT)

IS

'Permanently revokes an operational identity.';



-- ============================================================
-- Retire identity
--
-- ============================================================


CREATE OR REPLACE FUNCTION security.retire_identity

(
    p_identity_id UUID,
    p_reason TEXT
)

RETURNS VOID

LANGUAGE plpgsql

SECURITY DEFINER

SET search_path = security, public


AS $$

BEGIN


    PERFORM security.change_identity_lifecycle_state

    (

        p_identity_id,

        'RETIRED',

        p_reason

    );


END;

$$;



COMMENT ON FUNCTION security.retire_identity(UUID,TEXT)

IS

'Retires an operational identity from service.';



COMMIT;



-- ============================================================
-- End Part 5
-- ============================================================


-- ============================================================
-- 017_database_identity_lifecycle.sql
--
-- Part 6
--
-- Security Hardening
--
-- Identity lifecycle changes are controlled through
-- SECURITY DEFINER lifecycle functions.
--
-- ============================================================


BEGIN;



-- ============================================================
-- Transfer lifecycle function ownership
--
-- SECURITY DEFINER functions must not belong to humans.
--
-- ============================================================


ALTER FUNCTION security.change_identity_lifecycle_state(
    UUID,
    identity_lifecycle_state,
    TEXT
)
OWNER TO cad_security;



ALTER FUNCTION security.activate_identity(
    UUID,
    TEXT
)
OWNER TO cad_security;



ALTER FUNCTION security.suspend_identity(
    UUID,
    TEXT
)
OWNER TO cad_security;



ALTER FUNCTION security.lock_identity(
    UUID,
    TEXT
)
OWNER TO cad_security;



ALTER FUNCTION security.revoke_identity(
    UUID,
    TEXT
)
OWNER TO cad_security;



ALTER FUNCTION security.retire_identity(
    UUID,
    TEXT
)
OWNER TO cad_security;



-- ============================================================
-- Lock function execution environment
--
-- Prevent search_path manipulation.
--
-- ============================================================


ALTER FUNCTION security.change_identity_lifecycle_state(
    UUID,
    identity_lifecycle_state,
    TEXT
)
SET search_path = security, public;



ALTER FUNCTION security.activate_identity(
    UUID,
    TEXT
)
SET search_path = security, public;



ALTER FUNCTION security.suspend_identity(
    UUID,
    TEXT
)
SET search_path = security, public;



ALTER FUNCTION security.lock_identity(
    UUID,
    TEXT
)
SET search_path = security, public;



ALTER FUNCTION security.revoke_identity(
    UUID,
    TEXT
)
SET search_path = security, public;



ALTER FUNCTION security.retire_identity(
    UUID,
    TEXT
)
SET search_path = security, public;



-- ============================================================
-- Remove direct modification capability
--
-- Lifecycle transitions must flow through APIs.
--
-- ============================================================


REVOKE INSERT, UPDATE, DELETE
ON identities
FROM cad_application;



REVOKE INSERT, UPDATE, DELETE
ON identity_lifecycle_events
FROM cad_application;



REVOKE INSERT, UPDATE, DELETE
ON identity_lifecycle
FROM cad_application;



-- ============================================================
-- Application execution rights
--
-- Application may request lifecycle actions,
-- but cannot modify tables directly.
--
-- ============================================================


GRANT EXECUTE
ON FUNCTION security.change_identity_lifecycle_state(
    UUID,
    identity_lifecycle_state,
    TEXT
)
TO cad_application;



GRANT EXECUTE
ON FUNCTION security.activate_identity(
    UUID,
    TEXT
)
TO cad_application;



GRANT EXECUTE
ON FUNCTION security.suspend_identity(
    UUID,
    TEXT
)
TO cad_application;



GRANT EXECUTE
ON FUNCTION security.lock_identity(
    UUID,
    TEXT
)
TO cad_application;



GRANT EXECUTE
ON FUNCTION security.revoke_identity(
    UUID,
    TEXT
)
TO cad_application;



GRANT EXECUTE
ON FUNCTION security.retire_identity(
    UUID,
    TEXT
)
TO cad_application;



-- ============================================================
-- Audit visibility
--
-- Auditors can review identity lifecycle history.
--
-- ============================================================


GRANT SELECT
ON identities
TO cad_auditor;



GRANT SELECT
ON identity_lifecycle
TO cad_auditor;



GRANT SELECT
ON identity_lifecycle_events
TO cad_auditor;



COMMIT;



-- ============================================================
-- End Part 6
-- ============================================================
