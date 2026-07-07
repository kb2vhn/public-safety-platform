-- ============================================================
-- 011_row_level_security.sql
--
-- PostgreSQL Row Level Security Enforcement
--
-- Purpose:
--   Ensure users can only access records they are authorized
--   to access based on identity, agency, role, and session.
--
-- ============================================================


BEGIN;


-- ============================================================
-- 1. CREATE SECURITY CONTEXT HELPERS
--
-- These functions read the authenticated database session.
--
-- The Go API must set these values after mTLS validation.
--
-- Example:
--
-- SET app.user_id = 'uuid';
-- SET app.agency_id = 'uuid';
-- SET app.role = 'DISPATCHER';
--
-- ============================================================


CREATE OR REPLACE FUNCTION current_app_user()
RETURNS UUID
LANGUAGE sql
STABLE
AS $$
    SELECT current_setting('app.user_id', true)::uuid;
$$;



CREATE OR REPLACE FUNCTION current_app_agency()
RETURNS UUID
LANGUAGE sql
STABLE
AS $$
    SELECT current_setting('app.agency_id', true)::uuid;
$$;



CREATE OR REPLACE FUNCTION current_app_role()
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
    SELECT current_setting('app.role', true);
$$;



-- ============================================================
-- 2. AGENCIES
-- ============================================================

ALTER TABLE agencies
ENABLE ROW LEVEL SECURITY;


CREATE POLICY agency_isolation_policy
ON agencies
FOR SELECT
USING
(
    agency_id = current_app_agency()
    OR
    current_app_role() = 'SYS_ADMIN'
);



-- ============================================================
-- 3. USERS
--
-- Users should only see personnel belonging to their agency.
--
-- ============================================================


ALTER TABLE users
ENABLE ROW LEVEL SECURITY;


CREATE POLICY users_agency_policy
ON users
FOR SELECT
USING
(
    agency_id = current_app_agency()
    OR
    current_app_role() = 'SYS_ADMIN'
);



-- Prevent normal users from changing identity records.

CREATE POLICY users_update_policy
ON users
FOR UPDATE
USING
(
    current_app_role() = 'SYS_ADMIN'
);



-- ============================================================
-- 4. PRIVILEGE AUTHORIZATION LEDGER
--
-- No user can view or modify privilege requests outside
-- their authorized function.
--
-- ============================================================


ALTER TABLE privilege_authorization_ledger
ENABLE ROW LEVEL SECURITY;


CREATE POLICY privilege_request_visibility
ON privilege_authorization_ledger
FOR SELECT
USING
(
    target_user_id = current_app_user()

    OR

    current_app_role()
    IN
    (
        'SYS_ADMIN',
        'HR_AUDITOR'
    )
);



CREATE POLICY privilege_request_insert
ON privilege_authorization_ledger
FOR INSERT
WITH CHECK
(
    current_app_role()
    =
    'SYS_ADMIN'
);



-- No updates after approval.
-- Future changes require a new ledger entry.


CREATE POLICY privilege_request_no_modify
ON privilege_authorization_ledger
FOR UPDATE
USING
(
    false
);



-- ============================================================
-- 5. SHIFT ROSTER
--
-- Users can see their own schedule.
-- Supervisors can see assigned personnel.
--
-- ============================================================


ALTER TABLE shift_roster
ENABLE ROW LEVEL SECURITY;



CREATE POLICY shift_visibility
ON shift_roster
FOR SELECT
USING
(
    user_id = current_app_user()

    OR

    current_app_role()
    IN
    (
        'SHIFT_SUPERVISOR',
        'DEPT_HEAD_RO',
        'SYS_ADMIN'
    )
);



CREATE POLICY shift_management
ON shift_roster
FOR INSERT
WITH CHECK
(
    current_app_role()
    IN
    (
        'SHIFT_SUPERVISOR',
        'SYS_ADMIN'
    )
);



-- ============================================================
-- 6. SHIFT ACTIVATIONS
--
-- A supervisor activates.
-- The employee cannot self activate.
--
-- ============================================================


ALTER TABLE shift_activations
ENABLE ROW LEVEL SECURITY;



CREATE POLICY shift_activation_visibility
ON shift_activations
FOR SELECT
USING
(
    supervisor_approver_id = current_app_user()

    OR

    current_app_role()
    IN
    (
        'SYS_ADMIN'
    )
);



CREATE POLICY shift_activation_insert
ON shift_activations
FOR INSERT
WITH CHECK
(
    current_app_role()
    =
    'SHIFT_SUPERVISOR'
);



-- ============================================================
-- 7. DEVICE TRUST
--
-- A user cannot register their own trusted device.
--
-- ============================================================


ALTER TABLE administrative_hardware_gates
ENABLE ROW LEVEL SECURITY;


CREATE POLICY hardware_gate_visibility
ON administrative_hardware_gates
FOR SELECT
USING
(
    user_id = current_app_user()

    OR

    current_app_role()
    =
    'SYS_ADMIN'
);



CREATE POLICY hardware_gate_admin_only
ON administrative_hardware_gates
FOR INSERT
WITH CHECK
(
    current_app_role()
    =
    'SYS_ADMIN'
);



-- ============================================================
-- 8. FORCE RLS EVEN FOR TABLE OWNERS
--
-- Important:
-- Prevents accidental bypass by privileged service accounts.
--
-- ============================================================


ALTER TABLE users FORCE ROW LEVEL SECURITY;

ALTER TABLE agencies FORCE ROW LEVEL SECURITY;

ALTER TABLE privilege_authorization_ledger
FORCE ROW LEVEL SECURITY;

ALTER TABLE shift_roster
FORCE ROW LEVEL SECURITY;

ALTER TABLE shift_activations
FORCE ROW LEVEL SECURITY;

ALTER TABLE administrative_hardware_gates
FORCE ROW LEVEL SECURITY;



COMMIT;