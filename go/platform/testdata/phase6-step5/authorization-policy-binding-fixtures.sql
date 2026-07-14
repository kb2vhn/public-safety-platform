\set ON_ERROR_STOP on

CREATE SCHEMA step5_test AUTHORIZATION postgres;
REVOKE ALL ON SCHEMA step5_test FROM PUBLIC;

CREATE TABLE step5_test.common_context (
    organization_id uuid NOT NULL,
    service_id uuid NOT NULL,
    purpose_definition_id uuid NOT NULL,
    operation_definition_id uuid NOT NULL,
    operation_key text NOT NULL
);

CREATE TABLE step5_test.fixtures (
    fixture_key text PRIMARY KEY,
    decision_id uuid NOT NULL UNIQUE
);

DO $setup_common$
DECLARE
    v_now timestamptz := pg_catalog.statement_timestamp();
    v_suffix text := pg_catalog.replace(pg_catalog.gen_random_uuid()::text, '-', '');
    v_organization_id uuid := pg_catalog.gen_random_uuid();
    v_service_id uuid := pg_catalog.gen_random_uuid();
    v_purpose_definition_id uuid := pg_catalog.gen_random_uuid();
    v_operation_definition_id uuid := pg_catalog.gen_random_uuid();
    v_operation_key text := 'step5_test.operation_' || v_suffix;
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
    ) VALUES (
        v_organization_id,
        'step5_test.organization_' || v_suffix,
        'Phase 6 Step 5 Test Organization',
        'Phase 6 Step 5 Test Organization',
        'TEST_ORGANIZATION',
        'ACTIVE',
        v_now - interval '1 day',
        v_now + interval '1 day',
        'phase6-step5-runtime-test'
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
    ) VALUES (
        v_service_id,
        'step5_test.service_' || v_suffix,
        'Phase 6 Step 5 Test Service',
        'TEST_SERVICE',
        v_organization_id,
        'ACTIVE',
        v_now - interval '1 day',
        v_now + interval '1 day',
        'phase6-step5-runtime-test'
    );

    INSERT INTO access_control.purpose_definitions (
        purpose_definition_id,
        purpose_key,
        title,
        description,
        status
    ) VALUES (
        v_purpose_definition_id,
        'step5_test.purpose_' || v_suffix,
        'Phase 6 Step 5 Test Purpose',
        'Phase 6 Step 5 Test Purpose',
        'ACTIVE'
    );

    INSERT INTO access_control.operation_definitions (
        operation_definition_id,
        operation_key,
        title,
        description,
        status
    ) VALUES (
        v_operation_definition_id,
        v_operation_key,
        'Phase 6 Step 5 Test Operation',
        'Phase 6 Step 5 Test Operation',
        'ACTIVE'
    );

    INSERT INTO step5_test.common_context (
        organization_id,
        service_id,
        purpose_definition_id,
        operation_definition_id,
        operation_key
    ) VALUES (
        v_organization_id,
        v_service_id,
        v_purpose_definition_id,
        v_operation_definition_id,
        v_operation_key
    );
END;
$setup_common$;

CREATE FUNCTION step5_test.create_fixture(
    p_fixture_key text,
    p_policy_count integer,
    p_expected_mismatch boolean DEFAULT false
)
RETURNS uuid
LANGUAGE plpgsql
SET search_path = pg_catalog, step5_test
AS $function$
DECLARE
    v_now timestamptz := pg_catalog.statement_timestamp();
    v_common step5_test.common_context%ROWTYPE;
    v_policy_id uuid;
    v_policy_version_id uuid;
    v_expected_policy_id uuid;
    v_expected_policy_version_id uuid;
    v_decision_id uuid := pg_catalog.gen_random_uuid();
    v_suffix text := pg_catalog.replace(pg_catalog.gen_random_uuid()::text, '-', '');
    v_index integer;
BEGIN
    SELECT * INTO STRICT v_common FROM step5_test.common_context;

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
            ) VALUES (
                v_policy_id,
                'step5_test.policy_' || p_fixture_key || '_' ||
                    v_index::text || '_' || v_suffix,
                'Phase 6 Step 5 Test Policy',
                'Phase 6 Step 5 Test Policy',
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
            ) VALUES (
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
                'phase6-step5-runtime-test',
                '1',
                100
            );
        END LOOP;
    END IF;

    IF p_expected_mismatch THEN
        v_expected_policy_id := pg_catalog.gen_random_uuid();
        v_expected_policy_version_id := pg_catalog.gen_random_uuid();

        INSERT INTO access_control.authorization_policies (
            authorization_policy_id,
            policy_key,
            title,
            description,
            status
        ) VALUES (
            v_expected_policy_id,
            'step5_test.expected_' || p_fixture_key || '_' || v_suffix,
            'Phase 6 Step 5 Expected Policy',
            'Phase 6 Step 5 Expected Policy',
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
        ) VALUES (
            v_expected_policy_version_id,
            v_expected_policy_id,
            1,
            'PROTECTED_OPERATION',
            v_common.service_id,
            v_common.purpose_definition_id,
            v_common.operation_definition_id,
            v_common.organization_id,
            false,
            true,
            'TEST_RESOURCE',
            p_fixture_key || '_different_target',
            false,
            false,
            'REUSABLE',
            interval '5 minutes',
            'ACTIVE',
            v_now - interval '1 day',
            v_now + interval '1 day',
            'phase6-step5-runtime-test',
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
    ) VALUES (
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
        'phase6-step5-runtime-test',
        '1',
        '081-step3'
    );

    INSERT INTO step5_test.fixtures (fixture_key, decision_id)
    VALUES (p_fixture_key, v_decision_id);

    RETURN v_decision_id;
END;
$function$;

DO $create_fixtures$
BEGIN
    PERFORM step5_test.create_fixture('selected', 1, false);
    PERFORM step5_test.create_fixture('missing_policy', 0, false);
    PERFORM step5_test.create_fixture('ambiguous_policy', 2, false);
    PERFORM step5_test.create_fixture('mismatch', 1, true);
    PERFORM step5_test.create_fixture('concurrent', 1, false);
END;
$create_fixtures$;

INSERT INTO step5_test.fixtures (fixture_key, decision_id)
VALUES ('nonexistent', pg_catalog.gen_random_uuid());

SELECT fixture_key || '|' || decision_id::text
FROM step5_test.fixtures
ORDER BY fixture_key;
