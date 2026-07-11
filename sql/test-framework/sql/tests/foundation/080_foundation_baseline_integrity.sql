-- ============================================================================
-- Foundation baseline integrity
-- ============================================================================

SELECT sql_test.begin_file('080_foundation_baseline_integrity.sql');

SELECT sql_test.assert_true(
    'pgcrypto is installed in the extensions schema',
    EXISTS (
        SELECT 1
        FROM pg_extension AS extension_record
        JOIN pg_namespace AS extension_schema
          ON extension_schema.oid = extension_record.extnamespace
        WHERE extension_record.extname = 'pgcrypto'
          AND extension_schema.nspname = 'extensions'
    )
);

SELECT sql_test.assert_true(
    'Device identities require a device subject',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'identity.identities'::regclass
          AND conname = 'identities_subject_ck'
          AND contype = 'c'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Trust Provider identity mappings have one-current-mapping protection',
    EXISTS (
        SELECT 1
        FROM pg_index AS index_record
        JOIN pg_class AS index_relation
          ON index_relation.oid = index_record.indexrelid
        WHERE index_record.indrelid =
              'identity.trust_provider_identity_mappings'::regclass
          AND index_relation.relname =
              'trust_provider_identity_mappings_current_uq'
          AND index_record.indisunique
          AND index_record.indisvalid
    )
);

SELECT sql_test.assert_true(
    'Organizational-unit parentage is constrained to the same organization',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
              'organization.organizational_units'::regclass
          AND conname = 'organizational_units_parent_same_org_fk'
          AND contype = 'f'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Configuration items have explicit configuration scope',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'service'
          AND table_name = 'configuration_items'
          AND column_name = 'configuration_scope'
          AND is_nullable = 'NO'
    )
);

SELECT sql_test.assert_true(
    'Participation agreements are versioned',
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'service'
          AND table_name = 'participation_agreements'
          AND column_name = 'version_number'
          AND is_nullable = 'NO'
    )
);

SELECT sql_test.assert_true(
    'Approval Requests reference authoritative Governed Operation definitions',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'approval.approval_requests'::regclass
          AND conname = 'approval_requests_operation_definition_fk'
          AND contype = 'f'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Approval Request operation keys are bound to their definition identifiers',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'approval.approval_requests'::regclass
          AND conname = 'approval_requests_operation_definition_fk'
          AND pg_get_constraintdef(oid) LIKE
              '%(operation_definition_id, operation_key)%'
    )
);

SELECT sql_test.assert_true(
    'Decision Record operation snapshots are bound to their definition identifiers',
    EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'decision.decision_records'::regclass
          AND conname = 'decision_records_operation_definition_fk'
          AND contype = 'f'
          AND convalidated
    )
);

SELECT sql_test.assert_true(
    'Authentication Assertion lifecycle includes VERIFIED',
    pg_get_constraintdef(
        (
            SELECT oid
            FROM pg_constraint
            WHERE conrelid =
                  'access_control.authentication_assertions'::regclass
              AND conname = 'authentication_assertions_status_ck'
        )
    ) LIKE '%VERIFIED%'
);

SELECT sql_test.assert_true(
    'Authentication Assertions retain explicit terminal timestamps',
    (
        SELECT count(*) = 3
        FROM information_schema.columns
        WHERE table_schema = 'access_control'
          AND table_name = 'authentication_assertions'
          AND column_name IN (
              'rejected_at',
              'expired_at',
              'revoked_at'
          )
    )
);

SELECT sql_test.assert_true(
    'Authentication Assertion consumption requires VERIFIED state',
    position(
        'status = ''VERIFIED'''
        IN pg_get_functiondef(
            'access_control.consume_authentication_assertion(text,text,uuid,uuid,uuid,uuid,uuid,text,text)'::regprocedure
        )
    ) > 0
);

SELECT sql_test.assert_true(
    'Authentication Assertion consumption uses statement-consistent time',
    position(
        'statement_timestamp()'
        IN pg_get_functiondef(
            'access_control.consume_authentication_assertion(text,text,uuid,uuid,uuid,uuid,uuid,text,text)'::regprocedure
        )
    ) > 0
);

SELECT sql_test.assert_true(
    'Authorization Lease context verification uses statement-consistent time',
    position(
        'statement_timestamp()'
        IN pg_get_functiondef(
            'access_control.verify_authorization_lease_context(uuid,text,uuid,uuid,uuid,uuid,uuid,uuid,uuid,text,text,uuid,text,uuid)'::regprocedure
        )
    ) > 0
);

SELECT sql_test.assert_true(
    'Secret-only lease verification is documented as not being authorization',
    obj_description(
        'access_control.verify_lease_secret(uuid,text)'::regprocedure,
        'pg_proc'
    ) ILIKE '%not an authorization decision%'
);
