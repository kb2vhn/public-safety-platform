-- ============================================================
-- 014_database_security_functions.sql
--
-- Database Security Enforcement Layer
--
-- Purpose:
--   Centralize authorization decisions inside PostgreSQL.
--
-- Design:
--   Application does not directly manipulate tables.
--   Approved functions become the security boundary.
--
-- ============================================================


CREATE EXTENSION IF NOT EXISTS pgcrypto;


-- ============================================================
-- Security Context
--
-- Stores the identity PostgreSQL sees for this session.
--
-- Populated by trusted authentication layer.
--
-- ============================================================


CREATE TABLE security_session_context (

    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    database_user TEXT NOT NULL,

    platform_user_id UUID
        REFERENCES users(user_id),

    device_id UUID,

    user_certificate_hash TEXT,

    machine_certificate_hash TEXT,

    session_expires TIMESTAMPTZ NOT NULL,

    created_at TIMESTAMPTZ DEFAULT now()

);



REVOKE ALL
ON security_session_context
FROM PUBLIC;



-- ============================================================
-- Check active security session
-- ============================================================


CREATE OR REPLACE FUNCTION security_validate_session()

RETURNS BOOLEAN

LANGUAGE plpgsql

SECURITY DEFINER

AS $$

DECLARE

    valid_session BOOLEAN;


BEGIN


SELECT EXISTS

(

    SELECT 1

    FROM security_session_context

    WHERE database_user = CURRENT_USER

    AND session_expires > now()

)

INTO valid_session;



RETURN valid_session;


END;

$$;



-- ============================================================
-- Validate current operational authority
--
-- Prevents:
--   user has role but no active assignment
-- ============================================================


CREATE OR REPLACE FUNCTION security_check_role(

    required_role platform_role

)

RETURNS BOOLEAN

LANGUAGE plpgsql

SECURITY DEFINER


AS $$


BEGIN


RETURN EXISTS

(

SELECT 1

FROM users u

JOIN privilege_authorization_ledger pal

ON pal.target_user_id = u.user_id


WHERE u.username = CURRENT_USER

AND pal.requested_role = required_role

AND pal.status = 'ACTIVATED'

);



END;

$$;



-- ============================================================
-- Verify active shift
-- ============================================================


CREATE OR REPLACE FUNCTION security_check_shift()

RETURNS BOOLEAN

LANGUAGE plpgsql

SECURITY DEFINER


AS $$


BEGIN


RETURN EXISTS

(

SELECT 1

FROM shift_roster sr


JOIN shift_activations sa

ON sa.shift_id = sr.shift_id


JOIN users u

ON u.user_id = sr.user_id



WHERE u.username = CURRENT_USER

AND now()
BETWEEN sr.scheduled_start
AND sr.scheduled_end


AND sa.is_active = TRUE


AND now()
<
sa.expires_at

);


END;

$$;



-- ============================================================
-- Verify trusted hardware
--
-- Used for:
--   SYS_ADMIN
--   HR
--   Department heads
--
-- ============================================================


CREATE OR REPLACE FUNCTION security_check_device(

target_role platform_role,

machine_cert TEXT

)

RETURNS BOOLEAN

LANGUAGE plpgsql

SECURITY DEFINER


AS $$



BEGIN


RETURN EXISTS

(

SELECT 1

FROM administrative_hardware_gates hg

JOIN users u

ON u.user_id = hg.user_id


WHERE u.username = CURRENT_USER

AND hg.enforced_role = target_role

AND hg.allowed_machine_cert_cn = machine_cert

AND hg.is_active = TRUE

);



END;

$$;



-- ============================================================
-- Authorization gate
--
-- This becomes the master security decision point.
--
-- ============================================================


CREATE OR REPLACE FUNCTION security_authorize_action(

required_role platform_role,

machine_cert TEXT DEFAULT NULL

)

RETURNS BOOLEAN

LANGUAGE plpgsql

SECURITY DEFINER


AS $$


BEGIN


-- Session must exist

IF NOT security_validate_session()

THEN

RETURN FALSE;

END IF;



-- Administrative users require hardware validation

IF required_role IN

(

'SYS_ADMIN',

'HR_AUDITOR',

'DEPT_HEAD_RO'

)

THEN


RETURN security_check_device(

required_role,

machine_cert

);


END IF;



-- Operational users require shift approval

IF required_role IN

(

'DISPATCHER',

'PATROL_OFFICER',

'SHIFT_SUPERVISOR'

)

THEN


RETURN security_check_shift();


END IF;



RETURN FALSE;


END;

$$;



-- ============================================================
-- Secure audit writer
--
-- Every privileged action goes through here.
--
-- ============================================================


CREATE OR REPLACE FUNCTION security_write_audit(

event_name TEXT,

event_action TEXT,

payload JSONB

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



INSERT INTO cryptographic_audit_chain

(

actor_user_id,

event_type,

event_category,

action,

event_payload

)

VALUES

(

current_user_id,

event_name,

'SECURITY',

event_action,

payload

);



END;


$$;



-- ============================================================
-- Example protected operation
--
-- Instead of:
--
-- INSERT INTO calls (...)
--
-- Application does:
--
-- SELECT cad_create_call(...)
--
-- ============================================================


CREATE OR REPLACE FUNCTION security_test_permission()

RETURNS TEXT

LANGUAGE plpgsql

SECURITY DEFINER


AS $$


BEGIN


IF security_validate_session()

THEN

PERFORM security_write_audit(

'SECURITY_CHECK',

'ACCESS_GRANTED',

jsonb_build_object(

'user',
CURRENT_USER

)

);


RETURN 'AUTHORIZED';



ELSE



PERFORM security_write_audit(

'SECURITY_CHECK',

'ACCESS_DENIED',

jsonb_build_object(

'user',
CURRENT_USER

)

);



RETURN 'DENIED';


END IF;


END;

$$;



-- ============================================================
-- Lock down functions
-- ============================================================


REVOKE ALL
ON FUNCTION security_validate_session()
FROM PUBLIC;


REVOKE ALL
ON FUNCTION security_authorize_action(platform_role,text)
FROM PUBLIC;



-- Application receives EXECUTE only

GRANT EXECUTE
ON FUNCTION security_authorize_action(platform_role,text)
TO cad_application;



GRANT EXECUTE
ON FUNCTION security_write_audit(text,text,jsonb)
TO audit_writer;



-- ============================================================
-- Final rule:
--
-- The application does NOT receive:
--
-- SELECT * FROM users
-- UPDATE calls
-- DELETE audit
--
-- It receives:
--
-- EXECUTE approved_security_function()
--
-- ============================================================