-- ============================================================================
-- Migration: 920_least_privileged_runtime_grants_and_controlled_service_apis.sql
-- Title: Least-Privileged Runtime Grants and Controlled Service APIs
-- Layer: Deployment and Bootstrap
-- Status: PHASE 5 STEP 4 CANDIDATE
-- Target: PostgreSQL 18
-- ============================================================================
--
-- Purpose:
-- - Grant only the minimum database CONNECT, schema USAGE, and controlled
--   routine EXECUTE privileges required by the current production service
--   identities.
-- - Expose bounded delivery APIs for the integration and monitoring workers.
-- - Convert only explicitly approved controlled Foundation routines to
--   SECURITY DEFINER so runtime services do not need direct protected-table
--   privileges.
-- - Preserve deny-by-default posture for review roles, break-glass, and the
--   migration executor.
--
-- Security boundary:
-- - No runtime, service, or writer role receives direct table or sequence
--   privileges.
-- - No canonical service login receives direct object grants; privileges flow
--   only through inherited capability roles.
-- - Every exposed SECURITY DEFINER function is owned by
--   issp_foundation_owner, has a fixed search_path, and is revoked from PUBLIC.
-- - Runtime credentials remain unprovisioned.
-- - Investigator, audit, and validation access remains deferred to Step 5.
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
    v_missing_roles text;
BEGIN
    IF current_setting('server_version_num')::integer < 180000 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'feature_not_supported',
            MESSAGE = 'Iron Signal Platform deployment migrations require PostgreSQL 18 or newer',
            DETAIL = format(
                'Detected server_version_num=%s.',
                current_setting('server_version_num')
            );
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles AS role_record
        WHERE role_record.rolname = current_user
          AND role_record.rolsuper
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'insufficient_privilege',
            MESSAGE = 'Phase 5 Step 4 runtime-grant bootstrap requires a PostgreSQL superuser',
            DETAIL = format('Connected role=%I.', current_user),
            HINT = 'Use the controlled deployment bootstrap identity.';
    END IF;

    SELECT count(*)
    INTO v_foundation_migration_count
    FROM foundation_meta.applied_migrations;

    IF v_foundation_migration_count <> 34 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'object_not_in_prerequisite_state',
            MESSAGE = 'The accepted 34-migration Platform Foundation is required before runtime grants',
            DETAIL = format(
                'Registered Foundation migrations=%s.',
                v_foundation_migration_count
            );
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM deployment_meta.applied_deployment_migrations
        WHERE migration_id = '900_postgresql_role_topology_and_membership'
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'object_not_in_prerequisite_state',
            MESSAGE = 'Required deployment migration 900 is not registered';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM deployment_meta.applied_deployment_migrations
        WHERE migration_id = '910_database_schema_and_object_ownership'
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'object_not_in_prerequisite_state',
            MESSAGE = 'Required deployment migration 910 is not registered';
    END IF;

    SELECT string_agg(required_role.role_name, ', ' ORDER BY required_role.role_name)
    INTO v_missing_roles
    FROM (
        VALUES
            ('issp_database_owner'::name),
            ('issp_foundation_owner'::name),
            ('issp_extension_owner'::name),
            ('issp_migration_executor'::name),
            ('issp_runtime'::name),
            ('issp_writer_authentication_assertion'::name),
            ('issp_writer_session_control'::name),
            ('issp_writer_authorization_decision'::name),
            ('issp_writer_approval'::name),
            ('issp_writer_integration_delivery'::name),
            ('issp_writer_monitoring_delivery'::name),
            ('issp_read_only_investigator'::name),
            ('issp_audit_reader'::name),
            ('issp_validation_reader'::name),
            ('issp_break_glass'::name),
            ('issp_service_authorization'::name),
            ('issp_service_integration_delivery'::name),
            ('issp_service_monitoring_delivery'::name)
    ) AS required_role(role_name)
    WHERE NOT EXISTS (
        SELECT 1
        FROM pg_roles AS role_record
        WHERE role_record.rolname = required_role.role_name
    );

    IF v_missing_roles IS NOT NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = 'undefined_object',
            MESSAGE = 'One or more canonical Phase 5 roles are missing',
            DETAIL = v_missing_roles;
    END IF;

    IF pg_get_userbyid((
        SELECT database_record.datdba
        FROM pg_database AS database_record
        WHERE database_record.datname = current_database()
    )) <> 'issp_database_owner' THEN
        RAISE EXCEPTION USING
            ERRCODE = 'object_not_in_prerequisite_state',
            MESSAGE = 'Current database is not owned by issp_database_owner';
    END IF;
END;
$deployment_dependency_check$;

-- ============================================================================
-- Controlled delivery APIs for repository-only Foundation tables
-- ============================================================================

CREATE FUNCTION integration.claim_outbox_events(
    p_limit integer,
    p_claim_lease interval DEFAULT interval '30 seconds'
)
RETURNS TABLE (
    outbox_event_id uuid,
    integration_contract_id uuid,
    contract_key text,
    external_system_name text,
    adapter_name text,
    adapter_version text,
    event_type text,
    aggregate_type text,
    aggregate_id text,
    payload jsonb,
    classification_reference text,
    created_at timestamptz,
    attempt_number integer,
    claim_expires_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, integration
AS $function$
DECLARE
    v_evaluated_at timestamptz := pg_catalog.statement_timestamp();
BEGIN
    IF p_limit IS NULL OR p_limit < 1 OR p_limit > 100 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_parameter_value',
            MESSAGE = 'Outbox claim limit must be between 1 and 100';
    END IF;

    IF p_claim_lease IS NULL
       OR p_claim_lease <= interval '0 seconds'
       OR p_claim_lease > interval '15 minutes' THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_parameter_value',
            MESSAGE = 'Outbox claim lease must be greater than zero and no more than 15 minutes';
    END IF;

    RETURN QUERY
    WITH candidate_events AS (
        SELECT event_record.outbox_event_id
        FROM integration.outbox_events AS event_record
        JOIN integration.integration_contracts AS contract_record
          ON contract_record.integration_contract_id =
             event_record.integration_contract_id
        WHERE contract_record.status = 'ACTIVE'
          AND contract_record.valid_from <= v_evaluated_at
          AND (
              contract_record.valid_until IS NULL
              OR v_evaluated_at < contract_record.valid_until
          )
          AND event_record.available_at <= v_evaluated_at
          AND (
              (
                  event_record.status IN ('PENDING', 'RETRY')
                  AND (
                      event_record.next_attempt_at IS NULL
                      OR event_record.next_attempt_at <= v_evaluated_at
                  )
              )
              OR
              (
                  event_record.status = 'IN_PROGRESS'
                  AND event_record.next_attempt_at <= v_evaluated_at
              )
          )
        ORDER BY
            event_record.available_at,
            event_record.outbox_event_id
        FOR UPDATE OF event_record SKIP LOCKED
        LIMIT p_limit
    ),
    claimed_events AS (
        UPDATE integration.outbox_events AS event_record
        SET
            status = 'IN_PROGRESS',
            attempt_count = event_record.attempt_count + 1,
            next_attempt_at = v_evaluated_at + p_claim_lease,
            last_error = NULL
        FROM candidate_events
        WHERE event_record.outbox_event_id =
              candidate_events.outbox_event_id
        RETURNING
            event_record.outbox_event_id,
            event_record.integration_contract_id,
            event_record.event_type,
            event_record.aggregate_type,
            event_record.aggregate_id,
            event_record.payload,
            event_record.classification_reference,
            event_record.created_at,
            event_record.attempt_count,
            event_record.next_attempt_at
    )
    SELECT
        claimed_event.outbox_event_id,
        claimed_event.integration_contract_id,
        contract_record.contract_key,
        contract_record.external_system_name,
        contract_record.adapter_name,
        contract_record.adapter_version,
        claimed_event.event_type,
        claimed_event.aggregate_type,
        claimed_event.aggregate_id,
        claimed_event.payload,
        claimed_event.classification_reference,
        claimed_event.created_at,
        claimed_event.attempt_count,
        claimed_event.next_attempt_at
    FROM claimed_events AS claimed_event
    JOIN integration.integration_contracts AS contract_record
      ON contract_record.integration_contract_id =
         claimed_event.integration_contract_id
    ORDER BY claimed_event.created_at, claimed_event.outbox_event_id;
END;
$function$;

CREATE FUNCTION integration.mark_outbox_event_delivered(
    p_outbox_event_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
STRICT
SECURITY DEFINER
SET search_path = pg_catalog, integration
AS $function$
BEGIN
    UPDATE integration.outbox_events AS event_record
    SET
        status = 'DELIVERED',
        next_attempt_at = NULL,
        last_error = NULL
    WHERE event_record.outbox_event_id = p_outbox_event_id
      AND event_record.status = 'IN_PROGRESS';

    RETURN FOUND;
END;
$function$;

CREATE FUNCTION integration.reschedule_outbox_event(
    p_outbox_event_id uuid,
    p_last_error text,
    p_next_attempt_at timestamptz
)
RETURNS boolean
LANGUAGE plpgsql
STRICT
SECURITY DEFINER
SET search_path = pg_catalog, integration
AS $function$
DECLARE
    v_evaluated_at timestamptz := pg_catalog.statement_timestamp();
BEGIN
    IF pg_catalog.btrim(p_last_error) = '' THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_parameter_value',
            MESSAGE = 'Outbox delivery error must not be empty';
    END IF;

    IF p_next_attempt_at <= v_evaluated_at THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_parameter_value',
            MESSAGE = 'Outbox next-attempt time must be in the future';
    END IF;

    UPDATE integration.outbox_events AS event_record
    SET
        status = 'RETRY',
        next_attempt_at = p_next_attempt_at,
        last_error = pg_catalog.btrim(p_last_error)
    WHERE event_record.outbox_event_id = p_outbox_event_id
      AND event_record.status = 'IN_PROGRESS';

    RETURN FOUND;
END;
$function$;

CREATE FUNCTION observability.claim_monitoring_deliveries(
    p_limit integer,
    p_claim_lease interval DEFAULT interval '30 seconds'
)
RETURNS TABLE (
    monitoring_delivery_state_id uuid,
    monitoring_subscription_id uuid,
    subscription_key text,
    destination_type text,
    destination_reference text,
    event_filter jsonb,
    health_event_id uuid,
    metric_sample_id bigint,
    health_event jsonb,
    metric_sample jsonb,
    attempt_number integer,
    claim_expires_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, observability
AS $function$
DECLARE
    v_evaluated_at timestamptz := pg_catalog.statement_timestamp();
BEGIN
    IF p_limit IS NULL OR p_limit < 1 OR p_limit > 100 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_parameter_value',
            MESSAGE = 'Monitoring claim limit must be between 1 and 100';
    END IF;

    IF p_claim_lease IS NULL
       OR p_claim_lease <= interval '0 seconds'
       OR p_claim_lease > interval '15 minutes' THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_parameter_value',
            MESSAGE = 'Monitoring claim lease must be greater than zero and no more than 15 minutes';
    END IF;

    RETURN QUERY
    WITH candidate_deliveries AS (
        SELECT delivery_record.monitoring_delivery_state_id
        FROM observability.monitoring_delivery_state AS delivery_record
        JOIN observability.monitoring_subscriptions AS subscription_record
          ON subscription_record.monitoring_subscription_id =
             delivery_record.monitoring_subscription_id
        WHERE subscription_record.status = 'ACTIVE'
          AND delivery_record.attempt_count <
              subscription_record.max_retry_count
          AND (
              (
                  delivery_record.delivery_status IN ('PENDING', 'RETRY')
                  AND (
                      delivery_record.next_attempt_at IS NULL
                      OR delivery_record.next_attempt_at <= v_evaluated_at
                  )
              )
              OR
              (
                  delivery_record.delivery_status = 'IN_PROGRESS'
                  AND delivery_record.next_attempt_at <= v_evaluated_at
              )
          )
        ORDER BY
            COALESCE(
                delivery_record.next_attempt_at,
                '-infinity'::timestamptz
            ),
            delivery_record.monitoring_delivery_state_id
        FOR UPDATE OF delivery_record SKIP LOCKED
        LIMIT p_limit
    ),
    claimed_deliveries AS (
        UPDATE observability.monitoring_delivery_state AS delivery_record
        SET
            delivery_status = 'IN_PROGRESS',
            attempt_count = delivery_record.attempt_count + 1,
            next_attempt_at = v_evaluated_at + p_claim_lease,
            last_error = NULL,
            delivered_at = NULL
        FROM candidate_deliveries
        WHERE delivery_record.monitoring_delivery_state_id =
              candidate_deliveries.monitoring_delivery_state_id
        RETURNING
            delivery_record.monitoring_delivery_state_id,
            delivery_record.monitoring_subscription_id,
            delivery_record.health_event_id,
            delivery_record.metric_sample_id,
            delivery_record.attempt_count,
            delivery_record.next_attempt_at
    )
    SELECT
        claimed_delivery.monitoring_delivery_state_id,
        claimed_delivery.monitoring_subscription_id,
        subscription_record.subscription_key,
        subscription_record.destination_type,
        subscription_record.destination_reference,
        subscription_record.event_filter,
        claimed_delivery.health_event_id,
        claimed_delivery.metric_sample_id,
        CASE
            WHEN health_record.health_event_id IS NULL THEN NULL
            ELSE pg_catalog.to_jsonb(health_record)
        END,
        CASE
            WHEN metric_record.metric_sample_id IS NULL THEN NULL
            ELSE pg_catalog.to_jsonb(metric_record)
        END,
        claimed_delivery.attempt_count,
        claimed_delivery.next_attempt_at
    FROM claimed_deliveries AS claimed_delivery
    JOIN observability.monitoring_subscriptions AS subscription_record
      ON subscription_record.monitoring_subscription_id =
         claimed_delivery.monitoring_subscription_id
    LEFT JOIN observability.health_events AS health_record
      ON health_record.health_event_id = claimed_delivery.health_event_id
    LEFT JOIN observability.metric_samples AS metric_record
      ON metric_record.metric_sample_id = claimed_delivery.metric_sample_id
    ORDER BY claimed_delivery.monitoring_delivery_state_id;
END;
$function$;

CREATE FUNCTION observability.mark_monitoring_delivery_delivered(
    p_monitoring_delivery_state_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
STRICT
SECURITY DEFINER
SET search_path = pg_catalog, observability
AS $function$
DECLARE
    v_evaluated_at timestamptz := pg_catalog.statement_timestamp();
BEGIN
    UPDATE observability.monitoring_delivery_state AS delivery_record
    SET
        delivery_status = 'DELIVERED',
        next_attempt_at = NULL,
        last_error = NULL,
        delivered_at = v_evaluated_at
    WHERE delivery_record.monitoring_delivery_state_id =
          p_monitoring_delivery_state_id
      AND delivery_record.delivery_status = 'IN_PROGRESS';

    RETURN FOUND;
END;
$function$;

CREATE FUNCTION observability.reschedule_monitoring_delivery(
    p_monitoring_delivery_state_id uuid,
    p_last_error text,
    p_next_attempt_at timestamptz
)
RETURNS text
LANGUAGE plpgsql
STRICT
SECURITY DEFINER
SET search_path = pg_catalog, observability
AS $function$
DECLARE
    v_evaluated_at timestamptz := pg_catalog.statement_timestamp();
    v_result_status text;
BEGIN
    IF pg_catalog.btrim(p_last_error) = '' THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_parameter_value',
            MESSAGE = 'Monitoring delivery error must not be empty';
    END IF;

    IF p_next_attempt_at <= v_evaluated_at THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_parameter_value',
            MESSAGE = 'Monitoring next-attempt time must be in the future';
    END IF;

    UPDATE observability.monitoring_delivery_state AS delivery_record
    SET
        delivery_status = CASE
            WHEN delivery_record.attempt_count >=
                 subscription_record.max_retry_count
                THEN 'FAILED'
            ELSE 'RETRY'
        END,
        next_attempt_at = CASE
            WHEN delivery_record.attempt_count >=
                 subscription_record.max_retry_count
                THEN NULL
            ELSE p_next_attempt_at
        END,
        last_error = pg_catalog.btrim(p_last_error),
        delivered_at = NULL
    FROM observability.monitoring_subscriptions AS subscription_record
    WHERE delivery_record.monitoring_delivery_state_id =
          p_monitoring_delivery_state_id
      AND delivery_record.monitoring_subscription_id =
          subscription_record.monitoring_subscription_id
      AND delivery_record.delivery_status = 'IN_PROGRESS'
    RETURNING delivery_record.delivery_status
    INTO v_result_status;

    RETURN v_result_status;
END;
$function$;

COMMENT ON FUNCTION integration.claim_outbox_events(integer, interval) IS
    'Atomically claims bounded, currently deliverable integration outbox events using row locks and a server-time claim lease.';
COMMENT ON FUNCTION integration.mark_outbox_event_delivered(uuid) IS
    'Marks one currently claimed integration outbox event as delivered.';
COMMENT ON FUNCTION integration.reschedule_outbox_event(uuid, text, timestamptz) IS
    'Returns one currently claimed integration outbox event to a future retry time with an attributable error.';
COMMENT ON FUNCTION observability.claim_monitoring_deliveries(integer, interval) IS
    'Atomically claims bounded monitoring deliveries and returns the approved destination and payload snapshot.';
COMMENT ON FUNCTION observability.mark_monitoring_delivery_delivered(uuid) IS
    'Marks one currently claimed monitoring delivery as delivered at PostgreSQL statement time.';
COMMENT ON FUNCTION observability.reschedule_monitoring_delivery(uuid, text, timestamptz) IS
    'Reschedules one claimed monitoring delivery or marks it failed when its configured retry limit is exhausted.';

ALTER FUNCTION integration.claim_outbox_events(integer, interval)
    OWNER TO issp_foundation_owner;
ALTER FUNCTION integration.mark_outbox_event_delivered(uuid)
    OWNER TO issp_foundation_owner;
ALTER FUNCTION integration.reschedule_outbox_event(uuid, text, timestamptz)
    OWNER TO issp_foundation_owner;
ALTER FUNCTION observability.claim_monitoring_deliveries(integer, interval)
    OWNER TO issp_foundation_owner;
ALTER FUNCTION observability.mark_monitoring_delivery_delivered(uuid)
    OWNER TO issp_foundation_owner;
ALTER FUNCTION observability.reschedule_monitoring_delivery(uuid, text, timestamptz)
    OWNER TO issp_foundation_owner;

REVOKE ALL ON FUNCTION integration.claim_outbox_events(integer, interval)
    FROM PUBLIC;
REVOKE ALL ON FUNCTION integration.mark_outbox_event_delivered(uuid)
    FROM PUBLIC;
REVOKE ALL ON FUNCTION integration.reschedule_outbox_event(uuid, text, timestamptz)
    FROM PUBLIC;
REVOKE ALL ON FUNCTION observability.claim_monitoring_deliveries(integer, interval)
    FROM PUBLIC;
REVOKE ALL ON FUNCTION observability.mark_monitoring_delivery_delivered(uuid)
    FROM PUBLIC;
REVOKE ALL ON FUNCTION observability.reschedule_monitoring_delivery(uuid, text, timestamptz)
    FROM PUBLIC;

-- ============================================================================
-- Runtime privilege contract inventory
-- ============================================================================

CREATE TABLE deployment_meta.runtime_privilege_contract (
    grantee_role_name          name        NOT NULL,
    object_kind                text        NOT NULL,
    object_identity            text        NOT NULL,
    privilege_type             text        NOT NULL,
    security_definer_required  boolean     NOT NULL DEFAULT false,
    notes                      text        NOT NULL,
    introduced_by_migration_id text        NOT NULL,
    recorded_at                timestamptz NOT NULL DEFAULT clock_timestamp(),

    CONSTRAINT runtime_privilege_contract_pk
        PRIMARY KEY (
            grantee_role_name,
            object_kind,
            object_identity,
            privilege_type
        ),

    CONSTRAINT runtime_privilege_contract_role_fk
        FOREIGN KEY (grantee_role_name)
        REFERENCES deployment_meta.database_roles(role_name),

    CONSTRAINT runtime_privilege_contract_kind_ck
        CHECK (object_kind IN ('DATABASE', 'SCHEMA', 'ROUTINE')),

    CONSTRAINT runtime_privilege_contract_privilege_ck
        CHECK (
            (object_kind = 'DATABASE' AND privilege_type = 'CONNECT')
            OR (object_kind = 'SCHEMA' AND privilege_type = 'USAGE')
            OR (object_kind = 'ROUTINE' AND privilege_type = 'EXECUTE')
        ),

    CONSTRAINT runtime_privilege_contract_notes_ck
        CHECK (btrim(notes) <> '')
);

COMMENT ON TABLE deployment_meta.runtime_privilege_contract IS
    'Exact Phase 5 runtime privilege allowlist. Absence from this table means the privilege is not approved.';

ALTER TABLE deployment_meta.runtime_privilege_contract
    OWNER TO issp_database_owner;

INSERT INTO deployment_meta.runtime_privilege_contract (
    grantee_role_name,
    object_kind,
    object_identity,
    privilege_type,
    security_definer_required,
    notes,
    introduced_by_migration_id
)
VALUES
    (
        'issp_runtime',
        'DATABASE',
        current_database(),
        'CONNECT',
        false,
        'Common runtime connection capability inherited by bounded service logins.',
        '920_least_privileged_runtime_grants_and_controlled_service_apis'
    ),
    ('issp_writer_authentication_assertion'::name, 'SCHEMA', 'access_control', 'USAGE', false, 'Schema access required for the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_session_control'::name, 'SCHEMA', 'access_control', 'USAGE', false, 'Schema access required for the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_authorization_decision'::name, 'SCHEMA', 'access_control', 'USAGE', false, 'Schema access required for the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_authorization_decision'::name, 'SCHEMA', 'decision', 'USAGE', false, 'Schema access required for the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_approval'::name, 'SCHEMA', 'approval', 'USAGE', false, 'Schema access required for the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_approval'::name, 'SCHEMA', 'decision', 'USAGE', false, 'Schema access required for the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_integration_delivery'::name, 'SCHEMA', 'integration', 'USAGE', false, 'Schema access required for the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_monitoring_delivery'::name, 'SCHEMA', 'observability', 'USAGE', false, 'Schema access required for the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_authentication_assertion'::name, 'ROUTINE', 'access_control.mark_authentication_assertion_verified(uuid,text,text)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_authentication_assertion'::name, 'ROUTINE', 'access_control.reject_authentication_assertion(uuid,text)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_authentication_assertion'::name, 'ROUTINE', 'access_control.expire_authentication_assertion(uuid)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_authentication_assertion'::name, 'ROUTINE', 'access_control.revoke_authentication_assertion(uuid,text)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_authentication_assertion'::name, 'ROUTINE', 'access_control.consume_authentication_assertion(text,text,uuid,uuid,uuid,uuid,uuid,text,text)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_session_control'::name, 'ROUTINE', 'access_control.establish_session_from_authentication_assertion(text,uuid,interval,interval,text,text,uuid)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_session_control'::name, 'ROUTINE', 'access_control.complete_session_step_up(uuid,text,text,text)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_session_control'::name, 'ROUTINE', 'access_control.record_session_activity(uuid,text)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_session_control'::name, 'ROUTINE', 'access_control.lock_session(uuid,text,uuid,text)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_session_control'::name, 'ROUTINE', 'access_control.unlock_session(uuid,text,text,uuid,text)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_session_control'::name, 'ROUTINE', 'access_control.expire_session(uuid,uuid,text)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_session_control'::name, 'ROUTINE', 'access_control.revoke_session(uuid,text,uuid,text)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_session_control'::name, 'ROUTINE', 'access_control.terminate_session(uuid,text,uuid,text)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_authorization_decision'::name, 'ROUTINE', 'decision.resolve_authorization_policy(uuid)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_authorization_decision'::name, 'ROUTINE', 'decision.bind_authorization_policy(uuid)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_authorization_decision'::name, 'ROUTINE', 'decision.finalize_authorization_decision(uuid)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_authorization_decision'::name, 'ROUTINE', 'access_control.issue_authorization_lease_from_decision(uuid,text)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_authorization_decision'::name, 'ROUTINE', 'access_control.authorization_lease_context_is_usable(uuid,text,uuid,uuid,uuid,uuid,uuid,uuid,uuid,text,text,uuid,text,uuid,text)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_authorization_decision'::name, 'ROUTINE', 'access_control.consume_authorization_lease(uuid,text,uuid,uuid,uuid,uuid,uuid,uuid,uuid,uuid,text,text,uuid,text,uuid,text,uuid,uuid)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_authorization_decision'::name, 'ROUTINE', 'access_control.expire_authorization_lease(uuid)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_authorization_decision'::name, 'ROUTINE', 'access_control.revoke_lease(uuid,text)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_approval'::name, 'ROUTINE', 'approval.record_approval_action(uuid,uuid,uuid,uuid,uuid,uuid,text,text,text,uuid)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_approval'::name, 'ROUTINE', 'approval.evaluate_approval_stage(uuid,uuid,timestamptz,boolean)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_approval'::name, 'ROUTINE', 'approval.finalize_approval_request(uuid,text,uuid)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_approval'::name, 'ROUTINE', 'decision.link_approval_stage_evaluation(uuid,uuid,uuid)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_integration_delivery'::name, 'ROUTINE', 'integration.claim_outbox_events(integer,interval)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_integration_delivery'::name, 'ROUTINE', 'integration.mark_outbox_event_delivered(uuid)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_integration_delivery'::name, 'ROUTINE', 'integration.reschedule_outbox_event(uuid,text,timestamptz)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_monitoring_delivery'::name, 'ROUTINE', 'observability.claim_monitoring_deliveries(integer,interval)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_monitoring_delivery'::name, 'ROUTINE', 'observability.mark_monitoring_delivery_delivered(uuid)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis'),
    ('issp_writer_monitoring_delivery'::name, 'ROUTINE', 'observability.reschedule_monitoring_delivery(uuid,text,timestamptz)', 'EXECUTE', true, 'Controlled runtime routine exposed to the bounded capability.', '920_least_privileged_runtime_grants_and_controlled_service_apis')
;

-- ============================================================================
-- Normalize deny-by-default posture before applying the allowlist
-- ============================================================================

DO $revoke_unapproved_runtime_access$
DECLARE
    v_role_name name;
    v_schema_name name;
BEGIN
    FOR v_role_name IN
        SELECT database_role.role_name
        FROM deployment_meta.database_roles AS database_role
        WHERE NOT database_role.ownership_role
        ORDER BY database_role.role_name
    LOOP
        EXECUTE format(
            'REVOKE CONNECT, TEMPORARY ON DATABASE %I FROM %I',
            current_database(),
            v_role_name
        );

        FOREACH v_schema_name IN ARRAY ARRAY[
            'extensions'::name,
            'deployment_meta'::name,
            'foundation_meta'::name,
            'trust'::name,
            'identity'::name,
            'organization'::name,
            'service'::name,
            'attestation'::name,
            'approval'::name,
            'access_control'::name,
            'decision'::name,
            'governance'::name,
            'compliance'::name,
            'risk'::name,
            'resilience'::name,
            'performance'::name,
            'observability'::name,
            'integration'::name,
            'security_validation'::name
        ]
        LOOP
            EXECUTE format(
                'REVOKE ALL PRIVILEGES ON SCHEMA %I FROM %I',
                v_schema_name,
                v_role_name
            );

            EXECUTE format(
                'REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA %I FROM %I',
                v_schema_name,
                v_role_name
            );

            EXECUTE format(
                'REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA %I FROM %I',
                v_schema_name,
                v_role_name
            );

            EXECUTE format(
                'REVOKE ALL PRIVILEGES ON ALL ROUTINES IN SCHEMA %I FROM %I',
                v_schema_name,
                v_role_name
            );
        END LOOP;
    END LOOP;
END;
$revoke_unapproved_runtime_access$;

DO $revoke_public_database_access$
BEGIN
    EXECUTE format(
        'REVOKE CONNECT, TEMPORARY ON DATABASE %I FROM PUBLIC',
        current_database()
    );
END;
$revoke_public_database_access$;

-- The Foundation owner requires one narrowly bounded cryptographic dependency
-- for lease-secret hashing inside SECURITY DEFINER routines.
GRANT USAGE ON SCHEMA extensions
TO issp_foundation_owner;

GRANT EXECUTE ON FUNCTION extensions.digest(bytea, text)
TO issp_foundation_owner;

-- ============================================================================
-- Apply exact database and schema allowlist
-- ============================================================================

DO $grant_runtime_database_connect$
BEGIN
    EXECUTE format(
        'GRANT CONNECT ON DATABASE %I TO issp_runtime',
        current_database()
    );
END;
$grant_runtime_database_connect$;

DO $grant_runtime_schema_usage$
DECLARE
    v_contract deployment_meta.runtime_privilege_contract%ROWTYPE;
BEGIN
    FOR v_contract IN
        SELECT *
        FROM deployment_meta.runtime_privilege_contract
        WHERE object_kind = 'SCHEMA'
        ORDER BY grantee_role_name, object_identity
    LOOP
        EXECUTE format(
            'GRANT USAGE ON SCHEMA %I TO %I',
            v_contract.object_identity,
            v_contract.grantee_role_name
        );
    END LOOP;
END;
$grant_runtime_schema_usage$;

-- ============================================================================
-- Harden and expose only approved controlled routines
-- ============================================================================

DO $harden_and_grant_controlled_routines$
DECLARE
    v_contract deployment_meta.runtime_privilege_contract%ROWTYPE;
    v_routine_oid oid;
    v_role_name name;
BEGIN
    FOR v_contract IN
        SELECT *
        FROM deployment_meta.runtime_privilege_contract
        WHERE object_kind = 'ROUTINE'
        ORDER BY grantee_role_name, object_identity
    LOOP
        v_routine_oid := pg_catalog.to_regprocedure(
            v_contract.object_identity
        );

        IF v_routine_oid IS NULL THEN
            RAISE EXCEPTION USING
                ERRCODE = 'undefined_function',
                MESSAGE = 'Approved runtime routine does not exist',
                DETAIL = v_contract.object_identity;
        END IF;

        EXECUTE format(
            'ALTER FUNCTION %s OWNER TO issp_foundation_owner',
            v_routine_oid::regprocedure
        );

        IF v_contract.security_definer_required THEN
            EXECUTE format(
                'ALTER FUNCTION %s SECURITY DEFINER',
                v_routine_oid::regprocedure
            );
        END IF;

        EXECUTE format(
            'REVOKE ALL ON FUNCTION %s FROM PUBLIC',
            v_routine_oid::regprocedure
        );

        FOR v_role_name IN
            SELECT database_role.role_name
            FROM deployment_meta.database_roles AS database_role
            WHERE NOT database_role.ownership_role
            ORDER BY database_role.role_name
        LOOP
            EXECUTE format(
                'REVOKE ALL ON FUNCTION %s FROM %I',
                v_routine_oid::regprocedure,
                v_role_name
            );
        END LOOP;

        EXECUTE format(
            'GRANT EXECUTE ON FUNCTION %s TO %I',
            v_routine_oid::regprocedure,
            v_contract.grantee_role_name
        );
    END LOOP;
END;
$harden_and_grant_controlled_routines$;

-- ============================================================================
-- Validation before registration
-- ============================================================================

DO $validate_phase5_step4_runtime_grants$
DECLARE
    v_violation_count bigint;
BEGIN
    IF NOT has_database_privilege(
        'issp_runtime',
        current_database(),
        'CONNECT'
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'issp_runtime does not have database CONNECT';
    END IF;

    SELECT count(*)
    INTO v_violation_count
    FROM (
        VALUES
            ('issp_service_authorization'::name),
            ('issp_service_integration_delivery'::name),
            ('issp_service_monitoring_delivery'::name)
    ) AS service_role(role_name)
    WHERE NOT has_database_privilege(
        service_role.role_name,
        current_database(),
        'CONNECT'
    );

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'One or more bounded service logins lack inherited database CONNECT',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;

    SELECT count(*)
    INTO v_violation_count
    FROM (
        VALUES
            ('issp_migration_executor'::name),
            ('issp_read_only_investigator'::name),
            ('issp_audit_reader'::name),
            ('issp_validation_reader'::name),
            ('issp_break_glass'::name)
    ) AS denied_role(role_name)
    WHERE has_database_privilege(
        denied_role.role_name,
        current_database(),
        'CONNECT'
    );

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'A deferred or emergency role received database CONNECT',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;

    SELECT count(*)
    INTO v_violation_count
    FROM deployment_meta.runtime_privilege_contract;

    IF v_violation_count <> 40 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'Runtime privilege contract row count is not 40',
            DETAIL = format('observed_count=%s', v_violation_count);
    END IF;

    SELECT count(*)
    INTO v_violation_count
    FROM deployment_meta.runtime_privilege_contract AS privilege_contract
    WHERE CASE
        WHEN privilege_contract.object_kind <> 'SCHEMA' THEN false
        WHEN pg_catalog.to_regnamespace(
            privilege_contract.object_identity
        ) IS NULL THEN true
        ELSE NOT has_schema_privilege(
            privilege_contract.grantee_role_name,
            pg_catalog.to_regnamespace(
                privilege_contract.object_identity
            ),
            privilege_contract.privilege_type
        )
    END;

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'One or more approved schema privileges are ineffective',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;

    SELECT count(*)
    INTO v_violation_count
    FROM deployment_meta.runtime_privilege_contract AS privilege_contract
    WHERE CASE
        WHEN privilege_contract.object_kind <> 'ROUTINE' THEN false
        WHEN pg_catalog.to_regprocedure(
            privilege_contract.object_identity
        ) IS NULL THEN true
        ELSE NOT has_function_privilege(
            privilege_contract.grantee_role_name,
            pg_catalog.to_regprocedure(
                privilege_contract.object_identity
            ),
            privilege_contract.privilege_type
        )
    END;

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'One or more approved routine privileges are ineffective',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;

    SELECT count(*)
    INTO v_violation_count
    FROM deployment_meta.runtime_privilege_contract AS privilege_contract
    JOIN pg_proc AS routine_record
      ON routine_record.oid = pg_catalog.to_regprocedure(
          privilege_contract.object_identity
      )
    WHERE privilege_contract.object_kind = 'ROUTINE'
      AND (
          NOT routine_record.prosecdef
          OR pg_get_userbyid(routine_record.proowner) <>
             'issp_foundation_owner'
          OR NOT EXISTS (
              SELECT 1
              FROM unnest(
                  COALESCE(routine_record.proconfig, ARRAY[]::text[])
              ) AS configuration(setting)
              WHERE configuration.setting LIKE 'search_path=pg_catalog,%'
          )
      );

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'An exposed routine lacks the required SECURITY DEFINER posture',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;

    SELECT count(*)
    INTO v_violation_count
    FROM deployment_meta.runtime_privilege_contract AS privilege_contract
    WHERE privilege_contract.object_kind = 'ROUTINE'
      AND has_function_privilege(
          'public',
          pg_catalog.to_regprocedure(
              privilege_contract.object_identity
          ),
          'EXECUTE'
      );

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'PUBLIC can execute one or more exposed runtime routines',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;

    SELECT count(*)
    INTO v_violation_count
    FROM pg_class AS relation_record
    JOIN pg_namespace AS namespace_record
      ON namespace_record.oid = relation_record.relnamespace
    CROSS JOIN LATERAL pg_catalog.aclexplode(
        relation_record.relacl
    ) AS privilege_record
    JOIN pg_roles AS grantee_role
      ON grantee_role.oid = privilege_record.grantee
    JOIN deployment_meta.database_roles AS canonical_role
      ON canonical_role.role_name = grantee_role.rolname
    WHERE NOT canonical_role.ownership_role
      AND namespace_record.nspname IN (
          'foundation_meta',
          'trust',
          'identity',
          'organization',
          'service',
          'attestation',
          'approval',
          'access_control',
          'decision',
          'governance',
          'compliance',
          'risk',
          'resilience',
          'performance',
          'observability',
          'integration',
          'security_validation'
      )
      AND privilege_record.privilege_type IN (
          'SELECT',
          'INSERT',
          'UPDATE',
          'DELETE',
          'TRUNCATE',
          'REFERENCES',
          'TRIGGER',
          'USAGE'
      );

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'A non-owner canonical role received direct relation or sequence privileges',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;

    IF has_database_privilege(
        'issp_runtime',
        current_database(),
        'TEMPORARY'
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'issp_runtime received database TEMPORARY privilege';
    END IF;

    IF NOT has_schema_privilege(
        'issp_foundation_owner',
        'extensions',
        'USAGE'
    ) OR NOT has_function_privilege(
        'issp_foundation_owner',
        'extensions.digest(bytea,text)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'Foundation owner cryptographic dependency is incomplete';
    END IF;
END;
$validate_phase5_step4_runtime_grants$;

REVOKE ALL PRIVILEGES
ON TABLE deployment_meta.runtime_privilege_contract
FROM PUBLIC;

SELECT deployment_meta.register_deployment_migration(
    p_migration_id =>
        '920_least_privileged_runtime_grants_and_controlled_service_apis',
    p_migration_name =>
        'Least-privileged runtime grants and controlled service APIs',
    p_migration_checksum =>
        :'deployment_migration_checksum',
    p_relative_path =>
        :'deployment_migration_relative_path',
    p_notes =>
        'Granted inherited runtime CONNECT, exact capability schema USAGE and routine EXECUTE, hardened 31 controlled routines as SECURITY DEFINER, created bounded integration and monitoring delivery APIs, and preserved zero direct table or sequence grants.'
);

COMMIT;
