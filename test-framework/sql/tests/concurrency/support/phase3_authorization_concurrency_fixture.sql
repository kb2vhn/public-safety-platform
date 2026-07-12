\set ON_ERROR_STOP on

-- Test-only Phase 3 authorization concurrency fixture support.
-- This file is read into the same psql connection that creates each fixture,
-- because the accepted helper functions use per-connection pg_temp tables.

CREATE TEMP TABLE step4_common (
    provider_id uuid NOT NULL,
    device_id uuid NOT NULL,
    identity_id uuid NOT NULL,
    organization_id uuid NOT NULL,
    service_id uuid NOT NULL,
    purpose_definition_id uuid NOT NULL,
    operation_definition_id uuid NOT NULL,
    operation_key text NOT NULL
) ON COMMIT PRESERVE ROWS;

CREATE TEMP TABLE step4_lease_fixtures (
    fixture_key text PRIMARY KEY,
    decision_id uuid NOT NULL,
    use_decision_id uuid,
    session_id uuid NOT NULL,
    policy_version_id uuid NOT NULL,
    lease_id uuid,
    secret text NOT NULL,
    use_mode text NOT NULL,
    usage_limit integer
) ON COMMIT PRESERVE ROWS;

DO $setup_common$
DECLARE
    v_now timestamptz := pg_catalog.statement_timestamp();
    v_suffix text := pg_catalog.replace(pg_catalog.gen_random_uuid()::text, '-', '');
    v_provider_id uuid := pg_catalog.gen_random_uuid();
    v_device_id uuid := pg_catalog.gen_random_uuid();
    v_person_id uuid := pg_catalog.gen_random_uuid();
    v_identity_id uuid := pg_catalog.gen_random_uuid();
    v_organization_id uuid := pg_catalog.gen_random_uuid();
    v_service_id uuid := pg_catalog.gen_random_uuid();
    v_purpose_id uuid := pg_catalog.gen_random_uuid();
    v_operation_id uuid := pg_catalog.gen_random_uuid();
    v_operation_key text := 'sql_test.phase3_step6_operation_' || v_suffix;
BEGIN
    INSERT INTO trust.trust_providers (
        trust_provider_id, provider_key, display_name, provider_type,
        environment_key, status, valid_from, valid_until, created_by_reference
    ) VALUES (
        v_provider_id, 'sql_test.phase3_step6_provider_' || v_suffix,
        'SQL Test Phase 3 Step 6 Provider', 'IDENTITY_PROVIDER', 'test',
        'ACTIVE', v_now - interval '1 day', v_now + interval '1 day', 'sql_test'
    );

    INSERT INTO trust.devices (
        device_id, device_key, device_type, status, enrolled_at,
        trusted_from, trusted_until, created_by_reference
    ) VALUES (
        v_device_id, 'sql_test.phase3_step6_device_' || v_suffix,
        'WORKSTATION', 'TRUSTED', v_now - interval '1 day',
        v_now - interval '1 day', v_now + interval '1 day', 'sql_test'
    );

    INSERT INTO identity.persons (
        person_id, person_key, display_name, status, created_by_reference
    ) VALUES (
        v_person_id, 'sql_test.phase3_step6_person_' || v_suffix,
        'SQL Test Phase 3 Step 6 Person', 'ACTIVE', 'sql_test'
    );

    INSERT INTO identity.identities (
        identity_id, identity_key, identity_type, person_id, status,
        assurance_level, valid_from, valid_until, created_by_reference
    ) VALUES (
        v_identity_id, 'sql_test.phase3_step6_identity_' || v_suffix,
        'HUMAN', v_person_id, 'ACTIVE', 'TEST',
        v_now - interval '1 day', v_now + interval '1 day', 'sql_test'
    );

    INSERT INTO organization.organizations (
        organization_id, organization_key, legal_name, display_name,
        organization_type, status, valid_from, valid_until,
        created_by_reference
    ) VALUES (
        v_organization_id, 'sql_test.phase3_step6_org_' || v_suffix,
        'SQL Test Phase 3 Step 6 Organization',
        'SQL Test Phase 3 Step 6 Organization', 'TEST_ORGANIZATION',
        'ACTIVE', v_now - interval '1 day', v_now + interval '1 day', 'sql_test'
    );

    INSERT INTO service.platform_services (
        service_id, service_key, display_name, service_type,
        service_owner_organization_id, status, valid_from, valid_until,
        created_by_reference
    ) VALUES (
        v_service_id, 'sql_test.phase3_step6_service_' || v_suffix,
        'SQL Test Phase 3 Step 6 Service', 'TEST_SERVICE',
        v_organization_id, 'ACTIVE', v_now - interval '1 day',
        v_now + interval '1 day', 'sql_test'
    );

    INSERT INTO access_control.purpose_definitions (
        purpose_definition_id, purpose_key, title, description, status
    ) VALUES (
        v_purpose_id, 'sql_test.phase3_step6_purpose_' || v_suffix,
        'SQL Test Phase 3 Step 6 Purpose',
        'SQL Test Phase 3 Step 6 Purpose', 'ACTIVE'
    );

    INSERT INTO access_control.operation_definitions (
        operation_definition_id, operation_key, title, description, status
    ) VALUES (
        v_operation_id, v_operation_key,
        'SQL Test Phase 3 Step 6 Operation',
        'SQL Test Phase 3 Step 6 Operation', 'ACTIVE'
    );

    INSERT INTO pg_temp.step4_common VALUES (
        v_provider_id, v_device_id, v_identity_id, v_organization_id,
        v_service_id, v_purpose_id, v_operation_id, v_operation_key
    );
END;
$setup_common$;
