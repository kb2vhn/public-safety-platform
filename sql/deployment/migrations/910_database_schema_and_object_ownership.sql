-- ============================================================================
-- Migration: 910_database_schema_and_object_ownership.sql
-- Title: Database, Schema, and Object Ownership with Creator-Specific Defaults
-- Layer: Deployment and Bootstrap
-- Status: PHASE 5 STEP 3 CANDIDATE
-- Target: PostgreSQL 18
-- ============================================================================
--
-- Purpose:
-- Transfer the active Iron Signal Platform database and its protected objects
-- away from the login-capable bootstrap identity and into approved NOLOGIN
-- owners. Establish default privileges for every role that may create
-- deployable objects.
--
-- Security boundary:
-- - The database is owned by issp_database_owner.
-- - Platform Foundation schemas and objects are owned by
--   issp_foundation_owner.
-- - The extensions schema and extension member objects are owned by
--   issp_extension_owner.
-- - deployment_meta is owned by issp_database_owner.
-- - Runtime, service, review, writer, and break-glass roles own no protected
--   object.
-- - PUBLIC receives no database, schema, table, sequence, or routine access.
-- - Future routines and types created by approved creator roles receive no
--   implicit PUBLIC privileges.
-- - Runtime object grants remain deferred to Phase 5 Step 4.
--
-- PostgreSQL extension-owner limitation:
-- PostgreSQL 18 has no ALTER EXTENSION ... OWNER TO command. The pgcrypto
-- extension catalog record therefore remains owned by the controlled bootstrap
-- identity that created it. The extension schema and member objects are moved
-- to issp_extension_owner, and the catalog-owner limitation is explicitly
-- recorded for production review.
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
    v_missing_roles text;
    v_foundation_migration_count bigint;
    v_step2_migration_count bigint;
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
            MESSAGE = 'Phase 5 Step 3 ownership transfer requires a PostgreSQL superuser',
            DETAIL = format('Connected role=%I.', current_user),
            HINT = 'Use the controlled deployment bootstrap identity.';
    END IF;

    SELECT count(*)
      INTO v_foundation_migration_count
      FROM foundation_meta.applied_migrations;

    IF v_foundation_migration_count <> 34 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'object_not_in_prerequisite_state',
            MESSAGE = 'The accepted 34-migration Platform Foundation is required',
            DETAIL = format(
                'Registered Foundation migrations=%s.',
                v_foundation_migration_count
            );
    END IF;

    SELECT count(*)
      INTO v_step2_migration_count
      FROM deployment_meta.applied_deployment_migrations
     WHERE migration_id = '900_postgresql_role_topology_and_membership';

    IF v_step2_migration_count <> 1 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'object_not_in_prerequisite_state',
            MESSAGE = 'Phase 5 Step 2 role topology must be registered exactly once';
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
      LEFT JOIN pg_roles AS actual_role
        ON actual_role.rolname = required_role.role_name
     WHERE actual_role.rolname IS NULL;

    IF v_missing_roles IS NOT NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = 'object_not_in_prerequisite_state',
            MESSAGE = 'One or more Phase 5 Step 2 roles are missing',
            DETAIL = v_missing_roles;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_roles AS owner_role
        WHERE owner_role.rolname IN (
            'issp_database_owner',
            'issp_foundation_owner',
            'issp_extension_owner'
        )
          AND owner_role.rolcanlogin
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'Approved database ownership roles must remain NOLOGIN';
    END IF;
END;
$deployment_dependency_check$;

-- ============================================================================
-- Ownership policy and explicit platform limitation record
-- ============================================================================

CREATE TABLE deployment_meta.ownership_exceptions (
    ownership_exception_id uuid PRIMARY KEY
        DEFAULT extensions.gen_random_uuid(),
    object_type text NOT NULL,
    object_identity text NOT NULL,
    intended_owner_role name NOT NULL,
    actual_owner_role name NOT NULL,
    reason text NOT NULL,
    review_required_before_production boolean NOT NULL DEFAULT true,
    introduced_by_migration_id text NOT NULL,
    recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT ownership_exceptions_identity_uq
        UNIQUE (object_type, object_identity),
    CONSTRAINT ownership_exceptions_object_type_ck
        CHECK (object_type IN ('EXTENSION_CATALOG_OWNER')),
    CONSTRAINT ownership_exceptions_reason_ck
        CHECK (btrim(reason) <> '')
);

COMMENT ON TABLE deployment_meta.ownership_exceptions IS
    'Explicit ownership limitations that remain subject to production review.';

INSERT INTO deployment_meta.ownership_exceptions (
    object_type,
    object_identity,
    intended_owner_role,
    actual_owner_role,
    reason,
    review_required_before_production,
    introduced_by_migration_id
)
SELECT
    'EXTENSION_CATALOG_OWNER',
    extension_record.extname,
    'issp_extension_owner',
    pg_get_userbyid(extension_record.extowner),
    'PostgreSQL 18 does not provide ALTER EXTENSION OWNER. The extensions schema and pgcrypto member objects are transferred to issp_extension_owner while the extension catalog owner remains the controlled bootstrap identity.',
    true,
    '910_database_schema_and_object_ownership'
FROM pg_extension AS extension_record
WHERE extension_record.extname = 'pgcrypto';

-- ============================================================================
-- Schema and object ownership transfer
-- ============================================================================

DO $transfer_protected_ownership$
DECLARE
    v_schema_name text;
    v_owner_role name;
    v_relation record;
    v_routine record;
    v_type record;
BEGIN
    FOR v_schema_name, v_owner_role IN
        SELECT assignment.schema_name, assignment.owner_role
        FROM (
            VALUES
                ('extensions'::text, 'issp_extension_owner'::name),
                ('deployment_meta'::text, 'issp_database_owner'::name),
                ('foundation_meta'::text, 'issp_foundation_owner'::name),
                ('trust'::text, 'issp_foundation_owner'::name),
                ('identity'::text, 'issp_foundation_owner'::name),
                ('organization'::text, 'issp_foundation_owner'::name),
                ('service'::text, 'issp_foundation_owner'::name),
                ('attestation'::text, 'issp_foundation_owner'::name),
                ('approval'::text, 'issp_foundation_owner'::name),
                ('access_control'::text, 'issp_foundation_owner'::name),
                ('decision'::text, 'issp_foundation_owner'::name),
                ('governance'::text, 'issp_foundation_owner'::name),
                ('compliance'::text, 'issp_foundation_owner'::name),
                ('risk'::text, 'issp_foundation_owner'::name),
                ('resilience'::text, 'issp_foundation_owner'::name),
                ('performance'::text, 'issp_foundation_owner'::name),
                ('observability'::text, 'issp_foundation_owner'::name),
                ('integration'::text, 'issp_foundation_owner'::name),
                ('security_validation'::text, 'issp_foundation_owner'::name)
        ) AS assignment(schema_name, owner_role)
        ORDER BY assignment.schema_name
    LOOP
        IF to_regnamespace(v_schema_name) IS NULL THEN
            RAISE EXCEPTION USING
                ERRCODE = 'undefined_schema',
                MESSAGE = 'Required protected schema is missing',
                DETAIL = format('schema=%I', v_schema_name);
        END IF;

        EXECUTE format(
            'ALTER SCHEMA %I OWNER TO %I',
            v_schema_name,
            v_owner_role
        );

        FOR v_relation IN
            SELECT
                relation_record.relkind,
                relation_record.relname
            FROM pg_class AS relation_record
            JOIN pg_namespace AS namespace_record
              ON namespace_record.oid = relation_record.relnamespace
            WHERE namespace_record.nspname = v_schema_name
              AND relation_record.relkind IN ('r', 'p', 'v', 'm', 'S', 'f')
            ORDER BY relation_record.relname
        LOOP
            CASE v_relation.relkind
                WHEN 'r' THEN
                    EXECUTE format(
                        'ALTER TABLE %I.%I OWNER TO %I',
                        v_schema_name,
                        v_relation.relname,
                        v_owner_role
                    );
                WHEN 'p' THEN
                    EXECUTE format(
                        'ALTER TABLE %I.%I OWNER TO %I',
                        v_schema_name,
                        v_relation.relname,
                        v_owner_role
                    );
                WHEN 'v' THEN
                    EXECUTE format(
                        'ALTER VIEW %I.%I OWNER TO %I',
                        v_schema_name,
                        v_relation.relname,
                        v_owner_role
                    );
                WHEN 'm' THEN
                    EXECUTE format(
                        'ALTER MATERIALIZED VIEW %I.%I OWNER TO %I',
                        v_schema_name,
                        v_relation.relname,
                        v_owner_role
                    );
                WHEN 'S' THEN
                    EXECUTE format(
                        'ALTER SEQUENCE %I.%I OWNER TO %I',
                        v_schema_name,
                        v_relation.relname,
                        v_owner_role
                    );
                WHEN 'f' THEN
                    EXECUTE format(
                        'ALTER FOREIGN TABLE %I.%I OWNER TO %I',
                        v_schema_name,
                        v_relation.relname,
                        v_owner_role
                    );
                ELSE
                    RAISE EXCEPTION 'Unsupported protected relation kind: %',
                        v_relation.relkind;
            END CASE;
        END LOOP;

        FOR v_routine IN
            SELECT
                routine_record.prokind,
                routine_record.proname,
                pg_get_function_identity_arguments(routine_record.oid)
                    AS identity_arguments
            FROM pg_proc AS routine_record
            JOIN pg_namespace AS namespace_record
              ON namespace_record.oid = routine_record.pronamespace
            WHERE namespace_record.nspname = v_schema_name
            ORDER BY
                routine_record.proname,
                pg_get_function_identity_arguments(routine_record.oid)
        LOOP
            CASE v_routine.prokind
                WHEN 'p' THEN
                    EXECUTE format(
                        'ALTER PROCEDURE %I.%I(%s) OWNER TO %I',
                        v_schema_name,
                        v_routine.proname,
                        v_routine.identity_arguments,
                        v_owner_role
                    );
                WHEN 'a' THEN
                    EXECUTE format(
                        'ALTER AGGREGATE %I.%I(%s) OWNER TO %I',
                        v_schema_name,
                        v_routine.proname,
                        v_routine.identity_arguments,
                        v_owner_role
                    );
                ELSE
                    EXECUTE format(
                        'ALTER FUNCTION %I.%I(%s) OWNER TO %I',
                        v_schema_name,
                        v_routine.proname,
                        v_routine.identity_arguments,
                        v_owner_role
                    );
            END CASE;
        END LOOP;

        FOR v_type IN
            SELECT
                type_record.typname,
                type_record.typtype
            FROM pg_type AS type_record
            JOIN pg_namespace AS namespace_record
              ON namespace_record.oid = type_record.typnamespace
            WHERE namespace_record.nspname = v_schema_name
              AND type_record.typrelid = 0
              AND type_record.typelem = 0
              AND type_record.typtype IN ('b', 'c', 'd', 'e', 'm', 'r')
            ORDER BY type_record.typname
        LOOP
            IF v_type.typtype = 'd' THEN
                EXECUTE format(
                    'ALTER DOMAIN %I.%I OWNER TO %I',
                    v_schema_name,
                    v_type.typname,
                    v_owner_role
                );
            ELSE
                EXECUTE format(
                    'ALTER TYPE %I.%I OWNER TO %I',
                    v_schema_name,
                    v_type.typname,
                    v_owner_role
                );
            END IF;
        END LOOP;
    END LOOP;
END;
$transfer_protected_ownership$;

DO $transfer_database_ownership$
BEGIN
    EXECUTE format(
        'ALTER DATABASE %I OWNER TO issp_database_owner',
        current_database()
    );
END;
$transfer_database_ownership$;

-- ============================================================================
-- Existing PUBLIC privilege posture
-- ============================================================================

DO $revoke_existing_public_privileges$
DECLARE
    v_schema_name text;
BEGIN
    EXECUTE format(
        'REVOKE ALL PRIVILEGES ON DATABASE %I FROM PUBLIC',
        current_database()
    );

    FOREACH v_schema_name IN ARRAY ARRAY[
        'extensions',
        'deployment_meta',
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
    ]
    LOOP
        EXECUTE format(
            'REVOKE ALL PRIVILEGES ON SCHEMA %I FROM PUBLIC',
            v_schema_name
        );

        EXECUTE format(
            'REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA %I FROM PUBLIC',
            v_schema_name
        );

        EXECUTE format(
            'REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA %I FROM PUBLIC',
            v_schema_name
        );

        EXECUTE format(
            'REVOKE ALL PRIVILEGES ON ALL ROUTINES IN SCHEMA %I FROM PUBLIC',
            v_schema_name
        );
    END LOOP;
END;
$revoke_existing_public_privileges$;

-- ============================================================================
-- Creator-specific default privileges
-- ============================================================================

DO $establish_creator_specific_defaults$
DECLARE
    v_creator_role name;
BEGIN
    FOREACH v_creator_role IN ARRAY ARRAY[
        'issp_database_owner'::name,
        'issp_foundation_owner'::name,
        'issp_extension_owner'::name,
        'issp_migration_executor'::name
    ]
    LOOP
        EXECUTE format(
            'ALTER DEFAULT PRIVILEGES FOR ROLE %I REVOKE ALL PRIVILEGES ON SCHEMAS FROM PUBLIC',
            v_creator_role
        );

        EXECUTE format(
            'ALTER DEFAULT PRIVILEGES FOR ROLE %I REVOKE ALL PRIVILEGES ON TABLES FROM PUBLIC',
            v_creator_role
        );

        EXECUTE format(
            'ALTER DEFAULT PRIVILEGES FOR ROLE %I REVOKE ALL PRIVILEGES ON SEQUENCES FROM PUBLIC',
            v_creator_role
        );

        EXECUTE format(
            'ALTER DEFAULT PRIVILEGES FOR ROLE %I REVOKE ALL PRIVILEGES ON ROUTINES FROM PUBLIC',
            v_creator_role
        );

        EXECUTE format(
            'ALTER DEFAULT PRIVILEGES FOR ROLE %I REVOKE ALL PRIVILEGES ON TYPES FROM PUBLIC',
            v_creator_role
        );

        EXECUTE format(
            'ALTER DEFAULT PRIVILEGES FOR ROLE %I REVOKE ALL PRIVILEGES ON LARGE OBJECTS FROM PUBLIC',
            v_creator_role
        );
    END LOOP;
END;
$establish_creator_specific_defaults$;

-- ============================================================================
-- Ownership and privilege validation before registration
-- ============================================================================

DO $validate_phase5_step3_ownership$
DECLARE
    v_violation_count bigint;
BEGIN
    SELECT count(*)
      INTO v_violation_count
      FROM pg_database AS database_record
     WHERE database_record.datname = current_database()
       AND pg_get_userbyid(database_record.datdba) <> 'issp_database_owner';

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'Current database is not owned by issp_database_owner';
    END IF;

    SELECT count(*)
      INTO v_violation_count
      FROM (
          VALUES
              ('extensions'::text, 'issp_extension_owner'::name),
              ('deployment_meta'::text, 'issp_database_owner'::name),
              ('foundation_meta'::text, 'issp_foundation_owner'::name),
              ('trust'::text, 'issp_foundation_owner'::name),
              ('identity'::text, 'issp_foundation_owner'::name),
              ('organization'::text, 'issp_foundation_owner'::name),
              ('service'::text, 'issp_foundation_owner'::name),
              ('attestation'::text, 'issp_foundation_owner'::name),
              ('approval'::text, 'issp_foundation_owner'::name),
              ('access_control'::text, 'issp_foundation_owner'::name),
              ('decision'::text, 'issp_foundation_owner'::name),
              ('governance'::text, 'issp_foundation_owner'::name),
              ('compliance'::text, 'issp_foundation_owner'::name),
              ('risk'::text, 'issp_foundation_owner'::name),
              ('resilience'::text, 'issp_foundation_owner'::name),
              ('performance'::text, 'issp_foundation_owner'::name),
              ('observability'::text, 'issp_foundation_owner'::name),
              ('integration'::text, 'issp_foundation_owner'::name),
              ('security_validation'::text, 'issp_foundation_owner'::name)
      ) AS expected_schema(schema_name, owner_role)
      LEFT JOIN pg_namespace AS actual_schema
        ON actual_schema.nspname = expected_schema.schema_name
     WHERE actual_schema.oid IS NULL
        OR pg_get_userbyid(actual_schema.nspowner)
            IS DISTINCT FROM expected_schema.owner_role::text;

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'One or more protected schemas have an unexpected owner',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;

    SELECT count(*)
      INTO v_violation_count
      FROM pg_class AS relation_record
      JOIN pg_namespace AS namespace_record
        ON namespace_record.oid = relation_record.relnamespace
     WHERE relation_record.relkind IN ('r', 'p', 'v', 'm', 'S', 'f')
       AND namespace_record.nspname IN (
           'extensions',
           'deployment_meta',
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
       AND pg_get_userbyid(relation_record.relowner) <>
           CASE
               WHEN namespace_record.nspname = 'extensions'
                   THEN 'issp_extension_owner'
               WHEN namespace_record.nspname = 'deployment_meta'
                   THEN 'issp_database_owner'
               ELSE 'issp_foundation_owner'
           END;

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'One or more protected relations have an unexpected owner',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;

    SELECT count(*)
      INTO v_violation_count
      FROM pg_proc AS routine_record
      JOIN pg_namespace AS namespace_record
        ON namespace_record.oid = routine_record.pronamespace
     WHERE namespace_record.nspname IN (
           'extensions',
           'deployment_meta',
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
       AND pg_get_userbyid(routine_record.proowner) <>
           CASE
               WHEN namespace_record.nspname = 'extensions'
                   THEN 'issp_extension_owner'
               WHEN namespace_record.nspname = 'deployment_meta'
                   THEN 'issp_database_owner'
               ELSE 'issp_foundation_owner'
           END;

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'One or more protected routines have an unexpected owner',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;

    SELECT count(*)
      INTO v_violation_count
      FROM pg_type AS type_record
      JOIN pg_namespace AS namespace_record
        ON namespace_record.oid = type_record.typnamespace
     WHERE type_record.typrelid = 0
       AND type_record.typelem = 0
       AND type_record.typtype IN ('b', 'c', 'd', 'e', 'm', 'r')
       AND namespace_record.nspname IN (
           'extensions',
           'deployment_meta',
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
       AND pg_get_userbyid(type_record.typowner) <>
           CASE
               WHEN namespace_record.nspname = 'extensions'
                   THEN 'issp_extension_owner'
               WHEN namespace_record.nspname = 'deployment_meta'
                   THEN 'issp_database_owner'
               ELSE 'issp_foundation_owner'
           END;

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'One or more protected standalone types have an unexpected owner',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;

    SELECT count(*)
      INTO v_violation_count
      FROM (
          SELECT pg_get_userbyid(database_record.datdba) AS owner_name
          FROM pg_database AS database_record
          WHERE database_record.datname = current_database()

          UNION ALL

          SELECT pg_get_userbyid(namespace_record.nspowner)
          FROM pg_namespace AS namespace_record
          WHERE namespace_record.nspname IN (
              'extensions',
              'deployment_meta',
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

          UNION ALL

          SELECT pg_get_userbyid(relation_record.relowner)
          FROM pg_class AS relation_record
          JOIN pg_namespace AS namespace_record
            ON namespace_record.oid = relation_record.relnamespace
          WHERE relation_record.relkind IN ('r', 'p', 'v', 'm', 'S', 'f')
            AND namespace_record.nspname IN (
                'extensions',
                'deployment_meta',
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

          UNION ALL

          SELECT pg_get_userbyid(routine_record.proowner)
          FROM pg_proc AS routine_record
          JOIN pg_namespace AS namespace_record
            ON namespace_record.oid = routine_record.pronamespace
          WHERE namespace_record.nspname IN (
              'extensions',
              'deployment_meta',
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
      ) AS protected_owner
      JOIN pg_roles AS owner_role
        ON owner_role.rolname = protected_owner.owner_name
     WHERE owner_role.rolcanlogin;

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'A login-capable role still owns a protected database object',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;

    IF has_database_privilege(
        'public',
        current_database(),
        'CONNECT'
    ) OR has_database_privilege(
        'public',
        current_database(),
        'TEMPORARY'
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'PUBLIC retains database CONNECT or TEMPORARY privilege';
    END IF;

    SELECT count(*)
      INTO v_violation_count
      FROM deployment_meta.ownership_exceptions
     WHERE object_type = 'EXTENSION_CATALOG_OWNER'
       AND object_identity = 'pgcrypto'
       AND intended_owner_role = 'issp_extension_owner'
       AND review_required_before_production;

    IF v_violation_count <> 1 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'The pgcrypto extension-owner limitation is not recorded exactly once';
    END IF;
END;
$validate_phase5_step3_ownership$;

REVOKE ALL PRIVILEGES
ON ALL TABLES IN SCHEMA deployment_meta
FROM PUBLIC;

REVOKE ALL PRIVILEGES
ON ALL SEQUENCES IN SCHEMA deployment_meta
FROM PUBLIC;

REVOKE ALL PRIVILEGES
ON ALL ROUTINES IN SCHEMA deployment_meta
FROM PUBLIC;

SELECT deployment_meta.register_deployment_migration(
    p_migration_id =>
        '910_database_schema_and_object_ownership',
    p_migration_name =>
        'Database schema and object ownership with creator-specific defaults',
    p_migration_checksum =>
        :'deployment_migration_checksum',
    p_relative_path =>
        :'deployment_migration_relative_path',
    p_notes =>
        'Transferred protected ownership to NOLOGIN owners, revoked PUBLIC database and object access, established creator-specific default privileges, and recorded the PostgreSQL extension catalog-owner limitation.'
);

COMMIT;
