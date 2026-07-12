-- ============================================================================
-- Migration: 072_postgresql_session_control.sql
-- Title: PostgreSQL session establishment, step-up, and lifecycle control
-- Layer: Platform Foundation
-- Status: PHASE 2 STEP 3 IMPLEMENTATION CANDIDATE
-- Target: PostgreSQL 18
-- Compatibility policy: prefer mature features supported before PostgreSQL 18.
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '10min';
SET LOCAL idle_in_transaction_session_timeout = '10min';

SELECT pg_advisory_xact_lock(
    hashtext(current_database()),
    hashtext('platform-foundation-migrations')
);

DO $dependency_check$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM foundation_meta.applied_migrations
        WHERE migration_id = '070_postgresql_authentication_assertion_gate'
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'object_not_in_prerequisite_state',
                MESSAGE = 'Required migration 070_postgresql_authentication_assertion_gate is not registered';
    END IF;
END;
$dependency_check$;

-- Authentication Assertion linkage is added only after migration 070 creates
-- the assertion table and its accepted exact-context consumption boundary.
ALTER TABLE access_control.sessions
    ADD COLUMN establishment_authentication_assertion_id uuid NOT NULL,
    ADD COLUMN latest_step_up_authentication_assertion_id uuid,

    ADD CONSTRAINT sessions_establishment_assertion_fk
        FOREIGN KEY (establishment_authentication_assertion_id)
        REFERENCES access_control.authentication_assertions(
            authentication_assertion_id
        ),

    ADD CONSTRAINT sessions_latest_step_up_assertion_fk
        FOREIGN KEY (latest_step_up_authentication_assertion_id)
        REFERENCES access_control.authentication_assertions(
            authentication_assertion_id
        ),

    ADD CONSTRAINT sessions_establishment_assertion_uq
        UNIQUE (establishment_authentication_assertion_id),

    ADD CONSTRAINT sessions_step_up_evidence_shape_ck
        CHECK (
            (
                last_step_up_at IS NULL
                AND latest_step_up_authentication_assertion_id IS NULL
            )
            OR
            (
                last_step_up_at IS NOT NULL
                AND latest_step_up_authentication_assertion_id IS NOT NULL
            )
        ),

    ADD CONSTRAINT sessions_distinct_assertion_evidence_ck
        CHECK (
            latest_step_up_authentication_assertion_id IS NULL
            OR latest_step_up_authentication_assertion_id
                <> establishment_authentication_assertion_id
        );

COMMENT ON COLUMN access_control.sessions.establishment_authentication_assertion_id IS
    'The single consumed SESSION_ESTABLISHMENT Authentication Assertion that created this session.';

COMMENT ON COLUMN access_control.sessions.latest_step_up_authentication_assertion_id IS
    'The most recently consumed SESSION_STEP_UP Authentication Assertion supporting last_step_up_at.';

ALTER TABLE access_control.session_events
    ADD COLUMN authentication_assertion_id uuid,
    ADD CONSTRAINT session_events_authentication_assertion_fk
        FOREIGN KEY (authentication_assertion_id)
        REFERENCES access_control.authentication_assertions(
            authentication_assertion_id
        ),
    ADD CONSTRAINT session_events_assertion_shape_ck
        CHECK (
            (
                event_type IN ('CREATED', 'STEP_UP_COMPLETED')
                AND authentication_assertion_id IS NOT NULL
            )
            OR
            (
                event_type NOT IN ('CREATED', 'STEP_UP_COMPLETED')
                AND authentication_assertion_id IS NULL
            )
        );

COMMENT ON COLUMN access_control.session_events.authentication_assertion_id IS
    'Consumed Authentication Assertion supporting CREATED or STEP_UP_COMPLETED. Other event types do not carry assertion evidence.';

CREATE UNIQUE INDEX sessions_latest_step_up_assertion_uq
    ON access_control.sessions(latest_step_up_authentication_assertion_id)
    WHERE latest_step_up_authentication_assertion_id IS NOT NULL;

CREATE UNIQUE INDEX session_events_assertion_uq
    ON access_control.session_events(authentication_assertion_id)
    WHERE authentication_assertion_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- Current locally owned trust-state predicate
-- ---------------------------------------------------------------------------

CREATE FUNCTION access_control.session_context_is_locally_usable(
    p_identity_id uuid,
    p_device_id uuid,
    p_trust_provider_id uuid,
    p_service_id uuid,
    p_organization_id uuid,
    p_environment_key text,
    p_evaluated_at timestamptz
)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = pg_catalog, access_control
AS $function$
    SELECT
        p_identity_id IS NOT NULL
        AND p_trust_provider_id IS NOT NULL
        AND p_environment_key IS NOT NULL
        AND p_evaluated_at IS NOT NULL

        AND EXISTS (
            SELECT 1
            FROM identity.identities AS identity_record
            WHERE
                identity_record.identity_id = p_identity_id
                AND identity_record.status = 'ACTIVE'
                AND identity_record.valid_from <= p_evaluated_at
                AND (
                    identity_record.valid_until IS NULL
                    OR p_evaluated_at < identity_record.valid_until
                )
        )

        AND EXISTS (
            SELECT 1
            FROM trust.trust_providers AS provider_record
            WHERE
                provider_record.trust_provider_id = p_trust_provider_id
                AND provider_record.status = 'ACTIVE'
                AND provider_record.environment_key = p_environment_key
                AND provider_record.valid_from <= p_evaluated_at
                AND (
                    provider_record.valid_until IS NULL
                    OR p_evaluated_at < provider_record.valid_until
                )
        )

        AND NOT EXISTS (
            SELECT 1
            FROM trust.revocations AS provider_revocation
            WHERE
                provider_revocation.object_type = 'TRUST_PROVIDER'
                AND provider_revocation.trust_provider_id =
                    p_trust_provider_id
                AND provider_revocation.effective_at <= p_evaluated_at
                AND (
                    provider_revocation.expires_at IS NULL
                    OR p_evaluated_at < provider_revocation.expires_at
                )
        )

        AND (
            p_device_id IS NULL
            OR (
                EXISTS (
                    SELECT 1
                    FROM trust.devices AS device_record
                    WHERE
                        device_record.device_id = p_device_id
                        AND device_record.status = 'TRUSTED'
                        AND device_record.trusted_from IS NOT NULL
                        AND device_record.trusted_from <= p_evaluated_at
                        AND (
                            device_record.trusted_until IS NULL
                            OR p_evaluated_at < device_record.trusted_until
                        )
                )
                AND NOT EXISTS (
                    SELECT 1
                    FROM trust.revocations AS device_revocation
                    WHERE
                        device_revocation.object_type = 'DEVICE'
                        AND device_revocation.device_id = p_device_id
                        AND device_revocation.effective_at <= p_evaluated_at
                        AND (
                            device_revocation.expires_at IS NULL
                            OR p_evaluated_at < device_revocation.expires_at
                        )
                )
            )
        )

        AND (
            p_service_id IS NULL
            OR EXISTS (
                SELECT 1
                FROM service.platform_services AS service_record
                WHERE
                    service_record.service_id = p_service_id
                    AND service_record.status = 'ACTIVE'
                    AND service_record.valid_from <= p_evaluated_at
                    AND (
                        service_record.valid_until IS NULL
                        OR p_evaluated_at < service_record.valid_until
                    )
            )
        )

        AND (
            p_organization_id IS NULL
            OR EXISTS (
                SELECT 1
                FROM organization.organizations AS organization_record
                WHERE
                    organization_record.organization_id = p_organization_id
                    AND organization_record.status = 'ACTIVE'
                    AND organization_record.valid_from <= p_evaluated_at
                    AND (
                        organization_record.valid_until IS NULL
                        OR p_evaluated_at < organization_record.valid_until
                    )
            )
        );
$function$;

COMMENT ON FUNCTION access_control.session_context_is_locally_usable(
    uuid,
    uuid,
    uuid,
    uuid,
    uuid,
    text,
    timestamptz
) IS
    'Returns whether the supplied identity, optional device, Trust Provider, optional Platform Service, optional selected organization, environment, and authoritative time satisfy the locally owned session trust boundary. This is not an authorization decision.';

REVOKE ALL ON FUNCTION access_control.session_context_is_locally_usable(
    uuid,
    uuid,
    uuid,
    uuid,
    uuid,
    text,
    timestamptz
) FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- Atomic session establishment
-- ---------------------------------------------------------------------------

CREATE FUNCTION access_control.establish_session_from_authentication_assertion(
    p_assertion_id text,
    p_organization_id uuid,
    p_absolute_lifetime interval,
    p_inactivity_timeout interval,
    p_audience text,
    p_environment_key text,
    p_correlation_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SET search_path = pg_catalog, access_control
AS $function$
DECLARE
    v_evaluated_at timestamptz := pg_catalog.statement_timestamp();
    v_assertion access_control.authentication_assertions%ROWTYPE;
    v_consumed_assertion_id uuid;
    v_session_id uuid := gen_random_uuid();
BEGIN
    IF p_assertion_id IS NULL OR pg_catalog.btrim(p_assertion_id) = '' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Assertion identifier must not be empty';
    END IF;

    IF p_absolute_lifetime IS NULL
       OR p_absolute_lifetime <= interval '0 seconds' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Absolute session lifetime must be positive';
    END IF;

    IF p_inactivity_timeout IS NOT NULL
       AND (
            p_inactivity_timeout <= interval '0 seconds'
            OR p_inactivity_timeout > p_absolute_lifetime
       ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Inactivity timeout must be positive and no longer than the absolute lifetime';
    END IF;

    IF p_audience IS NULL OR pg_catalog.btrim(p_audience) = '' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Audience must not be empty';
    END IF;

    IF p_environment_key IS NULL
       OR p_environment_key !~ '^[a-z][a-z0-9_-]*$' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Environment key is invalid';
    END IF;

    SELECT assertion_record.*
    INTO v_assertion
    FROM access_control.authentication_assertions AS assertion_record
    WHERE
        assertion_record.assertion_id = pg_catalog.btrim(p_assertion_id)
        AND assertion_record.assertion_purpose = 'SESSION_ESTABLISHMENT'
        AND assertion_record.session_id IS NULL
        AND assertion_record.audience = p_audience
        AND assertion_record.environment_key = p_environment_key
        AND assertion_record.status = 'VERIFIED'
        AND assertion_record.received_at <= v_evaluated_at
        AND assertion_record.issued_at <= v_evaluated_at
        AND v_evaluated_at < assertion_record.expires_at
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_authorization_specification',
                MESSAGE = 'Session establishment is unavailable';
    END IF;

    IF NOT access_control.session_context_is_locally_usable(
        v_assertion.identity_id,
        v_assertion.device_id,
        v_assertion.trust_provider_id,
        v_assertion.service_id,
        p_organization_id,
        v_assertion.environment_key,
        v_evaluated_at
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_authorization_specification',
                MESSAGE = 'Session establishment is unavailable';
    END IF;

    BEGIN
        v_consumed_assertion_id :=
            access_control.consume_authentication_assertion(
                v_assertion.assertion_id,
                'SESSION_ESTABLISHMENT',
                v_assertion.trust_provider_id,
                v_assertion.identity_id,
                v_assertion.device_id,
                NULL,
                v_assertion.service_id,
                v_assertion.audience,
                v_assertion.environment_key
            );
    EXCEPTION
        WHEN SQLSTATE '28000' THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = 'invalid_authorization_specification',
                    MESSAGE = 'Session establishment is unavailable';
    END;

    INSERT INTO access_control.sessions (
        session_id,
        identity_id,
        organization_id,
        device_id,
        trust_provider_id,
        service_id,
        status,
        authenticated_at,
        expires_at,
        inactivity_timeout,
        last_activity_at,
        correlation_id,
        establishment_authentication_assertion_id
    )
    VALUES (
        v_session_id,
        v_assertion.identity_id,
        p_organization_id,
        v_assertion.device_id,
        v_assertion.trust_provider_id,
        v_assertion.service_id,
        'ACTIVE',
        v_evaluated_at,
        v_evaluated_at + p_absolute_lifetime,
        p_inactivity_timeout,
        v_evaluated_at,
        COALESCE(p_correlation_id, gen_random_uuid()),
        v_consumed_assertion_id
    );

    INSERT INTO access_control.session_events (
        session_id,
        event_type,
        event_at,
        acting_identity_id,
        authentication_assertion_id,
        details
    )
    VALUES (
        v_session_id,
        'CREATED',
        v_evaluated_at,
        v_assertion.identity_id,
        v_consumed_assertion_id,
        pg_catalog.jsonb_build_object(
            'assertion_purpose',
            'SESSION_ESTABLISHMENT',
            'audience',
            v_assertion.audience,
            'environment_key',
            v_assertion.environment_key
        )
    );

    RETURN v_session_id;
END;
$function$;

COMMENT ON FUNCTION access_control.establish_session_from_authentication_assertion(
    text,
    uuid,
    interval,
    interval,
    text,
    text,
    uuid
) IS
    'Atomically revalidates current local trust state, consumes one exact-context VERIFIED SESSION_ESTABLISHMENT Authentication Assertion, creates one ACTIVE session derived from that assertion, and records one CREATED event at the same PostgreSQL statement time. This does not authorize a Protected Operation.';

REVOKE ALL ON FUNCTION access_control.establish_session_from_authentication_assertion(
    text,
    uuid,
    interval,
    interval,
    text,
    text,
    uuid
) FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- Atomic step-up completion
-- ---------------------------------------------------------------------------

CREATE FUNCTION access_control.complete_session_step_up(
    p_session_id uuid,
    p_assertion_id text,
    p_audience text,
    p_environment_key text
)
RETURNS boolean
LANGUAGE plpgsql
SET search_path = pg_catalog, access_control
AS $function$
DECLARE
    v_evaluated_at timestamptz := pg_catalog.statement_timestamp();
    v_session access_control.sessions%ROWTYPE;
    v_consumed_assertion_id uuid;
BEGIN
    IF p_session_id IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Session identifier must not be null';
    END IF;

    IF p_assertion_id IS NULL OR pg_catalog.btrim(p_assertion_id) = '' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Assertion identifier must not be empty';
    END IF;

    IF p_audience IS NULL OR pg_catalog.btrim(p_audience) = '' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Audience must not be empty';
    END IF;

    IF p_environment_key IS NULL
       OR p_environment_key !~ '^[a-z][a-z0-9_-]*$' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Environment key is invalid';
    END IF;

    SELECT session_record.*
    INTO v_session
    FROM access_control.sessions AS session_record
    WHERE
        session_record.session_id = p_session_id
        AND session_record.status = 'ACTIVE'
        AND session_record.authenticated_at <= v_evaluated_at
        AND v_evaluated_at < session_record.expires_at
        AND (
            session_record.inactivity_timeout IS NULL
            OR (
                COALESCE(
                    session_record.last_activity_at,
                    session_record.authenticated_at
                ) + session_record.inactivity_timeout
            ) > v_evaluated_at
        )
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_authorization_specification',
                MESSAGE = 'Session step-up is unavailable';
    END IF;

    IF NOT access_control.session_context_is_locally_usable(
        v_session.identity_id,
        v_session.device_id,
        v_session.trust_provider_id,
        v_session.service_id,
        v_session.organization_id,
        p_environment_key,
        v_evaluated_at
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_authorization_specification',
                MESSAGE = 'Session step-up is unavailable';
    END IF;

    BEGIN
        v_consumed_assertion_id :=
            access_control.consume_authentication_assertion(
                pg_catalog.btrim(p_assertion_id),
                'SESSION_STEP_UP',
                v_session.trust_provider_id,
                v_session.identity_id,
                v_session.device_id,
                v_session.session_id,
                v_session.service_id,
                p_audience,
                p_environment_key
            );
    EXCEPTION
        WHEN SQLSTATE '28000' THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = 'invalid_authorization_specification',
                    MESSAGE = 'Session step-up is unavailable';
    END;

    UPDATE access_control.sessions
    SET
        last_step_up_at = v_evaluated_at,
        latest_step_up_authentication_assertion_id =
            v_consumed_assertion_id
    WHERE session_id = v_session.session_id;

    INSERT INTO access_control.session_events (
        session_id,
        event_type,
        event_at,
        acting_identity_id,
        authentication_assertion_id,
        details
    )
    VALUES (
        v_session.session_id,
        'STEP_UP_COMPLETED',
        v_evaluated_at,
        v_session.identity_id,
        v_consumed_assertion_id,
        pg_catalog.jsonb_build_object(
            'assertion_purpose',
            'SESSION_STEP_UP',
            'audience',
            p_audience,
            'environment_key',
            p_environment_key
        )
    );

    RETURN true;
END;
$function$;

COMMENT ON FUNCTION access_control.complete_session_step_up(
    uuid,
    text,
    text,
    text
) IS
    'Atomically revalidates one active usable session, consumes one exact-context VERIFIED SESSION_STEP_UP Authentication Assertion, records fresh step-up evidence, and writes one STEP_UP_COMPLETED event without changing session bindings or expiration. This does not grant authority or permanent elevation.';

REVOKE ALL ON FUNCTION access_control.complete_session_step_up(
    uuid,
    text,
    text,
    text
) FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- Controlled activity checkpoint
-- ---------------------------------------------------------------------------

CREATE FUNCTION access_control.record_session_activity(
    p_session_id uuid,
    p_environment_key text
)
RETURNS boolean
LANGUAGE plpgsql
SET search_path = pg_catalog, access_control
AS $function$
DECLARE
    v_evaluated_at timestamptz := pg_catalog.statement_timestamp();
    v_session access_control.sessions%ROWTYPE;
BEGIN
    IF p_session_id IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Session identifier must not be null';
    END IF;

    IF p_environment_key IS NULL
       OR p_environment_key !~ '^[a-z][a-z0-9_-]*$' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Environment key is invalid';
    END IF;

    SELECT session_record.*
    INTO v_session
    FROM access_control.sessions AS session_record
    WHERE session_record.session_id = p_session_id
    FOR UPDATE;

    IF NOT FOUND
       OR v_session.status <> 'ACTIVE'
       OR v_evaluated_at < v_session.authenticated_at
       OR v_evaluated_at >= v_session.expires_at
       OR (
            v_session.inactivity_timeout IS NOT NULL
            AND v_evaluated_at >=
                COALESCE(
                    v_session.last_activity_at,
                    v_session.authenticated_at
                ) + v_session.inactivity_timeout
       )
       OR v_evaluated_at <= COALESCE(
            v_session.last_activity_at,
            v_session.authenticated_at
       ) THEN
        RETURN false;
    END IF;

    IF NOT access_control.session_context_is_locally_usable(
        v_session.identity_id,
        v_session.device_id,
        v_session.trust_provider_id,
        v_session.service_id,
        v_session.organization_id,
        p_environment_key,
        v_evaluated_at
    ) THEN
        RETURN false;
    END IF;

    UPDATE access_control.sessions
    SET last_activity_at = v_evaluated_at
    WHERE session_id = v_session.session_id;

    INSERT INTO access_control.session_events (
        session_id,
        event_type,
        event_at,
        acting_identity_id,
        details
    )
    VALUES (
        v_session.session_id,
        'ACTIVITY_RECORDED',
        v_evaluated_at,
        v_session.identity_id,
        pg_catalog.jsonb_build_object(
            'environment_key',
            p_environment_key
        )
    );

    RETURN true;
END;
$function$;

COMMENT ON FUNCTION access_control.record_session_activity(
    uuid,
    text
) IS
    'Atomically records a bounded activity checkpoint for one active session that remains within its absolute and inactivity limits and whose current locally owned trust context remains usable. The session mutation and ACTIVITY_RECORDED event use one PostgreSQL statement time. This does not authorize a Protected Operation.';

REVOKE ALL ON FUNCTION access_control.record_session_activity(
    uuid,
    text
) FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- Controlled lock
-- ---------------------------------------------------------------------------

CREATE FUNCTION access_control.lock_session(
    p_session_id uuid,
    p_reason_code text,
    p_acting_identity_id uuid DEFAULT NULL,
    p_actor_reference text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SET search_path = pg_catalog, access_control
AS $function$
DECLARE
    v_evaluated_at timestamptz := pg_catalog.statement_timestamp();
    v_session access_control.sessions%ROWTYPE;
    v_reason_code text;
    v_actor_reference text;
BEGIN
    IF p_session_id IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Session identifier must not be null';
    END IF;

    v_reason_code := pg_catalog.btrim(p_reason_code);

    IF p_reason_code IS NULL
       OR v_reason_code = ''
       OR v_reason_code !~ '^[A-Z][A-Z0-9_]*$' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Reason code is invalid';
    END IF;

    IF p_actor_reference IS NOT NULL THEN
        v_actor_reference := pg_catalog.btrim(p_actor_reference);

        IF v_actor_reference = '' THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = 'invalid_parameter_value',
                    MESSAGE = 'Actor reference must not be empty';
        END IF;
    END IF;

    IF pg_catalog.num_nonnulls(
        p_acting_identity_id,
        p_actor_reference
    ) > 1 THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'At most one actor context may be supplied';
    END IF;

    SELECT session_record.*
    INTO v_session
    FROM access_control.sessions AS session_record
    WHERE session_record.session_id = p_session_id
    FOR UPDATE;

    IF NOT FOUND OR v_session.status <> 'ACTIVE' THEN
        RETURN false;
    END IF;

    UPDATE access_control.sessions
    SET
        status = 'LOCKED',
        locked_at = v_evaluated_at
    WHERE session_id = v_session.session_id;

    INSERT INTO access_control.session_events (
        session_id,
        event_type,
        event_at,
        acting_identity_id,
        actor_reference,
        reason_code,
        details
    )
    VALUES (
        v_session.session_id,
        'LOCKED',
        v_evaluated_at,
        p_acting_identity_id,
        v_actor_reference,
        v_reason_code,
        pg_catalog.jsonb_build_object(
            'previous_status',
            v_session.status
        )
    );

    RETURN true;
END;
$function$;

COMMENT ON FUNCTION access_control.lock_session(
    uuid,
    text,
    uuid,
    text
) IS
    'Atomically transitions one ACTIVE session to LOCKED, records the authoritative lock time and stable reason code, and writes one attributable LOCKED event. Locking does not pause or extend absolute expiration.';

REVOKE ALL ON FUNCTION access_control.lock_session(
    uuid,
    text,
    uuid,
    text
) FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- Controlled administrative unlock
-- ---------------------------------------------------------------------------

CREATE FUNCTION access_control.unlock_session(
    p_session_id uuid,
    p_reason_code text,
    p_environment_key text,
    p_acting_identity_id uuid DEFAULT NULL,
    p_actor_reference text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SET search_path = pg_catalog, access_control
AS $function$
DECLARE
    v_evaluated_at timestamptz := pg_catalog.statement_timestamp();
    v_session access_control.sessions%ROWTYPE;
    v_reason_code text;
    v_actor_reference text;
BEGIN
    IF p_session_id IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Session identifier must not be null';
    END IF;

    v_reason_code := pg_catalog.btrim(p_reason_code);

    IF p_reason_code IS NULL
       OR v_reason_code = ''
       OR v_reason_code !~ '^[A-Z][A-Z0-9_]*$' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Reason code is invalid';
    END IF;

    IF p_environment_key IS NULL
       OR p_environment_key !~ '^[a-z][a-z0-9_-]*$' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Environment key is invalid';
    END IF;

    IF p_actor_reference IS NOT NULL THEN
        v_actor_reference := pg_catalog.btrim(p_actor_reference);

        IF v_actor_reference = '' THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = 'invalid_parameter_value',
                    MESSAGE = 'Actor reference must not be empty';
        END IF;
    END IF;

    IF pg_catalog.num_nonnulls(
        p_acting_identity_id,
        p_actor_reference
    ) <> 1 THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Exactly one administrative actor context is required';
    END IF;

    SELECT session_record.*
    INTO v_session
    FROM access_control.sessions AS session_record
    WHERE session_record.session_id = p_session_id
    FOR UPDATE;

    IF NOT FOUND
       OR v_session.status <> 'LOCKED'
       OR v_evaluated_at < v_session.authenticated_at
       OR v_evaluated_at >= v_session.expires_at
       OR (
            v_session.inactivity_timeout IS NOT NULL
            AND v_evaluated_at >=
                COALESCE(
                    v_session.last_activity_at,
                    v_session.authenticated_at
                ) + v_session.inactivity_timeout
       ) THEN
        RETURN false;
    END IF;

    IF NOT access_control.session_context_is_locally_usable(
        v_session.identity_id,
        v_session.device_id,
        v_session.trust_provider_id,
        v_session.service_id,
        v_session.organization_id,
        p_environment_key,
        v_evaluated_at
    ) THEN
        RETURN false;
    END IF;

    UPDATE access_control.sessions
    SET
        status = 'ACTIVE',
        locked_at = NULL,
        last_activity_at = v_evaluated_at
    WHERE session_id = v_session.session_id;

    INSERT INTO access_control.session_events (
        session_id,
        event_type,
        event_at,
        acting_identity_id,
        actor_reference,
        reason_code,
        details
    )
    VALUES (
        v_session.session_id,
        'UNLOCKED',
        v_evaluated_at,
        p_acting_identity_id,
        v_actor_reference,
        v_reason_code,
        pg_catalog.jsonb_build_object(
            'previous_status',
            v_session.status,
            'environment_key',
            p_environment_key
        )
    );

    RETURN true;
END;
$function$;

COMMENT ON FUNCTION access_control.unlock_session(
    uuid,
    text,
    text,
    uuid,
    text
) IS
    'Atomically performs an attributable administrative LOCKED-to-ACTIVE transition only while the session remains within its absolute and inactivity limits and its current locally owned trust context remains usable. Unlock records activity at the same PostgreSQL statement time but does not extend absolute expiration or create step-up evidence.';

REVOKE ALL ON FUNCTION access_control.unlock_session(
    uuid,
    text,
    text,
    uuid,
    text
) FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- Controlled expiration
-- ---------------------------------------------------------------------------

CREATE FUNCTION access_control.expire_session(
    p_session_id uuid,
    p_acting_identity_id uuid DEFAULT NULL,
    p_actor_reference text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SET search_path = pg_catalog, access_control
AS $function$
DECLARE
    v_evaluated_at timestamptz := pg_catalog.statement_timestamp();
    v_session access_control.sessions%ROWTYPE;
    v_actor_reference text;
    v_expiration_cause text;
    v_inactivity_deadline timestamptz;
BEGIN
    IF p_session_id IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Session identifier must not be null';
    END IF;

    IF p_actor_reference IS NOT NULL THEN
        v_actor_reference := pg_catalog.btrim(p_actor_reference);

        IF v_actor_reference = '' THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = 'invalid_parameter_value',
                    MESSAGE = 'Actor reference must not be empty';
        END IF;
    END IF;

    IF pg_catalog.num_nonnulls(
        p_acting_identity_id,
        p_actor_reference
    ) > 1 THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'At most one actor context may be supplied';
    END IF;

    SELECT session_record.*
    INTO v_session
    FROM access_control.sessions AS session_record
    WHERE session_record.session_id = p_session_id
    FOR UPDATE;

    IF NOT FOUND OR v_session.status NOT IN ('ACTIVE', 'LOCKED') THEN
        RETURN false;
    END IF;

    IF v_session.inactivity_timeout IS NOT NULL THEN
        v_inactivity_deadline :=
            COALESCE(
                v_session.last_activity_at,
                v_session.authenticated_at
            ) + v_session.inactivity_timeout;
    END IF;

    IF v_evaluated_at >= v_session.expires_at THEN
        v_expiration_cause := 'ABSOLUTE_TIMEOUT';
    ELSIF v_inactivity_deadline IS NOT NULL
          AND v_evaluated_at >= v_inactivity_deadline THEN
        v_expiration_cause := 'INACTIVITY_TIMEOUT';
    ELSE
        RETURN false;
    END IF;

    UPDATE access_control.sessions
    SET
        status = 'EXPIRED',
        locked_at = NULL,
        expired_at = v_evaluated_at
    WHERE session_id = v_session.session_id;

    INSERT INTO access_control.session_events (
        session_id,
        event_type,
        event_at,
        acting_identity_id,
        actor_reference,
        reason_code,
        details
    )
    VALUES (
        v_session.session_id,
        'EXPIRED',
        v_evaluated_at,
        p_acting_identity_id,
        v_actor_reference,
        v_expiration_cause,
        pg_catalog.jsonb_build_object(
            'previous_status',
            v_session.status,
            'absolute_deadline',
            v_session.expires_at,
            'inactivity_deadline',
            v_inactivity_deadline
        )
    );

    RETURN true;
END;
$function$;

COMMENT ON FUNCTION access_control.expire_session(
    uuid,
    uuid,
    text
) IS
    'Atomically transitions one ACTIVE or LOCKED session to terminal EXPIRED only after its absolute or inactivity deadline is reached, records the database-determined timeout cause, clears current lock state, and writes one matching EXPIRED event.';

REVOKE ALL ON FUNCTION access_control.expire_session(
    uuid,
    uuid,
    text
) FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- Controlled revocation
-- ---------------------------------------------------------------------------

CREATE FUNCTION access_control.revoke_session(
    p_session_id uuid,
    p_reason_code text,
    p_acting_identity_id uuid DEFAULT NULL,
    p_actor_reference text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SET search_path = pg_catalog, access_control
AS $function$
DECLARE
    v_evaluated_at timestamptz := pg_catalog.statement_timestamp();
    v_session access_control.sessions%ROWTYPE;
    v_reason_code text;
    v_actor_reference text;
BEGIN
    IF p_session_id IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Session identifier must not be null';
    END IF;

    v_reason_code := pg_catalog.btrim(p_reason_code);

    IF p_reason_code IS NULL
       OR v_reason_code = ''
       OR v_reason_code !~ '^[A-Z][A-Z0-9_]*$' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Reason code is invalid';
    END IF;

    IF p_actor_reference IS NOT NULL THEN
        v_actor_reference := pg_catalog.btrim(p_actor_reference);

        IF v_actor_reference = '' THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = 'invalid_parameter_value',
                    MESSAGE = 'Actor reference must not be empty';
        END IF;
    END IF;

    IF pg_catalog.num_nonnulls(
        p_acting_identity_id,
        p_actor_reference
    ) <> 1 THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Exactly one revocation actor context is required';
    END IF;

    SELECT session_record.*
    INTO v_session
    FROM access_control.sessions AS session_record
    WHERE session_record.session_id = p_session_id
    FOR UPDATE;

    IF NOT FOUND OR v_session.status NOT IN ('ACTIVE', 'LOCKED') THEN
        RETURN false;
    END IF;

    UPDATE access_control.sessions
    SET
        status = 'REVOKED',
        locked_at = NULL,
        revoked_at = v_evaluated_at
    WHERE session_id = v_session.session_id;

    INSERT INTO access_control.session_events (
        session_id,
        event_type,
        event_at,
        acting_identity_id,
        actor_reference,
        reason_code,
        details
    )
    VALUES (
        v_session.session_id,
        'REVOKED',
        v_evaluated_at,
        p_acting_identity_id,
        v_actor_reference,
        v_reason_code,
        pg_catalog.jsonb_build_object(
            'previous_status',
            v_session.status
        )
    );

    RETURN true;
END;
$function$;

COMMENT ON FUNCTION access_control.revoke_session(
    uuid,
    text,
    uuid,
    text
) IS
    'Atomically transitions one ACTIVE or LOCKED session to terminal REVOKED, requires exactly one attributable revocation actor context, clears current lock state, preserves prior authentication evidence, and writes one matching REVOKED event.';

REVOKE ALL ON FUNCTION access_control.revoke_session(
    uuid,
    text,
    uuid,
    text
) FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- Controlled termination
-- ---------------------------------------------------------------------------

CREATE FUNCTION access_control.terminate_session(
    p_session_id uuid,
    p_reason_code text,
    p_acting_identity_id uuid DEFAULT NULL,
    p_actor_reference text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SET search_path = pg_catalog, access_control
AS $function$
DECLARE
    v_evaluated_at timestamptz := pg_catalog.statement_timestamp();
    v_session access_control.sessions%ROWTYPE;
    v_reason_code text;
    v_actor_reference text;
BEGIN
    IF p_session_id IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Session identifier must not be null';
    END IF;

    v_reason_code := pg_catalog.btrim(p_reason_code);

    IF p_reason_code IS NULL
       OR v_reason_code = ''
       OR v_reason_code !~ '^[A-Z][A-Z0-9_]*$' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Reason code is invalid';
    END IF;

    IF p_actor_reference IS NOT NULL THEN
        v_actor_reference := pg_catalog.btrim(p_actor_reference);

        IF v_actor_reference = '' THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = 'invalid_parameter_value',
                    MESSAGE = 'Actor reference must not be empty';
        END IF;
    END IF;

    IF pg_catalog.num_nonnulls(
        p_acting_identity_id,
        p_actor_reference
    ) > 1 THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'At most one actor context may be supplied';
    END IF;

    SELECT session_record.*
    INTO v_session
    FROM access_control.sessions AS session_record
    WHERE session_record.session_id = p_session_id
    FOR UPDATE;

    IF NOT FOUND OR v_session.status NOT IN ('ACTIVE', 'LOCKED') THEN
        RETURN false;
    END IF;

    UPDATE access_control.sessions
    SET
        status = 'TERMINATED',
        locked_at = NULL,
        terminated_at = v_evaluated_at
    WHERE session_id = v_session.session_id;

    INSERT INTO access_control.session_events (
        session_id,
        event_type,
        event_at,
        acting_identity_id,
        actor_reference,
        reason_code,
        details
    )
    VALUES (
        v_session.session_id,
        'TERMINATED',
        v_evaluated_at,
        p_acting_identity_id,
        v_actor_reference,
        v_reason_code,
        pg_catalog.jsonb_build_object(
            'previous_status',
            v_session.status
        )
    );

    RETURN true;
END;
$function$;

COMMENT ON FUNCTION access_control.terminate_session(
    uuid,
    text,
    uuid,
    text
) IS
    'Atomically transitions one ACTIVE or LOCKED session to terminal TERMINATED, clears current lock state, preserves prior authentication evidence, and writes one matching TERMINATED event with a stable reason and optional attributable actor context.';

REVOKE ALL ON FUNCTION access_control.terminate_session(
    uuid,
    text,
    uuid,
    text
) FROM PUBLIC;

SELECT foundation_meta.register_migration(
    p_migration_id => '072_postgresql_session_control',
    p_migration_name => 'PostgreSQL session establishment, step-up, and lifecycle control',
    p_migration_layer => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes => 'Added Authentication Assertion linkage, current local trust revalidation, atomic session establishment and step-up completion, controlled activity, lock, administrative unlock, expiration, revocation, termination, and same-transaction session events without weakening migration 070.'
);

COMMIT;
