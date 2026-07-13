-- ============================================================================
-- Migration: 900_postgresql_role_topology_and_membership.sql
-- Title: PostgreSQL Role Topology and Membership
-- Layer: Deployment and Bootstrap
-- Status: PHASE 5 STEP 2 CANDIDATE
-- Target: PostgreSQL 18
-- ============================================================================
--
-- Purpose:
-- Create the canonical Iron Signal Platform PostgreSQL role topology without
-- transferring object ownership or granting protected database privileges.
--
-- Security boundary:
-- - Canonical owner and capability roles are NOLOGIN.
-- - Login roles have no password at this step.
-- - No canonical role receives SUPERUSER, CREATEDB, CREATEROLE, REPLICATION,
--   or BYPASSRLS.
-- - Service identities inherit only explicit capability-role memberships.
-- - Service identities cannot SET ROLE into capability roles and cannot grant
--   those memberships onward.
-- - No migration-executor membership in an owner role is created.
-- - Break-glass remains NOLOGIN and has no members.
--
-- Deferred to later Phase 5 steps:
-- - database, schema, extension, relation, and routine ownership transfer;
-- - default privileges;
-- - object-level runtime grants;
-- - investigator, audit, and validation read grants;
-- - credential provisioning and break-glass activation lifecycle.
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
            MESSAGE = 'Phase 5 Step 2 role-topology bootstrap requires a PostgreSQL superuser',
            DETAIL = format('Connected role=%I.', current_user),
            HINT = 'Use the controlled deployment bootstrap identity. Runtime service identities are not permitted to create cluster roles.';
    END IF;

    SELECT count(*)
    INTO v_foundation_migration_count
    FROM foundation_meta.applied_migrations;

    IF v_foundation_migration_count <> 34 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'object_not_in_prerequisite_state',
            MESSAGE = 'The accepted 34-migration Platform Foundation is required before deployment role bootstrap',
            DETAIL = format(
                'Registered Foundation migrations=%s.',
                v_foundation_migration_count
            );
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM foundation_meta.applied_migrations
        WHERE migration_id = '099_foundation_validation'
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'object_not_in_prerequisite_state',
            MESSAGE = 'Required migration 099_foundation_validation is not registered';
    END IF;
END;
$deployment_dependency_check$;

-- ============================================================================
-- Deployment metadata boundary
-- ============================================================================

CREATE SCHEMA deployment_meta;

COMMENT ON SCHEMA deployment_meta IS
    'Deployment migration, PostgreSQL role-topology, and environment-bootstrap metadata.';

REVOKE ALL ON SCHEMA deployment_meta FROM PUBLIC;

CREATE TABLE deployment_meta.applied_deployment_migrations (
    migration_id        text        PRIMARY KEY,
    migration_name      text        NOT NULL,
    migration_layer     text        NOT NULL,
    migration_checksum text        NOT NULL,
    relative_path       text        NOT NULL,
    applied_at          timestamptz NOT NULL DEFAULT clock_timestamp(),
    applied_by          name        NOT NULL DEFAULT session_user,
    database_name       name        NOT NULL DEFAULT current_database(),
    server_version_num  integer     NOT NULL DEFAULT current_setting(
        'server_version_num'
    )::integer,
    application_name    text        NOT NULL DEFAULT COALESCE(
        NULLIF(current_setting('application_name', true), ''),
        'unspecified'
    ),
    transaction_id      bigint      NOT NULL DEFAULT txid_current(),
    notes               text,

    CONSTRAINT applied_deployment_migrations_id_ck
        CHECK (migration_id ~ '^9[0-9]{2}(_[a-z0-9]+)*$'),

    CONSTRAINT applied_deployment_migrations_name_ck
        CHECK (btrim(migration_name) <> ''),

    CONSTRAINT applied_deployment_migrations_layer_ck
        CHECK (migration_layer = 'DEPLOYMENT'),

    CONSTRAINT applied_deployment_migrations_checksum_ck
        CHECK (migration_checksum ~ '^[0-9a-f]{64}$'),

    CONSTRAINT applied_deployment_migrations_path_ck
        CHECK (
            relative_path
                ~ '^migrations/9[0-9]{2}_[a-z0-9_]+[.]sql$'
        )
);

COMMENT ON TABLE deployment_meta.applied_deployment_migrations IS
    'Append-oriented registry of successfully applied deployment migrations.';

CREATE UNIQUE INDEX applied_deployment_migrations_name_uq
    ON deployment_meta.applied_deployment_migrations (
        migration_layer,
        migration_name
    );

CREATE INDEX applied_deployment_migrations_applied_at_idx
    ON deployment_meta.applied_deployment_migrations (applied_at);

CREATE FUNCTION deployment_meta.register_deployment_migration(
    p_migration_id text,
    p_migration_name text,
    p_migration_checksum text,
    p_relative_path text,
    p_notes text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SET search_path = pg_catalog, deployment_meta
AS $function$
DECLARE
    v_existing deployment_meta.applied_deployment_migrations%ROWTYPE;
BEGIN
    IF p_migration_id IS NULL
       OR p_migration_id !~ '^9[0-9]{2}(_[a-z0-9]+)*$' THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_parameter_value',
            MESSAGE = 'Invalid deployment migration identifier',
            DETAIL = format('migration_id=%L', p_migration_id);
    END IF;

    IF p_migration_name IS NULL OR btrim(p_migration_name) = '' THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_parameter_value',
            MESSAGE = 'Deployment migration name must not be empty';
    END IF;

    IF p_migration_checksum IS NULL
       OR p_migration_checksum !~ '^[0-9a-f]{64}$' THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_parameter_value',
            MESSAGE = 'Deployment migration checksum must be a lowercase SHA-256 value';
    END IF;

    IF p_relative_path IS NULL
       OR p_relative_path
            !~ '^migrations/9[0-9]{2}_[a-z0-9_]+[.]sql$' THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_parameter_value',
            MESSAGE = 'Invalid deployment migration relative path',
            DETAIL = format('relative_path=%L', p_relative_path);
    END IF;

    SELECT *
    INTO v_existing
    FROM deployment_meta.applied_deployment_migrations
    WHERE migration_id = p_migration_id;

    IF FOUND THEN
        IF v_existing.migration_name IS DISTINCT FROM p_migration_name
           OR v_existing.migration_checksum IS DISTINCT FROM p_migration_checksum
           OR v_existing.relative_path IS DISTINCT FROM p_relative_path THEN
            RAISE EXCEPTION USING
                ERRCODE = 'integrity_constraint_violation',
                MESSAGE = 'Deployment migration identifier is already registered with different metadata',
                DETAIL = format('migration_id=%s', p_migration_id);
        END IF;

        RETURN;
    END IF;

    INSERT INTO deployment_meta.applied_deployment_migrations (
        migration_id,
        migration_name,
        migration_layer,
        migration_checksum,
        relative_path,
        notes
    )
    VALUES (
        p_migration_id,
        p_migration_name,
        'DEPLOYMENT',
        p_migration_checksum,
        p_relative_path,
        p_notes
    );
END;
$function$;

COMMENT ON FUNCTION deployment_meta.register_deployment_migration(
    text,
    text,
    text,
    text,
    text
) IS
    'Registers an exact deployment migration and rejects identifier reuse with changed metadata.';

REVOKE ALL ON FUNCTION deployment_meta.register_deployment_migration(
    text,
    text,
    text,
    text,
    text
) FROM PUBLIC;

CREATE TABLE deployment_meta.database_roles (
    role_name                   name        PRIMARY KEY,
    role_class_key              text        NOT NULL,
    login_allowed               boolean     NOT NULL,
    ownership_role              boolean     NOT NULL,
    capability_role             boolean     NOT NULL,
    break_glass_only            boolean     NOT NULL DEFAULT false,
    expected_connection_limit   integer     NOT NULL,
    credential_state            text        NOT NULL,
    description                 text        NOT NULL,
    introduced_by_migration_id  text        NOT NULL,
    recorded_at                 timestamptz NOT NULL DEFAULT clock_timestamp(),

    CONSTRAINT database_roles_name_ck
        CHECK (role_name::text ~ '^issp_[a-z0-9_]+$'),

    CONSTRAINT database_roles_class_ck
        CHECK (role_class_key ~ '^[a-z][a-z0-9_]*$'),

    CONSTRAINT database_roles_class_fk
        FOREIGN KEY (role_class_key)
        REFERENCES foundation_meta.database_role_classes (role_class_key),

    CONSTRAINT database_roles_connection_limit_ck
        CHECK (expected_connection_limit >= -1),

    CONSTRAINT database_roles_credential_state_ck
        CHECK (
            credential_state IN (
                'NOT_APPLICABLE',
                'UNPROVISIONED',
                'PROVISIONED',
                'DISABLED'
            )
        ),

    CONSTRAINT database_roles_description_ck
        CHECK (btrim(description) <> ''),

    CONSTRAINT database_roles_break_glass_ck
        CHECK (
            break_glass_only = false
            OR role_class_key = 'break_glass'
        )
);

COMMENT ON TABLE deployment_meta.database_roles IS
    'Expected canonical PostgreSQL roles and their Phase 5 role classes.';

CREATE TABLE deployment_meta.database_role_memberships (
    granted_role_name          name        NOT NULL,
    member_role_name           name        NOT NULL,
    inherit_option             boolean     NOT NULL,
    set_option                 boolean     NOT NULL,
    admin_option               boolean     NOT NULL,
    introduced_by_migration_id text        NOT NULL,
    recorded_at                timestamptz NOT NULL DEFAULT clock_timestamp(),

    CONSTRAINT database_role_memberships_pk
        PRIMARY KEY (granted_role_name, member_role_name),

    CONSTRAINT database_role_memberships_granted_fk
        FOREIGN KEY (granted_role_name)
        REFERENCES deployment_meta.database_roles (role_name),

    CONSTRAINT database_role_memberships_member_fk
        FOREIGN KEY (member_role_name)
        REFERENCES deployment_meta.database_roles (role_name),

    CONSTRAINT database_role_memberships_no_self_ck
        CHECK (granted_role_name <> member_role_name),

    CONSTRAINT database_role_memberships_no_admin_ck
        CHECK (admin_option = false),

    CONSTRAINT database_role_memberships_no_set_ck
        CHECK (set_option = false)
);

COMMENT ON TABLE deployment_meta.database_role_memberships IS
    'Expected capability memberships for bounded service login roles.';

INSERT INTO foundation_meta.schema_registry (
    schema_name,
    capability_key,
    architectural_layer,
    purpose,
    created_by_migration_id
)
VALUES (
    'deployment_meta',
    'deployment_metadata',
    'DEPLOYMENT',
    'Deployment migration, PostgreSQL role-topology, and environment-bootstrap metadata.',
    '900_postgresql_role_topology_and_membership'
);

-- ============================================================================
-- Foundation role-class metadata
-- ============================================================================

INSERT INTO foundation_meta.database_role_classes (
    role_class_key,
    title,
    description,
    login_allowed,
    ownership_allowed,
    operational_use_allowed,
    break_glass_only,
    created_by_reference
)
VALUES
    (
        'database_owner',
        'Database Owner',
        'Non-login ownership anchor for the Iron Signal Platform database.',
        false,
        true,
        false,
        false,
        'deployment:900_postgresql_role_topology_and_membership'
    ),
    (
        'foundation_owner',
        'Foundation Object Owner',
        'Non-login owner for Platform Foundation schemas and objects.',
        false,
        true,
        false,
        false,
        'deployment:900_postgresql_role_topology_and_membership'
    ),
    (
        'extension_owner',
        'Extension Owner',
        'Non-login owner for approved PostgreSQL extension objects.',
        false,
        true,
        false,
        false,
        'deployment:900_postgresql_role_topology_and_membership'
    ),
    (
        'migration_executor',
        'Migration Executor',
        'Controlled login identity for approved deployment migrations.',
        true,
        false,
        false,
        false,
        'deployment:900_postgresql_role_topology_and_membership'
    ),
    (
        'runtime_capability',
        'Runtime Capability',
        'Non-login common capability boundary for production services.',
        false,
        false,
        true,
        false,
        'deployment:900_postgresql_role_topology_and_membership'
    ),
    (
        'service_login',
        'Service Login',
        'Bounded login identity for one deployed service or worker.',
        true,
        false,
        true,
        false,
        'deployment:900_postgresql_role_topology_and_membership'
    ),
    (
        'controlled_writer',
        'Controlled Writer',
        'Non-login capability role for approved controlled write APIs.',
        false,
        false,
        true,
        false,
        'deployment:900_postgresql_role_topology_and_membership'
    ),
    (
        'read_only_investigator',
        'Read-Only Investigator',
        'Non-login review capability for approved investigative surfaces.',
        false,
        false,
        true,
        false,
        'deployment:900_postgresql_role_topology_and_membership'
    ),
    (
        'audit_reader',
        'Audit Reader',
        'Non-login review capability for approved audit surfaces.',
        false,
        false,
        true,
        false,
        'deployment:900_postgresql_role_topology_and_membership'
    ),
    (
        'validation_reader',
        'Validation Reader',
        'Non-login review capability for approved validation surfaces.',
        false,
        false,
        true,
        false,
        'deployment:900_postgresql_role_topology_and_membership'
    ),
    (
        'break_glass',
        'Break Glass',
        'Emergency-only role class that remains disabled at rest.',
        true,
        false,
        false,
        true,
        'deployment:900_postgresql_role_topology_and_membership'
    );

WITH incompatible_pairs (first_key, second_key, reason) AS (
    VALUES
        ('database_owner', 'migration_executor', 'Database ownership and migration execution must remain separate.'),
        ('database_owner', 'service_login', 'Database ownership and runtime service use must remain separate.'),
        ('database_owner', 'runtime_capability', 'Database ownership and runtime capability must remain separate.'),
        ('database_owner', 'controlled_writer', 'Database ownership and controlled writing must remain separate.'),
        ('database_owner', 'read_only_investigator', 'Database ownership and investigation must remain separate.'),
        ('database_owner', 'audit_reader', 'Database ownership and audit review must remain separate.'),
        ('database_owner', 'validation_reader', 'Database ownership and validation review must remain separate.'),
        ('database_owner', 'break_glass', 'Database ownership and emergency access must remain separate.'),
        ('foundation_owner', 'migration_executor', 'Foundation ownership and migration execution must remain separate.'),
        ('foundation_owner', 'service_login', 'Foundation ownership and runtime service use must remain separate.'),
        ('foundation_owner', 'runtime_capability', 'Foundation ownership and runtime capability must remain separate.'),
        ('foundation_owner', 'controlled_writer', 'Foundation ownership and controlled writing must remain separate.'),
        ('foundation_owner', 'read_only_investigator', 'Foundation ownership and investigation must remain separate.'),
        ('foundation_owner', 'audit_reader', 'Foundation ownership and audit review must remain separate.'),
        ('foundation_owner', 'validation_reader', 'Foundation ownership and validation review must remain separate.'),
        ('foundation_owner', 'break_glass', 'Foundation ownership and emergency access must remain separate.'),
        ('extension_owner', 'migration_executor', 'Extension ownership and migration execution must remain separate.'),
        ('extension_owner', 'service_login', 'Extension ownership and runtime service use must remain separate.'),
        ('extension_owner', 'runtime_capability', 'Extension ownership and runtime capability must remain separate.'),
        ('extension_owner', 'controlled_writer', 'Extension ownership and controlled writing must remain separate.'),
        ('extension_owner', 'read_only_investigator', 'Extension ownership and investigation must remain separate.'),
        ('extension_owner', 'audit_reader', 'Extension ownership and audit review must remain separate.'),
        ('extension_owner', 'validation_reader', 'Extension ownership and validation review must remain separate.'),
        ('extension_owner', 'break_glass', 'Extension ownership and emergency access must remain separate.'),
        ('migration_executor', 'service_login', 'Migration execution and runtime service identity must remain separate.'),
        ('migration_executor', 'runtime_capability', 'Migration execution and runtime capability must remain separate.'),
        ('migration_executor', 'controlled_writer', 'Migration execution and runtime writing must remain separate.'),
        ('migration_executor', 'read_only_investigator', 'Migration execution and investigation must remain separate.'),
        ('migration_executor', 'audit_reader', 'Migration execution and audit review must remain separate.'),
        ('migration_executor', 'validation_reader', 'Migration execution and validation review must remain separate.'),
        ('migration_executor', 'break_glass', 'Migration execution and emergency access must remain separate.'),
        ('runtime_capability', 'read_only_investigator', 'Runtime capability and investigation must remain separate.'),
        ('runtime_capability', 'audit_reader', 'Runtime capability and audit review must remain separate.'),
        ('runtime_capability', 'validation_reader', 'Runtime capability and validation review must remain separate.'),
        ('runtime_capability', 'break_glass', 'Runtime capability and emergency access must remain separate.'),
        ('service_login', 'read_only_investigator', 'Runtime service use and investigation must remain separate.'),
        ('service_login', 'audit_reader', 'Runtime service use and audit review must remain separate.'),
        ('service_login', 'validation_reader', 'Runtime service use and validation review must remain separate.'),
        ('service_login', 'break_glass', 'Runtime service use and emergency access must remain separate.'),
        ('controlled_writer', 'read_only_investigator', 'Controlled writing and investigation must remain separate.'),
        ('controlled_writer', 'audit_reader', 'Controlled writing and audit review must remain separate.'),
        ('controlled_writer', 'validation_reader', 'Controlled writing and validation review must remain separate.'),
        ('controlled_writer', 'break_glass', 'Controlled writing and emergency access must remain separate.')
)
INSERT INTO foundation_meta.incompatible_database_role_classes (
    first_role_class_id,
    second_role_class_id,
    reason,
    created_by_reference
)
SELECT
    first_class.database_role_class_id,
    second_class.database_role_class_id,
    incompatible_pairs.reason,
    'deployment:900_postgresql_role_topology_and_membership'
FROM incompatible_pairs
JOIN foundation_meta.database_role_classes AS first_class
  ON first_class.role_class_key = incompatible_pairs.first_key
JOIN foundation_meta.database_role_classes AS second_class
  ON second_class.role_class_key = incompatible_pairs.second_key;

-- ============================================================================
-- Canonical role inventory
-- ============================================================================

INSERT INTO deployment_meta.database_roles (
    role_name,
    role_class_key,
    login_allowed,
    ownership_role,
    capability_role,
    break_glass_only,
    expected_connection_limit,
    credential_state,
    description,
    introduced_by_migration_id
)
VALUES
    (
        'issp_database_owner',
        'database_owner',
        false,
        true,
        false,
        false,
        -1,
        'NOT_APPLICABLE',
        'Non-login ownership anchor for the Iron Signal Platform database.',
        '900_postgresql_role_topology_and_membership'
    ),
    (
        'issp_foundation_owner',
        'foundation_owner',
        false,
        true,
        false,
        false,
        -1,
        'NOT_APPLICABLE',
        'Non-login owner for Platform Foundation schemas and objects.',
        '900_postgresql_role_topology_and_membership'
    ),
    (
        'issp_extension_owner',
        'extension_owner',
        false,
        true,
        false,
        false,
        -1,
        'NOT_APPLICABLE',
        'Non-login owner for approved PostgreSQL extension objects.',
        '900_postgresql_role_topology_and_membership'
    ),
    (
        'issp_migration_executor',
        'migration_executor',
        true,
        false,
        false,
        false,
        2,
        'UNPROVISIONED',
        'Controlled login identity for approved deployment migrations.',
        '900_postgresql_role_topology_and_membership'
    ),
    (
        'issp_runtime',
        'runtime_capability',
        false,
        false,
        true,
        false,
        -1,
        'NOT_APPLICABLE',
        'Common non-login runtime capability boundary.',
        '900_postgresql_role_topology_and_membership'
    ),
    (
        'issp_writer_authentication_assertion',
        'controlled_writer',
        false,
        false,
        true,
        false,
        -1,
        'NOT_APPLICABLE',
        'Controlled Authentication Assertion lifecycle capability.',
        '900_postgresql_role_topology_and_membership'
    ),
    (
        'issp_writer_session_control',
        'controlled_writer',
        false,
        false,
        true,
        false,
        -1,
        'NOT_APPLICABLE',
        'Controlled session establishment and lifecycle capability.',
        '900_postgresql_role_topology_and_membership'
    ),
    (
        'issp_writer_authorization_decision',
        'controlled_writer',
        false,
        false,
        true,
        false,
        -1,
        'NOT_APPLICABLE',
        'Controlled authorization decision and lease capability.',
        '900_postgresql_role_topology_and_membership'
    ),
    (
        'issp_writer_approval',
        'controlled_writer',
        false,
        false,
        true,
        false,
        -1,
        'NOT_APPLICABLE',
        'Controlled approval action and finalization capability.',
        '900_postgresql_role_topology_and_membership'
    ),
    (
        'issp_writer_integration_delivery',
        'controlled_writer',
        false,
        false,
        true,
        false,
        -1,
        'NOT_APPLICABLE',
        'Controlled external-integration delivery capability.',
        '900_postgresql_role_topology_and_membership'
    ),
    (
        'issp_writer_monitoring_delivery',
        'controlled_writer',
        false,
        false,
        true,
        false,
        -1,
        'NOT_APPLICABLE',
        'Controlled monitoring delivery-state capability.',
        '900_postgresql_role_topology_and_membership'
    ),
    (
        'issp_read_only_investigator',
        'read_only_investigator',
        false,
        false,
        true,
        false,
        -1,
        'NOT_APPLICABLE',
        'Read-only investigator capability shell; object grants are deferred.',
        '900_postgresql_role_topology_and_membership'
    ),
    (
        'issp_audit_reader',
        'audit_reader',
        false,
        false,
        true,
        false,
        -1,
        'NOT_APPLICABLE',
        'Audit reader capability shell; object grants are deferred.',
        '900_postgresql_role_topology_and_membership'
    ),
    (
        'issp_validation_reader',
        'validation_reader',
        false,
        false,
        true,
        false,
        -1,
        'NOT_APPLICABLE',
        'Validation reader capability shell; object grants are deferred.',
        '900_postgresql_role_topology_and_membership'
    ),
    (
        'issp_break_glass',
        'break_glass',
        false,
        false,
        false,
        true,
        -1,
        'DISABLED',
        'Emergency-only role shell that remains NOLOGIN with no members.',
        '900_postgresql_role_topology_and_membership'
    ),
    (
        'issp_service_authorization',
        'service_login',
        true,
        false,
        false,
        false,
        20,
        'UNPROVISIONED',
        'Bounded login for Foundation authorization, session, and approval service work.',
        '900_postgresql_role_topology_and_membership'
    ),
    (
        'issp_service_integration_delivery',
        'service_login',
        true,
        false,
        false,
        false,
        10,
        'UNPROVISIONED',
        'Bounded login for external-integration outbox delivery work.',
        '900_postgresql_role_topology_and_membership'
    ),
    (
        'issp_service_monitoring_delivery',
        'service_login',
        true,
        false,
        false,
        false,
        10,
        'UNPROVISIONED',
        'Bounded login for monitoring subscription and delivery-state work.',
        '900_postgresql_role_topology_and_membership'
    );

-- Reject silent adoption of pre-existing canonical roles. A failed bootstrap
-- must be investigated rather than normalizing an unknown cluster role.
DO $canonical_role_collision_check$
DECLARE
    v_existing_roles text;
BEGIN
    SELECT string_agg(role_record.rolname, ', ' ORDER BY role_record.rolname)
    INTO v_existing_roles
    FROM pg_roles AS role_record
    JOIN deployment_meta.database_roles AS expected_role
      ON expected_role.role_name = role_record.rolname;

    IF v_existing_roles IS NOT NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = 'duplicate_object',
            MESSAGE = 'One or more canonical Iron Signal Platform roles already exist before migration 900',
            DETAIL = v_existing_roles,
            HINT = 'Use the deployment registry to determine whether migration 900 was already applied. Do not silently adopt untracked cluster roles.';
    END IF;
END;
$canonical_role_collision_check$;

-- ============================================================================
-- Create canonical roles with fail-safe attributes
-- ============================================================================

DO $create_canonical_roles$
DECLARE
    v_role deployment_meta.database_roles%ROWTYPE;
BEGIN
    FOR v_role IN
        SELECT *
        FROM deployment_meta.database_roles
        ORDER BY role_name
    LOOP
        IF v_role.login_allowed THEN
            EXECUTE format(
                'CREATE ROLE %I WITH LOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS CONNECTION LIMIT %s PASSWORD NULL',
                v_role.role_name,
                v_role.expected_connection_limit
            );
        ELSE
            EXECUTE format(
                'CREATE ROLE %I WITH NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS CONNECTION LIMIT %s',
                v_role.role_name,
                v_role.expected_connection_limit
            );
        END IF;
    END LOOP;
END;
$create_canonical_roles$;

COMMENT ON ROLE issp_database_owner IS
    'Iron Signal Platform database ownership anchor; NOLOGIN.';
COMMENT ON ROLE issp_foundation_owner IS
    'Iron Signal Platform Foundation object owner; NOLOGIN.';
COMMENT ON ROLE issp_extension_owner IS
    'Iron Signal Platform approved-extension owner; NOLOGIN.';
COMMENT ON ROLE issp_migration_executor IS
    'Controlled deployment migration login; credential not provisioned by repository SQL.';
COMMENT ON ROLE issp_runtime IS
    'Common Iron Signal Platform runtime capability; NOLOGIN.';
COMMENT ON ROLE issp_writer_authentication_assertion IS
    'Controlled Authentication Assertion writer capability; object grants deferred.';
COMMENT ON ROLE issp_writer_session_control IS
    'Controlled session writer capability; object grants deferred.';
COMMENT ON ROLE issp_writer_authorization_decision IS
    'Controlled authorization-decision writer capability; object grants deferred.';
COMMENT ON ROLE issp_writer_approval IS
    'Controlled approval writer capability; object grants deferred.';
COMMENT ON ROLE issp_writer_integration_delivery IS
    'Controlled integration-delivery writer capability; object grants deferred.';
COMMENT ON ROLE issp_writer_monitoring_delivery IS
    'Controlled monitoring-delivery writer capability; object grants deferred.';
COMMENT ON ROLE issp_read_only_investigator IS
    'Read-only investigator capability shell; grants deferred to Phase 5 Step 5.';
COMMENT ON ROLE issp_audit_reader IS
    'Audit reader capability shell; grants deferred to Phase 5 Step 5.';
COMMENT ON ROLE issp_validation_reader IS
    'Validation reader capability shell; grants deferred to Phase 5 Step 5.';
COMMENT ON ROLE issp_break_glass IS
    'Emergency-only role shell; NOLOGIN and without members at rest.';
COMMENT ON ROLE issp_service_authorization IS
    'Bounded Foundation authorization service login; credential not provisioned by repository SQL.';
COMMENT ON ROLE issp_service_integration_delivery IS
    'Bounded integration-delivery service login; credential not provisioned by repository SQL.';
COMMENT ON ROLE issp_service_monitoring_delivery IS
    'Bounded monitoring-delivery service login; credential not provisioned by repository SQL.';

-- ============================================================================
-- Bounded capability membership topology
-- ============================================================================

INSERT INTO deployment_meta.database_role_memberships (
    granted_role_name,
    member_role_name,
    inherit_option,
    set_option,
    admin_option,
    introduced_by_migration_id
)
VALUES
    (
        'issp_runtime',
        'issp_service_authorization',
        true,
        false,
        false,
        '900_postgresql_role_topology_and_membership'
    ),
    (
        'issp_writer_authentication_assertion',
        'issp_service_authorization',
        true,
        false,
        false,
        '900_postgresql_role_topology_and_membership'
    ),
    (
        'issp_writer_session_control',
        'issp_service_authorization',
        true,
        false,
        false,
        '900_postgresql_role_topology_and_membership'
    ),
    (
        'issp_writer_authorization_decision',
        'issp_service_authorization',
        true,
        false,
        false,
        '900_postgresql_role_topology_and_membership'
    ),
    (
        'issp_writer_approval',
        'issp_service_authorization',
        true,
        false,
        false,
        '900_postgresql_role_topology_and_membership'
    ),
    (
        'issp_runtime',
        'issp_service_integration_delivery',
        true,
        false,
        false,
        '900_postgresql_role_topology_and_membership'
    ),
    (
        'issp_writer_integration_delivery',
        'issp_service_integration_delivery',
        true,
        false,
        false,
        '900_postgresql_role_topology_and_membership'
    ),
    (
        'issp_runtime',
        'issp_service_monitoring_delivery',
        true,
        false,
        false,
        '900_postgresql_role_topology_and_membership'
    ),
    (
        'issp_writer_monitoring_delivery',
        'issp_service_monitoring_delivery',
        true,
        false,
        false,
        '900_postgresql_role_topology_and_membership'
    );

DO $grant_bounded_memberships$
DECLARE
    v_membership deployment_meta.database_role_memberships%ROWTYPE;
BEGIN
    FOR v_membership IN
        SELECT *
        FROM deployment_meta.database_role_memberships
        ORDER BY granted_role_name, member_role_name
    LOOP
        EXECUTE format(
            'GRANT %I TO %I WITH INHERIT TRUE',
            v_membership.granted_role_name,
            v_membership.member_role_name
        );

        EXECUTE format(
            'GRANT %I TO %I WITH SET FALSE',
            v_membership.granted_role_name,
            v_membership.member_role_name
        );

        EXECUTE format(
            'GRANT %I TO %I WITH ADMIN FALSE',
            v_membership.granted_role_name,
            v_membership.member_role_name
        );
    END LOOP;
END;
$grant_bounded_memberships$;

-- ============================================================================
-- Topology validation before registration
-- ============================================================================

DO $validate_role_attributes$
DECLARE
    v_violation_count bigint;
BEGIN
    SELECT count(*)
    INTO v_violation_count
    FROM deployment_meta.database_roles AS expected_role
    LEFT JOIN pg_roles AS actual_role
      ON actual_role.rolname = expected_role.role_name
    WHERE actual_role.rolname IS NULL
       OR actual_role.rolcanlogin IS DISTINCT FROM expected_role.login_allowed
       OR actual_role.rolconnlimit IS DISTINCT FROM expected_role.expected_connection_limit
       OR actual_role.rolsuper
       OR actual_role.rolcreatedb
       OR actual_role.rolcreaterole
       OR actual_role.rolreplication
       OR actual_role.rolbypassrls;

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'Canonical PostgreSQL role attributes do not match the Phase 5 Step 2 topology',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;

    SELECT count(*)
    INTO v_violation_count
    FROM deployment_meta.database_roles AS expected_role
    JOIN pg_authid AS actual_role
      ON actual_role.rolname = expected_role.role_name
    WHERE expected_role.login_allowed
      AND actual_role.rolpassword IS NOT NULL;

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'Phase 5 Step 2 login roles must not have repository-provisioned passwords',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;
END;
$validate_role_attributes$;

DO $validate_role_memberships$
DECLARE
    v_violation_count bigint;
BEGIN
    SELECT count(*)
    INTO v_violation_count
    FROM deployment_meta.database_role_memberships AS expected_membership
    LEFT JOIN pg_roles AS granted_role
      ON granted_role.rolname = expected_membership.granted_role_name
    LEFT JOIN pg_roles AS member_role
      ON member_role.rolname = expected_membership.member_role_name
    LEFT JOIN pg_auth_members AS actual_membership
      ON actual_membership.roleid = granted_role.oid
     AND actual_membership.member = member_role.oid
    WHERE actual_membership.roleid IS NULL
       OR actual_membership.inherit_option
            IS DISTINCT FROM expected_membership.inherit_option
       OR actual_membership.set_option
            IS DISTINCT FROM expected_membership.set_option
       OR actual_membership.admin_option
            IS DISTINCT FROM expected_membership.admin_option;

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'Canonical PostgreSQL role memberships do not match the Phase 5 Step 2 topology',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;

    SELECT count(*)
    INTO v_violation_count
    FROM pg_auth_members AS actual_membership
    JOIN pg_roles AS granted_role
      ON granted_role.oid = actual_membership.roleid
    JOIN pg_roles AS member_role
      ON member_role.oid = actual_membership.member
    WHERE (
        EXISTS (
            SELECT 1
            FROM deployment_meta.database_roles AS canonical_role
            WHERE canonical_role.role_name = granted_role.rolname
        )
        OR EXISTS (
            SELECT 1
            FROM deployment_meta.database_roles AS canonical_role
            WHERE canonical_role.role_name = member_role.rolname
        )
    )
      AND NOT EXISTS (
          SELECT 1
          FROM deployment_meta.database_role_memberships AS expected_membership
          WHERE expected_membership.granted_role_name = granted_role.rolname
            AND expected_membership.member_role_name = member_role.rolname
      );

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'Unexpected membership involving a canonical Iron Signal Platform role',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;
END;
$validate_role_memberships$;

-- No object ownership is transferred during Step 2.
DO $validate_no_premature_ownership$
DECLARE
    v_violation_count bigint;
BEGIN
    SELECT count(*)
    INTO v_violation_count
    FROM pg_database AS database_record
    JOIN deployment_meta.database_roles AS canonical_role
      ON canonical_role.role_name = pg_get_userbyid(database_record.datdba)
    WHERE database_record.datname = current_database();

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'Phase 5 Step 2 must not transfer current database ownership';
    END IF;

    SELECT count(*)
    INTO v_violation_count
    FROM pg_namespace AS namespace_record
    JOIN deployment_meta.database_roles AS canonical_role
      ON canonical_role.role_name = pg_get_userbyid(namespace_record.nspowner)
    WHERE namespace_record.nspname IN (
        'extensions',
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
        'security_validation',
        'deployment_meta'
    );

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'Phase 5 Step 2 must not transfer schema ownership',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;
END;
$validate_no_premature_ownership$;

REVOKE ALL PRIVILEGES
ON ALL TABLES IN SCHEMA deployment_meta
FROM PUBLIC;

REVOKE ALL PRIVILEGES
ON ALL SEQUENCES IN SCHEMA deployment_meta
FROM PUBLIC;

REVOKE ALL PRIVILEGES
ON ALL FUNCTIONS IN SCHEMA deployment_meta
FROM PUBLIC;

ALTER DEFAULT PRIVILEGES
IN SCHEMA deployment_meta
REVOKE ALL PRIVILEGES ON TABLES FROM PUBLIC;

ALTER DEFAULT PRIVILEGES
IN SCHEMA deployment_meta
REVOKE ALL PRIVILEGES ON SEQUENCES FROM PUBLIC;

ALTER DEFAULT PRIVILEGES
IN SCHEMA deployment_meta
REVOKE ALL PRIVILEGES ON FUNCTIONS FROM PUBLIC;

SELECT deployment_meta.register_deployment_migration(
    p_migration_id => '900_postgresql_role_topology_and_membership',
    p_migration_name => 'PostgreSQL role topology and membership',
    p_migration_checksum => :'deployment_migration_checksum',
    p_relative_path => :'deployment_migration_relative_path',
    p_notes => 'Created canonical owner, runtime, writer, review, service, migration, and disabled break-glass role shells plus bounded service memberships.'
);

COMMIT;
