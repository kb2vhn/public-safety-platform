
-- ============================================================================
-- Phase 3 Step 3 controlled policy selection and decision finalization
-- ============================================================================
--
-- Purpose:
-- Prove deterministic policy selection, policy binding, fail-closed policy
-- denial, exact stage closure, supporting-evidence requirements, computed
-- final results, finalization-once behavior, and the compatibility wrapper.
--
-- Authorization Lease issuance remains Phase 3 Step 4.
-- ============================================================================

SELECT sql_test.begin_file(
    '140_authorization_policy_selection_and_decision_finalization.sql'
);

CREATE TEMP TABLE step3_common (
    organization_id uuid NOT NULL,
    service_id uuid NOT NULL,
    purpose_definition_id uuid NOT NULL,
    operation_definition_id uuid NOT NULL,
    operation_key text NOT NULL
) ON COMMIT PRESERVE ROWS;

CREATE TEMP TABLE step3_fixtures (
    fixture_key text PRIMARY KEY,
    decision_id uuid NOT NULL UNIQUE,
    policy_version_id uuid,
    bind_result text,
    first_finalize_result boolean,
    second_finalize_result boolean
) ON COMMIT PRESERVE ROWS;

DO $setup_common$
DECLARE
    v_now timestamptz := pg_catalog.statement_timestamp();
    v_suffix text :=
        pg_catalog.replace(pg_catalog.gen_random_uuid()::text, '-', '');
    v_organization_id uuid := pg_catalog.gen_random_uuid();
    v_service_id uuid := pg_catalog.gen_random_uuid();
    v_purpose_definition_id uuid := pg_catalog.gen_random_uuid();
    v_operation_definition_id uuid := pg_catalog.gen_random_uuid();
    v_operation_key text :=
        'sql_test.phase3_step3_operation_' || v_suffix;
BEGIN
    INSERT INTO organization.organizations (
        organization_id,
        organization_key,
        legal_name,
        display_name,
        organization_type,
        status,
        valid_from,
        valid_until,
        created_by_reference
    )
    VALUES (
        v_organization_id,
        'sql_test.phase3_step3_org_' || v_suffix,
        'SQL Test Phase 3 Step 3 Organization',
        'SQL Test Phase 3 Step 3 Organization',
        'TEST_ORGANIZATION',
        'ACTIVE',
        v_now - interval '1 day',
        v_now + interval '1 day',
        'sql_test'
    );

    INSERT INTO service.platform_services (
        service_id,
        service_key,
        display_name,
        service_type,
        service_owner_organization_id,
        status,
        valid_from,
        valid_until,
        created_by_reference
    )
    VALUES (
        v_service_id,
        'sql_test.phase3_step3_service_' || v_suffix,
        'SQL Test Phase 3 Step 3 Service',
        'TEST_SERVICE',
        v_organization_id,
        'ACTIVE',
        v_now - interval '1 day',
        v_now + interval '1 day',
        'sql_test'
    );

    INSERT INTO access_control.purpose_definitions (
        purpose_definition_id,
        purpose_key,
        title,
        description,
        status
    )
    VALUES (
        v_purpose_definition_id,
        'sql_test.phase3_step3_purpose_' || v_suffix,
        'SQL Test Phase 3 Step 3 Purpose',
        'SQL Test Phase 3 Step 3 Purpose',
        'ACTIVE'
    );

    INSERT INTO access_control.operation_definitions (
        operation_definition_id,
        operation_key,
        title,
        description,
        status
    )
    VALUES (
        v_operation_definition_id,
        v_operation_key,
        'SQL Test Phase 3 Step 3 Operation',
        'SQL Test Phase 3 Step 3 Operation',
        'ACTIVE'
    );

    INSERT INTO pg_temp.step3_common (
        organization_id,
        service_id,
        purpose_definition_id,
        operation_definition_id,
        operation_key
    )
    VALUES (
        v_organization_id,
        v_service_id,
        v_purpose_definition_id,
        v_operation_definition_id,
        v_operation_key
    );
END;
$setup_common$;

CREATE FUNCTION sql_test.create_phase3_step3_fixture(
    p_fixture_key text,
    p_policy_count integer,
    p_required_result text,
    p_optional_mode text,
    p_supporting_record_required boolean,
    p_add_supporting_record boolean,
    p_expected_mismatch boolean DEFAULT false
)
RETURNS uuid
LANGUAGE plpgsql
SET search_path = pg_catalog, sql_test
AS $function$
DECLARE
    v_now timestamptz := pg_catalog.statement_timestamp();
    v_common pg_temp.step3_common%ROWTYPE;
    v_policy_id uuid;
    v_policy_version_id uuid;
    v_expected_policy_version_id uuid;
    v_required_stage_id uuid;
    v_optional_stage_id uuid;
    v_decision_id uuid := pg_catalog.gen_random_uuid();
    v_evaluation_id uuid;
    v_suffix text :=
        pg_catalog.replace(pg_catalog.gen_random_uuid()::text, '-', '');
    v_index integer;
    v_bind_result text;
BEGIN
    SELECT * INTO STRICT v_common FROM pg_temp.step3_common;

    IF p_policy_count > 0 THEN
        FOR v_index IN 1..p_policy_count LOOP
            v_policy_id := pg_catalog.gen_random_uuid();
        v_policy_version_id := pg_catalog.gen_random_uuid();

        INSERT INTO access_control.authorization_policies (
            authorization_policy_id,
            policy_key,
            title,
            description,
            status
        )
        VALUES (
            v_policy_id,
            'sql_test.phase3_step3_policy_' || p_fixture_key ||
                '_' || v_index::text || '_' || v_suffix,
            'SQL Test Phase 3 Step 3 Policy',
            'SQL Test Phase 3 Step 3 Policy',
            'ACTIVE'
        );

        INSERT INTO access_control.authorization_policy_versions (
            authorization_policy_version_id,
            authorization_policy_id,
            version_number,
            decision_class,
            service_id,
            purpose_definition_id,
            operation_definition_id,
            requester_organization_id,
            governed_scope_required,
            protected_target_required,
            protected_target_type,
            protected_target_reference,
            session_required,
            eligibility_required,
            lease_use_mode,
            lease_lifetime,
            status,
            valid_from,
            valid_until,
            governing_document_reference,
            governing_document_version,
            selection_priority
        )
        VALUES (
            v_policy_version_id,
            v_policy_id,
            1,
            'PROTECTED_OPERATION',
            v_common.service_id,
            v_common.purpose_definition_id,
            v_common.operation_definition_id,
            v_common.organization_id,
            false,
            true,
            'TEST_RESOURCE',
            p_fixture_key,
            false,
            false,
            'REUSABLE',
            interval '5 minutes',
            'ACTIVE',
            v_now - interval '1 day',
            v_now + interval '1 day',
            'sql-test-policy',
            '1',
            100
        );

        IF v_index = 1 THEN
            v_required_stage_id := pg_catalog.gen_random_uuid();
            v_optional_stage_id := pg_catalog.gen_random_uuid();

            INSERT INTO
                access_control.authorization_policy_stage_requirements (
                    authorization_policy_stage_requirement_id,
                    authorization_policy_version_id,
                    stage_order,
                    stage_key,
                    required,
                    not_required_reason_code,
                    not_required_rule_reference,
                    supporting_record_required
                )
            VALUES
                (
                    v_required_stage_id,
                    v_policy_version_id,
                    1,
                    'REQUEST_CONTEXT',
                    true,
                    NULL,
                    NULL,
                    p_supporting_record_required
                ),
                (
                    v_optional_stage_id,
                    v_policy_version_id,
                    2,
                    'APPROVAL',
                    false,
                    'APPROVAL_NOT_REQUIRED',
                    'sql-test-rule-approval-not-required',
                    false
                );
            END IF;
        END LOOP;
    END IF;

    IF p_expected_mismatch THEN
        v_expected_policy_version_id := pg_catalog.gen_random_uuid();
        v_policy_id := pg_catalog.gen_random_uuid();

        INSERT INTO access_control.authorization_policies (
            authorization_policy_id,
            policy_key,
            title,
            description,
            status
        )
        VALUES (
            v_policy_id,
            'sql_test.phase3_step3_expected_' || p_fixture_key ||
                '_' || v_suffix,
            'SQL Test Expected Policy',
            'SQL Test Expected Policy',
            'ACTIVE'
        );

        INSERT INTO access_control.authorization_policy_versions (
            authorization_policy_version_id,
            authorization_policy_id,
            version_number,
            decision_class,
            service_id,
            purpose_definition_id,
            operation_definition_id,
            requester_organization_id,
            governed_scope_required,
            protected_target_required,
            protected_target_type,
            protected_target_reference,
            session_required,
            eligibility_required,
            lease_use_mode,
            lease_lifetime,
            status,
            valid_from,
            valid_until,
            governing_document_reference,
            governing_document_version,
            selection_priority
        )
        VALUES (
            v_expected_policy_version_id,
            v_policy_id,
            1,
            'PROTECTED_OPERATION',
            v_common.service_id,
            v_common.purpose_definition_id,
            v_common.operation_definition_id,
            v_common.organization_id,
            false,
            true,
            'TEST_RESOURCE',
            p_fixture_key || '_other',
            false,
            false,
            'REUSABLE',
            interval '5 minutes',
            'ACTIVE',
            v_now - interval '1 day',
            v_now + interval '1 day',
            'sql-test-expected-policy',
            '1',
            100
        );
    END IF;

    INSERT INTO decision.decision_records (
        decision_id,
        request_id,
        correlation_id,
        decision_class,
        requester_organization_id,
        expected_authorization_policy_version_id,
        service_id,
        purpose_definition_id,
        operation_definition_id,
        operation_key,
        protected_target_type,
        protected_target_reference,
        requested_at,
        evaluated_at,
        evaluator_name,
        evaluator_version,
        database_schema_version
    )
    VALUES (
        v_decision_id,
        pg_catalog.gen_random_uuid(),
        pg_catalog.gen_random_uuid(),
        'PROTECTED_OPERATION',
        v_common.organization_id,
        v_expected_policy_version_id,
        v_common.service_id,
        v_common.purpose_definition_id,
        v_common.operation_definition_id,
        v_common.operation_key,
        'TEST_RESOURCE',
        p_fixture_key,
        v_now,
        v_now,
        'sql_test.phase3_step3',
        '1',
        '081-step3'
    );

    v_bind_result := decision.bind_authorization_policy(v_decision_id);

    INSERT INTO pg_temp.step3_fixtures (
        fixture_key,
        decision_id,
        policy_version_id,
        bind_result
    )
    SELECT
        p_fixture_key,
        v_decision_id,
        decision_record.authorization_policy_version_id,
        v_bind_result
    FROM decision.decision_records AS decision_record
    WHERE decision_record.decision_id = v_decision_id;

    IF v_bind_result <> 'AUTHORIZATION_POLICY_SELECTED' THEN
        RETURN v_decision_id;
    END IF;

    IF p_required_result IS NOT NULL THEN
        v_evaluation_id := pg_catalog.gen_random_uuid();

        INSERT INTO decision.evaluation_records (
            evaluation_id,
            decision_id,
            evaluation_order,
            evaluation_key,
            required,
            result,
            reason_code,
            evaluated_at,
            authorization_policy_version_id,
            authorization_policy_stage_requirement_id
        )
        VALUES (
            v_evaluation_id,
            v_decision_id,
            1,
            'REQUEST_CONTEXT',
            true,
            p_required_result,
            CASE p_required_result
                WHEN 'PASS' THEN 'REQUEST_CONTEXT_VALID'
                WHEN 'FAIL' THEN 'REQUEST_CONTEXT_FAILED'
                ELSE 'REQUEST_CONTEXT_NOT_EVALUATED'
            END,
            v_now,
            v_policy_version_id,
            v_required_stage_id
        );

        IF p_add_supporting_record THEN
            INSERT INTO decision.supporting_records (
                evaluation_id,
                record_type,
                record_id,
                record_version,
                required_for_result
            )
            VALUES (
                v_evaluation_id,
                'REQUEST_CONTEXT',
                p_fixture_key,
                '1',
                true
            );
        END IF;
    END IF;

    IF p_optional_mode = 'VALID_NOT_REQUIRED' THEN
        INSERT INTO decision.evaluation_records (
            decision_id,
            evaluation_order,
            evaluation_key,
            required,
            result,
            reason_code,
            evaluated_at,
            authorization_policy_version_id,
            authorization_policy_stage_requirement_id,
            policy_rule_reference
        )
        VALUES (
            v_decision_id,
            2,
            'APPROVAL',
            false,
            'NOT_REQUIRED',
            'APPROVAL_NOT_REQUIRED',
            v_now,
            v_policy_version_id,
            v_optional_stage_id,
            'sql-test-rule-approval-not-required'
        );
    ELSIF p_optional_mode = 'INVALID_NOT_REQUIRED' THEN
        INSERT INTO decision.evaluation_records (
            decision_id,
            evaluation_order,
            evaluation_key,
            required,
            result,
            reason_code,
            evaluated_at,
            authorization_policy_version_id,
            authorization_policy_stage_requirement_id,
            policy_rule_reference
        )
        VALUES (
            v_decision_id,
            2,
            'APPROVAL',
            false,
            'NOT_REQUIRED',
            'WRONG_NOT_REQUIRED_REASON',
            v_now,
            v_policy_version_id,
            v_optional_stage_id,
            'wrong-rule-reference'
        );
    ELSIF p_optional_mode = 'PASS' THEN
        INSERT INTO decision.evaluation_records (
            decision_id,
            evaluation_order,
            evaluation_key,
            required,
            result,
            reason_code,
            evaluated_at,
            authorization_policy_version_id,
            authorization_policy_stage_requirement_id
        )
        VALUES (
            v_decision_id,
            2,
            'APPROVAL',
            false,
            'PASS',
            'APPROVAL_VALID',
            v_now,
            v_policy_version_id,
            v_optional_stage_id
        );
    END IF;

    RETURN v_decision_id;
END;
$function$;

DO $create_and_finalize$
DECLARE
    v_decision_id uuid;
    v_first boolean;
    v_second boolean;
BEGIN
    v_decision_id := sql_test.create_phase3_step3_fixture(
        'allow',
        1,
        'PASS',
        'VALID_NOT_REQUIRED',
        true,
        true
    );
    v_first := decision.finalize_authorization_decision(v_decision_id);
    v_second := decision.finalize_authorization_decision(v_decision_id);
    UPDATE pg_temp.step3_fixtures
    SET first_finalize_result = v_first,
        second_finalize_result = v_second
    WHERE fixture_key = 'allow';

    v_decision_id := sql_test.create_phase3_step3_fixture(
        'missing_policy',
        0,
        NULL,
        'MISSING',
        false,
        false
    );

    v_decision_id := sql_test.create_phase3_step3_fixture(
        'ambiguous_policy',
        2,
        NULL,
        'MISSING',
        false,
        false
    );

    v_decision_id := sql_test.create_phase3_step3_fixture(
        'expected_mismatch',
        1,
        NULL,
        'MISSING',
        false,
        false,
        true
    );

    v_decision_id := sql_test.create_phase3_step3_fixture(
        'missing_required',
        1,
        NULL,
        'VALID_NOT_REQUIRED',
        false,
        false
    );
    v_first := decision.finalize_authorization_decision(v_decision_id);
    UPDATE pg_temp.step3_fixtures
    SET first_finalize_result = v_first
    WHERE fixture_key = 'missing_required';

    v_decision_id := sql_test.create_phase3_step3_fixture(
        'required_fail',
        1,
        'FAIL',
        'VALID_NOT_REQUIRED',
        false,
        false
    );
    v_first := decision.finalize_authorization_decision(v_decision_id);
    UPDATE pg_temp.step3_fixtures
    SET first_finalize_result = v_first
    WHERE fixture_key = 'required_fail';

    v_decision_id := sql_test.create_phase3_step3_fixture(
        'required_not_evaluated',
        1,
        'NOT_EVALUATED',
        'VALID_NOT_REQUIRED',
        false,
        false
    );
    v_first := decision.finalize_authorization_decision(v_decision_id);
    UPDATE pg_temp.step3_fixtures
    SET first_finalize_result = v_first
    WHERE fixture_key = 'required_not_evaluated';

    v_decision_id := sql_test.create_phase3_step3_fixture(
        'invalid_not_required',
        1,
        'PASS',
        'INVALID_NOT_REQUIRED',
        false,
        false
    );
    v_first := decision.finalize_authorization_decision(v_decision_id);
    UPDATE pg_temp.step3_fixtures
    SET first_finalize_result = v_first
    WHERE fixture_key = 'invalid_not_required';

    v_decision_id := sql_test.create_phase3_step3_fixture(
        'missing_support',
        1,
        'PASS',
        'VALID_NOT_REQUIRED',
        true,
        false
    );
    v_first := decision.finalize_authorization_decision(v_decision_id);
    UPDATE pg_temp.step3_fixtures
    SET first_finalize_result = v_first
    WHERE fixture_key = 'missing_support';

    v_decision_id := sql_test.create_phase3_step3_fixture(
        'legacy_wrapper',
        1,
        'PASS',
        'VALID_NOT_REQUIRED',
        false,
        false
    );
END;
$create_and_finalize$;

SELECT sql_test.assert_true(
    'Policy resolver routine exists',
    to_regprocedure(
        'decision.resolve_authorization_policy(uuid)'
    ) IS NOT NULL
);

SELECT sql_test.assert_true(
    'Controlled policy-binding routine exists',
    to_regprocedure(
        'decision.bind_authorization_policy(uuid)'
    ) IS NOT NULL
);

SELECT sql_test.assert_true(
    'Controlled authorization finalizer exists',
    to_regprocedure(
        'decision.finalize_authorization_decision(uuid)'
    ) IS NOT NULL
);

SELECT sql_test.assert_true(
    'Unique exact-context policy is selected and bound',
    EXISTS (
        SELECT 1
        FROM pg_temp.step3_fixtures
        WHERE fixture_key = 'allow'
          AND bind_result = 'AUTHORIZATION_POLICY_SELECTED'
          AND policy_version_id IS NOT NULL
    )
);

SELECT sql_test.assert_true(
    'Complete required stages finalize as ALLOW',
    EXISTS (
        SELECT 1
        FROM pg_temp.step3_fixtures AS fixture
        JOIN decision.decision_records AS decision_record
          ON decision_record.decision_id = fixture.decision_id
        WHERE fixture.fixture_key = 'allow'
          AND fixture.first_finalize_result
          AND decision_record.record_status = 'FINALIZED'
          AND decision_record.final_result = 'ALLOW'
          AND decision_record.primary_reason_code =
              'AUTHORIZATION_DECISION_ALLOWED'
    )
);

SELECT sql_test.assert_true(
    'Authorization finalization stores a terminal timestamp',
    EXISTS (
        SELECT 1
        FROM pg_temp.step3_fixtures AS fixture
        JOIN decision.decision_records AS decision_record
          ON decision_record.decision_id = fixture.decision_id
        WHERE fixture.fixture_key = 'allow'
          AND decision_record.finalized_at IS NOT NULL
          AND decision_record.finalized_at >=
              decision_record.evaluated_at
    )
);

SELECT sql_test.assert_true(
    'A finalized decision cannot finalize a second time',
    EXISTS (
        SELECT 1
        FROM pg_temp.step3_fixtures
        WHERE fixture_key = 'allow'
          AND second_finalize_result IS FALSE
    )
);

SELECT sql_test.assert_true(
    'Missing applicable policy persists a DENY',
    EXISTS (
        SELECT 1
        FROM pg_temp.step3_fixtures AS fixture
        JOIN decision.decision_records AS decision_record
          ON decision_record.decision_id = fixture.decision_id
        WHERE fixture.fixture_key = 'missing_policy'
          AND fixture.bind_result = 'AUTHORIZATION_POLICY_NOT_FOUND'
          AND decision_record.final_result = 'DENY'
          AND decision_record.primary_reason_code =
              'AUTHORIZATION_POLICY_NOT_FOUND'
    )
);

SELECT sql_test.assert_true(
    'Ambiguous applicable policy persists a DENY',
    EXISTS (
        SELECT 1
        FROM pg_temp.step3_fixtures AS fixture
        JOIN decision.decision_records AS decision_record
          ON decision_record.decision_id = fixture.decision_id
        WHERE fixture.fixture_key = 'ambiguous_policy'
          AND fixture.bind_result = 'AUTHORIZATION_POLICY_AMBIGUOUS'
          AND decision_record.final_result = 'DENY'
          AND decision_record.primary_reason_code =
              'AUTHORIZATION_POLICY_AMBIGUOUS'
    )
);

SELECT sql_test.assert_true(
    'Caller expected-policy mismatch persists a DENY',
    EXISTS (
        SELECT 1
        FROM pg_temp.step3_fixtures AS fixture
        JOIN decision.decision_records AS decision_record
          ON decision_record.decision_id = fixture.decision_id
        WHERE fixture.fixture_key = 'expected_mismatch'
          AND fixture.bind_result =
              'AUTHORIZATION_POLICY_CONTEXT_MISMATCH'
          AND decision_record.final_result = 'DENY'
          AND decision_record.primary_reason_code =
              'AUTHORIZATION_POLICY_CONTEXT_MISMATCH'
    )
);

SELECT sql_test.assert_true(
    'Missing policy stage denies finalization',
    EXISTS (
        SELECT 1
        FROM pg_temp.step3_fixtures AS fixture
        JOIN decision.decision_records AS decision_record
          ON decision_record.decision_id = fixture.decision_id
        WHERE fixture.fixture_key = 'missing_required'
          AND decision_record.final_result = 'DENY'
          AND decision_record.primary_reason_code =
              'AUTHORIZATION_DECISION_INCOMPLETE'
    )
);

SELECT sql_test.assert_true(
    'Required FAIL stage denies finalization',
    EXISTS (
        SELECT 1
        FROM pg_temp.step3_fixtures AS fixture
        JOIN decision.decision_records AS decision_record
          ON decision_record.decision_id = fixture.decision_id
        WHERE fixture.fixture_key = 'required_fail'
          AND decision_record.final_result = 'DENY'
          AND decision_record.primary_reason_code =
              'AUTHORIZATION_DECISION_REQUIRED_STAGE_FAILED'
    )
);

SELECT sql_test.assert_true(
    'Required NOT_EVALUATED stage denies finalization',
    EXISTS (
        SELECT 1
        FROM pg_temp.step3_fixtures AS fixture
        JOIN decision.decision_records AS decision_record
          ON decision_record.decision_id = fixture.decision_id
        WHERE fixture.fixture_key = 'required_not_evaluated'
          AND decision_record.final_result = 'DENY'
          AND decision_record.primary_reason_code =
              'AUTHORIZATION_DECISION_REQUIRED_STAGE_NOT_EVALUATED'
    )
);

SELECT sql_test.assert_true(
    'Incorrect NOT_REQUIRED policy rule denies finalization',
    EXISTS (
        SELECT 1
        FROM pg_temp.step3_fixtures AS fixture
        JOIN decision.decision_records AS decision_record
          ON decision_record.decision_id = fixture.decision_id
        WHERE fixture.fixture_key = 'invalid_not_required'
          AND decision_record.final_result = 'DENY'
          AND decision_record.primary_reason_code =
              'AUTHORIZATION_DECISION_NOT_REQUIRED_RULE_MISSING'
    )
);

SELECT sql_test.assert_true(
    'Missing required supporting evidence denies finalization',
    EXISTS (
        SELECT 1
        FROM pg_temp.step3_fixtures AS fixture
        JOIN decision.decision_records AS decision_record
          ON decision_record.decision_id = fixture.decision_id
        WHERE fixture.fixture_key = 'missing_support'
          AND decision_record.final_result = 'DENY'
          AND decision_record.primary_reason_code =
              'AUTHORIZATION_DECISION_INCOMPLETE'
    )
);

SELECT sql_test.assert_true(
    'Step 3 finalization never issues an Authorization Lease',
    NOT EXISTS (
        SELECT 1
        FROM access_control.authorization_leases AS lease
        JOIN pg_temp.step3_fixtures AS fixture
          ON fixture.decision_id = lease.issuing_decision_id
    )
);

SELECT sql_test.assert_raises(
    'Legacy finalizer rejects a caller-supplied mismatched result',
    $sql$
        SELECT decision.finalize_decision(
            (
                SELECT decision_id
                FROM pg_temp.step3_fixtures
                WHERE fixture_key = 'legacy_wrapper'
            ),
            'DENY',
            'CALLER_CONTROLLED_RESULT'
        )
    $sql$,
    '23514'
);

SELECT sql_test.assert_true(
    'Legacy mismatch rollback leaves the Decision Record draft',
    EXISTS (
        SELECT 1
        FROM pg_temp.step3_fixtures AS fixture
        JOIN decision.decision_records AS decision_record
          ON decision_record.decision_id = fixture.decision_id
        WHERE fixture.fixture_key = 'legacy_wrapper'
          AND decision_record.record_status = 'DRAFT'
          AND decision_record.final_result IS NULL
    )
);

SELECT sql_test.assert_true(
    'All Step 3 routines are unavailable to PUBLIC',
    NOT EXISTS (
        SELECT 1
        FROM pg_proc AS routine
        JOIN pg_namespace AS routine_schema
          ON routine_schema.oid = routine.pronamespace
        CROSS JOIN LATERAL aclexplode(
            COALESCE(
                routine.proacl,
                acldefault('f', routine.proowner)
            )
        ) AS privilege
        WHERE routine_schema.nspname = 'decision'
          AND routine.proname IN (
              'resolve_authorization_policy',
              'bind_authorization_policy',
              'finalize_authorization_decision',
              'finalize_decision'
          )
          AND privilege.grantee = 0
          AND privilege.privilege_type = 'EXECUTE'
    )
);

SELECT sql_test.assert_true(
    'All Step 3 routines use a fixed trusted search path',
    NOT EXISTS (
        SELECT 1
        FROM pg_proc AS routine
        JOIN pg_namespace AS routine_schema
          ON routine_schema.oid = routine.pronamespace
        WHERE routine_schema.nspname = 'decision'
          AND routine.proname IN (
              'resolve_authorization_policy',
              'bind_authorization_policy',
              'finalize_authorization_decision',
              'finalize_decision'
          )
          AND NOT EXISTS (
              SELECT 1
              FROM unnest(routine.proconfig) AS setting
              WHERE setting LIKE 'search_path=pg_catalog,%'
          )
    )
);

SELECT sql_test.assert_true(
    'Step 3 adds no SECURITY DEFINER routine',
    NOT EXISTS (
        SELECT 1
        FROM pg_proc AS routine
        JOIN pg_namespace AS routine_schema
          ON routine_schema.oid = routine.pronamespace
        WHERE routine_schema.nspname = 'decision'
          AND routine.proname IN (
              'resolve_authorization_policy',
              'bind_authorization_policy',
              'finalize_authorization_decision',
              'finalize_decision'
          )
          AND routine.prosecdef
    )
);

SELECT sql_test.assert_true(
    'All Step 3 routines have catalog comments',
    NOT EXISTS (
        SELECT 1
        FROM pg_proc AS routine
        JOIN pg_namespace AS routine_schema
          ON routine_schema.oid = routine.pronamespace
        WHERE routine_schema.nspname = 'decision'
          AND routine.proname IN (
              'resolve_authorization_policy',
              'bind_authorization_policy',
              'finalize_authorization_decision',
              'finalize_decision'
          )
          AND obj_description(routine.oid, 'pg_proc') IS NULL
    )
);

SELECT sql_test.assert_true(
    'Policy resolution uses statement-owned Decision Record context',
    pg_get_functiondef(
        'decision.resolve_authorization_policy(uuid)'::regprocedure
    ) NOT ILIKE '%p_service_id%'
);

SELECT sql_test.assert_true(
    'Authoritative finalizer accepts no caller-supplied result',
    pg_get_function_arguments(
        'decision.finalize_authorization_decision(uuid)'::regprocedure
    ) = 'p_decision_id uuid'
);
