-- ============================================================================
-- Migration: 099_foundation_validation.sql
-- Title: Foundation Validation
-- Layer: Platform Foundation
-- Status: REVIEW CANDIDATE
-- Target: PostgreSQL 18
-- ============================================================================
--
-- Purpose:
--   Create read-only validation views for the Platform Foundation.
--
-- This migration validates and exposes:
--   - Applied migration state
--   - PostgreSQL extension placement
--   - Schema privilege boundaries, including extensions
--   - PUBLIC grants on tables, sequences, and routines
--   - Function ownership, SECURITY DEFINER use, and fixed search paths
--   - Schema, relation, and function ownership
--   - Primary-key coverage
--   - Row-Level Security posture
--   - Expected append-only object posture
--   - Migration checksum posture
--
-- Important:
--   Some findings are intentionally marked REVIEW_REQUIRED rather than FAIL.
--   Ownership, RLS, append-only enforcement, runtime roles, and controlled
--   write paths are not considered complete merely because the migrations
--   execute successfully.
--
-- Dependencies:
--   - 098_security_boundaries_and_role_separation.sql
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '10min';
SET LOCAL idle_in_transaction_session_timeout = '10min';

SELECT pg_advisory_xact_lock(
    hashtext(current_database()),
    hashtext('platform-foundation-migrations')
);

-- ============================================================================
-- Dependency validation
-- ============================================================================

DO $dependency_check$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM foundation_meta.applied_migrations
        WHERE migration_id = '098_security_boundaries_and_role_separation'
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'object_not_in_prerequisite_state',
                MESSAGE = 'Required migration 098_security_boundaries_and_role_separation is not registered';
    END IF;
END;
$dependency_check$;

-- Drop only validation views owned by this migration so the migration may be
-- reapplied safely during development.
DROP VIEW IF EXISTS security_validation.foundation_review_summary;
DROP VIEW IF EXISTS security_validation.append_only_posture;
DROP VIEW IF EXISTS security_validation.expected_append_only_objects;
DROP VIEW IF EXISTS security_validation.row_security_posture;
DROP VIEW IF EXISTS security_validation.tables_without_primary_keys;
DROP VIEW IF EXISTS security_validation.function_security_posture;
DROP VIEW IF EXISTS security_validation.security_definer_functions;
DROP VIEW IF EXISTS security_validation.public_routine_privileges;
DROP VIEW IF EXISTS security_validation.public_sequence_privileges;
DROP VIEW IF EXISTS security_validation.public_table_privileges;
DROP VIEW IF EXISTS security_validation.foundation_function_ownership;
DROP VIEW IF EXISTS security_validation.foundation_relation_ownership;
DROP VIEW IF EXISTS security_validation.foundation_schema_ownership;
DROP VIEW IF EXISTS security_validation.public_schema_privileges;
DROP VIEW IF EXISTS security_validation.extension_inventory;
DROP VIEW IF EXISTS security_validation.foundation_table_counts;
DROP VIEW IF EXISTS security_validation.migration_integrity_status;
DROP VIEW IF EXISTS security_validation.migration_summary;
DROP VIEW IF EXISTS security_validation.foundation_schemas;

-- ============================================================================
-- Canonical Foundation schema list
-- ============================================================================

CREATE VIEW security_validation.foundation_schemas AS
SELECT
    registry.schema_name,
    registry.capability_key,
    registry.architectural_layer,
    registry.purpose,
    registry.active
FROM foundation_meta.schema_registry AS registry
ORDER BY registry.schema_name;

COMMENT ON VIEW security_validation.foundation_schemas IS
    'Canonical list of registered Foundation, validation, and extension schemas.';

-- ============================================================================
-- Migration validation
-- ============================================================================

CREATE VIEW security_validation.migration_summary AS
SELECT
    migration_id,
    migration_name,
    migration_layer,
    applied_at,
    applied_by,
    database_name,
    server_version_num,
    application_name,
    transaction_id
FROM foundation_meta.applied_migrations
ORDER BY migration_id;

COMMENT ON VIEW security_validation.migration_summary IS
    'Applied Platform Foundation migrations in migration order.';

CREATE VIEW security_validation.migration_integrity_status AS
SELECT
    migration_id,
    migration_name,
    migration_checksum,
    migration_checksum IS NOT NULL AS checksum_present,
    CASE
        WHEN migration_checksum IS NULL THEN 'REVIEW_REQUIRED'
        ELSE 'PASS'
    END AS review_status
FROM foundation_meta.applied_migrations
ORDER BY migration_id;

COMMENT ON VIEW security_validation.migration_integrity_status IS
    'Reports whether each applied migration has a stored SHA-256 checksum.';

-- ============================================================================
-- PostgreSQL extension validation
-- ============================================================================

CREATE VIEW security_validation.extension_inventory AS
SELECT
    extension.extname AS extension_name,
    namespace.nspname AS extension_schema,
    extension.extversion AS extension_version,
    pg_get_userbyid(extension.extowner) AS owner_name,
    owner_role.rolcanlogin AS owner_can_login,
    owner_role.rolsuper AS owner_is_superuser
FROM pg_extension AS extension
JOIN pg_namespace AS namespace
  ON namespace.oid = extension.extnamespace
JOIN pg_roles AS owner_role
  ON owner_role.oid = extension.extowner
ORDER BY extension.extname;

COMMENT ON VIEW security_validation.extension_inventory IS
    'Installed PostgreSQL extensions, their schemas, versions, and ownership posture.';

-- ============================================================================
-- Schema privilege and ownership validation
-- ============================================================================

CREATE VIEW security_validation.public_schema_privileges AS
SELECT
    namespace.nspname AS schema_name,
    has_schema_privilege(
        'public',
        namespace.oid,
        'USAGE'
    ) AS public_usage,
    has_schema_privilege(
        'public',
        namespace.oid,
        'CREATE'
    ) AS public_create
FROM pg_namespace AS namespace
JOIN foundation_meta.schema_registry AS registry
  ON registry.schema_name = namespace.nspname
WHERE registry.active = true
ORDER BY namespace.nspname;

COMMENT ON VIEW security_validation.public_schema_privileges IS
    'PUBLIC USAGE and CREATE privileges for every registered active schema, including extensions.';

CREATE VIEW security_validation.foundation_schema_ownership AS
SELECT
    namespace.nspname AS schema_name,
    pg_get_userbyid(namespace.nspowner) AS owner_name,
    owner_role.rolcanlogin AS owner_can_login,
    owner_role.rolsuper AS owner_is_superuser
FROM pg_namespace AS namespace
JOIN foundation_meta.schema_registry AS registry
  ON registry.schema_name = namespace.nspname
JOIN pg_roles AS owner_role
  ON owner_role.oid = namespace.nspowner
WHERE registry.active = true
ORDER BY namespace.nspname;

COMMENT ON VIEW security_validation.foundation_schema_ownership IS
    'Ownership posture of every registered active Foundation schema.';

-- ============================================================================
-- Relation and function ownership
-- ============================================================================

CREATE VIEW security_validation.foundation_relation_ownership AS
SELECT
    namespace.nspname AS schema_name,
    relation.relname AS object_name,
    CASE relation.relkind
        WHEN 'r' THEN 'TABLE'
        WHEN 'p' THEN 'PARTITIONED_TABLE'
        WHEN 'v' THEN 'VIEW'
        WHEN 'm' THEN 'MATERIALIZED_VIEW'
        WHEN 'S' THEN 'SEQUENCE'
        WHEN 'f' THEN 'FOREIGN_TABLE'
        ELSE relation.relkind::text
    END AS object_type,
    pg_get_userbyid(relation.relowner) AS owner_name,
    owner_role.rolcanlogin AS owner_can_login,
    owner_role.rolsuper AS owner_is_superuser
FROM pg_class AS relation
JOIN pg_namespace AS namespace
  ON namespace.oid = relation.relnamespace
JOIN foundation_meta.schema_registry AS registry
  ON registry.schema_name = namespace.nspname
JOIN pg_roles AS owner_role
  ON owner_role.oid = relation.relowner
WHERE registry.active = true
  AND relation.relkind IN ('r', 'p', 'v', 'm', 'S', 'f')
ORDER BY
    namespace.nspname,
    object_type,
    relation.relname;

COMMENT ON VIEW security_validation.foundation_relation_ownership IS
    'Ownership posture of Foundation tables, views, sequences, and related relations.';

CREATE VIEW security_validation.foundation_function_ownership AS
SELECT
    namespace.nspname AS schema_name,
    procedure.proname AS function_name,
    pg_get_function_identity_arguments(procedure.oid) AS argument_types,
    pg_get_userbyid(procedure.proowner) AS owner_name,
    owner_role.rolcanlogin AS owner_can_login,
    owner_role.rolsuper AS owner_is_superuser,
    procedure.prosecdef AS security_definer
FROM pg_proc AS procedure
JOIN pg_namespace AS namespace
  ON namespace.oid = procedure.pronamespace
JOIN foundation_meta.schema_registry AS registry
  ON registry.schema_name = namespace.nspname
JOIN pg_roles AS owner_role
  ON owner_role.oid = procedure.proowner
WHERE registry.active = true
ORDER BY
    namespace.nspname,
    procedure.proname,
    pg_get_function_identity_arguments(procedure.oid);

COMMENT ON VIEW security_validation.foundation_function_ownership IS
    'Ownership and SECURITY DEFINER posture of Foundation and approved extension routines.';

-- ============================================================================
-- PUBLIC object privileges
-- ============================================================================

CREATE VIEW security_validation.public_table_privileges AS
SELECT
    privileges.grantor,
    privileges.grantee,
    privileges.table_schema,
    privileges.table_name,
    privileges.privilege_type,
    privileges.is_grantable
FROM information_schema.table_privileges AS privileges
JOIN foundation_meta.schema_registry AS registry
  ON registry.schema_name = privileges.table_schema
WHERE privileges.grantee = 'PUBLIC'
  AND registry.active = true
ORDER BY
    privileges.table_schema,
    privileges.table_name,
    privileges.privilege_type;

COMMENT ON VIEW security_validation.public_table_privileges IS
    'Direct table and view privileges granted to PUBLIC in registered schemas.';

CREATE VIEW security_validation.public_sequence_privileges AS
SELECT
    privileges.grantor,
    privileges.grantee,
    privileges.object_schema AS sequence_schema,
    privileges.object_name AS sequence_name,
    privileges.privilege_type,
    privileges.is_grantable
FROM information_schema.usage_privileges AS privileges
JOIN foundation_meta.schema_registry AS registry
  ON registry.schema_name = privileges.object_schema
WHERE privileges.grantee = 'PUBLIC'
  AND privileges.object_type = 'SEQUENCE'
  AND registry.active = true
ORDER BY
    privileges.object_schema,
    privileges.object_name,
    privileges.privilege_type;

COMMENT ON VIEW security_validation.public_sequence_privileges IS
    'Sequence privileges granted to PUBLIC in registered schemas.';

CREATE VIEW security_validation.public_routine_privileges AS
SELECT
    privileges.grantor,
    privileges.grantee,
    privileges.routine_schema,
    privileges.routine_name,
    privileges.privilege_type,
    privileges.is_grantable
FROM information_schema.routine_privileges AS privileges
JOIN foundation_meta.schema_registry AS registry
  ON registry.schema_name = privileges.routine_schema
WHERE privileges.grantee = 'PUBLIC'
  AND registry.active = true
ORDER BY
    privileges.routine_schema,
    privileges.routine_name,
    privileges.privilege_type;

COMMENT ON VIEW security_validation.public_routine_privileges IS
    'Routine privileges granted to PUBLIC in registered schemas.';

-- ============================================================================
-- Function security posture
-- ============================================================================

CREATE VIEW security_validation.function_security_posture AS
SELECT
    namespace.nspname AS schema_name,
    procedure.proname AS function_name,
    pg_get_function_identity_arguments(procedure.oid) AS argument_types,
    pg_get_userbyid(procedure.proowner) AS owner_name,
    procedure.prosecdef AS security_definer,
    procedure.provolatile AS volatility_code,
    procedure.proparallel AS parallel_safety_code,
    procedure.proconfig,
    COALESCE(
        (
            SELECT setting
            FROM unnest(procedure.proconfig) AS setting
            WHERE setting LIKE 'search_path=%'
            LIMIT 1
        ),
        ''
    ) AS search_path_setting,
    EXISTS (
        SELECT 1
        FROM unnest(procedure.proconfig) AS setting
        WHERE setting LIKE 'search_path=%'
    ) AS fixed_search_path_present
FROM pg_proc AS procedure
JOIN pg_namespace AS namespace
  ON namespace.oid = procedure.pronamespace
JOIN foundation_meta.schema_registry AS registry
  ON registry.schema_name = namespace.nspname
WHERE registry.active = true
ORDER BY
    namespace.nspname,
    procedure.proname,
    pg_get_function_identity_arguments(procedure.oid);

COMMENT ON VIEW security_validation.function_security_posture IS
    'Foundation function security posture, including SECURITY DEFINER and fixed search_path state.';

CREATE VIEW security_validation.security_definer_functions AS
SELECT
    schema_name,
    function_name,
    argument_types,
    owner_name,
    proconfig,
    search_path_setting,
    fixed_search_path_present
FROM security_validation.function_security_posture
WHERE security_definer = true
ORDER BY
    schema_name,
    function_name,
    argument_types;

COMMENT ON VIEW security_validation.security_definer_functions IS
    'SECURITY DEFINER functions and whether each function has an explicit fixed search_path.';

-- ============================================================================
-- Relational integrity posture
-- ============================================================================

CREATE VIEW security_validation.tables_without_primary_keys AS
SELECT
    namespace.nspname AS schema_name,
    relation.relname AS table_name,
    CASE relation.relkind
        WHEN 'r' THEN 'TABLE'
        WHEN 'p' THEN 'PARTITIONED_TABLE'
        ELSE relation.relkind::text
    END AS table_type
FROM pg_class AS relation
JOIN pg_namespace AS namespace
  ON namespace.oid = relation.relnamespace
JOIN foundation_meta.schema_registry AS registry
  ON registry.schema_name = namespace.nspname
WHERE registry.active = true
  AND namespace.nspname NOT IN (
      'extensions',
      'security_validation'
  )
  AND relation.relkind IN ('r', 'p')
  AND NOT EXISTS (
      SELECT 1
      FROM pg_constraint AS constraint_record
      WHERE constraint_record.conrelid = relation.oid
        AND constraint_record.contype = 'p'
  )
ORDER BY
    namespace.nspname,
    relation.relname;

COMMENT ON VIEW security_validation.tables_without_primary_keys IS
    'Foundation tables and partitioned tables without a declared primary key.';

CREATE VIEW security_validation.row_security_posture AS
SELECT
    namespace.nspname AS schema_name,
    relation.relname AS table_name,
    relation.relrowsecurity AS row_security_enabled,
    relation.relforcerowsecurity AS force_row_security,
    (
        SELECT count(*)::bigint
        FROM pg_policy AS policy
        WHERE policy.polrelid = relation.oid
    ) AS policy_count
FROM pg_class AS relation
JOIN pg_namespace AS namespace
  ON namespace.oid = relation.relnamespace
JOIN foundation_meta.schema_registry AS registry
  ON registry.schema_name = namespace.nspname
WHERE registry.active = true
  AND namespace.nspname NOT IN (
      'extensions',
      'security_validation'
  )
  AND relation.relkind IN ('r', 'p')
ORDER BY
    namespace.nspname,
    relation.relname;

COMMENT ON VIEW security_validation.row_security_posture IS
    'RLS enablement, FORCE ROW LEVEL SECURITY state, and policy count for Foundation tables.';

-- ============================================================================
-- Append-only posture
-- ============================================================================

CREATE VIEW security_validation.expected_append_only_objects AS
SELECT
    expected.schema_name,
    expected.table_name,
    expected.rationale
FROM (
    VALUES
        (
            'foundation_meta'::text,
            'applied_migrations'::text,
            'Applied migration history must not be rewritten or deleted.'
        ),
        (
            'trust'::text,
            'revocations'::text,
            'Trust revocation history must remain attributable and reviewable.'
        ),
        (
            'trust'::text,
            'trust_lifecycle_events'::text,
            'Trust lifecycle history must remain append-only.'
        ),
        (
            'identity'::text,
            'identity_lifecycle_events'::text,
            'Identity lifecycle history must remain append-only.'
        ),
        (
            'approval'::text,
            'approval_actions'::text,
            'Approval actions must not be silently rewritten.'
        ),
        (
            'decision'::text,
            'decision_records'::text,
            'Decision Records are canonical historical records.'
        ),
        (
            'decision'::text,
            'evaluation_records'::text,
            'Decision evaluation history must remain bound to the original decision.'
        ),
        (
            'decision'::text,
            'supporting_records'::text,
            'Supporting Justification Chain references must remain historical.'
        ),
        (
            'governance'::text,
            'object_versions'::text,
            'Historical object versions must not be overwritten.'
        ),
        (
            'governance'::text,
            'object_version_relationships'::text,
            'Historical version relationships must remain attributable.'
        ),
        (
            'governance'::text,
            'lifecycle_events'::text,
            'Governed lifecycle history must remain append-only.'
        ),
        (
            'compliance'::text,
            'control_assurance_artifacts'::text,
            'Assurance-artifact records must remain immutable and historically attributable.'
        ),
        (
            'compliance'::text,
            'control_assurance_artifact_validations'::text,
            'Assurance-artifact validation results must remain append-only.'
        ),
        (
            'compliance'::text,
            'control_implementation_assurance_artifacts'::text,
            'Implementation-to-artifact relationships must remain historically attributable.'
        ),
        (
            'compliance'::text,
            'control_assessments'::text,
            'Control assessment results must remain append-only.'
        ),
        (
            'compliance'::text,
            'assessment_assurance_artifacts'::text,
            'Assessment-to-artifact relationships must remain historically attributable.'
        )
) AS expected (
    schema_name,
    table_name,
    rationale
)
ORDER BY
    expected.schema_name,
    expected.table_name;

COMMENT ON VIEW security_validation.expected_append_only_objects IS
    'Foundation tables expected to receive explicit append-only or controlled-correction enforcement.';

CREATE VIEW security_validation.append_only_posture AS
SELECT
    expected.schema_name,
    expected.table_name,
    expected.rationale,
    relation.oid IS NOT NULL AS table_exists,
    COALESCE(
        (
            SELECT bool_or(
                access_control_entry.privilege_type IN (
                    'UPDATE',
                    'DELETE',
                    'TRUNCATE'
                )
                AND access_control_entry.grantee <> relation.relowner
            )
            FROM aclexplode(
                COALESCE(
                    relation.relacl,
                    acldefault('r', relation.relowner)
                )
            ) AS access_control_entry
        ),
        false
    ) AS non_owner_write_grant_present,
    EXISTS (
        SELECT 1
        FROM pg_trigger AS trigger_record
        WHERE trigger_record.tgrelid = relation.oid
          AND trigger_record.tgisinternal = false
          AND (trigger_record.tgtype::integer & 2) = 2
          AND (
              (trigger_record.tgtype::integer & 8) = 8
              OR
              (trigger_record.tgtype::integer & 16) = 16
          )
    ) AS before_update_or_delete_trigger_present,
    COALESCE(relation.relrowsecurity, false) AS row_security_enabled,
    COALESCE(relation.relforcerowsecurity, false) AS force_row_security,
    CASE
        WHEN relation.oid IS NULL THEN 'FAIL'
        WHEN COALESCE(
            (
                SELECT bool_or(
                    access_control_entry.privilege_type IN (
                        'UPDATE',
                        'DELETE',
                        'TRUNCATE'
                    )
                    AND access_control_entry.grantee <> relation.relowner
                )
                FROM aclexplode(
                    COALESCE(
                        relation.relacl,
                        acldefault('r', relation.relowner)
                    )
                ) AS access_control_entry
            ),
            false
        ) THEN 'FAIL'
        WHEN EXISTS (
            SELECT 1
            FROM pg_trigger AS trigger_record
            WHERE trigger_record.tgrelid = relation.oid
              AND trigger_record.tgisinternal = false
              AND (trigger_record.tgtype::integer & 2) = 2
              AND (
                  (trigger_record.tgtype::integer & 8) = 8
                  OR
                  (trigger_record.tgtype::integer & 16) = 16
              )
        ) THEN 'GUARD_PRESENT_REVIEW_REQUIRED'
        ELSE 'CONTROL_PATH_REVIEW_REQUIRED'
    END AS review_status
FROM security_validation.expected_append_only_objects AS expected
LEFT JOIN pg_namespace AS namespace
  ON namespace.nspname = expected.schema_name
LEFT JOIN pg_class AS relation
  ON relation.relnamespace = namespace.oid
 AND relation.relname = expected.table_name
 AND relation.relkind IN ('r', 'p')
ORDER BY
    expected.schema_name,
    expected.table_name;

COMMENT ON VIEW security_validation.append_only_posture IS
    'Review posture for tables expected to use append-only or controlled-correction protections.';

-- ============================================================================
-- Foundation table counts
-- ============================================================================

CREATE VIEW security_validation.foundation_table_counts AS
SELECT
    tables.schemaname,
    count(*)::bigint AS table_count
FROM pg_tables AS tables
JOIN foundation_meta.schema_registry AS registry
  ON registry.schema_name = tables.schemaname
WHERE registry.active = true
  AND tables.schemaname NOT IN (
      'extensions',
      'security_validation'
  )
GROUP BY tables.schemaname
ORDER BY tables.schemaname;

COMMENT ON VIEW security_validation.foundation_table_counts IS
    'Table count by active Foundation data schema.';

-- ============================================================================
-- Consolidated review summary
-- ============================================================================

CREATE VIEW security_validation.foundation_review_summary AS
SELECT
    'Applied Foundation migrations'::text AS check_name,
    count(*)::text AS observed_value,
    '31'::text AS expected_value,
    CASE
        WHEN count(*) = 31 THEN 'PASS'
        ELSE 'FAIL'
    END AS review_status
FROM foundation_meta.applied_migrations

UNION ALL

SELECT
    'pgcrypto extension schema',
    COALESCE(
        (
            SELECT extension_schema
            FROM security_validation.extension_inventory
            WHERE extension_name = 'pgcrypto'
        ),
        'NOT_INSTALLED'
    ),
    'extensions',
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM security_validation.extension_inventory
            WHERE extension_name = 'pgcrypto'
              AND extension_schema = 'extensions'
        ) THEN 'PASS'
        ELSE 'FAIL'
    END

UNION ALL

SELECT
    'Registered schemas with PUBLIC USAGE',
    count(*)::text,
    '0',
    CASE
        WHEN count(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM security_validation.public_schema_privileges
WHERE public_usage = true

UNION ALL

SELECT
    'Registered schemas with PUBLIC CREATE',
    count(*)::text,
    '0',
    CASE
        WHEN count(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM security_validation.public_schema_privileges
WHERE public_create = true

UNION ALL

SELECT
    'PUBLIC table or view grants',
    count(*)::text,
    '0',
    CASE
        WHEN count(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM security_validation.public_table_privileges

UNION ALL

SELECT
    'PUBLIC sequence grants',
    count(*)::text,
    '0',
    CASE
        WHEN count(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM security_validation.public_sequence_privileges

UNION ALL

SELECT
    'PUBLIC routine grants',
    count(*)::text,
    '0',
    CASE
        WHEN count(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM security_validation.public_routine_privileges

UNION ALL

SELECT
    'SECURITY DEFINER functions without fixed search_path',
    count(*)::text,
    '0',
    CASE
        WHEN count(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM security_validation.security_definer_functions
WHERE fixed_search_path_present = false

UNION ALL

SELECT
    'Foundation tables without primary keys',
    count(*)::text,
    '0',
    CASE
        WHEN count(*) = 0 THEN 'PASS'
        ELSE 'REVIEW_REQUIRED'
    END
FROM security_validation.tables_without_primary_keys

UNION ALL

SELECT
    'Append-only candidates with direct non-owner write grants',
    count(*)::text,
    '0',
    CASE
        WHEN count(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM security_validation.append_only_posture
WHERE non_owner_write_grant_present = true

UNION ALL

SELECT
    'Append-only candidates requiring control-path review',
    count(*)::text,
    '0',
    CASE
        WHEN count(*) = 0 THEN 'PASS'
        ELSE 'REVIEW_REQUIRED'
    END
FROM security_validation.append_only_posture
WHERE review_status = 'CONTROL_PATH_REVIEW_REQUIRED'

UNION ALL

SELECT
    'Objects owned by login-capable roles',
    count(*)::text,
    '0 before production',
    CASE
        WHEN count(*) = 0 THEN 'PASS'
        ELSE 'REVIEW_REQUIRED'
    END
FROM (
    SELECT schema_name, object_name, object_type
    FROM security_validation.foundation_relation_ownership
    WHERE owner_can_login = true

    UNION ALL

    SELECT schema_name, function_name, 'FUNCTION'
    FROM security_validation.foundation_function_ownership
    WHERE owner_can_login = true
) AS login_owned_objects

UNION ALL

SELECT
    'Applied migrations without stored checksums',
    count(*)::text,
    '0 before production',
    CASE
        WHEN count(*) = 0 THEN 'PASS'
        ELSE 'REVIEW_REQUIRED'
    END
FROM security_validation.migration_integrity_status
WHERE checksum_present = false

UNION ALL

SELECT
    'Tables with Row-Level Security enabled',
    count(*)::text,
    'Policy-driven',
    'INFO'
FROM security_validation.row_security_posture
WHERE row_security_enabled = true;

COMMENT ON VIEW security_validation.foundation_review_summary IS
    'Consolidated pass, fail, review-required, and informational Foundation validation results.';

-- Validation objects must not become public merely because they are views.
REVOKE ALL PRIVILEGES
ON ALL TABLES IN SCHEMA security_validation
FROM PUBLIC;

-- Register or harmlessly re-register this migration.
SELECT foundation_meta.register_migration(
    p_migration_id       => '099_foundation_validation',
    p_migration_name     => 'Foundation validation',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created comprehensive Foundation validation views covering extensions, privileges, ownership, function security, relational integrity, RLS, append-only posture, and migration checksums.'
);

COMMIT;

