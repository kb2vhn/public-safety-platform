-- ============================================================================
-- Migration: 940_break_glass_and_credential_lifecycle.sql
-- Title: Disabled-at-Rest Break-Glass and Credential Lifecycle Controls
-- Layer: Deployment and Bootstrap
-- Status: PHASE 5 STEP 6 CANDIDATE
-- Target: PostgreSQL 18
-- ============================================================================
--
-- Purpose:
-- Implement attributable, time-bounded emergency database access while keeping
-- issp_break_glass disabled, credentialless, and without memberships at rest.
-- Record external credential/certificate lifecycle evidence without storing
-- credentials, private keys, tokens, or passwords in the database or repository.
--
-- Security boundary:
-- - activation requires a PostgreSQL superuser using a controlled bootstrap path;
-- - two independent approvers and a separate activation operator are required;
-- - activation grants only temporary SET-capable owner-role memberships;
-- - the role receives LOGIN, CONNECT, CONNECTION LIMIT 1, and VALID UNTIL only
--   for the declared emergency window;
-- - activation accepts only an externally generated SCRAM-SHA-256 verifier;
-- - VALID UNTIL therefore enforces the password-authentication expiration;
-- - the verifier is never written to evidence tables and is cleared on closure;
-- - deactivation and expiration terminate sessions, revoke CONNECT and all
--   emergency memberships, clear password state, and return the role to NOLOGIN;
-- - every request, activation, use record, deactivation, expiration, and
--   credential lifecycle transition produces append-only evidence and an
--   off-host-export-required evidence record;
-- - no runtime, service, review, migration, or ordinary administrator role is
--   granted execution of the emergency-control routines.
--
-- Required psql variables supplied by apply_deployment.sh:
-- - deployment_migration_checksum
-- - deployment_migration_relative_path
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '1min';
SET LOCAL idle_in_transaction_session_timeout = '1min';

SELECT pg_advisory_xact_lock(
    hashtext(current_database()),
    hashtext('iron-signal-platform-deployment-migrations')
);

-- ============================================================================
-- Dependency and execution-authority validation
-- ============================================================================

DO $deployment_dependency_check$
DECLARE
    v_foundation_migration_count bigint;
    v_step5_migration_count bigint;
    v_missing_roles text;
    v_break_glass_memberships bigint;
BEGIN
    IF current_setting('server_version_num')::integer < 180000 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'feature_not_supported',
            MESSAGE = 'Iron Signal Platform deployment migrations require PostgreSQL 18 or newer';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles AS role_record
        WHERE role_record.rolname = current_user
          AND role_record.rolsuper
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'insufficient_privilege',
            MESSAGE = 'Phase 5 Step 6 requires a PostgreSQL superuser',
            DETAIL = format('Connected role=%I.', current_user),
            HINT = 'Use the separately governed deployment bootstrap identity.';
    END IF;

    SELECT count(*)
    INTO v_foundation_migration_count
    FROM foundation_meta.applied_migrations;

    IF v_foundation_migration_count <> 34 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'object_not_in_prerequisite_state',
            MESSAGE = 'The accepted 34-migration Platform Foundation is required',
            DETAIL = format('Registered Foundation migrations=%s.', v_foundation_migration_count);
    END IF;

    SELECT count(*)
    INTO v_step5_migration_count
    FROM deployment_meta.applied_deployment_migrations
    WHERE migration_id = '930_investigator_audit_and_validation_review_surfaces';

    IF v_step5_migration_count <> 1 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'object_not_in_prerequisite_state',
            MESSAGE = 'Phase 5 Step 5 must be registered exactly once';
    END IF;

    SELECT string_agg(required_role.role_name, ', ' ORDER BY required_role.role_name)
    INTO v_missing_roles
    FROM (
        VALUES
            ('issp_database_owner'::name),
            ('issp_foundation_owner'::name),
            ('issp_extension_owner'::name),
            ('issp_migration_executor'::name),
            ('issp_break_glass'::name),
            ('issp_service_authorization'::name),
            ('issp_service_integration_delivery'::name),
            ('issp_service_monitoring_delivery'::name),
            ('issp_audit_reader'::name),
            ('issp_validation_reader'::name)
    ) AS required_role(role_name)
    LEFT JOIN pg_roles AS actual_role
      ON actual_role.rolname = required_role.role_name
    WHERE actual_role.rolname IS NULL;

    IF v_missing_roles IS NOT NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = 'object_not_in_prerequisite_state',
            MESSAGE = 'One or more required Phase 5 roles are missing',
            DETAIL = v_missing_roles;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_roles AS role_record
        WHERE role_record.rolname = 'issp_break_glass'
          AND (
              role_record.rolcanlogin
              OR role_record.rolsuper
              OR role_record.rolcreatedb
              OR role_record.rolcreaterole
              OR role_record.rolreplication
              OR role_record.rolbypassrls
          )
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'object_not_in_prerequisite_state',
            MESSAGE = 'issp_break_glass is not disabled and unprivileged at Step 6 entry';
    END IF;

    SELECT count(*)
    INTO v_break_glass_memberships
    FROM pg_auth_members AS membership_record
    JOIN pg_roles AS member_role
      ON member_role.oid = membership_record.member
    WHERE member_role.rolname = 'issp_break_glass';

    IF v_break_glass_memberships <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'object_not_in_prerequisite_state',
            MESSAGE = 'issp_break_glass has standing memberships before Step 6',
            DETAIL = format('membership_count=%s', v_break_glass_memberships);
    END IF;
END;
$deployment_dependency_check$;

-- ============================================================================
-- Emergency-control schema and lifecycle evidence tables
-- ============================================================================

CREATE SCHEMA emergency_control AUTHORIZATION issp_database_owner;
REVOKE ALL PRIVILEGES ON SCHEMA emergency_control FROM PUBLIC;

CREATE TABLE deployment_meta.credential_lifecycle_policy (
    role_name name PRIMARY KEY,
    credential_class text NOT NULL,
    maximum_lifetime interval NOT NULL,
    rotation_after_use boolean NOT NULL,
    external_secret_only boolean NOT NULL DEFAULT true,
    shared_credential_prohibited boolean NOT NULL DEFAULT true,
    repository_storage_prohibited boolean NOT NULL DEFAULT true,
    disable_when_unused boolean NOT NULL,
    introduced_by_migration_id text NOT NULL,
    CONSTRAINT credential_lifecycle_policy_class_ck CHECK (
        credential_class IN (
            'DEPLOYMENT',
            'SERVICE',
            'BREAK_GLASS_SCRAM'
        )
    ),
    CONSTRAINT credential_lifecycle_policy_lifetime_ck CHECK (
        maximum_lifetime > interval '0 seconds'
    ),
    CONSTRAINT credential_lifecycle_policy_external_ck CHECK (
        external_secret_only
        AND shared_credential_prohibited
        AND repository_storage_prohibited
    )
);

ALTER TABLE deployment_meta.credential_lifecycle_policy
    OWNER TO issp_database_owner;

INSERT INTO deployment_meta.credential_lifecycle_policy (
    role_name,
    credential_class,
    maximum_lifetime,
    rotation_after_use,
    external_secret_only,
    shared_credential_prohibited,
    repository_storage_prohibited,
    disable_when_unused,
    introduced_by_migration_id
)
VALUES
    (
        'issp_migration_executor',
        'DEPLOYMENT',
        interval '24 hours',
        true,
        true,
        true,
        true,
        true,
        '940_break_glass_and_credential_lifecycle'
    ),
    (
        'issp_service_authorization',
        'SERVICE',
        interval '90 days',
        false,
        true,
        true,
        true,
        false,
        '940_break_glass_and_credential_lifecycle'
    ),
    (
        'issp_service_integration_delivery',
        'SERVICE',
        interval '90 days',
        false,
        true,
        true,
        true,
        false,
        '940_break_glass_and_credential_lifecycle'
    ),
    (
        'issp_service_monitoring_delivery',
        'SERVICE',
        interval '90 days',
        false,
        true,
        true,
        true,
        false,
        '940_break_glass_and_credential_lifecycle'
    ),
    (
        'issp_break_glass',
        'BREAK_GLASS_SCRAM',
        interval '1 hour',
        true,
        true,
        true,
        true,
        true,
        '940_break_glass_and_credential_lifecycle'
    );

CREATE TABLE deployment_meta.credential_lifecycle_events (
    credential_event_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role_name name NOT NULL,
    event_type text NOT NULL,
    actor_identity text NOT NULL,
    external_credential_reference text NOT NULL,
    credential_fingerprint text NOT NULL,
    effective_at timestamptz NOT NULL,
    expires_at timestamptz,
    reason text NOT NULL,
    recorded_by name NOT NULL DEFAULT session_user,
    recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT credential_lifecycle_events_role_fk FOREIGN KEY (role_name)
        REFERENCES deployment_meta.credential_lifecycle_policy(role_name),
    CONSTRAINT credential_lifecycle_events_type_ck CHECK (
        event_type IN (
            'STAGED',
            'ACTIVATED',
            'ROTATED',
            'REVOKED',
            'DISABLED',
            'ROTATION_REQUIRED'
        )
    ),
    CONSTRAINT credential_lifecycle_events_actor_ck CHECK (
        btrim(actor_identity) <> ''
    ),
    CONSTRAINT credential_lifecycle_events_reference_ck CHECK (
        btrim(external_credential_reference) <> ''
        AND length(external_credential_reference) <= 512
    ),
    CONSTRAINT credential_lifecycle_events_fingerprint_ck CHECK (
        credential_fingerprint ~ '^[0-9a-f]{64}$'
    ),
    CONSTRAINT credential_lifecycle_events_reason_ck CHECK (
        btrim(reason) <> ''
    ),
    CONSTRAINT credential_lifecycle_events_expiry_ck CHECK (
        expires_at IS NULL OR expires_at > effective_at
    )
);

ALTER TABLE deployment_meta.credential_lifecycle_events
    OWNER TO issp_database_owner;

CREATE INDEX credential_lifecycle_events_role_time_idx
    ON deployment_meta.credential_lifecycle_events (
        role_name,
        effective_at DESC,
        credential_event_id DESC
    );

CREATE TABLE deployment_meta.break_glass_requests (
    break_glass_request_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    incident_reference text NOT NULL,
    reason text NOT NULL,
    requested_by text NOT NULL,
    approver_one text NOT NULL,
    approver_two text NOT NULL,
    requested_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    activate_before timestamptz NOT NULL,
    expires_at timestamptz NOT NULL,
    requested_duration interval NOT NULL,
    external_credential_reference text NOT NULL,
    credential_fingerprint text NOT NULL,
    created_by name NOT NULL DEFAULT session_user,
    CONSTRAINT break_glass_requests_incident_ck CHECK (
        btrim(incident_reference) <> ''
    ),
    CONSTRAINT break_glass_requests_reason_ck CHECK (
        btrim(reason) <> ''
    ),
    CONSTRAINT break_glass_requests_actor_ck CHECK (
        btrim(requested_by) <> ''
        AND btrim(approver_one) <> ''
        AND btrim(approver_two) <> ''
        AND requested_by <> approver_one
        AND requested_by <> approver_two
        AND approver_one <> approver_two
    ),
    CONSTRAINT break_glass_requests_window_ck CHECK (
        activate_before > requested_at
        AND expires_at > requested_at
        AND requested_duration > interval '0 seconds'
        AND expires_at = requested_at + requested_duration
    ),
    CONSTRAINT break_glass_requests_reference_ck CHECK (
        btrim(external_credential_reference) <> ''
        AND length(external_credential_reference) <= 512
    ),
    CONSTRAINT break_glass_requests_fingerprint_ck CHECK (
        credential_fingerprint ~ '^[0-9a-f]{64}$'
    )
);

ALTER TABLE deployment_meta.break_glass_requests
    OWNER TO issp_database_owner;

CREATE TABLE deployment_meta.break_glass_events (
    break_glass_event_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    break_glass_request_id bigint NOT NULL,
    event_type text NOT NULL,
    actor_identity text NOT NULL,
    event_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    effective_until timestamptz,
    action_summary text,
    target_reference text,
    recorded_by name NOT NULL DEFAULT session_user,
    application_name text NOT NULL DEFAULT coalesce(current_setting('application_name', true), ''),
    client_address inet DEFAULT inet_client_addr(),
    CONSTRAINT break_glass_events_request_fk FOREIGN KEY (break_glass_request_id)
        REFERENCES deployment_meta.break_glass_requests(break_glass_request_id),
    CONSTRAINT break_glass_events_type_ck CHECK (
        event_type IN (
            'REQUESTED',
            'ACTIVATED',
            'USE_RECORDED',
            'DEACTIVATED',
            'EXPIRED'
        )
    ),
    CONSTRAINT break_glass_events_actor_ck CHECK (
        btrim(actor_identity) <> ''
    ),
    CONSTRAINT break_glass_events_action_ck CHECK (
        event_type <> 'USE_RECORDED'
        OR (
            action_summary IS NOT NULL
            AND btrim(action_summary) <> ''
            AND target_reference IS NOT NULL
            AND btrim(target_reference) <> ''
        )
    )
);

ALTER TABLE deployment_meta.break_glass_events
    OWNER TO issp_database_owner;

CREATE INDEX break_glass_events_request_time_idx
    ON deployment_meta.break_glass_events (
        break_glass_request_id,
        event_at DESC,
        break_glass_event_id DESC
    );

CREATE TABLE deployment_meta.break_glass_evidence_outbox (
    evidence_record_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    break_glass_event_id bigint NOT NULL UNIQUE,
    break_glass_request_id bigint NOT NULL,
    evidence_type text NOT NULL,
    evidence_payload jsonb NOT NULL,
    off_host_export_required boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT break_glass_evidence_event_fk FOREIGN KEY (break_glass_event_id)
        REFERENCES deployment_meta.break_glass_events(break_glass_event_id),
    CONSTRAINT break_glass_evidence_request_fk FOREIGN KEY (break_glass_request_id)
        REFERENCES deployment_meta.break_glass_requests(break_glass_request_id),
    CONSTRAINT break_glass_evidence_type_ck CHECK (
        evidence_type IN (
            'REQUESTED',
            'ACTIVATED',
            'USE_RECORDED',
            'DEACTIVATED',
            'EXPIRED'
        )
    ),
    CONSTRAINT break_glass_evidence_export_ck CHECK (
        off_host_export_required
    )
);

ALTER TABLE deployment_meta.break_glass_evidence_outbox
    OWNER TO issp_database_owner;

-- ============================================================================
-- Append-only evidence enforcement
-- ============================================================================

CREATE FUNCTION emergency_control.reject_emergency_evidence_mutation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $function$
BEGIN
    RAISE EXCEPTION USING
        ERRCODE = 'insufficient_privilege',
        MESSAGE = 'Emergency-control evidence is append-only',
        DETAIL = format('relation=%I.%I operation=%s', TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP);
END;
$function$;

ALTER FUNCTION emergency_control.reject_emergency_evidence_mutation()
    OWNER TO issp_database_owner;
REVOKE ALL PRIVILEGES ON FUNCTION emergency_control.reject_emergency_evidence_mutation()
    FROM PUBLIC;

CREATE TRIGGER break_glass_requests_append_only
BEFORE UPDATE OR DELETE ON deployment_meta.break_glass_requests
FOR EACH STATEMENT
EXECUTE FUNCTION emergency_control.reject_emergency_evidence_mutation();

CREATE TRIGGER break_glass_events_append_only
BEFORE UPDATE OR DELETE ON deployment_meta.break_glass_events
FOR EACH STATEMENT
EXECUTE FUNCTION emergency_control.reject_emergency_evidence_mutation();

CREATE TRIGGER break_glass_evidence_outbox_append_only
BEFORE UPDATE OR DELETE ON deployment_meta.break_glass_evidence_outbox
FOR EACH STATEMENT
EXECUTE FUNCTION emergency_control.reject_emergency_evidence_mutation();

CREATE TRIGGER credential_lifecycle_events_append_only
BEFORE UPDATE OR DELETE ON deployment_meta.credential_lifecycle_events
FOR EACH STATEMENT
EXECUTE FUNCTION emergency_control.reject_emergency_evidence_mutation();

-- ============================================================================
-- Private evidence helpers
-- ============================================================================

CREATE FUNCTION emergency_control.append_break_glass_event(
    p_break_glass_request_id bigint,
    p_event_type text,
    p_actor_identity text,
    p_effective_until timestamptz,
    p_action_summary text,
    p_target_reference text
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog
AS $function$
DECLARE
    v_event_id bigint;
    v_request deployment_meta.break_glass_requests%ROWTYPE;
BEGIN
    SELECT *
    INTO STRICT v_request
    FROM deployment_meta.break_glass_requests AS request_record
    WHERE request_record.break_glass_request_id = p_break_glass_request_id;

    INSERT INTO deployment_meta.break_glass_events (
        break_glass_request_id,
        event_type,
        actor_identity,
        effective_until,
        action_summary,
        target_reference
    )
    VALUES (
        p_break_glass_request_id,
        p_event_type,
        p_actor_identity,
        p_effective_until,
        p_action_summary,
        p_target_reference
    )
    RETURNING break_glass_event_id
    INTO v_event_id;

    INSERT INTO deployment_meta.break_glass_evidence_outbox (
        break_glass_event_id,
        break_glass_request_id,
        evidence_type,
        evidence_payload
    )
    VALUES (
        v_event_id,
        p_break_glass_request_id,
        p_event_type,
        jsonb_build_object(
            'request_id', p_break_glass_request_id,
            'incident_reference', v_request.incident_reference,
            'event_type', p_event_type,
            'actor_identity', p_actor_identity,
            'effective_until', p_effective_until,
            'action_summary', p_action_summary,
            'target_reference', p_target_reference,
            'credential_reference', v_request.external_credential_reference,
            'credential_fingerprint', v_request.credential_fingerprint,
            'recorded_at', clock_timestamp(),
            'database_name', current_database(),
            'session_user', session_user,
            'current_user', current_user
        )
    );

    RETURN v_event_id;
END;
$function$;

ALTER FUNCTION emergency_control.append_break_glass_event(
    bigint,
    text,
    text,
    timestamptz,
    text,
    text
) OWNER TO issp_database_owner;
REVOKE ALL PRIVILEGES ON FUNCTION emergency_control.append_break_glass_event(
    bigint,
    text,
    text,
    timestamptz,
    text,
    text
) FROM PUBLIC;

CREATE FUNCTION emergency_control.record_credential_lifecycle_event(
    p_role_name name,
    p_event_type text,
    p_actor_identity text,
    p_external_credential_reference text,
    p_credential_fingerprint text,
    p_effective_at timestamptz,
    p_expires_at timestamptz,
    p_reason text
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog
AS $function$
DECLARE
    v_event_id bigint;
    v_maximum_lifetime interval;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles AS role_record
        WHERE role_record.rolname = current_user
          AND role_record.rolsuper
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'insufficient_privilege',
            MESSAGE = 'Credential lifecycle evidence requires a PostgreSQL superuser';
    END IF;

    SELECT policy_record.maximum_lifetime
    INTO STRICT v_maximum_lifetime
    FROM deployment_meta.credential_lifecycle_policy AS policy_record
    WHERE policy_record.role_name = p_role_name;

    IF p_expires_at IS NOT NULL
       AND p_expires_at > p_effective_at + v_maximum_lifetime THEN
        RAISE EXCEPTION USING
            ERRCODE = 'check_violation',
            MESSAGE = 'Credential lifetime exceeds the accepted role policy',
            DETAIL = format('role=%I maximum_lifetime=%s', p_role_name, v_maximum_lifetime);
    END IF;

    INSERT INTO deployment_meta.credential_lifecycle_events (
        role_name,
        event_type,
        actor_identity,
        external_credential_reference,
        credential_fingerprint,
        effective_at,
        expires_at,
        reason
    )
    VALUES (
        p_role_name,
        p_event_type,
        p_actor_identity,
        p_external_credential_reference,
        p_credential_fingerprint,
        p_effective_at,
        p_expires_at,
        p_reason
    )
    RETURNING credential_event_id
    INTO v_event_id;

    RETURN v_event_id;
END;
$function$;

ALTER FUNCTION emergency_control.record_credential_lifecycle_event(
    name,
    text,
    text,
    text,
    text,
    timestamptz,
    timestamptz,
    text
) OWNER TO issp_database_owner;
REVOKE ALL PRIVILEGES ON FUNCTION emergency_control.record_credential_lifecycle_event(
    name,
    text,
    text,
    text,
    text,
    timestamptz,
    timestamptz,
    text
) FROM PUBLIC;

-- ============================================================================
-- Controlled request, activation, use, and deactivation routines
-- ============================================================================

CREATE FUNCTION emergency_control.prepare_break_glass_activation(
    p_incident_reference text,
    p_reason text,
    p_requested_by text,
    p_approver_one text,
    p_approver_two text,
    p_external_credential_reference text,
    p_credential_fingerprint text,
    p_requested_duration interval
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog
AS $function$
DECLARE
    v_request_id bigint;
    v_requested_at timestamptz := clock_timestamp();
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles AS role_record
        WHERE role_record.rolname = current_user
          AND role_record.rolsuper
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'insufficient_privilege',
            MESSAGE = 'Break-glass preparation requires a PostgreSQL superuser';
    END IF;

    PERFORM pg_advisory_xact_lock(
        hashtext(current_database()),
        hashtext('issp-break-glass-lifecycle')
    );

    IF p_requested_duration < interval '5 minutes'
       OR p_requested_duration > interval '1 hour' THEN
        RAISE EXCEPTION USING
            ERRCODE = 'check_violation',
            MESSAGE = 'Break-glass duration must be between 5 minutes and 1 hour';
    END IF;

    IF btrim(p_requested_by) = ''
       OR btrim(p_approver_one) = ''
       OR btrim(p_approver_two) = ''
       OR p_requested_by = p_approver_one
       OR p_requested_by = p_approver_two
       OR p_approver_one = p_approver_two THEN
        RAISE EXCEPTION USING
            ERRCODE = 'check_violation',
            MESSAGE = 'Break-glass requires a requester and two distinct independent approvers';
    END IF;

    IF p_credential_fingerprint !~ '^[0-9a-f]{64}$' THEN
        RAISE EXCEPTION USING
            ERRCODE = 'check_violation',
            MESSAGE = 'Credential fingerprint must be a lowercase SHA-256 value';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM deployment_meta.break_glass_requests AS request_record
        JOIN LATERAL (
            SELECT event_record.event_type
            FROM deployment_meta.break_glass_events AS event_record
            WHERE event_record.break_glass_request_id = request_record.break_glass_request_id
            ORDER BY event_record.event_at DESC, event_record.break_glass_event_id DESC
            LIMIT 1
        ) AS latest_event ON true
        WHERE latest_event.event_type IN ('REQUESTED', 'ACTIVATED')
          AND request_record.expires_at > v_requested_at
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'object_not_in_prerequisite_state',
            MESSAGE = 'Another break-glass request is pending or active';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM deployment_meta.break_glass_requests AS request_record
        JOIN deployment_meta.break_glass_events AS event_record
          ON event_record.break_glass_request_id = request_record.break_glass_request_id
        WHERE request_record.credential_fingerprint = p_credential_fingerprint
          AND event_record.event_type = 'ACTIVATED'
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'unique_violation',
            MESSAGE = 'A previously activated break-glass credential fingerprint cannot be reused';
    END IF;

    INSERT INTO deployment_meta.break_glass_requests (
        incident_reference,
        reason,
        requested_by,
        approver_one,
        approver_two,
        requested_at,
        activate_before,
        expires_at,
        requested_duration,
        external_credential_reference,
        credential_fingerprint
    )
    VALUES (
        p_incident_reference,
        p_reason,
        p_requested_by,
        p_approver_one,
        p_approver_two,
        v_requested_at,
        v_requested_at + interval '15 minutes',
        v_requested_at + p_requested_duration,
        p_requested_duration,
        p_external_credential_reference,
        p_credential_fingerprint
    )
    RETURNING break_glass_request_id
    INTO v_request_id;

    PERFORM emergency_control.append_break_glass_event(
        v_request_id,
        'REQUESTED',
        p_requested_by,
        v_requested_at + p_requested_duration,
        NULL,
        p_incident_reference
    );

    PERFORM emergency_control.record_credential_lifecycle_event(
        'issp_break_glass',
        'STAGED',
        p_requested_by,
        p_external_credential_reference,
        p_credential_fingerprint,
        v_requested_at,
        v_requested_at + p_requested_duration,
        'Credential or certificate staged for an approved break-glass request.'
    );

    RETURN v_request_id;
END;
$function$;

ALTER FUNCTION emergency_control.prepare_break_glass_activation(
    text,
    text,
    text,
    text,
    text,
    text,
    text,
    interval
) OWNER TO issp_database_owner;
REVOKE ALL PRIVILEGES ON FUNCTION emergency_control.prepare_break_glass_activation(
    text,
    text,
    text,
    text,
    text,
    text,
    text,
    interval
) FROM PUBLIC;

CREATE FUNCTION emergency_control.activate_break_glass(
    p_break_glass_request_id bigint,
    p_operator_identity text,
    p_scram_verifier text
)
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog
AS $function$
DECLARE
    v_request deployment_meta.break_glass_requests%ROWTYPE;
    v_latest_event_type text;
    v_owner_role name;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles AS role_record
        WHERE role_record.rolname = current_user
          AND role_record.rolsuper
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'insufficient_privilege',
            MESSAGE = 'Break-glass activation requires a PostgreSQL superuser';
    END IF;

    PERFORM pg_advisory_xact_lock(
        hashtext(current_database()),
        hashtext('issp-break-glass-lifecycle')
    );

    SELECT *
    INTO STRICT v_request
    FROM deployment_meta.break_glass_requests AS request_record
    WHERE request_record.break_glass_request_id = p_break_glass_request_id
    FOR UPDATE;

    SELECT event_record.event_type
    INTO STRICT v_latest_event_type
    FROM deployment_meta.break_glass_events AS event_record
    WHERE event_record.break_glass_request_id = p_break_glass_request_id
    ORDER BY event_record.event_at DESC, event_record.break_glass_event_id DESC
    LIMIT 1;

    IF v_latest_event_type <> 'REQUESTED' THEN
        RAISE EXCEPTION USING
            ERRCODE = 'object_not_in_prerequisite_state',
            MESSAGE = 'Only a requested break-glass event may be activated';
    END IF;

    IF clock_timestamp() > v_request.activate_before
       OR clock_timestamp() >= v_request.expires_at THEN
        RAISE EXCEPTION USING
            ERRCODE = 'object_not_in_prerequisite_state',
            MESSAGE = 'The break-glass activation window has expired';
    END IF;

    IF btrim(p_operator_identity) = ''
       OR p_operator_identity IN (
           v_request.requested_by,
           v_request.approver_one,
           v_request.approver_two
       ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'check_violation',
            MESSAGE = 'The activation operator must be distinct from the requester and approvers';
    END IF;

    IF p_scram_verifier !~ '^SCRAM-SHA-256\$[0-9]+:[A-Za-z0-9+/=]+\$[A-Za-z0-9+/=]+:[A-Za-z0-9+/=]+$' THEN
        RAISE EXCEPTION USING
            ERRCODE = 'check_violation',
            MESSAGE = 'Break-glass activation requires an externally generated SCRAM-SHA-256 verifier';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_roles AS role_record
        WHERE role_record.rolname = 'issp_break_glass'
          AND role_record.rolcanlogin
    ) OR EXISTS (
        SELECT 1
        FROM pg_auth_members AS membership_record
        JOIN pg_roles AS member_role
          ON member_role.oid = membership_record.member
        WHERE member_role.rolname = 'issp_break_glass'
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'object_not_in_prerequisite_state',
            MESSAGE = 'issp_break_glass is not in the required disabled-at-rest posture';
    END IF;

    EXECUTE format(
        'GRANT CONNECT ON DATABASE %I TO issp_break_glass',
        current_database()
    );

    FOREACH v_owner_role IN ARRAY ARRAY[
        'issp_database_owner'::name,
        'issp_foundation_owner'::name,
        'issp_extension_owner'::name
    ]
    LOOP
        EXECUTE format(
            'GRANT %I TO issp_break_glass WITH INHERIT FALSE, SET TRUE, ADMIN FALSE',
            v_owner_role
        );
    END LOOP;

    EXECUTE format(
        'ALTER ROLE issp_break_glass WITH LOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS CONNECTION LIMIT 1 VALID UNTIL %L PASSWORD %L',
        v_request.expires_at,
        p_scram_verifier
    );

    ALTER ROLE issp_break_glass SET lock_timeout = '5s';
    ALTER ROLE issp_break_glass SET statement_timeout = '15min';
    ALTER ROLE issp_break_glass SET idle_in_transaction_session_timeout = '1min';
    ALTER ROLE issp_break_glass SET idle_session_timeout = '5min';

    PERFORM emergency_control.append_break_glass_event(
        p_break_glass_request_id,
        'ACTIVATED',
        p_operator_identity,
        v_request.expires_at,
        'Break-glass role activated through the controlled emergency procedure.',
        v_request.incident_reference
    );

    PERFORM emergency_control.record_credential_lifecycle_event(
        'issp_break_glass',
        'ACTIVATED',
        p_operator_identity,
        v_request.external_credential_reference,
        v_request.credential_fingerprint,
        clock_timestamp(),
        v_request.expires_at,
        'Externally generated SCRAM verifier activated; plaintext secret remains outside PostgreSQL evidence tables.'
    );

    RETURN v_request.expires_at;
END;
$function$;

ALTER FUNCTION emergency_control.activate_break_glass(bigint, text, text)
    OWNER TO issp_database_owner;
REVOKE ALL PRIVILEGES ON FUNCTION emergency_control.activate_break_glass(bigint, text, text)
    FROM PUBLIC;

CREATE FUNCTION emergency_control.record_break_glass_use(
    p_break_glass_request_id bigint,
    p_operator_identity text,
    p_action_summary text,
    p_target_reference text
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog
AS $function$
DECLARE
    v_request deployment_meta.break_glass_requests%ROWTYPE;
    v_latest_event_type text;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles AS role_record
        WHERE role_record.rolname = current_user
          AND role_record.rolsuper
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'insufficient_privilege',
            MESSAGE = 'Break-glass use evidence requires a PostgreSQL superuser';
    END IF;

    PERFORM pg_advisory_xact_lock(
        hashtext(current_database()),
        hashtext('issp-break-glass-lifecycle')
    );

    SELECT *
    INTO STRICT v_request
    FROM deployment_meta.break_glass_requests AS request_record
    WHERE request_record.break_glass_request_id = p_break_glass_request_id;

    SELECT event_record.event_type
    INTO STRICT v_latest_event_type
    FROM deployment_meta.break_glass_events AS event_record
    WHERE event_record.break_glass_request_id = p_break_glass_request_id
    ORDER BY event_record.event_at DESC, event_record.break_glass_event_id DESC
    LIMIT 1;

    IF v_latest_event_type NOT IN ('ACTIVATED', 'USE_RECORDED')
       OR clock_timestamp() >= v_request.expires_at THEN
        RAISE EXCEPTION USING
            ERRCODE = 'object_not_in_prerequisite_state',
            MESSAGE = 'Break-glass use may be recorded only for an active unexpired request';
    END IF;

    RETURN emergency_control.append_break_glass_event(
        p_break_glass_request_id,
        'USE_RECORDED',
        p_operator_identity,
        v_request.expires_at,
        p_action_summary,
        p_target_reference
    );
END;
$function$;

ALTER FUNCTION emergency_control.record_break_glass_use(bigint, text, text, text)
    OWNER TO issp_database_owner;
REVOKE ALL PRIVILEGES ON FUNCTION emergency_control.record_break_glass_use(bigint, text, text, text)
    FROM PUBLIC;

CREATE FUNCTION emergency_control.close_break_glass_request(
    p_break_glass_request_id bigint,
    p_operator_identity text,
    p_event_type text,
    p_outcome text
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog
AS $function$
DECLARE
    v_request deployment_meta.break_glass_requests%ROWTYPE;
    v_latest_event_type text;
    v_owner_role name;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles AS role_record
        WHERE role_record.rolname = current_user
          AND role_record.rolsuper
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'insufficient_privilege',
            MESSAGE = 'Break-glass closure requires a PostgreSQL superuser';
    END IF;

    PERFORM pg_advisory_xact_lock(
        hashtext(current_database()),
        hashtext('issp-break-glass-lifecycle')
    );

    IF p_event_type NOT IN ('DEACTIVATED', 'EXPIRED') THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_parameter_value',
            MESSAGE = 'Break-glass closure event type is invalid';
    END IF;

    SELECT *
    INTO STRICT v_request
    FROM deployment_meta.break_glass_requests AS request_record
    WHERE request_record.break_glass_request_id = p_break_glass_request_id
    FOR UPDATE;

    SELECT event_record.event_type
    INTO STRICT v_latest_event_type
    FROM deployment_meta.break_glass_events AS event_record
    WHERE event_record.break_glass_request_id = p_break_glass_request_id
    ORDER BY event_record.event_at DESC, event_record.break_glass_event_id DESC
    LIMIT 1;

    IF v_latest_event_type NOT IN ('ACTIVATED', 'USE_RECORDED') THEN
        RAISE EXCEPTION USING
            ERRCODE = 'object_not_in_prerequisite_state',
            MESSAGE = 'Only an active break-glass request may be closed';
    END IF;

    PERFORM pg_terminate_backend(activity_record.pid)
    FROM pg_stat_activity AS activity_record
    WHERE activity_record.usename = 'issp_break_glass'
      AND activity_record.pid <> pg_backend_pid();

    EXECUTE format(
        'REVOKE CONNECT ON DATABASE %I FROM issp_break_glass',
        current_database()
    );

    FOREACH v_owner_role IN ARRAY ARRAY[
        'issp_database_owner'::name,
        'issp_foundation_owner'::name,
        'issp_extension_owner'::name
    ]
    LOOP
        EXECUTE format(
            'REVOKE %I FROM issp_break_glass',
            v_owner_role
        );
    END LOOP;

    ALTER ROLE issp_break_glass WITH NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS CONNECTION LIMIT -1 VALID UNTIL 'infinity' PASSWORD NULL;

    PERFORM emergency_control.append_break_glass_event(
        p_break_glass_request_id,
        p_event_type,
        p_operator_identity,
        NULL,
        p_outcome,
        v_request.incident_reference
    );

    PERFORM emergency_control.record_credential_lifecycle_event(
        'issp_break_glass',
        'ROTATION_REQUIRED',
        p_operator_identity,
        v_request.external_credential_reference,
        v_request.credential_fingerprint,
        clock_timestamp(),
        NULL,
        format('Break-glass request %s closed with event %s; external credential rotation is mandatory.', p_break_glass_request_id, p_event_type)
    );
END;
$function$;

ALTER FUNCTION emergency_control.close_break_glass_request(bigint, text, text, text)
    OWNER TO issp_database_owner;
REVOKE ALL PRIVILEGES ON FUNCTION emergency_control.close_break_glass_request(bigint, text, text, text)
    FROM PUBLIC;

CREATE FUNCTION emergency_control.deactivate_break_glass(
    p_break_glass_request_id bigint,
    p_operator_identity text,
    p_outcome text
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog
AS $function$
BEGIN
    PERFORM emergency_control.close_break_glass_request(
        p_break_glass_request_id,
        p_operator_identity,
        'DEACTIVATED',
        p_outcome
    );
END;
$function$;

ALTER FUNCTION emergency_control.deactivate_break_glass(bigint, text, text)
    OWNER TO issp_database_owner;
REVOKE ALL PRIVILEGES ON FUNCTION emergency_control.deactivate_break_glass(bigint, text, text)
    FROM PUBLIC;

CREATE FUNCTION emergency_control.enforce_break_glass_expiration(
    p_operator_identity text,
    p_as_of timestamptz DEFAULT clock_timestamp()
)
RETURNS integer
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog
AS $function$
DECLARE
    v_request_id bigint;
    v_closed_count integer := 0;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles AS role_record
        WHERE role_record.rolname = current_user
          AND role_record.rolsuper
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'insufficient_privilege',
            MESSAGE = 'Break-glass expiration enforcement requires a PostgreSQL superuser';
    END IF;

    PERFORM pg_advisory_xact_lock(
        hashtext(current_database()),
        hashtext('issp-break-glass-lifecycle')
    );

    FOR v_request_id IN
        SELECT request_record.break_glass_request_id
        FROM deployment_meta.break_glass_requests AS request_record
        JOIN LATERAL (
            SELECT event_record.event_type
            FROM deployment_meta.break_glass_events AS event_record
            WHERE event_record.break_glass_request_id = request_record.break_glass_request_id
            ORDER BY event_record.event_at DESC, event_record.break_glass_event_id DESC
            LIMIT 1
        ) AS latest_event ON true
        WHERE latest_event.event_type IN ('ACTIVATED', 'USE_RECORDED')
          AND request_record.expires_at <= p_as_of
        ORDER BY request_record.break_glass_request_id
        FOR UPDATE OF request_record
    LOOP
        PERFORM emergency_control.close_break_glass_request(
            v_request_id,
            p_operator_identity,
            'EXPIRED',
            'Break-glass access reached its declared expiration and was forcibly disabled.'
        );
        v_closed_count := v_closed_count + 1;
    END LOOP;

    RETURN v_closed_count;
END;
$function$;

ALTER FUNCTION emergency_control.enforce_break_glass_expiration(text, timestamptz)
    OWNER TO issp_database_owner;
REVOKE ALL PRIVILEGES ON FUNCTION emergency_control.enforce_break_glass_expiration(text, timestamptz)
    FROM PUBLIC;

-- ============================================================================
-- Review and validation views
-- ============================================================================

CREATE VIEW deployment_meta.audit_break_glass_events
WITH (security_barrier = true)
AS
SELECT
    event_record.break_glass_event_id,
    event_record.break_glass_request_id,
    request_record.incident_reference,
    event_record.event_type,
    event_record.actor_identity,
    event_record.event_at,
    event_record.effective_until,
    event_record.action_summary,
    event_record.target_reference,
    event_record.recorded_by,
    event_record.application_name,
    event_record.client_address
FROM deployment_meta.break_glass_events AS event_record
JOIN deployment_meta.break_glass_requests AS request_record
  ON request_record.break_glass_request_id = event_record.break_glass_request_id;

ALTER VIEW deployment_meta.audit_break_glass_events
    OWNER TO issp_database_owner;

CREATE VIEW deployment_meta.audit_credential_lifecycle_events
WITH (security_barrier = true)
AS
SELECT
    event_record.credential_event_id,
    event_record.role_name,
    event_record.event_type,
    event_record.actor_identity,
    event_record.external_credential_reference,
    event_record.credential_fingerprint,
    event_record.effective_at,
    event_record.expires_at,
    event_record.reason,
    event_record.recorded_by,
    event_record.recorded_at
FROM deployment_meta.credential_lifecycle_events AS event_record;

ALTER VIEW deployment_meta.audit_credential_lifecycle_events
    OWNER TO issp_database_owner;

CREATE VIEW deployment_meta.break_glass_posture
WITH (security_barrier = true)
AS
WITH latest_event AS (
    SELECT DISTINCT ON (event_record.break_glass_request_id)
        event_record.break_glass_request_id,
        event_record.event_type,
        event_record.event_at,
        event_record.effective_until
    FROM deployment_meta.break_glass_events AS event_record
    ORDER BY
        event_record.break_glass_request_id,
        event_record.event_at DESC,
        event_record.break_glass_event_id DESC
)
SELECT
    request_record.break_glass_request_id,
    request_record.incident_reference,
    request_record.requested_by,
    request_record.approver_one,
    request_record.approver_two,
    request_record.requested_at,
    request_record.activate_before,
    request_record.expires_at,
    request_record.external_credential_reference,
    request_record.credential_fingerprint,
    latest_event.event_type AS current_state,
    latest_event.event_at AS last_event_at,
    role_record.rolcanlogin AS role_login_enabled,
    role_record.rolconnlimit AS role_connection_limit,
    role_record.rolvaliduntil AS role_valid_until,
    (
        SELECT count(*)
        FROM pg_auth_members AS membership_record
        WHERE membership_record.member = role_record.oid
    ) AS active_membership_count
FROM deployment_meta.break_glass_requests AS request_record
JOIN latest_event
  ON latest_event.break_glass_request_id = request_record.break_glass_request_id
CROSS JOIN LATERAL (
    SELECT *
    FROM pg_roles AS role_record
    WHERE role_record.rolname = 'issp_break_glass'
) AS role_record;

ALTER VIEW deployment_meta.break_glass_posture
    OWNER TO issp_database_owner;

CREATE VIEW deployment_meta.credential_lifecycle_posture
WITH (security_barrier = true)
AS
WITH latest_event AS (
    SELECT DISTINCT ON (event_record.role_name)
        event_record.role_name,
        event_record.event_type,
        event_record.effective_at,
        event_record.expires_at,
        event_record.external_credential_reference,
        event_record.credential_fingerprint
    FROM deployment_meta.credential_lifecycle_events AS event_record
    ORDER BY
        event_record.role_name,
        event_record.effective_at DESC,
        event_record.credential_event_id DESC
)
SELECT
    policy_record.role_name,
    policy_record.credential_class,
    policy_record.maximum_lifetime,
    policy_record.rotation_after_use,
    policy_record.external_secret_only,
    policy_record.shared_credential_prohibited,
    policy_record.repository_storage_prohibited,
    policy_record.disable_when_unused,
    latest_event.event_type AS latest_event_type,
    latest_event.effective_at AS latest_effective_at,
    latest_event.expires_at AS latest_expires_at,
    latest_event.external_credential_reference,
    latest_event.credential_fingerprint,
    role_record.rolcanlogin,
    role_record.rolconnlimit,
    role_record.rolvaliduntil,
    CASE
        WHEN latest_event.event_type IS NULL THEN 'EVIDENCE_REQUIRED'
        WHEN latest_event.event_type = 'ROTATION_REQUIRED' THEN 'ROTATION_REQUIRED'
        WHEN latest_event.expires_at IS NOT NULL
             AND latest_event.expires_at <= clock_timestamp() THEN 'EXPIRED'
        ELSE 'RECORDED'
    END AS posture_status
FROM deployment_meta.credential_lifecycle_policy AS policy_record
JOIN pg_roles AS role_record
  ON role_record.rolname = policy_record.role_name
LEFT JOIN latest_event
  ON latest_event.role_name = policy_record.role_name;

ALTER VIEW deployment_meta.credential_lifecycle_posture
    OWNER TO issp_database_owner;

CREATE VIEW deployment_meta.break_glass_evidence_posture
WITH (security_barrier = true)
AS
SELECT
    evidence_record.evidence_type,
    count(*) AS evidence_record_count,
    min(evidence_record.created_at) AS oldest_recorded_at,
    max(evidence_record.created_at) AS newest_recorded_at,
    bool_and(evidence_record.off_host_export_required) AS off_host_export_required
FROM deployment_meta.break_glass_evidence_outbox AS evidence_record
GROUP BY evidence_record.evidence_type;

ALTER VIEW deployment_meta.break_glass_evidence_posture
    OWNER TO issp_database_owner;

REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA emergency_control FROM PUBLIC;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA emergency_control FROM PUBLIC;
REVOKE ALL PRIVILEGES ON ALL ROUTINES IN SCHEMA emergency_control FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE
    deployment_meta.credential_lifecycle_policy,
    deployment_meta.credential_lifecycle_events,
    deployment_meta.break_glass_requests,
    deployment_meta.break_glass_events,
    deployment_meta.break_glass_evidence_outbox,
    deployment_meta.audit_break_glass_events,
    deployment_meta.audit_credential_lifecycle_events,
    deployment_meta.break_glass_posture,
    deployment_meta.credential_lifecycle_posture,
    deployment_meta.break_glass_evidence_posture
FROM PUBLIC;

GRANT USAGE ON SCHEMA deployment_meta TO issp_audit_reader;
GRANT SELECT ON TABLE
    deployment_meta.audit_break_glass_events,
    deployment_meta.audit_credential_lifecycle_events
TO issp_audit_reader;

GRANT SELECT ON TABLE
    deployment_meta.break_glass_posture,
    deployment_meta.credential_lifecycle_posture,
    deployment_meta.break_glass_evidence_posture
TO issp_validation_reader;

-- ============================================================================
-- Disabled-at-rest enforcement
-- ============================================================================

DO $disable_break_glass_at_rest$
DECLARE
    v_owner_role name;
BEGIN
    PERFORM pg_terminate_backend(activity_record.pid)
    FROM pg_stat_activity AS activity_record
    WHERE activity_record.usename = 'issp_break_glass'
      AND activity_record.pid <> pg_backend_pid();

    EXECUTE format(
        'REVOKE CONNECT ON DATABASE %I FROM issp_break_glass',
        current_database()
    );

    FOREACH v_owner_role IN ARRAY ARRAY[
        'issp_database_owner'::name,
        'issp_foundation_owner'::name,
        'issp_extension_owner'::name
    ]
    LOOP
        EXECUTE format(
            'REVOKE %I FROM issp_break_glass',
            v_owner_role
        );
    END LOOP;

    ALTER ROLE issp_break_glass WITH NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS CONNECTION LIMIT -1 VALID UNTIL 'infinity' PASSWORD NULL;
    ALTER ROLE issp_break_glass SET lock_timeout = '5s';
    ALTER ROLE issp_break_glass SET statement_timeout = '15min';
    ALTER ROLE issp_break_glass SET idle_in_transaction_session_timeout = '1min';
    ALTER ROLE issp_break_glass SET idle_session_timeout = '5min';
END;
$disable_break_glass_at_rest$;

-- ============================================================================
-- Post-implementation validation
-- ============================================================================

DO $validate_step6_posture$
DECLARE
    v_violation_count bigint;
BEGIN
    IF (SELECT count(*) FROM deployment_meta.credential_lifecycle_policy) <> 5 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'Credential lifecycle policy row count is not 5';
    END IF;

    SELECT count(*)
    INTO v_violation_count
    FROM pg_roles AS role_record
    WHERE role_record.rolname = 'issp_break_glass'
      AND (
          role_record.rolcanlogin
          OR role_record.rolsuper
          OR role_record.rolcreatedb
          OR role_record.rolcreaterole
          OR role_record.rolreplication
          OR role_record.rolbypassrls
          OR role_record.rolconnlimit <> -1
      );

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'issp_break_glass is not disabled and unprivileged at rest';
    END IF;

    SELECT count(*)
    INTO v_violation_count
    FROM pg_auth_members AS membership_record
    JOIN pg_roles AS member_role
      ON member_role.oid = membership_record.member
    WHERE member_role.rolname = 'issp_break_glass';

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'issp_break_glass retains standing role memberships';
    END IF;

    SELECT count(*)
    INTO v_violation_count
    FROM pg_authid AS authentication_record
    WHERE authentication_record.rolname = 'issp_break_glass'
      AND authentication_record.rolpassword IS NOT NULL;

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'issp_break_glass retains a database password at rest';
    END IF;

    IF has_database_privilege(
        'issp_break_glass',
        current_database(),
        'CONNECT'
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'issp_break_glass retains database CONNECT at rest';
    END IF;

    SELECT count(*)
    INTO v_violation_count
    FROM pg_proc AS routine_record
    JOIN pg_namespace AS namespace_record
      ON namespace_record.oid = routine_record.pronamespace
    CROSS JOIN LATERAL pg_catalog.aclexplode(
        coalesce(
            routine_record.proacl,
            pg_catalog.acldefault(
                'f',
                routine_record.proowner
            )
        )
    ) AS acl_record
    WHERE namespace_record.nspname = 'emergency_control'
      AND acl_record.grantee = 0
      AND acl_record.privilege_type = 'EXECUTE';

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'PUBLIC can execute an emergency-control routine',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;

    SELECT count(*)
    INTO v_violation_count
    FROM information_schema.columns AS column_record
    WHERE column_record.table_schema = 'deployment_meta'
      AND column_record.table_name IN (
          'credential_lifecycle_events',
          'break_glass_requests',
          'break_glass_events',
          'break_glass_evidence_outbox'
      )
      AND column_record.column_name IN (
          'password',
          'secret',
          'private_key',
          'credential_value',
          'token_value'
      );

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'Emergency evidence schema contains a prohibited raw credential column';
    END IF;

    SELECT count(*)
    INTO v_violation_count
    FROM pg_class AS view_record
    JOIN pg_namespace AS namespace_record
      ON namespace_record.oid = view_record.relnamespace
    WHERE namespace_record.nspname = 'deployment_meta'
      AND view_record.relname IN (
          'audit_break_glass_events',
          'audit_credential_lifecycle_events',
          'break_glass_posture',
          'credential_lifecycle_posture',
          'break_glass_evidence_posture'
      )
      AND (
          view_record.relkind <> 'v'
          OR NOT EXISTS (
              SELECT 1
              FROM unnest(coalesce(view_record.reloptions, ARRAY[]::text[])) AS option_record(option_value)
              WHERE option_record.option_value = 'security_barrier=true'
          )
          OR pg_catalog.pg_get_userbyid(view_record.relowner) <> 'issp_database_owner'
      );

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'A Step 6 review view lacks the accepted security posture',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;
END;
$validate_step6_posture$;

SELECT deployment_meta.register_deployment_migration(
    p_migration_id =>
        '940_break_glass_and_credential_lifecycle',
    p_migration_name =>
        'Disabled-at-rest break-glass and credential lifecycle controls',
    p_migration_checksum => :'deployment_migration_checksum',
    p_relative_path => :'deployment_migration_relative_path',
    p_notes =>
        'Implemented dual-approved, time-bounded emergency activation; forced deactivation and expiration; append-only evidence; off-host export requirements; and external credential lifecycle policy without storing credentials.'
);

COMMIT;
