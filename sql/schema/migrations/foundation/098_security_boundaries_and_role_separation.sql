-- ============================================================================
-- Migration: 098_security_boundaries_and_role_separation.sql
-- Title: Security Boundaries and Role Separation
-- Layer: Platform Foundation
-- Status: REVIEW CANDIDATE
-- Target: PostgreSQL 18
-- ============================================================================
--
-- Purpose:
--   Establish Foundation metadata for database role classes and remove
--   implicit PUBLIC access from Foundation and extension objects.
--
-- Important boundary:
--   This migration does not create the final deployment login roles or transfer
--   schema ownership. Those actions remain deployment-specific and must be
--   completed after the role and ownership design is approved.
--
-- Dependencies:
--   - 097_external_integration_outbox.sql
--
-- Security invariants:
--   - PUBLIC has no access to Foundation schemas, tables, sequences, or
--     functions.
--   - PUBLIC has no direct access to approved extension objects.
--   - Future objects created by the migration identity do not automatically
--     grant access to PUBLIC.
--   - Database role-class incompatibilities can be recorded explicitly.
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
        WHERE migration_id = '097_external_integration_outbox'
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'object_not_in_prerequisite_state',
                MESSAGE = 'Required migration 097_external_integration_outbox is not registered';
    END IF;
END;
$dependency_check$;

-- ============================================================================
-- Database role classes
-- ============================================================================

CREATE TABLE foundation_meta.database_role_classes (
    database_role_class_id  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    role_class_key          text        NOT NULL UNIQUE,
    title                   text        NOT NULL,
    description             text        NOT NULL,
    login_allowed           boolean     NOT NULL,
    ownership_allowed       boolean     NOT NULL,
    operational_use_allowed boolean     NOT NULL,
    break_glass_only        boolean     NOT NULL DEFAULT false,
    status                  text        NOT NULL DEFAULT 'ACTIVE',
    created_at              timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_by_reference    text        NOT NULL,

    CONSTRAINT database_role_classes_key_ck
        CHECK (
            role_class_key ~ '^[a-z][a-z0-9_]*$'
        ),

    CONSTRAINT database_role_classes_title_ck
        CHECK (
            btrim(title) <> ''
        ),

    CONSTRAINT database_role_classes_description_ck
        CHECK (
            btrim(description) <> ''
        ),

    CONSTRAINT database_role_classes_status_ck
        CHECK (
            status IN (
                'ACTIVE',
                'SUSPENDED',
                'RETIRED'
            )
        ),

    CONSTRAINT database_role_classes_break_glass_ck
        CHECK (
            break_glass_only = false
            OR login_allowed = true
        )
);

COMMENT ON TABLE foundation_meta.database_role_classes IS
    'Approved classes of PostgreSQL roles and the capabilities each class may possess.';

CREATE TABLE foundation_meta.incompatible_database_role_classes (
    incompatible_database_role_class_id uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    first_role_class_id                  uuid        NOT NULL,
    second_role_class_id                 uuid        NOT NULL,
    reason                               text        NOT NULL,
    status                               text        NOT NULL DEFAULT 'ACTIVE',
    created_at                           timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_by_reference                 text        NOT NULL,

    CONSTRAINT incompatible_role_classes_first_fk
        FOREIGN KEY (first_role_class_id)
        REFERENCES foundation_meta.database_role_classes (
            database_role_class_id
        ),

    CONSTRAINT incompatible_role_classes_second_fk
        FOREIGN KEY (second_role_class_id)
        REFERENCES foundation_meta.database_role_classes (
            database_role_class_id
        ),

    CONSTRAINT incompatible_role_classes_no_self_ck
        CHECK (
            first_role_class_id <> second_role_class_id
        ),

    CONSTRAINT incompatible_role_classes_reason_ck
        CHECK (
            btrim(reason) <> ''
        ),

    CONSTRAINT incompatible_role_classes_status_ck
        CHECK (
            status IN (
                'ACTIVE',
                'SUSPENDED',
                'RETIRED'
            )
        )
);

COMMENT ON TABLE foundation_meta.incompatible_database_role_classes IS
    'Pairs of PostgreSQL role classes that must not be accumulated by the same operating identity.';

CREATE UNIQUE INDEX incompatible_database_role_classes_pair_uq
    ON foundation_meta.incompatible_database_role_classes (
        LEAST(first_role_class_id, second_role_class_id),
        GREATEST(first_role_class_id, second_role_class_id)
    );

-- ============================================================================
-- Remove PUBLIC access from schemas
-- ============================================================================

REVOKE ALL ON SCHEMA extensions FROM PUBLIC;
REVOKE ALL ON SCHEMA foundation_meta FROM PUBLIC;
REVOKE ALL ON SCHEMA trust FROM PUBLIC;
REVOKE ALL ON SCHEMA identity FROM PUBLIC;
REVOKE ALL ON SCHEMA organization FROM PUBLIC;
REVOKE ALL ON SCHEMA service FROM PUBLIC;
REVOKE ALL ON SCHEMA attestation FROM PUBLIC;
REVOKE ALL ON SCHEMA approval FROM PUBLIC;
REVOKE ALL ON SCHEMA access_control FROM PUBLIC;
REVOKE ALL ON SCHEMA decision FROM PUBLIC;
REVOKE ALL ON SCHEMA governance FROM PUBLIC;
REVOKE ALL ON SCHEMA compliance FROM PUBLIC;
REVOKE ALL ON SCHEMA risk FROM PUBLIC;
REVOKE ALL ON SCHEMA resilience FROM PUBLIC;
REVOKE ALL ON SCHEMA performance FROM PUBLIC;
REVOKE ALL ON SCHEMA observability FROM PUBLIC;
REVOKE ALL ON SCHEMA integration FROM PUBLIC;
REVOKE ALL ON SCHEMA security_validation FROM PUBLIC;

-- ============================================================================
-- Remove PUBLIC access from existing Foundation objects
-- ============================================================================

REVOKE ALL PRIVILEGES
ON ALL TABLES IN SCHEMA
    foundation_meta,
    trust,
    identity,
    organization,
    service,
    attestation,
    approval,
    access_control,
    decision,
    governance,
    compliance,
    risk,
    resilience,
    performance,
    observability,
    integration
FROM PUBLIC;

REVOKE ALL PRIVILEGES
ON ALL SEQUENCES IN SCHEMA
    foundation_meta,
    trust,
    identity,
    organization,
    service,
    attestation,
    approval,
    access_control,
    decision,
    governance,
    compliance,
    risk,
    resilience,
    performance,
    observability,
    integration
FROM PUBLIC;

REVOKE ALL PRIVILEGES
ON ALL FUNCTIONS IN SCHEMA
    extensions,
    foundation_meta,
    trust,
    identity,
    organization,
    service,
    attestation,
    approval,
    access_control,
    decision,
    governance,
    compliance,
    risk,
    resilience,
    performance,
    observability,
    integration
FROM PUBLIC;

-- ============================================================================
-- Protect future objects created by the migration identity
-- ============================================================================

ALTER DEFAULT PRIVILEGES
IN SCHEMA
    foundation_meta,
    trust,
    identity,
    organization,
    service,
    attestation,
    approval,
    access_control,
    decision,
    governance,
    compliance,
    risk,
    resilience,
    performance,
    observability,
    integration
REVOKE ALL PRIVILEGES ON TABLES FROM PUBLIC;

ALTER DEFAULT PRIVILEGES
IN SCHEMA
    foundation_meta,
    trust,
    identity,
    organization,
    service,
    attestation,
    approval,
    access_control,
    decision,
    governance,
    compliance,
    risk,
    resilience,
    performance,
    observability,
    integration
REVOKE ALL PRIVILEGES ON SEQUENCES FROM PUBLIC;

ALTER DEFAULT PRIVILEGES
IN SCHEMA
    extensions,
    foundation_meta,
    trust,
    identity,
    organization,
    service,
    attestation,
    approval,
    access_control,
    decision,
    governance,
    compliance,
    risk,
    resilience,
    performance,
    observability,
    integration
REVOKE ALL PRIVILEGES ON FUNCTIONS FROM PUBLIC;

-- ============================================================================
-- Register migration
-- ============================================================================

SELECT foundation_meta.register_migration(
    p_migration_id       => '098_security_boundaries_and_role_separation',
    p_migration_name     => 'Security boundaries and role separation',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created database role-class metadata and removed PUBLIC privileges from Foundation and extension objects.'
);

COMMIT;


