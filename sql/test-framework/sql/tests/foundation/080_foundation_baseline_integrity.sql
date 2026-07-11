-- Phase -1 Foundation baseline integrity behavior tests.

SELECT sql_test.begin_file('080_foundation_baseline_integrity.sql');

INSERT INTO trust.trust_providers (
    trust_provider_id,
    provider_key,
    display_name,
    provider_type,
    environment_key,
    status,
    valid_from,
    created_by_reference
)
VALUES (
    '10000000-0000-0000-0000-000000000001',
    'sql_test.provider',
    'SQL Test Provider',
    'IDENTITY_PROVIDER',
    'test',
    'ACTIVE',
    statement_timestamp() - interval '1 day',
    'sql-test'
);

INSERT INTO trust.certificate_authorities (
    certificate_authority_id,
    trust_provider_id,
    authority_key,
    subject_distinguished_name,
    serial_number_hex,
    sha256_fingerprint,
    public_key_algorithm,
    public_key_size_bits,
    signature_algorithm,
    is_root_authority,
    status,
    valid_from,
    valid_until,
    created_by_reference
)
VALUES (
    '10000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000001',
    'sql_test_ca',
    'CN=SQL Test CA',
    '01',
    repeat('a', 64),
    'RSA',
    4096,
    'SHA256-RSA',
    true,
    'ACTIVE',
    statement_timestamp() - interval '1 day',
    statement_timestamp() + interval '365 days',
    'sql-test'
);

INSERT INTO trust.devices (
    device_id,
    device_key,
    device_type,
    status,
    created_by_reference
)
VALUES
(
    '10000000-0000-0000-0000-000000000003',
    'sql_test.device',
    'WORKSTATION',
    'TRUSTED',
    'sql-test'
),
(
    '10000000-0000-0000-0000-000000000004',
    'sql_test.device.two',
    'WORKSTATION',
    'TRUSTED',
    'sql-test'
);

INSERT INTO trust.device_certificates (
    device_certificate_id,
    device_id,
    certificate_authority_id,
    certificate_role,
    subject_distinguished_name,
    serial_number_hex,
    sha256_fingerprint,
    public_key_algorithm,
    public_key_size_bits,
    signature_algorithm,
    status,
    valid_from,
    valid_until,
    first_seen_at,
    last_seen_at,
    created_by_reference
)
VALUES (
    '10000000-0000-0000-0000-000000000005',
    '10000000-0000-0000-0000-000000000003',
    '10000000-0000-0000-0000-000000000002',
    'CLIENT_AUTHENTICATION',
    'CN=SQL Test Device',
    '02',
    repeat('b', 64),
    'RSA',
    2048,
    'SHA256-RSA',
    'ACTIVE',
    statement_timestamp() - interval '1 day',
    statement_timestamp() + interval '30 days',
    statement_timestamp() - interval '1 hour',
    statement_timestamp(),
    'sql-test'
);

SELECT sql_test.assert_raises(
    'Revocation object type must match the referenced target',
    $statement$
    INSERT INTO trust.revocations (
        object_type,
        device_certificate_id,
        reason_code,
        effective_at,
        recorded_by_reference
    )
    VALUES (
        'DEVICE',
        '10000000-0000-0000-0000-000000000005',
        'SQL_TEST',
        statement_timestamp(),
        'sql-test'
    )
    $statement$,
    '23514'
);

SELECT sql_test.assert_raises(
    'Certificate authority public key size must be positive',
    $statement$
    INSERT INTO trust.certificate_authorities (
        trust_provider_id,
        authority_key,
        subject_distinguished_name,
        serial_number_hex,
        sha256_fingerprint,
        public_key_algorithm,
        public_key_size_bits,
        signature_algorithm,
        is_root_authority,
        status,
        valid_from,
        valid_until,
        created_by_reference
    )
    VALUES (
        '10000000-0000-0000-0000-000000000001',
        'invalid_key_size',
        'CN=Invalid Key Size',
        '03',
        repeat('c', 64),
        'RSA',
        0,
        'SHA256-RSA',
        false,
        'ACTIVE',
        statement_timestamp(),
        statement_timestamp() + interval '1 day',
        'sql-test'
    )
    $statement$,
    '23514'
);

INSERT INTO identity.persons (
    person_id,
    person_key,
    display_name,
    status,
    created_by_reference
)
VALUES
(
    '20000000-0000-0000-0000-000000000001',
    'sql_test.person.one',
    'SQL Test Person One',
    'ACTIVE',
    'sql-test'
),
(
    '20000000-0000-0000-0000-000000000002',
    'sql_test.person.two',
    'SQL Test Person Two',
    'ACTIVE',
    'sql-test'
);

INSERT INTO identity.identities (
    identity_id,
    identity_key,
    identity_type,
    person_id,
    status,
    valid_from,
    created_by_reference
)
VALUES (
    '20000000-0000-0000-0000-000000000003',
    'sql_test.identity.human',
    'HUMAN',
    '20000000-0000-0000-0000-000000000001',
    'ACTIVE',
    statement_timestamp() - interval '1 day',
    'sql-test'
);

INSERT INTO identity.identities (
    identity_id,
    identity_key,
    identity_type,
    service_device_id,
    status,
    valid_from,
    created_by_reference
)
VALUES (
    '20000000-0000-0000-0000-000000000004',
    'sql_test.identity.device',
    'DEVICE',
    '10000000-0000-0000-0000-000000000003',
    'ACTIVE',
    statement_timestamp() - interval '1 day',
    'sql-test'
);

SELECT sql_test.assert_raises(
    'DEVICE identity requires a device subject',
    $statement$
    INSERT INTO identity.identities (
        identity_key,
        identity_type,
        status,
        valid_from,
        created_by_reference
    )
    VALUES (
        'sql_test.identity.invalid_device',
        'DEVICE',
        'ACTIVE',
        statement_timestamp(),
        'sql-test'
    )
    $statement$,
    '23514'
);

INSERT INTO identity.provider_identity_mappings (
    identity_id,
    trust_provider_id,
    provider_subject,
    valid_from,
    valid_until,
    status,
    created_by_reference
)
VALUES (
    '20000000-0000-0000-0000-000000000003',
    '10000000-0000-0000-0000-000000000001',
    'sql-test-subject',
    statement_timestamp() - interval '10 days',
    statement_timestamp() - interval '1 day',
    'SUPERSEDED',
    'sql-test'
);

INSERT INTO identity.provider_identity_mappings (
    identity_id,
    trust_provider_id,
    provider_subject,
    valid_from,
    status,
    created_by_reference
)
VALUES (
    '20000000-0000-0000-0000-000000000003',
    '10000000-0000-0000-0000-000000000001',
    'sql-test-subject',
    statement_timestamp() - interval '1 day',
    'ACTIVE',
    'sql-test'
);

SELECT sql_test.assert_equal_bigint(
    'Provider identity mapping history can preserve multiple versions',
    (
        SELECT count(*)
        FROM identity.provider_identity_mappings
        WHERE trust_provider_id =
            '10000000-0000-0000-0000-000000000001'
          AND provider_subject = 'sql-test-subject'
    ),
    2
);

SELECT sql_test.assert_raises(
    'Only one current provider subject mapping may exist',
    $statement$
    INSERT INTO identity.provider_identity_mappings (
        identity_id,
        trust_provider_id,
        provider_subject,
        valid_from,
        status,
        created_by_reference
    )
    VALUES (
        '20000000-0000-0000-0000-000000000003',
        '10000000-0000-0000-0000-000000000001',
        'sql-test-subject',
        statement_timestamp(),
        'ACTIVE',
        'sql-test'
    )
    $statement$,
    '23505'
);

SELECT sql_test.assert_raises(
    'Identity suspension release cannot precede its effective time',
    $statement$
    INSERT INTO identity.identity_suspensions (
        identity_id,
        reason_code,
        effective_at,
        released_at,
        recorded_by_reference
    )
    VALUES (
        '20000000-0000-0000-0000-000000000003',
        'SQL_TEST',
        statement_timestamp(),
        statement_timestamp() - interval '1 hour',
        'sql-test'
    )
    $statement$,
    '23514'
);

INSERT INTO organization.organizations (
    organization_id,
    organization_key,
    legal_name,
    display_name,
    organization_type,
    status,
    valid_from,
    created_by_reference
)
VALUES
(
    '30000000-0000-0000-0000-000000000001',
    'sql_test.organization.one',
    'SQL Test Organization One',
    'SQL Test Organization One',
    'TEST',
    'ACTIVE',
    statement_timestamp() - interval '1 day',
    'sql-test'
),
(
    '30000000-0000-0000-0000-000000000002',
    'sql_test.organization.two',
    'SQL Test Organization Two',
    'SQL Test Organization Two',
    'TEST',
    'ACTIVE',
    statement_timestamp() - interval '1 day',
    'sql-test'
);

INSERT INTO organization.organizational_units (
    organizational_unit_id,
    organization_id,
    unit_key,
    display_name,
    status,
    valid_from
)
VALUES (
    '30000000-0000-0000-0000-000000000003',
    '30000000-0000-0000-0000-000000000001',
    'parent',
    'Parent Unit',
    'ACTIVE',
    statement_timestamp() - interval '1 day'
);

SELECT sql_test.assert_raises(
    'Organizational unit parent must belong to the same organization',
    $statement$
    INSERT INTO organization.organizational_units (
        organization_id,
        parent_unit_id,
        unit_key,
        display_name,
        status,
        valid_from
    )
    VALUES (
        '30000000-0000-0000-0000-000000000002',
        '30000000-0000-0000-0000-000000000003',
        'invalid_child',
        'Invalid Child',
        'ACTIVE',
        statement_timestamp()
    )
    $statement$,
    '23503'
);

INSERT INTO service.platform_services (
    service_id,
    service_key,
    display_name,
    service_type,
    service_owner_organization_id,
    status,
    valid_from,
    created_by_reference
)
VALUES (
    '40000000-0000-0000-0000-000000000001',
    'sql_test.service',
    'SQL Test Service',
    'TEST',
    '30000000-0000-0000-0000-000000000001',
    'ACTIVE',
    statement_timestamp() - interval '1 day',
    'sql-test'
);

INSERT INTO service.deployments (
    deployment_id,
    service_id,
    deployment_key,
    environment_key,
    platform_operator_organization_id,
    status,
    valid_from
)
VALUES (
    '40000000-0000-0000-0000-000000000002',
    '40000000-0000-0000-0000-000000000001',
    'test',
    'test',
    '30000000-0000-0000-0000-000000000001',
    'ACTIVE',
    statement_timestamp() - interval '1 day'
);

SELECT sql_test.assert_raises(
    'Configuration scope cannot identify both service and deployment',
    $statement$
    INSERT INTO service.configuration_items (
        service_id,
        deployment_id,
        configuration_scope,
        configuration_key,
        configuration_value,
        version_number,
        valid_from,
        approved_by_reference
    )
    VALUES (
        '40000000-0000-0000-0000-000000000001',
        '40000000-0000-0000-0000-000000000002',
        'SERVICE',
        'sql_test.invalid_scope',
        '{}'::jsonb,
        1,
        statement_timestamp(),
        'sql-test'
    )
    $statement$,
    '23514'
);

INSERT INTO service.participation_agreements (
    service_id,
    participating_organization_id,
    service_owner_organization_id,
    platform_operator_organization_id,
    agreement_key,
    version_number,
    status,
    valid_from,
    valid_until,
    governing_document_reference,
    governing_document_version,
    created_by_reference
)
VALUES
(
    '40000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000002',
    '30000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    'sql_test_agreement',
    1,
    'SUPERSEDED',
    statement_timestamp() - interval '10 days',
    statement_timestamp() - interval '1 day',
    'sql-test-document',
    '1',
    'sql-test'
),
(
    '40000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000002',
    '30000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    'sql_test_agreement',
    2,
    'ACTIVE',
    statement_timestamp() - interval '1 day',
    NULL,
    'sql-test-document',
    '2',
    'sql-test'
);

SELECT sql_test.assert_equal_bigint(
    'Participation agreement history can preserve multiple versions',
    (
        SELECT count(*)
        FROM service.participation_agreements
        WHERE service_id =
            '40000000-0000-0000-0000-000000000001'
          AND participating_organization_id =
            '30000000-0000-0000-0000-000000000002'
          AND agreement_key = 'sql_test_agreement'
    ),
    2
);

SELECT sql_test.assert_raises(
    'An organization cannot delegate authority to itself',
    $statement$
    INSERT INTO service.delegated_authorities (
        delegating_organization_id,
        receiving_organization_id,
        service_id,
        authority_category,
        scope_reference,
        status,
        valid_from,
        created_by_reference
    )
    VALUES (
        '30000000-0000-0000-0000-000000000001',
        '30000000-0000-0000-0000-000000000001',
        '40000000-0000-0000-0000-000000000001',
        'TEST',
        'sql-test',
        'ACTIVE',
        statement_timestamp(),
        'sql-test'
    )
    $statement$,
    '23514'
);

INSERT INTO attestation.attestation_authorities (
    attestation_authority_id,
    authority_category,
    authorizing_organization_id,
    attesting_organization_id,
    service_id,
    authorized_identity_id,
    scope_reference,
    status,
    valid_from,
    created_by_reference
)
VALUES (
    '50000000-0000-0000-0000-000000000001',
    'TEST',
    '30000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    '40000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000003',
    'sql-test',
    'ACTIVE',
    statement_timestamp() - interval '1 day',
    'sql-test'
);

SELECT sql_test.assert_raises(
    'Organizational attestation person must match its identity',
    $statement$
    INSERT INTO attestation.organizational_attestations (
        attestation_authority_id,
        subject_identity_id,
        subject_person_id,
        attestation_category,
        attestation_value,
        scope_reference,
        status,
        valid_from
    )
    VALUES (
        '50000000-0000-0000-0000-000000000001',
        '20000000-0000-0000-0000-000000000003',
        '20000000-0000-0000-0000-000000000002',
        'TEST',
        '{}'::jsonb,
        'sql-test',
        'VALID',
        statement_timestamp()
    )
    $statement$,
    '23503'
);

SELECT sql_test.assert_true(
    'STABLE lease verification uses statement-consistent time',
    pg_get_functiondef(
        'access_control.verify_lease_secret(uuid,text)'::regprocedure
    ) LIKE '%statement_timestamp()%'
    AND pg_get_functiondef(
        'access_control.verify_lease_secret(uuid,text)'::regprocedure
    ) NOT LIKE '%clock_timestamp()%',
    NULL
);

-- Domain-neutral governed-scope behavior

INSERT INTO organization.governed_scopes (
    governed_scope_id,
    governed_scope_key,
    display_name,
    governed_scope_type,
    status,
    valid_from,
    created_by_reference
)
VALUES (
    '30000000-0000-0000-0000-000000000004',
    'sql_test.governed_scope',
    'SQL Test Governed Scope',
    'TEST_BOUNDARY',
    'ACTIVE',
    statement_timestamp() - interval '1 day',
    'sql-test'
);

INSERT INTO organization.governed_scope_authorities (
    governed_scope_authority_id,
    organization_id,
    governed_scope_id,
    authority_purpose,
    priority,
    valid_from,
    status,
    created_by_reference
)
VALUES (
    '30000000-0000-0000-0000-000000000005',
    '30000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000004',
    'SQL_TEST',
    100,
    statement_timestamp() - interval '1 day',
    'ACTIVE',
    'sql-test'
);

SELECT sql_test.assert_equal_bigint(
    'Governed scope authority is represented without a domain-specific boundary field',
    (
        SELECT count(*)
        FROM organization.governed_scope_authorities
        WHERE organization_id =
            '30000000-0000-0000-0000-000000000001'
          AND governed_scope_id =
            '30000000-0000-0000-0000-000000000004'
          AND authority_purpose = 'SQL_TEST'
    ),
    1
);
